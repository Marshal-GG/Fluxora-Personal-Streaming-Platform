"""Transcoding status + advisor + devices + fallback-history + benchmark.

| Method | Path                                              | Auth           |
|--------|---------------------------------------------------|----------------|
| GET    | /api/v1/transcoding/status                        | localhost only |
| GET    | /api/v1/transcoding/advisor                       | localhost only |
| GET    | /api/v1/transcoding/devices                       | localhost only |
| GET    | /api/v1/transcoding/fallback-history              | localhost only |
| POST   | /api/v1/transcoding/benchmark                     | localhost only |
| GET    | /api/v1/transcoding/benchmark/progress            | localhost only |
| GET    | /api/v1/transcoding/benchmark/history             | localhost only |
| GET    | /api/v1/transcoding/benchmark/history/{id}        | localhost only |
| DELETE | /api/v1/transcoding/benchmark/history/{id}        | localhost only |

Localhost-only because every endpoint here exposes operator-level metrics
(GPU utilization, VRAM, list of every active session, encoder recommendations,
detected hardware, encoder routing decisions, raw FFmpeg perf measurements,
historical perf comparisons).  Mobile clients do not consume these.
"""

import logging
from datetime import UTC, datetime

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from database.db import get_db
from models.transcoding import TranscodingStatusResponse
from routers.deps import require_local_caller
from services import (
    benchmark_history_service,
    benchmark_service,
    encoder_advisor,
    hardware_probe,
    session_router,
    settings_service,
    transcoding_service,
)

logger = logging.getLogger(__name__)

router = APIRouter()


class AdvisorResponse(BaseModel):
    recommended_encoder: str | None = None
    reason_code: str  # 'cpu_fallback' | 'failed_active' | 'hevc_compat' | 'none'
    reason_text: str
    severity: str  # 'info' | 'warning' | 'none'


class CpuInfo(BaseModel):
    vendor: str
    model: str
    threads: int


class GpuInfo(BaseModel):
    vendor: str  # nvidia | intel | amd | apple | unknown
    model: str
    vram_mb: int | None = None
    driver_version: str | None = None
    # VAAPI render-node path on Linux; null on other platforms.
    dev_path: str | None = None
    # Encoder names from the registry whose vendor matches AND whose
    # platform support set includes the current OS.  Pair with
    # /transcoding/status's `available_encoders` to see the truth.
    encoder_support: list[str]


class DevicesResponse(BaseModel):
    cpus: list[CpuInfo]
    gpus: list[GpuInfo]


class FallbackEventEntry(BaseModel):
    timestamp: str
    session_id: str
    requested_encoder: str
    actual_encoder: str
    # One of: 'configured', 'gpu_session_cap_hit',
    # 'all_encoders_saturated', 'encoder_unknown'.
    reason: str


class FallbackHistoryResponse(BaseModel):
    events: list[FallbackEventEntry]


class BenchmarkRequest(BaseModel):
    """Optional knobs for the benchmark run.

    All fields default sensibly — the desktop UI sends an empty body for the
    common case and only populates ``duration_sec`` / ``fps`` when an operator
    explicitly asks for a longer/shorter sample or a different frame rate.
    """

    duration_sec: int | None = Field(
        default=None,
        ge=2,
        le=20,
        description="Source clip length per encoder (2–20 s).  Defaults to 8.",
    )
    fps: int | None = Field(
        default=None,
        ge=24,
        le=60,
        description=(
            "Source frame rate (24–60).  Higher fps roughly halves the "
            "realtime multiplier per encoder — useful for gauging whether "
            "hardware can drive 60 fps content (sports, gaming captures).  "
            "Going above 60 has no value for this product since the player "
            "doesn't render high-refresh material specially."
        ),
    )
    width: int | None = Field(
        default=None,
        ge=320,
        le=3840,
        description=(
            "Source frame width in pixels.  Paired with ``height``; both "
            "default to the server's 1280 (720p).  Larger frames model "
            "heavier real-world workloads — 1920×1080 for live game "
            "capture, 3840×2160 for 4K HDR transcodes — and let the "
            "operator see how throughput / VRAM / concurrent capacity "
            "scale with the source they actually plan to stream."
        ),
    )
    height: int | None = Field(
        default=None,
        ge=240,
        le=2160,
        description="Source frame height in pixels.  Paired with ``width``.",
    )
    verify_caps: bool = Field(
        default=False,
        description=(
            "When true, run a brief concurrent-stress probe after each hw "
            "encoder benchmark to verify the registry's documented "
            "session cap.  Spawns up to ``max(8, registry_cap*3)`` short "
            "parallel encodes and counts survivors — the empirical answer "
            "for patched drivers / RTX 40-series / driver 530+ that may "
            "have lifted the documented limit.  Briefly saturates the GPU "
            "(~2 s wall-clock per hw encoder) so it's opt-in to avoid "
            "disrupting active streams."
        ),
    )


