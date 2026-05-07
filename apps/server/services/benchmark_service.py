"""Encoder benchmark — short FFmpeg encode per encoder for performance comparison.

Used by the desktop Encoder Settings → "Run Benchmark" button.  Differs from
``test_encoder``/``run_encoder_self_tests`` (in :mod:`services.transcoding_service`)
in that it produces *measurements* (fps, speed, bitrate, init time, GPU sample,
concurrent capacity) rather than a binary pass/fail.

Both run a synthetic ``lavfi testsrc`` source through the encoder; the benchmark
uses a multi-second clip so the numbers are stable past the encoder's startup
transient (NVENC needs ~500 ms to spin up CUDA + the encoder session).

Output is muxed into ``mpegts`` and piped to stdout DEVNULL — ``-f null -``
discards bytes before the muxer measures them, which leaves every progress line
with ``bitrate=N/A``; mpegts keeps the bitrate counter live without touching
disk.

Stderr is streamed (not written to a tempfile) so we can timestamp the first
``frame=N≥1`` line — that's the wall-clock-from-spawn ``init_ms`` value the UI
shows.

For hardware encoders, a midpoint GPU probe samples the vendor-specific tool
(``nvidia-smi`` / ``intel_gpu_top`` / ``radeontop`` / ``system_profiler``) at
``duration_sec / 2`` so the operator sees how saturated the silicon was during
the run.

Sequential, not parallel: running multiple encodes concurrently would contend
for GPU + CPU and produce noise instead of comparable per-encoder numbers.
"""

from __future__ import annotations

import asyncio
import logging
import math
import re
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from services.encoder_registry import ENCODER_REGISTRY
from services.ffmpeg_service import _ffmpeg_bin

logger = logging.getLogger(__name__)


# Defaults pick a workload large enough to amortise GPU init cost (~500 ms on
# NVENC) but small enough to bound total run time across N encoders.  720p30 is
# representative of typical streamed content; 8 s × 30 fps = 240 frames per
# encoder, so a 4-encoder system finishes in ~10–15 s wall-clock on hardware
# encoders and 30–60 s if libx264/libx265 are in the mix on a slow CPU.
_DEFAULT_DURATION_SEC = 8
_DEFAULT_SIZE = "1280x720"
_DEFAULT_FPS = 30

# Hard ceiling per encoder.  Software libx265 on a slow CPU can be 4× slower
# than realtime, so 8 s of source = 32 s wall.  We clamp at 35 s and report a
# timeout (still useful information — the operator learns the encoder is too
# slow for their hardware to ever drive a live stream).
_PER_ENCODER_TIMEOUT = 35.0

# Clamp range applied to the operator-supplied duration.  2 s minimum so the
# numbers aren't dominated by startup transient; 20 s maximum so a careless
# request can't hold the event loop for 5 minutes.
_MIN_DURATION = 2
_MAX_DURATION = 20

# Frame-rate clamp.  24 covers cinema; 60 covers gaming captures and sports.
# Beyond 60 fps adds nothing actionable for a media-streaming server — most
# library content is ≤30, the player doesn't render high-refresh material
# specially, and the encoder workload from going to 120 just hides hardware
# differences behind a uniformly-sub-realtime ceiling.
_MIN_FPS = 24
_MAX_FPS = 60

# Stderr reader chunk size.  Bigger than typical FFmpeg progress lines (~100 B
# each) so we usually pick up several at once; small enough that the first
# ``frame=`` line lands within one read after the encoder produces it.
_STDERR_READ_CHUNK = 4096

# Drain budget after the process exits — the reader task should normally see
# EOF immediately, but Windows pipe semantics can take a few hundred ms in
# pathological cases.
_READER_DRAIN_TIMEOUT = 2.0

# Per-vendor probe attribute name on ``transcoding_service``.  Resolved via
# getattr so test monkeypatches on the module are honoured.
_VENDOR_PROBE: dict[str, str] = {
    "nvidia": "_probe_nvidia",
    "intel": "_probe_intel_qsv",
    "amd": "_probe_amd_vaapi",
    "apple": "_probe_videotoolbox",
}


