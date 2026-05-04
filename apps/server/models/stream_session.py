from pydantic import BaseModel


class StreamStartResponse(BaseModel):
    session_id: str
    file_id: str
    playlist_url: str
    resume_sec: float = 0.0  # seconds to seek to on open (resume playback)
    # Source HDR format if any: "HDR10" | "HLG" | "DolbyVision" | None.
    # Drives the player's HDR badge + the "tonemap to SDR" toggle visibility.
    hdr_format: str | None = None
    # True when the server is currently tonemapping HDR to SDR for this
    # session.  Echoes the request's `tonemap` query param so the client
    # knows whether the toggle is currently on.
    tonemapped: bool = False


class StreamSessionResponse(BaseModel):
    id: str
    file_id: str
    client_id: str
    started_at: str
    ended_at: str | None
    connection_type: str
    bytes_transferred: int
    progress_sec: float
