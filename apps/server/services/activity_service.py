"""Append-only activity event log.

Producer services (auth, stream, files, library) call `record()` after a
noteworthy action completes. The router exposes `list_events()` for the
desktop Activity screen and `?limit=4` is what the Dashboard widget uses.

Event-type naming convention: `<domain>.<verb>` (e.g. `stream.start`,
`client.pair`, `file.upload`). Keep verbs in past tense in `summary`.

This service has no pub/sub — the desktop polls. If a future revision
needs live updates, mirror the notification_service queue pattern.
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import UTC, datetime
from typing import Any

import aiosqlite

logger = logging.getLogger(__name__)


def _row_to_dict(row: aiosqlite.Row) -> dict[str, Any]:
    payload_raw = row["payload"]
    payload: dict[str, Any] | None = None
    if payload_raw:
        try:
            payload = json.loads(payload_raw)
        except (ValueError, TypeError):
            logger.warning(
                "Activity event %s has invalid JSON payload; returning null",
                row["id"],
            )
    return {
        "id": row["id"],
        "type": row["type"],
        "actor_kind": row["actor_kind"],
        "actor_id": row["actor_id"],
        "target_kind": row["target_kind"],
        "target_id": row["target_id"],
        "summary": row["summary"],
        "payload": payload,
        "created_at": row["created_at"],
    }


async def record(
    db: aiosqlite.Connection,
    *,
    type: str,
    summary: str,
    actor_kind: str | None = None,
    actor_id: str | None = None,
    target_kind: str | None = None,
    target_id: str | None = None,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Insert one event. Producer-side errors must be swallowed by callers
    so a missing audit row never breaks the underlying flow.
    """
    event_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    payload_json = json.dumps(payload) if payload is not None else None
    await db.execute(
        """
        INSERT INTO activity_events
            (id, type, actor_kind, actor_id,
             target_kind, target_id, summary, payload, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            event_id,
            type,
            actor_kind,
            actor_id,
            target_kind,
            target_id,
            summary,
            payload_json,
            now,
        ),
    )
    await db.commit()
    return {
        "id": event_id,
        "type": type,
        "actor_kind": actor_kind,
        "actor_id": actor_id,
        "target_kind": target_kind,
        "target_id": target_id,
        "summary": summary,
        "payload": payload,
        "created_at": now,
    }


async def list_events(
    db: aiosqlite.Connection,
    *,
    limit: int = 50,
    since: str | None = None,
    type_prefix: str | None = None,
) -> list[dict[str, Any]]:
    """Most-recent-first list, optionally filtered.

    `since` accepts an ISO-8601 timestamp; only events with
    `created_at > since` are returned. `type_prefix` filters by event-type
    prefix (e.g. `'stream.'` matches stream.start + stream.end).
    """
    where: list[str] = []
    params: list[Any] = []
    if since is not None:
        where.append("created_at > ?")
        params.append(since)
    if type_prefix is not None:
        where.append("type LIKE ?")
        params.append(f"{type_prefix}%")
    where_sql = ("WHERE " + " AND ".join(where)) if where else ""

    sql = f"""
        SELECT * FROM activity_events
        {where_sql}
        ORDER BY created_at DESC
        LIMIT ?
    """
    params.append(limit)
    async with db.execute(sql, tuple(params)) as cur:
        rows = await cur.fetchall()
    return [_row_to_dict(row) for row in rows]
