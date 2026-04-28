import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, status

from database.db import get_db
from models.settings import UpdateSettingsBody, UserSettingsResponse
from routers.deps import require_local_caller
from services import settings_service

logger = logging.getLogger(__name__)

router = APIRouter()


def _to_response(row: dict) -> UserSettingsResponse:
    return UserSettingsResponse(
        server_name=row["server_name"],
        subscription_tier=row["subscription_tier"],
        max_concurrent_streams=row["max_concurrent_streams"],
        transcoding_enabled=bool(row["transcoding_enabled"]),
        license_key=row.get("license_key"),
        license_status=row.get("license_status", "none"),
        license_tier=row.get("license_tier"),
    )


@router.get("", response_model=UserSettingsResponse)
async def get_settings(
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> UserSettingsResponse:
    row = await settings_service.get_settings(db)
    return _to_response(row)


@router.patch("", response_model=UserSettingsResponse)
async def update_settings(
    body: UpdateSettingsBody,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> UserSettingsResponse:
    try:
        row = await settings_service.update_settings(
            db,
            server_name=body.server_name,
            tier=body.tier,
            license_key=body.license_key,
            transcoding_enabled=body.transcoding_enabled,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    return _to_response(row)
