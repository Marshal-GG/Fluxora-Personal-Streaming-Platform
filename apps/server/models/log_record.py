from typing import Literal

from pydantic import BaseModel

LogLevel = Literal["debug", "info", "warn", "error"]


class LogRecord(BaseModel):
    ts: str
    level: str
    source: str
    message: str


class LogListResponse(BaseModel):
    items: list[LogRecord]
    next_cursor: int | None = None
