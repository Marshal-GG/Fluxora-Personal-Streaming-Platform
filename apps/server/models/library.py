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


class CreateLibraryBody(BaseModel):
    name: str
    type: Literal["movies", "tv", "music", "files"]
    root_paths: list[str]


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
