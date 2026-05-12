"""Plan 20 — per-(client, source codec) blocklist service tests."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

import pytest

from services import client_codec_service


async def _insert_client(test_db) -> str:
    """Insert a minimal `clients` row + return its id."""
    client_id = f"client-{uuid.uuid4()}"
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        "INSERT INTO clients (id, name, platform, last_seen, is_trusted, auth_token)"
        " VALUES (?, ?, 'android', ?, 1, 'fake-hashed-token')",
        (client_id, "Test Device", now),
    )
    await test_db.commit()
    return client_id


@pytest.mark.asyncio
async def test_is_blocked_returns_false_for_empty_blocklist(test_db) -> None:
    client_id = await _insert_client(test_db)
    assert await client_codec_service.is_blocked(test_db, client_id, "av1") is False


@pytest.mark.asyncio
async def test_add_block_then_is_blocked_round_trip(test_db) -> None:
    client_id = await _insert_client(test_db)
    await client_codec_service.add_block(
        test_db, client_id, "av1", "player_error_within_6s"
    )
    await test_db.commit()
    assert await client_codec_service.is_blocked(test_db, client_id, "av1") is True
    # Different codec on same client still unblocked.
    assert await client_codec_service.is_blocked(test_db, client_id, "vp9") is False


@pytest.mark.asyncio
async def test_add_block_is_idempotent_under_double_add(test_db) -> None:
    """A burst of player-error events must not raise on PK collision."""
    client_id = await _insert_client(test_db)
    await client_codec_service.add_block(
        test_db, client_id, "hevc", "player_error_within_6s"
    )
    # Second call with the same (client, codec) is a no-op — INSERT OR
    # IGNORE in the service swallows the unique-constraint failure.
    await client_codec_service.add_block(
        test_db, client_id, "hevc", "different-reason-should-be-ignored"
    )
    await test_db.commit()

    # Exactly one row regardless of how many add_block calls landed.
    async with test_db.execute(
        "SELECT COUNT(*), reason FROM client_codec_blocklist"
        " WHERE client_id = ? AND source_codec = ?",
        (client_id, "hevc"),
    ) as cur:
        row = await cur.fetchone()
    assert row[0] == 1
    # First reason wins — INSERT OR IGNORE doesn't update.
    assert row[1] == "player_error_within_6s"


@pytest.mark.asyncio
async def test_is_blocked_treats_empty_codec_as_unblocked(test_db) -> None:
    """No codec → no PK match possible → always unblocked.  Guards
    against a lazy-probe-deferred path silently forcing transcode."""
    client_id = await _insert_client(test_db)
    assert await client_codec_service.is_blocked(test_db, client_id, "") is False
    assert await client_codec_service.is_blocked(test_db, client_id, None) is False  # type: ignore[arg-type]


@pytest.mark.asyncio
async def test_add_block_skips_empty_codec(test_db) -> None:
    """add_block with empty codec must be a logged no-op (no PK violation,
    no spurious NULL row)."""
    client_id = await _insert_client(test_db)
    await client_codec_service.add_block(
        test_db, client_id, "", "player_error_within_6s"
    )
    await test_db.commit()
    async with test_db.execute(
        "SELECT COUNT(*) FROM client_codec_blocklist WHERE client_id = ?",
        (client_id,),
    ) as cur:
        row = await cur.fetchone()
    assert row[0] == 0
