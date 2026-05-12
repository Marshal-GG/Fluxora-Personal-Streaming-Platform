"""Tests for ``services/benchmark_service.py``.

The benchmark runs a synthetic FFmpeg encode through each available encoder,
streams stderr live to timestamp the first encoded frame, samples the
vendor-specific GPU probe at the midpoint, then parses fps / speed / bitrate
from the final stderr progress line.

These tests mock ``asyncio.create_subprocess_exec`` so no real FFmpeg binary
is required.  The mock proc exposes a ``stderr`` reader that emits a chosen
text payload, lets the streaming reader pick up the first ``frame=`` line for
``init_ms``, then EOF.
"""

from __future__ import annotations

import asyncio
import time
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from services import benchmark_service

# ── clamp_duration: pure helper ───────────────────────────────────────────────


@pytest.mark.parametrize(
    "value,expected",
    [
        (None, 8),  # default when caller passes nothing
        (0, 2),  # below floor → clamped up
        (1, 2),
        (2, 2),
        (8, 8),
        (20, 20),
        (50, 20),  # above ceiling → clamped down
    ],
)
def test_clamp_duration_bounds(value: int | None, expected: int) -> None:
    assert benchmark_service.clamp_duration(value) == expected


@pytest.mark.parametrize(
    "value,expected",
    [
        (None, 30),  # default
        (10, 24),  # below floor
        (24, 24),
        (30, 30),
        (60, 60),
        (120, 60),  # above ceiling — high-refresh has no value here
    ],
)
def test_clamp_fps_bounds(value: int | None, expected: int) -> None:
    assert benchmark_service.clamp_fps(value) == expected


@pytest.mark.parametrize(
    "width,height,expected",
    [
        (None, None, (1280, 720)),  # default → 720p
        (1280, 720, (1280, 720)),  # exact 720p tier
        (1920, 1080, (1920, 1080)),  # exact 1080p tier
        (3840, 2160, (3840, 2160)),  # exact 4K tier
        (1366, 768, (1280, 720)),  # nearby SDR-laptop res snaps to 720p
        (2560, 1440, (1920, 1080)),  # 1440p falls between tiers; 1080p closest
        (4096, 2304, (3840, 2160)),  # cinema-ish 4K snaps to 4K tier
    ],
)
def test_clamp_resolution_snaps_to_known_tier(
    width: int | None, height: int | None, expected: tuple[int, int]
) -> None:
    assert benchmark_service.clamp_resolution(width, height) == expected


# ── parser regexes ──────────────────────────────────────────────────────────


def test_fps_speed_bitrate_regexes_against_real_ffmpeg_progress_line() -> None:
    """The regexes must accept the spacing variations FFmpeg produces."""
    line = (
        "frame=  240 fps= 30 q=23.0 size=N/A time=00:00:08.00 "
        "bitrate=1234.5kbits/s speed=1.05x"
    )
    assert benchmark_service._FPS_RE.search(line).group(1) == "30"
    assert benchmark_service._SPEED_RE.search(line).group(1) == "1.05"
    assert benchmark_service._BITRATE_RE.search(line).group(1) == "1234.5"
    assert benchmark_service._FRAME_RE.search(line).group(1) == "240"


def test_speed_regex_handles_subreal_time_speeds() -> None:
    """Software encoders can be slower than realtime — the ``speed=`` field
    drops below 1.0 and the regex must still parse it."""
    line = "frame=  240 fps= 12 q=28.0 bitrate= 800.0kbits/s speed=0.41x"
    assert benchmark_service._SPEED_RE.search(line).group(1) == "0.41"


# ── _pick_error_line: pure helper ────────────────────────────────────────────


def test_pick_error_line_skips_input_header() -> None:
    text = (
        "Input #0, lavfi, from 'testsrc=...':\n"
        "  Stream #0:0: Video: wrapped_avframe\n"
        "[hevc_qsv @ 0x1] Error querying encoder params: unsupported (-3)\n"
    )
    picked = benchmark_service._pick_error_line(text)
    assert picked is not None
    assert "Error querying" in picked


def test_pick_error_line_recognises_failed_marker() -> None:
    text = (
        "Input #0, lavfi, from '...'\n"
        "Some informational line\n"
        "[h264_nvenc @ 0x1] OpenEncodeSessionEx failed: out of memory (10)\n"
    )
    picked = benchmark_service._pick_error_line(text)
    assert picked is not None
    assert "failed" in picked.lower()


def test_pick_error_line_falls_back_to_last_line_when_no_marker_matches() -> None:
    text = "Some line A\nSome line B\nSome line C\n"
    picked = benchmark_service._pick_error_line(text)
    assert picked == "Some line C"


