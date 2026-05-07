"""Client-group CRUD + stream-gate enforcement.

Two models coexist here during the v1.5 transition (plan in
`docs/10_planning/13_groups_v2_content_spaces.md`):

**v1 (subtractive — current stream-gate consumer)**

Groups REMOVE access from a default-everything baseline:
- `allowed_libraries`: only these library ids may be streamed
- `time_window`: streams only allowed within this daily window
- `bandwidth_cap_mbps`: throughput cap (advisory)
- `max_rating`: content-rating ceiling (advisory)

The effective restriction is the intersection (most restrictive) of every
active group the client is in.  Used by `get_effective_restrictions` +
`reason_to_deny`; consumed by [`stream.py:100-107`].

**v2 (additive — new model, list-endpoint consumer)**

Groups GRANT access from a default-nothing baseline.  Every paired client
auto-joins the mandatory `Public` group (migration 025); additional groups
expose more libraries.  Multi-group is a UNION, not an intersection.  Some
groups require a PIN; PIN-gated libraries are *invisible* until unlocked,
not just blocked at play-time.

The single source of truth is `get_visible_libraries(client_id, now) ->
VisibleLibraries`.  Used by all list endpoints (M2 work) + the new
`reason_to_deny_stream` for the stream-gate (will replace v1 consumer).

PIN flow: `enter_pin_grant` writes a row to `group_pin_grants` with
expiry per the group's `pin_mode` ('session' = 12 h, 'per-entry' = 5 min).
`reason_to_deny_stream` + `get_visible_libraries` consult the grant before
honoring a gated group's libraries.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any

import aiosqlite

logger = logging.getLogger(__name__)

# Grant TTLs by mode.  'session' gives the operator's tablet a comfortable
# day's worth of unlocked access; 'per-entry' is the strict mode for
# adult / sensitive content where every navigation should re-PIN.  Tunable
# via env var if a user hits a corner case; honest values for v1.5.
_GRANT_TTL_SESSION = timedelta(hours=12)
_GRANT_TTL_PER_ENTRY = timedelta(minutes=5)

# Brute-force protection: 5 failed attempts within the last 60 seconds locks
# the (client, group) tuple out for the rest of the window.  PIN attempts
# table is pruned at 24 h by the housekeeping task in main.py.
_PIN_RATE_WINDOW_SEC = 60
_PIN_RATE_MAX_FAILS = 5

# Activity-event aggregation for failed PIN attempts.  Emit one
# `group.pin.failed-burst` event when failures hit the threshold
# inside the dedup window — avoids flooding the operator's audit feed
# with one row per fat-finger.  Window is wider than the rate-limit
# window (60 s) so a sliding-window second burst still counts.  The
# trigger fires when count *crosses* the threshold at the failing
# attempt; subsequent attempts in the same burst don't re-emit.
_FAILED_BURST_WINDOW_SEC = 600  # 10 min
_FAILED_BURST_THRESHOLD = 5

# Obvious PINs the strength policy rejects by default.  The list is
# intentionally short — operator gets clear feedback that "1234" / "0000"
# don't fly, but we don't pretend to enforce real password complexity on
# a 4-8 digit numeric.  Configurable expansion if a user hits an edge.
_OBVIOUS_PINS = {
    '0000', '1111', '2222', '3333', '4444', '5555', '6666', '7777',
    '8888', '9999',
    '1234', '2345', '3456', '4567', '5678', '6789',
    '4321', '5432', '6543', '7654', '8765', '9876', '0987',
    '0123',
    '2580',  # phone keypad column
}


# ── helpers ────────────────────────────────────────────────────────────────


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _decode_restrictions(row: aiosqlite.Row | None) -> dict[str, Any]:
    if row is None:
        return {
            "allowed_libraries": None,
            "bandwidth_cap_mbps": None,
            "time_window": None,
            "max_rating": None,
        }
    allowed = row["allowed_libraries"]
    window = row["time_window"]
    return {
        "allowed_libraries": json.loads(allowed) if allowed else None,
        "bandwidth_cap_mbps": row["bandwidth_cap_mbps"],
        "time_window": json.loads(window) if window else None,
        "max_rating": row["max_rating"],
    }


def _encode_restrictions(restrictions: dict[str, Any] | None) -> dict[str, Any]:
    """Convert a Pydantic-dump dict into DB column values."""
    if restrictions is None:
        return {
            "allowed_libraries": None,
            "bandwidth_cap_mbps": None,
            "time_window": None,
            "max_rating": None,
        }
    allowed = restrictions.get("allowed_libraries")
    window = restrictions.get("time_window")
    return {
        "allowed_libraries": json.dumps(allowed) if allowed is not None else None,
        "bandwidth_cap_mbps": restrictions.get("bandwidth_cap_mbps"),
        "time_window": json.dumps(window) if window is not None else None,
        "max_rating": restrictions.get("max_rating"),
    }


async def _member_count(db: aiosqlite.Connection, group_id: str) -> int:
    async with db.execute(
        "SELECT COUNT(*) FROM group_members WHERE group_id = ?", (group_id,)
    ) as cur:
        row = await cur.fetchone()
    return int(row[0]) if row else 0


async def _hydrate(
    db: aiosqlite.Connection, group_row: aiosqlite.Row
) -> dict[str, Any]:
    async with db.execute(
        "SELECT * FROM group_restrictions WHERE group_id = ?",
        (group_row["id"],),
    ) as cur:
        rest_row = await cur.fetchone()
    member_count = await _member_count(db, group_row["id"])
    # v2 columns are added by migration 025; access via .keys() check so
    # the function survives a partial-rollback scenario where only some
    # of the columns landed.  Defensive against operator-side schema
    # surgery — production code should never hit the fallback path.
    keys = group_row.keys() if hasattr(group_row, "keys") else []
    return {
        "id": group_row["id"],
        "name": group_row["name"],
        "description": group_row["description"],
        "status": group_row["status"],
        "created_at": group_row["created_at"],
        "updated_at": group_row["updated_at"],
        "member_count": member_count,
        "restrictions": _decode_restrictions(rest_row),
        "is_public": bool(group_row["is_public"]) if "is_public" in keys else False,
        "requires_pin": (
            bool(group_row["requires_pin"]) if "requires_pin" in keys else False
        ),
        "pin_mode": (
            group_row["pin_mode"] if "pin_mode" in keys else "session"
        ),
        "pin_model": (
            group_row["pin_model"] if "pin_model" in keys else "shared"
        ),
        "icon": group_row["icon"] if "icon" in keys else None,
        "color": group_row["color"] if "color" in keys else None,
        "max_concurrent_streams": (
            group_row["max_concurrent_streams"]
            if "max_concurrent_streams" in keys
            else None
        ),
    }


# ── CRUD ───────────────────────────────────────────────────────────────────


async def list_groups(db: aiosqlite.Connection) -> list[dict[str, Any]]:
    async with db.execute("SELECT * FROM groups ORDER BY created_at DESC") as cur:
        rows = await cur.fetchall()
    return [await _hydrate(db, row) for row in rows]


async def get_group(db: aiosqlite.Connection, group_id: str) -> dict[str, Any] | None:
    async with db.execute("SELECT * FROM groups WHERE id = ?", (group_id,)) as cur:
        row = await cur.fetchone()
    if row is None:
        return None
    return await _hydrate(db, row)


async def create_group(
    db: aiosqlite.Connection,
    name: str,
    description: str | None,
    restrictions: dict[str, Any] | None,
    *,
    pin: str | None = None,
    pin_mode: str = "session",
    pin_model: str = "shared",
    icon: str | None = None,
    color: str | None = None,
    max_concurrent_streams: int | None = None,
    hmac_key: str | None = None,
) -> dict[str, Any]:
    """Create a non-public group.  v2 fields are kw-only so existing
    callers (tests, /groups POST router) keep working when they don't
    pass them.  When `pin` is supplied, server-side validate_pin_strength
    runs before hashing; on failure the function raises ValueError so
    the router can translate to 400.  `hmac_key` is required when `pin`
    is supplied — supplied by the route from `settings.token_hmac_key`.

    M8: `pin_model` selects shared (one PIN per group, household secret)
    vs per-client (each member device enrolls its own).  Shared is the
    default — matches the M4 ship.  When per-client, callers must NOT
    supply `pin` at create time (per-client groups have no shared PIN);
    `requires_pin` is still set to 1 so the gate applies, and members
    enroll on first access via `enroll_pin`.
    """
    if pin_model not in ("shared", "per-client"):
        raise ValueError(
            f"pin_model must be 'shared' or 'per-client', got {pin_model!r}"
        )

    if pin is not None:
        if pin_model == "per-client":
            raise ValueError(
                "Per-client PIN groups have no shared PIN at create time; "
                "members enroll on first access."
            )
        strength_err = validate_pin_strength(pin)
        if strength_err is not None:
            raise ValueError(strength_err)
        if hmac_key is None:
            raise ValueError("hmac_key is required when pin is supplied")
    group_id = str(uuid.uuid4())
    now = _now()

    pin_hash = hash_pin(pin, hmac_key) if pin and hmac_key else None
    # Per-client groups are gated even though no shared PIN is set yet —
    # `requires_pin = 1` is what causes visibility resolution to put the
    # group in `enrollment_required_groups` until each member enrolls.
    requires_pin = 1 if (pin_hash or pin_model == "per-client") else 0

    await db.execute(
        """
        INSERT INTO groups
            (id, name, description, status, created_at, updated_at,
             requires_pin, pin_hash, pin_mode, pin_model,
             icon, color, max_concurrent_streams)
        VALUES (?, ?, ?, 'active', ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            group_id, name, description, now, now,
            requires_pin, pin_hash, pin_mode, pin_model,
            icon, color, max_concurrent_streams,
        ),
    )
    enc = _encode_restrictions(restrictions)
    await db.execute(
        """
        INSERT INTO group_restrictions
            (group_id, allowed_libraries, bandwidth_cap_mbps,
             time_window, max_rating)
        VALUES (?, ?, ?, ?, ?)
        """,
        (
            group_id,
            enc["allowed_libraries"],
            enc["bandwidth_cap_mbps"],
            enc["time_window"],
            enc["max_rating"],
        ),
    )
    await db.commit()
    logger.info(
        "Group created: %s (%s, pin=%s)",
        name, group_id, "yes" if pin_hash else "no",
    )

    hydrated = await get_group(db, group_id)
    if hydrated is None:
        raise RuntimeError(f"Failed to hydrate newly-created group {group_id}")
    return hydrated


