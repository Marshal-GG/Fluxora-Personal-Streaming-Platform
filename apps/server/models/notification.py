from typing import Literal

from pydantic import BaseModel, Field

NotificationType = Literal["info", "warning", "error", "success"]
NotificationCategory = Literal["system", "client", "license", "transcode", "storage"]


class NotificationResponse(BaseModel):
    id: str
    type: NotificationType
    category: NotificationCategory
    title: str
    message: str
    related_kind: str | None = None
    related_id: str | None = None
    created_at: str
    read_at: str | None = None
    dismissed_at: str | None = None


class NotificationCreate(BaseModel):
    """Internal — emitted by services, not exposed via REST."""

    type: NotificationType
    category: NotificationCategory
    title: str = Field(min_length=1, max_length=120)
    message: str = Field(min_length=1, max_length=500)
    related_kind: str | None = None
    related_id: str | None = None