def test_pick_error_line_returns_none_for_empty() -> None:
    assert benchmark_service._pick_error_line("") is None
    assert benchmark_service._pick_error_line("\n  \n") is None


# ── _recommended_concurrent: pure helper ─────────────────────────────────────


@pytest.mark.parametrize(
    "speed_x,realtime,cap,expected",
    [
        # Cap-bound: NVENC at 5.7× speed, cap=3 → 3
        (5.72, 5.72, 3, 3),
        # Cap-bound: NVENC at 1.5× speed, cap=3 → 1
        (1.5, 1.5, 3, 1),
        # No cap: software at 3.17× → 3
        (3.17, 3.17, None, 3),
        # No cap: software at 0.4× (sub-realtime) → 1 (floor protected)
        (0.4, 0.4, None, 1),
        # speed_x missing, realtime fallback
        (None, 2.5, None, 2),
        # Both missing → None
        (None, None, None, None),
        # Zero speed → None (treated as failure)
        (0.0, 0.0, None, None),
    ],
)
def test_recommended_concurrent_table(
    speed_x: float | None,
    realtime: float | None,
    cap: int | None,
    expected: int | None,
) -> None:
    got = benchmark_service._recommended_concurrent(
        speed_x=speed_x,
        realtime_multiplier=realtime,
        cap=cap,
    )
    assert got == expected


# ── benchmark_encoder: error paths that don't need a subprocess mock ─────────


@pytest.mark.asyncio
async def test_benchmark_unknown_encoder_returns_failure_without_running() -> None:
    """Unknown encoder name returns ``passed=False`` immediately."""
    result = await benchmark_service.benchmark_encoder("does_not_exist")
    assert result.passed is False
    assert result.error is not None
    assert "unknown encoder" in result.error
    assert result.vendor == "unknown"
    assert result.fps is None
    assert result.elapsed_sec is None


@pytest.mark.asyncio
async def test_benchmark_returns_failure_when_ffmpeg_binary_missing() -> None:
    """When ``_ffmpeg_bin()`` raises FileNotFoundError the benchmark must
    surface it as a normal failed row, not propagate the exception."""
    with patch.object(
        benchmark_service,
        "_ffmpeg_bin",
        side_effect=FileNotFoundError("no ffmpeg"),
    ):
        result = await benchmark_service.benchmark_encoder("libx264")

    assert result.passed is False
    assert result.error is not None
    assert "FFmpeg" in result.error
    # Even on this failure the registry-derived fields should still be present
    # so the desktop renders the row consistently.
    assert result.vendor == "software"
    assert result.codec == "h264"


# ── benchmark_encoder: streamed-stderr happy + failure paths ────────────────


def _make_proc_with_stderr(
    stderr_text: str,
    *,
    returncode: int = 0,
    chunks: int = 1,
):
    """Mock a subprocess where stderr emits ``stderr_text`` over N chunks.

    ``chunks`` controls how the payload is split — splitting across multiple
    reads exercises the streaming reader's "first frame appears mid-buffer"
    path.
    """
    proc = MagicMock()
    proc.pid = 1234
    proc.returncode = returncode
    proc.wait = AsyncMock(return_value=returncode)
    proc.kill = MagicMock()

    encoded = stderr_text.encode("utf-8")
    if chunks <= 1 or len(encoded) < chunks:
        chunk_list: list[bytes] = [encoded, b""]
    else:
        size = max(1, len(encoded) // chunks)
        chunk_list = [encoded[i : i + size] for i in range(0, len(encoded), size)] + [
            b""
        ]

    queue = list(chunk_list)

    async def _read(_n: int = 4096):
        if queue:
            return queue.pop(0)
        return b""

    proc.stderr = MagicMock()
    proc.stderr.read = AsyncMock(side_effect=_read)
    return proc


@pytest.mark.asyncio
async def test_benchmark_happy_path_parses_perf_numbers() -> None:
    """End-to-end happy path: FFmpeg exits cleanly, stderr carries a final
    progress line, parser extracts fps/speed/bitrate/frames/init_ms."""
    stderr_text = (
        "[lavfi @ 0x1] config in time_base: 1/30, frame_rate: 30/1\n"
        "Output #0, mpegts, to 'pipe:':\n"
        "  Stream #0:0: Video: h264, yuv420p, 1280x720, q=2-31, 30 fps\n"
        "frame=    1 fps=0.0 q=23.0 size=     0kB time=00:00:00.04 "
        "bitrate=N/A speed=0.10x    \r"
        "frame=  120 fps= 60 q=23.0 size=     1kB time=00:00:04.00 "
        "bitrate=900.0kbits/s speed=2.0x    \r"
        "frame=  240 fps= 60 q=23.0 size=     2kB time=00:00:08.00 "
        "bitrate=900.0kbits/s speed=2.05x\n"
    )

    fake = _make_proc_with_stderr(stderr_text, returncode=0)

    with (
        patch.object(benchmark_service, "_ffmpeg_bin", return_value="ffmpeg"),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(return_value=fake),
        ),
    ):
        result = await benchmark_service.benchmark_encoder(
            "libx264", duration_sec=8, probe_gpu=False
        )

    assert result.passed is True
    assert result.error is None
    assert result.vendor == "software"
    assert result.codec == "h264"
    assert result.fps == pytest.approx(60.0)
    assert result.speed_x == pytest.approx(2.05)
    assert result.bitrate_kbps == pytest.approx(900.0)
    assert result.encoded_frames == 240
    assert result.elapsed_sec is not None and result.elapsed_sec >= 0
    # Recommended concurrent: floor(2.05) = 2; libx264 has no cap.
    assert result.recommended_concurrent == 2
    assert result.concurrent_session_cap is None
    # init_ms is populated because the stream contained `frame=    1 ...`.
    assert result.init_ms is not None
    assert result.init_ms >= 0