async def update_group(
    db: aiosqlite.Connection,
    group_id: str,
    name: str | None,
    description: str | None,
    status: str | None,
    restrictions: dict[str, Any] | None,
    *,
    pin: str | None = None,
    pin_mode: str | None = None,
    pin_model: str | None = None,
    icon: str | None = None,
    color: str | None = None,
    max_concurrent_streams: int | None = None,
    hmac_key: str | None = None,
) -> dict[str, Any] | None:
    """Update an existing group.

    `pin` semantic (shared mode only):
      * `None` (omitted) — leave PIN unchanged.
      * `""` (empty string) — remove the PIN; group becomes non-gated.
        All existing grants for the group are deleted (members re-PIN
        on next access — moot here since the group is no longer gated,
        but keeps the grants table tidy).
      * `"<digits>"` — set / change the PIN.  Validates strength + hashes
        with `hmac_key`.  All existing grants are deleted (members re-PIN
        on next access).

    `pin_model` semantic (M8):
      * `None` (omitted) — leave mode unchanged.
      * `'shared'`     — household-PIN mode.  `pin` must be supplied in
        the same call when transitioning from per-client → shared (no
        meaningful default exists otherwise).  Per-client enrollment rows
        are deleted; existing grants are kept (members aren't kicked off
        mid-session).
      * `'per-client'` — per-member enrollment mode.  `pin_hash` is
        cleared (no shared secret).  `requires_pin = 1` because the
        group is still gated — visibility resolution surfaces members
        with no enrollment row in `enrollment_required_groups`.
        Existing grants are kept; on expiry each member is prompted to
        enroll.
    """
    existing = await get_group(db, group_id)
    if existing is None:
        return None

    # M8: mode transition — handle first so subsequent PIN handling sees
    # a coherent (mode, pin_hash, requires_pin) state.
    if pin_model is not None:
        if pin_model not in ("shared", "per-client"):
            raise ValueError(
                f"pin_model must be 'shared' or 'per-client', got {pin_model!r}"
            )
        current_model = existing.get("pin_model") or "shared"
        if pin_model != current_model:
            if pin_model == "per-client":
                # shared → per-client: clear shared hash; keep grants;
                # members re-enroll on grant expiry.
                await db.execute(
                    "UPDATE groups SET pin_model = 'per-client', "
                    "pin_hash = NULL, requires_pin = 1 "
                    "WHERE id = ?",
                    (group_id,),
                )
            else:
                # per-client → shared: requires the caller to also pass
                # `pin` so the group ends up with a usable shared secret.
                # Without it the group would be gated with no way to enter.
                if pin is None or pin == "":
                    raise ValueError(
                        "Switching to shared mode requires a new shared "
                        "PIN in the same call."
                    )
                # Validation + write happens in the `pin` block below;
                # delete enrollment rows here.
                await db.execute(
                    "DELETE FROM group_member_pins WHERE group_id = ?",
                    (group_id,),
                )
                await db.execute(
                    "UPDATE groups SET pin_model = 'shared' WHERE id = ?",
                    (group_id,),
                )

    # PIN handling — done after mode transition so the (mode, hash) pair
    # is consistent.  Reject `pin` writes when the resulting mode is
    # per-client (per-client groups have no shared PIN).
    resulting_model = (
        pin_model if pin_model is not None else (existing.get("pin_model") or "shared")
    )
    if pin is not None:
        if pin == "":
            if resulting_model == "per-client":
                # Per-client groups have no shared PIN to remove.  Use
                # the dedicated clear endpoint for individual members,
                # or flip the mode back to shared first.  Allow as a
                # no-op rather than 400 to keep the desktop "Remove PIN"
                # button idempotent across mode flips.
                pass
            else:
                # Remove PIN.
                await db.execute(
                    "UPDATE groups SET requires_pin = 0, pin_hash = NULL "
                    "WHERE id = ?",
                    (group_id,),
                )
                await db.execute(
                    "DELETE FROM group_pin_grants WHERE group_id = ?",
                    (group_id,),
                )
        else:
            if resulting_model == "per-client":
                raise ValueError(
                    "Per-client PIN groups have no shared PIN; members "
                    "enroll via the per-client enrollment endpoint."
                )
            strength_err = validate_pin_strength(pin)
            if strength_err is not None:
                raise ValueError(strength_err)
            if hmac_key is None:
                raise ValueError("hmac_key required when setting a PIN")
            new_hash = hash_pin(pin, hmac_key)
            await db.execute(
                "UPDATE groups SET requires_pin = 1, pin_hash = ? "
                "WHERE id = ?",
                (new_hash, group_id),
            )
            # Reset grants — members must re-PIN under the new PIN.
            await db.execute(
                "DELETE FROM group_pin_grants WHERE group_id = ?",
                (group_id,),
            )

    fields: list[str] = []
    values: list[Any] = []
    if name is not None:
        fields.append("name = ?")
        values.append(name)
    if description is not None:
        fields.append("description = ?")
        values.append(description)
    if status is not None:
        fields.append("status = ?")
        values.append(status)
    if pin_mode is not None:
        fields.append("pin_mode = ?")
        values.append(pin_mode)
    if icon is not None:
        fields.append("icon = ?")
        values.append(icon)
    if color is not None:
        fields.append("color = ?")
        values.append(color)
    if max_concurrent_streams is not None:
        fields.append("max_concurrent_streams = ?")
        values.append(max_concurrent_streams)
    if fields:
        fields.append("updated_at = ?")
        values.append(_now())
        values.append(group_id)
        await db.execute(
            f"UPDATE groups SET {', '.join(fields)} WHERE id = ?",
            tuple(values),
        )

    if restrictions is not None:
        enc = _encode_restrictions(restrictions)
        await db.execute(
            """
            UPDATE group_restrictions
               SET allowed_libraries = ?,
                   bandwidth_cap_mbps = ?,
                   time_window = ?,
                   max_rating = ?
             WHERE group_id = ?
            """,
            (
                enc["allowed_libraries"],
                enc["bandwidth_cap_mbps"],
                enc["time_window"],
                enc["max_rating"],
                group_id,
            ),
        )
        # touch updated_at when restrictions change
        await db.execute(
            "UPDATE groups SET updated_at = ? WHERE id = ?",
            (_now(), group_id),
        )

    await db.commit()
    logger.info("Group updated: %s", group_id)
    return await get_group(db, group_id)