# FFmpeg progress lines look like:
#   frame=  240 fps= 30 q=23.0 size=N/A time=00:00:08.00 bitrate=N/A speed=1.05x
# The final summary that lands after the muxer closes carries the most stable
# numbers — we walk stderr backwards and pick the last line carrying both
# ``fps=`` and ``speed=`` markers.
_FPS_RE = re.compile(r"fps\s*=\s*([\d.]+)")
_SPEED_RE = re.compile(r"speed\s*=\s*([\d.]+)x")
_BITRATE_RE = re.compile(r"bitrate\s*=\s*([\d.]+)\s*kbits/s")
_FRAME_RE = re.compile(r"frame\s*=\s*(\d+)")


# Tokens that mark a line as an actual FFmpeg error rather than the
# header / stream-mapping / informational chatter that comes before it.
# Lower-cased; matched as substrings.  Order doesn't matter — first
# match wins.
_ERROR_MARKERS = (
    "error",
    "failed",
    "could not",
    "unable to",
    "invalid",
    "unsupported",
    "no such",
    "not found",
)


def _pick_error_line(stderr_text: str) -> str | None:
    """Return the most informative error line from FFmpeg stderr.

    The naive "first non-empty line" picker grabs FFmpeg's input-file
    header (``Input #0, lavfi, from 'testsrc=...'``) — informational,
    not the actual failure.  This walks stderr looking for a line that
    contains one of the known error markers, then falls back to the
    *last* non-empty line (typically ``Conversion failed!``) before
    finally giving up and returning the first line.
    """
    lines = [ln.strip() for ln in stderr_text.splitlines() if ln.strip()]
    if not lines:
        return None

    for line in lines:
        lower = line.lower()
        if any(marker in lower for marker in _ERROR_MARKERS):
            return line

    return lines[-1]


@dataclass(frozen=True)
class EncoderBenchmarkResult:
    """One encoder's benchmark outcome.

    ``passed=True`` means the encode completed with exit 0; the perf fields
    will be populated unless FFmpeg's stderr was unusual enough that the
    parser failed to find them (rare).

    ``passed=False`` means the encode failed or timed out; ``error`` carries
    the actual error line (via :func:`_pick_error_line`), and the perf fields
    are ``None``.

    ``elapsed_sec`` is wall-clock from process spawn to exit/kill.
    ``realtime_multiplier`` = source_duration / elapsed_sec.  Values > 1
    mean the encoder runs faster than realtime (i.e. could drive a live
    stream), values < 1 mean the encoder is slower than realtime and would
    underrun on a live stream.

    ``init_ms`` is wall-clock from spawn to the first ``frame=N≥1`` progress
    line — the operator's "how long until first segment appears" budget.
    Includes CUDA context init / encoder session creation / device probe etc.

    ``gpu_utilization_percent`` and ``vram_used_mb`` are sampled once at the
    midpoint of the run via the same per-vendor probes the live status panel
    uses.  Null for software encoders or when the probe binary is missing.

    ``concurrent_session_cap`` mirrors :class:`services.encoder_registry.EncoderMeta`
    — NVENC consumer cards = 3, software/QSV/VAAPI/VideoToolbox = None.
    Treat it as a *vendor-documented default*: NVIDIA's driver 530+ removed
    the consumer cap on RTX 40-series, and community patches (keylase) lift
    it on older cards.

    ``verified_concurrent`` is the *empirical* answer from
    :func:`probe_concurrent_cap` — how many concurrent encodes actually
    succeeded on the operator's hardware/driver.  Only populated when the
    benchmark was invoked with ``verify_caps=True`` and the encoder has a
    registry cap to verify.  When present, ``recommended_concurrent`` is
    re-derived against this value rather than the registry default.

    ``recommended_concurrent`` collapses ``min(effective_cap, floor(speed_x))``
    into a single integer so the desktop UI can render "you can sustain N
    streams" without needing the cap values separately.
    """

    encoder: str
    vendor: str  # software | nvidia | intel | amd | apple
    codec: str   # h264 | hevc | (future) av1
    passed: bool
    error: str | None
    fps: float | None
    speed_x: float | None
    bitrate_kbps: float | None
    encoded_frames: int | None
    elapsed_sec: float | None
    realtime_multiplier: float | None
    init_ms: int | None
    gpu_utilization_percent: float | None
    vram_used_mb: int | None
    concurrent_session_cap: int | None
    recommended_concurrent: int | None
    verified_concurrent: int | None = None


