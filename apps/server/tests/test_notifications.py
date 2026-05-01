"""Tests for /api/v1/notifications and the notification_service pub/sub."""

from __future__ import annotations

import asyncio

import pytest
from httpx import ASGITransport, AsyncClient

from main import app
from services import notification_service

# ── service-level: CRUD ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_inserts_and_lists(test_db):
    await notification_service.create(
        test_db,
        type="info",
        category="client",
        title="Hello",
        message="World",
    )
    rows = await notification_service.list_notifications(test_db)
    assert len(rows) == 1
    assert rows[0]["title"] == "Hello"
    assert rows[0]["read_at"] is None
    assert rows[0]["dismissed_at"] is None


@pytest.mark.asyncio
async def test_only_unread_filter(test_db):
    n1 = await notification_service.create(
        test_db, type="info", category="client", title="A", message="a"
    )
    await notification_service.create(
        test_db, type="info", category="client", title="B", message="b"
    )
    await notification_service.mark_read(test_db, n1["id"])

    all_rows = await notification_service.list_notifications(test_db)
    unread_rows = await notification_service.list_notifications(
        test_db, only_unread=True
    )
    assert len(all_rows) == 2
    assert len(unread_rows) == 1
    assert unread_rows[0]["title"] == "B"


@pytest.mark.asyncio
async def test_mark_read_idempotent(test_db):
    n = await notification_service.create(
        test_db, type="info", category="client", title="x", message="y"
    )
    assert await notification_service.mark_read(test_db, n["id"]) is True
    assert await notification_service.mark_read(test_db, n["id"]) is False


@pytest.mark.asyncio
async def test_mark_all_read(test_db):
    await notification_service.create(
        test_db, type="info", category="client", title="A", message="a"
    )
    await notification_service.create(
        test_db, type="info", category="client", title="B", message="b"
    )
    count = await notification_service.mark_all_read(test_db)
    assert count == 2
    assert (
        len(await notification_service.list_notifications(test_db, only_unread=True))
        == 0
    )


@pytest.mark.asyncio
async def test_dismiss_excludes_from_default_list(test_db):
    n = await notification_service.create(
        test_db, type="warning", category="storage", title="full", message="..."
    )
    assert await notification_service.dismiss(test_db, n["id"]) is True
    rows = await notification_service.list_notifications(test_db)
    assert rows == []


# ── service-level: pubsub ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_subscribe_unsubscribe_pubsub(test_db):
    q = notification_service.subscribe()
    try:
        await notification_service.create(
            test_db, type="info", category="client", title="ping", message="m"
        )
        # Frame should be available immediately
        frame = await asyncio.wait_for(q.get(), timeout=1.0)
        assert frame["type"] == "notification"
        assert frame["data"]["title"] == "ping"
    finally:
        notification_service.unsubscribe(q)

    # After unsubscribe, no further frames
    await notification_service.create(
        test_db, type="info", category="client", title="post", message="m"
    )
    assert q.empty()


# ── REST endpoints ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_endpoint_list_and_unread_filter(client: AsyncClient, test_db):
    n = await notification_service.create(
        test_db, type="info", category="client", title="A", message="a"
    )
    await notification_service.create(
        test_db, type="info", category="client", title="B", message="b"
    )
    await notification_service.mark_read(test_db, n["id"])

    all_resp = await client.get("/api/v1/notifications")
    assert all_resp.status_code == 200
    assert len(all_resp.json()) == 2

    unread_resp = await client.get("/api/v1/notifications?unread=true")
    assert unread_resp.status_code == 200
    assert len(unread_resp.json()) == 1


@pytest.mark.asyncio
async def test_endpoint_mark_read_404(client: AsyncClient):
    resp = await client.post("/api/v1/notifications/nope/read")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_endpoint_dismiss(client: AsyncClient, test_db):
    n = await notification_service.create(
        test_db, type="info", category="client", title="x", message="y"
    )
    resp = await client.delete(f"/api/v1/notifications/{n['id']}")
    assert resp.status_code == 204
    second = await client.delete(f"/api/v1/notifications/{n['id']}")
    assert second.status_code == 404


@pytest.mark.asyncio
async def test_endpoint_read_all(client: AsyncClient, test_db):
    await notification_service.create(
        test_db, type="info", category="client", title="A", message="a"
    )
    await notification_service.create(
        test_db, type="info", category="client", title="B", message="b"
    )
    resp = await client.post("/api/v1/notifications/read-all")
    assert resp.status_code == 204
    unread = await client.get("/api/v1/notifications?unread=true")
    assert unread.json() == []


# ── auth-service emitter integration ───────────────────────────────────────


@pytest.mark.asyncio
async def test_pair_request_emits_notification(client: AsyncClient):
    body = {
        "client_id": "notif-test-client",
        "device_name": "Notif Phone",
        "platform": "android",
        "app_version": "0.1.0",
    }
    pair = await client.post("/api/v1/auth/request-pair", json=body)
    assert pair.status_code == 200

    listing = await client.get("/api/v1/notifications")
    rows = listing.json()
    assert any(
        r["category"] == "client"
        and r["related_id"] == "notif-test-client"
        and "Notif Phone" in r["message"]
        for r in rows
    )


# ── auth ──────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_endpoint_requires_token_off_loopback(test_db):
    """Off-loopback caller without a bearer token gets 401."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("203.0.113.7", 50000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.get(
            "/api/v1/notifications",
            headers={"CF-Connecting-IP": "203.0.113.7"},
        )
    assert resp.status_code == 401