async def delete_group(db: aiosqlite.Connection, group_id: str) -> bool:
    async with db.execute("SELECT id FROM groups WHERE id = ?", (group_id,)) as cur:
        if await cur.fetchone() is None:
            return False
    # ON DELETE CASCADE handles group_members + group_restrictions.
    await db.execute("DELETE FROM groups WHERE id = ?", (group_id,))
    await db.commit()
    logger.info("Group deleted: %s", group_id)
    return True


# ── Members ────────────────────────────────────────────────────────────────


async def _emit_group_activity(
    db: aiosqlite.Connection,
    *,
    type: str,
    summary: str,
    group_id: str,
    actor_id: str | None = None,
    payload: dict[str, Any] | None = None,
) -> None:
    """Best-effort `activity_event` writer for group write-paths (M5 of
    `14_groups_management_page.md`).

    Producer-side errors are swallowed — a missing audit row must never
    break the underlying group operation.  Imports `activity_service`
    lazily to avoid the import cycle that would otherwise form via
    `auth_service.approve_client` → `group_service` → `activity_service`
    → (back to auth or other producers).
    """
    try:
        from services import activity_service  # local import → no cycle
        await activity_service.record(
            db,
            type=type,
            summary=summary,
            target_kind="group",
            target_id=group_id,
            actor_kind="client" if actor_id else "operator",
            actor_id=actor_id,
            payload=payload,
        )
    except Exception as e:  # pragma: no cover — defensive
        logger.warning(
            "Failed to emit group activity event %s for group=%s: %s",
            type, group_id, e,
        )


async def _maybe_emit_failed_burst(
    db: aiosqlite.Connection,
    *,
    client_id: str,
    group_id: str,
    now: datetime,
) -> None:
    """Emit a `group.pin.failed-burst` activity event when the failure
    count for `(client, group)` just crossed `_FAILED_BURST_THRESHOLD`
    inside the 10-min window.  Single emission per burst — subsequent
    failures that bring the count above the threshold do NOT re-emit.

    Mechanism: the failure that triggered this call is already in
    `group_pin_attempts`.  Count failures in the last 10 min — if it
    equals exactly the threshold, the just-recorded failure is the one
    that crossed.  If it's higher, an earlier emission in the same
    burst already fired.  If it's lower, no action.

    A new burst (after the current 10-min window ages out) re-emits
    naturally — old failures fall out of the window, count drops, the
    next 5th failure is again exactly at the threshold.

    Best-effort like other producer calls — errors swallowed so a
    missing audit row never breaks the rate-limit response.
    """
    try:
        cutoff = (
            now - timedelta(seconds=_FAILED_BURST_WINDOW_SEC)
        ).isoformat()
        async with db.execute(
            """
            SELECT COUNT(*) FROM group_pin_attempts
             WHERE client_id = ? AND group_id = ?
               AND success = 0
               AND attempted_at > ?
            """,
            (client_id, group_id, cutoff),
        ) as cur:
            row = await cur.fetchone()
        count = int(row[0]) if row else 0
        if count != _FAILED_BURST_THRESHOLD:
            return  # below threshold or already emitted earlier in burst
        async with db.execute(
            "SELECT name FROM clients WHERE id = ?", (client_id,)
        ) as cur:
            client_row = await cur.fetchone()
        client_name = (
            client_row["name"] if client_row else client_id[:8]
        )
        await _emit_group_activity(
            db,
            type="group.pin.failed-burst",
            summary=(
                f"{_FAILED_BURST_THRESHOLD} failed PIN attempts from "
                f"{client_name} in the last "
                f"{_FAILED_BURST_WINDOW_SEC // 60} min"
            ),
            group_id=group_id,
            actor_id=client_id,
            payload={
                "count": count,
                "window_sec": _FAILED_BURST_WINDOW_SEC,
            },
        )
    except Exception as e:  # pragma: no cover — defensive
        logger.warning(
            "Failed to emit failed-burst activity event "
            "(client=%s group=%s): %s",
            client_id, group_id, e,
        )


async def add_member(db: aiosqlite.Connection, group_id: str, client_id: str) -> bool:
    """Add a client to a group. Returns False if either does not exist."""
    async with db.execute(
        "SELECT id, name FROM groups WHERE id = ?", (group_id,)
    ) as cur:
        group = await cur.fetchone()
    if group is None:
        return False
    async with db.execute(
        "SELECT id, name FROM clients WHERE id = ?", (client_id,)
    ) as cur:
        client = await cur.fetchone()
    if client is None:
        return False
    cursor = await db.execute(
        """
        INSERT OR IGNORE INTO group_members (group_id, client_id, added_at)
        VALUES (?, ?, ?)
        """,
        (group_id, client_id, _now()),
    )
    await db.commit()
    # Emit activity event only when the row actually landed — INSERT OR
    # IGNORE returns rowcount 0 on duplicate (idempotent re-add) and we
    # don't want to flood the operator's audit feed with no-ops.
    if (cursor.rowcount or 0) > 0:
        await _emit_group_activity(
            db,
            type="group.member.add",
            summary=f"{client['name']} added to group {group['name']}",
            group_id=group_id,
            actor_id=client_id,
        )
    return True


