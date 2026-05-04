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
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import aiosqlite

from services import settings_service
from services.encoder_registry import ALL_KNOWN_ENCODERS, ENCODER_REGISTRY
from services.ffmpeg_service import _active, _ffmpeg_bin

logger = logging.getLogger(__name__)

_AVAILABLE_CACHE: list[str] | None = None


@dataclass(frozen=True)
class EncoderTestResult:
    """Outcome of a single encoder self-test.

    Carries enough information for the desktop's failed-encoder modal to
    explain *why* an encoder isn't usable — a bare ``passed: bool`` would
    leave the operator guessing between "missing GPU driver" / "missing
    FFmpeg build feature" / "stale device path".
    """

    passed: bool
    error: str | None  # First non-empty stderr line on failure; None on pass.
    tested_at: datetime  # UTC timestamp of when the test ran.


# Per-encoder self-test results.  Populated on first detection and on
# settings changes.  Missing key = "not yet tested".
_TEST_RESULTS: dict[str, EncoderTestResult] = {}


# ── encoder discovery ──────────────────────────────────────────────────────


async def _detect_available_encoders() -> list[str]:
    """Run `ffmpeg -encoders` once; cache the result for the process lifetime.

    The encoder list doesn't change without restarting the server (binary or
    drivers haven't moved), so a process-wide cache is safe.
    Platform filtering runs first: encoders that can't exist on this OS are
    excluded before running the FFmpeg probe, saving a string search.
    """
    global _AVAILABLE_CACHE
    if _AVAILABLE_CACHE is not None:
        return _AVAILABLE_CACHE

    try:
        bin_path = _ffmpeg_bin()
    except FileNotFoundError:
        _AVAILABLE_CACHE = []
        return _AVAILABLE_CACHE

    # Filter by platform first — VideoToolbox never appears on Windows, etc.
    platform_candidates = [
        name for name in ALL_KNOWN_ENCODERS
        if ENCODER_REGISTRY[name].is_platform_supported()
    ]

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
    found = [enc for enc in platform_candidates if enc in text]
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
    first_line = out.splitlines()[0] if out else ""
    parts = [p.strip() for p in first_line.split(",")]
    if len(parts) != 2:
        return None, None
    try:
        return float(parts[0]), int(parts[1])
    except ValueError:
        return None, None


async def _probe_intel_qsv() -> tuple[float | None, int | None]:
    """Returns (render_busy%, None). Intel QSV via intel_gpu_top.

    ``intel_gpu_top`` outputs a JSON stream with one object per sample.
    We request a single dump (``-s 250`` = 250 ms sample, ``-J`` = JSON).
    VRAM is not exposed by intel_gpu_top; we return None for it.
    """
    out = await _run_probe(["intel_gpu_top", "-J", "-s", "250"], timeout=2.0)
    if not out:
        return None, None
    # intel_gpu_top JSON: [{"period":{...},"engines":{"Render/3D/0":{"busy":34.5},...}}]
    import json as _json

    try:
        samples = _json.loads(out)
        if not samples:
            return None, None
        engines = samples[-1].get("engines", {})
        # Sum all render engines — usually just one.
        render_vals = [
            v.get("busy", 0.0)
            for k, v in engines.items()
            if "render" in k.lower() or "3d" in k.lower()
        ]
        util = sum(render_vals) / max(len(render_vals), 1)
        return round(util, 1), None
    except Exception:  # noqa: BLE001
        return None, None


async def _probe_amd_vaapi() -> tuple[float | None, int | None]:
    """Returns (gpu%, None). AMD via radeontop.

    ``radeontop -d - -l 1`` dumps one CSV line to stdout and exits.
    Format example: ``1746355062.873931, gpu 12.00%, vram 5.00% 131072000b, ...``
    """
    out = await _run_probe(["radeontop", "-d", "-", "-l", "1"], timeout=2.5)
    if not out:
        return None, None
    import re

    m = re.search(r"gpu\s+([\d.]+)%", out, re.IGNORECASE)
    if not m:
        return None, None
    try:
        return float(m.group(1)), None
    except ValueError:
        return None, None


