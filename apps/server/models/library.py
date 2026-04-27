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
