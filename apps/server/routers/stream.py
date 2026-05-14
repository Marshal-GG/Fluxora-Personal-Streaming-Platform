import json
import logging
import uuid
from datetime import UTC, datetime
from pathlib import Path

import aiosqlite
from fastapi import APIRouter, Body, Depends, HTTPException, Request, status
from fastapi.responses import FileResponse
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import ValidationError
from slowapi import Limiter
from slowapi.util import get_remote_address

from config import settings
from database.db import get_db
from models.stream_session import (
    AudioTrackInfo,
    AudioTrackSwitchRequest,
    AudioTrackSwitchResponse,
    FallbackAudioTranscodeRequest,
    FallbackAudioTranscodeResponse,
    FallbackTranscodeBody,
    FallbackTranscodeResponse,
    StreamSeekResponse,
    StreamSessionResponse,
    StreamStartResponse,
)
from routers.deps import LOOPBACK, bearer, require_local_caller, validate_token
from services import (
    activity_service,
    client_audio_codec_service,
    client_codec_service,
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
    seek_sec: float | None = None,
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
        seek_sec: Caller-supplied resume position.  When provided, the
            server lands FFmpeg at this offset via ``-ss`` and shifts
            the static VOD playlist's media-sequence accordingly so the
            player's first segment request hits encoded bytes
            immediately.  When **omitted**, the server falls back to
            ``media_files.last_progress_sec`` so a half-watched file
            resumes from where the user left off.  Used by the mobile
            HDR↔SDR toggle which knows the live playhead more precisely
            than the DB's progress-throttled value (settings remediation
            / streaming pipeline plan §16 M1).
    """
    file_row = await library_service.get_file(db, file_id)
    if file_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )

    # Plan 19 §M8 — fetch the library row so per-library codec
    # passthrough overrides reach `ffmpeg_service.start_stream`.  The
    # row is None when the file is detached from any library (legacy
    # data); the resolver falls back cleanly to the global setting.
    library_row: dict | None = None
    if file_row.get("library_id"):
        library_row = await library_service.get_library(db, file_row["library_id"])

    # Library transcode plan (docs/10_planning/18_library_transcode_plan.md):
    # if a pre-transcoded H.264 sidecar exists for this file, route
    # FFmpeg at it instead of the original source.  The sidecar is
    # H.264 + AAC + .mkv by construction so the stream-copy branch in
    # `ffmpeg_service.start_stream` kicks in and segments land instantly
    # — no live software AV1/VP9 decode + NVENC pipeline.
    #
    # Belt-and-braces: when the sidecar row is set but the file has been
    # manually deleted / moved, fall back to the original source and log
    # the orphan so the operator can clean up.
    playback_path = file_row.get("transcoded_path") or file_row["path"]
    using_sidecar = False
    if file_row.get("transcoded_path"):
        if Path(file_row["transcoded_path"]).exists():
            using_sidecar = True
        else:
            logger.warning(
                "Transcoded sidecar missing on disk; falling back to source: %s",
                file_row["transcoded_path"],
            )
            playback_path = file_row["path"]
    # When the sidecar is in play, the FFmpeg input is NOT the same as
    # `file_row["path"]` — the path-based lookups inside `start_stream`
    # (codec resolution + duration for the static VOD playlist) would
    # miss and silently send the already-H.264 sidecar through NVENC.
    # Plan 18 sidecars are H.264 SDR by construction, so override.
    sidecar_codec_override = "h264" if using_sidecar else None
    sidecar_duration_override = (
        float(file_row["duration_sec"])
        if using_sidecar and file_row.get("duration_sec")
        else None
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

    # Resolve resume position.  Caller-supplied `seek_sec` wins (mobile
    # HDR-toggle path knows the live playhead); falls back to
    # `last_progress_sec` so a half-watched file resumes from where the
    # user left off.  Validate before passing to FFmpeg — negative values
    # would trip `-ss <T>`'s undefined behaviour, and seeking past EOF
    # would produce a static VOD playlist with zero segments listed and
    # break the player.
    duration_sec = float(file_row.get("duration_sec") or 0.0)
    if seek_sec is not None:
        if seek_sec < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="seek_sec must be non-negative",
            )
        if duration_sec > 0 and seek_sec >= duration_sec:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"seek_sec ({seek_sec:.2f}) must be less than the "
                    f"file's duration ({duration_sec:.2f}s)"
                ),
            )
        resolved_seek_sec = float(seek_sec)
    else:
        resolved_seek_sec = float(file_row.get("last_progress_sec") or 0.0)

    session_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()

    # Plan 20 — consult the per-(client, source codec) blocklist before
    # spawning, but only when the operator is on `streaming_mode='auto'`.
    # The blocklist is the persistent record of "this client previously
    # asked us to fall back for this codec".  Strict `client-decode` and
    # `server-transcode` modes are documented as deterministic — the
    # operator's pick wins, blocklist is ignored.
    settings_row = await settings_service.get_settings(db)
    effective_mode = settings_row.get("streaming_mode") or "client-decode"
    if effective_mode == "auto":
        if using_sidecar:
            source_codec_for_blocklist: str | None = "h264"
        else:
            source_codec_for_blocklist = file_row.get("codec_name")
        if source_codec_for_blocklist and await client_codec_service.is_blocked(
            db, client["id"], source_codec_for_blocklist
        ):
            logger.info(
                "client-codec blocklist hit: client=%s codec=%s — "
                "forcing transcode for session=%s",
                client["id"],
                source_codec_for_blocklist,
                session_id,
            )
            ffmpeg_service.set_session_force_transcode(session_id, True)

    # Plan 21 — audio-codec blocklist consult.  Independent of the video
    # blocklist above: a session can hit one, the other, both, or neither.
    # When the (client_id, normalized_audio_codec) pair has fired the
    # audio-only fallback before, pre-arm the per-session audio-force
    # flag so this session starts with audio re-encoded while video
    # keeps stream-copying.  Only fires under `streaming_mode='auto'`;
    # strict modes are documented as deterministic.
    #
    # Best-effort probe — ffprobe may be unavailable or the source may
    # have no audio stream; in either case ``audio_info`` is None and
    # the blocklist consult skips harmlessly (``is_blocked`` short-
    # circuits on a falsy codec).  We also stash the probed codec so
    # the response payload's ``audio_streaming_mode`` field can be
    # computed deterministically below — no second probe needed.
    source_audio_codec: str | None = None
    try:
        audio_info = await ffmpeg_service._probe_audio_params(playback_path)
        if audio_info is not None:
            source_audio_codec = audio_info.get("codec_name")
    except Exception:
        logger.debug(
            "router audio probe failed for %s — proceeding without audio codec",
            playback_path,
            exc_info=True,
        )
    if effective_mode == "auto":
        audio_codec_norm = (source_audio_codec or "").split("_")[0].lower()
        if audio_codec_norm and await client_audio_codec_service.is_blocked(
            db, client["id"], audio_codec_norm
        ):
            logger.info(
                "client-audio-codec blocklist hit: client=%s audio_codec=%s — "
                "forcing audio re-encode for session=%s",
                client["id"],
                audio_codec_norm,
                session_id,
            )
            ffmpeg_service.set_session_force_audio_transcode(session_id, True)

    try:
        await ffmpeg_service.start_stream(
            playback_path,
            session_id,
            settings.hls_tmp_path,
            tonemap_hdr=tonemap,
            seek_sec=resolved_seek_sec,
            source_codec_override=sidecar_codec_override,
            duration_sec_override=sidecar_duration_override,
            library_row=library_row,
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
    # Pull the segment-snapped seek value FFmpeg actually applied (it's
    # `floor(resolved_seek_sec / hls_time) * hls_time`).  The mobile
    # cubit uses this as ``_playlistOffsetSec`` to display source-time on
    # the scrubber instead of playlist-time (streaming pipeline plan §16
    # scrubber-offset patch 2026-05-08).  Falls back to the requested
    # value if the dict is empty (shouldn't happen post-start but defensive).
    applied_seek_sec = ffmpeg_service._applied_seek_sec.get(
        session_id, resolved_seek_sec
    )

    # Plan 21 — compute the audio pipeline the server picked for this
    # session by re-evaluating ``_resolve_audio_passthrough`` with the
    # same inputs FFmpeg used (probed source audio codec + the
    # effective tonemap-applied flag + the per-session audio-force
    # flag).  The resolver is a pure function; the router's re-call
    # matches the decision ``start_stream`` made internally without
    # adding a getter to ffmpeg_service.  Defaults to ``"transcode"``
    # when the probe missed — matches the safe default in the response
    # model and aligns with the audio re-encode path the cmd builder
    # falls through to when ``source_audio_codec`` is None.
    apply_hdr_tonemap = bool(tonemap and hdr_format)
    audio_passthrough = ffmpeg_service._resolve_audio_passthrough(
        apply_hdr_tonemap=apply_hdr_tonemap,
        source_audio_codec=source_audio_codec,
        session_id=session_id,
    )
    audio_streaming_mode = "stream-copy" if audio_passthrough else "transcode"

    # Plan 22 — assemble the per-track list the mobile Audio sheet will
    # render.  Lookup priority:
    #   1. Per-session cache populated by ``ffmpeg_service.start_stream``
    #      via ``_probe_audio_tracks``.  Fast, authoritative for the
    #      in-flight session, and survives the FFmpeg cmd build that
    #      just completed above.
    #   2. ``media_files.audio_tracks`` JSON column (M2 backfill) when
    #      the cache miss returns ``[]``.  Matters for code paths where
    #      the cache may have been cleared between start and response
    #      (e.g. plan 16 seek-restart re-entering ``start_stream``) and
    #      for the row-was-scanned-then-server-restarted case.  JSON
    #      parse failure is treated as a missing column — playback
    #      doesn't block on a corrupt row.
    #   3. ``[]`` — both miss → mobile renders no picker (pre-plan-22
    #      servers returned no field at all; the empty default preserves
    #      that UX path).
    raw_tracks: list = ffmpeg_service._session_audio_tracks.get(session_id, [])
    if not raw_tracks:
        db_audio_tracks = file_row.get("audio_tracks")
        if db_audio_tracks:
            try:
                parsed = json.loads(db_audio_tracks)
                if isinstance(parsed, list):
                    raw_tracks = parsed
            except (json.JSONDecodeError, TypeError):
                logger.debug(
                    "Failed to parse media_files.audio_tracks JSON for file=%s",
                    file_id,
                    exc_info=True,
                )

    # Defensive conversion: a single malformed track dict (missing a
    # required field, unexpected type) must not poison the whole
    # response.  Skip non-dicts up front; let Pydantic
    # ``ValidationError`` filter the rest per-entry.
    audio_tracks_resp: list[AudioTrackInfo] = []
    for track in raw_tracks:
        if not isinstance(track, dict):
            continue
        try:
            audio_tracks_resp.append(AudioTrackInfo(**track))
        except ValidationError:
            logger.debug(
                "Skipping malformed audio track entry for session=%s: %r",
                session_id,
                track,
                exc_info=True,
            )

    return StreamStartResponse(
        session_id=session_id,
        file_id=file_id,
        playlist_url=_playlist_url(request, session_id),
        resume_sec=resolved_seek_sec,
        applied_seek_sec=applied_seek_sec,
        hdr_format=hdr_format,
        # `tonemapped` only true when the *source* is HDR AND the
        # operator asked for tonemap.  An SDR file with `tonemap=true`
        # passes through unchanged, so the badge stays off.
        tonemapped=bool(tonemap and hdr_format),
        streaming_mode=effective_mode,
        audio_streaming_mode=audio_streaming_mode,
        audio_tracks=audio_tracks_resp,
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


@router.post("/{session_id}/seek", response_model=StreamSeekResponse)
@limiter.limit("30/minute")
async def seek_stream(
    session_id: str,
    request: Request,
    seek_sec: float,
    tonemap: bool = False,
    db: aiosqlite.Connection = Depends(get_db),
    client: aiosqlite.Row = Depends(validate_token),
) -> StreamSeekResponse:
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

    # Plan 19 §M8 — same library-row plumbing as /start so the seek
    # restart preserves the per-library codec passthrough decision.
    library_row: dict | None = None
    if file_row.get("library_id"):
        library_row = await library_service.get_library(db, file_row["library_id"])

    # Library transcode: prefer the H.264 sidecar if one exists.  Mirrors
    # the playback_path resolution in /start so a session that began on
    # the sidecar continues to use the sidecar after seek-restart, AND
    # the sidecar codec/duration overrides are forwarded so the restart
    # spawn doesn't accidentally fall through to NVENC transcode again.
    playback_path = file_row.get("transcoded_path") or file_row["path"]
    using_sidecar = False
    if file_row.get("transcoded_path"):
        if Path(file_row["transcoded_path"]).exists():
            using_sidecar = True
        else:
            logger.warning(
                "Transcoded sidecar missing on disk; falling back to source: %s",
                file_row["transcoded_path"],
            )
            playback_path = file_row["path"]
    sidecar_codec_override = "h264" if using_sidecar else None
    sidecar_duration_override = (
        float(file_row["duration_sec"])
        if using_sidecar and file_row.get("duration_sec")
        else None
    )

    try:
        await ffmpeg_service.restart_stream(
            playback_path,
            session_id,
            settings.hls_tmp_path,
            seek_sec=seek_sec,
            tonemap_hdr=tonemap,
            source_codec_override=sidecar_codec_override,
            duration_sec_override=sidecar_duration_override,
            library_row=library_row,
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

    # Return the segment-snapped value FFmpeg actually applied so the
    # mobile cubit can update its playlist-offset bookkeeping (streaming
    # pipeline plan §16 scrubber-offset patch 2026-05-08).  Falls back
    # to the requested value if the dict is empty (defensive — shouldn't
    # happen on the success branch).
    applied_seek_sec = ffmpeg_service._applied_seek_sec.get(session_id, seek_sec)
    return StreamSeekResponse(applied_seek_sec=applied_seek_sec)


# ── POST /api/v1/stream/{session_id}/fallback-transcode ────────────────────
# Plan 20.  Mobile / desktop player calls this when libmpv emits an error
# on the active session within the first 6 s of playback (the window where
# "client physically can't decode this codec" is far more likely than any
# other failure mode).  Server records the (client, source codec) pair in
# the blocklist + flips the per-session force-transcode flag + re-spawns
# FFmpeg from the live playhead with the transcode pipeline.  The
# playlist URL doesn't change; the client is expected to re-open the
# Media on the same URL to load the new (transcoded) segments.


@router.post(
    "/{session_id}/fallback-transcode",
    response_model=FallbackTranscodeResponse,
)
@limiter.limit("10/minute")
async def fallback_transcode(
    session_id: str,
    request: Request,
    body: FallbackTranscodeBody,
    db: aiosqlite.Connection = Depends(get_db),
    client: aiosqlite.Row = Depends(validate_token),
) -> FallbackTranscodeResponse:
    """Switch ``session_id`` from stream-copy to server-side transcode."""
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

    # Plan 20 — fallback only fires when the operator has opted in via
    # `streaming_mode = 'auto'`.  Strict `client-decode` is documented as
    # "modern devices only"; the operator picked it deliberately and a
    # client decode failure should surface to the user rather than
    # silently switch to transcode.  `server-transcode` is already
    # transcoding — nothing to fall back to.
    settings_row = await settings_service.get_settings(db)
    effective_mode = settings_row.get("streaming_mode") or "client-decode"
    if effective_mode != "auto":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Fallback is only available when streaming_mode='auto'. "
                f"Current mode: {effective_mode}."
            ),
        )

    file_row = await library_service.get_file(db, row["file_id"])
    if file_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Source file no longer exists",
        )

    # Per-library override resolution — mirrors /start + /seek so the
    # restarted session keeps every other plan-19 decision intact.
    library_row: dict | None = None
    if file_row.get("library_id"):
        library_row = await library_service.get_library(db, file_row["library_id"])

    # Sidecar handling — when the session is playing a transcoded sidecar
    # the FFmpeg input is H.264 by construction.  Mirrors /start + /seek
    # so blocklist + force-transcode work uniformly across paths.  We
    # still write the blocklist row against the *source* codec the
    # client actually saw — for a sidecar that's H.264, which means a
    # future session for this client + codec will start in transcode
    # mode even on the source playback path.  This is the conservative
    # choice: when the device fails on H.264 the next play of the H.264
    # source should also be transcoded (re-encoded to H.264 via the
    # configured encoder + audio re-encode), which is a no-op
    # passthrough for codec but may help with audio decoder failures.
    playback_path = file_row.get("transcoded_path") or file_row["path"]
    using_sidecar = False
    if file_row.get("transcoded_path"):
        if Path(file_row["transcoded_path"]).exists():
            using_sidecar = True
        else:
            logger.warning(
                "Transcoded sidecar missing on disk; falling back to source: %s",
                file_row["transcoded_path"],
            )
            playback_path = file_row["path"]
    sidecar_codec_override = "h264" if using_sidecar else None
    sidecar_duration_override = (
        float(file_row["duration_sec"])
        if using_sidecar and file_row.get("duration_sec")
        else None
    )

    if using_sidecar:
        source_codec: str | None = "h264"
    else:
        source_codec = file_row.get("codec_name")
    if not source_codec:
        # Lazy-probe never ran + no sidecar — we have no codec to block
        # on.  Still honour the operator's request to force-transcode
        # this session, but skip the persisted blocklist entry; the
        # next session will probe + may hit the same error, which is
        # a degenerate but acceptable case (a future plan can extend
        # `add_block` to take a probe-deferred sentinel).  Log loud so
        # an operator can see why the blocklist didn't get written.
        logger.warning(
            "fallback-transcode: no source_codec for session=%s file=%s — "
            "skipping blocklist write (in-session flag still set)",
            session_id,
            row["file_id"],
        )

    # Clamp the caller-supplied position to [0, duration - 1) so the
    # restart's `-ss` doesn't trip undefined behaviour or land past EOF
    # (which produces a zero-segment static playlist and breaks the
    # player).  Pydantic already enforced `>= 0`; this enforces the
    # upper bound + safe-margin.
    duration_sec = float(file_row.get("duration_sec") or 0.0)
    clamped = max(0.0, float(body.current_position_sec))
    if duration_sec > 0 and clamped >= duration_sec - 1.0:
        clamped = max(0.0, duration_sec - 1.0)

    if source_codec:
        await client_codec_service.add_block(
            db, client["id"], source_codec, "player_error_within_6s"
        )
        await db.commit()

    ffmpeg_service.set_session_force_transcode(session_id, True)

    try:
        await ffmpeg_service.restart_stream(
            playback_path,
            session_id,
            settings.hls_tmp_path,
            seek_sec=clamped,
            tonemap_hdr=False,
            source_codec_override=sidecar_codec_override,
            duration_sec_override=sidecar_duration_override,
            library_row=library_row,
        )
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        ffmpeg_error = str(exc) or exc.__class__.__name__
        logger.error(
            "fallback-transcode restart failed: session=%s seek=%.3f error=%s",
            session_id,
            clamped,
            ffmpeg_error,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Fallback transcode restart failed: {ffmpeg_error}",
        ) from exc

    return FallbackTranscodeResponse(
        session_id=session_id,
        playlist_url=_playlist_url(request, session_id),
        forced_transcode=True,
    )


# ── POST /api/v1/stream/{session_id}/fallback-audio-transcode ──────────────
# Plan 21.  Mirrors plan-20's /fallback-transcode but for AUDIO ONLY: the
# server keeps video stream-copying and only flips the audio path to
# re-encode.  Mobile / desktop player calls this when libmpv emits an
# audio-related error within the first 6 s of playback (the window where
# "client physically can't decode this audio codec" is far more likely
# than any other failure mode).  Server records the (client, source
# audio codec) pair in `client_audio_codec_blocklist` + flips the
# per-session audio-force flag + re-spawns FFmpeg from the live
# playhead.  Independent of the video fallback — both can fire in the
# same session.


@router.post(
    "/{session_id}/fallback-audio-transcode",
    response_model=FallbackAudioTranscodeResponse,
)
@limiter.limit("10/minute")
async def fallback_audio_transcode(
    session_id: str,
    request: Request,
    body: FallbackAudioTranscodeRequest,
    db: aiosqlite.Connection = Depends(get_db),
    client: aiosqlite.Row = Depends(validate_token),
) -> FallbackAudioTranscodeResponse:
    """Switch ``session_id`` from audio stream-copy to audio re-encode."""
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

    # Plan 21 — audio fallback only fires under `streaming_mode='auto'`.
    # Strict `client-decode` is "modern devices only" — a player audio
    # error should surface to the user rather than silently switch
    # pipelines.  `server-transcode` already re-encodes audio — nothing
    # to fall back to.
    settings_row = await settings_service.get_settings(db)
    effective_mode = settings_row.get("streaming_mode") or "client-decode"
    if effective_mode != "auto":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="audio fallback only valid in auto streaming mode",
        )

    file_row = await library_service.get_file(db, row["file_id"])
    if file_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Source file no longer exists",
        )

    # Per-library override resolution + sidecar handling — mirrors
    # /start + /seek + /fallback-transcode so the restarted session
    # keeps every other plan-19 / plan-20 decision intact.
    library_row: dict | None = None
    if file_row.get("library_id"):
        library_row = await library_service.get_library(db, file_row["library_id"])

    playback_path = file_row.get("transcoded_path") or file_row["path"]
    using_sidecar = False
    if file_row.get("transcoded_path"):
        if Path(file_row["transcoded_path"]).exists():
            using_sidecar = True
        else:
            logger.warning(
                "Transcoded sidecar missing on disk; falling back to source: %s",
                file_row["transcoded_path"],
            )
            playback_path = file_row["path"]
    sidecar_codec_override = "h264" if using_sidecar else None
    sidecar_duration_override = (
        float(file_row["duration_sec"])
        if using_sidecar and file_row.get("duration_sec")
        else None
    )

    # Probe the source's audio codec so we can write the blocklist row
    # for the (client, audio_codec) pair.  Best-effort — if ffprobe is
    # unavailable or the source has no audio stream we still honour the
    # operator's request to force audio re-encode for this session but
    # skip the persisted blocklist entry (no codec to attribute it to).
    # Log loud so an operator can see why the blocklist didn't grow.
    source_audio_codec: str | None = None
    try:
        audio_info = await ffmpeg_service._probe_audio_params(playback_path)
        if audio_info is not None:
            raw_codec = audio_info.get("codec_name")
            if raw_codec:
                source_audio_codec = raw_codec.split("_")[0].lower()
    except Exception:
        logger.debug(
            "fallback-audio-transcode: audio probe failed for %s",
            playback_path,
            exc_info=True,
        )
    if not source_audio_codec:
        logger.warning(
            "fallback-audio-transcode: no source_audio_codec for session=%s "
            "file=%s — skipping blocklist write (in-session flag still set)",
            session_id,
            row["file_id"],
        )

    # Clamp the caller-supplied position to [0, duration - 1) so the
    # restart's `-ss` doesn't trip undefined behaviour or land past EOF
    # (which produces a zero-segment static playlist and breaks the
    # player).  Pydantic already enforced `>= 0`; this enforces the
    # upper bound + safe-margin.  Mirrors /fallback-transcode.
    duration_sec = float(file_row.get("duration_sec") or 0.0)
    clamped = max(0.0, float(body.current_position_sec))
    if duration_sec > 0 and clamped >= duration_sec - 1.0:
        clamped = max(0.0, duration_sec - 1.0)

    if source_audio_codec:
        await client_audio_codec_service.add_block(
            db, client["id"], source_audio_codec, "client decode error"
        )
        await db.commit()

    ffmpeg_service.set_session_force_audio_transcode(session_id, True)

    try:
        await ffmpeg_service.restart_stream(
            playback_path,
            session_id,
            settings.hls_tmp_path,
            seek_sec=clamped,
            tonemap_hdr=False,
            source_codec_override=sidecar_codec_override,
            duration_sec_override=sidecar_duration_override,
            library_row=library_row,
        )
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        ffmpeg_error = str(exc) or exc.__class__.__name__
        logger.error(
            "fallback-audio-transcode restart failed: session=%s seek=%.3f error=%s",
            session_id,
            clamped,
            ffmpeg_error,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Fallback audio transcode restart failed: {ffmpeg_error}",
        ) from exc

    return FallbackAudioTranscodeResponse(
        session_id=session_id,
        playlist_url=_playlist_url(request, session_id),
        forced_audio_transcode=True,
    )


# ── POST /api/v1/stream/{session_id}/audio-track ───────────────────────────
# Plan 23 — server-restart audio-track switching.  Mirrors plan-21's
# fallback-audio-transcode shape: respawn FFmpeg from the live playhead,
# this time with `-map 0:a:<index>?` pinning the chosen source audio
# track.  Replaces the broken libmpv-on-Android client-side
# `setAudioTrack` path (operator-reported 2026-05-15: the client-side
# swap left audio dead for 20 s then froze the entire player; no
# workaround stuck).  The pinned-track approach means libmpv only ever
# sees one audio stream so mid-stream switching never happens.


@router.post(
    "/{session_id}/audio-track",
    response_model=AudioTrackSwitchResponse,
)
@limiter.limit("12/minute")
async def switch_audio_track(
    session_id: str,
    request: Request,
    body: AudioTrackSwitchRequest,
    db: aiosqlite.Connection = Depends(get_db),
    client: aiosqlite.Row = Depends(validate_token),
) -> AudioTrackSwitchResponse:
    """Pin ``session_id`` to source audio track ``body.index`` and
    respawn FFmpeg from ``body.current_position_sec``.  Returns the
    same playlist URL — the client must call ``Player.open(url)``
    again to pick up the new pipeline's segments (which now contain
    exactly one audio stream, the operator-chosen one)."""
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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Source file no longer exists",
        )

    # Validate `body.index` against the session's known audio tracks.
    # Cache-first (plan 22 M1 populated this on start_stream); fall
    # back to the persisted column on media_files (plan 22 M2's scan
    # writes it) so a server-restart in the middle of the session
    # doesn't 400 the picker.
    tracks: list = ffmpeg_service._session_audio_tracks.get(session_id) or []
    if not tracks:
        db_audio_tracks = file_row.get("audio_tracks")
        if db_audio_tracks:
            try:
                parsed = json.loads(db_audio_tracks)
                if isinstance(parsed, list):
                    tracks = parsed
            except (json.JSONDecodeError, TypeError):
                logger.debug(
                    "audio-track switch: corrupt audio_tracks JSON for file=%s",
                    row["file_id"],
                    exc_info=True,
                )
    valid_indices = {
        int(t["index"])
        for t in tracks
        if isinstance(t, dict) and isinstance(t.get("index"), int)
    }
    if not valid_indices:
        # Source has no probed tracks at all — refuse rather than spawn
        # an FFmpeg that'll trip on `-map 0:a:0?` against a silent file.
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No audio tracks available on this source",
        )
    if body.index not in valid_indices:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Audio track index {body.index} not in source",
        )

    # Per-library overrides + sidecar handling — mirrors /start +
    # /seek + /fallback-* so the restarted session keeps every other
    # plan-19 / plan-20 decision intact.
    library_row: dict | None = None
    if file_row.get("library_id"):
        library_row = await library_service.get_library(db, file_row["library_id"])

    playback_path = file_row.get("transcoded_path") or file_row["path"]
    using_sidecar = False
    if file_row.get("transcoded_path"):
        if Path(file_row["transcoded_path"]).exists():
            using_sidecar = True
        else:
            logger.warning(
                "Transcoded sidecar missing on disk; falling back to source: %s",
                file_row["transcoded_path"],
            )
            playback_path = file_row["path"]
    sidecar_codec_override = "h264" if using_sidecar else None
    sidecar_duration_override = (
        float(file_row["duration_sec"])
        if using_sidecar and file_row.get("duration_sec")
        else None
    )

    # Clamp the caller-supplied position to [0, duration - 1) so the
    # restart's `-ss` doesn't trip undefined behaviour or land past EOF.
    duration_sec = float(file_row.get("duration_sec") or 0.0)
    clamped = max(0.0, float(body.current_position_sec))
    if duration_sec > 0 and clamped >= duration_sec - 1.0:
        clamped = max(0.0, duration_sec - 1.0)

    # Pin the audio track BEFORE restart_stream so the respawn picks it
    # up in `_build_ffmpeg_cmd` + `_ensure_fmp4_init_segment`.  Clears
    # automatically on session end via `stop_stream`.
    ffmpeg_service.set_session_pinned_audio_track(session_id, body.index)

    # Wipe the stale init.mp4 so `_ensure_fmp4_init_segment` regenerates
    # it under the new `-map 0:a:<index>?` pin.  Without this the old
    # init (declaring every audio track) lingers next to segments that
    # only carry one track — libmpv ingests one frame and stalls
    # because the track-count contract is violated.  Operator-reported
    # 2026-05-15: track switch fires server-side cleanly but client
    # video freezes immediately afterward, matching this exact symptom.
    session_dir = Path(settings.hls_tmp_path) / session_id
    init_path = session_dir / "init.mp4"
    try:
        init_path.unlink()
    except FileNotFoundError:
        pass
    except OSError:
        # Best-effort — log and let restart_stream proceed.  Worst case
        # the operator sees the freeze and we iterate.
        logger.warning(
            "audio-track switch: could not unlink stale init.mp4 for session=%s",
            session_id,
            exc_info=True,
        )

    try:
        await ffmpeg_service.restart_stream(
            playback_path,
            session_id,
            settings.hls_tmp_path,
            seek_sec=clamped,
            tonemap_hdr=False,
            source_codec_override=sidecar_codec_override,
            duration_sec_override=sidecar_duration_override,
            library_row=library_row,
        )
    except FileNotFoundError as exc:
        # Source vanished mid-restart — release the pin so the operator
        # isn't stuck with a half-applied state.
        ffmpeg_service.clear_session_pinned_audio_track(session_id)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        ffmpeg_service.clear_session_pinned_audio_track(session_id)
        ffmpeg_error = str(exc) or exc.__class__.__name__
        logger.error(
            "audio-track switch restart failed: session=%s index=%d seek=%.3f error=%s",
            session_id,
            body.index,
            clamped,
            ffmpeg_error,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Audio track switch restart failed: {ffmpeg_error}",
        ) from exc

    logger.info(
        "audio-track switch: session=%s index=%d seek=%.3f",
        session_id,
        body.index,
        clamped,
    )

    return AudioTrackSwitchResponse(
        session_id=session_id,
        playlist_url=_playlist_url(request, session_id),
        pinned_audio_track_index=body.index,
        applied_seek_sec=clamped,
    )


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
    if not resolved.exists() and (filename.startswith("seg") or filename == "init.mp4"):
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
