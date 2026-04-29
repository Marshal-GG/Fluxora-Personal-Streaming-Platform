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
