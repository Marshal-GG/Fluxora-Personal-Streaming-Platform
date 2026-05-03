from pydantic import BaseModel, ConfigDict, Field


class MediaFileResponse(BaseModel):
    # `extra='ignore'` lets us hand the model a full `media_files` row dict
    # from `library_service.list_files()` without having to filter columns
    # the API surface does not expose (e.g. internal-only future additions).
    model_config = ConfigDict(populate_by_name=True, extra="ignore")

    id: str
    path: str
    name: str
    extension: str
    size_bytes: int
    duration_sec: float | None
    library_id: str | None
    tmdb_id: int | None
    # TMDB-enriched metadata (nullable until a scan with a valid API key is run)
    title: str | None = None
    overview: str | None = None
    poster_url: str | None = None
    # Resume position — stored as last_progress_sec in the DB; exposed as
    # resume_sec so the Dart client's generated fromJson reads it directly.
    resume_sec: float = Field(default=0.0, alias="last_progress_sec")
    # FFprobe-derived video metadata (migration 016). Null on rows that
    # pre-date the migration until the next scan touches them, and on
    # non-video extensions where probing is skipped.
    width: int | None = None
    height: int | None = None
    codec_name: str | None = None
    hdr_format: str | None = None
    # TV episode aggregation (migration 016). Populated by Phase D's TMDB
    # back-fill; null on movies and on TV files scanned before the back-fill.
    tmdb_show_id: int | None = None
    season_number: int | None = None
    episode_number: int | None = None
    created_at: str
    updated_at: str
