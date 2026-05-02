import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, status

from database.db import get_db
from models.settings import UpdateSettingsBody, UserSettingsResponse
from routers.deps import require_local_caller
from services import activity_service, settings_service

logger = logging.getLogger(__name__)

router = APIRouter()

# Boolean columns that SQLite returns as int (0/1) and must be coerced to bool.
_BOOL_COLS = {
    "transcoding_enabled",
    "auto_start_on_boot",
    "auto_restart_on_crash",
    "minimize_to_system_tray",
    "scan_libraries_on_startup",
    "generate_thumbnails",
    "enable_mdns",
    "enable_webrtc",
    "enable_pairing_required",
    "enable_log_export",
}


def _to_response(row: dict) -> UserSettingsResponse:
    # Start with every field that exists in the response model and in the row.
    fields: dict = {k: row[k] for k in UserSettingsResponse.model_fields if k in row}
    # Coerce all boolean columns from SQLite integers to Python bools.
    for col in _BOOL_COLS:
        if col in fields:
            fields[col] = bool(fields[col])
    # License-status fields come from the service enrichment, not the raw row.
    fields["license_status"] = row.get("license_status", "none")
    fields["license_tier"] = row.get("license_tier")
    fields["license_key"] = row.get("license_key")
    return UserSettingsResponse(**fields)


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
    changed = body.model_dump(exclude_none=True)
    try:
        row = await settings_service.update_settings(db, **changed)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    if changed:
        try:
            # Log only the field names changed; values may include license keys
            # or URLs with secrets.
            field_list = sorted(changed.keys())
            await activity_service.record(
                db,
                type="settings.change",
                summary=f"Settings updated: {', '.join(field_list)}",
                actor_kind="operator",
                target_kind="settings",
                payload={"fields": field_list},
            )
        except Exception:
            logger.warning(
                "Failed to record settings.change activity event", exc_info=True
            )
    return _to_response(row)
