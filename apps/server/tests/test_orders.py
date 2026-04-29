"""Tests for GET /api/v1/orders — owner license key retrieval."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient
from main import app

pytestmark = pytest.mark.asyncio

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _insert_order(db_conn, order_id: str, tier: str, key: str) -> None:
    await db_conn.execute(
        """
        INSERT INTO polar_orders (order_id, tier, license_key, processed_at)
        VALUES (?, ?, ?, '2026-04-29T00:00:00')
        """,
        (order_id, tier, key),
    )
    await db_conn.commit()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

async def test_list_orders_empty(client):
    """Empty table returns an empty list, not an error."""
    resp = await client.get("/api/v1/orders")
    assert resp.status_code == 200
    body = resp.json()
    assert body["orders"] == []
    assert body["total"] == 0


async def test_list_orders_returns_rows(client, test_db):
    """Inserted orders are returned with correct fields."""
    await _insert_order(test_db, "order-001", "plus", "FLUXORA-PLUS-20270429-AABBCC")
    await _insert_order(test_db, "order-002", "pro", "FLUXORA-PRO-20270429-DDEEFF")

    resp = await client.get("/api/v1/orders")
    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 2
    ids = {o["order_id"] for o in body["orders"]}
    assert ids == {"order-001", "order-002"}
    for order in body["orders"]:
        assert "license_key" in order
        assert "tier" in order
        assert "processed_at" in order


async def test_list_orders_sorted_newest_first(client, test_db):
    """Orders are returned newest-first by processed_at."""
    await test_db.execute(
        """
        INSERT INTO polar_orders (order_id, tier, license_key, processed_at)
        VALUES ('old-order', 'plus', 'KEY-OLD', '2026-01-01T00:00:00')
        """
    )
    await test_db.execute(
        """
        INSERT INTO polar_orders (order_id, tier, license_key, processed_at)
        VALUES ('new-order', 'pro', 'KEY-NEW', '2026-06-01T00:00:00')
        """
    )
    await test_db.commit()

    resp = await client.get("/api/v1/orders")
    assert resp.status_code == 200
    orders = resp.json()["orders"]
    assert orders[0]["order_id"] == "new-order"
    assert orders[1]["order_id"] == "old-order"


async def test_list_orders_blocked_from_lan(test_db):
    """Non-localhost callers must be rejected with 403."""
    await _insert_order(test_db, "order-lan", "pro", "FLUXORA-PRO-X")
    
    # Create an AsyncClient that simulates a remote IP connection
    transport = ASGITransport(app=app, client=("192.168.1.100", 12345))
    async with AsyncClient(transport=transport, base_url="http://test") as remote_client:
        resp = await remote_client.get("/api/v1/orders")
        assert resp.status_code == 403
