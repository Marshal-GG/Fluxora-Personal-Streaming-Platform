"""Plan 20 — per-(client, source codec) blocklist for transparent
transcode fallback.

When a client on the new 'auto' streaming mode reports a player
decoder error within the first 6 s of playback, the stream router
records the (client_id, source_codec) pair here.  The next session
for that pair starts directly in server-transcode mode regardless of
the global `streaming_mode` setting or the per-library override —
the device has physically told us it can't decode this codec, so we
honour that without wasting another session probing.

Two operations:

* ``is_blocked(db, client_id, source_codec)`` — read-only lookup
  invoked from ``stream.start_stream`` after the source codec is
  resolved.
* ``add_block(db, client_id, source_codec, reason)`` — idempotent
  upsert (``INSERT OR IGNORE``).  Called from the new
  ``/fallback-transcode`` endpoint.  The caller is responsible for
  ``db.commit()``.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime

import aiosqlite

logger = logging.getLogger(__name__)


async def is_blocked(
    db: aiosqlite.Connection, client_id: str, source_codec: str
) -> bool:
    """Return True iff (client_id, source_codec) is in the blocklist.

    A None ``source_codec`` (lazy-probe missed; not in media_files,
    not in the sidecar override) can never match a row — the
    composite primary key requires a non-NULL codec.  Treat it as
    "not blocked" so the absence of a probe result doesn't force the
    transcode path silently.
    """
    if not source_codec:
        return False
    async with db.execute(
        "SELECT 1 FROM client_codec_blocklist"
        " WHERE client_id = ? AND source_codec = ?",
        (client_id, source_codec),
    ) as cur:
        row = await cur.fetchone()
    return row is not None


async def add_block(
    db: aiosqlite.Connection,
    client_id: str,
    source_codec: str,
    reason: str,
) -> None:
    """Record that ``client_id`` can't decode ``source_codec``.

    Idempotent: a second call for the same pair is a no-op via
    ``INSERT OR IGNORE`` so a burst of player-error events doesn't
    raise on the primary-key collision.  Caller commits.
    """
    if not source_codec:
        logger.warning(
            "client_codec_service.add_block called with empty source_codec "
            "for client=%s; skipping",
            client_id,
        )
        return
    now = datetime.now(UTC).isoformat()
    await db.execute(
        "INSERT OR IGNORE INTO client_codec_blocklist"
        " (client_id, source_codec, reason, created_at)"
        " VALUES (?, ?, ?, ?)",
        (client_id, source_codec, reason, now),
    )
    logger.info(
        "client_codec_blocklist add: client=%s codec=%s reason=%s",
        client_id,
        source_codec,
        reason,
    )
