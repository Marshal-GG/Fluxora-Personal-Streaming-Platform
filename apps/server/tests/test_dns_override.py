"""Tests for utils.dns_override.

The module monkey-patches ``socket.getaddrinfo`` at import time so any
hostname registered in the override map is resolved against a hard-
coded IP instead of the system resolver.  This is the workaround for
end-user ISPs (e.g. Reliance Jio) that DNS-hijack ``api.themoviedb.org``.
"""

from __future__ import annotations

import socket
from unittest.mock import AsyncMock, patch

import httpx
import pytest

from utils import dns_override


# ── Patched socket.getaddrinfo behaviour ─────────────────────────────────────


def test_patched_getaddrinfo_returns_override_for_registered_host():
    """When a hostname is in the override map, getaddrinfo synthesises
    an IPv4 A record pointing at the override IP — the system resolver
    is bypassed entirely so an ISP DNS hijack can't redirect us back."""
    dns_override._DNS_OVERRIDES["test.example.com"] = "203.0.113.42"
    try:
        results = socket.getaddrinfo("test.example.com", 443)
        assert len(results) == 1
        family, socktype, proto, canonname, addr = results[0]
        assert family == socket.AF_INET
        assert socktype == socket.SOCK_STREAM
        assert proto == socket.IPPROTO_TCP
        assert addr == ("203.0.113.42", 443)
    finally:
        dns_override._DNS_OVERRIDES.pop("test.example.com", None)


def test_patched_getaddrinfo_passes_through_unknown_hosts():
    """Hostnames NOT in the override map fall through to the original
    resolver — overrides must be opt-in per host so we don't break
    every other outbound HTTPS call in the server."""
    # Use a hostname that's basically guaranteed to resolve from any
    # network with internet access.  If the test env has no network,
    # the original resolver will raise gaierror — that's still proof
    # we delegated to it (the patched path would have synthesised a
    # successful response).
    try:
        results = socket.getaddrinfo("localhost", 80)
        # localhost resolves to 127.0.0.1 (IPv4) or ::1 (IPv6); we only
        # care that the response shape matches the *original* resolver
        # rather than the synthetic single-tuple shape.  In practice
        # localhost returns multiple entries, which our patched fast
        # path never produces.
        assert len(results) >= 1
        assert all(len(t) == 5 for t in results)
    except socket.gaierror:
        # No DNS at all in the test env — still acceptable evidence
        # that we passed through (the override path can't raise this).
        pass


def test_patched_getaddrinfo_handles_non_numeric_port():
    """Service names like 'https' must fall through to the original
    resolver instead of crashing with int() ValueError — we only
    short-circuit when the port is numeric or None."""
    dns_override._DNS_OVERRIDES["test.example.com"] = "203.0.113.42"
    try:
        # Call directly with a service name; should delegate.  We don't
        # assert on the return value (the original resolver may raise
        # depending on /etc/services); the important thing is that the
        # patched function doesn't itself raise ValueError on int().
        try:
            socket.getaddrinfo("test.example.com", "https")
        except (socket.gaierror, OSError):
            # Original resolver may or may not know "https"; we only
            # care the patched layer handed off cleanly.
            pass
    finally:
        dns_override._DNS_OVERRIDES.pop("test.example.com", None)


def test_patched_getaddrinfo_handles_none_port():
    dns_override._DNS_OVERRIDES["test.example.com"] = "203.0.113.42"
    try:
        results = socket.getaddrinfo("test.example.com", None)
        assert results[0][4] == ("203.0.113.42", 0)
    finally:
        dns_override._DNS_OVERRIDES.pop("test.example.com", None)


# ── DoH resolution against 1.1.1.1 ─────────────────────────────────────────


@pytest.mark.asyncio
async def test_resolve_via_doh_returns_first_a_record():
    """The DoH JSON response shape is ``{"Answer": [{"type": 1, "data":
    "ip"}, ...]}``; resolve_via_doh must return the first A-record
    (type=1) ignoring AAAA (type=28) and any other record types."""
    fake_response = {
        "Answer": [
            {"name": "api.themoviedb.org", "type": 28, "data": "::1"},  # AAAA
            {"name": "api.themoviedb.org", "type": 1, "data": "3.165.239.87"},
            {"name": "api.themoviedb.org", "type": 1, "data": "3.165.239.88"},
        ]
    }

    with patch("httpx.AsyncClient") as mock_cls:
        mock_cls.return_value.__aenter__ = AsyncMock(
            return_value=type(
                "C",
                (),
                {
                    "get": AsyncMock(
                        return_value=type(
                            "R",
                            (),
                            {
                                "raise_for_status": lambda self: None,
                                "json": lambda self: fake_response,
                            },
                        )()
                    )
                },
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        ip = await dns_override.resolve_via_doh("api.themoviedb.org")

    assert ip == "3.165.239.87"


@pytest.mark.asyncio
async def test_resolve_via_doh_returns_none_when_no_a_records():
    """If only AAAA records come back, resolve_via_doh returns None
    rather than synthesising an unsupported override (the patched
    socket layer only emits AF_INET tuples)."""
    fake_response = {
        "Answer": [
            {"name": "ipv6-only.example.com", "type": 28, "data": "::1"},
        ]
    }

    with patch("httpx.AsyncClient") as mock_cls:
        mock_cls.return_value.__aenter__ = AsyncMock(
            return_value=type(
                "C",
                (),
                {
                    "get": AsyncMock(
                        return_value=type(
                            "R",
                            (),
                            {
                                "raise_for_status": lambda self: None,
                                "json": lambda self: fake_response,
                            },
                        )()
                    )
                },
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        ip = await dns_override.resolve_via_doh("ipv6-only.example.com")

    assert ip is None


@pytest.mark.asyncio
async def test_resolve_via_doh_returns_none_on_network_error():
    """A network failure to 1.1.1.1 itself (rare; user behind a heavy
    firewall) must not crash — resolver returns None and the caller
    falls back to system DNS."""
    with patch("httpx.AsyncClient") as mock_cls:
        mock_cls.return_value.__aenter__ = AsyncMock(
            side_effect=httpx.ConnectTimeout("DoH endpoint unreachable")
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        ip = await dns_override.resolve_via_doh("api.themoviedb.org")

    assert ip is None


@pytest.mark.asyncio
async def test_register_doh_override_populates_map_on_success():
    with patch.object(
        dns_override,
        "resolve_via_doh",
        new=AsyncMock(return_value="3.165.239.87"),
    ):
        ok = await dns_override.register_doh_override("api.themoviedb.org")

    assert ok is True
    assert dns_override.get_override("api.themoviedb.org") == "3.165.239.87"
    dns_override.clear_override("api.themoviedb.org")


@pytest.mark.asyncio
async def test_register_doh_override_returns_false_on_failure():
    with patch.object(
        dns_override,
        "resolve_via_doh",
        new=AsyncMock(return_value=None),
    ):
        ok = await dns_override.register_doh_override("dead.example.com")

    assert ok is False
    assert dns_override.get_override("dead.example.com") is None


def test_clear_override_removes_entry():
    dns_override._DNS_OVERRIDES["x.example.com"] = "1.2.3.4"
    assert dns_override.has_override("x.example.com")
    dns_override.clear_override("x.example.com")
    assert not dns_override.has_override("x.example.com")


def test_clear_override_no_op_for_missing_entry():
    """Clearing a hostname that was never registered must not raise —
    callers don't always know the prior state and we want them to be
    able to call clear_override defensively."""
    dns_override.clear_override("never-registered.example.com")  # no raise
