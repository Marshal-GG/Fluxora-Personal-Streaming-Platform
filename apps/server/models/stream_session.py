from typing import Literal

from pydantic import BaseModel, Field


class AudioTrackInfo(BaseModel):
    """Plan 22 — per-track metadata exposed in /stream/start response.

    Mobile uses this to populate the Audio sheet picker; track switching
    is purely client-side via media_kit's setAudioTrack (no server
    roundtrip).  Each entry mirrors one element of the cached
    ``ffmpeg_service._session_audio_tracks[session_id]`` list (which in
    turn comes from ``_probe_audio_tracks``) or one element of the
    JSON-decoded ``media_files.audio_tracks`` column when the cache
    missed.
    """

    index: int = Field(ge=0)
    codec: str
    language: str | None = None
    title: str | None = None
    channels: int = Field(ge=1)
    sample_rate: int = Field(ge=1)
    bit_rate: int | None = Field(default=None, ge=0)

    model_config = {"extra": "ignore"}


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
    # Plan 21 — actual audio pipeline the server picked for this session.
    # ``"stream-copy"`` means the source audio packets pass through
    # unmodified (allowlist codec + tonemap off + no force flag);
    # ``"transcode"`` means the audio is being re-encoded to AAC.  The
    # mobile / desktop player uses this to decide whether to arm the
    # audio-decode-error watcher (only stream-copy sessions can fall
    # back to audio-only transcode; transcode sessions already speak
    # the lowest-common-denominator AAC).  Defaults to ``"transcode"``
    # for safety on unknown sessions — a stale client that doesn't yet
    # understand the field stays on the conservative re-encode path.
    audio_streaming_mode: Literal["stream-copy", "transcode"] = "transcode"
    # Plan 22 — every audio track the source advertises, in FFmpeg
    # stream-index order.  Mobile renders this as the Audio bottom-sheet
    # picker (track switching is purely client-side via media_kit's
    # ``setAudioTrack``).  Default ``[]`` preserves backward compat:
    # pre-plan-22 mobile clients tolerate the new field and just ignore
    # it; pre-plan-22 servers return responses without the field and
    # mobile sees ``[]`` → no picker rendered.
    audio_tracks: list[AudioTrackInfo] = Field(default_factory=list)


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


# ── Plan 21 — fallback-audio-transcode endpoint ──────────────────────


class FallbackAudioTranscodeRequest(BaseModel):
    """Caller-supplied current playhead so the server can restart from
    the live position instead of guessing.  Pydantic enforces
    ``>= 0``; the router clamps to ``[0, duration_sec - 1)`` before
    forwarding to FFmpeg so ``-ss`` never lands at EOF.

    Mirrors plan 20's ``FallbackTranscodeBody`` shape exactly — the
    audio-only fallback uses the same playhead semantics as the video
    fallback; only the pipeline state the server flips differs.
    """

    current_position_sec: float = Field(ge=0)


class FallbackAudioTranscodeResponse(BaseModel):
    """200 response.  Playlist URL is the same as the one returned by
    ``/start`` — the client must re-open the playlist on the same URL
    to pick up the new (audio-re-encoded) segments.  Video continues
    stream-copying; only the audio path flipped.
    """

    session_id: str
    playlist_url: str
    forced_audio_transcode: bool