def _failed_result(
    *,
    encoder: str,
    meta_vendor: str,
    meta_codec: str,
    error: str,
    elapsed_sec: float | None = None,
    init_ms: int | None = None,
    gpu_util: float | None = None,
    vram_mb: int | None = None,
    cap: int | None = None,
) -> EncoderBenchmarkResult:
    """Construct a passed=False result with consistent field defaults."""
    return EncoderBenchmarkResult(
        encoder=encoder,
        vendor=meta_vendor,
        codec=meta_codec,
        passed=False,
        error=error,
        fps=None,
        speed_x=None,
        bitrate_kbps=None,
        encoded_frames=None,
        elapsed_sec=elapsed_sec,
        realtime_multiplier=None,
        init_ms=init_ms,
        gpu_utilization_percent=gpu_util,
        vram_used_mb=vram_mb,
        concurrent_session_cap=cap,
        recommended_concurrent=None,
    )


async def benchmark_encoder(
    encoder: str,
    *,
    duration_sec: int = _DEFAULT_DURATION_SEC,
    size: str = _DEFAULT_SIZE,
    fps: int = _DEFAULT_FPS,
    hwaccel_device: str | None = None,
    timeout: float = _PER_ENCODER_TIMEOUT,
    probe_gpu: bool = True,
) -> EncoderBenchmarkResult:
    """Run a fixed-length lavfi encode through one encoder and return perf.

    Mirrors the ``test_encoder`` invocation pattern but runs for several
    seconds of source content (vs 1 s) so fps/speed numbers stabilise past
    the encoder's startup transient.  Output is muxed into mpegts and piped
    to DEVNULL so the bitrate counter stays live without touching disk.

    Args:
        encoder: FFmpeg encoder name (e.g. ``"h264_nvenc"``).
        duration_sec: Source length in seconds.  Clamped to [2, 20] by the
            router; this function honours the value passed in.
        size: Source resolution as ``"WxH"``.
        fps: Source frame rate.
        hwaccel_device: VAAPI render-node path on Linux; ignored elsewhere.
        timeout: Wall-clock ceiling.  Returns a timeout failure on expiry.
        probe_gpu: When True (default) hw encoders get a midpoint GPU probe.
            Tests pass False to skip the probe and dodge the asyncio.sleep.
    """
    meta = ENCODER_REGISTRY.get(encoder)
    if meta is None:
        return _failed_result(
            encoder=encoder,
            meta_vendor="unknown",
            meta_codec="unknown",
            error=f"unknown encoder: {encoder!r}",
        )

    try:
        ffmpeg = _ffmpeg_bin()
    except FileNotFoundError:
        return _failed_result(
            encoder=encoder,
            meta_vendor=meta.vendor,
            meta_codec=meta.codec,
            error="FFmpeg binary not found on PATH",
            cap=meta.concurrent_session_cap,
        )

    # ``-loglevel info`` so the periodic ``frame= ... fps= ... speed= ...``
    # progress lines are emitted.  ``error`` (the level used by test_encoder)
    # would suppress them and leave the parser with nothing to read.
    cmd: list[str] = [ffmpeg, "-hide_banner", "-loglevel", "info"]
    cmd.extend(meta.pre_input_args(device=hwaccel_device))
    cmd.extend(
        [
            "-f",
            "lavfi",
            "-i",
            f"testsrc=duration={duration_sec}:size={size}:rate={fps}",
        ]
    )
    # Medium preset + CRF 23 — close to the desktop's typical defaults so the
    # numbers reflect the real encoding workload an operator would see, not
    # an artificial ultrafast pass.
    cmd.extend(meta.video_codec_args("medium", 23))
    cmd.extend(meta.filter_args())
    # Mux into mpegts and pipe stdout to DEVNULL — see module docstring for
    # the rationale (``-f null -`` leaves bitrate=N/A).
    cmd.extend(["-an", "-f", "mpegts", "-"])

    logger.info(
        "Encoder benchmark start: encoder=%s duration=%ss size=%s fps=%s",
        encoder,
        duration_sec,
        size,
        fps,
    )

    started = time.monotonic()
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.PIPE,
        )
    except OSError as exc:
        logger.warning("Encoder benchmark spawn failed: %s — %s", encoder, exc)
        return _failed_result(
            encoder=encoder,
            meta_vendor=meta.vendor,
            meta_codec=meta.codec,
            error=f"spawn failed: {exc}",
            cap=meta.concurrent_session_cap,
        )

    # ── stderr reader: stream FFmpeg output, timestamp first frame, accumulate
    stderr_chunks: list[bytes] = []
    init_ms_box: list[int | None] = [None]

    async def _read_stderr() -> None:
        if proc.stderr is None:
            return
        while True:
            try:
                chunk = await proc.stderr.read(_STDERR_READ_CHUNK)
            except (asyncio.CancelledError, Exception):  # noqa: BLE001
                return
            if not chunk:
                return
            stderr_chunks.append(chunk)
            if init_ms_box[0] is None:
                # Decode just this chunk to scan for the first frame=N line.
                # FFmpeg writes progress separated by carriage-return; split
                # on both \r and \n so each progress update is its own row.
                text = chunk.decode("utf-8", errors="replace")
                for line in re.split(r"[\r\n]", text):
                    m = _FRAME_RE.search(line)
                    if m and int(m.group(1)) >= 1:
                        init_ms_box[0] = int(
                            (time.monotonic() - started) * 1000
                        )
                        break

    reader_task = asyncio.create_task(_read_stderr())

    # ── midpoint GPU probe for hardware encoders
    gpu_box: list[tuple[float | None, int | None]] = [(None, None)]
    probe_task: asyncio.Task[None] | None = None
    if probe_gpu and meta.vendor in _VENDOR_PROBE:
        async def _midpoint_probe() -> None:
            try:
                # Fire halfway through so the encoder is already in steady
                # state; if the run is shorter than 2 s we still want a
                # sample, hence the ``max(0.25, ...)`` floor.
                await asyncio.sleep(max(0.25, duration_sec / 2.0))
                from services import transcoding_service as _ts

                probe_name = _VENDOR_PROBE[meta.vendor]
                probe = getattr(_ts, probe_name)
                gpu_box[0] = await probe()
            except (asyncio.CancelledError, Exception):  # noqa: BLE001
                # GPU probe failures must not break the benchmark — leave
                # gpu_box[0] = (None, None) and let the row render with —.
                return

        probe_task = asyncio.create_task(_midpoint_probe())

    # ── wait for FFmpeg
    timed_out = False
    try:
        await asyncio.wait_for(proc.wait(), timeout=timeout)
    except TimeoutError:
        timed_out = True
        try:
            proc.kill()
            await proc.wait()
        except ProcessLookupError:
            pass

    elapsed = time.monotonic() - started

    # ── drain reader (sees EOF after the process exits) + cleanup probe
    try:
        await asyncio.wait_for(reader_task, timeout=_READER_DRAIN_TIMEOUT)
    except TimeoutError:
        reader_task.cancel()

    if probe_task is not None:
        if not probe_task.done():
            probe_task.cancel()
        try:
            await probe_task
        except (asyncio.CancelledError, Exception):  # noqa: BLE001
            pass

    cap = meta.concurrent_session_cap

    if timed_out:
        logger.warning(
            "Encoder benchmark timed out: encoder=%s after=%.1fs",
            encoder,
            elapsed,
        )
        return _failed_result(
            encoder=encoder,
            meta_vendor=meta.vendor,
            meta_codec=meta.codec,
            error=f"timed out after {timeout:.0f}s",
            elapsed_sec=elapsed,
            init_ms=init_ms_box[0],
            gpu_util=gpu_box[0][0],
            vram_mb=gpu_box[0][1],
            cap=cap,
        )

    tail_text = b"".join(stderr_chunks).decode("utf-8", errors="replace")

    if proc.returncode != 0:
        first_err = _pick_error_line(tail_text) or (
            f"exit code {proc.returncode}"
        )
        if len(first_err) > 240:
            first_err = first_err[:237] + "..."
        logger.info(
            "Encoder benchmark failed: encoder=%s rc=%s err=%s",
            encoder,
            proc.returncode,
            first_err,
        )
        return _failed_result(
            encoder=encoder,
            meta_vendor=meta.vendor,
            meta_codec=meta.codec,
            error=first_err,
            elapsed_sec=elapsed,
            init_ms=init_ms_box[0],
            gpu_util=gpu_box[0][0],
            vram_mb=gpu_box[0][1],
            cap=cap,
        )

    # Walk stderr backwards to find the last progress line — that's the one
    # written immediately before the muxer closed and carries the most
    # stable fps/speed/bitrate numbers.
    chunks = re.split(r"[\r\n]", tail_text)
    last_progress = ""
    for chunk in reversed(chunks):
        if "speed=" in chunk and "fps=" in chunk:
            last_progress = chunk
            break

    fps_match = _FPS_RE.search(last_progress)
    speed_match = _SPEED_RE.search(last_progress)
    bitrate_match = _BITRATE_RE.search(last_progress)
    frame_match = _FRAME_RE.search(last_progress)

    fps_value = float(fps_match.group(1)) if fps_match else None
    speed_value = float(speed_match.group(1)) if speed_match else None
    bitrate_value = float(bitrate_match.group(1)) if bitrate_match else None
    frame_value = int(frame_match.group(1)) if frame_match else None
    rt_multiplier = duration_sec / elapsed if elapsed > 0 else None

    recommended = _recommended_concurrent(
        speed_x=speed_value,
        realtime_multiplier=rt_multiplier,
        cap=cap,
    )

    result = EncoderBenchmarkResult(
        encoder=encoder,
        vendor=meta.vendor,
        codec=meta.codec,
        passed=True,
        error=None,
        fps=fps_value,
        speed_x=speed_value,
        bitrate_kbps=bitrate_value,
        encoded_frames=frame_value,
        elapsed_sec=elapsed,
        realtime_multiplier=rt_multiplier,
        init_ms=init_ms_box[0],
        gpu_utilization_percent=gpu_box[0][0],
        vram_used_mb=gpu_box[0][1],
        concurrent_session_cap=cap,
        recommended_concurrent=recommended,
    )
    logger.info(
        "Encoder benchmark done: encoder=%s fps=%s speed=%sx init=%sms "
        "concurrent=%s elapsed=%.2fs",
        encoder,
        result.fps,
        result.speed_x,
        result.init_ms,
        result.recommended_concurrent,
        elapsed,
    )
    return result


