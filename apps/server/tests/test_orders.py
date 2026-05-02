"""Tests for GET /api/v1/orders — owner license key retrieval."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from main import app

pytestmark = pytest.mark.asyncio

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _insert_order(
    db_conn, order_id: str, tier: str, key: str, email: str | None = None
) -> None:
    await db_conn.execute(
        """
        INSERT INTO polar_orders (
            order_id, customer_email, tier, license_key, processed_at
        )
        VALUES (?, ?, ?, ?, '2026-04-29T00:00:00')
        """,
        (order_id, email, tier, key),
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
    await _insert_order(
        test_db, "order-001", "plus", "FLUXORA-PLUS-X", "alice@example.com"
    )
    await _insert_order(test_db, "order-002", "pro", "FLUXORA-PRO-Y")

    resp = await client.get("/api/v1/orders")
    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 2

    # Check Alice
    alice = next(o for o in body["orders"] if o["order_id"] == "order-001")
    assert alice["customer_email"] == "alice@example.com"

    # Check order without email
    other = next(o for o in body["orders"] if o["order_id"] == "order-002")
    assert other["customer_email"] is None

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
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as remote_client:
        resp = await remote_client.get("/api/v1/orders")
        assert resp.status_code == 403


# ── pagination + portal URL (§7.11) ──────────────────────────────────────


async def test_list_orders_pagination(client, test_db):
    """Insert 5 orders; limit=2 returns the 2 newest, next_cursor=2."""
    for i in range(5):
        await _insert_order(
            test_db,
            f"order-{i}",
            "pro",
            f"KEY-{i}",
            email=f"u{i}@e.com",
        )

    page1 = await client.get("/api/v1/orders?limit=2&cursor=0")
    body = page1.json()
    assert page1.status_code == 200
    assert len(body["orders"]) == 2
    assert body["total"] == 2
    assert body["total_all"] == 5
    assert body["next_cursor"] == 2

    page3 = await client.get(f"/api/v1/orders?limit=2&cursor={body['next_cursor'] + 2}")
    body3 = page3.json()
    assert len(body3["orders"]) == 1
    assert body3["next_cursor"] is None


async def test_list_orders_limit_validation(client):
    resp = await client.get("/api/v1/orders?limit=0")
    assert resp.status_code == 422
    resp = await client.get("/api/v1/orders?limit=300")
    assert resp.status_code == 422


async def test_portal_url_404_when_unset(client, monkeypatch):
    monkeypatch.setattr("routers.orders.settings.polar_portal_url", "")
    resp = await client.get("/api/v1/orders/portal-url")
    assert resp.status_code == 404


async def test_portal_url_returns_configured(client, monkeypatch):
    monkeypatch.setattr(
        "routers.orders.settings.polar_portal_url",
        "https://polar.sh/fluxora/portal",
    )
    resp = await client.get("/api/v1/orders/portal-url")
    assert resp.status_code == 200
    assert resp.json() == {"url": "https://polar.sh/fluxora/portal"}


async def test_portal_url_blocked_from_lan(monkeypatch, test_db):
    monkeypatch.setattr(
        "routers.orders.settings.polar_portal_url",
        "https://polar.sh/fluxora/portal",
    )
    transport = ASGITransport(app=app, client=("192.168.1.100", 12345))
    async with AsyncClient(transport=transport, base_url="http://test") as remote:
        resp = await remote.get("/api/v1/orders/portal-url")
        assert resp.status_code == 403
