import hashlib
import hmac
import logging
import secrets
from datetime import UTC, datetime

import aiosqlite

logger = logging.getLogger(__name__)


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
) -> None:
    now = datetime.now(UTC).isoformat()
    await db.execute(
        """
        INSERT INTO clients (
            id, name, platform, last_seen, is_trusted, auth_token, status
        ) VALUES (?, ?, ?, ?, 0, '', 'pending')
        ON CONFLICT(id) DO UPDATE SET
            name       = excluded.name,
            platform   = excluded.platform,
            last_seen  = excluded.last_seen,
            status     = CASE WHEN status = 'rejected' THEN 'pending' ELSE status END
        """,
        (client_id, device_name, platform, now),
    )
    await db.commit()
    logger.info(
        "Pair request from %s (%s) — client_id=%s", device_name, platform, client_id
    )


async def get_client(db: aiosqlite.Connection, client_id: str) -> aiosqlite.Row | None:
    async with db.execute("SELECT * FROM clients WHERE id = ?", (client_id,)) as cur:
        return await cur.fetchone()


async def approve_client(
    db: aiosqlite.Connection, client_id: str, hmac_key: str
) -> str:
    """Approve a pending client. Returns the raw bearer token to send once."""
    raw_token = generate_token()
    token_hash = hash_token(raw_token, hmac_key)
    now = datetime.now(UTC).isoformat()

    await db.execute(
        """
        UPDATE clients
        SET is_trusted = 1, auth_token = ?, status = 'approved', last_seen = ?
        WHERE id = ?
        """,
        (token_hash, now, client_id),
    )
    await db.commit()
    logger.info("Client approved: %s", client_id)
    return raw_token


async def reject_client(db: aiosqlite.Connection, client_id: str) -> None:
    await db.execute(
        "UPDATE clients SET status = 'rejected', is_trusted = 0 WHERE id = ?",
        (client_id,),
    )
    await db.commit()
    logger.info("Client rejected: %s", client_id)


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