@pytest.mark.asyncio
async def test_benchmark_init_ms_populated_when_first_frame_seen() -> None:
    """Even a minimal payload with a single ``frame=N≥1`` line populates
    init_ms — that's the mechanism the desktop uses to surface
    stream-start latency."""
    stderr_text = (
        "Output #0, mpegts, to 'pipe:':\n"
        "frame=    1 fps=10.0 q=23.0 bitrate=500.0kbits/s speed=0.5x    \n"
        "frame=    5 fps=10.0 q=23.0 bitrate=500.0kbits/s speed=0.5x    \n"
    )

    fake = _make_proc_with_stderr(stderr_text, returncode=0)

    with (
        patch.object(benchmark_service, "_ffmpeg_bin", return_value="ffmpeg"),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(return_value=fake),
        ),
    ):
        result = await benchmark_service.benchmark_encoder(
            "libx264", duration_sec=2, probe_gpu=False
        )

    assert result.init_ms is not None


@pytest.mark.asyncio
async def test_benchmark_failure_surfaces_actual_error_line() -> None:
    """Non-zero exit must produce ``passed=False`` carrying the actual error
    line — NOT the input-header line that FFmpeg prints first.  Was the
    failure mode visible on the user's hevc_qsv benchmark."""
    stderr_text = (
        "Input #0, lavfi, from 'testsrc=duration=8:size=1280x720:rate=30':\n"
        "  Duration: N/A, start: 0.000000, bitrate: N/A\n"
        "  Stream #0:0: Video: wrapped_avframe, yuv420p, 1280x720, 30 fps\n"
        "Stream mapping:\n"
        "  Stream #0:0 -> #0:0 (rawvideo (native) -> hevc (hevc_qsv))\n"
        "[hevc_qsv @ 0x1] Error querying encoder params: unsupported (-3)\n"
        "[vost#0:0/hevc_qsv @ 0x2] Error initializing output stream\n"
        "Conversion failed!\n"
    )

    fake = _make_proc_with_stderr(stderr_text, returncode=1)

    with (
        patch.object(benchmark_service, "_ffmpeg_bin", return_value="ffmpeg"),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(return_value=fake),
        ),
    ):
        result = await benchmark_service.benchmark_encoder("hevc_qsv", probe_gpu=False)

    assert result.passed is False
    assert result.error is not None
    assert "Error querying encoder params" in result.error
    assert "Input #0" not in result.error
    assert result.vendor == "intel"
    assert result.codec == "hevc"
    assert result.fps is None


@pytest.mark.asyncio
async def test_benchmark_timeout_returns_killed_marker() -> None:
    """If the encode runs longer than ``timeout`` seconds the service must
    kill the process and return ``passed=False`` with a timeout marker."""

    async def _spawn_that_hangs(*_args, **_kwargs):
        proc = MagicMock()
        proc.pid = 999
        proc.returncode = None
        killed = {"flag": False}

        async def _wait():
            if killed["flag"]:
                return 0
            await asyncio.sleep(60)
            return 0

        def _kill():
            killed["flag"] = True
            proc.returncode = -9

        proc.wait = AsyncMock(side_effect=_wait)
        proc.kill = MagicMock(side_effect=_kill)

        # Stderr never emits anything; reader will stay blocked on read().
        async def _read(_n: int = 4096):
            await asyncio.sleep(60)
            return b""

        proc.stderr = MagicMock()
        proc.stderr.read = AsyncMock(side_effect=_read)
        return proc

    with (
        patch.object(benchmark_service, "_ffmpeg_bin", return_value="ffmpeg"),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(side_effect=_spawn_that_hangs),
        ),
    ):
        t0 = time.perf_counter()
        result = await benchmark_service.benchmark_encoder(
            "libx264", timeout=0.2, probe_gpu=False
        )
        elapsed = time.perf_counter() - t0

    assert result.passed is False
    assert result.error is not None
    assert "timed out" in result.error
    # Reader drain budget is ~2 s; total wall must stay under it.
    assert elapsed < 3.5


