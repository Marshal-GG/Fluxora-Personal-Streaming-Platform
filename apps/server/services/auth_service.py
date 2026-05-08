import hashlib
import hmac
import logging
import secrets
from datetime import UTC, datetime

import aiosqlite

from services import activity_service, notification_service

logger = logging.getLogger(__name__)


# In-memory store for raw tokens awaiting first /auth/status poll.
#
# Lives in the service layer (not the router) so that create_pair_request can
# clear the entry when a previously-approved client re-pairs from the same
# client_id — otherwise an attacker who held the old raw token could pop it
# off the queue between the operator approving and the legitimate device
# polling.  The hash in the DB is already invalidated by the re-pair flow;
# clearing this dict makes the raw token unrecoverable too.
_pending_tokens: dict[str, str] = {}


def store_pending_token(client_id: str, raw_token: str) -> None:
    _pending_tokens[client_id] = raw_token


def consume_pending_token(client_id: str) -> str | None:
    return _pending_tokens.pop(client_id, None)


def clear_pending_token(client_id: str) -> None:
    _pending_tokens.pop(client_id, None)


def generate_token() -> str:
    return secrets.token_urlsafe(32)


def hash_token(token: str, secret_key: str) -> str:
    return hmac.new(secret_key.encode(), token.encode(), hashlib.sha256).hexdigest()


def verify_token(provided_token: str, stored_hash: str, secret_key: str) -> bool:
    expected = hash_token(provided_token, secret_key)
    return hmac.compare_digest(expected, stored_hash)


async def create_pair_request(
    db: aiosqlite.Connection,
    client_id: str,
    device_name: str,
    platform: str,
    app_version: str,
    email: str | None = None,
    client_ip: str | None = None,
) -> None:
    """Insert a fresh pending pair request, or reset an existing client.

    Same-client_id re-pair semantics (Phase A backfill plan §8.5 bug 1):
    if a row with this client_id already exists in any status, the row is
    reset to `status = 'pending'` with `is_trusted = 0` and a cleared
    `auth_token` so the previously-issued bearer is dead the instant the
    request lands. Any in-memory pending raw token for this client_id is
    dropped too.

    `client_ip` is captured from the request socket and persisted to
    `clients.last_ip` (nullable). On re-pair from a new network the
    column is overwritten so the desktop UI always reflects the current
    network the device is reaching the server from.
    """
    now = datetime.now(UTC).isoformat()
    await db.execute(
        """
        INSERT INTO clients (
            id, name, platform, last_seen, is_trusted, auth_token, status,
            email, paired_at, last_ip
        ) VALUES (?, ?, ?, ?, 0, '', 'pending', ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name       = excluded.name,
            platform   = excluded.platform,
            last_seen  = excluded.last_seen,
            email      = COALESCE(excluded.email, clients.email),
            last_ip    = COALESCE(excluded.last_ip, clients.last_ip),
            is_trusted = 0,
            auth_token = '',
            status     = 'pending'
        """,
        (client_id, device_name, platform, now, email, now, client_ip),
    )
    await db.commit()
    clear_pending_token(client_id)
    logger.info(
        "Pair request from %s (%s) — client_id=%s", device_name, platform, client_id
    )
    try:
        await notification_service.create(
            db,
            type="info",
            category="client",
            title="New pairing request",
            message=f"{device_name} ({platform}) wants to pair.",
            related_kind="client",
            related_id=client_id,
        )
    except Exception:
        logger.warning("Failed to emit pairing notification", exc_info=True)

    try:
        await activity_service.record(
            db,
            type="client.pair",
            summary=f"{device_name} ({platform}) requested pairing",
            actor_kind="client",
            actor_id=client_id,
            target_kind="client",
            target_id=client_id,
            payload={"device_name": device_name, "platform": platform},
        )
    except Exception:
        logger.warning("Failed to record client.pair activity event", exc_info=True)