async def remove_member(
    db: aiosqlite.Connection, group_id: str, client_id: str
) -> bool:
    # Look up display names BEFORE delete so the activity event has
    # them.  Cheap; only fires when there's something to remove.
    async with db.execute(
        """
        SELECT g.name AS group_name, c.name AS client_name
          FROM group_members m
          JOIN groups  g ON g.id = m.group_id
          JOIN clients c ON c.id = m.client_id
         WHERE m.group_id = ? AND m.client_id = ?
        """,
        (group_id, client_id),
    ) as cur:
        names = await cur.fetchone()
    cursor = await db.execute(
        "DELETE FROM group_members WHERE group_id = ? AND client_id = ?",
        (group_id, client_id),
    )
    await db.commit()
    deleted = cursor.rowcount > 0
    if deleted and names is not None:
        await _emit_group_activity(
            db,
            type="group.member.remove",
            summary=(
                f"{names['client_name']} removed from group "
                f"{names['group_name']}"
            ),
            group_id=group_id,
            actor_id=client_id,
        )
    return deleted


async def set_member_time_window_override(
    db: aiosqlite.Connection,
    group_id: str,
    client_id: str,
    *,
    time_window: dict[str, Any] | None,
) -> bool:
    """Set or clear a per-member time-window override (M5 of
    `14_groups_management_page.md`, plan §6.3 of
    `13_groups_v2_content_spaces.md` — "older kid stays up later" case).

    `time_window=None` clears the override; the member inherits the
    group's window.  Returns False if no membership row exists for
    `(group_id, client_id)` so the router can 404.

    JSON shape mirrors `group_restrictions.time_window`:
        {"start_h": int 0-23, "end_h": int 0-23, "days": [0..6]}
    """
    async with db.execute(
        "SELECT 1 FROM group_members WHERE group_id = ? AND client_id = ?",
        (group_id, client_id),
    ) as cur:
        if await cur.fetchone() is None:
            return False
    encoded = json.dumps(time_window) if time_window is not None else None
    await db.execute(
        """
        UPDATE group_members
           SET time_window_override = ?
         WHERE group_id = ? AND client_id = ?
        """,
        (encoded, group_id, client_id),
    )
    await db.commit()
    return True


async def list_members(
    db: aiosqlite.Connection,
    group_id: str,
    *,
    include_pin_state: bool = False,
    now: datetime | None = None,
) -> list[dict[str, Any]] | None:
    """List members of a group.

    When `include_pin_state=True` (M3 of `14_groups_management_page.md`),
    each row also carries:
      * `enrollment_state` — `'enrolled'` | `'not_enrolled'` | `'not_required'`
        (M8 per-client mode tracks enrollment; shared mode + non-gated
        groups are always `'not_required'`).
      * `has_active_grant` — bool; True if a non-expired
        `group_pin_grants` row exists for this client.
      * `grant_expires_at` — ISO timestamp or null.
      * `recent_failed_attempts` — int; count of `success=0` rows in the
        last 60 s for the rate-limit window.  Lets the desktop UI render
        a "Locked out" badge without a second round-trip.

    Computed in one query via correlated sub-selects.  Avoids the N+1
    fanout the desktop Members tab would otherwise hit (§9.3 of the plan).
    """
    async with db.execute(
        "SELECT id, requires_pin, pin_model FROM groups WHERE id = ?",
        (group_id,),
    ) as cur:
        group = await cur.fetchone()
    if group is None:
        return None

    if not include_pin_state:
        async with db.execute(
            """
            SELECT c.id, c.name, c.platform, c.last_seen, c.is_trusted,
                   c.status, m.added_at
              FROM group_members m
              JOIN clients c ON c.id = m.client_id
             WHERE m.group_id = ?
             ORDER BY m.added_at
            """,
            (group_id,),
        ) as cur:
            rows = await cur.fetchall()
        return [dict(row) for row in rows]

    moment = now or datetime.now(UTC)
    now_iso = moment.isoformat()
    rate_window_iso = (
        moment - timedelta(seconds=_PIN_RATE_WINDOW_SEC)
    ).isoformat()

    async with db.execute(
        """
        SELECT c.id, c.name, c.platform, c.last_seen, c.is_trusted, c.status,
               m.added_at,
               (SELECT 1 FROM group_member_pins gmp
                 WHERE gmp.group_id = ? AND gmp.client_id = c.id
                LIMIT 1)                                AS has_enrollment,
               (SELECT expires_at FROM group_pin_grants gpg
                 WHERE gpg.group_id = ? AND gpg.client_id = c.id
                   AND gpg.expires_at > ?
                LIMIT 1)                                AS grant_expires_at,
               (SELECT COUNT(*) FROM group_pin_attempts gpa
                 WHERE gpa.group_id = ? AND gpa.client_id = c.id
                   AND gpa.success = 0
                   AND gpa.attempted_at > ?)            AS recent_failed_attempts
          FROM group_members m
          JOIN clients c ON c.id = m.client_id
         WHERE m.group_id = ?
         ORDER BY m.added_at
        """,
        (
            group_id, group_id, now_iso, group_id, rate_window_iso, group_id,
        ),
    ) as cur:
        rows = await cur.fetchall()

    requires_pin = bool(group["requires_pin"])
    pin_model = group["pin_model"] or "shared"
    out: list[dict[str, Any]] = []
    for row in rows:
        d = dict(row)
        if not requires_pin:
            enrollment_state = "not_required"
        elif pin_model == "shared":
            enrollment_state = "not_required"
        elif d.get("has_enrollment") is not None:
            enrollment_state = "enrolled"
        else:
            enrollment_state = "not_enrolled"
        out.append(
            {
                **{
                    k: v
                    for k, v in d.items()
                    if k != "has_enrollment"
                },
                "enrollment_state": enrollment_state,
                "has_active_grant": d.get("grant_expires_at") is not None,
                "recent_failed_attempts": int(
                    d.get("recent_failed_attempts") or 0
                ),
            }
        )
    return out


# ── Stream-gate enforcement ────────────────────────────────────────────────


@dataclass(frozen=True)
class EffectiveRestrictions:
    """Combined restrictions across every active group a client belongs to.

    `None` on any field means 'no restriction of this kind applies'.
    """

    allowed_libraries: frozenset[str] | None
    bandwidth_cap_mbps: int | None
    time_windows: tuple[dict[str, Any], ...]  # AND-combined; stream must satisfy each
    max_rating: str | None


async def get_effective_restrictions(
    db: aiosqlite.Connection, client_id: str
) -> EffectiveRestrictions:
    async with db.execute(
        """
        SELECT r.allowed_libraries, r.bandwidth_cap_mbps,
               r.time_window, r.max_rating
          FROM group_members m
          JOIN groups g            ON g.id = m.group_id
          JOIN group_restrictions r ON r.group_id = g.id
         WHERE m.client_id = ? AND g.status = 'active'
        """,
        (client_id,),
    ) as cur:
        rows = await cur.fetchall()

    allowed: frozenset[str] | None = None
    bandwidth: int | None = None
    windows: list[dict[str, Any]] = []
    rating: str | None = None

    for row in rows:
        if row["allowed_libraries"]:
            ids = frozenset(json.loads(row["allowed_libraries"]))
            allowed = ids if allowed is None else allowed & ids
        if row["bandwidth_cap_mbps"] is not None:
            cap = int(row["bandwidth_cap_mbps"])
            bandwidth = cap if bandwidth is None else min(bandwidth, cap)
        if row["time_window"]:
            windows.append(json.loads(row["time_window"]))
        if row["max_rating"]:
            # Advisory only — keep the most recent non-null value. A real
            # ratings ladder would compare them; v1 just records.
            rating = row["max_rating"]

    return EffectiveRestrictions(
        allowed_libraries=allowed,
        bandwidth_cap_mbps=bandwidth,
        time_windows=tuple(windows),
        max_rating=rating,
    )


