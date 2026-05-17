import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, Query, status

from config import settings
from database.db import get_db
from models.library import (
    CreateLibraryBody,
    LibraryResponse,
    StorageBreakdownResponse,
    StorageByType,
    UpdateLibraryBody,
)
from routers.deps import validate_token_or_local
from services import (
    activity_service,
    browse_service,
    group_service,
    library_service,
    notification_service,
    thumbnail_worker,
)
from services.browse_service import BrowseError

logger = logging.getLogger(__name__)

# Sentinel marker — distinguishes "PATCH didn't include this field"
# from "PATCH explicitly set this field to None".  Used by the tri-
# state `<codec>_stream_copy_override` columns where None is itself a
# legal value (inherit global setting).  Lives at module scope so the
# library_service can re-import the same singleton if needed.
_UNSET: object = object()

router = APIRouter()


def _override_to_bool(raw: object | None) -> bool | None:
    """Plan 19 §M8 — `<codec>_stream_copy_override` is INTEGER NULL.

    NULL inherits the global setting; 0 / 1 pin the behaviour.  Pydantic
    validates the wire shape (bool | None); this helper only converts
    SQLite's INTEGER-or-NULL storage into the same shape.
    """
    if raw is None:
        return None
    return bool(raw)


def _parse_library(row: dict) -> LibraryResponse:
    raw_tmdb = row.get("tmdb_enabled")
    # Pre-migration rows have no tmdb_enabled column; default to True
    # so the operator sees current behaviour until they explicitly
    # opt out via the edit form.
    tmdb_enabled = True if raw_tmdb is None else bool(raw_tmdb)
    return LibraryResponse(
        id=row["id"],
        name=row["name"],
        type=row["type"],
        root_paths=row["root_paths"],
        last_scanned=row.get("last_scanned"),
        created_at=row["created_at"],
        file_count=row.get("file_count", 0),
        total_size_bytes=row.get("total_size_bytes", 0),
        cover_urls=row.get("cover_urls", []),
        av1_stream_copy_override=_override_to_bool(row.get("av1_stream_copy_override")),
        vp9_stream_copy_override=_override_to_bool(row.get("vp9_stream_copy_override")),
        tmdb_enabled=tmdb_enabled,
    )