# ── midpoint GPU probe wiring ────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_benchmark_skips_gpu_probe_for_software_encoders() -> None:
    """Software encoders have no GPU to probe — the probe coroutine is never
    scheduled regardless of ``probe_gpu``."""
    stderr_text = (
        "Output #0, mpegts, to 'pipe:':\n"
        "frame=  240 fps= 60 q=23.0 bitrate=900.0kbits/s speed=2.0x\n"
    )
    fake = _make_proc_with_stderr(stderr_text, returncode=0)

    with (
        patch.object(benchmark_service, "_ffmpeg_bin", return_value="ffmpeg"),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(return_value=fake),
        ),
    ):
        result = await benchmark_service.benchmark_encoder("libx264", probe_gpu=True)

    assert result.gpu_utilization_percent is None
    assert result.vram_used_mb is None


@pytest.mark.asyncio
async def test_benchmark_runs_midpoint_probe_for_nvidia_encoders() -> None:
    """For nvidia encoders the midpoint probe fires and its result lands in
    ``gpu_utilization_percent`` + ``vram_used_mb``.  The mocked proc.wait
    sleeps long enough (0.5 s ≥ probe's 0.25 s floor) to let the midpoint
    coroutine fire before the process exits."""
    stderr_text = (
        "Output #0, mpegts, to 'pipe:':\n"
        "frame=  240 fps= 200 q=23.0 bitrate=1100.0kbits/s speed=6.5x\n"
    )
    fake = _make_proc_with_stderr(stderr_text, returncode=0)

    async def _slow_wait():
        # Probe sleeps ``max(0.25, duration_sec/2)`` = 1.0 s for duration=2;
        # proc must outlive that so the probe coroutine fires before we hit
        # the post-wait cleanup that cancels it.
        await asyncio.sleep(1.5)
        return 0

    fake.wait = AsyncMock(side_effect=_slow_wait)

    from services import transcoding_service

    with (
        patch.object(benchmark_service, "_ffmpeg_bin", return_value="ffmpeg"),
        patch.object(
            transcoding_service,
            "_probe_nvidia",
            new=AsyncMock(return_value=(34.0, 580)),
        ),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(return_value=fake),
        ),
    ):
        result = await benchmark_service.benchmark_encoder(
            "h264_nvenc", duration_sec=2, probe_gpu=True
        )

    assert result.passed is True
    assert result.gpu_utilization_percent == pytest.approx(34.0)
    assert result.vram_used_mb == 580
    # NVENC consumer cap = 3 (registry); speed_x = 6.5 → recommended = 3.
    assert result.concurrent_session_cap == 3
    assert result.recommended_concurrent == 3


# ── run_benchmark: orchestrator ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_probe_concurrent_cap_counts_succeeding_attempts() -> None:
    """Cap probe spawns N concurrent attempts; result is the count that
    exit cleanly.  Fakes a process where the first 3 spawns succeed and
    the rest fail — emulating NVENC's 3-session cap."""
    spawn_count = {"n": 0}

    async def _spawn(*_args, **_kwargs):
        spawn_count["n"] += 1
        proc = MagicMock()
        proc.pid = 100 + spawn_count["n"]
        # First 3 spawns return 0 (cap-allowed); rest return 1 (cap-rejected).
        rc = 0 if spawn_count["n"] <= 3 else 1
        proc.returncode = rc
        proc.wait = AsyncMock(return_value=rc)
        proc.kill = MagicMock()
        return proc

    with (
        patch.object(benchmark_service, "_ffmpeg_bin", return_value="ffmpeg"),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(side_effect=_spawn),
        ),
    ):
        verified = await benchmark_service.probe_concurrent_cap(
            "h264_nvenc", registry_cap=3
        )

    # max(8, 3*3) = 9 attempts; 3 succeeded → verified == 3.
    assert spawn_count["n"] == 9
    assert verified == 3


