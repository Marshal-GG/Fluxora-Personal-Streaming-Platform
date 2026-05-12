import asyncio
import json
import logging
import math
import shutil
import sys
import tempfile
from pathlib import Path

from services.encoder_registry import ENCODER_REGISTRY, EncoderMeta

logger = logging.getLogger(__name__)

# Active sessions: session_id → asyncio.subprocess.Process
_active: dict[str, asyncio.subprocess.Process] = {}

# Per-session stderr temp-file paths. Populated in start_stream, drained
# (and unlinked) in stop_stream. Keyed by session_id so a long-running
# transcode and a quickly-failed one don't fight over the same handle.
_stderr_paths: dict[str, Path] = {}

# Per-session restart locks. ``restart_stream`` acquires the session's
# lock for the entire kill→wipe→respawn→playlist-rewrite sequence so
# two concurrent seek calls (e.g. user double-tap on the seek bar) don't
# race the kill against the new spawn — without this, the second call's
# ``_terminate_ffmpeg`` could kill the first call's freshly-spawned
# process and leave the session permanently dead.  Looked up lazily
# because the set of session ids isn't known at module-import time.
_seek_locks: dict[str, asyncio.Lock] = {}

# Per-session restart counters. Bumped on every successful
# ``restart_stream`` call and emitted as the ``#EXT-X-DISCONTINUITY-
# SEQUENCE`` value in the rewritten static playlist.  Per HLS spec the
# value must monotonically increase across discontinuities; this counter
# is the cleanest way to keep the value monotonic across the lifetime of
# a single session.
_discontinuity_seq: dict[str, int] = {}

# Per-session natural-exit watchers (streaming pipeline plan §4.5).  When
# FFmpeg finishes encoding the file cleanly (returncode == 0) we replace
# the spawn-time over-promised static VOD playlist with FFmpeg's own
# accurate one — fixes the 5-15% tail-mismatch on stream-copy HEVC.  The
# task is tracked so ``_terminate_ffmpeg`` can cancel it: a watcher that
# fires after a kill would either no-op on the rc != 0 guard or race the
# session-dir cleanup; cancelling cuts that out cleanly.
_finalize_watchers: dict[str, asyncio.Task[None]] = {}

# Per-session segment-aligned seek position (streaming pipeline plan §16
# scrubber-offset patch 2026-05-08).  When ``start_stream`` /
# ``restart_stream`` snap the requested seek to a segment boundary
# (``floor(seek / hls_time) * hls_time``), the playlist's t=0 corresponds
# to that snapped source-time — but libmpv's reported playback position
# starts at 0 regardless.  The router reads this dict to surface
# ``applied_seek_sec`` in the /start + /seek responses; the mobile cubit
# stores it as ``_playlistOffsetSec`` and adds it to libmpv's position
# when rendering the scrubber so the user sees source-time, not playlist-
# time.  Cleared on stop_stream alongside the other per-session dicts.
_applied_seek_sec: dict[str, float] = {}

# Plan 20 — per-session "force transcode regardless of stream-copy
# eligibility" flag.  Set to True by the ``/fallback-transcode``
# endpoint after a client reports a decode error in the first 6 s.
# Read at the top of ``start_stream`` so the next spawn (the restart
# kicked off by the same endpoint) bypasses every direct-remux gate.
# Also flipped by ``stream.start_stream`` when the per-client blocklist
# already contains (client_id, source_codec).  Cleared on
# ``stop_stream`` so a long-running server doesn't accumulate entries.
_session_force_transcode: dict[str, bool] = {}


def set_session_force_transcode(session_id: str, value: bool = True) -> None:
    """Mark / unmark ``session_id`` for forced server-side transcoding.

    Public helper for the stream router — the fallback endpoint flips
    the bit before kicking ``restart_stream``, and the /start endpoint
    flips it pre-spawn when the blocklist already matches the
    (client, source codec) pair.
    """
    if value:
        _session_force_transcode[session_id] = True
    else:
        _session_force_transcode.pop(session_id, None)


def clear_session_force_transcode(session_id: str) -> None:
    """Drop the session's force-transcode bit, if any.

    Called from ``stop_stream`` so the entry doesn't linger after the
    session ends.  No-op when no entry exists.
    """
    _session_force_transcode.pop(session_id, None)


def _get_seek_lock(session_id: str) -> asyncio.Lock:
    """Return the per-session restart lock, creating it on first access."""
    lock = _seek_locks.get(session_id)
    if lock is None:
        lock = asyncio.Lock()
        _seek_locks[session_id] = lock
    return lock


def _drain_stderr(session_id: str, max_bytes: int = 4096) -> str:
    """Read up to the last [max_bytes] of FFmpeg stderr for this session.

    Returns an empty string if the file is missing / unreadable — the
    caller should fall back to a generic "FFmpeg failed" message.
    """
    path = _stderr_paths.get(session_id)
    if path is None or not path.exists():
        return ""
    try:
        with path.open("rb") as fh:
            fh.seek(0, 2)  # seek to end
            size = fh.tell()
            fh.seek(max(0, size - max_bytes))
            tail = fh.read()
        return tail.decode("utf-8", errors="replace").strip()
    except OSError:
        logger.warning(
            "Could not read FFmpeg stderr file: session=%s path=%s",
            session_id,
            path,
            exc_info=True,
        )
        return ""


def _drop_stderr(session_id: str) -> None:
    """Delete the stderr temp file for a session, if any."""
    path = _stderr_paths.pop(session_id, None)
    if path is None:
        return
    try:
        path.unlink(missing_ok=True)
    except OSError:
        logger.warning("Could not unlink FFmpeg stderr file: %s", path, exc_info=True)


def _ffmpeg_bin() -> str:
    """Return FFmpeg binary path, preferring a bundled copy in PyInstaller builds."""
    if getattr(sys, "frozen", False):
        bundled = Path(sys._MEIPASS) / "ffmpeg"  # type: ignore[attr-defined]
        if bundled.exists():
            return str(bundled)
        bundled_exe = Path(sys._MEIPASS) / "ffmpeg.exe"  # type: ignore[attr-defined]
        if bundled_exe.exists():
            return str(bundled_exe)
    found = shutil.which("ffmpeg")
    if found is None:
        raise FileNotFoundError(
            "FFmpeg not found. Install it and ensure it is on PATH."
        )
    return found


def _ffprobe_bin() -> str | None:
    """Return ffprobe path or None if unavailable. Probing is best-effort —
    a missing ffprobe must never break library scans."""
    if getattr(sys, "frozen", False):
        for name in ("ffprobe", "ffprobe.exe"):
            bundled = Path(sys._MEIPASS) / name  # type: ignore[attr-defined]
            if bundled.exists():
                return str(bundled)
    return shutil.which("ffprobe")


def _detect_hdr_format(stream: dict) -> str | None:
    """Return "HDR10" / "HLG" / "DolbyVision" or None for SDR.

    Detection priority is Dolby Vision first (it travels as side-data on top
    of an HDR10 base layer, so transfer-function inspection alone would
    misclassify a DV file as HDR10).
    """
    side_data = stream.get("side_data_list") or []
    for entry in side_data:
        kind = (entry.get("side_data_type") or "").lower()
        if "dolby vision" in kind:
            return "DolbyVision"
    transfer = (stream.get("color_transfer") or "").lower()
    if transfer in ("smpte2084", "pq"):
        return "HDR10"
    if transfer in ("arib-std-b67", "hlg"):
        return "HLG"
    return None


