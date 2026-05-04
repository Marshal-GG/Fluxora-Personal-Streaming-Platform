"""Transcoding status + advisor — desktop Transcoding / Settings screens.

| Method | Path                          | Auth           |
|--------|-------------------------------|----------------|
| GET    | /api/v1/transcoding/status    | localhost only |
| GET    | /api/v1/transcoding/advisor   | localhost only |

Localhost-only because both expose operator-level metrics (GPU utilization,
VRAM, list of every active session, encoder recommendations).  Mobile
clients do not consume these.
"""

import logging

import aiosqlite
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from database.db import get_db
from models.transcoding import TranscodingStatusResponse
from routers.deps import require_local_caller
from services import encoder_advisor, settings_service, transcoding_service

logger = logging.getLogger(__name__)

router = APIRouter()


class AdvisorResponse(BaseModel):
    recommended_encoder: str | None = None
    reason_code: str  # 'cpu_fallback' | 'failed_active' | 'hevc_compat' | 'none'
    reason_text: str
    severity: str  # 'info' | 'warning' | 'none'


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