@pytest.mark.asyncio
async def test_probe_concurrent_cap_returns_higher_than_registry_when_unlocked() -> (
    None
):
    """A patched / RTX-40 / driver-530+ box can run more than the
    documented cap.  When all 9 attempts succeed, the verified value
    should exceed the registry default — that's the empirical evidence
    the operator needs to know their cap was lifted."""

    async def _spawn_all_succeed(*_args, **_kwargs):
        proc = MagicMock()
        proc.pid = 200
        proc.returncode = 0
        proc.wait = AsyncMock(return_value=0)
        proc.kill = MagicMock()
        return proc

    with (
        patch.object(benchmark_service, "_ffmpeg_bin", return_value="ffmpeg"),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(side_effect=_spawn_all_succeed),
        ),
    ):
        verified = await benchmark_service.probe_concurrent_cap(
            "h264_nvenc", registry_cap=3
        )

    # 9 attempts all succeeded → verified == 9 (exceeds registry's 3).
    assert verified == 9
    assert verified > 3  # this is the operator-actionable signal


@pytest.mark.asyncio
async def test_probe_concurrent_cap_returns_none_for_unknown_encoder() -> None:
    verified = await benchmark_service.probe_concurrent_cap(
        "does_not_exist", registry_cap=3
    )
    assert verified is None


@pytest.mark.asyncio
async def test_probe_concurrent_cap_returns_none_when_ffmpeg_missing() -> None:
    with patch.object(
        benchmark_service,
        "_ffmpeg_bin",
        side_effect=FileNotFoundError("no ffmpeg"),
    ):
        verified = await benchmark_service.probe_concurrent_cap(
            "h264_nvenc", registry_cap=3
        )
    assert verified is None


@pytest.mark.asyncio
async def test_run_benchmark_with_verify_caps_runs_probe_for_capped_encoders() -> None:
    """When verify_caps=True, hw encoders with a registry cap get an
    additional probe call.  Software encoders (no cap) are skipped."""
    probe_calls: list[str] = []

    async def _fake_benchmark(encoder, **_kwargs):
        meta = benchmark_service.ENCODER_REGISTRY[encoder]
        return benchmark_service.EncoderBenchmarkResult(
            encoder=encoder,
            vendor=meta.vendor,
            codec=meta.codec,
            width=1280,
            height=720,
            passed=True,
            error=None,
            fps=60.0,
            speed_x=4.0,
            bitrate_kbps=900.0,
            encoded_frames=240,
            elapsed_sec=2.0,
            realtime_multiplier=4.0,
            init_ms=120,
            gpu_utilization_percent=None,
            vram_used_mb=None,
            concurrent_session_cap=meta.concurrent_session_cap,
            recommended_concurrent=4,
        )

    async def _fake_probe(encoder, **_kwargs):
        probe_calls.append(encoder)
        return 7  # measured cap higher than registry default

    with (
        patch.object(
            benchmark_service, "benchmark_encoder", side_effect=_fake_benchmark
        ),
        patch.object(
            benchmark_service,
            "probe_concurrent_cap",
            side_effect=_fake_probe,
        ),
    ):
        results = await benchmark_service.run_benchmark(
            ["libx264", "h264_nvenc", "h264_qsv"],
            verify_caps=True,
        )

    # libx264 (no cap) + h264_qsv (no cap) are skipped; only h264_nvenc.
    assert probe_calls == ["h264_nvenc"]
    nvenc = next(r for r in results if r.encoder == "h264_nvenc")
    assert nvenc.verified_concurrent == 7
    # Recommended re-derived against verified cap: min(7, floor(4.0)) = 4.
    assert nvenc.recommended_concurrent == 4


@pytest.mark.asyncio
async def test_run_benchmark_threads_fps_into_cap_probe() -> None:
    """The cap probe must receive the operator-selected fps — otherwise
    a 60 fps benchmark would be paired with a 30 fps cap probe and the
    'verified concurrent' chip would lie about the actual workload's
    capacity."""
    probe_kwargs: dict = {}

    async def _fake_benchmark(encoder, **_kwargs):
        meta = benchmark_service.ENCODER_REGISTRY[encoder]
        return benchmark_service.EncoderBenchmarkResult(
            encoder=encoder,
            vendor=meta.vendor,
            codec=meta.codec,
            width=1280,
            height=720,
            passed=True,
            error=None,
            fps=120.0,
            speed_x=2.0,
            bitrate_kbps=1500.0,
            encoded_frames=480,
            elapsed_sec=4.0,
            realtime_multiplier=2.0,
            init_ms=300,
            gpu_utilization_percent=None,
            vram_used_mb=None,
            concurrent_session_cap=meta.concurrent_session_cap,
            recommended_concurrent=2,
        )

    async def _fake_probe(encoder, **kwargs):
        probe_kwargs.update(kwargs)
        probe_kwargs["encoder"] = encoder
        return 5

    with (
        patch.object(
            benchmark_service, "benchmark_encoder", side_effect=_fake_benchmark
        ),
        patch.object(
            benchmark_service,
            "probe_concurrent_cap",
            side_effect=_fake_probe,
        ),
    ):
        await benchmark_service.run_benchmark(
            ["h264_nvenc"],
            fps=60,
            verify_caps=True,
        )

    assert probe_kwargs["encoder"] == "h264_nvenc"
    assert probe_kwargs["fps"] == 60


