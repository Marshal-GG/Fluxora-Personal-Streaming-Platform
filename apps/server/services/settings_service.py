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
    transcoding_encoder: str | None = None,
    transcoding_preset: str | None = None,
    transcoding_crf: int | None = None,
    # General
    language: str | None = None,
    auto_start_on_boot: bool | None = None,
    auto_restart_on_crash: bool | None = None,
    minimize_to_system_tray: bool | None = None,
    theme_accent: str | None = None,
    default_library_view: str | None = None,
    scan_libraries_on_startup: bool | None = None,
    generate_thumbnails: bool | None = None,
    # Network
    preferred_mode: str | None = None,
    enable_mdns: bool | None = None,
    enable_webrtc: bool | None = None,
    relay_server_url: str | None = None,
    # Streaming
    default_quality: str | None = None,
    ai_segment_duration_seconds: int | None = None,
    # Security
    enable_pairing_required: bool | None = None,
    session_timeout_minutes: int | None = None,
    # Advanced
    enable_log_export: bool | None = None,
    custom_server_url: str | None = None,
) -> dict:
    """Persist one or more settings fields.

    Changing *tier* automatically updates *max_concurrent_streams* to match
    the tier's defined limit.  Returns the full updated settings row.

    Only columns whose kwarg is non-None are written; all others are left
    untouched in the database (dynamic UPDATE).
    """
    # --- tier / max_concurrent_streams special handling ---
    if tier is not None:
        if tier not in VALID_TIERS:
            valid_tiers = ", ".join(sorted(VALID_TIERS))
            raise ValueError(f"Invalid tier: {tier!r}. Must be one of {valid_tiers}")

    # Build dynamic field list: (column_name, value) for every non-None kwarg.
    # Boolean fields are stored as integers in SQLite.
    _bool_fields = {
        "transcoding_enabled",
        "auto_start_on_boot",
        "auto_restart_on_crash",
        "minimize_to_system_tray",
        "scan_libraries_on_startup",
        "generate_thumbnails",
        "enable_mdns",
        "enable_webrtc",
        "enable_pairing_required",
        "enable_log_export",
    }

    # Map kwarg names to DB column names (most are identical; tier→subscription_tier).
    _kwarg_to_col: dict[str, str] = {
        "server_name": "server_name",
        "tier": "subscription_tier",
        "license_key": "license_key",
        "transcoding_enabled": "transcoding_enabled",
        "transcoding_encoder": "transcoding_encoder",
        "transcoding_preset": "transcoding_preset",
        "transcoding_crf": "transcoding_crf",
        "language": "language",
        "auto_start_on_boot": "auto_start_on_boot",
        "auto_restart_on_crash": "auto_restart_on_crash",
        "minimize_to_system_tray": "minimize_to_system_tray",
        "theme_accent": "theme_accent",
        "default_library_view": "default_library_view",
        "scan_libraries_on_startup": "scan_libraries_on_startup",
        "generate_thumbnails": "generate_thumbnails",
        "preferred_mode": "preferred_mode",
        "enable_mdns": "enable_mdns",
        "enable_webrtc": "enable_webrtc",
        "relay_server_url": "relay_server_url",
        "default_quality": "default_quality",
        "ai_segment_duration_seconds": "ai_segment_duration_seconds",
        "enable_pairing_required": "enable_pairing_required",
        "session_timeout_minutes": "session_timeout_minutes",
        "enable_log_export": "enable_log_export",
        "custom_server_url": "custom_server_url",
    }

    # Collect all provided kwargs into a local dict for iteration.
    provided: dict[str, object] = {
        "server_name": server_name,
        "tier": tier,
        "license_key": license_key,
        "transcoding_enabled": transcoding_enabled,
        "transcoding_encoder": transcoding_encoder,
        "transcoding_preset": transcoding_preset,
        "transcoding_crf": transcoding_crf,
        "language": language,
        "auto_start_on_boot": auto_start_on_boot,
        "auto_restart_on_crash": auto_restart_on_crash,
        "minimize_to_system_tray": minimize_to_system_tray,
        "theme_accent": theme_accent,
        "default_library_view": default_library_view,
        "scan_libraries_on_startup": scan_libraries_on_startup,
        "generate_thumbnails": generate_thumbnails,
        "preferred_mode": preferred_mode,
        "enable_mdns": enable_mdns,
        "enable_webrtc": enable_webrtc,
        "relay_server_url": relay_server_url,
        "default_quality": default_quality,
        "ai_segment_duration_seconds": ai_segment_duration_seconds,
        "enable_pairing_required": enable_pairing_required,
        "session_timeout_minutes": session_timeout_minutes,
        "enable_log_export": enable_log_export,
        "custom_server_url": custom_server_url,
    }

    updates: list[tuple[str, object]] = []
    for kwarg, value in provided.items():
        if value is None:
            continue
        col = _kwarg_to_col[kwarg]
        db_value = int(value) if col in _bool_fields else value  # type: ignore[arg-type]
        updates.append((col, db_value))

    # When tier changes, also update max_concurrent_streams.
    if tier is not None:
        updates.append(("max_concurrent_streams", TIER_STREAM_LIMITS[tier]))

    if updates:
        set_clause = ", ".join(f"{col} = ?" for col, _ in updates)
        values = [v for _, v in updates]
        await db.execute(
            f"UPDATE user_settings SET {set_clause} WHERE id = 1",  # noqa: S608
            values,
        )
        await db.commit()
        logger.info("Settings updated: fields=%s", [col for col, _ in updates])

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
        "transcoding_encoder": "libx264",
        "transcoding_preset": "veryfast",
        "transcoding_crf": 23,
        "language": "en",
        "auto_start_on_boot": 0,
        "auto_restart_on_crash": 1,
        "minimize_to_system_tray": 1,
        "theme_accent": None,
        "default_library_view": "grid",
        "scan_libraries_on_startup": 1,
        "generate_thumbnails": 1,
        "preferred_mode": "auto",
        "enable_mdns": 1,
        "enable_webrtc": 1,
        "relay_server_url": None,
        "default_quality": "auto",
        "ai_segment_duration_seconds": 4,
        "enable_pairing_required": 1,
        "session_timeout_minutes": 60,
        "enable_log_export": 1,
        "custom_server_url": None,
    }


def _enrich_license(row: dict) -> dict:
    """Annotate a settings dict with license_status and license_tier."""
    result = license_service.validate_key(row.get("license_key"))
    row["license_status"] = result.reason if not result.valid else "valid"
    row["license_tier"] = result.tier
    return row
