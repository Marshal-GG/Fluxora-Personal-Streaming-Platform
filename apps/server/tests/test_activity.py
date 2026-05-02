"""Tests for /api/v1/activity and activity_service."""

from __future__ import annotations

import asyncio

import pytest
from httpx import ASGITransport, AsyncClient

from main import app
from services import activity_service

# ── service-level ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_record_inserts_and_lists(test_db):
    await activity_service.record(
        test_db,
        type="stream.start",
        summary="Test summary",
        actor_kind="client",
        actor_id="client-1",
        target_kind="session",
        target_id="session-1",
    )
    rows = await activity_service.list_events(test_db)
    assert len(rows) == 1
    assert rows[0]["type"] == "stream.start"
    assert rows[0]["summary"] == "Test summary"
    assert rows[0]["actor_kind"] == "client"
    assert rows[0]["actor_id"] == "client-1"


@pytest.mark.asyncio
async def test_list_orders_recent_first(test_db):
    await activity_service.record(test_db, type="stream.start", summary="First event")
    await asyncio.sleep(0.01)
    await activity_service.record(test_db, type="stream.end", summary="Second event")
    await asyncio.sleep(0.01)
    await activity_service.record(test_db, type="client.pair", summary="Third event")
    rows = await activity_service.list_events(test_db)
    assert len(rows) == 3
    # Most recent first
    assert rows[0]["summary"] == "Third event"
    assert rows[1]["summary"] == "Second event"
    assert rows[2]["summary"] == "First event"


@pytest.mark.asyncio
async def test_type_prefix_filter(test_db):
    await activity_service.record(test_db, type="stream.start", summary="s1")
    await asyncio.sleep(0.01)
    await activity_service.record(test_db, type="stream.end", summary="s2")
    await asyncio.sleep(0.01)
    await activity_service.record(test_db, type="client.pair", summary="c1")

    rows = await activity_service.list_events(test_db, type_prefix="stream.")
    assert len(rows) == 2
    for r in rows:
        assert r["type"].startswith("stream.")


@pytest.mark.asyncio
async def test_since_filter(test_db):
    event_a = await activity_service.record(
        test_db, type="stream.start", summary="Event A"
    )
    await asyncio.sleep(0.01)
    ts_between = event_a["created_at"]
    await asyncio.sleep(0.01)
    await activity_service.record(test_db, type="stream.end", summary="Event B")

    rows = await activity_service.list_events(test_db, since=ts_between)
    assert len(rows) == 1
    assert rows[0]["summary"] == "Event B"


@pytest.mark.asyncio
async def test_payload_json_roundtrip(test_db):
    payload = {"foo": 1, "bar": "baz"}
    await activity_service.record(
        test_db,
        type="stream.start",
        summary="With payload",
        payload=payload,
    )
    rows = await activity_service.list_events(test_db)
    assert len(rows) == 1
    assert isinstance(rows[0]["payload"], dict)
    assert rows[0]["payload"] == payload


@pytest.mark.asyncio
async def test_payload_invalid_json_returns_null(test_db):
    import uuid
    from datetime import UTC, datetime

    event_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO activity_events
            (id, type, actor_kind, actor_id, target_kind, target_id,
             summary, payload, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            event_id,
            "stream.start",
            None,
            None,
            None,
            None,
            "Bad payload event",
            "not json",
            now,
        ),
    )
    await test_db.commit()

    rows = await activity_service.list_events(test_db)
    bad_row = next((r for r in rows if r["id"] == event_id), None)
    assert bad_row is not None
    assert bad_row["payload"] is None


# ── REST endpoints ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_endpoint_list(client: AsyncClient, test_db):
    await activity_service.record(
        test_db, type="stream.start", summary="From endpoint test"
    )
    resp = await client.get("/api/v1/activity")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert any(r["summary"] == "From endpoint test" for r in data)


