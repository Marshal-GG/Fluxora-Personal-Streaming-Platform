"""Tests for the real-IP middleware, HLS-block-on-tunnel middleware, and
the localhost-only hardening that rejects tunneled requests.
"""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from utils import real_ip

# ── is_cloudflare_ip ─────────────────────────────────────────────────────────


def test_is_cloudflare_ip_recognises_cf_v4():
    # Pick an IP from a known CF range (104.16.0.0/13 covers a huge slice)
    assert real_ip.is_cloudflare_ip("104.16.0.1")


def test_is_cloudflare_ip_recognises_cf_v6():
    assert real_ip.is_cloudflare_ip("2606:4700::1")


def test_is_cloudflare_ip_rejects_non_cf():
    assert not real_ip.is_cloudflare_ip("8.8.8.8")
    assert not real_ip.is_cloudflare_ip("127.0.0.1")
    assert not real_ip.is_cloudflare_ip("192.168.1.1")


def test_is_cloudflare_ip_handles_garbage():
    assert not real_ip.is_cloudflare_ip("not-an-ip")
    assert not real_ip.is_cloudflare_ip("")


# ── HLS-block-on-tunnel middleware ───────────────────────────────────────────


@pytest.mark.asyncio
async def test_hls_route_blocked_when_cf_header_present(client: AsyncClient):
    """A request to /api/v1/hls/* with CF-Connecting-IP must be 403'd."""
    response = await client.get(
        "/api/v1/hls/some-session/playlist.m3u8",
        headers={"CF-Connecting-IP": "203.0.113.5"},
    )
    assert response.status_code == 403
    assert "tunnel" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_hls_route_passes_when_no_cf_header(client: AsyncClient):
    """Without the tunnel header, /hls/* falls through to the actual route
    (which then 401s because we have no auth — but importantly NOT 403)."""
    response = await client.get("/api/v1/hls/some-session/playlist.m3u8")
    # Expect 401 (no token) or 404 (no such session) — anything except the 403
    # the middleware would have returned. The point is we got past the block.
    assert response.status_code != 403


@pytest.mark.asyncio
async def test_hls_block_disabled_via_setting(client: AsyncClient, monkeypatch):
    """Setting FLUXORA_BLOCK_HLS_OVER_TUNNEL=False bypasses the middleware."""
    import config

    monkeypatch.setattr(config.settings, "fluxora_block_hls_over_tunnel", False)
    response = await client.get(
        "/api/v1/hls/some-session/playlist.m3u8",
        headers={"CF-Connecting-IP": "203.0.113.5"},
    )
    # Should fall through to the route now (any non-403 response is fine)
    assert response.status_code != 403


@pytest.mark.asyncio
async def test_non_hls_route_unaffected_by_cf_header(client: AsyncClient):
    """The block applies ONLY to /hls/* paths. Other routes work fine."""
    response = await client.get(
        "/api/v1/info", headers={"CF-Connecting-IP": "203.0.113.5"}
    )
    assert response.status_code == 200


# ── require_local_caller hardening ───────────────────────────────────────────


@pytest.mark.asyncio
async def test_settings_endpoint_blocks_tunneled_request(client: AsyncClient):
    """GET /api/v1/settings is localhost-only; CF-Connecting-IP must be 403'd
    even though cloudflared forwards via 127.0.0.1."""
    response = await client.get(
        "/api/v1/settings", headers={"CF-Connecting-IP": "203.0.113.5"}
    )
    assert response.status_code == 403
    assert "tunnel" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_orders_endpoint_blocks_tunneled_request(client: AsyncClient):
    response = await client.get(
        "/api/v1/orders", headers={"CF-Connecting-IP": "203.0.113.5"}
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_settings_endpoint_works_without_cf_header(client: AsyncClient):
    """Verify the legitimate localhost path still works after the hardening."""
    response = await client.get("/api/v1/settings")
    assert response.status_code == 200


# ── validate_token_or_local hardening ────────────────────────────────────────


@pytest.mark.asyncio
async def test_files_endpoint_requires_token_when_tunneled(client: AsyncClient):
    """/api/v1/files is normally accessible from localhost without auth, but
    a tunneled request must produce 401 (token required) — NOT pass through."""
    response = await client.get(
        "/api/v1/files", headers={"CF-Connecting-IP": "203.0.113.5"}
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_library_endpoint_requires_token_when_tunneled(client: AsyncClient):
    response = await client.get(
        "/api/v1/library", headers={"CF-Connecting-IP": "203.0.113.5"}
    )
    assert response.status_code == 401


# ── CORS allow-list ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_cors_preflight_allowed_origin(client: AsyncClient):
    response = await client.options(
        "/api/v1/info",
        headers={
            "Origin": "https://fluxora-api.marshalx.dev",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert response.status_code in (200, 204)
    assert (
        response.headers.get("access-control-allow-origin")
        == "https://fluxora-api.marshalx.dev"
    )


@pytest.mark.asyncio
async def test_cors_preflight_disallowed_origin(client: AsyncClient):
    response = await client.options(
        "/api/v1/info",
        headers={
            "Origin": "https://attacker.example.com",
            "Access-Control-Request-Method": "GET",
        },
    )
    # Disallowed origin: middleware doesn't add the allow-origin header.
    assert "access-control-allow-origin" not in {
        k.lower() for k in response.headers.keys()
    }
