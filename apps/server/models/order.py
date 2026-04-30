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
