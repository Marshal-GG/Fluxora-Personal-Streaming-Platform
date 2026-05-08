from typing import Literal

from pydantic import BaseModel, Field, field_validator


class PairRequestBody(BaseModel):
    client_id: str
    device_name: str
    platform: Literal["android", "ios", "windows", "macos", "linux"]
    app_version: str = "0.1.0"
    # Optional contact for the operator (Phase A — see backfill plan §9.1).
    # The mobile pairing flow has a "skip" affordance, so missing/null is
    # fine.  The field is echoed back via /clients/me; it is not used as an
    # identity key, so a plain string is sufficient — no email-validator
    # dependency required.
    email: str | None = None


class PairResponse(BaseModel):
    client_id: str
    status: str


class AuthStatusResponse(BaseModel):
    status: Literal["pending_approval", "approved", "rejected"]
    auth_token: str | None = None


class ActiveSessionInfo(BaseModel):
    """Single active stream session attached to a client row.

    Populated by the `auth_service.list_clients` LEFT JOIN against
    `stream_sessions WHERE ended_at IS NULL`. All fields are NULL when
    the client has no in-flight session — the client row still appears
    in the response, just with `active_session = None`.
    """

    session_id: str
    started_at: str
    encoder_used: str | None = None
    media_title: str | None = None


class GroupSummary(BaseModel):
    """Tiny summary of a group a client belongs to.

    Returned per-client by `GET /api/v1/auth/clients` so the desktop
    Clients screen can render group-membership chips on the detail panel
    without a second fetch.  Heavier fields (`restrictions`, `member_count`,
    `created_at`, `updated_at`) live on the dedicated `/groups/{id}` route
    — operators see them when they click into the group, not when they
    look at a client.
    """

    id: str
    name: str
    status: str  # 'active' | 'inactive'


class ClientListItem(BaseModel):
    id: str
    name: str
    platform: str
    status: str
    last_seen: str
    is_trusted: bool
    last_ip: str | None = None
    active_session: ActiveSessionInfo | None = None
    # Groups this client belongs to.  Defaulted to [] so any pre-2026-05-07
    # caller deserialising the response shape doesn't break — the field is
    # always populated server-side post-M3.
    groups: list[GroupSummary] = []


class ClientListResponse(BaseModel):
    clients: list[ClientListItem]
    total: int


class ClientMeResponse(BaseModel):
    """Per-client profile surface for `GET /clients/me` (Phase A).

    `display_name` is sourced from the existing `clients.name` column —
    `name` already serves as the display name; the field is renamed only
    in the API surface for clarity.  `tier` is read from the operator's
    `user_settings.subscription_tier` so the mobile profile screen can
    show "PLUS MEMBER" without a second round-trip to `/info`.
    """

    id: str
    display_name: str
    email: str | None = None
    platform: str
    paired_at: str | None = None
    last_seen: str
    tier: str


class UpdateClientMeRequest(BaseModel):
    """PATCH body for `/auth/clients/me` (mobile settings remediation plan
    M2.5).  Lets the calling client rename its own display device name.

    Validation rules:
      * `display_name` is trimmed before length checks — pure-whitespace
        input is rejected as 422 rather than silently turning into an
        empty string in the DB.
      * Length bound `[1, 50]` matches the desktop "Edit device name"
        affordance (operator-side rename uses the same cap).
      * Control characters (`\\x00`-`\\x1f`) are forbidden — they would
        render as garbage on the operator's Clients screen and are a
        common source of log-injection / display corruption mischief.
    """

    display_name: str = Field(min_length=1, max_length=50)

    @field_validator("display_name")
    @classmethod
    def _validate_display_name(cls, v: str) -> str:
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("display_name must not be blank")
        if len(trimmed) > 50:
            raise ValueError("display_name must be at most 50 characters")
        if any(ord(ch) < 0x20 for ch in trimmed):
            raise ValueError("display_name must not contain control characters")
        return trimmed


class ClientMeStatsResponse(BaseModel):
    """Per-client watch statistics for `GET /auth/clients/me/stats`
    (Phase B backfill plan §3 row 3).

    All three values are non-negative integers and degrade gracefully —
    a fresh client with no stream sessions returns `{0, 0, 0}` rather
    than 404.  `shows` will stay at 0 until Phase D back-fills the
    `tmdb_show_id` column on TV episode rows; that's intentional honesty
    rather than a guessed-up number.
    """

    hours: int
    movies: int
    shows: int
