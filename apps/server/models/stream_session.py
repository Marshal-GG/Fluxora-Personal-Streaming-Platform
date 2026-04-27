from pydantic import BaseModel


class StreamStartResponse(BaseModel):
    session_id: str
    file_id: str
    playlist_url: str


class StreamSessionResponse(BaseModel):
    id: str
    file_id: str
    client_id: str
    started_at: str
    ended_at: str | None
    connection_type: str
    bytes_transferred: int
    progress_sec: float
