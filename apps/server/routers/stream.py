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
    activity_service,
    ffmpeg_service,
    group_service,
    library_service,
    notification_service,
    session_router,
    settings_service,
)

logger = logging.getLogger(__name__)

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)

# Last-persisted `media_files.last_progress_sec` value per session.
# `update_progress` writes `stream_sessions.progress_sec` every tick
# (transient state, fine to update at any rate) but only writes the
# resume marker on `media_files` once per 30 s of source-time delta.
# The raw 5-second-tick progress polling on N concurrent streams was
# producing N × 12 WAL writes per minute against a single user_settings
# DB row — useful for the initial validation, wasteful in steady state.
# `stop_stream` flushes the final value from `stream_sessions` so
# resume position is exact when the user closes cleanly; the worst-
# case staleness (app killed mid-watch without a clean stop) is the
# debounce interval below.
_PROGRESS_DEBOUNCE_SEC = 30.0
_last_persisted_progress: dict[str, float] = {}


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
    tonemap: bool = False,
    db: aiosqlite.Connection = Depends(get_db),
    client: aiosqlite.Row = Depends(validate_token),
) -> StreamStartResponse:
    """Start an HLS streaming session for ``file_id``.

    Query params:
        tonemap: When ``true`` and the source is HDR (HDR10 / HLG /
            DolbyVision per `media_files.hdr_format`), the server forces
            transcode mode + applies a zscale + Hable tonemap chain to
            convert BT.2020 PQ → BT.709 SDR.  No-op for SDR sources.
            Default ``false`` (preserves the source's HDR bitstream when
            stream-copying).
    """
    file_row = await library_service.get_file(db, file_id)
    if file_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )

    # v2 stream gate (M2 of `docs/10_planning/13_groups_v2_content_spaces.md`):
    # consult `reason_to_deny_stream` which uses the additive content-spaces
    # model + PIN grants.  Returns the most-specific deny reason — time-
    # window message takes priority over the generic library-not-allowed
    # so mobile M5 routes the kid to "Outside playback hours" rather than
    # the generic gate copy.  PIN-locked content denies with the generic
    # message (doesn't leak existence — operator who set up the gate
    # doesn't want a kid probing file ids to discover Adults content).
    deny_reason = await group_service.reason_to_deny_stream(
        db, client["id"], library_id=file_row.get("library_id")
    )
    if deny_reason:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=deny_reason)

    # Dedup: if this client already has an active session for this same
    # file (e.g. a buggy / restarting client posted /start twice), kill
    # the prior FFmpeg + cleanup its session dir + stamp ended_at on
    # the row before spawning a new one.  Otherwise the GPU/CPU usage
    # doubles per re-spin until the prior session's natural lifecycle
    # cleans it up — visible to the user as "every restart makes it
    # slower", reproducible by toggling tonemap rapidly.  The dedup
    # runs *before* the concurrency check below so a legitimate
    # re-start doesn't get rejected for hitting the per-client cap.
    async with db.execute(
        "SELECT id FROM stream_sessions"
        " WHERE client_id = ? AND file_id = ? AND ended_at IS NULL",
        (client["id"], file_id),
    ) as cur:
        prior_rows = await cur.fetchall()
    for prior in prior_rows:
        prior_sid = prior["id"]
        logger.info(
            "Replacing prior active session for same (client, file): "
            "client=%s file=%s prior_session=%s",
            client["id"],
            file_id,
            prior_sid,
        )
        try:
            await ffmpeg_service.stop_stream(prior_sid)
            ffmpeg_service.cleanup_session_dir(prior_sid, settings.hls_tmp_path)
        except Exception:
            logger.warning(
                "Failed to fully tear down prior session %s — continuing",
                prior_sid,
                exc_info=True,
            )
        await db.execute(
            "UPDATE stream_sessions SET ended_at = ? WHERE id = ?",
            (datetime.now(UTC).isoformat(), prior_sid),
        )
        _last_persisted_progress.pop(prior_sid, None)
    if prior_rows:
        await db.commit()

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
            file_row["path"],
            session_id,
            settings.hls_tmp_path,
            tonemap_hdr=tonemap,
        )
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        # ffmpeg_service.start_stream raises RuntimeError with the first
        # non-empty stderr line (or "exit code N" / "no output before
        # timeout") embedded.  Surface that to the client + the
        # notification — without it the operator sees only "Transcoding
        # service unavailable" which doesn't help diagnose missing codecs,
        # bad source files, or driver issues.
        ffmpeg_error = str(exc) or exc.__class__.__name__
        logger.error(
            "FFmpeg failed to start: session=%s error=%s",
            session_id,
            ffmpeg_error,
            exc_info=True,
        )
        try:
            await notification_service.create(
                db,
                type="error",
                category="transcode",
                title="Transcode failed",
                message=(
                    f"Could not start playback for {file_row['name']}: "
                    f"{ffmpeg_error}"
                ),
                related_kind="session",
                related_id=session_id,
            )
        except Exception:
            logger.warning("Failed to emit transcode notification", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"FFmpeg failed: {ffmpeg_error}",
        ) from exc

    # session_router publishes the actual encoder choice (or None if this
    # was a stream-copy session that never invoked an encoder).  Persist
    # it so the active-sessions UI shows what's running per session.
    encoder_used = session_router.get_session_encoder(session_id)
    await db.execute(
        """
        INSERT INTO stream_sessions
            (id, file_id, client_id, started_at, connection_type, encoder_used)
        VALUES (?, ?, ?, ?, 'lan', ?)
        """,
        (session_id, file_id, client["id"], now, encoder_used),
    )
    await db.commit()

    try:
        await activity_service.record(
            db,
            type="stream.start",
            summary=f"{client['name']} started watching {file_row['name']}",
            actor_kind="client",
            actor_id=client["id"],
            target_kind="session",
            target_id=session_id,
            payload={"file_id": file_id, "connection_type": "lan"},
        )
    except Exception:
        logger.warning("Failed to record stream.start activity event", exc_info=True)

    hdr_format = file_row.get("hdr_format")
    return StreamStartResponse(
        session_id=session_id,
        file_id=file_id,
        playlist_url=_playlist_url(request, session_id),
        resume_sec=file_row.get("last_progress_sec") or 0.0,
        hdr_format=hdr_format,
        # `tonemapped` only true when the *source* is HDR AND the
        # operator asked for tonemap.  An SDR file with `tonemap=true`
        # passes through unchanged, so the badge stays off.
        tonemapped=bool(tonemap and hdr_format),
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
    # Always update stream_sessions.progress_sec (transient live value;
    # drives the active-sessions UI on the desktop).  Debounce the
    # resume-marker write on media_files to once per 30 s of source-
    # time delta — see the comment on _PROGRESS_DEBOUNCE_SEC for the
    # WAL-rate motivation.  stop_stream flushes the final value so a
    # clean close ends with exact resume accuracy.
    await db.execute(
        "UPDATE stream_sessions SET progress_sec = ? WHERE id = ?",
        (progress_sec, session_id),
    )
    last = _last_persisted_progress.get(session_id)
    if last is None or abs(progress_sec - last) >= _PROGRESS_DEBOUNCE_SEC:
        await db.execute(
            "UPDATE media_files SET last_progress_sec = ?, updated_at = ?"
            " WHERE id = ?",
            (progress_sec, now, row["file_id"]),
        )
        _last_persisted_progress[session_id] = progress_sec
    await db.commit()


# ── POST /api/v1/stream/{session_id}/seek ───────────────────────────────────


@router.post("/{session_id}/seek", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("30/minute")
async def seek_stream(
    session_id: str,
    request: Request,
    seek_sec: float,
    tonemap: bool = False,
    db: aiosqlite.Connection = Depends(get_db),
    client: aiosqlite.Row = Depends(validate_token),
) -> None:
    """Re-spawn FFmpeg from ``seek_sec`` for an active session.

    The original architecture only encodes from ``t=0``; the static VOD
    playlist + 5 s segment-wait absorb forward seeks within seconds of
    the encoded boundary, but a far-ahead seek lands in territory FFmpeg
    has not produced yet and the player 404s.  This endpoint kills the
    active FFmpeg, wipes the produced segments, and re-spawns with
    ``-ss <seek_sec>`` + ``-start_number <K>`` so the next segment the
    player asks for actually exists.

    The ``tonemap`` query param preserves the current tonemap state of
    the session — the client is expected to forward whatever
    ``tonemapped`` value it received from ``/start`` (or whatever it
    most-recently toggled to via the mobile overflow menu).  Without
    this, a seek would silently revert tonemap to off.

    Returns 204 with no body.  The playlist URL is unchanged; the
    *contents* of ``playlist.m3u8`` change to a new VOD list with
    ``#EXT-X-DISCONTINUITY-SEQUENCE`` bumped and ``#EXT-X-DISCONTINUITY``
    before the first listed segment.  Client must re-open the playlist
    on the same URL to pick up the new contents — for media_kit /
    libmpv, that means calling ``Player.open(Media(url))`` again.
    """
    if seek_sec < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="seek_sec must be non-negative",
        )

    async with db.execute(
        "SELECT id, client_id, file_id FROM stream_sessions"
        " WHERE id = ? AND ended_at IS NULL",
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

    file_row = await library_service.get_file(db, row["file_id"])
    if file_row is None:
        # Session refers to a file that's been deleted between start and
        # this seek.  Treat as gone — there's no useful place to seek to.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Source file no longer exists",
        )

    try:
        await ffmpeg_service.restart_stream(
            file_row["path"],
            session_id,
            settings.hls_tmp_path,
            seek_sec=seek_sec,
            tonemap_hdr=tonemap,
        )
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        ffmpeg_error = str(exc) or exc.__class__.__name__
        logger.error(
            "FFmpeg restart failed: session=%s seek=%.3f error=%s",
            session_id,
            seek_sec,
            ffmpeg_error,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Seek restart failed: {ffmpeg_error}",
        ) from exc


# ── DELETE /api/v1/stream/{session_id} ──────────────────────────────────────


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def stop_stream(
    session_id: str,
    request: Request,
    db: aiosqlite.Connection = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> None:
    async with db.execute(
        "SELECT id, client_id, file_id, progress_sec FROM stream_sessions"
        " WHERE id = ? AND ended_at IS NULL",
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
        client = await validate_token(request, credentials, db)
        if row["client_id"] != client["id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not your session",
            )

    await ffmpeg_service.stop_stream(session_id)
    ffmpeg_service.cleanup_session_dir(session_id, settings.hls_tmp_path)

    now = datetime.now(UTC).isoformat()
    # Flush the final live progress to media_files so resume position
    # is exact on a clean close.  The debounce in update_progress lets
    # writes through every 30 s, so on average the in-memory
    # _last_persisted_progress is up to ~30 s stale.  This statement
    # closes that gap.
    final_progress = row["progress_sec"]
    if final_progress is not None and final_progress > 0:
        await db.execute(
            "UPDATE media_files SET last_progress_sec = ?, updated_at = ?"
            " WHERE id = ?",
            (final_progress, now, row["file_id"]),
        )
    await db.execute(
        "UPDATE stream_sessions SET ended_at = ? WHERE id = ?",
        (now, session_id),
    )
    await db.commit()
    # Drop the in-memory dedup entry — long-running servers shouldn't
    # accumulate one float per ended session indefinitely.
    _last_persisted_progress.pop(session_id, None)

    try:
        await activity_service.record(
            db,
            type="stream.end",
            summary="Session ended",
            actor_kind="client",
            actor_id=row["client_id"],
            target_kind="session",
            target_id=session_id,
        )
    except Exception:
        logger.warning("Failed to record stream.end activity event", exc_info=True)


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

    # When the static VOD playlist (see `_write_static_vod_playlist`) is
    # in use, the player can request segments before FFmpeg has written
    # them — typical when the user seeks ahead of the current encode
    # position.  Wait briefly so a transient miss doesn't surface as a
    # hard error; if FFmpeg genuinely never produces this segment (file
    # ended early, encode failed) we still 404 after the timeout.
    #
    # Worker-pinning budget tightened from 5 s → 2 s on 2026-05-08 (plan
    # §4.3) — the seek-restart pipeline (Commits 2/3, 2026-05-05) shrinks
    # the realistic gap between a player request and the segment landing
    # on disk to sub-second for stream-copy and ~1 s for transcode.
    # Tonemap restarts (≥10 s gap) are bridged client-side by the
    # mobile player's `_SeekingOverlay` + media_kit's 404-retry loop,
    # which together hammer the segment until FFmpeg catches up.  Three
    # concurrent seekers used to chew 15 worker-seconds; now ≤6.
    if not resolved.exists() and (
        filename.startswith("seg") or filename == "init.mp4"
    ):
        import asyncio as _asyncio

        for _ in range(20):  # up to 2 s @ 100 ms
            await _asyncio.sleep(0.1)
            if resolved.exists():
                break

    if not resolved.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Segment not found"
        )

    # Content-Type matters: fmp4 segments + the init segment must be
    # `video/mp4` (or media_kit / Safari refuse to parse them); mpegts
    # segments are `video/MP2T`; the playlist itself is the Apple HLS
    # MIME type.  Mis-typing the init segment in particular causes
    # silent playback failure because the player can't extract the moov.
    if filename.endswith(".m3u8"):
        media_type = "application/vnd.apple.mpegurl"
    elif filename.endswith(".m4s") or filename.endswith(".mp4"):
        media_type = "video/mp4"
    else:
        media_type = "video/MP2T"

    return FileResponse(str(resolved), media_type=media_type)