def _recommended_concurrent(
    *,
    speed_x: float | None,
    realtime_multiplier: float | None,
    cap: int | None,
) -> int | None:
    """Project how many concurrent realtime streams this encoder can sustain.

    Prefers ``speed_x`` (FFmpeg's encoder-side measurement, less polluted by
    process startup overhead than wall-clock); falls back to
    ``realtime_multiplier`` when speed_x is missing.  At least 1 if the
    encoder finished at all — sub-realtime encoders can still drive a single
    stream as long as the user accepts the lag.
    """
    metric = speed_x if speed_x and speed_x > 0 else realtime_multiplier
    if metric is None or metric <= 0:
        return None
    sustained = max(1, math.floor(metric))
    if cap is not None:
        return min(cap, sustained)
    return sustained


# In-flight progress for the currently-running benchmark.  Polled by the
# desktop's progress endpoint so the operator sees which encoder is being
# tested instead of a featureless "Running…" spinner for 60+ seconds.
#
# ``None`` when no benchmark is in flight.  Single dict (not a list / map)
# because ``run_benchmark`` is invoked one-at-a-time per worker process —
# concurrent benchmarks would contend for the GPU + invalidate each other's
# numbers, so the upstream router doesn't allow them.
#
# Schema:
#     {
#         "started_at":      ISO timestamp,
#         "total_encoders":  int,
#         "completed":       int,                # encoders fully done
#         "current_encoder": str | None,         # encoder being processed
#         "current_step":    str,                # "encoding" | "verifying_cap"
#         "current_index":   int,                # 1-based for UI display
#     }
_progress: dict[str, Any] | None = None


