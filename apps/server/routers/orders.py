"""Orders router — owner-only license key retrieval.

| Method | Path                                    | Auth           |
|--------|-----------------------------------------|----------------|
| GET    | /api/v1/orders?limit=&cursor=           | localhost only |
| GET    | /api/v1/orders/portal-url               | localhost only |

`portal-url` returns the configured Polar customer-portal landing URL
(set via the `FLUXORA_POLAR_PORTAL_URL` env var) so the desktop
Subscription screen can deep-link the customer to manage payment or
cancel. 404 when the env var is unset.
"""

from __future__ import annotations

import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, Query, status

from config import settings
from database.db import get_db
from models.order import (
    PolarOrderItem,
    PolarOrderListResponse,
    PortalUrlResponse,
)
from routers.deps import require_local_caller

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/portal-url", response_model=PortalUrlResponse)
async def get_portal_url(
    _local: None = Depends(require_local_caller),
) -> PortalUrlResponse:
    """Return the configured Polar customer-portal URL, or 404 if unset."""
    if not settings.polar_portal_url:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=(
                "Polar customer portal not configured. "
                "Set FLUXORA_POLAR_PORTAL_URL in ~/.fluxora/.env."
            ),
        )
    return PortalUrlResponse(url=settings.polar_portal_url)


@router.get("", response_model=PolarOrderListResponse)
async def list_orders(
    limit: int = Query(default=20, ge=1, le=200),
    cursor: int = Query(default=0, ge=0),
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> PolarOrderListResponse:
    """Return processed Polar orders, paginated.

    Cursor is a 0-based row offset. The next page is `cursor + limit`;
    `next_cursor` is null when the page returns fewer than `limit` rows.
    """
    db.row_factory = aiosqlite.Row

    async with db.execute("SELECT COUNT(*) FROM polar_orders") as count_cur:
        count_row = await count_cur.fetchone()
    total_all = int(count_row[0]) if count_row else 0

    cur = await db.execute(
        """
        SELECT order_id, customer_email, tier, license_key, processed_at
          FROM polar_orders
         ORDER BY processed_at DESC
         LIMIT ? OFFSET ?
        """,
        (limit, cursor),
    )
    rows = await cur.fetchall()
    items = [
        PolarOrderItem(
            order_id=row["order_id"],
            customer_email=row["customer_email"],
            tier=row["tier"],
            license_key=row["license_key"],
            processed_at=row["processed_at"],
        )
        for row in rows
    ]
    next_cursor = cursor + limit if cursor + limit < total_all else None
    logger.info(
        "Owner retrieved %d/%d polar_order record(s) (cursor=%d)",
        len(items),
        total_all,
        cursor,
    )
    return PolarOrderListResponse(
        orders=items,
        total=len(items),
        total_all=total_all,
        next_cursor=next_cursor,
    )
