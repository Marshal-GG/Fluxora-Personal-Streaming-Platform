from pydantic import BaseModel, Field


class StreamStartResponse(BaseModel):
    session_id: str
    file_id: str
    playlist_url: str
    resume_sec: float = 0.0  # seconds to seek to on open (resume playback)
    # Segment-aligned seek position FFmpeg actually started at — equals
    # ``floor(resume_sec / hls_time) * hls_time``.  The playlist's t=0
    # corresponds to this source-time, NOT to t=0 of the file.  The
    # mobile cubit uses this as ``_playlistOffsetSec`` and adds it to
    # libmpv's reported position when rendering the scrubber so the
    # user sees source-time, not playlist-time (streaming pipeline plan
    # §16 scrubber-offset patch 2026-05-08).
    applied_seek_sec: float = 0.0
    # Source HDR format if any: "HDR10" | "HLG" | "DolbyVision" | None.
    # Drives the player's HDR badge + the "tonemap to SDR" toggle visibility.
    hdr_format: str | None = None
    # True when the server is currently tonemapping HDR to SDR for this
    # session.  Echoes the request's `tonemap` query param so the client
    # knows whether the toggle is currently on.
    tonemapped: bool = False
    # Plan 20 — effective streaming mode for this session.  Mobile/desktop
    # players use this to decide whether to arm the auto-fallback watcher:
    # only `"auto"` may trigger a fallback POST.  `"client-decode"` and
    # `"server-transcode"` sessions ignore decode errors and surface them
    # to the user instead.
    streaming_mode: str = "client-decode"


class StreamSeekResponse(BaseModel):
    """Response body for ``POST /api/v1/stream/{session_id}/seek``.

    Was previously 204 No Content; the scrubber-offset patch needs the
    server to surface the segment-aligned seek position so the mobile
    cubit can update its playlist-offset bookkeeping (streaming pipeline
    plan §16 scrubber-offset patch 2026-05-08).
    """

    applied_seek_sec: float


class StreamSessionResponse(BaseModel):
    id: str
    file_id: str
    client_id: str
    started_at: str
    ended_at: str | None
    connection_type: str
    bytes_transferred: int
    progress_sec: float


# ── Plan 20 — fallback-transcode endpoint ────────────────────────────


class FallbackTranscodeBody(BaseModel):
    """Caller-supplied current playhead so the server can restart from
    the live position instead of guessing.  Clamped server-side to
    ``[0, duration_sec - 1)``.
    """

    current_position_sec: float = Field(ge=0)


class FallbackTranscodeResponse(BaseModel):
    """200 response.  Playlist URL is the same as the one returned by
    ``/start`` — the client must re-open the playlist on the same URL
    to pick up the new (transcoded) segments.
    """

    session_id: str
    playlist_url: str
    forced_transcode: bool