def get_progress() -> dict[str, Any] | None:
    """Return a snapshot of the current benchmark's progress, or None.

    The router exposes this via ``GET /benchmark/progress``.  Returning a
    snapshot copy isn't strictly necessary (callers don't mutate) but
    keeps the contract clean if a future agent adds writes.
    """
    if _progress is None:
        return None
    return dict(_progress)


async def run_benchmark(
    encoders: list[str],
    *,
    duration_sec: int = _DEFAULT_DURATION_SEC,
    fps: int = _DEFAULT_FPS,
    width: int = 1280,
    height: int = 720,
    hwaccel_device: str | None = None,
    verify_caps: bool = False,
) -> list[EncoderBenchmarkResult]:
    """Benchmark a list of encoders sequentially and return per-encoder results.

    Sequential is intentional — concurrent encodes share GPU/CPU and produce
    noise that defeats the comparison.  Each encoder's perf line in the
    desktop UI must reflect what that encoder can do *alone*.

    When ``verify_caps`` is True, encoders that carry a registry session cap
    (currently NVENC) get a brief concurrent-stress probe after the main
    measurement.  The probe spawns `max(8, cap*3)` short parallel encodes
    and counts successes — that's the empirical answer to "what's the actual
    cap on this hardware/driver" because the registry value is just a
    vendor default that newer drivers / patched cards may exceed.

    The probe briefly saturates the GPU while it runs (~2 s wall-clock per
    encoder) so it's opt-in — running it with active streams in flight
    would degrade them.
    """
    size = f"{width}x{height}"
    results: list[EncoderBenchmarkResult] = []

    # Publish initial progress before the first encoder spawn so the desktop
    # poller sees the run go from "running=false" → "running=true" within
    # one tick of clicking the button.
    global _progress
    started_iso = datetime.now(UTC).isoformat()
    _progress = {
        "started_at": started_iso,
        "total_encoders": len(encoders),
        "completed": 0,
        "current_encoder": None,
        "current_step": "starting",
        "current_index": 0,
    }

    try:
        for index, enc in enumerate(encoders, start=1):
            _progress = {
                **(_progress or {}),
                "current_encoder": enc,
                "current_step": "encoding",
                "current_index": index,
            }
            res = await benchmark_encoder(
                enc,
                duration_sec=duration_sec,
                fps=fps,
                size=size,
                hwaccel_device=hwaccel_device,
            )
            if (
                verify_caps
                and res.passed
                and res.concurrent_session_cap is not None
            ):
                # Switch to "verifying_cap" so the desktop status line
                # changes from "Encoding h264_nvenc" → "Verifying NVENC
                # session cap" — operators wonder why a single encoder
                # is taking ~12 s otherwise (8 s main + 2 s probe + buffer).
                _progress = {
                    **(_progress or {}),
                    "current_step": "verifying_cap",
                }
                # Probe with the *same* fps + resolution as the main run
                # so the verified count reflects the operator's actual
                # workload — a 4K HDR encode is materially heavier than
                # 720p and may hit VRAM exhaustion before the documented
                # session cap.
                verified = await probe_concurrent_cap(
                    enc,
                    registry_cap=res.concurrent_session_cap,
                    hwaccel_device=hwaccel_device,
                    fps=fps,
                    size=size,
                )
                if verified is not None:
                    # Re-derive recommended_concurrent against the verified
                    # cap since it may differ from the registry default —
                    # a patched driver might actually allow 6 streams.
                    res = _with_verified_cap(res, verified)
            results.append(res)
            _progress = {
                **(_progress or {}),
                "completed": index,
            }
        return results
    finally:
        # Always clear progress on exit (success / exception / cancellation)
        # so the desktop poller flips back to "no benchmark running" — a
        # stale dict would leave the UI's progress bar stuck.
        _progress = None


