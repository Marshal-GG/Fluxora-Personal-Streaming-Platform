"""Client-group management.

| Method | Path                                       | Auth                  |
|--------|--------------------------------------------|-----------------------|
| GET    | /api/v1/groups/                            | localhost or token    |
| POST   | /api/v1/groups/                            | localhost only        |
| GET    | /api/v1/groups/{id}                        | localhost or token    |
| PATCH  | /api/v1/groups/{id}                        | localhost only        |
| DELETE | /api/v1/groups/{id}                        | localhost only        |
| GET    | /api/v1/groups/{id}/members                | localhost or token    |
| POST   | /api/v1/groups/{id}/members                | localhost only        |
| DELETE | /api/v1/groups/{id}/members/{cid}          | localhost only        |
| DELETE | /api/v1/groups/{id}/members/{cid}/pin      | localhost only (M8)   |
| POST   | /api/v1/groups/{id}/enter                  | bearer token only     |
| POST   | /api/v1/groups/{id}/enroll                 | bearer token only (M8)|
| POST   | /api/v1/groups/{id}/enroll/change          | bearer token only (M8)|
| DELETE | /api/v1/groups/{id}/grant                  | bearer token only     |
| GET    | /api/v1/groups/{id}/grant-status           | bearer token only     |
| POST   | /api/v1/groups/{id}/master-override        | localhost only        |

The /enter, /enroll, /grant, /grant-status routes are PIN unlock surfaces
from §M4 + §M8 of `docs/10_planning/13_groups_v2_content_spaces.md`.
Bearer-token only because they're client-identity scoped (the calling
device is the grant or enrollment subject).  The operator's master-
override + member-PIN-clear paths are localhost routes lower down.
"""

import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from config import settings
from database.db import get_db
from models.group import (
    GroupCreate,
    GroupMemberAdd,
    GroupMemberPatch,
    GroupResponse,
    GroupUpdate,
)
from routers.deps import require_local_caller, validate_token, validate_token_or_local
from services import group_service

logger = logging.getLogger(__name__)

router = APIRouter()


def _to_response(payload: dict) -> GroupResponse:
    return GroupResponse(**payload)


