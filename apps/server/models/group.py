from typing import Literal

from pydantic import BaseModel, Field

GroupStatus = Literal["active", "inactive"]


class TimeWindow(BaseModel):
    """A daily streaming window. `start_h`/`end_h` are 0-23 in server-local
    time. If `end_h <= start_h` the window wraps midnight.
    `days` are weekday indices in Python's convention: 0=Monday … 6=Sunday.
    """

    start_h: int = Field(ge=0, le=23)
    end_h: int = Field(ge=0, le=23)
    days: list[int] = Field(default_factory=lambda: [0, 1, 2, 3, 4, 5, 6])


class GroupRestrictions(BaseModel):
    """All fields are optional. `None` means 'no restriction of this kind'."""

    allowed_libraries: list[str] | None = None
    bandwidth_cap_mbps: int | None = Field(default=None, ge=0)
    time_window: TimeWindow | None = None
    max_rating: str | None = None


class GroupResponse(BaseModel):
    id: str
    name: str
    description: str | None
    status: GroupStatus
    created_at: str
    updated_at: str
    member_count: int = 0
    restrictions: GroupRestrictions = Field(default_factory=GroupRestrictions)


class GroupCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str | None = None
    restrictions: GroupRestrictions | None = None


class GroupUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = None
    status: GroupStatus | None = None
    restrictions: GroupRestrictions | None = None


class GroupMemberAdd(BaseModel):
    client_id: str