@pytest.mark.asyncio
async def test_run_benchmark_without_verify_caps_skips_probe() -> None:
    """Default ``verify_caps=False`` — probe is never called even for
    capped encoders.  Verified_concurrent stays None on every result."""
    probe_calls: list[str] = []

    async def _fake_benchmark(encoder, **_kwargs):
        meta = benchmark_service.ENCODER_REGISTRY[encoder]
        return benchmark_service.EncoderBenchmarkResult(
            encoder=encoder,
            vendor=meta.vendor,
            codec=meta.codec,
            width=1280,
            height=720,
            passed=True,
            error=None,
            fps=60.0,
            speed_x=4.0,
            bitrate_kbps=900.0,
            encoded_frames=240,
            elapsed_sec=2.0,
            realtime_multiplier=4.0,
            init_ms=120,
            gpu_utilization_percent=None,
            vram_used_mb=None,
            concurrent_session_cap=meta.concurrent_session_cap,
            recommended_concurrent=3,
        )

    async def _fake_probe(encoder, **_kwargs):
        probe_calls.append(encoder)
        return 9

    with (
        patch.object(
            benchmark_service, "benchmark_encoder", side_effect=_fake_benchmark
        ),
        patch.object(
            benchmark_service,
            "probe_concurrent_cap",
            side_effect=_fake_probe,
        ),
    ):
        results = await benchmark_service.run_benchmark(
            ["h264_nvenc"],
            verify_caps=False,
        )

    assert probe_calls == []
    assert results[0].verified_concurrent is None


@pytest.mark.asyncio
async def test_run_benchmark_publishes_progress_per_encoder() -> None:
    """While ``run_benchmark`` walks encoders, ``get_progress`` should
    surface the current encoder + step so the desktop poller can render
    a live status line.  After the run completes, progress flips to
    ``None`` so the UI knows to clear the progress card."""
    seen_progress: list[dict | None] = []

    async def _capturing_benchmark(encoder, **_kwargs):
        # Snapshot progress mid-run — at this point the global should
        # reflect "we're currently working on this encoder".
        seen_progress.append(benchmark_service.get_progress())
        meta = benchmark_service.ENCODER_REGISTRY[encoder]
        return benchmark_service.EncoderBenchmarkResult(
            encoder=encoder,
            vendor=meta.vendor,
            codec=meta.codec,
            width=1280,
            height=720,
            passed=True,
            error=None,
            fps=60.0,
            speed_x=2.0,
            bitrate_kbps=900.0,
            encoded_frames=240,
            elapsed_sec=4.0,
            realtime_multiplier=2.0,
            init_ms=200,
            gpu_utilization_percent=None,
            vram_used_mb=None,
            concurrent_session_cap=meta.concurrent_session_cap,
            recommended_concurrent=2,
        )

    # Sanity — no benchmark running before we start.
    assert benchmark_service.get_progress() is None

    with patch.object(
        benchmark_service, "benchmark_encoder", side_effect=_capturing_benchmark
    ):
        await benchmark_service.run_benchmark(["libx264", "h264_nvenc", "h264_qsv"])

    # Should have captured one snapshot per encoder; each snapshot names
    # the encoder being processed at that moment.
    assert len(seen_progress) == 3
    assert all(p is not None for p in seen_progress)
    assert seen_progress[0]["current_encoder"] == "libx264"
    assert seen_progress[0]["current_index"] == 1
    assert seen_progress[0]["total_encoders"] == 3
    assert seen_progress[0]["current_step"] == "encoding"
    assert seen_progress[1]["current_encoder"] == "h264_nvenc"
    assert seen_progress[1]["current_index"] == 2
    # And after the run completes, progress is cleared.
    assert benchmark_service.get_progress() is None


@pytest.mark.asyncio
async def test_run_benchmark_progress_clears_on_exception() -> None:
    """If the underlying ``benchmark_encoder`` raises, the progress
    global must still be cleared — otherwise the desktop poller would
    show a phantom "running" state forever."""

    async def _crashing_benchmark(*_args, **_kwargs):
        raise RuntimeError("simulated encoder failure")

    with patch.object(
        benchmark_service, "benchmark_encoder", side_effect=_crashing_benchmark
    ):
        with pytest.raises(RuntimeError):
            await benchmark_service.run_benchmark(["libx264"])

    assert benchmark_service.get_progress() is None


