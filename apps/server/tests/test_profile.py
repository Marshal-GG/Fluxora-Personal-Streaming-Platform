"""Tests for /api/v1/profile."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from main import app


@pytest.mark.asyncio
async def test_get_profile_default_state(client: AsyncClient):
    """A fresh install has no display_name/email but profile_created_at is
    backfilled by migration 012, and avatar_letter falls back to 'F'."""
    resp = await client.get("/api/v1/profile")
    assert resp.status_code == 200
    body = resp.json()
    assert body["display_name"] is None
    assert body["email"] is None
    assert body["avatar_letter"] == "F"
    assert body["avatar_path"] is None
    assert body["created_at"] is not None  # backfilled
    assert body["last_login_at"] is None


@pytest.mark.asyncio
async def test_patch_profile_sets_fields(client: AsyncClient):
    resp = await client.patch(
        "/api/v1/profile",
        json={"display_name": "Marshal", "email": "marshal@example.org"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["display_name"] == "Marshal"
    assert body["email"] == "marshal@example.org"
    assert body["avatar_letter"] == "M"

    # GET reads back the same values
    again = await client.get("/api/v1/profile")
    assert again.json()["display_name"] == "Marshal"


@pytest.mark.asyncio
async def test_patch_profile_partial(client: AsyncClient):
    """Omitted fields stay untouched."""
    await client.patch(
        "/api/v1/profile",
        json={"display_name": "Alice", "email": "a@b.c"},
    )

    resp = await client.patch("/api/v1/profile", json={"email": "alice@new.example"})
    body = resp.json()
    assert body["display_name"] == "Alice"
    assert body["email"] == "alice@new.example"
    assert body["avatar_letter"] == "A"  # falls back to display_name


@pytest.mark.asyncio
async def test_patch_profile_clears_via_empty_string(client: AsyncClient):
    await client.patch(
        "/api/v1/profile",
        json={"display_name": "Bob", "email": "b@c.d"},
    )
    resp = await client.patch("/api/v1/profile", json={"email": ""})
    body = resp.json()
    assert body["display_name"] == "Bob"
    assert body["email"] is None  # cleared
    # avatar_letter still falls back to display_name
    assert body["avatar_letter"] == "B"


@pytest.mark.asyncio
async def test_avatar_letter_from_email_when_no_name(client: AsyncClient):
    await client.patch("/api/v1/profile", json={"email": "zoe@example.com"})
    resp = await client.get("/api/v1/profile")
    assert resp.json()["avatar_letter"] == "Z"


@pytest.mark.asyncio
async def test_avatar_letter_skips_whitespace(client: AsyncClient):
    """Leading whitespace in display_name doesn't bleed into avatar_letter."""
    await client.patch("/api/v1/profile", json={"display_name": "   nina"})
    resp = await client.get("/api/v1/profile")
    assert resp.json()["avatar_letter"] == "N"


@pytest.mark.asyncio
async def test_get_requires_localhost(test_db):
    """Tunneled requests must be rejected — admin endpoint."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("203.0.113.7", 50000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.get(
            "/api/v1/profile",
            headers={"CF-Connecting-IP": "203.0.113.7"},
        )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_patch_requires_localhost(test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("203.0.113.7", 50000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.patch(
            "/api/v1/profile",
            json={"display_name": "x"},
            headers={"CF-Connecting-IP": "203.0.113.7"},
        )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_max_length_enforced(client: AsyncClient):
    """Pydantic validation rejects absurdly long values."""
    resp = await client.patch("/api/v1/profile", json={"display_name": "x" * 200})
    assert resp.status_code == 422
