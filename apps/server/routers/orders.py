"""Orders router — owner-only license key retrieval.

GET /api/v1/orders
    Returns all rows from polar_orders (order_id, tier, license_key, processed_at).
    Restricted to localhost callers via require_local_caller.
    This endpoint lets the owner look up generated license keys so they can be
    sent to customers manually (until automated delivery is implemented).
"""

from __future__ import annotations

import logging

import aiosqlite
from fastapi import APIRouter, Depends

from database.db import get_db
from models.order import PolarOrderItem, PolarOrderListResponse
from routers.deps import require_local_caller

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("", response_model=PolarOrderListResponse)
async def list_orders(
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> PolarOrderListResponse:
    """Return all processed Polar orders with their generated license keys.

    Only callable from localhost. Intended for the Desktop Control Panel owner
    retrieval screen so keys can be forwarded to customers manually.
    """
    db.row_factory = aiosqlite.Row
    cursor = await db.execute(
        """
        SELECT order_id, customer_email, tier, license_key, processed_at
        FROM polar_orders
        ORDER BY processed_at DESC
        """
    )
    rows = await cursor.fetchall()
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
    logger.info("Owner retrieved %d polar_order record(s)", len(items))
    return PolarOrderListResponse(orders=items, total=len(items))