@pytest.mark.asyncio
async def test_run_benchmark_progress_step_flips_to_verifying_cap() -> None:
    """When verify_caps=True for an encoder with a registry cap, the
    progress step transitions ``encoding`` → ``verifying_cap`` so the
    desktop status line can change copy mid-encoder."""
    captured_steps_during_probe: list[str | None] = []

    async def _fake_benchmark(encoder, **_kwargs):
        meta = benchmark_service.ENCODER_REGISTRY[encoder]
        return benchmark_service.EncoderBenchmarkResult(
            encoder=encoder,
            vendor=meta.vendor,
            codec=meta.codec,
            width=1280,
            height=720,
            passed=True,
            error=None,
            fps=120.0,
            speed_x=4.0,
            bitrate_kbps=1500.0,
            encoded_frames=240,
            elapsed_sec=2.0,
            realtime_multiplier=4.0,
            init_ms=400,
            gpu_utilization_percent=None,
            vram_used_mb=None,
            concurrent_session_cap=meta.concurrent_session_cap,
            recommended_concurrent=3,
        )

    async def _capturing_probe(encoder, **_kwargs):
        snap = benchmark_service.get_progress()
        captured_steps_during_probe.append(snap["current_step"] if snap else None)
        return 5

    with (
        patch.object(
            benchmark_service, "benchmark_encoder", side_effect=_fake_benchmark
        ),
        patch.object(
            benchmark_service,
            "probe_concurrent_cap",
            side_effect=_capturing_probe,
        ),
    ):
        await benchmark_service.run_benchmark(
            ["h264_nvenc"],
            verify_caps=True,
        )

    assert captured_steps_during_probe == ["verifying_cap"]
    assert benchmark_service.get_progress() is None


@pytest.mark.asyncio
async def test_run_benchmark_runs_encoders_sequentially_and_collects_results() -> None:
    """The orchestrator must call ``benchmark_encoder`` once per encoder and
    return one result per encoder in the supplied order — no dedup, no
    reordering, no parallel execution."""
    seen: list[str] = []

    async def _fake_benchmark(encoder, **_kwargs):
        seen.append(encoder)
        meta = benchmark_service.ENCODER_REGISTRY[encoder]
        return benchmark_service.EncoderBenchmarkResult(
            encoder=encoder,
            vendor=meta.vendor,
            codec=meta.codec,
            width=1280,
            height=720,
            passed=True,
            error=None,
            fps=30.0,
            speed_x=1.0,
            bitrate_kbps=500.0,
            encoded_frames=240,
            elapsed_sec=1.0,
            realtime_multiplier=1.0,
            init_ms=100,
            gpu_utilization_percent=None,
            vram_used_mb=None,
            concurrent_session_cap=meta.concurrent_session_cap,
            recommended_concurrent=1,
        )

    with patch.object(
        benchmark_service, "benchmark_encoder", side_effect=_fake_benchmark
    ):
        results = await benchmark_service.run_benchmark(
            ["libx264", "h264_nvenc", "h264_qsv"], duration_sec=4
        )

    assert seen == ["libx264", "h264_nvenc", "h264_qsv"]
    assert [r.encoder for r in results] == [
        "libx264",
        "h264_nvenc",
        "h264_qsv",
    ]
    assert all(r.passed for r in results)


# ── Matrix-mode (resolution × encoder) ───────────────────────────────────────


def test_clamp_resolutions_dedupes_after_snap() -> None:
    """Operator selecting both 1280×720 and 1366×768 ends up with a single
    720p tier — clamp snaps the second to 720p and dedup drops it.
    Order preserved on first occurrence so the matrix runs in the order
    the operator selected (an operator who picked 4K then 720p sees 4K
    results land first, which matches their mental model)."""
    out = benchmark_service.clamp_resolutions(
        [(1280, 720), (1366, 768), (1920, 1080), (3840, 2160), (1920, 1080)]
    )
    assert out == [(1280, 720), (1920, 1080), (3840, 2160)]


def test_clamp_resolutions_falls_back_to_default_for_empty() -> None:
    """Single-resolution callers passing None / [] keep their existing
    behaviour: a single 720p tier."""
    assert benchmark_service.clamp_resolutions(None) == [(1280, 720)]
    assert benchmark_service.clamp_resolutions([]) == [(1280, 720)]