async def _probe_videotoolbox() -> tuple[float | None, int | None]:
    """Returns (None, vram_mb). Apple VideoToolbox — utilization not available
    without sudo; we surface VRAM from system_profiler.
    """
    out = await _run_probe(
        ["system_profiler", "SPDisplaysDataType", "-json"], timeout=3.0
    )
    if not out:
        return None, None
    import json as _json

    try:
        data = _json.loads(out)
        displays = data.get("SPDisplaysDataType", [])
        for gpu in displays:
            vram_str: str = gpu.get("spdisplays_vram", "")
            # e.g. "8192 MB" or "1 GB"
            parts = vram_str.split()
            if len(parts) == 2:
                amount = float(parts[0])
                unit = parts[1].upper()
                if unit == "GB":
                    return None, int(amount * 1024)
                if unit == "MB":
                    return None, int(amount)
    except Exception:  # noqa: BLE001
        pass
    return None, None


# Vendor → probe function *name* (resolved via getattr at call time so that
# `patch.object(transcoding_service, "_probe_nvidia", ...)` in tests — and any
# other late-binding swap — actually intercepts the call.  A direct
# function-reference dict captures the original implementation at module load
# and silently bypasses the patch.
_VENDOR_PROBE: dict[str, str] = {
    "nvidia": "_probe_nvidia",
    "intel": "_probe_intel_qsv",
    "amd": "_probe_amd_vaapi",
    "apple": "_probe_videotoolbox",
}


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
        meta = ENCODER_REGISTRY.get(enc)
        gpu_engine = meta.hwaccel if meta else None
        result = _TEST_RESULTS.get(enc)

        load: dict[str, Any] = {
            "encoder": enc,
            "active_sessions": live_count if enc == active_encoder else 0,
            "gpu_utilization_percent": None,
            "vram_used_mb": None,
            "cpu_utilization_percent": None,
            "gpu_engine": gpu_engine,
            "encoder_test_passed": result.passed if result else None,
            "encoder_test_error": result.error if result else None,
            "encoder_tested_at": (
                result.tested_at.isoformat() if result else None
            ),
        }

        # Dispatch GPU stats to the correct probe based on vendor.  Resolve
        # the probe via globals() so monkeypatching the module attribute in
        # tests is honoured.
        if meta and meta.vendor in _VENDOR_PROBE and enc == active_encoder:
            probe = globals()[_VENDOR_PROBE[meta.vendor]]
            util, vram = await probe()
            load["gpu_utilization_percent"] = util
            load["vram_used_mb"] = vram

        encoder_loads.append(load)

    sessions = await _list_active_sessions(db)

    return {
        "active_encoder": active_encoder,
        "available_encoders": available,
        "encoder_loads": encoder_loads,
        "active_sessions": sessions,
    }


async def run_encoder_self_tests(available: list[str], hwaccel_device: str | None) -> None:
    """Run self-tests for all detected encoders; populate ``_TEST_RESULTS``.

    Called once at server startup (non-blocking background task) and
    whenever the operator changes ``transcoding_encoder`` via the settings
    API.  Software encoders (libx264, libx265) always pass.
    """
    from services.ffmpeg_service import test_encoder

    for enc in available:
        now = datetime.now(UTC)
        meta = ENCODER_REGISTRY.get(enc)
        if meta and meta.vendor == "software":
            # Software encoders don't need a runtime test — libx264 is always
            # present if FFmpeg reported it in -encoders.
            _TEST_RESULTS[enc] = EncoderTestResult(
                passed=True, error=None, tested_at=now
            )
            continue
        passed, error = await test_encoder(enc, hwaccel_device=hwaccel_device)
        _TEST_RESULTS[enc] = EncoderTestResult(
            passed=passed, error=error, tested_at=now
        )
        if not passed:
            logger.warning(
                "Encoder self-test FAILED — %s: %s", enc, error or "(no error captured)"
            )
