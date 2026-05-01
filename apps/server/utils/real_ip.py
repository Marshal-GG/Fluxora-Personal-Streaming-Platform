"""Cloudflare real-IP resolution.

When a request arrives via Cloudflare Tunnel, the immediate peer at FastAPI is
the cloudflared daemon (loopback). The actual client IP arrives in the
``CF-Connecting-IP`` header — but only Cloudflare-originated requests should be
trusted to set that header, otherwise any LAN client could spoof an IP for
rate-limiting purposes.

The middleware:

1. Reads ``CF-Connecting-IP`` only when the immediate peer is in Cloudflare's
   published IP range.
2. Sets ``request.state.real_ip`` to either the trusted CF header or the peer.
3. ``slowapi``'s rate-limiter ``key_func`` reads ``request.state.real_ip``.

Range list is fetched from Cloudflare at startup (see ``refresh_cf_ranges``)
with a hardcoded fallback so the server still boots if the CF endpoint is
unreachable. Refresh is opt-in via ``schedule_refresh`` from the lifespan.
"""

from __future__ import annotations

import logging
from ipaddress import ip_address, ip_network
from typing import TYPE_CHECKING

import httpx
from starlette.middleware.base import BaseHTTPMiddleware

from config import settings

if TYPE_CHECKING:
    from ipaddress import IPv4Network, IPv6Network

    from starlette.requests import Request
    from starlette.responses import Response
    from starlette.types import ASGIApp

logger = logging.getLogger(__name__)


# ── Hardcoded fallback (last refreshed 2026-05-01 against
# https://www.cloudflare.com/ips-v4 and ips-v6). Used if the live fetch fails.
_FALLBACK_CF_IPV4: tuple[str, ...] = (
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22",
)

_FALLBACK_CF_IPV6: tuple[str, ...] = (
    "2400:cb00::/32",
    "2606:4700::/32",
    "2803:f800::/32",
    "2405:b500::/32",
    "2405:8100::/32",
    "2a06:98c0::/29",
    "2c0f:f248::/32",
)

_CF_IPV4_URL = "https://www.cloudflare.com/ips-v4"
_CF_IPV6_URL = "https://www.cloudflare.com/ips-v6"
_FETCH_TIMEOUT_SEC = 10.0


# Cached parsed ranges. Initialised on first access via fallback; overwritten
# on successful refresh. Module-level state is intentional — middlewares share
# one cache.
_cached_ranges: list[IPv4Network | IPv6Network] = []


def _load_fallback() -> list[IPv4Network | IPv6Network]:
    return [ip_network(c) for c in _FALLBACK_CF_IPV4 + _FALLBACK_CF_IPV6]


async def refresh_cf_ranges(*, force_fallback: bool = False) -> None:
    """Fetch Cloudflare's current IP range list. Falls back on any error."""
    global _cached_ranges

    if force_fallback:
        _cached_ranges = _load_fallback()
        logger.info(
            "CF range list loaded from fallback (%d ranges)", len(_cached_ranges)
        )
        return

    try:
        async with httpx.AsyncClient(timeout=_FETCH_TIMEOUT_SEC) as client:
            v4 = (await client.get(_CF_IPV4_URL)).text
            v6 = (await client.get(_CF_IPV6_URL)).text
        ranges: list[IPv4Network | IPv6Network] = []
        for line in (v4 + "\n" + v6).splitlines():
            line = line.strip()
            if line:
                ranges.append(ip_network(line))
        if not ranges:
            raise ValueError("CF endpoints returned empty range list")
        _cached_ranges = ranges
        logger.info(
            "CF range list refreshed from cloudflare.com (%d ranges)", len(ranges)
        )
    except Exception as exc:  # pragma: no cover — network-dependent
        logger.warning(
            "Failed to refresh CF range list (%s); using bundled fallback", exc
        )
        _cached_ranges = _load_fallback()


def is_cloudflare_ip(ip_str: str) -> bool:
    """Return True if *ip_str* is in any known Cloudflare range."""
    if not _cached_ranges:
        # Lazy-init from fallback so callers don't have to await refresh first.
        _cached_ranges.extend(_load_fallback())
    try:
        ip = ip_address(ip_str)
    except ValueError:
        return False
    return any(ip in r for r in _cached_ranges)


def _peer_host(request: Request) -> str:
    return request.client.host if request.client else "127.0.0.1"


class RealIPMiddleware(BaseHTTPMiddleware):
    """Set ``request.state.real_ip`` from CF-Connecting-IP when trustworthy.

    "Trustworthy" means: ``FLUXORA_TRUST_CF_HEADERS`` is on AND the immediate
    peer is in Cloudflare's range. Otherwise the peer's IP is used directly.
    """

    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)

    async def dispatch(self, request: Request, call_next) -> Response:
        peer = _peer_host(request)
        cf_ip = request.headers.get("CF-Connecting-IP")
        if settings.fluxora_trust_cf_headers and cf_ip and is_cloudflare_ip(peer):
            request.state.real_ip = cf_ip
        else:
            request.state.real_ip = peer
        return await call_next(request)


def real_ip_key(request: Request) -> str:
    """slowapi key_func: prefer the middleware-set real IP, fall back to peer."""
    return getattr(request.state, "real_ip", _peer_host(request))


class HLSBlockOverTunnelMiddleware(BaseHTTPMiddleware):
    """403 ``/api/v1/hls/*`` requests that arrived via Cloudflare Tunnel.

    Enforces the architectural rule that the public tunnel never carries
    media bandwidth — clients must negotiate WebRTC for WAN streaming. The
    presence of ``CF-Connecting-IP`` is the tunnel signature.

    Toggleable via ``FLUXORA_BLOCK_HLS_OVER_TUNNEL`` (default: True).
    """

    _PROTECTED_PREFIX = "/api/v1/hls/"

    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)

    async def dispatch(self, request: Request, call_next) -> Response:
        if (
            settings.fluxora_block_hls_over_tunnel
            and request.url.path.startswith(self._PROTECTED_PREFIX)
            and request.headers.get("CF-Connecting-IP")
        ):
            from starlette.responses import JSONResponse

            return JSONResponse(
                status_code=403,
                content={
                    "detail": (
                        "HLS over public tunnel is disabled. "
                        "Use WebRTC for WAN streaming."
                    )
                },
            )
        return await call_next(request)
