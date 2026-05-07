import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, status

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
from services import activity_service, group_service, library_service

logger = logging.getLogger(__name__)

router = APIRouter()


def _parse_library(row: dict) -> LibraryResponse:
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
        db, name=body.name, lib_type=body.type, root_paths=body.root_paths
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
    if body.name is None and body.root_paths is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one field (name or root_paths) must be provided",
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
    return _parse_library(row)


@router.delete("/{library_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_library(
    library_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> None:
    # Capture the library name before delete so the audit summary is
    # human-readable instead of just an opaque id.
    existing = await library_service.get_library(db, library_id)
    deleted = await library_service.delete_library(db, library_id)
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
            db, library_id, api_key, include_dvr=include_dvr,
        )
    except Exception:
        logger.error(
            "TMDB rescan failed for library %s", library_id, exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB rescan failed",
        )
    return {"library_id": library_id, **result}