async def get_client(db: aiosqlite.Connection, client_id: str) -> aiosqlite.Row | None:
    async with db.execute("SELECT * FROM clients WHERE id = ?", (client_id,)) as cur:
        return await cur.fetchone()


async def approve_client(
    db: aiosqlite.Connection, client_id: str, hmac_key: str
) -> str:
    """Approve a pending client. Returns the raw bearer token to send once.

    Stamps `paired_at` only on the first approval (re-pair leaves the
    original timestamp in place so the desktop's "Paired Mar 15" label
    reflects when the user originally trusted the device, not the most
    recent re-pair).
    """
    raw_token = generate_token()
    token_hash = hash_token(raw_token, hmac_key)
    now = datetime.now(UTC).isoformat()

    await db.execute(
        """
        UPDATE clients
        SET is_trusted = 1, auth_token = ?, status = 'approved', last_seen = ?,
            paired_at = COALESCE(paired_at, ?)
        WHERE id = ?
        """,
        (token_hash, now, now, client_id),
    )

    # M3 of docs/10_planning/13_groups_v2_content_spaces.md — every newly-
    # approved client auto-joins the mandatory Public group.  Without this,
    # the v2 visibility model leaves the client with empty visible_libraries
    # (post-migration the v1 "no-group = full-access" default no longer
    # applies).  INSERT OR IGNORE so a repeat-approve (re-pair flow) is
    # idempotent.  The Public group itself is created by migration 025;
    # we don't conditionally check for it because its absence would mean
    # the migration didn't run, which is a server-config bug, not a flow
    # we should defensively work around.
    await db.execute(
        """
        INSERT OR IGNORE INTO group_members (group_id, client_id, added_at)
        VALUES ('public', ?, ?)
        """,
        (client_id, now),
    )

    await db.commit()
    logger.info("Client approved: %s", client_id)

    try:
        await activity_service.record(
            db,
            type="client.approve",
            summary=f"Client {client_id} approved",
            actor_kind="operator",
            target_kind="client",
            target_id=client_id,
        )
    except Exception:
        logger.warning("Failed to record client.approve activity event", exc_info=True)

    return raw_token


async def reject_client(db: aiosqlite.Connection, client_id: str) -> None:
    await db.execute(
        "UPDATE clients SET status = 'rejected', is_trusted = 0 WHERE id = ?",
        (client_id,),
    )
    await db.commit()
    logger.info("Client rejected: %s", client_id)

    try:
        await activity_service.record(
            db,
            type="client.reject",
            summary=f"Client {client_id} rejected",
            actor_kind="operator",
            target_kind="client",
            target_id=client_id,
        )
    except Exception:
        logger.warning("Failed to record client.reject activity event", exc_info=True)


async def revoke_client(db: aiosqlite.Connection, client_id: str) -> None:
    await db.execute(
        """
        UPDATE clients
        SET is_trusted = 0, auth_token = '', status = 'rejected'
        WHERE id = ?
        """,
        (client_id,),
    )
    await db.commit()
    logger.info("Client revoked: %s", client_id)


async def update_client_display_name(
    db: aiosqlite.Connection, client_id: str, display_name: str
) -> None:
    """Update a single client's `name` (a.k.a. display name) column.

    Backs the mobile self-rename flow (`PATCH /auth/clients/me`, mobile
    settings remediation plan M2.5).  The caller has already validated
    + trimmed `display_name` via the `UpdateClientMeRequest` model, so
    this layer just performs the parameterized UPDATE and bumps the
    `last_seen` timestamp.  `clients` has no `updated_at` column in v1,
    so `last_seen` doubles as the freshness signal — same convention
    every other authenticated route follows via `update_client_heartbeat`.
    """
    now = datetime.now(UTC).isoformat()
    await db.execute(
        "UPDATE clients SET name = ?, last_seen = ? WHERE id = ?",
        (display_name, now, client_id),
    )
    await db.commit()
    logger.info("Client %s renamed display_name", client_id)