def _in_window(window: dict[str, Any], now: datetime) -> bool:
    raw_days = window.get("days")
    days = raw_days if raw_days is not None else [0, 1, 2, 3, 4, 5, 6]
    if now.weekday() not in days:
        return False
    start_h = int(window.get("start_h", 0))
    end_h = int(window.get("end_h", 23))
    hour = now.hour
    if start_h == end_h:
        # zero-length window — treat as 'no time allowed'
        return False
    if start_h < end_h:
        return start_h <= hour < end_h
    # wraps midnight
    return hour >= start_h or hour < end_h


def reason_to_deny(
    restrictions: EffectiveRestrictions,
    *,
    library_id: str | None,
    now: datetime | None = None,
) -> str | None:
    """Return None if the stream is allowed, otherwise a short reason string."""
    if (
        restrictions.allowed_libraries is not None
        and library_id is not None
        and library_id not in restrictions.allowed_libraries
    ):
        return "Library not allowed for this client's group(s)"
    if restrictions.time_windows:
        moment = now or datetime.now()
        for window in restrictions.time_windows:
            if not _in_window(window, moment):
                return "Outside the allowed streaming time window"
    return None


# ── v2 — additive content-spaces model ─────────────────────────────────────
#
# Plan: docs/10_planning/13_groups_v2_content_spaces.md.
# These functions ride alongside the v1 ones above; M2 of the v2 plan will
# switch consumers (list endpoints + stream router) over.  v1 stays
# in place until then so the existing stream gate doesn't break.


@dataclass(frozen=True)
class _MembershipState:
    """Per-group state for a client at a given moment.  Internal — fed
    to both `get_visible_libraries` and `reason_to_deny_stream` so the
    walk happens once."""

    group_id: str
    name: str
    is_public: bool
    is_active: bool         # group.status == 'active'
    requires_pin: bool
    pin_model: str          # 'shared' or 'per-client' (M8)
    pin_mode: str           # 'session' or 'per-entry'
    is_enrolled: bool       # per-client mode + enrollment row exists
    is_pin_unlocked: bool   # requires_pin=False, OR a valid grant exists
    in_time_window: bool    # group has no window OR `now` satisfies it
    libraries: frozenset[str]
    icon: str | None
    color: str | None
    grant_expires_at: str | None  # ISO timestamp or None when no grant


@dataclass(frozen=True)
class VisibleLibraries:
    """The set of library ids a client can see right now, with provenance.

    `library_ids` is what list endpoints filter against.
    `groups_contributing` maps each contributing group id -> the libraries
    it granted (used by the desktop "view as" debug + the mobile UI).
    `pin_locked_groups` lists groups the client is a member of but hasn't
    unlocked — populated so the mobile "Unlock libraries" surface knows
    what's hidden.  `enrollment_required_groups` is the M8 sibling: groups
    in `pin_model='per-client'` mode where the client hasn't yet enrolled
    a PIN at all — mobile routes these to the *enrollment* surface, not
    the entry surface.  `time_locked_groups` is the same idea for
    time-window misses; populated so the stream-gate can produce a more
    specific "outside the time window" reason.

    `groups` is a flat list of every group the client is a member of,
    each with the metadata mobile + desktop need for rendering — name,
    icon, color, requires_pin, pin_model, pin_mode, is_active, plus the
    locked-state flags + grant expiry.  Drives the M6 mobile Profile
    cards (visible / locked / unlocked) without a fanout to /groups + N
    × /grant-status.
    """

    library_ids: frozenset[str]
    groups_contributing: dict[str, frozenset[str]] = field(default_factory=dict)
    pin_locked_groups: frozenset[str] = frozenset()
    enrollment_required_groups: frozenset[str] = frozenset()
    time_locked_groups: frozenset[str] = frozenset()
    groups: tuple[dict[str, Any], ...] = ()


async def _resolve_membership(
    db: aiosqlite.Connection,
    client_id: str,
    *,
    now: datetime,
) -> list[_MembershipState]:
    """Walk every group this client belongs to + return per-group state.

    Pure function over DB state at `now`.  Both `get_visible_libraries`
    and `reason_to_deny_stream` consume the result so the SQL walk
    happens once per request.

    Time-window resolution: if the member has a `time_window_override`
    (post-migration-025 column), it wins.  Otherwise the group's own
    `time_window` applies.  Either NULL → no window, always in.
    """
    async with db.execute(
        """
        SELECT g.id            AS group_id,
               g.name          AS name,
               g.is_public     AS is_public,
               g.status        AS status,
               g.requires_pin  AS requires_pin,
               g.pin_model     AS pin_model,
               g.pin_mode      AS pin_mode,
               g.icon          AS icon,
               g.color         AS color,
               r.allowed_libraries        AS allowed_libraries,
               r.time_window              AS time_window,
               m.time_window_override     AS time_window_override,
               (SELECT 1 FROM group_pin_grants gpg
                 WHERE gpg.client_id = m.client_id
                   AND gpg.group_id  = g.id
                   AND gpg.expires_at > ?
                LIMIT 1)                  AS has_grant,
               (SELECT expires_at FROM group_pin_grants gpg
                 WHERE gpg.client_id = m.client_id
                   AND gpg.group_id  = g.id
                   AND gpg.expires_at > ?
                LIMIT 1)                  AS grant_expires_at,
               (SELECT 1 FROM group_member_pins gmp
                 WHERE gmp.client_id = m.client_id
                   AND gmp.group_id  = g.id
                LIMIT 1)                  AS has_enrollment
          FROM group_members m
          JOIN groups g            ON g.id = m.group_id
     LEFT JOIN group_restrictions r ON r.group_id = g.id
         WHERE m.client_id = ?
        """,
        (now.isoformat(), now.isoformat(), client_id),
    ) as cur:
        rows = await cur.fetchall()

    states: list[_MembershipState] = []
    for row in rows:
        # Library set: empty when no restrictions row, or when
        # allowed_libraries is NULL/empty JSON.  Public on a fresh install
        # falls into the empty-set case until the operator adds libraries.
        libs: frozenset[str] = frozenset()
        if row["allowed_libraries"]:
            try:
                parsed = json.loads(row["allowed_libraries"])
                if isinstance(parsed, list):
                    libs = frozenset(str(x) for x in parsed)
            except (json.JSONDecodeError, ValueError):
                logger.warning(
                    "Malformed allowed_libraries for group %s — "
                    "treating as empty set",
                    row["group_id"],
                )

        # Time window: per-member override wins when present.  Both stored
        # as JSON dicts of {start_h, end_h, days[]}.
        window_json = row["time_window_override"] or row["time_window"]
        in_window = True
        if window_json:
            try:
                window = json.loads(window_json)
                in_window = _in_window(window, now)
            except (json.JSONDecodeError, ValueError):
                logger.warning(
                    "Malformed time_window for group %s — "
                    "treating as always-in",
                    row["group_id"],
                )

        states.append(
            _MembershipState(
                group_id=row["group_id"],
                name=row["name"],
                is_public=bool(row["is_public"]),
                is_active=row["status"] == "active",
                requires_pin=bool(row["requires_pin"]),
                pin_model=row["pin_model"] or "shared",
                pin_mode=row["pin_mode"] or "session",
                is_enrolled=row["has_enrollment"] is not None,
                # PIN-unlocked when group doesn't require a PIN, OR a valid
                # grant row exists (the subquery returned 1).  The Public
                # group never requires a PIN by convention but the schema
                # allows it; we honour whatever is set.
                is_pin_unlocked=(
                    not bool(row["requires_pin"])
                    or row["has_grant"] is not None
                ),
                in_time_window=in_window,
                libraries=libs,
                icon=row["icon"],
                color=row["color"],
                grant_expires_at=row["grant_expires_at"],
            )
        )
    return states


