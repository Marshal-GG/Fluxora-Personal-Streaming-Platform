from typing import Any

from pydantic import BaseModel


class ActivityEventResponse(BaseModel):
    id: str
    type: str
    actor_kind: str | None = None
    actor_id: str | None = None
    target_kind: str | None = None
    target_id: str | None = None
    summary: str
    payload: dict[str, Any] | None = None
    created_at: str
