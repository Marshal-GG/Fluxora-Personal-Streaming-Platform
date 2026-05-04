from typing import Literal

from pydantic import BaseModel


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


class ClientListItem(BaseModel):
    id: str
    name: str
    platform: str
    status: str
    last_seen: str
    is_trusted: bool


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
