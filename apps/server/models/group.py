from typing import Literal

from pydantic import BaseModel, Field

GroupStatus = Literal["active", "inactive"]
PinMode = Literal["session", "per-entry"]
PinModel = Literal["shared", "per-client"]


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
    # v2 content-spaces fields (migration 025).  All defaulted so older
    # clients deserialising the response shape don't break — pre-v2
    # consumers ignore the extra keys.  `pin_hash` is intentionally
    # never returned (write-only at create/update time); the operator
    # sees a `requires_pin` boolean + manages the PIN via
    # set_pin / reset_pin endpoints.
    is_public: bool = False
    requires_pin: bool = False
    pin_mode: PinMode = "session"
    pin_model: PinModel = "shared"
    icon: str | None = None
    color: str | None = None
    max_concurrent_streams: int | None = None


class GroupCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str | None = None
    restrictions: GroupRestrictions | None = None
    # v2 fields.  PIN is the most important — operator sets it at create
    # time when the group is meant to be gated.  `pin_mode` defaults to
    # 'session' (12 h grants); operators can pick 'per-entry' for the
    # strict 5-minute mode on adult / sensitive content.  Server runs
    # `validate_pin_strength` before hashing.
    #
    # M8: `pin_model = 'per-client'` selects per-member enrollment.  Must
    # be created without a `pin` value — each member device sets its own
    # PIN on first access via /enroll.
    pin: str | None = Field(default=None, min_length=4, max_length=8)
    pin_mode: PinMode = "session"
    pin_model: PinModel = "shared"
    icon: str | None = Field(default=None, max_length=40)
    color: str | None = Field(default=None, max_length=16)
    max_concurrent_streams: int | None = Field(default=None, ge=1, le=100)


class GroupUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = None
    status: GroupStatus | None = None
    restrictions: GroupRestrictions | None = None
    # v2 fields.  `pin` semantic on PATCH:
    #   * pin = "<digits>" → set / change the PIN; clears all existing
    #     grants for the group (members re-PIN on next access).
    #   * pin = "" (empty string) → remove the PIN (group becomes
    #     non-gated); also clears existing grants.
    #   * pin = None (field not present) → leave PIN unchanged.
    # The desktop CP "Reset PIN" button supplies a fresh string;
    # "Remove PIN" supplies "".
    #
    # M8: `pin_model` flips between 'shared' (one PIN per group) and
    # 'per-client' (each member enrolls their own).  Switching to shared
    # requires `pin` in the same call (otherwise the group ends up gated
    # with no shared secret).  Switching to per-client clears the shared
    # `pin_hash` and prompts each member to re-enroll on next access.
    pin: str | None = Field(default=None, max_length=8)
    pin_mode: PinMode | None = None
    pin_model: PinModel | None = None
    icon: str | None = Field(default=None, max_length=40)
    color: str | None = Field(default=None, max_length=16)
    max_concurrent_streams: int | None = Field(default=None, ge=1, le=100)


class GroupMemberAdd(BaseModel):
    client_id: str


class GroupMemberPatch(BaseModel):
    """PATCH body for `/groups/{id}/members/{client_id}` (M5 of
    `14_groups_management_page.md`).  All fields optional; per-field
    null semantic mirrors the group-level PATCH:

    * `time_window_override = None` (key omitted) — leave unchanged.
    * `time_window_override = TimeWindow(...)` — set the override.
    * `time_window_override = TimeWindow(start_h=0, end_h=0, days=[])`
      is the canonical "clear" value documented in the API contract;
      the router maps it to a SQL UPDATE … SET = NULL.  An explicit
      sentinel keeps the JSON shape consistent.
    """

    time_window_override: TimeWindow | None = None
