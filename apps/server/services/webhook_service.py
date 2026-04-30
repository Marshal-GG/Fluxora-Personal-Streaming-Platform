"""Polar.sh webhook processing service.

Responsibilities:
- Verify Polar's Standard Webhooks HMAC-SHA256 signature.
- Map Polar product metadata to Fluxora subscription tiers.
- Call license_service.generate_key() after paid orders.
- Record processed order IDs to guarantee idempotent delivery.
- Return the generated key internally so the router can acknowledge delivery
  without echoing the key in its response.

Generated keys are stored in SQLite for owner retrieval. They are not logged
or echoed in webhook responses because a license key is an entitlement token.
The Polar webhook secret is a secret and must never be logged.

Environment variable required:
    POLAR_WEBHOOK_SECRET - copied from the Polar dashboard or CLI.

Polar events we handle:
    order.paid    - payment fully processed; safe point to issue a key
    order.created - accepted only when the payload is already paid

Docs: https://polar.sh/docs/integrate/webhooks/delivery
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
import logging
import time
from typing import Any

import aiosqlite

from services import license_service

logger = logging.getLogger(__name__)

# Maps the Polar product "metadata.tier" value (set in the Polar dashboard)
# to a Fluxora tier name understood by license_service.
_POLAR_TIER_MAP: dict[str, str] = {
    "free": "free",
    "plus": "plus",
    "pro": "pro",
    "ultimate": "ultimate",
}

# Default key lifetime in days for each tier.
_TIER_DAYS: dict[str, int | None] = {
    "free": 365,
    "plus": 365,
    "pro": 365,
    "ultimate": None,  # lifetime
}


# ---------------------------------------------------------------------------
# Signature verification
# ---------------------------------------------------------------------------


def verify_polar_signature(
    raw_body: bytes,
    webhook_id: str | None,
    webhook_timestamp: str | None,
    signature_header: str | None,
    secret: str,
    *,
    tolerance_seconds: int = 300,
) -> bool:
    """Return True if a Polar Standard Webhooks signature is valid.

    Standard Webhooks signs ``webhook-id.webhook-timestamp.raw_body`` and
    sends one or more base64 HMAC-SHA256 signatures as:
        webhook-signature: v1,<base64> v1,<rotated-base64>

    Polar's dashboard and CLI expose plain secrets, while Standard Webhooks
    libraries often work with base64-serialized secrets. To keep local setup
    ergonomic without adding a dependency, we accept the raw secret and the
    common serialized variants.
    """
    if not webhook_id or not webhook_timestamp or not signature_header or not secret:
        logger.warning("Polar webhook received without required signature headers")
        return False

    if "." in webhook_id or "." in webhook_timestamp:
        logger.warning("Polar webhook metadata contains invalid separator")
        return False

    try:
        timestamp = int(webhook_timestamp)
    except ValueError:
        logger.warning("Polar webhook timestamp is not an integer")
        return False

    if abs(time.time() - timestamp) > tolerance_seconds:
        logger.warning("Polar webhook timestamp outside tolerance window")
        return False

    provided = _parse_standard_signatures(signature_header)
    if not provided:
        logger.warning("Unexpected Polar signature format: %s", signature_header[:20])
        return False

    signed_payload = b".".join(
        [webhook_id.encode(), webhook_timestamp.encode(), raw_body]
    )
    for secret_bytes in _secret_candidates(secret):
        expected = base64.b64encode(
            hmac.new(secret_bytes, signed_payload, hashlib.sha256).digest()
        ).decode()
        if any(hmac.compare_digest(sig, expected) for sig in provided):
            return True

    return False


def _parse_standard_signatures(signature_header: str) -> list[str]:
    signatures: list[str] = []
    for item in signature_header.split():
        if not item.startswith("v1,"):
            continue
        sig = item.split(",", 1)[1].strip()
        if sig:
            signatures.append(sig)
    return signatures


def _secret_candidates(secret: str) -> list[bytes]:
    """Return plausible HMAC key bytes for Polar/Standard Webhooks secrets."""
    cleaned = secret.strip()
    candidates: list[bytes] = []

    def add(candidate: bytes) -> None:
        if candidate and candidate not in candidates:
            candidates.append(candidate)

    add(cleaned.encode())

    if cleaned.startswith("whsec_"):
        decoded = _try_base64_decode(cleaned.removeprefix("whsec_"))
        if decoded is not None:
            add(decoded)

    if cleaned.startswith("polar_whs_"):
        add(cleaned.removeprefix("polar_whs_").encode())

    decoded = _try_base64_decode(cleaned)
    if decoded is not None:
        add(decoded)

    return candidates


def _try_base64_decode(value: str) -> bytes | None:
    try:
        padding = "=" * (-len(value) % 4)
        return base64.b64decode(value + padding, validate=True)
    except (binascii.Error, ValueError):
        return None


# ---------------------------------------------------------------------------
# Event processing
# ---------------------------------------------------------------------------


async def handle_order_paid(
    event_data: dict[str, Any],
    db: aiosqlite.Connection,
) -> str | None:
    """Process a Polar ``order.paid`` event and issue a license key."""
    return await _process_paid_order(event_data, db, event_name="order.paid")


async def handle_order_created(
    event_data: dict[str, Any],
    db: aiosqlite.Connection,
) -> str | None:
    """Process a Polar ``order.created`` event if it is already paid.

    Polar's normal safe issuance event is ``order.paid``. This fallback exists
    for payloads that arrive as ``order.created`` with ``paid=true``.
    """
    if not _is_paid_order(event_data):
        logger.info(
            "Skipping order.created for unpaid order: %s",
            event_data.get("id", ""),
        )
        return None
    return await _process_paid_order(event_data, db, event_name="order.created")


async def _process_paid_order(
    event_data: dict[str, Any],
    db: aiosqlite.Connection,
    *,
    event_name: str,
) -> str | None:
    """Issue a license key for a paid Polar order."""
    order_id: str = event_data.get("id", "")
    if not order_id:
        logger.error("%s event missing 'id' field", event_name)
        return None

    # Idempotency: skip if this order was already processed.
    if await _order_already_processed(order_id, db):
        logger.info("Skipping duplicate order: %s", order_id)
        return None

    tier = _extract_tier(event_data)
    if not tier:
        logger.warning(
            "%s for order %s has no recognized tier in product metadata",
            event_name,
            order_id,
        )
        return None

    customer = event_data.get("customer")
    if not isinstance(customer, dict):
        customer = {}
    email: str = str(customer.get("email", "")).strip()

    # Pass order_id as nonce to guarantee uniqueness and link key to order.
    key = _generate_key_for_tier(tier, order_id, nonce=order_id)
    if not key:
        return None

    await _record_order(order_id, email, tier, key, db)
    logger.info(
        "Issued unique license key for %s order %s (customer=%s, tier=%s)",
        event_name,
        order_id,
        email,
        tier,
    )
    return key


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _extract_tier(event_data: dict[str, Any]) -> str | None:
    """Read the tier from product metadata.

    In the Polar dashboard, add a metadata key ``tier`` to each product
    with the value matching a Fluxora tier name (plus / pro / ultimate).
    """
    product = event_data.get("product")
    if not isinstance(product, dict):
        return None
    metadata = product.get("metadata")
    if not isinstance(metadata, dict):
        return None
    raw_tier: str = str(metadata.get("tier", "")).lower().strip()
    return _POLAR_TIER_MAP.get(raw_tier)


def _is_paid_order(event_data: dict[str, Any]) -> bool:
    return bool(event_data.get("paid")) or str(event_data.get("status", "")) == "paid"


def _generate_key_for_tier(
    tier: str, ref_id: str, nonce: str | None = None
) -> str | None:
    """Call license_service.generate_key() and handle errors gracefully."""
    days = _TIER_DAYS.get(tier)
    try:
        return license_service.generate_key(tier, days, nonce=nonce)
    except ValueError as exc:
        logger.error(
            "Failed to generate license key for tier=%s ref=%s: %s",
            tier,
            ref_id,
            exc,
        )
        return None


async def _order_already_processed(order_id: str, db: aiosqlite.Connection) -> bool:
    cursor = await db.execute(
        "SELECT 1 FROM polar_orders WHERE order_id = ?", (order_id,)
    )
    row = await cursor.fetchone()
    return row is not None


async def _record_order(
    order_id: str,
    email: str,
    tier: str,
    license_key: str,
    db: aiosqlite.Connection,
) -> None:
    await db.execute(
        """
        INSERT INTO polar_orders (
            order_id, customer_email, tier, license_key, processed_at
        )
        VALUES (?, ?, ?, ?, datetime('now'))
        """,
        (order_id, email, tier, license_key),
    )
    await db.commit()
