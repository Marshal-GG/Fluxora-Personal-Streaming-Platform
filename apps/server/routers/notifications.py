"""Notification list / mark-read / dismiss.

| Method | Path                                    | Auth                  |
|--------|-----------------------------------------|-----------------------|
| GET    | /api/v1/notifications/?unread=&limit=   | localhost or token    |
| POST   | /api/v1/notifications/{id}/read         | localhost or token    |
| POST   | /api/v1/notifications/read-all          | localhost or token    |
| DELETE | /api/v1/notifications/{id}              | localhost or token    |

GETs and mutations both accept the desktop control panel (loopback) and
the mobile / off-LAN clients (bearer token), since the notifications
feed is per-server, not per-client. The desktop sidebar bell is the
primary consumer; mobile may surface select categories.
"""

import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, Query, status

from database.db import get_db
from models.notification import NotificationResponse
from routers.deps import validate_token_or_local
from services import notification_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("", response_model=list[NotificationResponse])
async def list_notifications(
    unread: bool = Query(default=False),
    limit: int = Query(default=50, ge=1, le=200),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[NotificationResponse]:
    rows = await notification_service.list_notifications(
        db, only_unread=unread, limit=limit
    )
    return [NotificationResponse(**r) for r in rows]


@router.post("/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def mark_all_read(
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> None:
    await notification_service.mark_all_read(db)


@router.post("/{notif_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_read(
    notif_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> None:
    ok = await notification_service.mark_read(db, notif_id)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found or already read/dismissed",
        )


@router.delete("/{notif_id}", status_code=status.HTTP_204_NO_CONTENT)
async def dismiss(
    notif_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> None:
    ok = await notification_service.dismiss(db, notif_id)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found or already dismissed",
        )