@router.get("", response_model=list[GroupResponse])
async def list_groups(
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[GroupResponse]:
    rows = await group_service.list_groups(db)
    return [_to_response(r) for r in rows]


@router.post("", response_model=GroupResponse, status_code=status.HTTP_201_CREATED)
async def create_group(
    body: GroupCreate,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> GroupResponse:
    restrictions = body.restrictions.model_dump() if body.restrictions else None
    try:
        created = await group_service.create_group(
            db,
            name=body.name,
            description=body.description,
            restrictions=restrictions,
            pin=body.pin,
            pin_mode=body.pin_mode,
            pin_model=body.pin_model,
            icon=body.icon,
            color=body.color,
            max_concurrent_streams=body.max_concurrent_streams,
            hmac_key=settings.token_hmac_key,
        )
    except ValueError as e:
        # PIN strength rejection from group_service.  Translate to 400 with
        # the strength-policy message so the desktop CP can display it
        # next to the PIN field.
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        ) from e
    return _to_response(created)


@router.get("/{group_id}", response_model=GroupResponse)
async def get_group(
    group_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> GroupResponse:
    payload = await group_service.get_group(db, group_id)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )
    return _to_response(payload)


@router.patch("/{group_id}", response_model=GroupResponse)
async def update_group(
    group_id: str,
    body: GroupUpdate,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> GroupResponse:
    restrictions = body.restrictions.model_dump() if body.restrictions else None
    try:
        updated = await group_service.update_group(
            db,
            group_id=group_id,
            name=body.name,
            description=body.description,
            status=body.status,
            restrictions=restrictions,
            pin=body.pin,
            pin_mode=body.pin_mode,
            pin_model=body.pin_model,
            icon=body.icon,
            color=body.color,
            max_concurrent_streams=body.max_concurrent_streams,
            hmac_key=settings.token_hmac_key,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        ) from e
    if updated is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )
    return _to_response(updated)


@router.delete("/{group_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_group(
    group_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> None:
    deleted = await group_service.delete_group(db, group_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )


@router.get("/{group_id}/members")
async def list_members(
    group_id: str,
    include: str | None = None,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[dict]:
    """List members of a group.

    Query parameter `include=pin_state` (M3 of `14_groups_management_page.md`)
    extends each row with `enrollment_state`, `has_active_grant`,
    `grant_expires_at`, `recent_failed_attempts` so the desktop Members
    tab can render PIN status badges without a second round-trip.  Older
    callers that don't pass `include` get the v1 shape unchanged.
    """
    include_pin_state = include == "pin_state"
    rows = await group_service.list_members(
        db, group_id, include_pin_state=include_pin_state
    )
    if rows is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )
    return rows


@router.post("/{group_id}/members", status_code=status.HTTP_204_NO_CONTENT)
async def add_member(
    group_id: str,
    body: GroupMemberAdd,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> None:
    ok = await group_service.add_member(db, group_id, body.client_id)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group or client not found",
        )


@router.delete(
    "/{group_id}/members/{client_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_member(
    group_id: str,
    client_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> None:
    removed = await group_service.remove_member(db, group_id, client_id)
    if not removed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group member not found",
        )


@router.patch(
    "/{group_id}/members/{client_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def patch_member(
    group_id: str,
    client_id: str,
    body: GroupMemberPatch,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> None:
    """Update per-member overrides on a group membership row.  Currently
    surfaces `time_window_override` only (M5 of
    `14_groups_management_page.md`).  Sentinel `start_h=0, end_h=0,
    days=[]` clears the override; any other shape sets it.
    """
    if body.time_window_override is None:
        # Sentinel for "no field present" — body was effectively empty.
        # Treat as no-op for forward-compat (future fields might land
        # here without breaking older callers).
        return
    tw = body.time_window_override
    is_clear_sentinel = (
        tw.start_h == 0 and tw.end_h == 0 and not tw.days
    )
    payload = None if is_clear_sentinel else tw.model_dump()
    ok = await group_service.set_member_time_window_override(
        db, group_id, client_id, time_window=payload
    )
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group member not found",
        )


# ── PIN flow (M4 of `13_groups_v2_content_spaces.md`) ─────────────────────


class _PinEnterBody(BaseModel):
    """Request body for `POST /groups/{id}/enter`.  PIN is 4-8 numeric;
    server-side `validate_pin_strength` runs before the compare so junk
    inputs don't even hit the rate limiter.  `pin` is plain in the body
    (HMAC happens server-side); transport is HTTPS over the LAN +
    Cloudflare tunnel — same channel as bearer tokens."""

    pin: str = Field(min_length=4, max_length=8)


class _PinEnterResponse(BaseModel):
    expires_at: str
    pin_mode: str  # 'session' | 'per-entry' (echoed for client UX)


class _GrantStatusResponse(BaseModel):
    """Reply from `GET /groups/{id}/grant-status`.  `unlocked=False` is
    the steady-state for a PIN-required group the client hasn't entered
    yet; `unlocked=True` + `expires_at` shows the active grant.  Used by
    the mobile "Unlock libraries" surface to know which groups still
    need a PIN.

    M8 fields (`pin_model`, `enrollment_state`) let the mobile UI route
    to the *enrollment* surface instead of the *entry* surface for
    per-client groups the device hasn't yet enrolled in.
    """

    unlocked: bool
    expires_at: str | None = None
    pin_model: str = "shared"  # 'shared' | 'per-client'
    enrollment_state: str = "not_required"
    # 'not_required'        — shared mode, or already enrolled, or not gated
    # 'enrolled'            — per-client mode + enrollment row exists
    # 'enrollment_required' — per-client mode + no enrollment yet


class _EnrollBody(BaseModel):
    """Request body for `POST /groups/{id}/enroll` — first-time per-client
    PIN enrollment."""

    pin: str = Field(min_length=4, max_length=8)


class _EnrollChangeBody(BaseModel):
    """Request body for `POST /groups/{id}/enroll/change` — replace the
    calling client's per-client PIN.  `old_pin` is the existing PIN;
    wrong values count against the rate limiter so this endpoint can't
    be used to brute-force the existing PIN."""

    old_pin: str = Field(min_length=4, max_length=8)
    new_pin: str = Field(min_length=4, max_length=8)


@router.post(
    "/{group_id}/enter",
    response_model=_PinEnterResponse,
)
async def enter_group(
    group_id: str,
    body: _PinEnterBody,
    db: aiosqlite.Connection = Depends(get_db),
    me: aiosqlite.Row = Depends(validate_token),
) -> _PinEnterResponse:
    """Enter a PIN to unlock a PIN-gated group for the calling client.

    Bearer-token only: the calling device is the grant subject; the
    operator's master-override path is the localhost variant below.
    Strength policy (`validate_pin_strength`) runs first so junk
    inputs don't burn rate-limit budget.  Failed attempts insert a
    row into `group_pin_attempts`; 5 fails in 60 s lock the (client,
    group) tuple out — even with the correct PIN the next call 429s
    until the window passes.

    Errors:
      * 400 — strength rejection (PIN doesn't meet the policy)
      * 404 — unknown group
      * 400 — group doesn't require a PIN (no-op)
      * 401 — incorrect PIN (with `attempts_remaining` in the body)
      * 429 — rate limited
    """
    strength_err = group_service.validate_pin_strength(body.pin)
    if strength_err is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=strength_err
        )

    result = await group_service.enter_pin_grant(
        db,
        client_id=me["id"],
        group_id=group_id,
        pin=body.pin,
        hmac_key=settings.token_hmac_key,
    )

    if result.granted:
        # Look up pin_mode for the response so the mobile UI can size
        # the "this unlock lasts 12 hours" / "5 minutes" caption right.
        async with db.execute(
            "SELECT pin_mode FROM groups WHERE id = ?", (group_id,)
        ) as cur:
            row = await cur.fetchone()
        return _PinEnterResponse(
            expires_at=result.expires_at or "",
            pin_mode=row["pin_mode"] if row else "session",
        )

    if result.error == "unknown_group":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )
    if result.error == "no_pin_required":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Group does not require a PIN",
        )
    if result.error == "rate_limited":
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed PIN attempts — try again in a minute",
        )
    if result.error == "enrollment_required":
        # Per-client mode with no enrollment row.  Mobile is expected to
        # call /enroll first; this 400 is the route layer telling a UI
        # that fell through that the user needs to set up a PIN before
        # they can enter one.
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Per-client PIN enrollment required — call /enroll first",
        )
    # incorrect_pin
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=f"Incorrect PIN ({result.attempts_remaining} attempts remaining)",
    )


