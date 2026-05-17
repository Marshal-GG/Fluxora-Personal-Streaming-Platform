import logging
import mimetypes
import os
from datetime import UTC
from pathlib import Path

import aiosqlite
from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse

from config import get_data_dir, settings
from database.db import get_db
from models.media_file import MediaFileResponse
from routers.deps import require_local_caller, validate_token_or_local
from services import activity_service, group_service, library_service, thumbnail_worker

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post(
    "/upload",
    response_model=MediaFileResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_file(
    library_id: str = Form(...),
    file: UploadFile = File(...),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> MediaFileResponse:
    try:
        row = await library_service.upload_file_to_library(
            db=db,
            library_id=library_id,
            file=file,
            tmdb_api_key=settings.fluxora_tmdb_key or None,
        )
        try:
            await activity_service.record(
                db,
                type="file.upload",
                summary=f"Uploaded {row.get('name', 'file')} to library",
                actor_kind="client" if _client else "operator",
                actor_id=_client["id"] if _client else None,
                target_kind="file",
                target_id=row.get("id"),
                payload={
                    "library_id": library_id,
                    "size_bytes": row.get("size_bytes"),
                },
            )
        except Exception:
            logger.warning("Failed to record file.upload activity event", exc_info=True)
        return MediaFileResponse(**row)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception:
        logger.error("Failed to upload file to library %s", library_id, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to upload file",
        )


@router.get("", response_model=list[MediaFileResponse])
async def list_files(
    library_id: str | None = Query(default=None),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[MediaFileResponse]:
    """List media files, optionally filtered to one library.

    Bearer-token callers (paired clients) see only files in libraries
    their group memberships expose — v2 content-spaces visibility model.
    When `library_id` is supplied AND the library is not in the caller's
    visible set, return 403 (operator-supplied id; honest deny).  When no
    `library_id` is supplied, the result is filtered to the caller's
    visible libraries.  Localhost callers (operator's desktop CP) skip
    the filter entirely.
    """
    if _client is not None:
        visible = await group_service.get_visible_libraries(db, _client["id"])
        if library_id is not None and library_id not in visible.library_ids:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Library not allowed for this client's group(s)",
            )
        rows = await library_service.list_files(db, library_id=library_id)
        # Files with NULL library_id (orphan uploads, pre-library-system
        # rows) are unconditionally visible — they can't be group-gated
        # by definition.  Same v1 behaviour.
        result = [
            MediaFileResponse(**row)
            for row in rows
            if row["library_id"] is None or row["library_id"] in visible.library_ids
        ]
    else:
        rows = await library_service.list_files(db, library_id=library_id)
        result = [MediaFileResponse(**row) for row in rows]
    # Per-library priority boost (plan 27): operator opening a library
    # bumps that library's pending thumbnails to the front of the worker
    # queue.  Best-effort — never fails the request.
    if library_id is not None:
        try:
            boosted = await thumbnail_worker.boost_library(db, library_id)
            if boosted:
                logger.debug(
                    "Boosted %d pending thumbnails for library=%s",
                    boosted,
                    library_id,
                )
        except Exception:
            logger.warning(
                "Thumbnail priority boost failed for library=%s",
                library_id,
                exc_info=True,
            )
    return result


@router.get("/recent", response_model=list[MediaFileResponse])
async def list_recent_files(
    limit: int = Query(default=20, ge=1, le=50),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[MediaFileResponse]:
    """Most-recently-added media files — backs the mobile Home "Recently
    added" rail (Phase A backfill plan §9.1).  Sorted by `created_at DESC`.
    Route is registered before `/{file_id}` so FastAPI does not treat
    "recent" as a literal id.

    Bearer-token callers see only files from libraries their groups
    expose; localhost skips the filter.
    """
    rows = await library_service.list_recent_files(db, limit=limit)
    if _client is not None:
        visible = await group_service.get_visible_libraries(db, _client["id"])
        rows = [
            r
            for r in rows
            if r["library_id"] is None or r["library_id"] in visible.library_ids
        ]
    return [MediaFileResponse(**row) for row in rows]


@router.get("/search", response_model=list[MediaFileResponse])
async def search_files(
    q: str = Query(..., min_length=1, max_length=200),
    limit: int = Query(default=20, ge=1, le=50),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[MediaFileResponse]:
    """Search media files by `name` + TMDB `title` (case-insensitive
    substring match).  Backs the mobile Search tab (Phase B backfill plan
    §3 row 2).  v1 uses SQL `LIKE` per decision §5 row 1 — FTS5 is the
    v2 swap-in.  `q` is required; `limit` clamped to `[1, 50]`.

    Bearer-token callers see only files from libraries their groups
    expose; localhost skips the filter.
    """
    rows = await library_service.search_files(db, query=q, limit=limit)
    if _client is not None:
        visible = await group_service.get_visible_libraries(db, _client["id"])
        rows = [
            r
            for r in rows
            if r["library_id"] is None or r["library_id"] in visible.library_ids
        ]
    return [MediaFileResponse(**row) for row in rows]


@router.get("/{file_id}/content")
async def get_file_content(
    file_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> FileResponse:
    """Serve the raw bytes of a media file.

    Backs the M11 beyond-video viewers (PDF, photo, music) that load the
    file as a network source, and the "Open in..." action that downloads
    it to a temp path on the device before handing it off to the OS.

    Group visibility applies: bearer-token callers receive 404 (not 403)
    when the file's library is outside their content space — matching
    the existing get_file behaviour to prevent enumeration of gated content.
    Localhost skips the filter.
    """
    row = await library_service.get_file(db, file_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )
    if _client is not None and row["library_id"] is not None:
        visible = await group_service.get_visible_libraries(db, _client["id"])
        if row["library_id"] not in visible.library_ids:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
            )
    path: str = row["path"]
    if not os.path.isfile(path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File not found on disk",
        )
    media_type, _ = mimetypes.guess_type(path)
    return FileResponse(
        path=path,
        media_type=media_type or "application/octet-stream",
        filename=row["name"],
    )


@router.get("/{file_id}/thumbnail")
async def get_thumbnail(
    file_id: str,
    v: str | None = Query(default=None),  # cache-buster; intentionally unused
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> FileResponse:
    """Serve the cached JPEG thumbnail.  404 when not yet generated.

    The `v` query parameter is accepted but ignored — it exists only
    to make the URL unique per generation so client image caches
    invalidate when a thumbnail is regenerated.  See
    ``library_service._library_aggregates`` for where the suffix gets
    stamped onto cover_urls.

    Group visibility applies: bearer-token callers receive 404 (not
    403) when the file's library is outside their content space —
    matches ``get_file`` / ``get_file_content`` behaviour to prevent
    enumeration of gated content.  Localhost skips the filter.

    Plan 27.
    """
    # Visibility check before disclosing whether the thumbnail row exists.
    row = await library_service.get_file(db, file_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )
    if _client is not None and row["library_id"] is not None:
        visible = await group_service.get_visible_libraries(db, _client["id"])
        if row["library_id"] not in visible.library_ids:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
            )

    async with db.execute(
        "SELECT status FROM media_thumbnails WHERE file_id = ?",
        (file_id,),
    ) as cur:
        thumb_row = await cur.fetchone()
    if thumb_row is None or thumb_row["status"] != "ready":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="thumbnail not ready",
        )

    jpeg_path = get_data_dir() / "thumbnails" / f"{file_id}.jpg"
    if not jpeg_path.exists():
        # Row says ready but the file is gone — log + 404.  Worker can
        # re-queue on the operator's next regenerate sweep.
        logger.warning("Thumbnail row=ready but file missing: %s", jpeg_path)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="thumbnail file missing",
        )

    return FileResponse(
        path=str(jpeg_path),
        media_type="image/jpeg",
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.post("/{file_id}/stream-test", status_code=status.HTTP_200_OK)
async def stream_test(
    file_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _: None = Depends(require_local_caller),
) -> dict:
    """Dry-run sanity check for the operator-facing "Stream test" affordance.

    Verifies the file is reachable on disk + reports the codec + the
    playback path that `/stream/start` would route through (the H.264
    sidecar from plan 18 wins over the source when present + on disk).
    Does NOT spawn FFmpeg, does NOT INSERT a `stream_sessions` row, does
    NOT require a bearer token.  Localhost-only because it bypasses the
    group-visibility gate that bearer-token callers go through —
    operators on the desktop have full access to every library; remote
    clients shouldn't be able to probe arbitrary file ids.

    Returns:
        ``{file_id, playback_path, codec, audio_codec, would_use_sidecar,
        ok: True}`` on success.

    Errors:
        - 404 file not found in catalog
        - 404 file (or its sidecar) missing on disk — surfaces a clear
          message so the operator knows whether to re-scan / re-locate
          the source or to retry plan-18 transcoding.
    """
    file_row = await library_service.get_file(db, file_id)
    if file_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )

    # Mirror `start_stream`'s playback-path resolution so the operator
    # tests the *exact* file that would be served — when a plan-18
    # H.264 sidecar exists, that's what plays, not the original AV1/VP9
    # source.  Falls back to the source if the sidecar row is set but
    # the on-disk file has been deleted / moved.
    sidecar_path = file_row.get("transcoded_path")
    using_sidecar = bool(sidecar_path) and Path(sidecar_path).exists()
    playback_path = sidecar_path if using_sidecar else file_row["path"]

    if not Path(playback_path).is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=(
                "Source file missing on disk"
                if not using_sidecar
                else "Transcoded sidecar missing on disk"
            ),
        )

    # Pull cached codec from the scan-populated columns; null when the
    # file is a non-probeable kind (PDF / EPUB / etc.) — operator sees
    # the codec slot empty in the toast which is the correct signal.
    audio_codec: str | None = None
    raw_tracks = file_row.get("audio_tracks")
    if raw_tracks:
        import json

        try:
            parsed = json.loads(raw_tracks)
            if isinstance(parsed, list) and parsed:
                first = parsed[0]
                if isinstance(first, dict):
                    codec_val = first.get("codec")
                    if isinstance(codec_val, str):
                        audio_codec = codec_val
        except (TypeError, ValueError):
            audio_codec = None

    return {
        "file_id": file_id,
        "playback_path": playback_path,
        "codec": file_row.get("codec_name"),
        "audio_codec": audio_codec,
        "would_use_sidecar": using_sidecar,
        "ok": True,
    }


@router.get("/{file_id}", response_model=MediaFileResponse)
async def get_file(
    file_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> MediaFileResponse:
    """Fetch a single file's metadata.

    Bearer-token callers receive 404 (not 403) when the file lives in
    a library their groups don't expose — we don't even confirm the
    file exists, to prevent enumeration of gated content via id-guessing.
    Localhost skips the filter.
    """
    row = await library_service.get_file(db, file_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )
    if _client is not None and row["library_id"] is not None:
        visible = await group_service.get_visible_libraries(db, _client["id"])
        if row["library_id"] not in visible.library_ids:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="File not found",
            )
    return MediaFileResponse(**row)


@router.post(
    "/{file_id}/reset-progress",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def reset_progress(
    file_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> None:
    """Reset `last_progress_sec` to 0 for the given file.

    Backs the "Start over" affordance on file detail screens (streaming
    pipeline plan §4.10).  Use case: a user finished a movie (so it
    dropped out of Continue Watching at the 95 % cutoff), and now wants
    to re-watch it from the beginning without manually scrubbing back to
    0:00 once playback starts.

    Bearer-token callers receive 404 (not 403) when the file lives in
    a library their groups don't expose — matching the get-file route
    so progress-reset can't be used to enumerate gated content.
    Localhost skips the visibility filter.
    """
    row = await library_service.get_file(db, file_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )
    if _client is not None and row["library_id"] is not None:
        visible = await group_service.get_visible_libraries(db, _client["id"])
        if row["library_id"] not in visible.library_ids:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="File not found",
            )

    from datetime import datetime

    now = datetime.now(UTC).isoformat()
    await db.execute(
        "UPDATE media_files SET last_progress_sec = 0, updated_at = ?" " WHERE id = ?",
        (now, file_id),
    )
    await db.commit()


@router.post(
    "/{file_id}/regenerate-thumbnail",
    status_code=status.HTTP_200_OK,
)
async def regenerate_file_thumbnail(
    file_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    """Reset a single file's thumbnail to pending + priority=10.

    Backs the right-click "Generate thumbnail" action for indexed files
    whose current thumbnail is failed / stale / pending.  Worker picks
    up the reset row on its next tick.

    Bearer-token callers receive 404 (not 403) when the file's library
    is outside their content space — matches `get_thumbnail` /
    `get_file_content` so the regenerate action can't be used to
    enumerate gated content.  Localhost skips the visibility filter.

    Returns ``{file_id, status: 'pending'}``.
    """
    row = await library_service.get_file(db, file_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )
    if _client is not None and row["library_id"] is not None:
        visible = await group_service.get_visible_libraries(db, _client["id"])
        if row["library_id"] not in visible.library_ids:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
            )

    try:
        ok = await thumbnail_worker.regenerate_file(db, file_id)
    except Exception:
        logger.error(
            "Per-file thumbnail regenerate failed for %s",
            file_id,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Thumbnail regeneration failed",
        )
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )

    try:
        await activity_service.record(
            db,
            type="file.thumbnail_regenerated",
            summary=f"Regenerated thumbnail for {row.get('name', file_id)}",
            actor_kind="operator" if _client is None else "client",
            actor_id=_client["id"] if _client else None,
            target_kind="file",
            target_id=file_id,
        )
    except Exception:
        logger.warning(
            "Failed to record file.thumbnail_regenerated event",
            exc_info=True,
        )

    return {"file_id": file_id, "status": "pending"}


@router.delete("/{file_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_file(
    file_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> None:
    # Capture the file name before delete so the audit summary is
    # human-readable instead of just an opaque id.
    existing = await library_service.get_file(db, file_id)
    deleted = await library_service.delete_file(db, file_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )
    try:
        name = existing["name"] if existing else file_id
        await activity_service.record(
            db,
            type="file.delete",
            summary=f"File '{name}' deleted",
            actor_kind="client" if _client else "operator",
            actor_id=_client["id"] if _client else None,
            target_kind="file",
            target_id=file_id,
        )
    except Exception:
        logger.warning("Failed to record file.delete activity event", exc_info=True)