async def get_visible_libraries(
    db: aiosqlite.Connection,
    client_id: str,
    *,
    now: datetime | None = None,
) -> VisibleLibraries:
    """Resolve the visible-libraries set for a client at `now`.

    For each group the client belongs to:
      * Skip if the group is inactive (status != 'active').
      * Skip if the group's time window is closed right now (record in
        time_locked_groups so stream-gate denial messages can be specific).
      * Skip if the group requires a PIN and the client has no valid
        grant (record in pin_locked_groups for the unlock UI).
      * Otherwise UNION the group's libraries into the visible set.

    The Public group is just another row in the walk — its membership is
    guaranteed by `auth_service.approve_client` post-M3 + the
    migration-025 backfill, so every paired client gets at least Public's
    libraries (which the operator configures separately).
    """
    moment = now or datetime.now(UTC)
    memberships = await _resolve_membership(db, client_id, now=moment)

    visible: set[str] = set()
    contributing: dict[str, frozenset[str]] = {}
    pin_locked: set[str] = set()
    enrollment_required: set[str] = set()
    time_locked: set[str] = set()
    groups_meta: list[dict[str, Any]] = []

    for m in memberships:
        # Build the per-group metadata first — included regardless of
        # active / locked / time-window state so the mobile UI can
        # render "Inactive" group rows + "outside the time window"
        # badges + "lock" buttons on already-unlocked groups.
        groups_meta.append({
            "id": m.group_id,
            "name": m.name,
            "icon": m.icon,
            "color": m.color,
            "is_public": m.is_public,
            "is_active": m.is_active,
            "requires_pin": m.requires_pin,
            "pin_model": m.pin_model,
            "pin_mode": m.pin_mode,
            "is_enrolled": m.is_enrolled,
            "in_time_window": m.in_time_window,
            "is_unlocked": m.is_pin_unlocked,
            "grant_expires_at": m.grant_expires_at,
        })
        if not m.is_active:
            continue
        if not m.in_time_window:
            time_locked.add(m.group_id)
            continue
        if not m.is_pin_unlocked:
            # Per-client mode + no enrollment yet → route to enrollment
            # surface, not the entry surface.  Mobile shows "Set up a PIN"
            # CTA instead of "Enter PIN".
            if (
                m.requires_pin
                and m.pin_model == "per-client"
                and not m.is_enrolled
            ):
                enrollment_required.add(m.group_id)
            else:
                pin_locked.add(m.group_id)
            continue
        if m.libraries:
            visible.update(m.libraries)
            contributing[m.group_id] = m.libraries

    return VisibleLibraries(
        library_ids=frozenset(visible),
        groups_contributing=contributing,
        pin_locked_groups=frozenset(pin_locked),
        enrollment_required_groups=frozenset(enrollment_required),
        time_locked_groups=frozenset(time_locked),
        groups=tuple(groups_meta),
    )


async def reason_to_deny_stream(
    db: aiosqlite.Connection,
    client_id: str,
    *,
    library_id: str | None,
    now: datetime | None = None,
) -> str | None:
    """v2 stream-gate.  Return None if the stream is allowed, else a short
    reason string in the M5 mobile parser's vocabulary:
        - "Outside the allowed streaming time window"
        - "Library not allowed for this client's group(s)"

    Reason selection prefers the *most informative* explanation:
      * If at least one group exposes the library but is currently
        time-locked → time-window message (kid sees "Outside playback
        hours" via M5).
      * Otherwise → library-not-allowed message (kid sees "Not in your
        library access").  This is also the response when a PIN-gated
        group exposes the library — we don't leak the existence of
        gated content via a different message.

    Allowed when ANY active + in-window + pin-unlocked group exposes the
    library_id.  Library list filtering (M2) ensures mobile rarely
    triggers this denial path; it fires when mobile holds a stale
    file_id from before the gate changed.
    """
    if library_id is None:
        return None

    moment = now or datetime.now(UTC)
    memberships = await _resolve_membership(db, client_id, now=moment)

    library_in_time_locked = False
    for m in memberships:
        if not m.is_active:
            continue
        if library_id not in m.libraries:
            continue
        if not m.in_time_window:
            library_in_time_locked = True
            continue
        if not m.is_pin_unlocked:
            # Library exists in a gated group.  Treat as not-allowed
            # rather than time-locked so we don't leak that gated content
            # exists.  Operator's PIN UX handles the unlock path.
            continue
        # Found an active, in-window, unlocked group exposing this library.
        return None

    if library_in_time_locked:
        return "Outside the allowed streaming time window"
    return "Library not allowed for this client's group(s)"


# ── PIN flow (server side of M4) ───────────────────────────────────────────


