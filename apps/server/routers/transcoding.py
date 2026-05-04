"""Transcoding status + advisor + devices + fallback-history.

| Method | Path                                    | Auth           |
|--------|-----------------------------------------|----------------|
| GET    | /api/v1/transcoding/status              | localhost only |
| GET    | /api/v1/transcoding/advisor             | localhost only |
| GET    | /api/v1/transcoding/devices             | localhost only |
| GET    | /api/v1/transcoding/fallback-history    | localhost only |

Localhost-only because every endpoint here exposes operator-level metrics
(GPU utilization, VRAM, list of every active session, encoder recommendations,
detected hardware, encoder routing decisions).  Mobile clients do not
consume these.
"""

import logging

import aiosqlite
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from database.db import get_db
from models.transcoding import TranscodingStatusResponse
from routers.deps import require_local_caller
from services import (
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
    reason: str  # 'configured' | 'gpu_session_cap_hit' | 'all_encoders_saturated' | 'encoder_unknown'


class FallbackHistoryResponse(BaseModel):
    events: list[FallbackEventEntry]


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