def _with_verified_cap(
    base: EncoderBenchmarkResult, verified: int
) -> EncoderBenchmarkResult:
    """Return a copy of ``base`` with ``verified_concurrent`` populated and
    ``recommended_concurrent`` re-derived against the verified ceiling."""
    new_recommended = _recommended_concurrent(
        speed_x=base.speed_x,
        realtime_multiplier=base.realtime_multiplier,
        cap=verified,
    )
    return EncoderBenchmarkResult(
        encoder=base.encoder,
        vendor=base.vendor,
        codec=base.codec,
        passed=base.passed,
        error=base.error,
        fps=base.fps,
        speed_x=base.speed_x,
        bitrate_kbps=base.bitrate_kbps,
        encoded_frames=base.encoded_frames,
        elapsed_sec=base.elapsed_sec,
        realtime_multiplier=base.realtime_multiplier,
        init_ms=base.init_ms,
        gpu_utilization_percent=base.gpu_utilization_percent,
        vram_used_mb=base.vram_used_mb,
        concurrent_session_cap=base.concurrent_session_cap,
        recommended_concurrent=new_recommended,
        verified_concurrent=verified,
    )


# Per-attempt timeout for the cap probe.  Each attempt is a short source
# encode; under cap-saturation contention the surviving sessions slow down
# considerably, so 15 s is a safe ceiling that won't false-fail healthy
# sessions while still bounding the total wall-clock.
_CAP_PROBE_PER_ATTEMPT_TIMEOUT = 15.0