@router.delete(
    "/{group_id}/grant",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def revoke_grant(
    group_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    me: aiosqlite.Row = Depends(validate_token),
) -> None:
    """Lock a previously-unlocked group on the calling client.  Idempotent
    — no-op when no grant exists.  Mobile "Lock" button + the global
    "Lock all" button both hit this."""
    await group_service.revoke_pin_grant(db, me["id"], group_id)


@router.get(
    "/{group_id}/grant-status",
    response_model=_GrantStatusResponse,
)
async def grant_status(
    group_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    me: aiosqlite.Row = Depends(validate_token),
) -> _GrantStatusResponse:
    """Whether the calling client currently holds a valid grant for the
    group, plus M8 enrollment state for per-client mode.  Mobile polls
    this on app foreground to refresh the unlock state after sleep /
    restart — local cache survives but the server-side grant may have
    expired or the operator may have flipped the group's pin_model."""
    from datetime import UTC, datetime
    now_iso = datetime.now(UTC).isoformat()
    async with db.execute(
        """
        SELECT g.requires_pin, g.pin_model,
               (SELECT 1 FROM group_pin_grants gpg
                 WHERE gpg.client_id = ? AND gpg.group_id = g.id
                   AND gpg.expires_at > ?
                LIMIT 1)                      AS has_grant,
               (SELECT expires_at FROM group_pin_grants gpg
                 WHERE gpg.client_id = ? AND gpg.group_id = g.id
                   AND gpg.expires_at > ?
                LIMIT 1)                      AS grant_expires_at,
               (SELECT 1 FROM group_member_pins gmp
                 WHERE gmp.client_id = ? AND gmp.group_id = g.id
                LIMIT 1)                      AS has_enrollment
          FROM groups g
         WHERE g.id = ?
        """,
        (me["id"], now_iso, me["id"], now_iso, me["id"], group_id),
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )

    pin_model = row["pin_model"] or "shared"
    requires_pin = bool(row["requires_pin"])
    is_enrolled = row["has_enrollment"] is not None

    if not requires_pin:
        enrollment_state = "not_required"
    elif pin_model == "shared":
        enrollment_state = "not_required"
    elif is_enrolled:
        enrollment_state = "enrolled"
    else:
        enrollment_state = "enrollment_required"

    return _GrantStatusResponse(
        unlocked=row["has_grant"] is not None,
        expires_at=row["grant_expires_at"],
        pin_model=pin_model,
        enrollment_state=enrollment_state,
    )


# ── M8 — per-client PIN enrollment ────────────────────────────────────────


def _translate_enroll_error(err: str | None, attempts_remaining: int | None):
    """Shared error → HTTPException mapping for /enroll + /enroll/change.
    Strength-policy reasons surface as 400; structural failures (group
    state, membership) as 4xx with their own codes."""
    if err == "unknown_group":
        return HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )
    if err == "no_pin_required":
        return HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Group does not require a PIN",
        )
    if err == "wrong_mode":
        return HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "This group uses a shared PIN — use /enter, not /enroll"
            ),
        )
    if err == "not_a_member":
        return HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Calling client is not a member of this group",
        )
    if err == "already_enrolled":
        return HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "PIN already enrolled — use /enroll/change to replace it"
            ),
        )
    if err == "not_enrolled":
        return HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No enrollment for this client — use /enroll first",
        )
    if err == "rate_limited":
        return HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed PIN attempts — try again in a minute",
        )
    if err == "incorrect_pin":
        return HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                f"Incorrect PIN ({attempts_remaining} attempts remaining)"
            ),
        )
    # strength-policy reason or unknown — surface as 400 with the raw text
    return HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=err or "Enrollment failed",
    )


