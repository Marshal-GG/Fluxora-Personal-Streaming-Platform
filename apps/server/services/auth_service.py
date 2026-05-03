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
) -> None:
    """Insert a fresh pending pair request, or reset an existing client.

    Same-client_id re-pair semantics (Phase A backfill plan §8.5 bug 1):
    if a row with this client_id already exists in any status, the row is
    reset to `status = 'pending'` with `is_trusted = 0` and a cleared
    `auth_token` so the previously-issued bearer is dead the instant the
    request lands. Any in-memory pending raw token for this client_id is
    dropped too.
    """
    now = datetime.now(UTC).isoformat()
    await db.execute(
        """
        INSERT INTO clients (
            id, name, platform, last_seen, is_trusted, auth_token, status,
            email, paired_at
        ) VALUES (?, ?, ?, ?, 0, '', 'pending', ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name       = excluded.name,
            platform   = excluded.platform,
            last_seen  = excluded.last_seen,
            email      = COALESCE(excluded.email, clients.email),
            is_trusted = 0,
            auth_token = '',
            status     = 'pending'
        """,
        (client_id, device_name, platform, now, email, now),
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


async def list_clients(db: aiosqlite.Connection) -> list[aiosqlite.Row]:
    async with db.execute(
        """
        SELECT id, name, platform, status, last_seen, is_trusted
        FROM clients
        ORDER BY last_seen DESC
        """
    ) as cur:
        return await cur.fetchall()


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
