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

    ``suggestion`` is populated when ``classify_encoder_failure`` recognises
    the stderr signature as a known-actionable case (old Intel driver,
    NVENC behind WDDM, etc.).  Surfaced in the desktop self-test card so
    end users — who can't read FFmpeg's MFX error codes — get a direct
    "do this" line instead of the cryptic upstream error.
    """

    passed: bool
    error: str | None  # First non-empty stderr line on failure; None on pass.
    tested_at: datetime  # UTC timestamp of when the test ran.
    suggestion: str | None = None


def classify_encoder_failure(encoder: str, error: str | None) -> str | None:
    """Map a known-bad encoder error to an end-user-actionable suggestion.

    The startup self-test surfaces FFmpeg's raw stderr.  That's diagnostic
    gold for someone who knows what ``MFX_ERR_NOT_FOUND`` means but useless
    to the average user.  This classifier fingerprints specific failure
    signatures and returns a one-line "fix" that the desktop UI shows.

    Returns ``None`` when no classifier matches — caller should fall back to
    the raw error string.

    Adding a new pattern: keep it specific (encoder + substring match), and
    write the suggestion in plain language pointing at the action the user
    can take without rebuilding anything.
    """
    if not error:
        return None
    err = error.lower()

    # Intel QSV — MFX session: -9 (MFX_ERR_NOT_FOUND) when the FFmpeg build
    # was compiled against oneVPL 2.x but the user's Intel graphics driver
    # only ships the legacy MSDK (libmfx 1.x) runtime.  Common on systems
    # with Intel drivers older than ~2022.  The hardware itself is fine;
    # only the runtime layer is mismatched.
    if encoder.endswith("_qsv") and "mfx session: -9" in err:
        return (
            "Your Intel Graphics driver predates the oneVPL runtime that "
            "this FFmpeg build expects.  Update via the Intel Driver & "
            "Support Assistant or install the Intel oneVPL GPU Runtime "
            "from the Microsoft Store to enable Quick Sync hardware "
            "transcoding.  Streaming will use the next encoder in the "
            "fallback chain in the meantime."
        )

    # Intel QSV — generic "no Intel iGPU available" case (vs. above where
    # the iGPU IS present but the runtime can't talk to it).  Matches the
    # signature when running on a system with NVIDIA-only or AMD-only GPUs.
    if encoder.endswith("_qsv") and (
        "no device available" in err or "device creation failed" in err
    ):
        return (
            "No Intel iGPU detected on this system.  Quick Sync requires "
            "Intel integrated graphics — your machine appears to use a "
            "different GPU vendor.  This encoder will be skipped; "
            "streaming will use the next encoder in the fallback chain."
        )

    # NVIDIA NVENC — driver present but session creation refused, typically
    # because the session cap is exceeded (GeForce cards limit concurrent
    # NVENC sessions to 3 unless you patch the driver).
    if encoder.endswith("_nvenc") and "openencodesessionex" in err:
        return (
            "NVIDIA NVENC refused a new session.  GeForce drivers cap "
            "concurrent NVENC sessions at 3 by default.  Reduce the "
            "max-streams setting or use a Quadro / RTX-A driver patch."
        )

    # Intel QSV HEVC — `Error querying encoder params: unsupported (-3)`
    # surfaces on iGPUs whose hardware media engine supports H.264 encode
    # but not HEVC encode.  UHD 620/630 (Kaby Lake / Coffee Lake era) are
    # the common offenders — H.264 QSV works fine on the same chip but
    # hevc_qsv fails with this exact stderr signature.  The user can't
    # fix this without different hardware, but the message keeps them
    # from chasing driver updates that won't help.
    if encoder.endswith("_qsv") and "error querying encoder params" in err:
        return (
            "This Intel iGPU's hardware media engine doesn't support HEVC "
            "encoding — H.264 Quick Sync still works on the same chip "
            "and will be used instead.  No driver update can fix this; "
            "HEVC encode requires newer Intel hardware (Ice Lake / Tiger "
            "Lake or later)."
        )

    return None


# Per-encoder self-test results.  Populated on first detection and on
# settings changes.  Missing key = "not yet tested".
_TEST_RESULTS: dict[str, EncoderTestResult] = {}


def get_test_results() -> dict[str, EncoderTestResult]:
    """Read-only snapshot of the encoder self-test cache.

    Used by `services/support_bundle_service.py` to capture the most
    recent probe results without re-running them. Returns a shallow
    copy so callers can iterate without holding a reference to the
    live mutable dict.
    """
    return dict(_TEST_RESULTS)


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
        name
        for name in ALL_KNOWN_ENCODERS
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
        SELECT s.id, s.client_id, s.progress_sec, s.encoder_used,
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
                "encoder_used": row["encoder_used"],
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
            "encoder_tested_at": (result.tested_at.isoformat() if result else None),
            "encoder_test_suggestion": result.suggestion if result else None,
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


async def run_encoder_self_tests(
    available: list[str], hwaccel_device: str | None
) -> None:
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
        suggestion = classify_encoder_failure(enc, error) if not passed else None
        _TEST_RESULTS[enc] = EncoderTestResult(
            passed=passed,
            error=error,
            tested_at=now,
            suggestion=suggestion,
        )
        if not passed:
            # Known-actionable failures (old Intel driver, no iGPU on the
            # box, NVENC session cap, ...) log at INFO with the suggestion
            # — the priority chain transparently falls back, so this is
            # informational rather than a problem the operator must solve.
            # Anything we don't recognise stays at WARNING so unexpected
            # failures still surface in the log.
            if suggestion:
                logger.info("Encoder self-test skipped — %s: %s", enc, suggestion)
            else:
                logger.warning(
                    "Encoder self-test FAILED — %s: %s",
                    enc,
                    error or "(no error captured)",
                )


_ENCODER_LABELS = {
    "h264_qsv": "H.264 (Intel Quick Sync)",
    "hevc_qsv": "HEVC (Intel Quick Sync)",
    "av1_qsv": "AV1 (Intel Quick Sync)",
    "h264_nvenc": "H.264 (NVIDIA NVENC)",
    "hevc_nvenc": "HEVC (NVIDIA NVENC)",
    "av1_nvenc": "AV1 (NVIDIA NVENC)",
    "h264_vaapi": "H.264 (AMD/Linux VA-API)",
    "hevc_vaapi": "HEVC (AMD/Linux VA-API)",
    "h264_videotoolbox": "H.264 (Apple VideoToolbox)",
    "hevc_videotoolbox": "HEVC (Apple VideoToolbox)",
}


async def emit_encoder_failure_notifications(db: aiosqlite.Connection) -> int:
    """Surface classifier suggestions to the desktop notification bell.

    A log line at INFO is invisible unless the operator opens the Logs
    screen.  Users who never look there will never know that Quick Sync
    is sitting there waiting on a driver update, even though we worked
    out exactly what they need to do.  This emits one notification per
    encoder with a recognised failure suggestion so the desktop's
    notifications panel surfaces the actionable bit.

    Deduplication mirrors the storage-warning pattern in
    `library_service.get_storage_breakdown`: skip if a non-dismissed
    notification already exists for the same `(category, related_id)`
    pair within the last day.  Without dedup, a server restart loop
    would spam the bell.

    Returns the count of notifications actually inserted.
    """
    from services import notification_service

    inserted = 0
    for encoder, result in _TEST_RESULTS.items():
        if result.passed or not result.suggestion:
            continue
        async with db.execute(
            """
            SELECT id FROM notifications
             WHERE category = 'transcode'
               AND related_kind = 'encoder'
               AND related_id = ?
               AND created_at > datetime('now', '-1 day')
               AND dismissed_at IS NULL
             LIMIT 1
            """,
            (encoder,),
        ) as cur:
            existing = await cur.fetchone()
        if existing is not None:
            continue
        label = _ENCODER_LABELS.get(encoder, encoder)
        try:
            await notification_service.create(
                db,
                type="warning",
                category="transcode",
                title=f"{label} unavailable",
                message=result.suggestion,
                related_kind="encoder",
                related_id=encoder,
            )
            inserted += 1
        except Exception:
            logger.warning(
                "Failed to emit encoder-suggestion notification for %s",
                encoder,
                exc_info=True,
            )
    return inserted
