"""Lightweight TMDB metadata enrichment service.

Only called when the TMDB API key is configured in settings.
If the key is absent the service is effectively a no-op.

ISP DNS-hijack workaround
-------------------------
Some ISPs (Reliance Jio in India is a confirmed case as of 2026-05)
return a sinkhole IP for ``api.themoviedb.org`` instead of the real
Cloudfront address.  TCP connections to that sinkhole hang and
``httpx.ConnectTimeout`` is raised against every TMDB call.

We can't ask end users to switch their system DNS — that's not a
shipping requirement we can impose.  Instead, on the first
``ConnectError`` / ``ConnectTimeout`` the service registers a DoH
override (lookup via ``1.1.1.1``) for the hostname and retries once.
The override is a process-wide entry that monkey-patches
``socket.getaddrinfo`` so subsequent calls go to the real IP without
extra logic in the request path.  See ``utils/dns_override.py``.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import httpx

from utils import dns_override

logger = logging.getLogger(__name__)

_TMDB_DEFAULT_BASE = "https://api.themoviedb.org/3"
_POSTER_DEFAULT_BASE = "https://image.tmdb.org/t/p/w342"
_TMDB_DEFAULT_HOST = "api.themoviedb.org"


class TmdbService:
    """Fetch basic movie/show metadata from TMDB by title keyword.

    ``base_url`` and ``poster_base_url`` are optional overrides for the
    canonical TMDB URLs.  Used to route TMDB traffic through a
    user-controlled reverse proxy (e.g. a Cloudflare Worker on the
    operator's own domain) when the ISP blocks
    ``api.themoviedb.org`` / ``image.tmdb.org`` at the DNS or IP
    level.  The DoH retry below remains useful for users whose ISP
    only does DNS hijacking; the proxy URL is the right fix when the
    block extends to the IPs themselves.
    """

    def __init__(
        self,
        api_key: str,
        *,
        base_url: str | None = None,
        poster_base_url: str | None = None,
    ) -> None:
        self._key = api_key
        self._base_url = (base_url or _TMDB_DEFAULT_BASE).rstrip("/")
        self._poster_base_url = (
            poster_base_url or _POSTER_DEFAULT_BASE
        ).rstrip("/")
        # The DoH-retry hostname follows the search URL — when an
        # operator routes through their own proxy, attempts that hit
        # the proxy hostname may still be DNS-hijacked at the user's
        # network (rare; their own domain is on Cloudflare anycast),
        # but the override targets the same hostname the failed
        # connection used.
        self._tmdb_host = self._extract_host(self._base_url)

    @staticmethod
    def _extract_host(url: str) -> str:
        # Tiny manual parse to avoid importing urllib for one call.
        # ``url`` is always a fully-qualified ``https://host[:port]/path``
        # so a left-strip + slice is sufficient.
        without_scheme = url.split("//", 1)[-1]
        return without_scheme.split("/", 1)[0].split(":", 1)[0]

    async def search(self, query: str) -> TmdbMeta | None:
        """Return the best-matching TMDB result for *query*, or None on failure.

        On a ``ConnectError`` / ``ConnectTimeout`` the call is retried
        once after registering a DNS-over-HTTPS override for
        ``api.themoviedb.org`` (see module docstring).  The retry is
        also wrapped in the same exception handler so a hard outage
        falls through to the warning log instead of looping.
        """
        for attempt in range(2):
            try:
                async with httpx.AsyncClient(timeout=10) as client:
                    resp = await client.get(
                        f"{self._base_url}/search/multi",
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
                    poster_url = (
                        f"{self._poster_base_url}{poster_path}"
                        if poster_path
                        else None
                    )

                    return TmdbMeta(
                        tmdb_id=tmdb_id,
                        title=title,
                        overview=overview,
                        poster_url=poster_url,
                    )
                # No movie/tv hit — return None without retrying.
                return None

            except (httpx.ConnectError, httpx.ConnectTimeout) as exc:
                # First attempt: install a DoH override and retry.
                # Most likely cause: ISP-level DNS hijack returning a
                # sinkhole IP for the TMDB host.  Cached overrides
                # short-circuit the lookup on the next attempt so the
                # cost is paid exactly once per process.  When the
                # operator has set a proxy base URL the override
                # targets the proxy host, not api.themoviedb.org.
                if attempt == 0 and not dns_override.has_override(self._tmdb_host):
                    logger.info(
                        "TMDB %s on first attempt — registering DoH override for %s",
                        exc.__class__.__name__,
                        self._tmdb_host,
                    )
                    if await dns_override.register_doh_override(self._tmdb_host):
                        continue
                logger.warning(
                    "TMDB search failed for %r: %s: %r",
                    query,
                    exc.__class__.__name__,
                    exc,
                )
                return None

            except Exception as exc:
                # Any other exception (parse, JSON, HTTP 4xx/5xx via
                # raise_for_status, etc.) — surface with the class
                # name so the operator can distinguish a 401 (bad API
                # key) from a 503 (TMDB outage) from a JSON decode
                # failure.  ``repr()`` always carries the class + args
                # so the log line is never an empty trailing colon.
                logger.warning(
                    "TMDB search failed for %r: %s: %r",
                    query,
                    exc.__class__.__name__,
                    exc,
                )
                return None

        return None


@dataclass
class TmdbMeta:
    tmdb_id: int
    title: str
    overview: str
    poster_url: str | None
