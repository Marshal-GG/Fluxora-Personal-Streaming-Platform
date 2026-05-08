from pydantic import BaseModel


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
