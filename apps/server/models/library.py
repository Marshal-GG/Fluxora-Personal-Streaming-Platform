from typing import Literal

from pydantic import BaseModel


class LibraryResponse(BaseModel):
    id: str
    name: str
    type: Literal["movies", "tv", "music", "files"]
    root_paths: list[str]
    last_scanned: str | None
    created_at: str
    file_count: int = 0
    total_size_bytes: int = 0
    cover_urls: list[str] = []
    # Plan 19 §M8 — per-library AV1 / VP9 codec passthrough overrides.
    # Tri-state: None inherits the global `streaming_mode` setting,
    # True forces stream-copy for sources of that codec in this
    # library, False forces transcoding.  Honoured by
    # `ffmpeg_service.start_stream` via `_resolve_codec_passthrough`.
    av1_stream_copy_override: bool | None = None
    vp9_stream_copy_override: bool | None = None
    # Per-library TMDB-enrichment toggle (migration 040).  Default
    # True so existing libraries continue to enrich; flipping to
    # False both stops future enrichment passes AND masks already-
    # persisted TMDB columns (poster_url / title / overview /
    # tmdb_id) from API responses without dropping the rows from
    # disk — re-enabling brings everything back.
    tmdb_enabled: bool = True


class CreateLibraryBody(BaseModel):
    name: str
    type: Literal["movies", "tv", "music", "files"]
    root_paths: list[str]
    # Operator can opt the library out of TMDB at creation time —
    # useful for non-media libraries (screenshots, captures, document
    # archives) where TMDB matching would just produce noise.
    tmdb_enabled: bool = True


class UpdateLibraryBody(BaseModel):
    """Partial update — every field is optional. At least one must be set."""

    name: str | None = None
    root_paths: list[str] | None = None
    # Plan 19 §M8 — tri-state per-codec override.  Setting NULL
    # explicitly clears the override (inherit global setting); True /
    # False pin the behaviour for this library regardless of the
    # global toggle.
    av1_stream_copy_override: bool | None = None
    vp9_stream_copy_override: bool | None = None
    # Per-library TMDB toggle (migration 040) — see LibraryResponse
    # field comment for hide-but-keep semantics.
    tmdb_enabled: bool | None = None


class StorageByType(BaseModel):
    movies: int = 0
    tv: int = 0
    music: int = 0
    files: int = 0


class StorageBreakdownResponse(BaseModel):
    """Aggregated storage usage backing the redesigned Dashboard donut.

    `total_bytes` is the sum of `media_files.size_bytes` across all libraries.
    `capacity_bytes` is the combined disk capacity of every unique mount that
    backs at least one library root. Returns `0` if no libraries exist or
    none have an accessible root path.
    """

    total_bytes: int
    capacity_bytes: int
    by_type: StorageByType