def hash_pin(pin: str, hmac_key: str) -> str:
    """HMAC-SHA256 the PIN with the server's HMAC key.  Same algorithm the
    bearer-token store uses (see `auth_service`); rotates with the operator's
    key-rotation discipline."""
    return hmac.new(
        hmac_key.encode("utf-8"),
        pin.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def validate_pin_strength(pin: str) -> str | None:
    """Return None if the PIN passes the strength policy, else a reason
    string.  Server enforces; desktop CP can mirror the rules client-side
    for snappy feedback but the server is authoritative."""
    if not pin.isdigit():
        return "PIN must be numeric"
    if len(pin) < 4 or len(pin) > 8:
        return "PIN must be 4-8 digits"
    if pin in _OBVIOUS_PINS:
        return "PIN is too obvious — try something less guessable"
    return None


async def _recent_failed_attempts(
    db: aiosqlite.Connection,
    client_id: str,
    group_id: str,
    *,
    window_sec: int = _PIN_RATE_WINDOW_SEC,
    now: datetime,
) -> int:
    """Count failed PIN attempts for (client, group) in the last
    `window_sec` seconds.  Used by the rate limiter."""
    cutoff = (now - timedelta(seconds=window_sec)).isoformat()
    async with db.execute(
        """
        SELECT COUNT(*) FROM group_pin_attempts
         WHERE client_id = ? AND group_id = ?
           AND success = 0
           AND attempted_at > ?
        """,
        (client_id, group_id, cutoff),
    ) as cur:
        row = await cur.fetchone()
    return int(row[0]) if row else 0


@dataclass(frozen=True)
class PinGrantResult:
    """Outcome of an `enter_pin_grant` call.  `granted` is the happy
    path; `error` carries one of:
      - 'rate_limited'   : too many recent failed attempts; retry later
      - 'incorrect_pin'  : PIN didn't match
      - 'no_pin_required': the group isn't PIN-gated
      - 'unknown_group'  : group_id doesn't exist
    """

    granted: bool
    expires_at: str | None = None
    error: str | None = None
    attempts_remaining: int | None = None


async def enter_pin_grant(
    db: aiosqlite.Connection,
    client_id: str,
    group_id: str,
    pin: str,
    *,
    hmac_key: str,
    now: datetime | None = None,
) -> PinGrantResult:
    """Validate the PIN, log the attempt, insert a grant on success.

    Server returns `rate_limited` after 5 failed attempts within 60 s
    (operator can still recover via the master-override path on
    localhost — that bypasses this rate limit).
    """
    moment = now or datetime.now(UTC)

    # Group lookup first — cheap; lets us return a clean "unknown_group"
    # error before we charge an attempt against the rate limit.
    async with db.execute(
        """
        SELECT requires_pin, pin_hash, pin_mode, pin_model
          FROM groups WHERE id = ?
        """,
        (group_id,),
    ) as cur:
        group = await cur.fetchone()
    if group is None:
        return PinGrantResult(granted=False, error="unknown_group")
    if not group["requires_pin"]:
        return PinGrantResult(granted=False, error="no_pin_required")

    # Rate limit check.
    fails = await _recent_failed_attempts(
        db, client_id, group_id, now=moment
    )
    if fails >= _PIN_RATE_MAX_FAILS:
        return PinGrantResult(
            granted=False,
            error="rate_limited",
            attempts_remaining=0,
        )

    # M8: per-client mode reads the calling client's enrollment row, not
    # the group's shared hash.  Missing enrollment in per-client mode
    # surfaces as `enrollment_required` so the mobile UI can route the
    # user to the enrollment surface instead of the entry surface.
    pin_model = group["pin_model"] or "shared"
    if pin_model == "per-client":
        async with db.execute(
            """
            SELECT pin_hash FROM group_member_pins
             WHERE group_id = ? AND client_id = ?
            """,
            (group_id, client_id),
        ) as cur:
            enroll_row = await cur.fetchone()
        if enroll_row is None:
            return PinGrantResult(
                granted=False, error="enrollment_required"
            )
        expected = enroll_row["pin_hash"]
    else:
        expected = group["pin_hash"]

    actual = hash_pin(pin, hmac_key)
    success = (
        expected is not None
        and hmac.compare_digest(expected, actual)
    )

    # Log every attempt — the brute-force ledger is the rate limiter's
    # source of truth; success rows are kept for audit (operator can see
    # "kid unlocked Adults at 22:30" in the activity feed).
    await db.execute(
        """
        INSERT INTO group_pin_attempts
            (client_id, group_id, attempted_at, success)
        VALUES (?, ?, ?, ?)
        """,
        (client_id, group_id, moment.isoformat(), 1 if success else 0),
    )

    if not success:
        await db.commit()
        # Activity-feed aggregation — fire one burst event when the
        # 10-min window count just crossed the threshold.  Rate limit
        # uses a 60-s window for lockout; this 10-min window catches
        # bursts that drip-feed across multiple lockouts.
        await _maybe_emit_failed_burst(
            db, client_id=client_id, group_id=group_id, now=moment,
        )
        return PinGrantResult(
            granted=False,
            error="incorrect_pin",
            attempts_remaining=max(
                0, _PIN_RATE_MAX_FAILS - (fails + 1)
            ),
        )

    # Grant TTL by mode.
    ttl = (
        _GRANT_TTL_PER_ENTRY
        if group["pin_mode"] == "per-entry"
        else _GRANT_TTL_SESSION
    )
    expires_at = moment + ttl
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
            moment.isoformat(),
            expires_at.isoformat(),
        ),
    )
    await db.commit()
    logger.info(
        "PIN grant issued: client=%s group=%s expires=%s",
        client_id,
        group_id,
        expires_at.isoformat(),
    )
    await _emit_group_activity(
        db,
        type="group.pin.unlock",
        summary=(
            f"PIN unlocked (expires {expires_at.isoformat(timespec='seconds')})"
        ),
        group_id=group_id,
        actor_id=client_id,
    )
    return PinGrantResult(
        granted=True,
        expires_at=expires_at.isoformat(),
    )


async def revoke_all_grants_for_group(
    db: aiosqlite.Connection, group_id: str
) -> int:
    """Bulk-drop every active PIN grant for a group.  Operator-side
    "Reset all PINs" action — `clear_member_pin` per member is the
    per-client recovery path; this is the shared-mode equivalent.

    Returns the count of rows deleted (drives the operator snackbar
    "Cleared N grants" feedback).  Idempotent — calling on a group
    with no active grants returns 0.

    Does NOT touch `group_member_pins` (per-client enrollments) — the
    operator's intent here is "force everyone to re-enter the shared
    PIN," not "blow away the per-client setup."  For per-client mode
    use `clear_member_pin` per row instead.

    Emits one `group.pin.grants-reset` activity event with the count
    so the operator audit feed shows the bulk action.
    """
    cursor = await db.execute(
        "DELETE FROM group_pin_grants WHERE group_id = ?",
        (group_id,),
    )
    await db.commit()
    deleted = cursor.rowcount or 0
    if deleted > 0:
        logger.info(
            "Bulk grant reset on group=%s — %d grant(s) dropped",
            group_id, deleted,
        )
        await _emit_group_activity(
            db,
            type="group.pin.grants-reset",
            summary=(
                f"Operator reset all PIN grants ({deleted} dropped); "
                f"members re-enter on next access"
            ),
            group_id=group_id,
            payload={"count": deleted},
        )
    return deleted


async def revoke_pin_grant(
    db: aiosqlite.Connection, client_id: str, group_id: str
) -> bool:
    """Drop a client's grant for a group.  Returns True iff a row was
    actually deleted.  Mobile lock buttons + operator master override
    (delete-someone-else's-grant from the desktop CP) both call this."""
    cursor = await db.execute(
        """
        DELETE FROM group_pin_grants
         WHERE client_id = ? AND group_id = ?
        """,
        (client_id, group_id),
    )
    await db.commit()
    deleted = (cursor.rowcount or 0) > 0
    if deleted:
        logger.info("PIN grant revoked: client=%s group=%s", client_id, group_id)
    return deleted


async def housekeep_pin_state(db: aiosqlite.Connection) -> tuple[int, int]:
    """Prune expired grants + 24-hour-old attempt rows.  Called from
    the existing startup background task in main.py.  Returns
    `(grants_pruned, attempts_pruned)` for the log line."""
    now = datetime.now(UTC)

    grant_cur = await db.execute(
        "DELETE FROM group_pin_grants WHERE expires_at <= ?",
        (now.isoformat(),),
    )
    grants_pruned = grant_cur.rowcount or 0

    attempt_cutoff = (now - timedelta(hours=24)).isoformat()
    attempt_cur = await db.execute(
        "DELETE FROM group_pin_attempts WHERE attempted_at < ?",
        (attempt_cutoff,),
    )
    attempts_pruned = attempt_cur.rowcount or 0

    await db.commit()
    if grants_pruned or attempts_pruned:
        logger.info(
            "Pruned %d expired grants, %d old attempts",
            grants_pruned,
            attempts_pruned,
        )
    return grants_pruned, attempts_pruned


# ── Per-client PIN enrollment (M8 — hybrid PIN model) ──────────────────────


