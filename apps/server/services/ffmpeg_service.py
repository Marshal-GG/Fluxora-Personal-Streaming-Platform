import asyncio
import json
import logging
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
    """Run ffprobe on the first video stream; return width/height/codec/hdr.

    Returns None when ffprobe is not installed, the file is not a decodable
    video, or the stream list is empty. Callers must treat the response as
    advisory — scan completion never depends on probe success.
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
    return {
        "width": int(width) if isinstance(width, int) else None,
        "height": int(height) if isinstance(height, int) else None,
        "codec_name": stream.get("codec_name"),
        "hdr_format": _detect_hdr_format(stream),
    }


async def _resolve_source_codec(db, file_path: str, file_id: str | None) -> str | None:
    """Return the source video codec name, probing on-demand if needed.

    Files scanned before migration 016 (or before the FFprobe-at-scan
    step) have `codec_name IS NULL` — they would silently transcode even
    when the source is stream-copy-eligible.  Probe lazily and persist
    the result so the next playback of the same file is fast.
    """
    async with db.execute(
        "SELECT id, codec_name, width, height, hdr_format FROM media_files"
        " WHERE path = ?",
        (file_path,),
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        return None
    if row["codec_name"]:
        return row["codec_name"]

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
        return None

    # Persist the probe result so the next play is constant-time.  We
    # already have the row id; mirror `library_service._persist_probe`
    # without importing it (avoids a circular dep — that module imports
    # `probe_video` from us).
    from datetime import UTC, datetime

    try:
        await db.execute(
            "UPDATE media_files SET width = ?, height = ?, codec_name = ?,"
            "  hdr_format = ?, updated_at = ?"
            " WHERE id = ?",
            (
                info["width"],
                info["height"],
                info["codec_name"],
                info["hdr_format"],
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
    return info["codec_name"]


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


# Substrings in FFmpeg stderr that indicate the cuvid hardware decoder
# rejected the source.  When we see any of these in a failed-attempt's
# stderr tail, retry the pipeline once without the cuvid hint so the
# software decoder gets a chance — covers HDR / 12-bit / 4:4:4 sources
# that NVDEC AV1 (or similar) won't accept on the operator's GPU.
_CUVID_FAILURE_MARKERS: tuple[str, ...] = (
    "cuvid is not supported",
    "not supported with this chroma format",
    "cuvid",  # broad catch-all — any cuvid-tagged error in the tail
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
    use_cuvid: bool,
) -> list[str]:
    """Compose the FFmpeg command line.

    Split out from ``start_stream`` so the cuvid-failure retry path can
    rebuild the command with ``use_cuvid=False`` without duplicating the
    HLS flag block.
    """
    cmd: list[str] = [_ffmpeg_bin(), "-hide_banner", "-loglevel", "error"]

    if not direct_remux:
        # Pre-input hardware acceleration flags (empty list for software).
        cmd.extend(meta.pre_input_args(device=hwaccel_device))
        # Force the input decoder when FFmpeg's auto-selection is known
        # to break (e.g. AV1 software decode on the bundled build).
        # Skipped on the retry pass after a cuvid failure.
        if use_cuvid:
            cmd.extend(_input_decoder_args(source_codec, meta))

    cmd.extend(["-i", file_path])

    if direct_remux:
        cmd.extend(["-c:v", "copy"])
    else:
        cmd.extend(meta.video_codec_args(preset, crf))
        cmd.extend(meta.filter_args())

    cmd.extend(["-c:a", "aac", "-b:a", "128k"])

    use_fmp4 = direct_remux_hevc or (
        not direct_remux and meta.segment_fmt == "fmp4"
    )
    hls_time = "10" if direct_remux else "6"
    common_hls = [
        "-f", "hls",
        "-hls_time", hls_time,
        "-hls_list_size", "0",
    ]
    if not direct_remux:
        common_hls.extend(["-hls_flags", "independent_segments"])

    if use_fmp4:
        cmd.extend(common_hls + [
            "-hls_segment_type", "fmp4",
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
    """Heuristically classify a stderr tail as a cuvid-rejection failure."""
    lower = stderr_tail.lower()
    return any(marker in lower for marker in _CUVID_FAILURE_MARKERS)


async def _spawn_ffmpeg_attempt(
    cmd: list[str],
    session_id: str,
    playlist: Path,
) -> tuple[bool, str, int | None]:
    """Run one FFmpeg attempt; return (succeeded, stderr_tail, returncode).

    On success the playlist appeared within 10 s and the process is still
    running.  On failure the process either exited prematurely or the
    playlist never appeared in time; the stderr tail is drained and the
    process killed.  The session's stderr file is unlinked in either
    case so retries get a fresh capture.
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
        )
    finally:
        try:
            import os
            os.close(stderr_fd)
        except OSError:
            pass

    _active[session_id] = proc
    logger.info("FFmpeg started: session=%s pid=%d", session_id, proc.pid)

    for _ in range(100):
        if playlist.exists():
            return True, "", None
        if proc.returncode is not None:
            tail = _drain_stderr(session_id)
            _drop_stderr(session_id)
            _active.pop(session_id, None)
            return False, tail, proc.returncode
        await asyncio.sleep(0.1)

    # Playlist never appeared within 10 s but the process is still alive —
    # kill it and capture whatever stderr exists.
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
    return False, tail, proc.returncode


