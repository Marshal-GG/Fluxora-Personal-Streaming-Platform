from pydantic import BaseModel, Field


class MediaFileResponse(BaseModel):
    model_config = {"populate_by_name": True}

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
    created_at: str
    updated_at: str
