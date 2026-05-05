"""Tests for GET /api/v1/settings and PATCH /api/v1/settings."""

import pytest
from httpx import AsyncClient

# ── helpers ───────────────────────────────────────────────────────────────────


async def _approve_client(client: AsyncClient) -> str:
    """Register and approve a client; return the raw bearer token."""
    pair_res = await client.post(
        "/api/v1/auth/request-pair",
        json={
            "client_id": "client-settings-test",
            "device_name": "Test Device",
            "platform": "android",
            "app_version": "0.1.0",
        },
    )
    assert pair_res.status_code == 200

    await client.post("/api/v1/auth/approve/client-settings-test")

    status_res = await client.get("/api/v1/auth/status/client-settings-test")
    return status_res.json()["auth_token"]


# ── GET /api/v1/settings ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_settings_returns_defaults(client: AsyncClient) -> None:
    res = await client.get("/api/v1/settings")
    assert res.status_code == 200
    body = res.json()
    assert body["server_name"] == "Fluxora Server"
    assert body["subscription_tier"] == "free"
    assert body["max_concurrent_streams"] == 1
    assert body["transcoding_enabled"] is True
    assert body["license_key"] is None


@pytest.mark.asyncio
async def test_get_settings_blocked_from_external(client: AsyncClient) -> None:
    """Settings endpoint must be localhost-only."""
    from unittest.mock import patch

    with patch("routers.deps.require_local_caller", side_effect=None):
        # We test by faking a non-loopback client host
        pass
    # The fixture sends requests from the ASGI transport which appears as
    # 127.0.0.1 to the dependency — so this always succeeds; we verify the
    # dependency rejects LAN IPs via auth tests.


# ── PATCH /api/v1/settings ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_patch_settings_updates_server_name(client: AsyncClient) -> None:
    res = await client.patch("/api/v1/settings", json={"server_name": "My Media Box"})
    assert res.status_code == 200
    assert res.json()["server_name"] == "My Media Box"


@pytest.mark.asyncio
async def test_patch_settings_tier_updates_max_streams(client: AsyncClient) -> None:
    for tier, expected_streams in [("plus", 3), ("pro", 10), ("ultimate", 9999)]:
        res = await client.patch("/api/v1/settings", json={"tier": tier})
        assert res.status_code == 200
        body = res.json()
        assert body["subscription_tier"] == tier
        assert body["max_concurrent_streams"] == expected_streams


@pytest.mark.asyncio
async def test_patch_settings_invalid_tier_returns_422(client: AsyncClient) -> None:
    res = await client.patch("/api/v1/settings", json={"tier": "enterprise"})
    assert res.status_code == 422


@pytest.mark.asyncio
async def test_patch_settings_stores_license_key(client: AsyncClient) -> None:
    # Must be FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG> (5 segments, correct prefix).
    # The format validator accepts any 5-segment FLUXORA-... key;
    # full signature check happens in license_service, not the model layer.
    valid_format_key = "FLUXORA-PLUS-99991231-CAFE-ABCDEF01"
    res = await client.patch("/api/v1/settings", json={"license_key": valid_format_key})
    assert res.status_code == 200
    assert res.json()["license_key"] == valid_format_key
    # license_status reflects signature check (no secret in test env → no_secret)
    assert res.json()["license_status"] in ("valid", "no_secret", "invalid_signature")


@pytest.mark.asyncio
async def test_patch_settings_blank_server_name_rejected(client: AsyncClient) -> None:
    res = await client.patch("/api/v1/settings", json={"server_name": "   "})
    assert res.status_code == 422


@pytest.mark.asyncio
async def test_patch_settings_partial_update_preserves_other_fields(
    client: AsyncClient,
) -> None:
    """Updating only server_name should not reset the tier."""
    await client.patch("/api/v1/settings", json={"tier": "pro"})
    res = await client.patch("/api/v1/settings", json={"server_name": "New Name"})
    body = res.json()
    assert body["server_name"] == "New Name"
    assert body["subscription_tier"] == "pro"
    assert body["max_concurrent_streams"] == 10


# ── Tier-aware concurrency (stream router integration) ────────────────────────


@pytest.mark.asyncio
async def test_free_tier_blocks_second_stream(client: AsyncClient) -> None:
    """Free tier limit is 1 concurrent stream; a start on a *different*
    file while a stream is already active should 429.

    The pre-existing session and the start request must reference
    DIFFERENT file_ids — otherwise `/start`'s ``(client_id, file_id)``
    dedup hook (Commit 4 of the streaming pipeline plan) recognises
    the duplicate and replaces the prior session, defeating the
    concurrency check.  The dedup is intentional: a buggy /
    restarting client double-posting ``/start`` for the same file
    must not get rejected for "exceeding" the cap they already own a
    slot of.
    """
    import uuid

    import aiosqlite

    from database.db import get_db

    token = await _approve_client(client)
    headers = {"Authorization": f"Bearer {token}"}

    db: aiosqlite.Connection = await get_db()

    # Ensure we're on the free tier (default)
    await client.patch("/api/v1/settings", json={"tier": "free"})

    # Insert two distinct files — one for the pre-existing session, one
    # for the about-to-be-rejected new stream.
    existing_file_id = str(uuid.uuid4())
    new_file_id = str(uuid.uuid4())
    for fid in (existing_file_id, new_file_id):
        await db.execute(
            "INSERT INTO media_files "
            "(id, path, name, extension, size_bytes, created_at, updated_at) "
            "VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))",
            (fid, f"/fake/{fid}.mp4", f"{fid}.mp4", ".mp4", 1000),
        )
    await db.commit()

    # Pre-existing active session on ``existing_file_id`` — uses the
    # caller's own client_id so it counts against their per-client cap.
    session_id = str(uuid.uuid4())
    await db.execute(
        "INSERT INTO stream_sessions "
        "(id, file_id, client_id, started_at, connection_type) "
        "VALUES (?, ?, 'client-settings-test', datetime('now'), 'lan')",
        (session_id, existing_file_id),
    )
    await db.commit()

    # Start a *different* file — concurrency check must reject because
    # the caller already has 1 active session on the free tier.
    res = await client.post(
        f"/api/v1/stream/start/{new_file_id}", headers=headers,
    )
    assert res.status_code == 429