# How short the per-attempt source clip is.  Just long enough to force the
# encoder past initialisation so a session-cap rejection actually surfaces.
# Decoupled from the main benchmark's ``duration_sec`` because cap detection
# doesn't need a stable steady-state measurement — it only needs each
# attempt to run long enough to either succeed or hit the OpenEncodeSessionEx
# rejection.
_CAP_PROBE_DURATION_SEC = 1


async def probe_concurrent_cap(
    encoder: str,
    *,
    registry_cap: int | None = None,
    hwaccel_device: str | None = None,
    size: str = _DEFAULT_SIZE,
    fps: int = _DEFAULT_FPS,
) -> int | None:
    """Spawn `max(8, registry_cap*3)` concurrent encodes; return success count.

    The empirical answer to "what's my actual NVENC session cap" — the
    registry value is a vendor default that newer drivers / patched cards
    may exceed.  Spawning beyond the cap surfaces the
    ``OpenEncodeSessionEx failed: out of memory`` error from the surplus
    sessions; counting the survivors gives the verified ceiling.

    Each attempt uses the *same* ``size`` and ``fps`` as the calling
    benchmark so the verified count actually reflects the operator's
    workload — a 60 fps × 1280×720 encode is materially heavier than a
    30 fps × 640×360 encode and could hit VRAM exhaustion before the
    documented session cap.  Using the matching workload keeps the chip
    on the desktop honest: "N concurrent at the workload you measured".

    Each attempt is short (~1 s of source) at veryfast/CRF 28 so the
    probe saturates only briefly even on slow hardware.

    Returns None when the encoder is unknown or FFmpeg can't be located.
    Returns 0 when the probe ran but every attempt failed (driver issue,
    not a cap concern).
    """
    meta = ENCODER_REGISTRY.get(encoder)
    if meta is None:
        return None
    try:
        ffmpeg = _ffmpeg_bin()
    except FileNotFoundError:
        return None

    target = max(8, (registry_cap or 0) * 3)

    # Deliberately use ``-f null -`` here (not mpegts) — we don't need
    # bitrate measurement, just success/fail. Lighter overhead.
    cmd: list[str] = [ffmpeg, "-hide_banner", "-loglevel", "error"]
    cmd.extend(meta.pre_input_args(device=hwaccel_device))
    cmd.extend(
        [
            "-f",
            "lavfi",
            "-i",
            f"testsrc=duration={_CAP_PROBE_DURATION_SEC}:size={size}:rate={fps}",
        ]
    )
    cmd.extend(meta.video_codec_args("veryfast", 28))
    cmd.extend(meta.filter_args())
    cmd.extend(["-an", "-f", "null", "-"])

    async def _one_attempt() -> bool:
        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
        except OSError:
            return False
        try:
            await asyncio.wait_for(
                proc.wait(), timeout=_CAP_PROBE_PER_ATTEMPT_TIMEOUT
            )
        except TimeoutError:
            try:
                proc.kill()
                await proc.wait()
            except ProcessLookupError:
                pass
            return False
        return proc.returncode == 0

    logger.info(
        "Cap probe start: encoder=%s target_attempts=%d (registry_cap=%s)",
        encoder,
        target,
        registry_cap,
    )
    started = time.monotonic()
    tasks = [asyncio.create_task(_one_attempt()) for _ in range(target)]
    results = await asyncio.gather(*tasks, return_exceptions=False)
    elapsed = time.monotonic() - started
    succeeded = sum(1 for r in results if r)
    logger.info(
        "Cap probe done: encoder=%s succeeded=%d/%d elapsed=%.1fs",
        encoder,
        succeeded,
        target,
        elapsed,
    )
    return succeeded


