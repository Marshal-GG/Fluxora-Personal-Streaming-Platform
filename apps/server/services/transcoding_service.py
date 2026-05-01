"""Transcoding status feed for the desktop Transcoding screen.

Aggregates: the configured encoder + the set of encoders FFmpeg knows
about + per-encoder load counts (and a best-effort GPU probe) + a list
of currently-active stream sessions.

GPU probes are best-effort. If `nvidia-smi` / `intel_gpu_top` /
`radeontop` aren't on PATH or fail, the corresponding fields return
`None` rather than raising. The desktop UI shows '–' for null values.

The list of "available encoders" is the intersection of (a) the four
encoders the server knows how to drive (libx264, h264_nvenc,
h264_qsv, h264_vaapi) and (b) what `ffmpeg -encoders` reports — so a
build of FFmpeg without NVENC won't surface NVENC as available.
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any

import aiosqlite

from services import settings_service
from services.ffmpeg_service import _active, _ffmpeg_bin

logger = logging.getLogger(__name__)

_KNOWN_ENCODERS = ["libx264", "h264_nvenc", "h264_qsv", "h264_vaapi"]
_AVAILABLE_CACHE: list[str] | None = None


# ── encoder discovery ──────────────────────────────────────────────────────


async def _detect_available_encoders() -> list[str]:
    """Run `ffmpeg -encoders` once; cache the result for the process lifetime.

    The encoder list doesn't change without restarting the server (binary or
    drivers haven't moved), so a process-wide cache is safe.
    """
    global _AVAILABLE_CACHE
    if _AVAILABLE_CACHE is not None:
        return _AVAILABLE_CACHE

    try:
        bin_path = _ffmpeg_bin()
    except FileNotFoundError:
        _AVAILABLE_CACHE = []
        return _AVAILABLE_CACHE

    try:
        proc = await asyncio.create_subprocess_exec(
            bin_path,
            "-hide_banner",
            "-encoders",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        out, _ = await asyncio.wait_for(proc.communicate(), timeout=5.0)
    except (TimeoutError, OSError) as exc:
        logger.warning("ffmpeg -encoders probe failed: %s", exc)
        _AVAILABLE_CACHE = []
        return _AVAILABLE_CACHE

    text = out.decode(errors="replace")
    found = [enc for enc in _KNOWN_ENCODERS if enc in text]
    _AVAILABLE_CACHE = found
    logger.info("Detected available encoders: %s", found)
    return found


# ── GPU / CPU probes ────────────────────────────────────────────────────────


async def _run_probe(args: list[str], timeout: float = 1.5) -> str | None:
    """Run a probe command and return stdout, or None on failure."""
    try:
        proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        out, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except (TimeoutError, OSError, FileNotFoundError):
        return None
    if proc.returncode != 0:
        return None
    return out.decode(errors="replace").strip()


async def _probe_nvidia() -> tuple[float | None, int | None]:
    """Returns (gpu_util%, vram_used_mb). NVIDIA only."""
    out = await _run_probe(
        [
            "nvidia-smi",
            "--query-gpu=utilization.gpu,memory.used",
            "--format=csv,noheader,nounits",
        ]
    )
    if not out:
        return None, None
    # Format example: "34, 580" — first GPU only in v1.
    first_line = out.splitlines()[0] if out else ""
    parts = [p.strip() for p in first_line.split(",")]
    if len(parts) != 2:
        return None, None
    try:
        return float(parts[0]), int(parts[1])
    except ValueError:
        return None, None


# ── session aggregation ────────────────────────────────────────────────────


async def _list_active_sessions(
    db: aiosqlite.Connection,
) -> list[dict[str, Any]]:
    """Active sessions joined with media_files + clients for the UI."""
    async with db.execute(
        """
        SELECT s.id, s.client_id, s.progress_sec,
               m.title       AS media_title,
               m.name        AS media_name,
               m.duration_sec,
               c.name        AS client_name
          FROM stream_sessions s
     LEFT JOIN media_files m ON m.id = s.file_id
     LEFT JOIN clients     c ON c.id = s.client_id
         WHERE s.ended_at IS NULL
         ORDER BY s.started_at DESC
        """
    ) as cur:
        rows = await cur.fetchall()

    sessions: list[dict[str, Any]] = []
    for row in rows:
        progress: float | None = None
        if row["duration_sec"] and row["progress_sec"] is not None:
            try:
                progress = max(
                    0.0,
                    min(1.0, float(row["progress_sec"]) / float(row["duration_sec"])),
                )
            except (ValueError, ZeroDivisionError):
                progress = None
        sessions.append(
            {
                "id": row["id"],
                "client_id": row["client_id"],
                "client_name": row["client_name"],
                "media_title": row["media_title"] or row["media_name"],
                # input_codec / output_codec / fps / speed_x are not currently
                # tracked at the session level — placeholders for future work.
                "input_codec": None,
                "output_codec": "h264",
                "fps": None,
                "speed_x": None,
                "progress": progress,
            }
        )
    return sessions


# ── public API ──────────────────────────────────────────────────────────────


async def get_status(db: aiosqlite.Connection) -> dict[str, Any]:
    settings_row = await settings_service.get_settings(db)
    active_encoder = settings_row.get("transcoding_encoder") or "libx264"

    available = await _detect_available_encoders()

    # In v1 every active session uses the configured encoder, so the load
    # count is the live FFmpeg-process count; we attribute it all to
    # `active_encoder`. Other listed encoders show 0 active sessions.
    live_count = len(_active)

    encoder_loads: list[dict[str, Any]] = []
    for enc in available or [active_encoder]:
        load: dict[str, Any] = {
            "encoder": enc,
            "active_sessions": live_count if enc == active_encoder else 0,
            "gpu_utilization_percent": None,
            "vram_used_mb": None,
            "cpu_utilization_percent": None,
        }
        if enc == "h264_nvenc" and enc == active_encoder:
            util, vram = await _probe_nvidia()
            load["gpu_utilization_percent"] = util
            load["vram_used_mb"] = vram
        # QSV / VAAPI probes (intel_gpu_top, radeontop) are best-effort and
        # vary too much by distro to ship reliably; left as null in v1.
        encoder_loads.append(load)

    sessions = await _list_active_sessions(db)

    return {
        "active_encoder": active_encoder,
        "available_encoders": available,
        "encoder_loads": encoder_loads,
        "active_sessions": sessions,
    }
