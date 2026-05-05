"""Tests for TmdbService — all network calls are mocked with httpx.MockTransport."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from services.tmdb_service import TmdbService

# ── helpers ────────────────────────────────────────────────────────────────────

MOVIE_HIT = {
    "id": 123,
    "media_type": "movie",
    "title": "Inception",
    "overview": (
        "A thief who steals corporate secrets through the use of dream-sharing."
    ),
    "poster_path": "/inception.jpg",
}

TV_HIT = {
    "id": 456,
    "media_type": "tv",
    "name": "Breaking Bad",
    "overview": "A high school chemistry teacher turned methamphetamine producer.",
    "poster_path": "/bb.jpg",
}

PERSON_HIT = {
    "id": 789,
    "media_type": "person",
    "name": "Christopher Nolan",
}


def _mock_search(results: list[dict]):
    """Return a mock httpx response for /search/multi."""
    import httpx

    async def _handler(request):
        return httpx.Response(200, json={"results": results})

    return httpx.AsyncClient(transport=httpx.MockTransport(_handler))


# ── tests ──────────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_search_returns_movie_meta():
    svc = TmdbService(api_key="fake-key")

    import httpx

    async def _handler(request):
        return httpx.Response(200, json={"results": [MOVIE_HIT]})

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
                                "json": lambda self: {"results": [MOVIE_HIT]},
                            },
                        )()
                    )
                },
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        result = await svc.search("Inception")

    assert result is not None
    assert result.tmdb_id == 123
    assert result.title == "Inception"
    assert result.poster_url == "https://image.tmdb.org/t/p/w342/inception.jpg"


@pytest.mark.asyncio
async def test_search_returns_tv_meta():
    svc = TmdbService(api_key="fake-key")

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
                                "json": lambda self: {"results": [TV_HIT]},
                            },
                        )()
                    )
                },
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        result = await svc.search("Breaking Bad")

    assert result is not None
    assert result.tmdb_id == 456
    assert result.title == "Breaking Bad"
    assert result.poster_url == "https://image.tmdb.org/t/p/w342/bb.jpg"


@pytest.mark.asyncio
async def test_search_skips_person_results():
    """Person-only results return None."""
    svc = TmdbService(api_key="fake-key")

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
                                "json": lambda self: {"results": [PERSON_HIT]},
                            },
                        )()
                    )
                },
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        result = await svc.search("Christopher Nolan")

    assert result is None


@pytest.mark.asyncio
async def test_search_returns_none_on_network_error():
    """Any exception from httpx must be swallowed and None returned."""
    svc = TmdbService(api_key="fake-key")

    with patch("httpx.AsyncClient") as mock_cls:
        mock_cls.return_value.__aenter__ = AsyncMock(side_effect=Exception("timeout"))
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        result = await svc.search("anything")

    assert result is None


@pytest.mark.asyncio
async def test_search_handles_missing_poster():
    """A result with no poster_path should yield poster_url=None."""
    svc = TmdbService(api_key="fake-key")
    hit = {**MOVIE_HIT, "poster_path": None}

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
                                "json": lambda self: {"results": [hit]},
                            },
                        )()
                    )
                },
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        result = await svc.search("Inception no poster")

    assert result is not None
    assert result.poster_url is None


# ── ISP DNS-hijack workaround: retry-after-DoH-override behaviour ──────────────


@pytest.mark.asyncio
async def test_search_retries_with_doh_override_on_connect_timeout():
    """The motivating field case: ISP returns a sinkhole IP for
    api.themoviedb.org, the first connection times out; the service
    must register a DoH override and retry once, then succeed.  This
    verifies both the retry loop and the dns_override.register call."""
    import httpx

    from utils import dns_override

    # Start clean — previous tests may have left the override populated.
    dns_override.clear_override("api.themoviedb.org")

    call_count = {"value": 0}

    def _get_side_effect(*args, **kwargs):
        call_count["value"] += 1
        if call_count["value"] == 1:
            # First call simulates the sinkhole: TCP connect never
            # completes within timeout.
            raise httpx.ConnectTimeout("simulated sinkhole")
        # Second call (post-override) succeeds.
        return type(
            "R",
            (),
            {
                "raise_for_status": lambda self: None,
                "json": lambda self: {"results": [MOVIE_HIT]},
            },
        )()

    with patch("httpx.AsyncClient") as mock_cls, patch.object(
        dns_override,
        "register_doh_override",
        new=AsyncMock(return_value=True),
    ) as mock_register:
        mock_cls.return_value.__aenter__ = AsyncMock(
            return_value=type(
                "C",
                (),
                {"get": AsyncMock(side_effect=_get_side_effect)},
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        svc = TmdbService(api_key="fake-key")
        result = await svc.search("Inception")

    # Two GET attempts, one DoH override registration in between.
    assert call_count["value"] == 2
    mock_register.assert_awaited_once_with("api.themoviedb.org")
    assert result is not None
    assert result.tmdb_id == 123

    dns_override.clear_override("api.themoviedb.org")


@pytest.mark.asyncio
async def test_search_does_not_retry_when_override_already_registered():
    """When a DoH override is already in place, a fresh
    ConnectTimeout is treated as a real outage rather than a hijack —
    no retry, no further DoH lookup, just log and return None.  This
    keeps a hard outage from looping forever between failed attempts
    and pointless DoH refreshes."""
    import httpx

    from utils import dns_override

    # Pre-populate the override so the service sees "we already tried".
    dns_override._DNS_OVERRIDES["api.themoviedb.org"] = "203.0.113.1"

    call_count = {"value": 0}

    def _get_side_effect(*args, **kwargs):
        call_count["value"] += 1
        raise httpx.ConnectTimeout("still down")

    with patch("httpx.AsyncClient") as mock_cls, patch.object(
        dns_override,
        "register_doh_override",
        new=AsyncMock(return_value=True),
    ) as mock_register:
        mock_cls.return_value.__aenter__ = AsyncMock(
            return_value=type(
                "C",
                (),
                {"get": AsyncMock(side_effect=_get_side_effect)},
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        svc = TmdbService(api_key="fake-key")
        result = await svc.search("Inception")

    assert call_count["value"] == 1  # no retry
    mock_register.assert_not_awaited()
    assert result is None

    dns_override.clear_override("api.themoviedb.org")


# ── Proxy URL override (Cloudflare Worker reverse proxy) ──────────────────────


@pytest.mark.asyncio
async def test_search_uses_default_tmdb_url_when_no_override():
    """No override → canonical TMDB URL.  Pinned so a refactor that
    breaks the default fallback fails this test instead of silently
    sending requests to whatever empty-string-rstripped becomes."""
    svc = TmdbService(api_key="fake-key")
    captured = {}

    def _capture_url(url, params=None, **kwargs):
        captured["url"] = url
        return type(
            "R",
            (),
            {
                "raise_for_status": lambda self: None,
                "json": lambda self: {"results": [MOVIE_HIT]},
            },
        )()

    with patch("httpx.AsyncClient") as mock_cls:
        mock_cls.return_value.__aenter__ = AsyncMock(
            return_value=type(
                "C", (), {"get": AsyncMock(side_effect=_capture_url)},
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        await svc.search("Inception")

    assert captured["url"] == "https://api.themoviedb.org/3/search/multi"


@pytest.mark.asyncio
async def test_search_uses_custom_base_url_when_provided():
    """When the operator routes through their own Cloudflare Worker
    (the Reliance-Jio-DNS-block workaround), every TMDB request must
    target the proxy URL — not silently fall back to the canonical
    domain that's been blocked."""
    svc = TmdbService(
        api_key="fake-key",
        base_url="https://fluxora-api.marshalx.dev/tmdb/3",
    )
    captured = {}

    def _capture_url(url, params=None, **kwargs):
        captured["url"] = url
        return type(
            "R",
            (),
            {
                "raise_for_status": lambda self: None,
                "json": lambda self: {"results": [MOVIE_HIT]},
            },
        )()

    with patch("httpx.AsyncClient") as mock_cls:
        mock_cls.return_value.__aenter__ = AsyncMock(
            return_value=type(
                "C", (), {"get": AsyncMock(side_effect=_capture_url)},
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        await svc.search("Inception")

    assert (
        captured["url"]
        == "https://fluxora-api.marshalx.dev/tmdb/3/search/multi"
    )


@pytest.mark.asyncio
async def test_search_uses_custom_poster_base_for_returned_metadata():
    """Posters must also flow through the proxy — stored poster_url
    values are served to mobile/desktop clients which would otherwise
    hit image.tmdb.org directly and fail the same way."""
    svc = TmdbService(
        api_key="fake-key",
        poster_base_url="https://fluxora-api.marshalx.dev/tmdb-img/t/p/w342",
    )

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
                                "json": lambda self: {"results": [MOVIE_HIT]},
                            },
                        )()
                    )
                },
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        result = await svc.search("Inception")

    assert result is not None
    assert result.poster_url == (
        "https://fluxora-api.marshalx.dev/tmdb-img/t/p/w342/inception.jpg"
    )