class BenchmarkEncoderResult(BaseModel):
    """One encoder's perf line in the benchmark response.

    ``passed=False`` rows still carry ``error`` (and possibly ``elapsed_sec``
    when the failure was a timeout) so the desktop renders a ``failed`` row
    rather than dropping the encoder silently.

    ``vendor`` + ``codec`` mirror :class:`services.encoder_registry.EncoderMeta`
    so the desktop UI can group rows by vendor (Software / NVIDIA / Intel /
    AMD / Apple) without re-deriving the mapping client-side.

    ``init_ms`` is wall-clock from spawn to first encoded frame — the
    operator's "stream-start latency" budget.

    ``gpu_utilization_percent`` and ``vram_used_mb`` are sampled once at the
    midpoint of the run via the same per-vendor probes the live status panel
    uses.  Null for software encoders, on probe-binary-missing systems, or
    when the probe fails.

    ``concurrent_session_cap`` mirrors the registry value (NVENC consumer
    cards = 3; software/QSV/VAAPI/VideoToolbox have no enforced cap).
    ``recommended_concurrent`` is ``min(cap, floor(speed_x))`` — the
    practical "how many streams can I sustain at realtime" answer the
    desktop UI shows as a chip per row.
    """

    encoder: str
    vendor: str
    codec: str
    passed: bool
    error: str | None = None
    fps: float | None = None
    speed_x: float | None = None
    bitrate_kbps: float | None = None
    encoded_frames: int | None = None
    elapsed_sec: float | None = None
    realtime_multiplier: float | None = None
    init_ms: int | None = None
    gpu_utilization_percent: float | None = None
    vram_used_mb: int | None = None
    concurrent_session_cap: int | None = None
    recommended_concurrent: int | None = None
    # Empirical session cap from the cap probe — only populated when the
    # request set verify_caps=true AND the encoder has a registry cap.
    # When present, recommended_concurrent above was re-derived against
    # this number rather than the registry default.
    verified_concurrent: int | None = None


class BenchmarkResponse(BaseModel):
    # Autoincrement id from ``benchmark_runs``; the desktop uses it to keep
    # the visible "current run" highlighted in the history sidebar.
    id: int
    started_at: str
    finished_at: str
    duration_sec: int
    fps: int
    width: int
    height: int
    verify_caps: bool
    results: list[BenchmarkEncoderResult]


class BenchmarkProgress(BaseModel):
    """Live progress snapshot for an in-flight benchmark run.

    ``running=False`` is the idle state — every field below it is null.
    The desktop polls this every ~500 ms while its own POST is in flight
    so the operator sees which encoder is currently being tested + a
    derived fraction for the progress bar.
    """

    running: bool
    started_at: str | None = None
    total_encoders: int | None = None
    completed: int | None = None
    current_encoder: str | None = None
    # ``starting`` | ``encoding`` | ``verifying_cap``.  Drives the desktop
    # status line ("Encoding h264_nvenc" vs "Verifying NVENC session cap").
    current_step: str | None = None
    current_index: int | None = None


class BenchmarkHistoryEntry(BaseModel):
    """One row in the history sidebar list — no per-encoder results.

    Operators clicking an entry trigger a follow-up
    ``GET /benchmark/history/{id}`` to fetch the full result body.
    """

    id: int
    started_at: str
    finished_at: str
    duration_sec: int
    fps: int
    width: int
    height: int
    verify_caps: bool
    encoder_count: int