@router.post(
    "/{group_id}/enroll",
    response_model=_PinEnterResponse,
)
async def enroll_pin(
    group_id: str,
    body: _EnrollBody,
    db: aiosqlite.Connection = Depends(get_db),
    me: aiosqlite.Row = Depends(validate_token),
) -> _PinEnterResponse:
    """First-time enrollment for a per-client PIN group.  Records the
    calling client's PIN and immediately issues a session-length grant
    (the user just typed the PIN — re-prompting is hostile UX).

    Errors:
      * 400 — strength rejection / no-pin-required / wrong mode /
              not-enrolled (use /enter)
      * 401 — n/a (no compare on enrollment)
      * 403 — calling client isn't a member of the group
      * 404 — unknown group
      * 409 — already enrolled (use /enroll/change instead)
    """
    result = await group_service.enroll_pin(
        db,
        client_id=me["id"],
        group_id=group_id,
        pin=body.pin,
        hmac_key=settings.token_hmac_key,
    )
    if result.granted:
        async with db.execute(
            "SELECT pin_mode FROM groups WHERE id = ?", (group_id,)
        ) as cur:
            row = await cur.fetchone()
        return _PinEnterResponse(
            expires_at=result.expires_at or "",
            pin_mode=row["pin_mode"] if row else "session",
        )
    raise _translate_enroll_error(result.error, result.attempts_remaining)