@router.get("", response_model=list[LibraryResponse])
async def list_libraries(
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[LibraryResponse]:
    """List all libraries.  Localhost callers (operator's desktop CP) see
    every row; bearer-token callers (paired clients) see only the libraries
    their group memberships expose — per the v2 content-spaces visibility
    model (M2 of `docs/10_planning/13_groups_v2_content_spaces.md`).
    """
    rows = await library_service.list_libraries(db)
    if _client is not None:
        visible = await group_service.get_visible_libraries(db, _client["id"])
        rows = [r for r in rows if r["id"] in visible.library_ids]
    return [_parse_library(r) for r in rows]


@router.get("/storage-breakdown", response_model=StorageBreakdownResponse)
async def get_storage_breakdown(
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> StorageBreakdownResponse:
    """Aggregated storage usage backing the redesigned Dashboard donut."""
    payload = await library_service.get_storage_breakdown(db)
    return StorageBreakdownResponse(
        total_bytes=payload["total_bytes"],
        capacity_bytes=payload["capacity_bytes"],
        by_type=StorageByType(**payload["by_type"]),
    )


@router.post("", response_model=LibraryResponse, status_code=status.HTTP_201_CREATED)
async def create_library(
    body: CreateLibraryBody,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> LibraryResponse:
    row = await library_service.create_library(
        db,
        name=body.name,
        lib_type=body.type,
        root_paths=body.root_paths,
        tmdb_enabled=body.tmdb_enabled,
    )
    try:
        await activity_service.record(
            db,
            type="library.create",
            summary=f"Library '{body.name}' created ({body.type})",
            actor_kind="client" if _client else "operator",
            actor_id=_client["id"] if _client else None,
            target_kind="library",
            target_id=row["id"],
            payload={"type": body.type, "root_count": len(body.root_paths)},
        )
    except Exception:
        logger.warning("Failed to record library.create activity event", exc_info=True)
    notification_service.broadcast_event("library_changed")
    return _parse_library(row)


@router.get("/{library_id}", response_model=LibraryResponse)
async def get_library(
    library_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> LibraryResponse:
    row = await library_service.get_library(db, library_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Library not found"
        )
    return _parse_library(row)


@router.patch("/{library_id}", response_model=LibraryResponse)
async def update_library(
    library_id: str,
    body: UpdateLibraryBody,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> LibraryResponse:
    # Plan 19 §M8 — override fields are tri-state (NULL inherits, 0/1
    # pin).  PATCH semantics make us distinguish "field omitted" from
    # "field explicitly set to null"; pydantic v2's `model_fields_set`
    # is the cleanest way.
    fields_set = body.model_fields_set
    has_av1_override = "av1_stream_copy_override" in fields_set
    has_vp9_override = "vp9_stream_copy_override" in fields_set
    has_tmdb_enabled = "tmdb_enabled" in fields_set

    if (
        body.name is None
        and body.root_paths is None
        and not has_av1_override
        and not has_vp9_override
        and not has_tmdb_enabled
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "At least one field (name, root_paths, codec override, "
                "or tmdb_enabled) must be provided"
            ),
        )
    if body.name is not None and not body.name.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="name cannot be empty",
        )
    if body.root_paths is not None and len(body.root_paths) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="root_paths cannot be empty",
        )
    row = await library_service.update_library(
        db,
        library_id,
        name=body.name,
        root_paths=body.root_paths,
        av1_stream_copy_override=(
            body.av1_stream_copy_override if has_av1_override else _UNSET
        ),
        vp9_stream_copy_override=(
            body.vp9_stream_copy_override if has_vp9_override else _UNSET
        ),
        tmdb_enabled=(body.tmdb_enabled if has_tmdb_enabled else _UNSET),
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Library not found"
        )
    try:
        await activity_service.record(
            db,
            type="library.update",
            summary=f"Library '{row['name']}' updated",
            actor_kind="client" if _client else "operator",
            actor_id=_client["id"] if _client else None,
            target_kind="library",
            target_id=library_id,
            payload={
                "renamed": body.name is not None,
                "roots_changed": body.root_paths is not None,
            },
        )
    except Exception:
        logger.warning("Failed to record library.update activity event", exc_info=True)
    notification_service.broadcast_event("library_changed")
    return _parse_library(row)


@router.delete("/{library_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_library(
    library_id: str,
    delete_sidecars: bool = Query(default=True),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> None:
    # Capture the library name before delete so the audit summary is
    # human-readable instead of just an opaque id.
    existing = await library_service.get_library(db, library_id)
    # Plan 19 §M8 — `delete_sidecars=true` (default) unlinks the H.264
    # transcoded sidecars produced for this library before the row +
    # CASCADE drops.  Operators with a separate cache mount that they
    # plan to reattach to a renamed library can pass `false` to
    # preserve the on-disk files.
    deleted = await library_service.delete_library(
        db, library_id, delete_sidecars=delete_sidecars
    )
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Library not found"
        )
    try:
        name = existing["name"] if existing else library_id
        await activity_service.record(
            db,
            type="library.delete",
            summary=f"Library '{name}' deleted",
            actor_kind="client" if _client else "operator",
            actor_id=_client["id"] if _client else None,
            target_kind="library",
            target_id=library_id,
        )
    except Exception:
        logger.warning("Failed to record library.delete activity event", exc_info=True)
    # Delete also frees disk (and removes sidecars when delete_sidecars=True)
    # so storage breakdown changes too.
    notification_service.broadcast_event("library_changed")
    notification_service.broadcast_event("storage_changed")


@router.post("/{library_id}/scan", status_code=status.HTTP_200_OK)
async def scan_library(
    library_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    row = await library_service.get_library(db, library_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Library not found"
        )
    try:
        added = await library_service.scan_library(
            db,
            library_id,
            tmdb_api_key=settings.fluxora_tmdb_key or None,
        )
    except Exception:
        logger.error("Scan failed for library %s", library_id, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Scan failed",
        )
    # File counts + storage totals both changed.
    notification_service.broadcast_event("library_changed")
    notification_service.broadcast_event("storage_changed")
    return {"library_id": library_id, "files_added": added}


@router.post("/{library_id}/enrich-tmdb", status_code=status.HTTP_200_OK)
async def enrich_library_tmdb(
    library_id: str,
    include_dvr: bool = False,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    """Re-run TMDB enrichment for files in [library_id] that lack a
    ``tmdb_id``.  Distinct from ``/scan`` (which only enriches newly-
    inserted files) so the operator can fill in metadata gaps after
    pasting the TMDB API key, fixing a typo in a filename, or moving
    files between libraries — all without deleting + re-creating rows
    (which would wipe resume markers + watch history).

    Query param ``include_dvr=true`` bypasses the DVR-filename skip
    heuristic (defaults to false).  Most users leave it off; enable
    only if you know your capture archive's filenames *do* contain
    real titles you want TMDB-searched.

    Returns ``{library_id, matched, enriched, skipped_dvr}``.  No-op
    (returns zeros) when ``FLUXORA_TMDB_KEY`` is not configured.
    """
    row = await library_service.get_library(db, library_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Library not found"
        )
    api_key = settings.fluxora_tmdb_key or None
    if not api_key:
        return {
            "library_id": library_id,
            "matched": 0,
            "enriched": 0,
            "skipped_dvr": 0,
            "detail": "TMDB API key not configured",
        }
    try:
        result = await library_service.enrich_library_tmdb(
            db,
            library_id,
            api_key,
            include_dvr=include_dvr,
        )
    except Exception:
        logger.error(
            "TMDB rescan failed for library %s",
            library_id,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB rescan failed",
        )
    # Posters / titles changed, but file counts didn't — only library_changed.
    notification_service.broadcast_event("library_changed")
    return {"library_id": library_id, **result}


@router.get("/{library_id}/browse", status_code=status.HTTP_200_OK)
async def browse_library(
    library_id: str,
    path: str = Query(default="", description="relative path under the library root"),
    show_hidden: bool = Query(
        default=False,
        description="when True, include dotfiles + Windows hidden attribute "
        "entries in the listing",
    ),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    """Walk the actual filesystem under the library's `root_paths` and
    return an Explorer-style directory listing.  Joins against
    `media_files.path` so each entry carries `is_indexed` +
    (when indexed) `file_id` for client-side smart dispatch.

    Security: the `path` parameter is normalised + path-traversal-
    checked against the canonicalised `root_paths`.  Any escape attempt
    returns 403.  Symlinks are followed once but their resolved
    target must still live under a root.

    Hidden semantics: dotfile names on every platform + Windows
    `FILE_ATTRIBUTE_HIDDEN` / `FILE_ATTRIBUTE_SYSTEM` flags.  Toggle
    via `?show_hidden=true`.

    Response shape: see `services.browse_service.BrowseResponse.to_json`.
    """
    try:
        response = await browse_service.browse_library(
            db,
            library_id=library_id,
            relative_path=path,
            show_hidden=show_hidden,
        )
    except BrowseError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e
    return response.to_json()


@router.get(
    "/{library_id}/folder-size",
    status_code=status.HTTP_200_OK,
)
async def get_folder_size(
    library_id: str,
    path: str = Query(
        default="",
        description="relative path under the library root identifying "
        "the directory to measure (empty = library root)",
    ),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    """Recursively measure a subdirectory's total size + file count.

    Backs the folder-browser right detail panel's "Compute size" button
    (opt-in to avoid surprise CPU/disk IO on huge libraries).  Returns
    ``{library_id, relative_path, size_bytes, file_count}``.

    Path security mirrors `/browse`: 403 on escape, 404 on missing,
    400 when the path resolves to a file.
    """
    try:
        result = await browse_service.folder_size(
            db, library_id=library_id, relative_path=path
        )
    except BrowseError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e
    return {
        "library_id": library_id,
        "relative_path": path,
        **result,
    }


@router.get(
    "/{library_id}/resolve-absolute",
    status_code=status.HTTP_200_OK,
)
async def resolve_absolute_path(
    library_id: str,
    path: str = Query(
        ...,
        description="absolute on-disk path the operator typed into the "
        "desktop URL bar; the server walks every library root and "
        "returns the relative path under the matching one",
    ),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    """Resolve an absolute on-disk path to a library-relative path.

    Backs the desktop folder browser's manual-typing fallback: when
    the URL bar's client-side prefix match against the currently-
    visible root fails (multi-root library, case mismatch, typed
    canonical form differs), the client posts the absolute here and
    walks every configured `library.root_paths`.

    Returns ``{library_id, root_path, relative_path}`` on a match.

    Errors:
        - 404 path doesn't exist OR isn't under any library root
    """
    try:
        matched_root, relative = await browse_service.resolve_absolute_to_relative(
            db, library_id=library_id, absolute_path=path
        )
    except BrowseError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e
    return {
        "library_id": library_id,
        "root_path": str(matched_root),
        "relative_path": relative,
    }


@router.post(
    "/{library_id}/index-file",
    status_code=status.HTTP_200_OK,
)
async def index_single_file(
    library_id: str,
    path: str = Query(
        ...,
        description="relative path under the library root identifying "
        "the file to index",
    ),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    """Index a single file by its `<root>/<relative>` path.

    Used by the desktop folder browser's right-click "Index this file"
    action so the operator can add an unindexed file to the catalog
    without rescanning the whole library.  Returns
    ``{file_id, already_indexed, enriched, queued_thumbnail: True}``.

    Path security: the same containment + canonicalisation checks
    `browse_service.browse_library` uses.  403 on escape; 404 when the
    file or library is missing.  400 for unsupported extensions or
    when the path points at a directory.
    """
    try:
        absolute_path, _kind = await browse_service.resolve_file_for_index(
            db, library_id=library_id, relative_path=path
        )
    except BrowseError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e

    try:
        result = await library_service.index_single_file(
            db,
            library_id=library_id,
            absolute_path=absolute_path,
            tmdb_api_key=settings.fluxora_tmdb_key or None,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        ) from e
    except Exception:
        logger.error(
            "Index single file failed for library %s path %r",
            library_id,
            path,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Index failed",
        )

    if not result["already_indexed"]:
        try:
            await activity_service.record(
                db,
                type="file.indexed",
                summary=f"Indexed {absolute_path.name}",
                actor_kind="operator" if _client is None else "client",
                actor_id=_client["id"] if _client else None,
                target_kind="file",
                target_id=result["file_id"],
                payload={"library_id": library_id},
            )
        except Exception:
            logger.warning(
                "Failed to record file.indexed activity event",
                exc_info=True,
            )
        notification_service.broadcast_event("library_changed")
        notification_service.broadcast_event("storage_changed")

    return {
        "file_id": result["file_id"],
        "already_indexed": result["already_indexed"],
        "enriched": result["enriched"],
        "queued_thumbnail": True,
    }


@router.post(
    "/{library_id}/scan-subtree",
    status_code=status.HTTP_200_OK,
)
async def scan_subtree(
    library_id: str,
    path: str = Query(
        ...,
        description="relative path under the library root identifying "
        "the directory to rescan",
    ),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    """Rescan a single subtree under one of the library's `root_paths`.

    Used by the desktop folder browser's right-click "Scan this folder"
    action so the operator can pick up newly-added files in a single
    directory without paying for a full library walk.  Returns
    ``{library_id, files_added}``.

    Path security mirrors `/browse`: 403 on escape, 404 on missing,
    400 when the path resolves to a file.
    """
    try:
        absolute_dir = await browse_service.resolve_subtree_for_scan(
            db, library_id=library_id, relative_path=path
        )
    except BrowseError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e

    try:
        added = await library_service.scan_library(
            db,
            library_id,
            tmdb_api_key=settings.fluxora_tmdb_key or None,
            subtree_abs=str(absolute_dir),
        )
    except Exception:
        logger.error(
            "Subtree scan failed for library %s path %r",
            library_id,
            path,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Scan failed",
        )

    notification_service.broadcast_event("library_changed")
    notification_service.broadcast_event("storage_changed")
    return {"library_id": library_id, "files_added": added}


@router.post(
    "/{library_id}/unindex-subtree",
    status_code=status.HTTP_200_OK,
)
async def unindex_subtree(
    library_id: str,
    path: str = Query(
        ...,
        description="relative path under the library root identifying "
        "the directory whose indexed files should be removed from the "
        "catalog; files on disk are NOT deleted",
    ),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    """Remove every `media_files` row under the given subtree.

    Cascades to `media_thumbnails` / `transcode_jobs` / etc. via the
    schema's `ON DELETE CASCADE` foreign keys.  Files on disk stay
    where they are — this is the inverse of "Scan this folder," not
    a destructive disk operation.

    Returns ``{library_id, files_removed}``.  Path security mirrors
    `/browse`: 403 on escape, 404 on missing, 400 when the path
    resolves to a file.
    """
    try:
        absolute_dir = await browse_service.resolve_subtree_for_scan(
            db, library_id=library_id, relative_path=path
        )
    except BrowseError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e

    try:
        removed = await library_service.unindex_subtree(
            db,
            library_id=library_id,
            subtree_abs=absolute_dir,
        )
    except Exception:
        logger.error(
            "Subtree unindex failed for library %s path %r",
            library_id,
            path,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unindex failed",
        )

    if removed:
        notification_service.broadcast_event("library_changed")
        notification_service.broadcast_event("storage_changed")
    return {"library_id": library_id, "files_removed": removed}


@router.post(
    "/{library_id}/regenerate-thumbnails",
    status_code=status.HTTP_200_OK,
)
async def regenerate_library_thumbnails(
    library_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    """Reset every thumbnail row for files in ``library_id`` to pending.

    Deletes the cached JPEGs on disk so the background worker
    re-renders them at current settings (width, HDR tonemap, etc).
    Useful after the operator changes ``thumbnail_width`` in Settings
    → Advanced or after fixing a transient extraction failure.

    Returns ``{library_id, queued}`` — the count of files queued for
    regeneration.  Records a ``library.thumbnails_regenerated``
    activity event.

    Plan 27 M3.
    """
    row = await library_service.get_library(db, library_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Library not found"
        )

    try:
        queued = await thumbnail_worker.regenerate_library(db, library_id)
    except Exception:
        logger.error(
            "Thumbnail regeneration failed for library %s",
            library_id,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Thumbnail regeneration failed",
        )

    if queued > 0:
        try:
            await activity_service.record(
                db,
                type="library.thumbnails_regenerated",
                summary=f"Regenerated thumbnails for {queued} file(s)",
                actor_kind="operator" if _client is None else "client",
                actor_id=_client["id"] if _client else None,
                target_kind="library",
                target_id=library_id,
                payload={"queued": queued},
            )
        except Exception:
            logger.warning(
                "Failed to record library.thumbnails_regenerated event",
                exc_info=True,
            )

    return {"library_id": library_id, "queued": queued}
