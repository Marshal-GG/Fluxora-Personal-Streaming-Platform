"""DNS override for hostnames the user's ISP hijacks at the resolver
level (e.g. some Indian ISPs return a sinkhole IP for
``api.themoviedb.org`` to enforce a regional block).

The fix has to live server-side because telling end users to switch
their system DNS isn't a reasonable shipping requirement.  We use
Cloudflare's anycast IP ``1.1.1.1`` to perform a DNS-over-HTTPS lookup
(no DNS round-trip needed since 1.1.1.1 is reached by IP), cache the
real address, then monkey-patch ``socket.getaddrinfo`` to consult the
cache before falling through to the system resolver.

Why monkey-patch instead of a custom httpx transport?  asyncio's
default resolver runs ``socket.getaddrinfo`` in a thread pool, and
httpx ultimately calls into that resolver — patching ``socket``
catches every code path with a single change instead of forcing each
service to use a custom client.  The patch consults
``_DNS_OVERRIDES`` first; non-overridden hostnames pass through to
the original resolver unchanged, so the patch is a no-op in the
absence of registered overrides.

Usage:

    from utils import dns_override

    # On startup or first failure, register an override:
    await dns_override.register_doh_override("api.themoviedb.org")

    # Subsequent httpx / requests / urllib calls that resolve that
    # hostname will pick up the override automatically.

The override stays installed for the process lifetime; call
``clear_override(host)`` to drop it (e.g. when the cached IP appears
to have gone stale and we want to fall back to system DNS for the
next attempt).
"""

from __future__ import annotations

import logging
import socket
from typing import Any

import httpx

logger = logging.getLogger(__name__)


# Hostname → IPv4 string.  Populated by `register_doh_override`.
_DNS_OVERRIDES: dict[str, str] = {}

# Capture the original resolver before we replace it.  The patched
# version delegates here for any hostname not in the override map.
_original_getaddrinfo = socket.getaddrinfo


def _patched_getaddrinfo(
    host: str | bytes | None,
    port: int | str | None,
    *args: Any,
    **kwargs: Any,
) -> list[tuple[Any, ...]]:
    """Drop-in replacement for ``socket.getaddrinfo``.

    When ``host`` is in ``_DNS_OVERRIDES`` we synthesise a single A-record
    response pointing at the override IP.  TLS clients then connect to
    that IP but continue to send the original hostname for SNI + the
    HTTP Host header (because we never touch those — only the DNS
    resolution step), so Cloudfront serves the correct certificate and
    cert validation succeeds.
    """
    if isinstance(host, str) and host in _DNS_OVERRIDES:
        ip = _DNS_OVERRIDES[host]
        # Normalise the port the way getaddrinfo would — it accepts
        # ``None``, ``int``, or a service-name ``str``.  Service-name
        # resolution is handled by passing through to the original for
        # the port argument when it isn't already a number.
        try:
            port_num = int(port) if port is not None else 0
        except (TypeError, ValueError):
            # Fall through to the original resolver if the port isn't
            # numeric — we don't want to second-guess service-name
            # mapping for non-overridden cases.
            return _original_getaddrinfo(host, port, *args, **kwargs)
        return [
            (
                socket.AF_INET,
                socket.SOCK_STREAM,
                socket.IPPROTO_TCP,
                "",
                (ip, port_num),
            )
        ]
    return _original_getaddrinfo(host, port, *args, **kwargs)


# Install the patch exactly once, on first import.  Idempotent so
# re-importing the module (e.g. under test reload) doesn't stack
# multiple wrappers.
if socket.getaddrinfo is not _patched_getaddrinfo:
    socket.getaddrinfo = _patched_getaddrinfo  # type: ignore[assignment]


# Cloudflare DoH endpoint.  We connect by IP (1.1.1.1) so the lookup
# itself doesn't depend on system DNS — that's the whole point.  TLS
# SNI is set explicitly to ``cloudflare-dns.com`` because that's what
# the cert at this IP is issued for.  httpx handles SNI from the URL
# host by default; using the IP in the URL would break SNI, so we use
# the canonical hostname and rely on the fact that 1.1.1.1's
# resolution by the system always returns 1.1.1.1 (it's anycast and
# the canonical hosts file maps it).
_DOH_URL = "https://1.1.1.1/dns-query"


async def resolve_via_doh(
    hostname: str, *, timeout: float = 5.0,
) -> str | None:
    """Resolve ``hostname`` via Cloudflare DoH.  Bypasses the system
    resolver entirely so ISP-level DNS hijacking can't affect the
    result.  Returns the first A-record IP, or None on failure.

    The DoH JSON API accepts ``Accept: application/dns-json`` and
    returns ``{"Answer": [{"name": "...", "type": 1, "data": "ip"}]}``
    where ``type=1`` is an A record (IPv4).  We pick the first match —
    Cloudfront / Cloudflare load balancing picks a different IP per
    response anyway, so any one of them is fine.
    """
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.get(
                _DOH_URL,
                params={"name": hostname, "type": "A"},
                headers={"Accept": "application/dns-json"},
            )
            resp.raise_for_status()
            data = resp.json()
            for ans in data.get("Answer", []):
                if ans.get("type") == 1:  # A record
                    ip = ans.get("data")
                    if isinstance(ip, str) and ip:
                        return ip
    except Exception as exc:
        logger.warning(
            "DoH resolution failed for %s: %s: %r",
            hostname,
            exc.__class__.__name__,
            exc,
        )
    return None


async def register_doh_override(hostname: str) -> bool:
    """Resolve ``hostname`` via DoH and add it to the override map.

    Returns True if an override was registered (or refreshed to the
    same IP), False on resolution failure.  Idempotent — re-running
    is cheap and keeps the cached IP fresh against Cloudfront's
    rotation.
    """
    ip = await resolve_via_doh(hostname)
    if ip is None:
        return False
    prior = _DNS_OVERRIDES.get(hostname)
    if prior != ip:
        logger.info("DNS override registered: %s → %s", hostname, ip)
    _DNS_OVERRIDES[hostname] = ip
    return True


def get_override(hostname: str) -> str | None:
    """Return the currently-registered override IP for ``hostname``,
    or None if none is set."""
    return _DNS_OVERRIDES.get(hostname)


def clear_override(hostname: str) -> None:
    """Remove a hostname from the override map.  The next resolution
    attempt falls back to system DNS — useful when the cached IP has
    gone stale and we want to give the system resolver another
    chance (e.g. the user's network situation has changed)."""
    _DNS_OVERRIDES.pop(hostname, None)


def has_override(hostname: str) -> bool:
    return hostname in _DNS_OVERRIDES
