"""Pydantic models for Polar order / license key retrieval."""

from __future__ import annotations

from pydantic import BaseModel


class PolarOrderItem(BaseModel):
    order_id: str
    customer_email: str | None
    tier: str
    license_key: str
    processed_at: str


class PolarOrderListResponse(BaseModel):
    orders: list[PolarOrderItem]
    total: int
    # Total count of orders in the table (independent of `limit`). Lets the
    # UI show "1-20 of 47" without a separate count query.
    total_all: int = 0
    # Pass back to the next request as `?cursor=` to fetch the next page.
    # Null when this is the last page.
    next_cursor: int | None = None


class PortalUrlResponse(BaseModel):
    url: str
