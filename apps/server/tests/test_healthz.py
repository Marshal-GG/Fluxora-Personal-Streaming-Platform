"""Tests for the /api/v1/healthz endpoint and the remote_url field on /info."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

# ── /api/v1/healthz ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_healthz_returns_ok(client: AsyncClient) -> None:
    response = await client.get("/api/v1/healthz")
    assert response.status_code == 200
    assert response.json() == {"ok": True}


@pytest.mark.asyncio
async def test_healthz_no_auth_required(client: AsyncClient) -> None:
    """Healthz must work for unauthenticated callers (CF tunnel uses it)."""
    response = await client.get("/api/v1/healthz")
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_healthz_constant_body(client: AsyncClient) -> None:
    """Body should be identical across calls — no DB hit, no clock drift."""
    a = await client.get("/api/v1/healthz")
    b = await client.get("/api/v1/healthz")
    assert a.json() == b.json() == {"ok": True}


# ── /api/v1/info → remote_url field ──────────────────────────────────────────


@pytest.mark.asyncio
async def test_info_remote_url_null_when_unconfigured(client: AsyncClient) -> None:
    """Default state: no public URL configured → field is null."""
    import config

    # Conftest defaults FLUXORA_PUBLIC_URL to "" so we just verify the API surface.
    response = await client.get("/api/v1/info")
    assert response.status_code == 200
    body = response.json()
    assert "remote_url" in body
    assert body["remote_url"] is None
    # Settings sanity check
    assert config.settings.fluxora_public_url == ""


@pytest.mark.asyncio
async def test_info_remote_url_populated_when_configured(
    client: AsyncClient, monkeypatch
) -> None:
    """When FLUXORA_PUBLIC_URL is set, /info should expose it."""
    import config

    monkeypatch.setattr(
        config.settings, "fluxora_public_url", "https://fluxora-api.marshalx.dev"
    )
    response = await client.get("/api/v1/info")
    assert response.status_code == 200
    assert response.json()["remote_url"] == "https://fluxora-api.marshalx.dev"


@pytest.mark.asyncio
async def test_info_response_contract(client: AsyncClient) -> None:
    """The full server-info response shape we promise to clients."""
    response = await client.get("/api/v1/info")
    body = response.json()
    assert set(body.keys()) == {"server_name", "version", "tier", "remote_url"}
    assert isinstance(body["server_name"], str)
    assert isinstance(body["version"], str)
    assert isinstance(body["tier"], str)
    assert body["remote_url"] is None or isinstance(body["remote_url"], str)
