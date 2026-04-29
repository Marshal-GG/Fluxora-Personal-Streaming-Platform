"""Lightweight TMDB metadata enrichment service.

Only called when the TMDB API key is configured in settings.
If the key is absent the service is effectively a no-op.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import httpx

logger = logging.getLogger(__name__)

_TMDB_BASE = "https://api.themoviedb.org/3"
_POSTER_BASE = "https://image.tmdb.org/t/p/w342"


@dataclass
class TmdbMeta:
    tmdb_id: int
    title: str
    overview: str
    poster_url: str | None


class TmdbService:
    """Fetch basic movie/show metadata from TMDB by title keyword."""

    def __init__(self, api_key: str) -> None:
        self._key = api_key

    async def search(self, query: str) -> TmdbMeta | None:
        """Return the best-matching TMDB result for *query*, or None on failure."""
        try:
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.get(
                    f"{_TMDB_BASE}/search/multi",
                    params={"api_key": self._key, "query": query, "page": 1},
                )
                resp.raise_for_status()
                results = resp.json().get("results", [])

            # Accept movies and TV shows; prefer whichever ranks first
            for item in results:
                media_type = item.get("media_type")
                if media_type not in ("movie", "tv"):
                    continue

                tmdb_id: int = item["id"]
                title: str = item.get("title") or item.get("name") or query
                overview: str = item.get("overview") or ""
                poster_path: str | None = item.get("poster_path")
                poster_url = f"{_POSTER_BASE}{poster_path}" if poster_path else None

                return TmdbMeta(
                    tmdb_id=tmdb_id,
                    title=title,
                    overview=overview,
                    poster_url=poster_url,
                )

        except Exception as exc:  # network, parse, etc.
            logger.warning("TMDB search failed for %r: %s", query, exc)

        return None