@pytest.mark.asyncio
async def test_run_benchmark_matrix_produces_n_times_m_results() -> None:
    """Outer loop is per-resolution, inner loop is per-encoder.  Two
    encoders × three resolutions = six results in resolution-outer order
    so the desktop sees results land in chunks of "all encoders at 720p,
    all encoders at 1080p, ...".  Each result self-describes its
    resolution via the new width/height fields on EncoderBenchmarkResult."""
    seen: list[tuple[str, str]] = []

    async def _fake_benchmark(encoder, *, size, **_kwargs):
        seen.append((encoder, size))
        meta = benchmark_service.ENCODER_REGISTRY[encoder]
        w_str, h_str = size.split("x")
        return benchmark_service.EncoderBenchmarkResult(
            encoder=encoder,
            vendor=meta.vendor,
            codec=meta.codec,
            width=int(w_str),
            height=int(h_str),
            passed=True,
            error=None,
            fps=30.0,
            speed_x=1.0,
            bitrate_kbps=500.0,
            encoded_frames=240,
            elapsed_sec=8.0,
            realtime_multiplier=1.0,
            init_ms=200,
            gpu_utilization_percent=None,
            vram_used_mb=None,
            concurrent_session_cap=meta.concurrent_session_cap,
            recommended_concurrent=1,
        )

    with patch.object(
        benchmark_service, "benchmark_encoder", side_effect=_fake_benchmark
    ):
        results = await benchmark_service.run_benchmark(
            ["libx264", "h264_nvenc"],
            resolutions=[(1280, 720), (1920, 1080), (3840, 2160)],
        )

    # Outer = resolution, inner = encoder; each pair invoked exactly once.
    assert seen == [
        ("libx264", "1280x720"),
        ("h264_nvenc", "1280x720"),
        ("libx264", "1920x1080"),
        ("h264_nvenc", "1920x1080"),
        ("libx264", "3840x2160"),
        ("h264_nvenc", "3840x2160"),
    ]
    assert len(results) == 6
    # Each result self-describes its resolution — the desktop groups by
    # encoder + reads each row's (width, height) directly rather than
    # inferring from the parent run's primary dimensions.
    assert results[0].width == 1280 and results[0].height == 720
    assert results[2].width == 1920 and results[2].height == 1080
    assert results[5].width == 3840 and results[5].height == 2160


@pytest.mark.asyncio
async def test_run_benchmark_matrix_publishes_resolution_index_in_progress() -> None:
    """In matrix mode the progress snapshot must include
    ``total_resolutions`` and ``current_resolution_index`` so the desktop
    can render "Resolution 2 of 3 · Encoder 4 of 6" instead of just an
    encoder counter that resets at each resolution boundary."""
    seen_progress: list[dict | None] = []

    async def _capturing_benchmark(encoder, *, size, **_kwargs):
        seen_progress.append(benchmark_service.get_progress())
        meta = benchmark_service.ENCODER_REGISTRY[encoder]
        w_str, h_str = size.split("x")
        return benchmark_service.EncoderBenchmarkResult(
            encoder=encoder,
            vendor=meta.vendor,
            codec=meta.codec,
            width=int(w_str),
            height=int(h_str),
            passed=True,
            error=None,
            fps=60.0,
            speed_x=2.0,
            bitrate_kbps=900.0,
            encoded_frames=480,
            elapsed_sec=4.0,
            realtime_multiplier=2.0,
            init_ms=200,
            gpu_utilization_percent=None,
            vram_used_mb=None,
            concurrent_session_cap=meta.concurrent_session_cap,
            recommended_concurrent=2,
        )

    with patch.object(
        benchmark_service, "benchmark_encoder", side_effect=_capturing_benchmark
    ):
        await benchmark_service.run_benchmark(
            ["libx264", "h264_nvenc"],
            resolutions=[(1280, 720), (1920, 1080)],
        )

    assert len(seen_progress) == 4  # 2 encoders × 2 resolutions
    # First two snapshots are at 720p; next two at 1080p.
    assert seen_progress[0]["total_resolutions"] == 2
    assert seen_progress[0]["current_resolution_index"] == 1
    assert seen_progress[0]["current_resolution_width"] == 1280
    assert seen_progress[0]["current_resolution_height"] == 720
    assert seen_progress[2]["current_resolution_index"] == 2
    assert seen_progress[2]["current_resolution_width"] == 1920
    assert seen_progress[2]["current_resolution_height"] == 1080
    # Total encoders counter reflects pair count, not encoder count.
    assert seen_progress[0]["total_encoders"] == 4
    assert seen_progress[3]["current_index"] == 4
    # Progress cleared after run completes.
    assert benchmark_service.get_progress() is None