@router.post(
    "/{group_id}/enroll/change",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def change_enrolled_pin(
    group_id: str,
    body: _EnrollChangeBody,
    db: aiosqlite.Connection = Depends(get_db),
    me: aiosqlite.Row = Depends(validate_token),
) -> None:
    """Replace the calling client's per-client PIN.  Verifies `old_pin`
    against the rate limiter.  Existing grant carries — the user already
    authenticated successfully so we don't kick them out for changing
    their PIN.

    Errors:
      * 400 — strength rejection / no-pin-required / wrong mode / not-enrolled
      * 401 — old_pin wrong
      * 404 — unknown group
      * 429 — rate limited
    """
    result = await group_service.change_member_pin(
        db,
        client_id=me["id"],
        group_id=group_id,
        old_pin=body.old_pin,
        new_pin=body.new_pin,
        hmac_key=settings.token_hmac_key,
    )
    if result.granted:
        return
    raise _translate_enroll_error(result.error, result.attempts_remaining)


@router.delete(
    "/{group_id}/members/{client_id}/pin",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def clear_member_pin(
    group_id: str,
    client_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> None:
    """Operator action — drop a member's per-client PIN enrollment so
    they re-enroll on next access.  Localhost only — the desktop CP is
    the only legitimate caller.  Also drops any active grant for that
    member so visibility flips immediately.  Idempotent — clearing a
    non-existent enrollment returns 204.

    Errors:
      * 403 — not from localhost
    """
    await group_service.clear_member_pin(db, client_id, group_id)


@router.post(
    "/{group_id}/grants/reset",
    status_code=status.HTTP_200_OK,
)
async def reset_all_grants(
    group_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> dict:
    """Bulk-drop every active PIN grant for a group (M7 follow-up of
    `14_groups_management_page.md` — desktop "Reset all PINs" Danger
    Zone action for shared-mode groups).

    Per-client mode operators use `DELETE /groups/{id}/members/{cid}/pin`
    per member instead — this route only touches grants, not the
    per-client enrollment ledger, because the shared-mode intent is
    "force re-entry of the shared PIN," not "blow away setup."

    Auth: localhost only — same trust boundary as master-override.

    Errors:
      * 404 — group not found
    """
    async with db.execute(
        "SELECT id FROM groups WHERE id = ?", (group_id,)
    ) as cur:
        if await cur.fetchone() is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Group not found",
            )
    deleted = await group_service.revoke_all_grants_for_group(db, group_id)
    return {"dropped": deleted}


@router.post(
    "/{group_id}/master-override",
    response_model=_PinEnterResponse,
)
async def master_override_unlock(
    group_id: str,
    client_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> _PinEnterResponse:
    """Operator master override: unlock a PIN-gated group on a specific
    client without supplying the PIN.  Localhost only — the desktop CP
    is the only legitimate caller; off-loopback callers get 403 via
    `require_local_caller`.

    Recovery path for the forgot-PIN case ("operator forgot the Adults
    PIN; tablet is locked out").  Always-available; bypasses the rate
    limiter; logs an activity event with `actor=operator-override` for
    audit.

    Errors:
      * 404 — unknown group
      * 400 — group doesn't require a PIN (no-op; nothing to unlock)
    """
    from datetime import UTC, datetime, timedelta

    async with db.execute(
        "SELECT requires_pin, pin_mode FROM groups WHERE id = ?",
        (group_id,),
    ) as cur:
        group = await cur.fetchone()
    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )
    if not group["requires_pin"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Group does not require a PIN",
        )

    # Issue a session-length grant regardless of pin_mode — operator
    # override is meant to be sticky enough that the kid's tablet
    # doesn't immediately re-prompt.
    now = datetime.now(UTC)
    expires_at = now + timedelta(hours=12)
    await db.execute(
        """
        INSERT INTO group_pin_grants
            (client_id, group_id, granted_at, expires_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT (client_id, group_id) DO UPDATE SET
            granted_at = excluded.granted_at,
            expires_at = excluded.expires_at
        """,
        (
            client_id,
            group_id,
            now.isoformat(),
            expires_at.isoformat(),
        ),
    )
    # Log a successful "attempt" so audit shows operator overrode the gate.
    await db.execute(
        """
        INSERT INTO group_pin_attempts
            (client_id, group_id, attempted_at, success)
        VALUES (?, ?, ?, 1)
        """,
        (client_id, group_id, now.isoformat()),
    )
    await db.commit()
    logger.info(
        "Master override: client=%s group=%s expires=%s",
        client_id,
        group_id,
        expires_at.isoformat(),
    )
    return _PinEnterResponse(
        expires_at=expires_at.isoformat(),
        pin_mode=group["pin_mode"],
    )
