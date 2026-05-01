"""License key generation and validation — self-hosted HMAC-SHA256 approach.

Key format: FLUXORA-<TIER>-<EXPIRY_YYYYMMDD>-<NONCE>-<HMAC8>
  - TIER    : FREE | PLUS | PRO | ULTI
  - EXPIRY  : 8-digit date (99991231 = lifetime)
  - NONCE   : 4-char random hex string (prevents rainbow-table attacks)
  - HMAC8   : first 8 hex chars of HMAC-SHA256(secret, "TIER:EXPIRY:NONCE")

The server HMAC secret is stored in the .env as FLUXORA_LICENSE_SECRET.
If absent the service operates in *offline-only* mode: keys are accepted
as-is and the tier is read from the stored tier field (no key gating).

Generating a key (admin CLI, run on the server machine):
    python -m services.license_service --tier plus --days 365
"""

import binascii
import hashlib
import hmac
import logging
import os
from datetime import date, timedelta

import aiosqlite

from config import settings

logger = logging.getLogger(__name__)

# Maps the short code embedded in the key to a subscription tier name.
_CODE_TO_TIER: dict[str, str] = {
    "FREE": "free",
    "PLUS": "plus",
    "PRO": "pro",
    "ULTI": "ultimate",
}
_TIER_TO_CODE: dict[str, str] = {v: k for k, v in _CODE_TO_TIER.items()}

LIFETIME_DATE = "99991231"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


class LicenseResult:
    __slots__ = ("valid", "tier", "expires", "reason")

    def __init__(
        self,
        *,
        valid: bool,
        tier: str | None = None,
        expires: str | None = None,
        reason: str = "",
    ) -> None:
        self.valid = valid
        self.tier = tier
        self.expires = expires
        self.reason = reason

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"LicenseResult(valid={self.valid}, tier={self.tier!r}, "
            f"expires={self.expires!r}, reason={self.reason!r})"
        )


def validate_key(key: str | None) -> LicenseResult:
    """Validate a license key string.

    Returns a :class:`LicenseResult` with ``valid=True`` if:
    - The key has the correct 5-part structure.
    - The HMAC signature matches (when FLUXORA_LICENSE_SECRET is set).
    - The key has not expired.
    """
    if not key:
        return LicenseResult(valid=False, reason="empty")

    key = key.strip().upper()
    parts = key.split("-")

    # Expected format: FLUXORA - <TIER> - <EXPIRY> - <NONCE> - <SIG>
    if parts[0] != "FLUXORA":
        return LicenseResult(valid=False, reason="malformed")

    if len(parts) != 5:
        return LicenseResult(valid=False, reason="malformed")

    _, tier_code, expiry, nonce, sig = parts
    payload_parts = [tier_code, expiry, nonce]

    if tier_code not in _CODE_TO_TIER:
        return LicenseResult(valid=False, reason="unknown_tier")

    if len(expiry) != 8 or not expiry.isdigit():
        return LicenseResult(valid=False, reason="malformed_expiry")

    # Expiry check
    if expiry != LIFETIME_DATE:
        try:
            exp_date = date(int(expiry[:4]), int(expiry[4:6]), int(expiry[6:8]))
            if date.today() > exp_date:
                return LicenseResult(
                    valid=False,
                    tier=_CODE_TO_TIER[tier_code],
                    expires=expiry,
                    reason="expired",
                )
        except ValueError:
            return LicenseResult(valid=False, reason="malformed_expiry")

    # HMAC signature check
    secret = getattr(settings, "fluxora_license_secret", "")
    if not secret:
        logger.warning(
            "FLUXORA_LICENSE_SECRET not set — key structure OK but signature "
            "not verified (offline-advisory mode)"
        )
        return LicenseResult(
            valid=False,
            tier=_CODE_TO_TIER[tier_code],
            expires=expiry,
            reason="no_secret",
        )

    expected = _compute_sig(secret, payload_parts)
    if not hmac.compare_digest(sig, expected):
        return LicenseResult(valid=False, reason="invalid_signature")

    return LicenseResult(
        valid=True,
        tier=_CODE_TO_TIER[tier_code],
        expires=expiry,
    )