class BenchmarkHistoryResponse(BaseModel):
    entries: list[BenchmarkHistoryEntry]


@router.get("/status", response_model=TranscodingStatusResponse)
async def get_transcoding_status(
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> TranscodingStatusResponse:
    payload = await transcoding_service.get_status(db)
    return TranscodingStatusResponse(**payload)


@router.get("/advisor", response_model=AdvisorResponse)
async def get_advisor(
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> AdvisorResponse:
    """Return a recommendation for the operator's current encoder choice.

    Pure function over current settings + detected encoders + last self-test
    results.  ``reason_code == 'none'`` means "the operator's choice is
    fine; render no banner."
    """
    settings = await settings_service.get_settings(db)
    active = settings.get("transcoding_encoder") or "libx264"
    available = await transcoding_service._detect_available_encoders()
    rec = encoder_advisor.recommend(
        active=active,
        available=available,
        test_results=transcoding_service._TEST_RESULTS,
    )
    return AdvisorResponse(
        recommended_encoder=rec.recommended_encoder,
        reason_code=rec.reason_code,
        reason_text=rec.reason_text,
        severity=rec.severity,
    )


@router.get("/devices", response_model=DevicesResponse)
async def get_devices(
    _local: None = Depends(require_local_caller),
) -> DevicesResponse:
    """Return detected CPU + GPU hardware on the server host.

    Result is cached for the lifetime of the server process — hardware
    doesn't change at runtime, and probes are slow (~500 ms cold on
    Windows).  Slice B of the GPU UX plan.
    """
    payload = await hardware_probe.detect_hardware()
    return DevicesResponse(**payload)


@router.get("/fallback-history", response_model=FallbackHistoryResponse)
async def get_fallback_history(
    _local: None = Depends(require_local_caller),
) -> FallbackHistoryResponse:
    """Return recent encoder routing decisions from session_router.

    Backed by an in-memory ring buffer (max 50 events) — historical
    analysis across server restarts uses ``stream_sessions.encoder_used``
    instead.  Slice C of the GPU UX plan.
    """
    return FallbackHistoryResponse(events=session_router.get_history())


@router.post("/benchmark", response_model=BenchmarkResponse)
async def run_benchmark(
    body: BenchmarkRequest | None = None,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> BenchmarkResponse:
    """Run a short synthetic encode through every available encoder.

    Long-running by design — sequential per-encoder, ~5–10 s of wall-clock
    each on hardware encoders, materially longer if libx264/libx265 is in
    the chain on a slow CPU.  Total wall-time scales with the number of
    detected encoders × the source duration.

    The desktop "Run Benchmark" button shows a spinner; clients should set a
    receive timeout of at least 90 s for this call.  The endpoint itself
    enforces a 35 s ceiling per encoder so the whole call has a hard upper
    bound (encoders × 35 s) regardless of how slow the hardware is.

    Returns one row per encoder with fps / speed / bitrate / realtime-
    multiplier.  Failed/timed-out rows carry ``passed=False`` + ``error``
    rather than being dropped — operators need to see *why* an encoder
    couldn't be benchmarked, not just that it was missing from the list.
    """
    duration = benchmark_service.clamp_duration(
        body.duration_sec if body else None
    )
    fps = benchmark_service.clamp_fps(body.fps if body else None)
    width, height = benchmark_service.clamp_resolution(
        body.width if body else None,
        body.height if body else None,
    )
    verify_caps = bool(body.verify_caps) if body else False

    available = await transcoding_service._detect_available_encoders()
    settings = await settings_service.get_settings(db)
    hwaccel_device = settings.get("transcoding_hwaccel_device")

    started = datetime.now(UTC)
    results = await benchmark_service.run_benchmark(
        available,
        duration_sec=duration,
        fps=fps,
        width=width,
        height=height,
        hwaccel_device=hwaccel_device,
        verify_caps=verify_caps,
    )
    finished = datetime.now(UTC)

    logger.info(
        "Encoder benchmark complete: encoders=%d duration=%ss fps=%s "
        "size=%dx%d verify_caps=%s elapsed=%.1fs",
        len(results),
        duration,
        fps,
        width,
        height,
        verify_caps,
        (finished - started).total_seconds(),
    )

    # Persist before responding so the desktop always sees the run in the
    # history sidebar — failure to persist is a real bug we want to surface
    # rather than a silent drop.  ``save_benchmark_run`` also prunes older
    # entries so the table stays bounded.
    run_id = await benchmark_history_service.save_benchmark_run(
        db,
        started_at=started.isoformat(),
        finished_at=finished.isoformat(),
        duration_sec=duration,
        fps=fps,
        width=width,
        height=height,
        verify_caps=verify_caps,
        results=results,
    )

    return BenchmarkResponse(
        id=run_id,
        started_at=started.isoformat(),
        finished_at=finished.isoformat(),
        duration_sec=duration,
        fps=fps,
        width=width,
        height=height,
        verify_caps=verify_caps,
        results=[
            BenchmarkEncoderResult(
                encoder=r.encoder,
                vendor=r.vendor,
                codec=r.codec,
                passed=r.passed,
                error=r.error,
                fps=r.fps,
                speed_x=r.speed_x,
                bitrate_kbps=r.bitrate_kbps,
                encoded_frames=r.encoded_frames,
                elapsed_sec=r.elapsed_sec,
                realtime_multiplier=r.realtime_multiplier,
                init_ms=r.init_ms,
                gpu_utilization_percent=r.gpu_utilization_percent,
                vram_used_mb=r.vram_used_mb,
                concurrent_session_cap=r.concurrent_session_cap,
                recommended_concurrent=r.recommended_concurrent,
                verified_concurrent=r.verified_concurrent,
            )
            for r in results
        ],
    )


@router.get(
    "/benchmark/progress",
    response_model=BenchmarkProgress,
)
async def get_benchmark_progress(
    _local: None = Depends(require_local_caller),
) -> BenchmarkProgress:
    """Return the in-flight benchmark's progress, or ``running=false``.

    Polled by the desktop ~every 500 ms during a benchmark run so the
    operator sees per-encoder status + a derived progress fraction
    (``completed / total_encoders``).  Reads a module-level snapshot
    from :func:`benchmark_service.get_progress` — no DB hit, cheap to
    call repeatedly.
    """
    snap = benchmark_service.get_progress()
    if snap is None:
        return BenchmarkProgress(running=False)
    return BenchmarkProgress(running=True, **snap)


@router.get(
    "/benchmark/history",
    response_model=BenchmarkHistoryResponse,
)
async def list_benchmark_history(
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
    limit: int = Query(default=20, ge=1, le=50),
) -> BenchmarkHistoryResponse:
    """Return recent benchmark-run summaries, newest first.

    Per-encoder results are excluded for payload size — the desktop fetches
    the full body via :func:`get_benchmark_history_entry` only when the
    operator clicks a row in the sidebar.
    """
    rows = await benchmark_history_service.list_benchmark_runs(db, limit=limit)
    return BenchmarkHistoryResponse(
        entries=[BenchmarkHistoryEntry(**row) for row in rows]
    )


@router.get(
    "/benchmark/history/{run_id}",
    response_model=BenchmarkResponse,
)
async def get_benchmark_history_entry(
    run_id: int,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> BenchmarkResponse:
    """Return the full body for one stored run.  404 if the id is unknown."""
    row = await benchmark_history_service.get_benchmark_run(db, run_id)
    if row is None:
        raise HTTPException(status_code=404, detail="benchmark run not found")
    return BenchmarkResponse(
        id=row["id"],
        started_at=row["started_at"],
        finished_at=row["finished_at"],
        duration_sec=row["duration_sec"],
        fps=row["fps"],
        width=row["width"],
        height=row["height"],
        verify_caps=row["verify_caps"],
        # ``results`` from the JSON blob is already a list of dicts shaped
        # like BenchmarkEncoderResult — Pydantic validates on construction.
        results=[BenchmarkEncoderResult(**r) for r in row["results"]],
    )


@router.delete("/benchmark/history/{run_id}", status_code=204)
async def delete_benchmark_history_entry(
    run_id: int,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> None:
    """Delete one stored run.  404 if the id is unknown."""
    deleted = await benchmark_history_service.delete_benchmark_run(db, run_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="benchmark run not found")
