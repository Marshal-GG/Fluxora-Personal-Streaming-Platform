"""Client-group CRUD + stream-gate enforcement.

Groups bundle clients together and apply shared restrictions:
- `allowed_libraries`: only these library ids may be streamed
- `time_window`: streams only allowed within this daily window
- `bandwidth_cap_mbps`: throughput cap (advisory in v1 — recorded but not
  yet enforced inside the FFmpeg session)
- `max_rating`: content-rating ceiling (advisory in v1 — `media_files` does
  not yet carry a rating column)

A client can belong to multiple groups. The effective restriction is the
intersection (most restrictive) of every active group the client is in:
- library lists intersect
- time windows intersect (a stream must be inside *every* group's window)
- bandwidth caps take the minimum
- max ratings take the lowest
"""

from __future__ import annotations

import json
import logging
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import aiosqlite

logger = logging.getLogger(__name__)


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
    return {
        "id": group_row["id"],
        "name": group_row["name"],
        "description": group_row["description"],
        "status": group_row["status"],
        "created_at": group_row["created_at"],
        "updated_at": group_row["updated_at"],
        "member_count": member_count,
        "restrictions": _decode_restrictions(rest_row),
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
) -> dict[str, Any]:
    group_id = str(uuid.uuid4())
    now = _now()
    await db.execute(
        """
        INSERT INTO groups (id, name, description, status, created_at, updated_at)
        VALUES (?, ?, ?, 'active', ?, ?)
        """,
        (group_id, name, description, now, now),
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
    logger.info("Group created: %s (%s)", name, group_id)

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
) -> dict[str, Any] | None:
    existing = await get_group(db, group_id)
    if existing is None:
        return None

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


async def add_member(db: aiosqlite.Connection, group_id: str, client_id: str) -> bool:
    """Add a client to a group. Returns False if either does not exist."""
    async with db.execute("SELECT id FROM groups WHERE id = ?", (group_id,)) as cur:
        if await cur.fetchone() is None:
            return False
    async with db.execute("SELECT id FROM clients WHERE id = ?", (client_id,)) as cur:
        if await cur.fetchone() is None:
            return False
    await db.execute(
        """
        INSERT OR IGNORE INTO group_members (group_id, client_id, added_at)
        VALUES (?, ?, ?)
        """,
        (group_id, client_id, _now()),
    )
    await db.commit()
    return True


async def remove_member(
    db: aiosqlite.Connection, group_id: str, client_id: str
) -> bool:
    cursor = await db.execute(
        "DELETE FROM group_members WHERE group_id = ? AND client_id = ?",
        (group_id, client_id),
    )
    await db.commit()
    return cursor.rowcount > 0


async def list_members(
    db: aiosqlite.Connection, group_id: str
) -> list[dict[str, Any]] | None:
    async with db.execute("SELECT id FROM groups WHERE id = ?", (group_id,)) as cur:
        if await cur.fetchone() is None:
            return None
    async with db.execute(
        """
        SELECT c.id, c.name, c.platform, c.last_seen, c.is_trusted, c.status,
               m.added_at
          FROM group_members m
          JOIN clients c ON c.id = m.client_id
         WHERE m.group_id = ?
         ORDER BY m.added_at
        """,
        (group_id,),
    ) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


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