async def list_clients(db: aiosqlite.Connection) -> list[aiosqlite.Row]:
    """Return all clients with `last_ip`, active session, and group memberships.

    Active-session join: a client is allowed at most one session in flight
    in v1 (`concurrent_session_cap` is 1 per encoder), but defensively we
    pick the most recently started one if multiple ever appear (window
    function `ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY started_at DESC)`).
    The desktop Clients screen uses `active_session_*` columns to render
    the detail-panel "Currently Streaming" block; rows where the join
    didn't match keep them all NULL.

    Groups join (M3, 2026-05-07): a client can belong to 0..N groups via
    `group_members`.  We aggregate via SQLite's `json_group_array` so the
    response carries the groups inline — saves the desktop a per-client
    follow-up fetch when rendering the detail panel's group chips.  Output
    column `groups_json` is a JSON array of
    `{"id": ..., "name": ..., "status": ...}` objects, or NULL when the
    client is in no groups (router treats NULL as `[]`).
    """
    async with db.execute(
        """
        SELECT c.id, c.name, c.platform, c.status, c.last_seen,
               c.is_trusted, c.last_ip,
               sess.session_id        AS active_session_id,
               sess.started_at        AS active_session_started_at,
               sess.encoder_used      AS active_session_encoder,
               sess.media_title       AS active_session_media_title,
               grp.groups_json        AS groups_json
          FROM clients c
     LEFT JOIN (
                SELECT s.client_id, s.id AS session_id, s.started_at,
                       s.encoder_used,
                       COALESCE(m.title, m.name) AS media_title,
                       ROW_NUMBER() OVER (
                           PARTITION BY s.client_id
                           ORDER BY s.started_at DESC
                       ) AS rn
                  FROM stream_sessions s
             LEFT JOIN media_files m ON m.id = s.file_id
                 WHERE s.ended_at IS NULL
                ) sess
                ON sess.client_id = c.id AND sess.rn = 1
     LEFT JOIN (
                SELECT gm.client_id,
                       json_group_array(
                           json_object(
                               'id',     g.id,
                               'name',   g.name,
                               'status', g.status
                           )
                       ) AS groups_json
                  FROM group_members gm
                  JOIN groups g ON g.id = gm.group_id
                 GROUP BY gm.client_id
                ) grp ON grp.client_id = c.id
         ORDER BY c.last_seen DESC
        """
    ) as cur:
        return await cur.fetchall()


async def update_client_heartbeat(
    db: aiosqlite.Connection,
    client_id: str,
    last_ip: str | None = None,
) -> None:
    """Touch `last_seen` (and optionally `last_ip`) for an authenticated client.

    Called from the `validate_token` dependency on every authenticated
    request so the desktop's poll picks up presence + IP changes within a
    poll cycle. SQLite write throughput easily covers Fluxora's expected
    request rate (a handful of mobile clients on a home server); revisit
    only if write contention shows up in profiling.
    """
    now = datetime.now(UTC).isoformat()
    if last_ip is None:
        await db.execute(
            "UPDATE clients SET last_seen = ? WHERE id = ?",
            (now, client_id),
        )
    else:
        await db.execute(
            "UPDATE clients SET last_seen = ?, last_ip = ? WHERE id = ?",
            (now, last_ip, client_id),
        )
    await db.commit()


async def get_trusted_client_by_token(
    db: aiosqlite.Connection, raw_token: str, hmac_key: str
) -> aiosqlite.Row | None:
    """Return the client row if the token is valid and trusted, else None."""
    token_hash = hash_token(raw_token, hmac_key)
    async with db.execute(
        """
        SELECT * FROM clients
        WHERE auth_token = ? AND is_trusted = 1 AND status = 'approved'
        """,
        (token_hash,),
    ) as cur:
        return await cur.fetchone()