async def probe_video(file_path: str) -> dict | None:
    """Run ffprobe; return width/height/codec/hdr/duration_sec.

    Returns None when ffprobe is not installed, the file is not a decodable
    video, or the stream list is empty. Callers must treat the response as
    advisory — scan completion never depends on probe success.

    ``duration_sec`` is read from the container's ``format.duration`` because
    a stream-level ``duration`` field is unreliable for many MKV/WebM sources
    (matroska reports duration on the container only).  Required for the
    static VOD playlist generator in ``start_stream`` — when this is None
    the player falls back to FFmpeg's growing playlist and the seek bar
    only spans segments written so far.
    """
    ffprobe = _ffprobe_bin()
    if ffprobe is None:
        return None
    cmd = [
        ffprobe,
        "-v",
        "error",
        "-print_format",
        "json",
        "-show_streams",
        "-show_format",
        "-select_streams",
        "v:0",
        file_path,
    ]
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        stdout, _ = await proc.communicate()
    except (OSError, FileNotFoundError):
        logger.warning("ffprobe failed for %s", file_path, exc_info=True)
        return None
    if proc.returncode != 0:
        return None
    try:
        data = json.loads(stdout.decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        return None
    streams = data.get("streams") or []
    if not streams:
        return None
    stream = streams[0]
    width = stream.get("width")
    height = stream.get("height")

    duration_sec: float | None = None
    fmt = data.get("format") or {}
    raw_duration = fmt.get("duration")
    if raw_duration is not None:
        try:
            d = float(raw_duration)
            if d > 0:
                duration_sec = d
        except (TypeError, ValueError):
            pass

    return {
        "width": int(width) if isinstance(width, int) else None,
        "height": int(height) if isinstance(height, int) else None,
        "codec_name": stream.get("codec_name"),
        "hdr_format": _detect_hdr_format(stream),
        "duration_sec": duration_sec,
    }


async def _probe_audio_params(file_path: str) -> dict | None:
    """Run ffprobe on the first audio stream.  Returns
    ``{codec_name, sample_rate, channels, bit_rate}`` or ``None`` when
    ffprobe is unavailable / the file has no audio / the probe fails.

    Streaming pipeline plan §16 M4 — instrumentation only.  Caller logs
    the result at session start so AV-sync issues surface a paper
    trail (codec, sample rate, channel count) before the encoder runs.
    Diagnostics-only; failures must not block playback.
    """
    ffprobe = _ffprobe_bin()
    if ffprobe is None:
        return None
    cmd = [
        ffprobe,
        "-v",
        "error",
        "-print_format",
        "json",
        "-show_streams",
        "-select_streams",
        "a:0",
        file_path,
    ]
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        stdout, _ = await proc.communicate()
    except (OSError, FileNotFoundError):
        logger.debug("audio ffprobe failed for %s", file_path, exc_info=True)
        return None
    if proc.returncode != 0:
        return None
    try:
        data = json.loads(stdout.decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        return None
    streams = data.get("streams") or []
    if not streams:
        return None
    s = streams[0]
    return {
        "codec_name": s.get("codec_name"),
        "sample_rate": s.get("sample_rate"),
        "channels": s.get("channels"),
        "bit_rate": s.get("bit_rate"),
    }


async def _resolve_source_metadata(
    db,
    file_path: str,
) -> tuple[str | None, str | None]:
    """Return ``(codec_name, hdr_format)`` for the source file.

    Files scanned before migration 016 (or before the FFprobe-at-scan
    step) have NULL codec_name — they would silently transcode even
    when the source is stream-copy-eligible.  Probe lazily and persist
    the result so the next playback of the same file is fast.

    ``hdr_format`` is one of ``"HDR10"`` / ``"HLG"`` / ``"DolbyVision"`` /
    ``None`` (SDR).  Drives the tonemap decision in start_stream when the
    operator has asked for HDR sources to be converted to SDR.
    """
    async with db.execute(
        "SELECT id, codec_name, width, height, hdr_format FROM media_files"
        " WHERE path = ?",
        (file_path,),
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        return None, None
    if row["codec_name"]:
        return row["codec_name"], row["hdr_format"]

    # Lazy probe — one ffprobe invocation, ~200 ms.  Cheaper than even
    # 1 s of unnecessary transcoding.
    info = None
    try:
        info = await probe_video(file_path)
    except Exception:
        logger.warning(
            "Lazy ffprobe failed for %s — transcoding as fallback",
            file_path,
            exc_info=True,
        )
    if info is None:
        return None, None

    # Persist the probe result so the next play is constant-time.  We
    # already have the row id; mirror `library_service._persist_probe`
    # without importing it (avoids a circular dep — that module imports
    # `probe_video` from us).
    from datetime import UTC, datetime

    try:
        await db.execute(
            "UPDATE media_files SET width = ?, height = ?, codec_name = ?,"
            "  hdr_format = ?,"
            "  duration_sec = COALESCE(?, duration_sec),"
            "  updated_at = ?"
            " WHERE id = ?",
            (
                info["width"],
                info["height"],
                info["codec_name"],
                info["hdr_format"],
                info.get("duration_sec"),
                datetime.now(UTC).isoformat(),
                row["id"],
            ),
        )
        await db.commit()
    except Exception:
        logger.warning(
            "Could not persist lazy ffprobe result for %s",
            file_path,
            exc_info=True,
        )
    return info["codec_name"], info["hdr_format"]


async def _resolve_source_codec(db, file_path: str, file_id: str | None) -> str | None:
    """Back-compat wrapper — returns just the codec name."""
    codec, _ = await _resolve_source_metadata(db, file_path)
    return codec


# NVIDIA cuvid hardware-decoder names by source codec.  FFmpeg's
# `-hwaccel cuda` should auto-pick these for the input stream, but in
# practice the auto-selection is unreliable for AV1 — the bundled FFmpeg
# falls through to the native software AV1 decoder which fails on many
# real-world AV1 files (`Failed to get pixel format` / `Get current frame
# error`).  Forcing `-c:v <codec>_cuvid` BEFORE `-i` makes FFmpeg use
# NVDEC for the input, keeping decoded frames on the GPU and avoiding
# the broken software path entirely.
#
# Falls back gracefully: if the GPU doesn't support NVDEC for that codec
# (e.g. AV1 NVDEC needs RTX 30+ Ampere or newer), FFmpeg surfaces a clear
# error which `start_stream` bubbles up via the captured stderr tail —
# operator sees "av1_cuvid: hardware AV1 decoder not supported on this
# GPU" and can re-encode the source.
_NVIDIA_CUVID_BY_CODEC: dict[str, str] = {
    "av1": "av1_cuvid",
    "hevc": "hevc_cuvid",
    "h265": "hevc_cuvid",
    "h264": "h264_cuvid",
    "vp9": "vp9_cuvid",
    "vp8": "vp8_cuvid",
    "mpeg2video": "mpeg2_cuvid",
    "mpeg4": "mpeg4_cuvid",
    "vc1": "vc1_cuvid",
}


# zscale + tonemap filter chain that converts BT.2020 PQ HDR10 → BT.709
# SDR with Hable tonemapping.  Result is yuv420p ready for any 8-bit
# encoder (libx264, h264_nvenc, h264_qsv, etc.).
#
# Steps:
# 1. `zscale=t=linear:npl=100`   — un-PQ the transfer to linear light
# 2. `format=gbrpf32le`          — float planar so tonemap has headroom
# 3. `zscale=p=bt709`            — gamut: BT.2020 → BT.709 primaries
# 4. `tonemap=tonemap=hable:desat=0` — Hable curve, no desaturation
# 5. `zscale=t=bt709:m=bt709:r=tv,format=yuv420p` — back to TV-range 8-bit
#
# Hable is the default for a reason: it preserves highlight detail
# better than `linear` / `gamma` on a wide range of source content.
# `desat=0` keeps the saturated colours rather than washing them — most
# game capture sources benefit from the full saturation.
_HDR_TO_SDR_VF = (
    "zscale=t=linear:npl=100,format=gbrpf32le,"
    "zscale=p=bt709,"
    "tonemap=tonemap=hable:desat=0,"
    "zscale=t=bt709:m=bt709:r=tv,format=yuv420p"
)


def _input_decoder_args(
    source_codec: str | None,
    encoder_meta: EncoderMeta,
) -> list[str]:
    """Return explicit `-c:v <decoder>` for the input when needed.

    Only fires for NVIDIA encoders today; other vendors rely on FFmpeg's
    automatic decoder selection.  Returning an empty list means "let
    FFmpeg pick the default decoder".

    Specifically targets the broken-software-AV1-decode case the operator
    sees with the bundled FFmpeg build.
    """
    if encoder_meta.vendor != "nvidia" or not source_codec:
        return []
    decoder = _NVIDIA_CUVID_BY_CODEC.get(source_codec.lower())
    if decoder is None:
        return []
    return ["-c:v", decoder]


# Substrings in FFmpeg stderr that indicate the GPU input pipeline
# rejected the source.  When we see any of these in a failed-attempt's
# stderr tail, retry the pipeline with `use_gpu_input=False` so the
# software decoder gets a chance — covers HDR / 12-bit / 4:4:4 sources
# that NVDEC won't accept (cuvid-tagged errors), AV1 sources on Turing
# GPUs without AV1 NVDEC ("Your platform doesn't support hardware
# accelerated AV1 decoding"), and any other case where `-hwaccel cuda`
# itself fails to initialise for the input.
_CUVID_FAILURE_MARKERS: tuple[str, ...] = (
    "cuvid is not supported",
    "not supported with this chroma format",
    "cuvid",  # any cuvid-tagged error in the tail
    "hwaccel initialisation returned error",
    "doesn't support hardware accelerated",
    "hardware is lacking required capabilities",
)


def _build_ffmpeg_cmd(
    *,
    file_path: str,
    session_dir: Path,
    playlist: Path,
    meta: EncoderMeta,
    preset: str,
    crf: int,
    hwaccel_device: str | None,
    source_codec: str | None,
    direct_remux: bool,
    direct_remux_hevc: bool,
    direct_remux_av1: bool = False,
    direct_remux_vp9: bool = False,
    use_gpu_input: bool,
    apply_hdr_tonemap: bool = False,
    seek_sec: float = 0.0,
    start_segment_index: int = 0,
    source_audio_codec: str | None = None,
    source_audio_sample_rate: int | None = None,
) -> list[str]:
    """Compose the FFmpeg command line.

    ``use_gpu_input=True`` (first attempt) injects the encoder's
    pre-input ``-hwaccel`` flags AND the cuvid input-decoder hint when
    applicable.  ``use_gpu_input=False`` (retry path after a CUDA-input
    failure) drops *both* — frames stay on the CPU through software
    decode and only land on the GPU at NVENC encode time via FFmpeg's
    automatic upload.  Slower than the all-GPU path but works on any
    GPU + FFmpeg combination, which is what makes it a sensible retry.

    Loglevel is ``info`` for every session — the conditional warning /
    error split was the original sin behind the M2 ``-readrate`` retry
    failures (`<no stderr captured>` because FFmpeg's startup messages
    were below the threshold) and the HDR-audio diagnostic blind-spot
    (`error`-level suppressed the AAC-mux warnings on the stream-copy
    audio path).  Streaming pipeline plan §17 — diagnostics first so
    every future "FFmpeg killed for unknown reason" failure produces
    actionable stderr.  In-memory cost is unchanged because
    ``_drain_stderr`` caps the read at 4 KB; per-session tempfile cost
    is unlinked at session end either way.
    """
    loglevel = "info"
    cmd: list[str] = [_ffmpeg_bin(), "-hide_banner", "-loglevel", loglevel]

    # Throttle FFmpeg's input reader to ~1.5× source rate, but ONLY for
    # transcode sessions (streaming pipeline plan §17 M3 +
    # post-real-device-test refinement 2026-05-08 evening).
    #
    # Why transcode-only:
    #   • Stream-copy is already CPU-cheap (~5 % of one core).  It
    #     produces segments faster than the player consumes them
    #     naturally; throttling it doesn't save meaningful CPU and
    #     introduces a real failure mode where the first post-restart
    #     segment can take longer than the segment-serve wait timeout
    #     (2 s) to appear → 404 storm → media_kit gives up after a
    #     handful of retries.  Operator hit this on a real-device test
    #     of the M3 retry: `seg00195.ts` 404'd repeatedly because
    #     stream-copy + `-readrate 1.5` made the first post-seek segment
    #     too slow for the 2 s wait.
    #   • Transcode (NVENC at 3-6× realtime, software libx264 at
    #     0.5-2×) is where the home server actually heats up.  The
    #     fan-noise / power-draw concern that motivated this throttle
    #     in the first place is a transcode-pipeline concern.  Apply
    #     it there.
    #
    # Tonemap is also skipped: tonemap on CPU is at 0.4-0.8× realtime
    # already; `-readrate 1.5` either silently no-ops or starves the
    # buffer.
    #
    # `-readrate_initial_burst 30` (FFmpeg 5.1+) lets FFmpeg consume
    # the first 30 s of source at full speed before throttle kicks in.
    # Capability-gated via the version probe; older builds get the
    # plain throttle.
    if not direct_remux and not apply_hdr_tonemap:
        from services.ffmpeg_capabilities import get_capabilities

        cmd.extend(["-readrate", "1.5"])
        if get_capabilities().supports_readrate_initial_burst:
            cmd.extend(["-readrate_initial_burst", "30"])

    if not direct_remux and use_gpu_input:
        # Pre-input hardware acceleration flags (empty list for software).
        cmd.extend(meta.pre_input_args(device=hwaccel_device))
        # Force the input decoder when FFmpeg's auto-selection is known
        # to break (e.g. AV1 software decode on the bundled build).
        cmd.extend(_input_decoder_args(source_codec, meta))

    # Input-side seek — placed *before* `-i` for the fast path.  For
    # transcode this is decoder-fast (FFmpeg seeks the demuxer); for
    # stream-copy it keyframe-snaps to the nearest preceding keyframe,
    # which is the best we can do without re-encoding (the cost of
    # which would defeat the whole point of stream-copy).  The caller is
    # expected to align seek_sec to a multiple of `hls_time` so the
    # produced segments line up cleanly with the playlist's segment
    # numbering and there's no off-by-fraction-of-second drift.
    if seek_sec > 0:
        cmd.extend(["-ss", f"{seek_sec:.3f}"])

    cmd.extend(["-i", file_path])

    if direct_remux:
        # Stream-copy preserves the source's HDR bitstream.  Tonemap
        # cannot apply here — it requires decoded pixels; the caller is
        # responsible for forcing transcode mode (direct_remux=False)
        # whenever apply_hdr_tonemap is True.
        cmd.extend(["-c:v", "copy"])
    else:
        cmd.extend(meta.video_codec_args(preset, crf))
        # Combine the tonemap chain with the encoder's own filter chain
        # (VAAPI needs `format=nv12|vaapi,hwupload`).  Tonemap runs first
        # — it operates on CPU pixels, then the result feeds into VAAPI
        # upload if needed.
        encoder_vf = meta.vf_chain  # raw string from registry, may be None
        chains = [c for c in (
            _HDR_TO_SDR_VF if apply_hdr_tonemap else None,
            encoder_vf,
        ) if c]
        if chains:
            cmd.extend(["-vf", ",".join(chains)])

    # Audio pipeline (streaming pipeline plan §16 M4 fix; tonemap-audio
    # interaction patch 2026-05-08).
    #
    # Three paths:
    #
    # 1. Source is AAC at 48 kHz AND tonemap is OFF → `-c:a copy`.  Skips
    #    re-encode entirely.  HLS clients all support AAC + 48 kHz
    #    directly, and skipping the re-encode eliminates the timestamp
    #    drift that was the most likely cause of the operator-reported
    #    "audio is very delayed" symptom.
    #
    # 2. Source is AAC at 48 kHz BUT tonemap is ON → `-c:a aac -b:a 128k`
    #    (resample omitted since source is already 48 kHz).  Operator-
    #    reported regression 2026-05-08: HDR-with-tonemap sessions showed
    #    NO AUDIO when the audio path was `-c:a copy`.  Most likely
    #    cause is mux-timestamp drift from heavy video transcode +
    #    tonemap filter chain interacting with copied audio packets — the
    #    audio container's frame timing drifts off the video's re-encoded
    #    PTS budget and the HLS muxer drops audio rather than emit a
    #    broken segment.  Forcing audio re-encode regenerates clean PTS
    #    that aligns with the transcoded video.  CPU cost is negligible
    #    (audio encode is <3 % vs the tonemap chain's CPU bill).
    #
    # 3. Source is anything else (DTS, AC3, FLAC, AAC at 44.1/96 kHz, etc.)
    #    → `-c:a aac -b:a 128k -ar 48000`.  Forces resample to 48 kHz so
    #    the AAC encoder doesn't introduce sample-rate drift on
    #    non-48 kHz sources, AND remaps non-AAC sources to AAC for HLS
    #    client compatibility.
    #
    # Defaults (when audio params aren't known) fall through to path 3 —
    # the safer of the three, since it always produces valid HLS audio.
    audio_is_aac_48khz = (
        source_audio_codec == "aac"
        and source_audio_sample_rate == 48000
    )
    if audio_is_aac_48khz and not apply_hdr_tonemap:
        # Path 1 — copy.  Safe only when video is also stream-copy or
        # transcoded WITHOUT the tonemap filter chain (which is what
        # caused the audio-drop regression on HDR sessions).
        cmd.extend(["-c:a", "copy"])
    elif audio_is_aac_48khz and apply_hdr_tonemap:
        # Path 2 — re-encode but skip the resample (source already at
        # 48 kHz; no drift to worry about, just clean PTS regeneration).
        cmd.extend(["-c:a", "aac", "-b:a", "128k"])
    else:
        # Path 3 — full re-encode + resample to 48 kHz.
        cmd.extend(["-c:a", "aac", "-b:a", "128k", "-ar", "48000"])

    # fmp4 segments for HEVC / AV1 / VP9 stream-copy and for transcode-
    # mode encoders whose registry says fmp4.  Plan 19 §M7 — AV1 + VP9
    # ride the same fmp4 segment path HEVC uses; MPEG-TS doesn't carry
    # those codecs cleanly across all clients but fmp4 (CMAF) is
    # well-supported.  The bundled FFmpeg's HLS muxer is unreliable
    # about writing the init segment under stream-copy —
    # `_ensure_fmp4_init_segment()` generates one ourselves if FFmpeg
    # skipped it, so the playlist's `#EXT-X-MAP URI` always points at a
    # real file.
    use_fmp4 = (
        direct_remux_hevc or direct_remux_av1 or direct_remux_vp9
        or (not direct_remux and meta.segment_fmt == "fmp4")
    )
    hls_time = "10" if direct_remux else "6"
    common_hls = [
        "-f", "hls",
        "-hls_time", hls_time,
        "-hls_list_size", "0",
    ]
    # Continue the segment numbering from where the previous spawn left
    # off (used by `restart_stream`).  For an initial spawn this is 0,
    # which matches FFmpeg's default and is a no-op.  Without this the
    # restart writes seg00000.* on disk while the static VOD playlist
    # tells the player the file is at seg<K>.* — segment 404 + retry
    # storm.
    if start_segment_index > 0:
        common_hls.extend(["-start_number", str(start_segment_index)])
    if not direct_remux:
        common_hls.extend(["-hls_flags", "independent_segments"])

    if use_fmp4:
        cmd.extend(common_hls + [
            "-hls_segment_type", "fmp4",
            # Pin the init-segment filename explicitly so the playlist's
            # #EXT-X-MAP URI matches what's actually written to disk.
            # FFmpeg's default for unnamed fmp4 init segments varies between
            # builds — some produce `init.mp4`, others embed init data into
            # `seg00000.m4s`.  Without this flag the player gets a playlist
            # pointing at `init.mp4` but the file doesn't exist → 404.
            "-hls_fmp4_init_filename", "init.mp4",
            "-hls_segment_filename", str(session_dir / "seg%05d.m4s"),
            str(playlist),
        ])
    else:
        cmd.extend(common_hls + [
            "-hls_segment_type", "mpegts",
            "-hls_segment_filename", str(session_dir / "seg%05d.ts"),
            str(playlist),
        ])
    return cmd


def _is_cuvid_failure(stderr_tail: str) -> bool:
    """Heuristically classify a stderr tail as a GPU-input-pipeline failure.

    Name kept for back-compat with tests; in practice it now matches both
    cuvid-tagged errors AND the broader "hwaccel cuda failed to set up"
    family that surfaces when AV1 NVDEC is unavailable on the GPU
    (Turing, etc.).
    """
    lower = stderr_tail.lower()
    return any(marker in lower for marker in _CUVID_FAILURE_MARKERS)


def _write_static_vod_playlist(
    *,
    playlist: Path,
    duration_sec: float,
    hls_time: float,
    use_fmp4: bool,
    init_filename: str = "init.mp4",
    start_segment_index: int = 0,
    discontinuity_seq: int = 0,
) -> int:
    """Pre-emit a complete VOD playlist listing every segment FFmpeg will
    eventually write.

    Without this, the player loads FFmpeg's incrementally-growing playlist
    and the seek bar only spans the segments written so far — extending
    over the encode duration.  With a static playlist the player sees the
    file's full duration immediately and can seek anywhere.  When the user
    seeks ahead of FFmpeg's current write position, the HLS router waits
    briefly for the requested segment to appear before falling back to 404.

    Returns the number of segments listed.

    ``start_segment_index`` and ``discontinuity_seq`` together enable the
    seek-restart path (`restart_stream`):

    - ``start_segment_index`` shifts both the listed segment URLs (the
      list begins at ``seg<K>.{ts,m4s}``) and the playlist's
      ``#EXT-X-MEDIA-SEQUENCE`` to ``K``.  FFmpeg's ``-start_number K``
      writes seg<K> + onwards; without the matching shift here the
      player would 404 against the file the playlist promises.
    - ``discontinuity_seq > 0`` adds ``#EXT-X-DISCONTINUITY-SEQUENCE``
      and inserts a ``#EXT-X-DISCONTINUITY`` line before the first
      segment, telling the player to flush its decode buffer.  Required
      because a re-spawn from a non-zero ``-ss`` produces frames whose
      decode timestamps do not continue from what the player previously
      consumed.

    Limitation: stream-copy aligns segments to source keyframes, so actual
    segment durations may exceed ``hls_time`` by a few seconds.  The
    predicted segment count is therefore an upper bound; the playlist
    may list a few segments at the tail that FFmpeg doesn't end up
    writing.  Players retry-then-skip on 404 within reason; the
    operator-visible effect is a small stutter at end-of-file in the
    worst case.
    """
    if duration_sec <= 0 or hls_time <= 0:
        return 0
    n_total = max(1, math.ceil(duration_sec / hls_time))
    if start_segment_index >= n_total:
        # Seek past end of file — emit an empty (but still valid) VOD
        # playlist so the player resolves cleanly to end-of-stream.
        lines = [
            "#EXTM3U",
            f"#EXT-X-VERSION:{6 if use_fmp4 else 3}",
            f"#EXT-X-TARGETDURATION:{max(1, math.ceil(hls_time))}",
            "#EXT-X-PLAYLIST-TYPE:VOD",
            f"#EXT-X-MEDIA-SEQUENCE:{start_segment_index}",
            "#EXT-X-ENDLIST",
        ]
        playlist.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return 0
    last_dur = duration_sec - (n_total - 1) * hls_time
    if last_dur <= 0:
        last_dur = hls_time
    target_dur = max(1, math.ceil(hls_time))
    extension = "m4s" if use_fmp4 else "ts"

    lines: list[str] = [
        "#EXTM3U",
        # VERSION 6 is needed for `#EXT-X-MAP` (init segment) per Apple HLS spec.
        f"#EXT-X-VERSION:{6 if use_fmp4 else 3}",
        f"#EXT-X-TARGETDURATION:{target_dur}",
        "#EXT-X-PLAYLIST-TYPE:VOD",
        f"#EXT-X-MEDIA-SEQUENCE:{start_segment_index}",
    ]
    if discontinuity_seq > 0:
        lines.append(f"#EXT-X-DISCONTINUITY-SEQUENCE:{discontinuity_seq}")
    if use_fmp4:
        lines.append(f'#EXT-X-MAP:URI="{init_filename}"')
    if discontinuity_seq > 0:
        # Mark the seek point as a decode-buffer-flush boundary; placed
        # immediately before the first listed segment so the player
        # discards anything still in its pipeline from the previous
        # spawn before consuming the new segment data.
        lines.append("#EXT-X-DISCONTINUITY")
    for i in range(start_segment_index, n_total):
        dur = last_dur if i == n_total - 1 else hls_time
        lines.append(f"#EXTINF:{dur:.6f},")
        lines.append(f"seg{i:05d}.{extension}")
    lines.append("#EXT-X-ENDLIST")
    playlist.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return n_total - start_segment_index


def _finalize_vod_playlist(
    *,
    session_dir: Path,
    served_playlist_name: str = "playlist.m3u8",
    ff_playlist_name: str = "_ff_playlist.m3u8",
    discontinuity_seq: int = 0,
) -> bool:
    """Replace the served VOD playlist with FFmpeg's accurate one.

    Streaming pipeline plan §4.5.  The served playlist is pre-emitted at
    spawn time as a static list with ``ceil(duration / hls_time)``
    entries (see ``_write_static_vod_playlist``) — that's an upper
    bound.  Stream-copy aligns segments to source keyframes, so the
    actual count diverges by 5-15% on long-GOP HEVC sources and the
    over-promised tail entries 404 against files FFmpeg never produced.

    FFmpeg's own incremental playlist (``_ff_playlist.m3u8``) holds the
    truth: per-segment ``#EXTINF`` durations + only the segments
    actually written.  After FFmpeg exits naturally we copy its
    playlist over the served path so future loads (resume flows, cross-
    session reuse, slow polling clients) see the truthful list.

    Preserves the seek-restart bookkeeping (``EXT-X-DISCONTINUITY-
    SEQUENCE``) by re-injecting it after the version line — FFmpeg
    doesn't know about our seek-restart counter.

    Returns True on successful rewrite; False when the FFmpeg playlist
    is missing or empty (in which case the served playlist is left
    untouched — better an over-promised playlist than a broken one).
    """
    served = session_dir / served_playlist_name
    ff = session_dir / ff_playlist_name
    if not ff.exists():
        return False
    raw = ff.read_text(encoding="utf-8")
    if not raw.strip():
        return False
    if discontinuity_seq > 0:
        # Inject right after the EXT-X-VERSION line so the player picks
        # up the seek-restart bookkeeping the next time it loads the
        # playlist.  The inline ``#EXT-X-DISCONTINUITY`` marker the
        # static playlist used (sat before the first listed segment) is
        # unnecessary now — the player already consumed the
        # discontinuity at restart time.  Only the SEQUENCE value
        # matters for downstream caches.
        lines = raw.splitlines()
        out: list[str] = []
        injected = False
        for line in lines:
            out.append(line)
            if not injected and line.startswith("#EXT-X-VERSION"):
                out.append(
                    f"#EXT-X-DISCONTINUITY-SEQUENCE:{discontinuity_seq}"
                )
                injected = True
        raw = "\n".join(out)
        if not raw.endswith("\n"):
            raw += "\n"
    served.write_text(raw, encoding="utf-8")
    return True


async def _finalize_vod_playlist_on_exit(
    session_id: str,
    proc: asyncio.subprocess.Process,
    session_dir: Path,
    discontinuity_seq: int,
) -> None:
    """Background task: await FFmpeg's natural exit + finalise the
    served VOD playlist.

    No-op when:
      * The task is cancelled (``stop_stream`` / ``restart_stream`` is
        about to tear down or replace this session).
      * ``returncode != 0`` — the process was killed or crashed; the
        existing failure / cleanup paths handle the dir.
      * The session directory has been torn down between exit and
        finalise (race with stop_stream's cleanup).

    Self-cleans the entry in ``_finalize_watchers`` on exit so the dict
    doesn't grow forever on a long-running server.  Streaming pipeline
    plan §4.5.
    """
    try:
        rc = await proc.wait()
    except asyncio.CancelledError:
        _finalize_watchers.pop(session_id, None)
        raise
    if rc != 0:
        _finalize_watchers.pop(session_id, None)
        return
    if not session_dir.exists():
        _finalize_watchers.pop(session_id, None)
        return
    try:
        ok = _finalize_vod_playlist(
            session_dir=session_dir,
            discontinuity_seq=discontinuity_seq,
        )
        if ok:
            logger.info(
                "VOD playlist finalised after natural FFmpeg exit: "
                "session=%s",
                session_id,
            )
    except Exception:
        logger.warning(
            "VOD playlist finalisation raised for session=%s",
            session_id,
            exc_info=True,
        )
    finally:
        _finalize_watchers.pop(session_id, None)


async def _ensure_fmp4_init_segment(
    session_dir: Path,
    file_path: str,
    audio_aac_kbps: int = 128,
) -> bool:
    """Generate `<session_dir>/init.mp4` if FFmpeg's HLS muxer didn't.

    The bundled FFmpeg's HLS muxer is unreliable about writing the
    fmp4 init segment under stream-copy — segments get written but
    `init.mp4` is silently skipped, leaving the playlist's
    `#EXT-X-MAP URI="init.mp4"` pointing at a missing file → player
    refuses to start playback (404 from the HLS router).

    This generates an init-only fragmented mp4 by re-running FFmpeg
    against the source with ``-t 0.04`` (≈one frame) + the same
    fragmentation flags the HLS muxer uses (`empty_moov` puts the
    moov at the head of the file; `default_base_moof` + `frag_keyframe`
    are the standard fmp4 set).  The resulting file has the moov box
    matching the source's video config + the AAC config we'd produce
    in the segments.  Players parse the moov, set up the decoder, and
    skip the tiny mdat without complaint.

    Returns True if a file now exists at `init.mp4` (whether we wrote
    it or it was already there); False on failure.
    """
    init_path = session_dir / "init.mp4"
    if init_path.exists() and init_path.stat().st_size > 0:
        return True

    try:
        ffmpeg = _ffmpeg_bin()
    except FileNotFoundError:
        return False

    # `-map 0:a:0?` makes the audio track optional — silent video files
    # (no audio stream at index 0) don't error out.
    # `-t 0.04` writes ≈1 frame at 25 fps; the moov header is what the
    # player actually reads, the tiny mdat is skipped.
    cmd = [
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-i", file_path,
        "-map", "0:v:0", "-c:v", "copy",
        "-map", "0:a:0?", "-c:a", "aac", "-b:a", f"{audio_aac_kbps}k",
        "-t", "0.04",
        "-movflags", "+empty_moov+default_base_moof+frag_keyframe",
        "-f", "mp4",
        str(init_path),
    ]
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await asyncio.wait_for(proc.wait(), timeout=10.0)
    except (TimeoutError, OSError):
        logger.warning(
            "Manual fmp4 init-segment generation failed for %s",
            file_path,
            exc_info=True,
        )
        return False

    if proc.returncode != 0:
        logger.warning(
            "Manual fmp4 init-segment generation exited with code %d for %s",
            proc.returncode,
            file_path,
        )
        return False

    return init_path.exists() and init_path.stat().st_size > 0


async def _spawn_ffmpeg_attempt(
    cmd: list[str],
    session_id: str,
    playlist: Path,
    *,
    playlist_timeout_sec: float = 10.0,
) -> tuple[bool, str, int | None, bool]:
    """Run one FFmpeg attempt.

    Returns ``(succeeded, stderr_tail, returncode, killed_after_timeout)``.

    On success the playlist appeared within ``playlist_timeout_sec`` and
    the process is still running.  On failure the process either exited
    prematurely (``killed_after_timeout=False``) or the playlist never
    appeared in time and we terminated the process ourselves
    (``killed_after_timeout=True``).  The stderr tail is drained and
    the session's stderr file is unlinked in either failure case so
    retries get a fresh capture.

    ``playlist_timeout_sec`` is pipeline-aware: stream-copy and
    NVENC-only transcodes finish their first segment within seconds, so
    the default 10 s is fine.  HDR→SDR tonemap runs on the CPU at ~0.6×
    realtime — a 6-second source segment takes ~10 wall-seconds, which
    means callers with tonemap enabled MUST raise this to 60 s+ or the
    timeout will kill FFmpeg right as it produces the first segment.
    Software-only transcodes sit in between and use 30 s.

    Why ``killed_after_timeout`` is a separate flag: on Windows
    ``proc.terminate()`` calls ``TerminateProcess(handle, 1)``, which
    sets ``proc.returncode = 1`` even though FFmpeg never voluntarily
    exited with that code.  Without this flag the caller can't tell a
    real "FFmpeg crashed with exit 1" from "we killed it after a
    timeout" — both look like exit code 1 from the outside.

    The process is launched with `cwd=playlist.parent` (the session
    directory) so the HLS muxer's `-hls_fmp4_init_filename` — which only
    accepts a basename — resolves to `<session_dir>/init.mp4` instead
    of the server-process cwd.  Without this the bundled FFmpeg writes
    the init segment next to whatever directory the server was launched
    from (e.g. `apps/server/init.mp4`) while the playlist's
    `#EXT-X-MAP URI` points at the session dir, producing a 404.
    """
    stderr_fd, stderr_path = tempfile.mkstemp(
        prefix=f"fluxora-ffmpeg-{session_id}-", suffix=".log"
    )
    _stderr_paths[session_id] = Path(stderr_path)
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=stderr_fd,
            cwd=str(playlist.parent),
        )
    finally:
        try:
            import os
            os.close(stderr_fd)
        except OSError:
            pass

    _active[session_id] = proc
    logger.info(
        "FFmpeg started: session=%s pid=%d playlist_timeout=%.0fs",
        session_id,
        proc.pid,
        playlist_timeout_sec,
    )

    poll_interval = 0.1
    poll_iterations = max(1, int(playlist_timeout_sec / poll_interval))
    for _ in range(poll_iterations):
        if playlist.exists():
            return True, "", None, False
        if proc.returncode is not None:
            tail = _drain_stderr(session_id)
            _drop_stderr(session_id)
            _active.pop(session_id, None)
            return False, tail, proc.returncode, False
        await asyncio.sleep(poll_interval)

    # Playlist never appeared within the budget but the process is still
    # alive — kill it and capture whatever stderr exists.  The
    # killed_after_timeout flag tells the caller this is *our* exit
    # code, not FFmpeg's.
    try:
        proc.terminate()
        try:
            await asyncio.wait_for(proc.wait(), timeout=2.0)
        except TimeoutError:
            proc.kill()
            await proc.wait()
    except ProcessLookupError:
        pass
    tail = _drain_stderr(session_id)
    _drop_stderr(session_id)
    _active.pop(session_id, None)
    return False, tail, proc.returncode, True


def _resolve_codec_passthrough(
    settings_row: dict | None,
    library_row: dict | None,
    codec: str,
    *,
    session_force_transcode: bool = False,
) -> bool:
    """Plan 19 §M8 + plan 20 — resolve whether to stream-copy `codec`.

    Decision precedence (highest → lowest):

    1. ``session_force_transcode`` — set by the plan-20 fallback path
       after the client reported a decode error.  Forces False
       regardless of every other input.
    2. Per-library tri-state override (``<codec>_stream_copy_override``):
       NULL inherits, 0 forces transcoding, 1 forces stream-copy.
    3. Global ``streaming_mode``:
       * ``client-decode`` ⇒ True (stream-copy AV1/VP9 to capable clients)
       * ``auto`` ⇒ True (start optimistically; the fallback endpoint
         flips ``session_force_transcode`` later when the client
         can't decode)
       * ``server-transcode`` ⇒ False (legacy plan-18 path).
    """
    if session_force_transcode:
        return False
    settings_row = settings_row or {}
    if library_row is not None:
        override_col = f"{codec}_stream_copy_override"
        override = library_row.get(override_col)
        if override is not None:
            return bool(override)
    mode = settings_row.get("streaming_mode") or "client-decode"
    return mode in ("auto", "client-decode")


async def start_stream(
    file_path: str,
    session_id: str,
    hls_root: Path,
    *,
    tonemap_hdr: bool = False,
    seek_sec: float = 0.0,
    discontinuity_seq: int = 0,
    source_codec_override: str | None = None,
    duration_sec_override: float | None = None,
    library_row: dict | None = None,
) -> Path:
    """Spawn FFmpeg for HLS output; return the .m3u8 playlist path.

    Picks one of two pipelines depending on the source's video codec:

    - **Stream-copy** when the source is h264 or hevc.  FFmpeg remuxes
      the existing video stream into HLS segments without touching pixels —
      drops CPU usage by ~95%.  Audio is re-encoded to AAC 128 kb/s
      (source audio may be AC3 / DTS which HLS clients don't universally
      support; audio encoding is <3% CPU relative to video).

    - **Full transcode** for everything else (vp9, av1, mpeg4, etc.).
      Uses the operator's configured encoder / preset / CRF read from
      ``user_settings``.  Hardware-accelerated encoders (NVENC, QSV,
      VAAPI, VideoToolbox) are dispatched via ``encoder_registry.py``:
      pre-input ``-hwaccel`` flags are placed *before* ``-i`` as required
      by FFmpeg, preset names are translated to native HW names, and
      quality control uses the correct per-vendor flag.

    **Cuvid auto-fallback:** the first transcode attempt may include a
    forced cuvid decoder (e.g. ``-c:v av1_cuvid``) which breaks on
    sources whose chroma format / bit depth aren't supported by the
    GPU's NVDEC engine (typical with HDR / 10-bit AV1 on RTX 30, or
    4:4:4 / 12-bit anywhere).  When the first attempt fails with a
    cuvid-tagged stderr, we retry once without the hint so FFmpeg's
    default decoder gets a chance.  No-op when the first attempt
    succeeds or when the failure is unrelated to cuvid.
    """
    from database.db import get_db
    from services import session_router, settings_service

    db = await get_db()
    settings_row = await settings_service.get_settings(db)

    # Plan 20 — pulled near the top so every direct-remux gate below
    # can short-circuit when the fallback path has armed the flag.
    # `stream.start_stream` (router) sets this before calling us when
    # the per-(client, codec) blocklist already matches; the
    # /fallback-transcode endpoint sets it before calling
    # `restart_stream`, which threads through here.
    force_transcode: bool = _session_force_transcode.get(session_id, False)

    default_encoder: str = (
        settings_row.get("transcoding_encoder", "libx264") or "libx264"
    )
    preset: str = settings_row.get("transcoding_preset", "veryfast") or "veryfast"
    crf: int = int(settings_row.get("transcoding_crf", 23) or 23)
    hwaccel_device: str | None = settings_row.get("transcoding_hwaccel_device")

    # Plan 18 — when the router is feeding a transcoded sidecar (the
    # `.h264.<ext>` produced by `transcode_service`), the file_path
    # FFmpeg actually reads is NOT in `media_files`; the path-based
    # lookup in `_resolve_source_metadata` would miss + return
    # (None, None), the direct-remux check below would then fail,
    # and we'd silently NVENC-transcode the already-H.264 sidecar.
    # The router knows the sidecar is H.264 SDR by construction;
    # `source_codec_override` short-circuits the lookup.
    if source_codec_override is not None:
        source_codec = source_codec_override
        hdr_format = None
    else:
        source_codec, hdr_format = await _resolve_source_metadata(db, file_path)

    # Streaming pipeline plan §16 M4 — probe the source's audio params at
    # session start.  Two consumers:
    #
    #   1. INFO log (`audio_probe ...`) so the operator can grep for the
    #      session's audio shape when diagnosing AV-sync issues.
    #   2. `_build_ffmpeg_cmd` audio-branch — when source is AAC at 48 kHz,
    #      the cmd uses `-c:a copy` instead of re-encoding (skipping the
    #      re-encode eliminates the timestamp drift that was the most
    #      likely cause of the operator-reported "audio is very delayed"
    #      symptom).
    #
    # Best-effort — ffprobe failure / no-audio sources / format quirks all
    # leave the locals at None, which the cmd builder treats as "use the
    # safe re-encode path".  Must not break playback under any failure.
    audio_codec_name: str | None = None
    audio_sample_rate: int | None = None
    try:
        audio_info = await _probe_audio_params(file_path)
        if audio_info is not None:
            audio_codec_name = audio_info.get("codec_name")
            raw_rate = audio_info.get("sample_rate")
            if raw_rate is not None:
                try:
                    audio_sample_rate = int(raw_rate)
                except (TypeError, ValueError):
                    audio_sample_rate = None
            logger.info(
                "audio_probe session=%s codec=%s sample_rate=%s "
                "channels=%s bit_rate=%s",
                session_id,
                audio_codec_name or "?",
                raw_rate or "?",
                audio_info.get("channels") or "?",
                audio_info.get("bit_rate") or "?",
            )
    except Exception:
        # Diagnostics only — must not break playback.
        logger.debug("audio_probe raised — skipping", exc_info=True)

    # Tonemap is only meaningful when both: (a) the source is HDR and
    # (b) the caller asked for it.  Anything else is a no-op.
    apply_hdr_tonemap = bool(tonemap_hdr and hdr_format)

    direct_remux_h264 = source_codec == "h264" and not force_transcode
    direct_remux_hevc = source_codec in ("hevc", "h265") and not force_transcode
    # Plan 19 §M7 — global `streaming_mode` controls AV1/VP9 stream-
    # copy.  M8 layers a per-library tri-state override on top so an
    # operator can pin behaviour for one library without changing
    # the global default.  Plan 20 adds a third precedence layer:
    # `_session_force_transcode` (set by the fallback endpoint /
    # blocklist hit) overrides everything else.  The resolver
    # collapses all four signals to a single bool per codec.
    direct_remux_av1 = source_codec == "av1" and _resolve_codec_passthrough(
        settings_row, library_row, "av1",
        session_force_transcode=force_transcode,
    )
    direct_remux_vp9 = source_codec == "vp9" and _resolve_codec_passthrough(
        settings_row, library_row, "vp9",
        session_force_transcode=force_transcode,
    )
    direct_remux = (
        direct_remux_h264 or direct_remux_hevc
        or direct_remux_av1 or direct_remux_vp9
    )

    # Diagnostic — one INFO line per session-start so the operator can
    # grep their logs to explain why a session went transcode vs
    # stream-copy.  Reason precedence mirrors the resolver layers
    # above: forced fallback > HDR tonemap > unsupported source codec
    # > per-library override > global setting.  The `path` field is
    # whatever direct_remux resolves to at this point (before tonemap
    # may flip it further down — that case logs its own line so the
    # operator sees both pieces of evidence).
    global_mode = settings_row.get("streaming_mode") or "client-decode"
    if force_transcode:
        # Both code paths that set the flag (per-client blocklist hit
        # at /start, /fallback-transcode endpoint mid-session) end up
        # here.  The router distinguishes them via the originating
        # endpoint; this log is just the post-resolution reason.
        decision_reason = "forced-fallback"
        decision_path = "transcode"
    elif apply_hdr_tonemap and (
        source_codec in ("h264", "hevc", "h265", "av1", "vp9")
    ):
        decision_reason = "hdr-tonemap"
        decision_path = "transcode"
    elif direct_remux:
        # Stream-copy was chosen.  Distinguish which signal won.
        if library_row is not None and source_codec in ("av1", "vp9"):
            override = library_row.get(f"{source_codec}_stream_copy_override")
            if override is not None:
                decision_reason = "library-override"
            elif global_mode == "client-decode":
                decision_reason = "global-client-decode"
            else:
                # auto / fallthrough — auto starts optimistically in
                # stream-copy until the client reports otherwise.
                decision_reason = "global-auto"
        elif source_codec in ("h264", "hevc", "h265"):
            decision_reason = "always-passthrough"
        elif global_mode == "client-decode":
            decision_reason = "global-client-decode"
        else:
            decision_reason = "global-auto"
        decision_path = "stream-copy"
    else:
        # Transcode chosen but no fallback / tonemap — must be either
        # the global server-transcode mode, a library override that
        # closed the gate, or an unsupported source codec.
        if library_row is not None and source_codec in ("av1", "vp9"):
            override = library_row.get(f"{source_codec}_stream_copy_override")
            if override == 0:
                decision_reason = "library-override"
            elif global_mode == "server-transcode":
                decision_reason = "global-server-transcode"
            else:
                decision_reason = "unsupported-source-codec"
        elif global_mode == "server-transcode" and source_codec in ("av1", "vp9"):
            decision_reason = "global-server-transcode"
        else:
            decision_reason = "unsupported-source-codec"
        decision_path = "transcode"
    logger.info(
        "stream_decision session=%s source_codec=%s mode=%s "
        "path=%s reason=%s",
        session_id,
        source_codec or "<unknown>",
        global_mode,
        decision_path,
        decision_reason,
    )

    # Tonemap requires decoded pixels, so it forces transcode mode even
    # for h264 / hevc / av1 / vp9 sources we'd otherwise stream-copy.
    # The tonemap filter chain runs CPU-side; CUDA hwaccel input would
    # push frames into VRAM and the zscale/tonemap filters can't read
    # them.  Drop the GPU-input pipeline for tonemap sessions.
    if apply_hdr_tonemap and direct_remux:
        logger.info(
            "Tonemap requested for HDR source — overriding stream-copy "
            "for session"
        )
        direct_remux = False
        direct_remux_h264 = False
        direct_remux_hevc = False
        direct_remux_av1 = False
        direct_remux_vp9 = False

    # Stream-copy doesn't invoke any encoder, so it bypasses the router
    # entirely.  Transcode mode consults the router so the operator's
    # priority chain (Slice C) gets a chance to fall over to a different
    # encoder when the first choice is at its concurrent-session cap.
    if direct_remux:
        encoder = default_encoder
    else:
        chain_raw = settings_row.get("transcoding_chain")
        chain = session_router.parse_chain(chain_raw)
        if not chain:
            # Back-compat default: try the operator's configured encoder
            # first, then fall through to libx264.  Existing installs that
            # never touched the chain UI get this for free.
            chain = (
                [default_encoder, "libx264"]
                if default_encoder != "libx264"
                else ["libx264"]
            )
        encoder, route_reason = session_router.pick_encoder(
            chain, session_id, default_encoder=default_encoder
        )

    meta: EncoderMeta = ENCODER_REGISTRY.get(encoder, ENCODER_REGISTRY["libx264"])
    if meta.name != encoder:
        logger.warning(
            "Unknown encoder %r in settings — falling back to libx264", encoder
        )

    session_dir = hls_root / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    # `playlist` is what the client requests via the HLS router.  We
    # pre-emit a static VOD playlist there listing every segment FFmpeg
    # will eventually write, so the player's seek bar shows full
    # duration upfront.  FFmpeg writes its own incremental playlist to
    # `_ff_playlist.m3u8` (we use it only as the "FFmpeg has produced
    # output" sentinel; it's never served to the client).
    playlist = session_dir / "playlist.m3u8"
    ff_playlist = session_dir / "_ff_playlist.m3u8"

    # AV1 + VP9 ride the same fmp4 segment path HEVC uses — MPEG-TS
    # doesn't carry AV1 / VP9 cleanly across all clients, but fmp4
    # (CMAF) is well-supported.  H.264 stays on MPEG-TS for back-compat.
    use_fmp4 = direct_remux_hevc or direct_remux_av1 or direct_remux_vp9 or (
        not direct_remux and meta.segment_fmt == "fmp4"
    )
    if direct_remux_hevc:
        mode = "stream-copy(hevc/fmp4)"
    elif direct_remux_av1:
        mode = "stream-copy(av1/fmp4)"
    elif direct_remux_vp9:
        mode = "stream-copy(vp9/fmp4)"
    elif direct_remux_h264:
        mode = "stream-copy(h264/mpegts)"
    else:
        seg = "fmp4" if use_fmp4 else "mpegts"
        mode = f"transcode({meta.name}/{seg})"
    logger.info(
        "FFmpeg pipeline: session=%s mode=%s source_codec=%s",
        session_id,
        mode,
        source_codec or "<unknown>",
    )

    # Tonemap forces software input — zscale/tonemap operate on CPU
    # pixels.  Skipping GPU input on the first attempt avoids the
    # guaranteed `Impossible to convert between the formats supported`
    # round-trip.
    first_attempt_gpu_input = not apply_hdr_tonemap

    # Align the requested seek to a segment boundary so FFmpeg's
    # `-start_number` and the static playlist's media-sequence stay
    # consistent.  ``segment_hls_time`` matches what FFmpeg uses below
    # (10 s for stream-copy, 6 s for transcode).
    segment_hls_time = 10.0 if direct_remux else 6.0
    if seek_sec > 0:
        start_segment_index = max(0, int(seek_sec // segment_hls_time))
        # Snap the input-side seek to the same boundary so segment N's
        # contents start at exactly N * hls_time of source time.  Stream-
        # copy is keyframe-bound anyway; the snap is at most a fraction
        # of a second of imprecision relative to what the user asked for.
        aligned_seek_sec = start_segment_index * segment_hls_time
    else:
        start_segment_index = 0
        aligned_seek_sec = 0.0

    # Stash for the router to read on its way out (streaming pipeline
    # plan §16 scrubber-offset patch 2026-05-08).  The /start + /seek
    # responses surface this so the mobile cubit knows the playlist's
    # source-time origin.
    _applied_seek_sec[session_id] = aligned_seek_sec

    # Pipeline-aware playlist-appearance timeout.  See the docstring on
    # ``_spawn_ffmpeg_attempt`` for the wall-time math behind these
    # choices: tonemap is CPU-only at ~0.6× realtime so the first
    # 6-second segment lands at ~10 wall-seconds — anything tighter
    # than 60 s timeout-kills a healthy tonemap session.  Software-only
    # transcodes are slower than hardware but faster than tonemap.
    #
    # Streaming pipeline plan §17 M4 — when `-readrate 1.5` is on (the
    # M3 retry), a slow source-disk read or busy CPU could push the
    # first-segment wall-time past the default 10 s budget for
    # stream-copy.  Bump the floor to 30 s when readrate is active:
    # the burst window covers the happy path; the extra budget catches
    # the slow-disk edge case without silently regressing to the
    # ``<no stderr captured>`` failure mode that motivated this plan.
    if apply_hdr_tonemap:
        playlist_timeout_sec = 60.0
    elif not direct_remux and meta.vendor == "software":
        playlist_timeout_sec = 30.0
    else:
        playlist_timeout_sec = 10.0
    # `-readrate 1.5` is only on for transcodes (not stream-copy, not
    # tonemap) — same gate as the cmd builder.  When it's active, give
    # the first segment up to 30 s wall to land: the burst window covers
    # the happy path, the extra budget absorbs slow-disk edge cases.
    if not direct_remux and not apply_hdr_tonemap:
        playlist_timeout_sec = max(playlist_timeout_sec, 30.0)

    # First attempt — full GPU input pipeline (-hwaccel cuda + cuvid hint),
    # unless tonemap is forcing CPU.
    cmd = _build_ffmpeg_cmd(
        file_path=file_path,
        session_dir=session_dir,
        playlist=ff_playlist,
        meta=meta,
        preset=preset,
        crf=crf,
        hwaccel_device=hwaccel_device,
        source_codec=source_codec,
        direct_remux=direct_remux,
        direct_remux_hevc=direct_remux_hevc,
        direct_remux_av1=direct_remux_av1,
        direct_remux_vp9=direct_remux_vp9,
        use_gpu_input=first_attempt_gpu_input,
        apply_hdr_tonemap=apply_hdr_tonemap,
        seek_sec=aligned_seek_sec,
        start_segment_index=start_segment_index,
        source_audio_codec=audio_codec_name,
        source_audio_sample_rate=audio_sample_rate,
    )
    succeeded, tail, returncode, killed_after_timeout = await _spawn_ffmpeg_attempt(
        cmd, session_id, ff_playlist, playlist_timeout_sec=playlist_timeout_sec,
    )

    # Retry once if the GPU input pipeline failed — software decode
    # piping into NVENC encode is slower but works on any GPU + FFmpeg.
    # Only retry when the first attempt actually invoked GPU input
    # (transcode mode + non-software encoder + GPU input wasn't already
    # disabled for tonemap).
    used_gpu_input = (
        first_attempt_gpu_input
        and not direct_remux
        and meta.vendor != "software"
    )
    if not succeeded and used_gpu_input and _is_cuvid_failure(tail):
        logger.warning(
            "GPU input pipeline rejected source (session=%s); retrying "
            "with software decode.  Original stderr tail:\n%s",
            session_id,
            tail or "<empty>",
        )
        cmd = _build_ffmpeg_cmd(
            file_path=file_path,
            session_dir=session_dir,
            playlist=ff_playlist,
            meta=meta,
            preset=preset,
            crf=crf,
            hwaccel_device=hwaccel_device,
            source_codec=source_codec,
            direct_remux=direct_remux,
            direct_remux_hevc=direct_remux_hevc,
            use_gpu_input=False,
            apply_hdr_tonemap=apply_hdr_tonemap,
            seek_sec=aligned_seek_sec,
            start_segment_index=start_segment_index,
        )
        # Software-decode retry is materially slower than the GPU-input
        # first attempt, so bump the timeout up one tier.  A 10 s budget
        # would just timeout-kill the retry on slow sources.
        retry_timeout_sec = max(playlist_timeout_sec, 30.0)
        succeeded, tail, returncode, killed_after_timeout = await _spawn_ffmpeg_attempt(
            cmd, session_id, ff_playlist, playlist_timeout_sec=retry_timeout_sec,
        )

    if succeeded:
        # If the playlist is fmp4, make sure init.mp4 actually exists on
        # disk — bundled FFmpeg builds skip writing it under stream-copy
        # despite the `-hls_fmp4_init_filename` flag.  No-op when FFmpeg
        # already wrote it (file exists).
        if use_fmp4:
            try:
                wrote = await _ensure_fmp4_init_segment(session_dir, file_path)
                if not wrote:
                    logger.warning(
                        "Could not generate fmp4 init segment for session=%s; "
                        "playback may fail with a 404 on init.mp4",
                        session_id,
                    )
            except Exception:
                logger.warning(
                    "Manual init-segment generation raised for session=%s",
                    session_id,
                    exc_info=True,
                )

        # Pre-emit a static VOD playlist listing every segment FFmpeg
        # will eventually write.  Player sees full duration on its
        # scrubber instead of watching it grow over the encode time.
        # Best-effort — when duration is unknown we skip and fall back
        # to FFmpeg's incremental playlist by copying it once.
        try:
            duration_sec: float | None = None
            # Plan 18 — sidecar playback path isn't in media_files, so
            # the path-based lookup misses and the static VOD playlist
            # gets skipped (player loses the scrubber's known total
            # duration).  The router has the source row's duration in
            # hand; thread it through as an override.
            if duration_sec_override is not None and duration_sec_override > 0:
                duration_sec = float(duration_sec_override)
            else:
                async with db.execute(
                    "SELECT duration_sec FROM media_files WHERE path = ?",
                    (file_path,),
                ) as cur:
                    drow = await cur.fetchone()
                if drow and drow["duration_sec"]:
                    duration_sec = float(drow["duration_sec"])
            if duration_sec and duration_sec > 0:
                count = _write_static_vod_playlist(
                    playlist=playlist,
                    duration_sec=duration_sec,
                    hls_time=segment_hls_time,
                    use_fmp4=use_fmp4,
                    start_segment_index=start_segment_index,
                    discontinuity_seq=discontinuity_seq,
                )
                logger.info(
                    "Static VOD playlist: session=%s segments=%d "
                    "(start_index=%d) duration=%.1fs disc_seq=%d",
                    session_id,
                    count,
                    start_segment_index,
                    duration_sec,
                    discontinuity_seq,
                )
            else:
                # Duration unknown — fall back to FFmpeg's incremental
                # playlist (copied to the served path so the route still
                # finds it).  Player's seek bar will grow as before, but
                # at least playback starts.
                if ff_playlist.exists():
                    playlist.write_bytes(ff_playlist.read_bytes())
                logger.warning(
                    "Static VOD playlist skipped — no duration known for session=%s",
                    session_id,
                )
        except Exception:
            logger.warning(
                "Static VOD playlist write raised for session=%s",
                session_id,
                exc_info=True,
            )

        # Kick off the natural-exit watcher (streaming pipeline §4.5).
        # When FFmpeg finishes encoding cleanly, it'll replace the
        # over-promised static playlist with FFmpeg's accurate one so
        # the tail-segment 404s the static list causes on stream-copy
        # disappear from any future playlist load.  Tracked in
        # _finalize_watchers so _terminate_ffmpeg can cancel it on
        # stop / restart paths (a watcher firing after a kill would
        # race the session-dir cleanup).  We replace any existing
        # watcher first — restart_stream's _terminate_ffmpeg already
        # cancels, but cancellation propagation is async; we don't
        # want a stale task lingering against the new spawn's proc.
        # `_spawn_ffmpeg_attempt` stores the live process in the
        # `_active` registry under `session_id` on success — that's the
        # source of truth for the watcher.  Retrieve it here rather than
        # threading the handle through `_spawn_ffmpeg_attempt`'s return
        # tuple (which is intentionally minimal — succeeded / tail /
        # returncode / killed_after_timeout).
        live_proc = _active.get(session_id)
        if live_proc is not None:
            existing = _finalize_watchers.pop(session_id, None)
            if existing is not None and not existing.done():
                existing.cancel()
            _finalize_watchers[session_id] = asyncio.create_task(
                _finalize_vod_playlist_on_exit(
                    session_id=session_id,
                    proc=live_proc,
                    session_dir=session_dir,
                    discontinuity_seq=discontinuity_seq,
                ),
                name=f"finalize-vod-{session_id}",
            )
        else:
            # Should not happen on the success branch — _spawn_ffmpeg_attempt
            # populates _active before returning True.  Log if it does and
            # skip the watcher rather than blow up the whole start_stream.
            logger.warning(
                "Skipping finalise-VOD watcher for session=%s — "
                "no live proc in _active despite successful spawn",
                session_id,
            )

        return playlist

    # Both attempts failed (or the only attempt did) — release the encoder
    # slot we reserved (if any) so a stuck failure doesn't leave the cap
    # accounting permanently inflated, AND wipe the partial session
    # directory so failed attempts don't accumulate disk on a long-
    # running server (the orphan cleanup on next startup catches these
    # too, but that's a long way off if uptime is days).  Failure
    # paths still raise the original diagnostic; the cleanup is a
    # side-effect that doesn't change the surfaced error.
    from services import session_router

    session_router.release_session(session_id)
    try:
        cleanup_session_dir(session_id, hls_root)
    except Exception:
        logger.warning(
            "cleanup_session_dir raised on failure path for session=%s",
            session_id,
            exc_info=True,
        )
    if killed_after_timeout:
        # We terminated FFmpeg ourselves because the playlist never
        # appeared in time.  proc.returncode is set (TerminateProcess on
        # Windows = 1) but it's *our* exit code, not FFmpeg's — surfacing
        # it as "exit code 1" sent the operator hunting for an FFmpeg
        # bug that doesn't exist.
        hint = (
            " — likely a slow tonemap or software transcode on this CPU"
            if apply_hdr_tonemap or (not direct_remux and meta.vendor == "software")
            else ""
        )
        logger.error(
            "FFmpeg killed after %.0fs timeout: session=%s no first segment%s\n"
            "FFmpeg stderr (last 4 KB):\n%s",
            playlist_timeout_sec,
            session_id,
            hint,
            tail or "<no stderr captured>",
        )
        first_line = next(
            (line for line in tail.splitlines() if line.strip()),
            f"no output within {playlist_timeout_sec:.0f}s",
        )
        raise RuntimeError(
            f"FFmpeg killed after {playlist_timeout_sec:.0f}s timeout"
            f" (no first segment{hint}): {first_line}"
        )
    if returncode is not None:
        logger.error(
            "FFmpeg exited prematurely with code %d: session=%s\n"
            "FFmpeg stderr (last 4 KB):\n%s",
            returncode,
            session_id,
            tail or "<no stderr captured>",
        )
        first_line = next(
            (line for line in tail.splitlines() if line.strip()),
            f"exit code {returncode}",
        )
        raise RuntimeError(f"FFmpeg failed to start: {first_line}")
    logger.error(
        "FFmpeg timed out creating playlist for session=%s\n"
        "FFmpeg stderr (last 4 KB):\n%s",
        session_id,
        tail or "<no stderr captured>",
    )
    first_line = next(
        (line for line in tail.splitlines() if line.strip()),
        "no output before timeout",
    )
    raise RuntimeError(f"FFmpeg stream generation timed out: {first_line}")


async def _terminate_ffmpeg(session_id: str) -> None:
    """Kill the FFmpeg subprocess for a session, if any.

    Pops the entry out of `_active` and waits for the process to fully
    exit (with `kill()` fallback after 5 s).  Does NOT release the
    encoder-cap slot — that's the caller's job.  ``stop_stream`` calls
    this then releases; ``restart_stream`` calls this and keeps the
    slot reserved because the same session is about to spawn again.

    Also cancels the natural-exit watcher (streaming pipeline §4.5):
    the watcher's rc != 0 guard would no-op anyway, but cancellation
    is cleaner — avoids the watcher racing the session-dir cleanup
    on a restart.
    """
    watcher = _finalize_watchers.pop(session_id, None)
    if watcher is not None and not watcher.done():
        watcher.cancel()
    proc = _active.pop(session_id, None)
    if proc is None or proc.returncode is not None:
        return
    try:
        proc.terminate()
        try:
            await asyncio.wait_for(proc.wait(), timeout=5.0)
        except TimeoutError:
            proc.kill()
            await proc.wait()
    except ProcessLookupError:
        pass
    logger.info("FFmpeg stopped: session=%s", session_id)


async def stop_stream(session_id: str) -> None:
    """Kill the FFmpeg process for a session."""
    from services import session_router

    await _terminate_ffmpeg(session_id)
    # Free the session's slot in the encoder cap accounting (no-op if the
    # session was stream-copy and never reserved a slot).
    session_router.release_session(session_id)
    # Whether stop_stream is called after a clean run or after start_stream
    # already drained + dropped the stderr file, _drop_stderr is a no-op
    # when there's nothing to remove.
    _drop_stderr(session_id)
    # Per-session housekeeping for the seek-restart machinery — removes
    # the lock + counter on session end so they don't accumulate
    # forever in a long-running server.  Safe even if no seek ever ran.
    _seek_locks.pop(session_id, None)
    _discontinuity_seq.pop(session_id, None)
    _applied_seek_sec.pop(session_id, None)
    # Plan 20 — drop the fallback-transcode marker too.
    clear_session_force_transcode(session_id)


async def restart_stream(
    file_path: str,
    session_id: str,
    hls_root: Path,
    seek_sec: float,
    *,
    tonemap_hdr: bool = False,
    source_codec_override: str | None = None,
    duration_sec_override: float | None = None,
    library_row: dict | None = None,
) -> Path:
    """Re-spawn FFmpeg from ``seek_sec`` for an existing session.

    Used by the ``POST /api/v1/stream/{session_id}/seek`` endpoint when
    the user drags the seek bar past the encoded boundary.  The original
    architecture encoded strictly from t=0 and relied on the static VOD
    playlist + a 5-second segment-wait in the HLS router to absorb
    forward seeks — that works for tens-of-seconds drift but collapses
    the moment the seek lands far ahead of FFmpeg's current write
    position.

    Behaviour:

    1. Acquires the per-session restart lock so two seek calls in flight
       can't race each other.  The lock is released in a ``finally``.
    2. Terminates the active FFmpeg subprocess (no-op if it had already
       exited).  Does NOT release the encoder-cap slot — the same
       session is about to spawn again on the same encoder.
    3. Wipes ``seg*.{ts,m4s}`` and ``init.mp4`` from the session
       directory so the player's next request hits the new FFmpeg's
       output, not the previous spawn's stale data.  Keeps the playlist
       briefly so the HLS router has something to serve during the
       sub-second gap; ``start_stream`` overwrites it once spawn
       succeeds.
    4. Bumps the session's discontinuity-sequence counter.
    5. Calls ``start_stream`` with ``seek_sec`` and the new
       ``discontinuity_seq``.  ``start_stream`` aligns the seek to a
       segment boundary, builds the FFmpeg command with ``-ss`` +
       ``-start_number``, spawns, and writes a fresh static VOD
       playlist with ``#EXT-X-DISCONTINUITY-SEQUENCE`` +
       ``#EXT-X-DISCONTINUITY`` markers so the player flushes its
       decode buffer when it next loads the playlist.

    The caller (the seek endpoint) is responsible for cueing the player
    to re-fetch the playlist on the same URL — for media_kit / libmpv
    the way to do that is to re-open the ``Media`` object, which
    Commit 3 of the streaming pipeline plan adds in the mobile cubit.
    """
    lock = _get_seek_lock(session_id)
    async with lock:
        await _terminate_ffmpeg(session_id)
        _drop_stderr(session_id)

        # Wipe stale segments + init segment.  Leave the playlist in
        # place — start_stream overwrites it once spawn succeeds, and
        # in the brief window the HLS router serves stale segment
        # references (which then 404 + retry under its 5 s wait until
        # the new spawn produces seg<K>).
        session_dir = hls_root / session_id
        if session_dir.exists():
            for entry in session_dir.iterdir():
                name = entry.name
                if name.startswith("seg") or name == "init.mp4":
                    try:
                        entry.unlink()
                    except OSError:
                        logger.warning(
                            "Could not unlink %s during restart of session=%s",
                            entry,
                            session_id,
                            exc_info=True,
                        )

        # Bump the discontinuity sequence so the rewritten playlist tells
        # the player "what comes next is decoder-discontinuous from what
        # was there before".  Player libraries flush their decode buffer
        # on a sequence bump.
        next_seq = _discontinuity_seq.get(session_id, 0) + 1
        _discontinuity_seq[session_id] = next_seq

        logger.info(
            "Restarting stream: session=%s seek_sec=%.3f disc_seq=%d",
            session_id,
            seek_sec,
            next_seq,
        )

        return await start_stream(
            file_path,
            session_id,
            hls_root,
            tonemap_hdr=tonemap_hdr,
            seek_sec=seek_sec,
            discontinuity_seq=next_seq,
            source_codec_override=source_codec_override,
            duration_sec_override=duration_sec_override,
            library_row=library_row,
        )


async def test_encoder(
    encoder: str,
    hwaccel_device: str | None = None,
    timeout: float = 15.0,
) -> tuple[bool, str | None]:
    """Encode 1 second of a synthetic test pattern to verify the encoder works.

    Runs ``ffmpeg -f lavfi -i testsrc=duration=1`` through the configured
    encoder and immediately discards the output (``-f null -``).  A non-zero
    return code or a timeout means the encoder is broken / missing.

    Args:
        encoder: FFmpeg encoder name to test (e.g. ``"h264_nvenc"``).
        hwaccel_device: Optional VAAPI device path.  Ignored for non-VAAPI.
        timeout: Maximum seconds to wait before declaring failure.

    Returns:
        ``(passed, error)``.  ``passed`` is ``True`` iff FFmpeg exited with
        code 0.  ``error`` is the first non-empty stderr line on failure
        (truncated to 240 chars), or ``None`` on success.  The error is what
        the desktop UI surfaces in the failed-encoder modal — without it the
        operator can't tell a missing-driver case from a missing-binary case.
    """
    meta = ENCODER_REGISTRY.get(encoder)
    if meta is None:
        logger.warning("test_encoder: unknown encoder %r — skipping", encoder)
        return False, f"unknown encoder: {encoder!r}"

    try:
        ffmpeg = _ffmpeg_bin()
    except FileNotFoundError:
        logger.warning("test_encoder: FFmpeg not found")
        return False, "FFmpeg binary not found on PATH"

    cmd: list[str] = [ffmpeg, "-hide_banner", "-loglevel", "error"]
    cmd.extend(meta.pre_input_args(device=hwaccel_device))
    cmd.extend(["-f", "lavfi", "-i", "testsrc=duration=1:size=320x240:rate=25"])
    cmd.extend(meta.video_codec_args("veryfast", 28))
    cmd.extend(meta.filter_args())
    cmd.extend(["-an", "-f", "null", "-"])

    # Capture stderr to a tempfile (mirrors start_stream's pattern).  A PIPE
    # would deadlock if FFmpeg ever wrote more than the pipe buffer; tempfile
    # is unbounded and drained on completion.
    stderr_fd, stderr_path = tempfile.mkstemp(
        prefix=f"fluxora-test-{encoder}-", suffix=".log"
    )
    logger.info("Encoder self-test: encoder=%s", encoder)
    proc: asyncio.subprocess.Process | None = None
    try:
        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=stderr_fd,
            )
        finally:
            try:
                import os
                os.close(stderr_fd)
            except OSError:
                pass

        try:
            await asyncio.wait_for(proc.wait(), timeout=timeout)
        except TimeoutError:
            logger.warning(
                "Encoder self-test timed out after %.0fs: encoder=%s",
                timeout,
                encoder,
            )
            try:
                proc.kill()
                await proc.wait()
            except ProcessLookupError:
                pass
            return False, f"timed out after {timeout:.0f}s"
        except OSError as exc:
            logger.warning(
                "Encoder self-test failed (OSError): encoder=%s",
                encoder,
                exc_info=True,
            )
            return False, f"OS error: {exc}"

        passed = proc.returncode == 0
        if passed:
            logger.info(
                "Encoder self-test passed: encoder=%s returncode=%s",
                encoder,
                proc.returncode,
            )
            return True, None

        # Failure path — drain stderr, surface the first non-empty line.
        try:
            with Path(stderr_path).open("rb") as fh:
                fh.seek(0, 2)
                size = fh.tell()
                fh.seek(max(0, size - 4096))
                tail = fh.read().decode("utf-8", errors="replace")
        except OSError:
            tail = ""
        first_line = next(
            (line.strip() for line in tail.splitlines() if line.strip()),
            f"exit code {proc.returncode}",
        )
        # 240 chars is enough for any meaningful FFmpeg error (typical lines
        # are <120) without overflowing a notification toast.
        if len(first_line) > 240:
            first_line = first_line[:237] + "..."
        # DEBUG, not WARNING — `run_encoder_self_tests` is the single
        # source of truth for the user-facing log level.  When the failure
        # signature matches a known-actionable pattern (old Intel driver,
        # no iGPU on this machine, NVENC session cap) the outer caller
        # logs at INFO with a plain-language suggestion.  Logging WARNING
        # here too would double-spam the log with FFmpeg's raw stderr
        # right next to the friendly suggestion line.  The diagnostic is
        # still available on `--log-level=DEBUG` when needed.
        logger.debug(
            "Encoder self-test FAILED: encoder=%s returncode=%s error=%s",
            encoder,
            proc.returncode,
            first_line,
        )
        return False, first_line
    finally:
        try:
            Path(stderr_path).unlink(missing_ok=True)
        except OSError:
            logger.warning(
                "Could not unlink test_encoder stderr file: %s",
                stderr_path,
                exc_info=True,
            )


def cleanup_session_dir(session_id: str, hls_root: Path) -> None:
    """Delete the HLS segment directory for a session."""
    session_dir = hls_root / session_id
    if session_dir.exists():
        shutil.rmtree(session_dir, ignore_errors=True)
        logger.info("HLS dir removed: session=%s", session_id)


def is_running(session_id: str) -> bool:
    proc = _active.get(session_id)
    return proc is not None and proc.returncode is None
