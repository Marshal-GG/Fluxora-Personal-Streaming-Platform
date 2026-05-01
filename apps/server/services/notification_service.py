"""In-app notification CRUD + WebSocket fan-out.

Notifications are produced by other services (auth, license, ffmpeg,
library) when a noteworthy event happens. They are persisted in the
`notifications` table and pushed live to any WS subscribers via a
process-local pub/sub.

Lifecycle:
- `create()` inserts a row, then fan-outs to every subscriber's queue.
- WS clients call `subscribe()` to get an asyncio.Queue, drain it in a
  loop, and call `unsubscribe()` on disconnect.
- Slow consumers drop frames (queue full → silent skip) rather than
  blocking the producer.

The pub/sub is in-process only — fine for a single-server install.
A clustered deployment would need Redis pub/sub or similar.
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import UTC, datetime
from typing import Any

import aiosqlite

logger = logging.getLogger(__name__)

# ── pub/sub ────────────────────────────────────────────────────────────────

_subscribers: set[asyncio.Queue[dict[str, Any]]] = set()
_QUEUE_MAX = 100


def subscribe() -> asyncio.Queue[dict[str, Any]]:
    """Register a new WS consumer; returns its frame queue."""
    q: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=_QUEUE_MAX)
    _subscribers.add(q)
    return q


def unsubscribe(q: asyncio.Queue[dict[str, Any]]) -> None:
    _subscribers.discard(q)


def _broadcast(payload: dict[str, Any]) -> None:
    for q in list(_subscribers):
        try:
            q.put_nowait(payload)
        except asyncio.QueueFull:
            logger.warning("Notification queue full; dropping frame for one subscriber")


# ── helpers ────────────────────────────────────────────────────────────────


def _row_to_dict(row: aiosqlite.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "type": row["type"],
        "category": row["category"],
        "title": row["title"],
        "message": row["message"],
        "related_kind": row["related_kind"],
        "related_id": row["related_id"],
        "created_at": row["created_at"],
        "read_at": row["read_at"],
        "dismissed_at": row["dismissed_at"],
    }


# ── CRUD ───────────────────────────────────────────────────────────────────


async def create(
    db: aiosqlite.Connection,
    *,
    type: str,
    category: str,
    title: str,
    message: str,
    related_kind: str | None = None,
    related_id: str | None = None,
) -> dict[str, Any]:
    notif_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await db.execute(
        """
        INSERT INTO notifications
            (id, type, category, title, message,
             related_kind, related_id, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (notif_id, type, category, title, message, related_kind, related_id, now),
    )
    await db.commit()

    payload = {
        "id": notif_id,
        "type": type,
        "category": category,
        "title": title,
        "message": message,
        "related_kind": related_kind,
        "related_id": related_id,
        "created_at": now,
        "read_at": None,
        "dismissed_at": None,
    }
    _broadcast({"type": "notification", "data": payload})
    logger.info(
        "Notification created: category=%s type=%s id=%s",
        category,
        type,
        notif_id,
    )
    return payload


async def list_notifications(
    db: aiosqlite.Connection,
    *,
    only_unread: bool = False,
    limit: int = 50,
) -> list[dict[str, Any]]:
    if only_unread:
        sql = """
            SELECT * FROM notifications
             WHERE dismissed_at IS NULL AND read_at IS NULL
             ORDER BY created_at DESC
             LIMIT ?
        """
    else:
        sql = """
            SELECT * FROM notifications
             WHERE dismissed_at IS NULL
             ORDER BY created_at DESC
             LIMIT ?
        """
    async with db.execute(sql, (limit,)) as cur:
        rows = await cur.fetchall()
    return [_row_to_dict(row) for row in rows]


async def mark_read(db: aiosqlite.Connection, notif_id: str) -> bool:
    now = datetime.now(UTC).isoformat()
    cursor = await db.execute(
        """
        UPDATE notifications
           SET read_at = ?
         WHERE id = ? AND read_at IS NULL AND dismissed_at IS NULL
        """,
        (now, notif_id),
    )
    await db.commit()
    return cursor.rowcount > 0


async def mark_all_read(db: aiosqlite.Connection) -> int:
    now = datetime.now(UTC).isoformat()
    cursor = await db.execute(
        """
        UPDATE notifications
           SET read_at = ?
         WHERE read_at IS NULL AND dismissed_at IS NULL
        """,
        (now,),
    )
    await db.commit()
    return cursor.rowcount


async def dismiss(db: aiosqlite.Connection, notif_id: str) -> bool:
    now = datetime.now(UTC).isoformat()
    cursor = await db.execute(
        """
        UPDATE notifications
           SET dismissed_at = ?
         WHERE id = ? AND dismissed_at IS NULL
        """,
        (now, notif_id),
    )
    await db.commit()
    return cursor.rowcount > 0
