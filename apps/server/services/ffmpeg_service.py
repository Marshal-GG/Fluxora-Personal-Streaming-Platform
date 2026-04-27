import asyncio
import logging
import shutil
import sys
from pathlib import Path

logger = logging.getLogger(__name__)

# Active sessions: session_id → asyncio.subprocess.Process
_active: dict[str, asyncio.subprocess.Process] = {}


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


async def start_stream(
    file_path: str,
    session_id: str,
    hls_root: Path,
) -> Path:
    """Spawn FFmpeg for HLS transcode; return the .m3u8 playlist path."""
    session_dir = hls_root / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    playlist = session_dir / "playlist.m3u8"

    cmd = [
        _ffmpeg_bin(),
        "-i",
        file_path,
        "-c:v",
        "libx264",
        "-preset",
        "veryfast",
        "-crf",
        "23",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        "-f",
        "hls",
        "-hls_time",
        "6",
        "-hls_list_size",
        "0",
        "-hls_segment_type",
        "mpegts",
        "-hls_flags",
        "independent_segments",
        "-hls_segment_filename",
        str(session_dir / "seg%05d.ts"),
        str(playlist),
    ]

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.PIPE,
    )
    _active[session_id] = proc
    logger.info("FFmpeg started: session=%s pid=%d", session_id, proc.pid)
    return playlist


async def stop_stream(session_id: str) -> None:
    """Kill the FFmpeg process for a session and clean up its temp directory."""
    proc = _active.pop(session_id, None)
    if proc and proc.returncode is None:
        try:
            proc.kill()
            await proc.wait()
        except ProcessLookupError:
            pass
        logger.info("FFmpeg stopped: session=%s", session_id)


def cleanup_session_dir(session_id: str, hls_root: Path) -> None:
    """Delete the HLS segment directory for a session."""
    session_dir = hls_root / session_id
    if session_dir.exists():
        shutil.rmtree(session_dir, ignore_errors=True)
        logger.info("HLS dir removed: session=%s", session_id)


def is_running(session_id: str) -> bool:
    proc = _active.get(session_id)
    return proc is not None and proc.returncode is None