async def enroll_pin(
    db: aiosqlite.Connection,
    client_id: str,
    group_id: str,
    pin: str,
    *,
    hmac_key: str,
    now: datetime | None = None,
) -> PinGrantResult:
    """First-time per-client PIN enrollment for a per-client-mode group.

    Validates the PIN, writes the enrollment row, and immediately issues
    a session-length grant (the user just typed the PIN — no need to
    re-enter it on the same flow).

    Errors mirror `enter_pin_grant` so the route layer can re-use the
    same translation table:
      * 'unknown_group'        — group_id doesn't exist
      * 'no_pin_required'      — group is not gated
      * 'wrong_mode'           — group is in shared-PIN mode (use /enter)
      * 'not_a_member'         — calling client isn't a member of the group
      * 'already_enrolled'     — enrollment row exists; use change endpoint
      * '<strength reason>'    — PIN strength policy violated
    """
    moment = now or datetime.now(UTC)

    strength_err = validate_pin_strength(pin)
    if strength_err is not None:
        return PinGrantResult(granted=False, error=strength_err)

    async with db.execute(
        "SELECT requires_pin, pin_mode, pin_model FROM groups WHERE id = ?",
        (group_id,),
    ) as cur:
        group = await cur.fetchone()
    if group is None:
        return PinGrantResult(granted=False, error="unknown_group")
    if not group["requires_pin"]:
        return PinGrantResult(granted=False, error="no_pin_required")
    if (group["pin_model"] or "shared") != "per-client":
        return PinGrantResult(granted=False, error="wrong_mode")

    async with db.execute(
        "SELECT 1 FROM group_members WHERE group_id = ? AND client_id = ?",
        (group_id, client_id),
    ) as cur:
        member = await cur.fetchone()
    if member is None:
        return PinGrantResult(granted=False, error="not_a_member")

    async with db.execute(
        "SELECT 1 FROM group_member_pins WHERE group_id = ? AND client_id = ?",
        (group_id, client_id),
    ) as cur:
        existing = await cur.fetchone()
    if existing is not None:
        return PinGrantResult(granted=False, error="already_enrolled")

    new_hash = hash_pin(pin, hmac_key)
    await db.execute(
        """
        INSERT INTO group_member_pins
            (group_id, client_id, pin_hash, enrolled_at)
        VALUES (?, ?, ?, ?)
        """,
        (group_id, client_id, new_hash, moment.isoformat()),
    )

    # Issue an immediate session-length grant — the user just authenticated
    # by typing the PIN.  Per-entry mode still gets session-length on
    # enrollment because the alternative (5 min then re-prompt) is hostile
    # right after a fresh enrollment.
    expires_at = moment + _GRANT_TTL_SESSION
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
            moment.isoformat(),
            expires_at.isoformat(),
        ),
    )
    await db.execute(
        """
        INSERT INTO group_pin_attempts
            (client_id, group_id, attempted_at, success)
        VALUES (?, ?, ?, 1)
        """,
        (client_id, group_id, moment.isoformat()),
    )
    await db.commit()
    logger.info(
        "PIN enrolled (per-client): client=%s group=%s",
        client_id, group_id,
    )
    return PinGrantResult(
        granted=True,
        expires_at=expires_at.isoformat(),
    )


async def change_member_pin(
    db: aiosqlite.Connection,
    client_id: str,
    group_id: str,
    old_pin: str,
    new_pin: str,
    *,
    hmac_key: str,
    now: datetime | None = None,
) -> PinGrantResult:
    """Replace a per-client enrolled PIN.  Verifies `old_pin` first; on
    mismatch records a failed attempt against the rate limit so this
    endpoint can't be used to brute-force the existing PIN.

    Errors:
      * 'unknown_group'   — group doesn't exist
      * 'wrong_mode'      — group is shared-PIN (no per-client PIN to change)
      * 'not_enrolled'    — no enrollment row yet (use enroll endpoint)
      * 'rate_limited'    — too many recent failed attempts
      * 'incorrect_pin'   — old_pin didn't match
      * '<strength reason>' — new_pin policy violated
    """
    moment = now or datetime.now(UTC)

    strength_err = validate_pin_strength(new_pin)
    if strength_err is not None:
        return PinGrantResult(granted=False, error=strength_err)

    async with db.execute(
        "SELECT requires_pin, pin_model FROM groups WHERE id = ?",
        (group_id,),
    ) as cur:
        group = await cur.fetchone()
    if group is None:
        return PinGrantResult(granted=False, error="unknown_group")
    if (group["pin_model"] or "shared") != "per-client":
        return PinGrantResult(granted=False, error="wrong_mode")

    async with db.execute(
        "SELECT pin_hash FROM group_member_pins "
        "WHERE group_id = ? AND client_id = ?",
        (group_id, client_id),
    ) as cur:
        enroll_row = await cur.fetchone()
    if enroll_row is None:
        return PinGrantResult(granted=False, error="not_enrolled")

    fails = await _recent_failed_attempts(
        db, client_id, group_id, now=moment
    )
    if fails >= _PIN_RATE_MAX_FAILS:
        return PinGrantResult(
            granted=False, error="rate_limited", attempts_remaining=0
        )

    if not hmac.compare_digest(
        enroll_row["pin_hash"], hash_pin(old_pin, hmac_key)
    ):
        await db.execute(
            """
            INSERT INTO group_pin_attempts
                (client_id, group_id, attempted_at, success)
            VALUES (?, ?, ?, 0)
            """,
            (client_id, group_id, moment.isoformat()),
        )
        await db.commit()
        # Same activity-feed aggregation as `enter_pin_grant` so a
        # brute-force-via-change attempt also surfaces in the audit feed.
        await _maybe_emit_failed_burst(
            db, client_id=client_id, group_id=group_id, now=moment,
        )
        return PinGrantResult(
            granted=False,
            error="incorrect_pin",
            attempts_remaining=max(
                0, _PIN_RATE_MAX_FAILS - (fails + 1)
            ),
        )

    new_hash = hash_pin(new_pin, hmac_key)
    await db.execute(
        """
        UPDATE group_member_pins
           SET pin_hash = ?, enrolled_at = ?
         WHERE group_id = ? AND client_id = ?
        """,
        (new_hash, moment.isoformat(), group_id, client_id),
    )
    # Existing grant carries; the user already authenticated successfully.
    await db.commit()
    logger.info(
        "PIN changed (per-client): client=%s group=%s",
        client_id, group_id,
    )
    return PinGrantResult(granted=True)


async def clear_member_pin(
    db: aiosqlite.Connection,
    client_id: str,
    group_id: str,
) -> bool:
    """Operator action — drop a member's enrollment so they re-enroll on
    next access.  Also drops their grant for the group so visibility
    flips immediately.  Returns True iff an enrollment row was actually
    deleted (router can return 404 on False)."""
    cursor = await db.execute(
        """
        DELETE FROM group_member_pins
         WHERE group_id = ? AND client_id = ?
        """,
        (group_id, client_id),
    )
    deleted = (cursor.rowcount or 0) > 0
    # Always drop any active grant — the operator's intent is "this
    # device must re-authenticate," and the grant would otherwise mask
    # the cleared enrollment.
    await db.execute(
        """
        DELETE FROM group_pin_grants
         WHERE group_id = ? AND client_id = ?
        """,
        (group_id, client_id),
    )
    await db.commit()
    if deleted:
        logger.info(
            "Per-client PIN cleared by operator: client=%s group=%s",
            client_id, group_id,
        )
        await _emit_group_activity(
            db,
            type="group.pin.cleared",
            summary="Operator cleared per-client PIN; member must re-enroll",
            group_id=group_id,
            actor_id=client_id,
        )
    return deleted