async def emit_license_expiry_warnings(
    db: aiosqlite.Connection, key: str | None
) -> None:
    """Emit a notification if the configured key is expired or expiring within 30 days.

    Idempotent: skips if a matching notification was already created in the last day.
    """
    from services import notification_service

    result = validate_key(key)

    if result.valid is False and result.reason == "expired":
        related_id = key or "unknown"
        async with db.execute(
            """
            SELECT id FROM notifications
             WHERE category = 'license'
               AND related_id = ?
               AND created_at > datetime('now', '-1 day')
               AND dismissed_at IS NULL
             LIMIT 1
            """,
            (related_id,),
        ) as cur:
            if await cur.fetchone() is not None:
                return
        try:
            await notification_service.create(
                db,
                type="error",
                category="license",
                title="License expired",
                message="Renew to keep your tier active.",
                related_kind="license",
                related_id=related_id,
            )
        except Exception:
            logger.warning("Failed to emit license expiry notification", exc_info=True)
        return

    if result.valid is True and result.expires and result.expires != LIFETIME_DATE:
        try:
            exp_date = date(
                int(result.expires[:4]),
                int(result.expires[4:6]),
                int(result.expires[6:8]),
            )
        except (ValueError, TypeError):
            return

        days_left = (exp_date - date.today()).days
        if days_left <= 30:
            related_id = key or "unknown"
            async with db.execute(
                """
                SELECT id FROM notifications
                 WHERE category = 'license'
                   AND related_id = ?
                   AND created_at > datetime('now', '-1 day')
                   AND dismissed_at IS NULL
                 LIMIT 1
                """,
                (related_id,),
            ) as cur:
                if await cur.fetchone() is not None:
                    return
            try:
                await notification_service.create(
                    db,
                    type="warning",
                    category="license",
                    title="License expires soon",
                    message=f"Your license expires on {result.expires}.",
                    related_kind="license",
                    related_id=related_id,
                )
            except Exception:
                logger.warning(
                    "Failed to emit license expiry warning notification", exc_info=True
                )


def generate_key(tier: str, days: int | None = None, nonce: str | None = None) -> str:
    """Generate a signed license key for *tier*.

    Args:
        tier:  One of ``free | plus | pro | ultimate``.
        days:  Days until expiry.  ``None`` → lifetime key.
        nonce: Optional unique string to include in the key and signature.
               If None, a random 4-char hex string is generated.

    Raises:
        ValueError: If the tier is unknown or FLUXORA_LICENSE_SECRET is absent.
    """
    tier = tier.lower()
    if tier not in _TIER_TO_CODE:
        raise ValueError(f"Unknown tier: {tier!r}")

    secret = getattr(settings, "fluxora_license_secret", "")
    if not secret:
        raise ValueError(
            "FLUXORA_LICENSE_SECRET must be set in .env to generate signed keys"
        )

    tier_code = _TIER_TO_CODE[tier]
    if days is None:
        expiry = LIFETIME_DATE
    else:
        expiry = (date.today() + timedelta(days=days)).strftime("%Y%m%d")

    if nonce is None:
        nonce = binascii.hexlify(os.urandom(2)).decode().upper()
    else:
        nonce = nonce.strip().upper()

    sig = _compute_sig(secret, [tier_code, expiry, nonce])
    return f"FLUXORA-{tier_code}-{expiry}-{nonce}-{sig}"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _compute_sig(secret: str, parts: list[str]) -> str:
    payload = ":".join(parts).encode()
    mac = hmac.new(secret.encode(), payload, hashlib.sha256).hexdigest()
    return mac[:8].upper()


# ---------------------------------------------------------------------------
# CLI helper — python -m services.license_service --tier plus --days 365
# ---------------------------------------------------------------------------

if __name__ == "__main__":  # pragma: no cover
    import argparse

    parser = argparse.ArgumentParser(description="Generate a Fluxora license key")
    parser.add_argument(
        "--tier", required=True, choices=list(_TIER_TO_CODE), help="Subscription tier"
    )
    parser.add_argument(
        "--days",
        type=int,
        default=None,
        help="Days until expiry (omit for lifetime key)",
    )
    args = parser.parse_args()
    print(generate_key(args.tier, args.days))
