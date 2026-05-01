"""Activity event log — desktop Activity screen + Dashboard widget.

| Method | Path | Auth |
|--------|------|------|
| GET    | /api/v1/activity?limit=&since=&type= | localhost or token |

Query params:
- `limit`  — 1..200 (default 50). Dashboard widget uses 4.
- `since`  — ISO-8601 timestamp; returns events strictly after this.
- `type`   — event-type prefix (e.g. `stream.` matches stream.start +
             stream.end). Pass the full type for an exact match.
"""

import logging

import aiosqlite
from fastapi import APIRouter, Depends, Query

from database.db import get_db
from models.activity import ActivityEventResponse
from routers.deps import validate_token_or_local
from services import activity_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("", response_model=list[ActivityEventResponse])
async def list_activity(
    limit: int = Query(default=50, ge=1, le=200),
    since: str | None = Query(default=None),
    type: str | None = Query(default=None),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[ActivityEventResponse]:
    rows = await activity_service.list_events(
        db, limit=limit, since=since, type_prefix=type
    )
    return [ActivityEventResponse(**r) for r in rows]
