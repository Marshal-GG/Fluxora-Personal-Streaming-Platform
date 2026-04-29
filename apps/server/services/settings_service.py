from __future__ import annotations

import logging

import aiosqlite

from services import license_service

logger = logging.getLogger(__name__)

# Stream concurrency caps per subscription tier.
TIER_STREAM_LIMITS: dict[str, int] = {
    "free": 1,
    "plus": 3,
    "pro": 10,
    "ultimate": 9999,
}

VALID_TIERS = frozenset(TIER_STREAM_LIMITS)


async def get_settings(db: aiosqlite.Connection) -> dict:
    """Return the current user_settings row as a dict, enriched with license status."""
    async with db.execute("SELECT * FROM user_settings WHERE id = 1") as cur:
        row = await cur.fetchone()
    base = dict(row) if row is not None else _defaults()
    return _enrich_license(base)


async def update_settings(
    db: aiosqlite.Connection,
    *,
    server_name: str | None = None,
    tier: str | None = None,
    license_key: str | None = None,
    transcoding_enabled: bool | None = None,
) -> dict:
    """Persist one or more settings fields.

    Changing *tier* automatically updates *max_concurrent_streams* to match
    the tier's defined limit.  Returns the full updated settings row.
    """
    current = await get_settings(db)

    new_name = server_name if server_name is not None else current["server_name"]
    new_tier = tier if tier is not None else current["subscription_tier"]
    new_key = license_key if license_key is not None else current.get("license_key")
    new_transcoding = (
        transcoding_enabled
        if transcoding_enabled is not None
        else bool(current["transcoding_enabled"])
    )

    if new_tier not in VALID_TIERS:
        valid_tiers = ", ".join(sorted(VALID_TIERS))
        raise ValueError(f"Invalid tier: {new_tier!r}. Must be one of {valid_tiers}")

    new_max_streams = TIER_STREAM_LIMITS[new_tier]

    await db.execute(
        """
        UPDATE user_settings
        SET server_name            = ?,
            subscription_tier      = ?,
            max_concurrent_streams = ?,
            license_key            = ?,
            transcoding_enabled    = ?
        WHERE id = 1
        """,
        (new_name, new_tier, new_max_streams, new_key, int(new_transcoding)),
    )
    await db.commit()
    logger.info("Settings updated: tier=%s max_streams=%d", new_tier, new_max_streams)
    return _enrich_license(await get_settings(db))


async def get_max_concurrent_streams(db: aiosqlite.Connection) -> int:
    """Return the active stream concurrency limit from the DB.

    Used by the stream router instead of the static config value so that
    a tier change takes effect immediately without a server restart.
    """
    async with db.execute(
        "SELECT max_concurrent_streams FROM user_settings WHERE id = 1"
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        return TIER_STREAM_LIMITS["free"]
    return int(row["max_concurrent_streams"])


def _defaults() -> dict:
    return {
        "id": 1,
        "server_name": "Fluxora Server",
        "transcoding_enabled": 1,
        "max_concurrent_streams": TIER_STREAM_LIMITS["free"],
        "subscription_tier": "free",
        "license_key": None,
        "tmdb_api_key": None,
    }


def _enrich_license(row: dict) -> dict:
    """Annotate a settings dict with license_status and license_tier."""
    result = license_service.validate_key(row.get("license_key"))
    row["license_status"] = result.reason if not result.valid else "valid"
    row["license_tier"] = result.tier
    return row