def test_extract_host_from_proxy_url():
    """The DoH-retry hostname must follow the search URL host so the
    override targets the actual TCP destination, not the canonical
    api.themoviedb.org that the proxy hides."""
    svc = TmdbService(
        api_key="fake-key",
        base_url="https://fluxora-api.marshalx.dev/tmdb/3",
    )
    assert svc._tmdb_host == "fluxora-api.marshalx.dev"


def test_extract_host_strips_port():
    svc = TmdbService(
        api_key="fake-key",
        base_url="https://example.local:8443/tmdb/3",
    )
    assert svc._tmdb_host == "example.local"


def test_base_url_trailing_slash_is_normalised():
    """A common configuration error is leaving a trailing slash on
    the base URL.  The service must normalise it so requests don't
    hit `proxy.example.com//search/multi` (which Cloudflare's URL
    canonicalisation might reject)."""
    svc = TmdbService(
        api_key="fake-key",
        base_url="https://proxy.example.com/tmdb/3/",
    )
    assert svc._base_url == "https://proxy.example.com/tmdb/3"


@pytest.mark.asyncio
async def test_search_does_not_retry_on_non_connection_errors():
    """A 401 / 404 / JSON-decode error should NOT trigger the DoH
    override registration — that's only for TCP-level failures.  An
    HTTP status error indicates we successfully reached TMDB; the
    override would be a wrong fix that masks the real problem (bad
    API key, deprecated endpoint, etc)."""
    import httpx

    from utils import dns_override

    dns_override.clear_override("api.themoviedb.org")

    def _get_side_effect(*args, **kwargs):
        # raise_for_status would raise this on a 401 response.
        raise httpx.HTTPStatusError(
            "401 Unauthorized",
            request=httpx.Request("GET", "https://api.themoviedb.org/3/search/multi"),
            response=httpx.Response(401, json={"status_message": "Invalid API key"}),
        )

    with patch("httpx.AsyncClient") as mock_cls, patch.object(
        dns_override,
        "register_doh_override",
        new=AsyncMock(return_value=True),
    ) as mock_register:
        mock_cls.return_value.__aenter__ = AsyncMock(
            return_value=type(
                "C",
                (),
                {"get": AsyncMock(side_effect=_get_side_effect)},
            )()
        )
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        svc = TmdbService(api_key="bad-key")
        result = await svc.search("Inception")

    mock_register.assert_not_awaited()
    assert result is None
