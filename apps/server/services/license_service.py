"""License key generation and validation — self-hosted HMAC-SHA256 approach.

Key format: FLUXORA-<TIER>-<EXPIRY_YYYYMMDD>-<HMAC8>
  - TIER    : FREE | PLUS | PRO | ULTI
  - EXPIRY  : 8-digit date (99991231 = lifetime)
  - HMAC8   : first 8 hex chars of HMAC-SHA256(secret, "TIER:EXPIRY")

The server HMAC secret is stored in the .env as FLUXORA_LICENSE_SECRET.
If absent the service operates in *offline-only* mode: keys are accepted
as-is and the tier is read from the stored tier field (no key gating).

Generating a key (admin CLI, run on the server machine):
    python -m services.license_service --tier plus --days 365
"""

from __future__ import annotations

import hashlib
import hmac
import logging
from datetime import date, timedelta

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
    - The key has the correct structure.
    - The HMAC signature matches (when FLUXORA_LICENSE_SECRET is set).
    - The key has not expired.

    If FLUXORA_LICENSE_SECRET is not configured, signature checking is
    skipped and the method returns ``valid=False`` with
    ``reason="no_secret"`` so callers know to treat key entry as advisory.
    """
    if not key:
        return LicenseResult(valid=False, reason="empty")

    key = key.strip().upper()
    parts = key.split("-")
    # Expected: FLUXORA - <TIER> - <EXPIRY> - <HMAC8>  → 4 segments
    if len(parts) != 4 or parts[0] != "FLUXORA":
        return LicenseResult(valid=False, reason="malformed")

    _, tier_code, expiry, sig = parts

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

    expected = _compute_sig(secret, tier_code, expiry)
    if not hmac.compare_digest(sig, expected):
        return LicenseResult(valid=False, reason="invalid_signature")

    return LicenseResult(
        valid=True,
        tier=_CODE_TO_TIER[tier_code],
        expires=expiry,
    )


def generate_key(tier: str, days: int | None = None) -> str:
    """Generate a signed license key for *tier*.

    Args:
        tier:  One of ``free | plus | pro | ultimate``.
        days:  Days until expiry.  ``None`` → lifetime key.

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

    sig = _compute_sig(secret, tier_code, expiry)
    return f"FLUXORA-{tier_code}-{expiry}-{sig}"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _compute_sig(secret: str, tier_code: str, expiry: str) -> str:
    payload = f"{tier_code}:{expiry}".encode()
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
