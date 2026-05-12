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
    # transcoding_chain is stored as JSON-encoded TEXT; decode for the
    # response so the desktop sees a list (or null for "use default").
    if "transcoding_chain" in fields:
        from services.session_router import parse_chain

        chain = parse_chain(fields["transcoding_chain"])
        fields["transcoding_chain"] = chain or None
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


_ENCODER_CHANGE_FIELDS = {"transcoding_encoder", "transcoding_hwaccel_device"}


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

    # If the encoder or VAAPI device path changed, re-run self-tests so the
    # new choice is validated immediately and _TEST_RESULTS stays current.
    if _ENCODER_CHANGE_FIELDS & changed.keys():
        import asyncio as _asyncio

        from services import transcoding_service as _ts

        async def _retest() -> None:
            try:
                avail = await _ts._detect_available_encoders()
                device = row.get("transcoding_hwaccel_device")
                await _ts.run_encoder_self_tests(avail, device)
                # Reuse the same DB connection — settings change happens
                # within the request; our background task uses the shared
                # singleton.  Re-emit so any new failure pattern (e.g.
                # operator switched hwaccel device and the new path is
                # broken) surfaces in the bell.
                from database.db import get_db as _get_db

                _db = await _get_db()
                await _ts.emit_encoder_failure_notifications(_db)
            except Exception:
                logger.warning(
                    "Encoder re-test after settings change failed",
                    exc_info=True,
                )

        _asyncio.create_task(_retest())

    return _to_response(row)
