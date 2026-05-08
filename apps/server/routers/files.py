import logging
import mimetypes
import os

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

from config import settings
from database.db import get_db
from models.media_file import MediaFileResponse
from routers.deps import validate_token_or_local
from services import activity_service, group_service, library_service

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
        return [
            MediaFileResponse(**row)
            for row in rows
            if row["library_id"] is None
            or row["library_id"] in visible.library_ids
        ]
    rows = await library_service.list_files(db, library_id=library_id)
    return [MediaFileResponse(**row) for row in rows]


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
            r for r in rows
            if r["library_id"] is None
            or r["library_id"] in visible.library_ids
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
            r for r in rows
            if r["library_id"] is None
            or r["library_id"] in visible.library_ids
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

    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).isoformat()
    await db.execute(
        "UPDATE media_files SET last_progress_sec = 0, updated_at = ?"
        " WHERE id = ?",
        (now, file_id),
    )
    await db.commit()


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