@pytest.mark.asyncio
async def test_endpoint_limit_clamp(client: AsyncClient):
    # limit > 200 should yield 422
    resp = await client.get("/api/v1/activity?limit=300")
    assert resp.status_code == 422

    # limit = 0 should yield 422
    resp = await client.get("/api/v1/activity?limit=0")
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_endpoint_type_filter(client: AsyncClient, test_db):
    await activity_service.record(test_db, type="stream.start", summary="s-start")
    await asyncio.sleep(0.01)
    await activity_service.record(test_db, type="stream.end", summary="s-end")
    await asyncio.sleep(0.01)
    await activity_service.record(test_db, type="client.pair", summary="c-pair")

    resp = await client.get("/api/v1/activity?type=stream.")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 2
    for item in data:
        assert item["type"].startswith("stream.")


@pytest.mark.asyncio
async def test_endpoint_since_filter(client: AsyncClient, test_db):
    event_a = await activity_service.record(
        test_db, type="stream.start", summary="Before TS"
    )
    await asyncio.sleep(0.01)
    ts = event_a["created_at"]
    await asyncio.sleep(0.01)
    await activity_service.record(test_db, type="stream.end", summary="After TS")

    resp = await client.get("/api/v1/activity", params={"since": ts})
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["summary"] == "After TS"


@pytest.mark.asyncio
async def test_pair_request_emits_activity(client: AsyncClient):
    body = {
        "client_id": "activity-test-client",
        "device_name": "Activity Phone",
        "platform": "ios",
        "app_version": "1.0.0",
    }
    pair = await client.post("/api/v1/auth/request-pair", json=body)
    assert pair.status_code == 200

    listing = await client.get("/api/v1/activity")
    rows = listing.json()
    assert any(
        r["type"] == "client.pair"
        and r["actor_id"] == "activity-test-client"
        and "Activity Phone" in r["summary"]
        for r in rows
    )


@pytest.mark.asyncio
async def test_endpoint_requires_token_off_loopback(test_db):
    """Off-loopback caller without a bearer token gets 401."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("203.0.113.7", 50000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.get(
            "/api/v1/activity",
            headers={"CF-Connecting-IP": "203.0.113.7"},
        )
    assert resp.status_code == 401


# ── extended emitters (file.upload, settings.change, client.revoke) ───────


@pytest.mark.asyncio
async def test_settings_change_emits_activity(client: AsyncClient):
    resp = await client.patch("/api/v1/settings", json={"server_name": "Renamed"})
    assert resp.status_code == 200
    listing = await client.get("/api/v1/activity")
    rows = listing.json()
    match = next((r for r in rows if r["type"] == "settings.change"), None)
    assert match is not None
    assert match["actor_kind"] == "operator"
    # Field names logged, values not
    assert match["payload"]["fields"] == ["server_name"]
    assert "Renamed" not in match["summary"]


@pytest.mark.asyncio
async def test_settings_change_skipped_when_body_empty(client: AsyncClient):
    """Empty PATCH (all fields excluded as None) emits no activity event."""
    before = await client.get("/api/v1/activity")
    before_count = len(before.json())
    resp = await client.patch("/api/v1/settings", json={})
    assert resp.status_code == 200
    after = await client.get("/api/v1/activity")
    after_settings = [r for r in after.json() if r["type"] == "settings.change"]
    assert len(after_settings) == 0
    # Total event count unchanged
    assert len(after.json()) == before_count


@pytest.mark.asyncio
async def test_revoke_emits_activity(client: AsyncClient, monkeypatch):
    """Revoking a paired client emits a client.revoke event with operator
    actor and the revoked client_id as target."""
    monkeypatch.setattr(
        "routers.auth.settings.token_hmac_key", "test-secret-key-for-unit-tests-only"
    )
    body = {
        "client_id": "to-revoke",
        "device_name": "Phone",
        "platform": "android",
        "app_version": "0.1.0",
    }
    await client.post("/api/v1/auth/request-pair", json=body)
    await client.post("/api/v1/auth/approve/to-revoke")

    resp = await client.delete("/api/v1/auth/revoke/to-revoke")
    assert resp.status_code == 204

    listing = await client.get("/api/v1/activity")
    rows = listing.json()
    match = next(
        (
            r
            for r in rows
            if r["type"] == "client.revoke" and r["target_id"] == "to-revoke"
        ),
        None,
    )
    assert match is not None
    assert match["actor_kind"] == "operator"