def clamp_duration(value: int | None) -> int:
    """Clamp the operator-supplied duration into a safe range.

    The router-side input model already validates types; this helper exists
    so the same clamp lives in one place for the test suite to assert.
    """
    if value is None:
        return _DEFAULT_DURATION_SEC
    return max(_MIN_DURATION, min(_MAX_DURATION, value))


def clamp_fps(value: int | None) -> int:
    """Clamp the operator-supplied fps into the supported range."""
    if value is None:
        return _DEFAULT_FPS
    return max(_MIN_FPS, min(_MAX_FPS, value))


# Resolution tiers the desktop UI exposes.  Constraining clamp output to
# these values keeps the benchmark history readable (otherwise an operator
# fat-fingering width=1281 would create a "1281×720" history row that's
# indistinguishable from the canonical 720p result).  Pixel-equivalence
# (width × height) drives the snap so non-16:9 inputs map to the nearest
# tier of similar workload.
_RESOLUTION_TIERS: tuple[tuple[int, int], ...] = (
    (1280, 720),    # 720p — default; representative library content
    (1920, 1080),   # 1080p — live game capture, broadcast TV
    (3840, 2160),   # 2160p / 4K — HDR sources, high-end captures
)


def clamp_resolution(
    width: int | None, height: int | None
) -> tuple[int, int]:
    """Snap operator-supplied dimensions to the nearest documented tier.

    ``(None, None)`` returns the 720p default.  Anything else is mapped
    by total-pixel proximity — operators submitting odd values (e.g. an
    SDR-targeted 1366×768) snap to the closest workload size so the
    benchmark history doesn't get cluttered with one-off resolutions.
    """
    if width is None and height is None:
        return _RESOLUTION_TIERS[0]
    target_pixels = (width or 1280) * (height or 720)
    return min(
        _RESOLUTION_TIERS,
        key=lambda wh: abs(wh[0] * wh[1] - target_pixels),
    )
