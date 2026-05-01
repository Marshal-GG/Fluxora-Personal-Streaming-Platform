import logging
import uuid
from datetime import UTC, datetime
from pathlib import Path

import aiosqlite
from fastapi import APIRouter, Body, Depends, HTTPException, Request, status
from fastapi.responses import FileResponse
from fastapi.security import HTTPAuthorizationCredentials
from slowapi import Limiter
from slowapi.util import get_remote_address

from config import settings
from database.db import get_db
from models.stream_session import StreamSessionResponse, StreamStartResponse
from routers.deps import LOOPBACK, bearer, require_local_caller, validate_token
from services import (
    ffmpeg_service,
    group_service,
    library_service,
    notification_service,
    settings_service,
)

logger = logging.getLogger(__name__)

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)


# ── GET /api/v1/stream/sessions ─────────────────────────────────────────────


@router.get("/sessions", response_model=list[StreamSessionResponse])
async def list_sessions(
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> list[StreamSessionResponse]:
    """List all active stream sessions (Admin/Local only)."""
    async with db.execute(
        "SELECT * FROM stream_sessions WHERE ended_at IS NULL ORDER BY started_at DESC"
    ) as cur:
        rows = await cur.fetchall()
    return [StreamSessionResponse(**dict(r)) for r in rows]


def _playlist_url(request: Request, session_id: str) -> str:
    base = str(request.base_url).rstrip("/")
    return f"{base}/api/v1/hls/{session_id}/playlist.m3u8"


# ── POST /api/v1/stream/start/{file_id} ─────────────────────────────────────


@router.post(
    "/start/{file_id}",
    response_model=StreamStartResponse,
    status_code=status.HTTP_201_CREATED,
)
@limiter.limit("10/minute")
async def start_stream(
    file_id: str,
    request: Request,
    db: aiosqlite.Connection = Depends(get_db),
    client: aiosqlite.Row = Depends(validate_token),
) -> StreamStartResponse:
    file_row = await library_service.get_file(db, file_id)
    if file_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )

    # Enforce group restrictions (allowed libraries / time window).
    # Bandwidth cap and max-rating are advisory in v1.
    restrictions = await group_service.get_effective_restrictions(db, client["id"])
    deny_reason = group_service.reason_to_deny(
        restrictions, library_id=file_row.get("library_id")
    )
    if deny_reason:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=deny_reason)

    # Enforce tier-aware stream concurrency limit (reads from user_settings DB row)
    max_streams = await settings_service.get_max_concurrent_streams(db)
    async with db.execute(
        "SELECT COUNT(*) FROM stream_sessions WHERE client_id = ? AND ended_at IS NULL",
        (client["id"],),
    ) as cur:
        row = await cur.fetchone()
    if row and row[0] >= max_streams:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Stream concurrency limit reached",
        )

    session_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()

    try:
        await ffmpeg_service.start_stream(
            file_row["path"], session_id, settings.hls_tmp_path
        )
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except Exception:
        logger.error("FFmpeg failed to start: session=%s", session_id, exc_info=True)
        try:
            await notification_service.create(
                db,
                type="error",
                category="transcode",
                title="Transcode failed",
                message=f"Could not start playback for {file_row['name']}.",
                related_kind="session",
                related_id=session_id,
            )
        except Exception:
            logger.warning("Failed to emit transcode notification", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Transcoding service unavailable",
        )

    await db.execute(
        """
        INSERT INTO stream_sessions
            (id, file_id, client_id, started_at, connection_type)
        VALUES (?, ?, ?, ?, 'lan')
        """,
        (session_id, file_id, client["id"], now),
    )
    await db.commit()

    return StreamStartResponse(
        session_id=session_id,
        file_id=file_id,
        playlist_url=_playlist_url(request, session_id),
        resume_sec=file_row.get("last_progress_sec") or 0.0,
    )


# ── PATCH /api/v1/stream/{session_id}/progress ───────────────────────────────


