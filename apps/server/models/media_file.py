from pydantic import BaseModel


class MediaFileResponse(BaseModel):
    id: str
    path: str
    name: str
    extension: str
    size_bytes: int
    duration_sec: float | None
    library_id: str | None
    tmdb_id: int | None
    created_at: str
    updated_at: str
