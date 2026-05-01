"""Transcoding status — desktop Transcoding screen.

| Method | Path                          | Auth           |
|--------|-------------------------------|----------------|
| GET    | /api/v1/transcoding/status    | localhost only |

Localhost-only because it exposes operator-level metrics (GPU utilization,
VRAM, list of every active session). Mobile clients do not consume this.
"""

import logging

import aiosqlite
from fastapi import APIRouter, Depends

from database.db import get_db
from models.transcoding import TranscodingStatusResponse
from routers.deps import require_local_caller
from services import transcoding_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/status", response_model=TranscodingStatusResponse)
async def get_transcoding_status(
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> TranscodingStatusResponse:
    payload = await transcoding_service.get_status(db)
    return TranscodingStatusResponse(**payload)