@router.patch("/{session_id}/progress", status_code=status.HTTP_204_NO_CONTENT)
async def update_progress(
    session_id: str,
    progress_sec: float = Body(..., embed=True),
    db: aiosqlite.Connection = Depends(get_db),
    client: aiosqlite.Row = Depends(validate_token),
) -> None:
    """Record the client's current playback position for resume-on-reopen."""
    async with db.execute(
        """
        SELECT id, client_id, file_id
        FROM stream_sessions
        WHERE id = ? AND ended_at IS NULL
        """,
        (session_id,),
    ) as cur:
        row = await cur.fetchone()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
        )
    if row["client_id"] != client["id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not your session"
        )

    now = datetime.now(UTC).isoformat()
    # Persist to stream_sessions (live value) and media_files (resume marker)
    await db.execute(
        "UPDATE stream_sessions SET progress_sec = ? WHERE id = ?",
        (progress_sec, session_id),
    )
    await db.execute(
        "UPDATE media_files SET last_progress_sec = ?, updated_at = ? WHERE id = ?",
        (progress_sec, now, row["file_id"]),
    )
    await db.commit()


# ── DELETE /api/v1/stream/{session_id} ──────────────────────────────────────


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def stop_stream(
    session_id: str,
    request: Request,
    db: aiosqlite.Connection = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> None:
    async with db.execute(
        "SELECT id, client_id FROM stream_sessions WHERE id = ? AND ended_at IS NULL",
        (session_id,),
    ) as cur:
        row = await cur.fetchone()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
        )

    host = request.client.host if request.client else "127.0.0.1"
    if host not in LOOPBACK:
        # Not a local admin, must be a valid client and own the session
        client = await validate_token(credentials, db)
        if row["client_id"] != client["id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not your session",
            )

    await ffmpeg_service.stop_stream(session_id)
    ffmpeg_service.cleanup_session_dir(session_id, settings.hls_tmp_path)

    now = datetime.now(UTC).isoformat()
    await db.execute(
        "UPDATE stream_sessions SET ended_at = ? WHERE id = ?",
        (now, session_id),
    )
    await db.commit()


# ── GET /api/v1/stream/{session_id} ─────────────────────────────────────────


@router.get("/{session_id}", response_model=StreamSessionResponse)
async def get_session(
    session_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    client: aiosqlite.Row = Depends(validate_token),
) -> StreamSessionResponse:
    async with db.execute(
        "SELECT * FROM stream_sessions WHERE id = ? AND client_id = ?",
        (session_id, client["id"]),
    ) as cur:
        row = await cur.fetchone()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
        )
    return StreamSessionResponse(**dict(row))


# ── HLS file serving ─────────────────────────────────────────────────────────
# Mounted at /api/v1/hls via main.py

hls_router = APIRouter()


@hls_router.get("/{session_id}/{filename}", include_in_schema=False)
async def serve_hls(
    session_id: str,
    filename: str,
    db: aiosqlite.Connection = Depends(get_db),
    client: aiosqlite.Row = Depends(validate_token),
) -> FileResponse:
    # 1. Verify session ownership to prevent cross-client hijacking
    async with db.execute(
        "SELECT client_id FROM stream_sessions WHERE id = ? AND ended_at IS NULL",
        (session_id,),
    ) as cur:
        row = await cur.fetchone()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
        )
    if row["client_id"] != client["id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied to this session",
        )

    # 2. Path traversal guard — filename must not escape the session directory
    if ".." in filename or "/" in filename or "\\" in filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid filename"
        )

    session_dir: Path = settings.hls_tmp_path / session_id
    file_path = session_dir / filename

    # Canonicalise and verify the resolved path is inside the session dir
    try:
        resolved = file_path.resolve()
        base_resolved = session_dir.resolve()
        resolved.relative_to(base_resolved)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )

    if not resolved.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Segment not found"
        )

    if filename.endswith(".m3u8"):
        media_type = "application/vnd.apple.mpegurl"
    else:
        media_type = "video/MP2T"

    return FileResponse(str(resolved), media_type=media_type)
