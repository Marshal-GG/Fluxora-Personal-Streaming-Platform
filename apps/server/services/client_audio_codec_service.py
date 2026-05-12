"""Plan 21 — per-(client, source audio codec) blocklist for transparent
audio-only transcode fallback.

When a client on the 'auto' streaming mode reports a player audio
decoder error within the first 6 s of playback, the stream router
records the (client_id, audio_codec) pair here.  The next session for
that pair starts with `_session_force_audio_transcode=True` so the
audio path re-encodes while video continues to stream-copy.  Video
decode failures are tracked separately in `client_codec_blocklist`
(plan 20) — combining them would force unnecessary full transcodes
when only one stream needs help.

Two operations, mirroring `client_codec_service`:

* ``is_blocked(db, client_id, audio_codec)`` — read-only lookup
  invoked from ``stream.start_stream`` after the source audio codec
  is resolved.
* ``add_block(db, client_id, audio_codec, reason)`` — idempotent
  upsert (``INSERT OR IGNORE``).  Called from the new
  ``/fallback-audio-transcode`` endpoint.  The caller is responsible
  for ``db.commit()``.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime

import aiosqlite

logger = logging.getLogger(__name__)


async def is_blocked(
    db: aiosqlite.Connection, client_id: str, audio_codec: str
) -> bool:
    """Return True iff (client_id, audio_codec) is in the blocklist.

    A None ``audio_codec`` (probe missed; audio stream metadata not
    available) can never match a row — the composite primary key
    requires a non-NULL codec.  Treat it as "not blocked" so the
    absence of a probe result doesn't force the audio transcode path
    silently.
    """
    if not audio_codec:
        return False
    async with db.execute(
        "SELECT 1 FROM client_audio_codec_blocklist"
        " WHERE client_id = ? AND audio_codec = ?",
        (client_id, audio_codec),
    ) as cur:
        row = await cur.fetchone()
    return row is not None


async def add_block(
    db: aiosqlite.Connection,
    client_id: str,
    audio_codec: str,
    reason: str,
) -> None:
    """Record that ``client_id`` can't decode ``audio_codec``.

    Idempotent: a second call for the same pair is a no-op via
    ``INSERT OR IGNORE`` so a burst of player-error events doesn't
    raise on the primary-key collision.  Caller commits.
    """
    if not audio_codec:
        logger.warning(
            "client_audio_codec_service.add_block called with empty audio_codec "
            "for client=%s; skipping",
            client_id,
        )
        return
    now = datetime.now(UTC).isoformat()
    await db.execute(
        "INSERT OR IGNORE INTO client_audio_codec_blocklist"
        " (client_id, audio_codec, reason, created_at)"
        " VALUES (?, ?, ?, ?)",
        (client_id, audio_codec, reason, now),
    )
    logger.info(
        "client_audio_codec_blocklist add: client=%s audio_codec=%s reason=%s",
        client_id,
        audio_codec,
        reason,
    )