async def start_stream(
    file_path: str,
    session_id: str,
    hls_root: Path,
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
    from services import settings_service

    db = await get_db()
    settings_row = await settings_service.get_settings(db)

    encoder: str = settings_row.get("transcoding_encoder", "libx264") or "libx264"
    preset: str = settings_row.get("transcoding_preset", "veryfast") or "veryfast"
    crf: int = int(settings_row.get("transcoding_crf", 23) or 23)
    hwaccel_device: str | None = settings_row.get("transcoding_hwaccel_device")

    meta: EncoderMeta = ENCODER_REGISTRY.get(encoder, ENCODER_REGISTRY["libx264"])
    if meta.name != encoder:
        logger.warning(
            "Unknown encoder %r in settings — falling back to libx264", encoder
        )

    source_codec = await _resolve_source_codec(db, file_path, None)
    direct_remux_h264 = source_codec == "h264"
    direct_remux_hevc = source_codec in ("hevc", "h265")
    direct_remux = direct_remux_h264 or direct_remux_hevc

    session_dir = hls_root / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    playlist = session_dir / "playlist.m3u8"

    use_fmp4 = direct_remux_hevc or (
        not direct_remux and meta.segment_fmt == "fmp4"
    )
    if direct_remux_hevc:
        mode = "stream-copy(hevc/fmp4)"
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

    # First attempt — with cuvid hint if applicable.
    cmd = _build_ffmpeg_cmd(
        file_path=file_path,
        session_dir=session_dir,
        playlist=playlist,
        meta=meta,
        preset=preset,
        crf=crf,
        hwaccel_device=hwaccel_device,
        source_codec=source_codec,
        direct_remux=direct_remux,
        direct_remux_hevc=direct_remux_hevc,
        use_cuvid=True,
    )
    succeeded, tail, returncode = await _spawn_ffmpeg_attempt(
        cmd, session_id, playlist
    )

    # Retry once if cuvid blew up — software decode might still work.
    cuvid_was_used = bool(_input_decoder_args(source_codec, meta))
    if not succeeded and cuvid_was_used and _is_cuvid_failure(tail):
        logger.warning(
            "cuvid decoder rejected source (session=%s); retrying without "
            "cuvid hint.  Original stderr tail:\n%s",
            session_id,
            tail or "<empty>",
        )
        cmd = _build_ffmpeg_cmd(
            file_path=file_path,
            session_dir=session_dir,
            playlist=playlist,
            meta=meta,
            preset=preset,
            crf=crf,
            hwaccel_device=hwaccel_device,
            source_codec=source_codec,
            direct_remux=direct_remux,
            direct_remux_hevc=direct_remux_hevc,
            use_cuvid=False,
        )
        succeeded, tail, returncode = await _spawn_ffmpeg_attempt(
            cmd, session_id, playlist
        )

    if succeeded:
        return playlist

    # Both attempts failed (or the only attempt did) — surface the
    # captured stderr tail to the operator-facing notification.
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


async def stop_stream(session_id: str) -> None:
    """Kill the FFmpeg process for a session."""
    proc = _active.pop(session_id, None)
    if proc and proc.returncode is None:
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
    # Whether stop_stream is called after a clean run or after start_stream
    # already drained + dropped the stderr file, _drop_stderr is a no-op
    # when there's nothing to remove.
    _drop_stderr(session_id)


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
        logger.warning(
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
