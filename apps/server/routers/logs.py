"""Structured log filtering for the desktop Logs screen.

| Method | Path                          | Auth           |
|--------|-------------------------------|----------------|
| GET    | /api/v1/logs (filters below)  | localhost only |

Query params: `level` (repeatable), `source`, `since`, `until`, `q`,
`limit` (1..1000 default 200), `cursor` (offset, default 0).

Localhost-only because the log file can contain operator-sensitive
breadcrumbs (file paths, internal IPs, transcoder errors). The mobile
client has no consumer for this surface.
"""

import logging
from pathlib import Path

from fastapi import APIRouter, Depends, Query

from config import settings
from models.log_record import LogListResponse
from routers.deps import require_local_caller
from services import log_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("", response_model=LogListResponse)
async def list_logs(
    level: list[str] | None = Query(default=None),
    source: str | None = Query(default=None),
    since: str | None = Query(default=None),
    until: str | None = Query(default=None),
    q: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=1000),
    cursor: int = Query(default=0, ge=0),
    _local: None = Depends(require_local_caller),
) -> LogListResponse:
    log_path = Path(settings.fluxora_log_path)
    payload = log_service.list_logs(
        log_path,
        levels=level,
        source=source,
        since=since,
        until=until,
        q=q,
        limit=limit,
        cursor=cursor,
    )
    return LogListResponse(**payload)
