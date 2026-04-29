"""Polar.sh webhook router - POST /api/v1/webhook/polar.

Security model:
- Every request is verified against POLAR_WEBHOOK_SECRET before any business
  logic runs. Unsigned or incorrectly signed requests return 403 immediately.
- The endpoint is intentionally not protected by require_local_caller because
  Polar's servers are external.
- Rate limiting is applied by the global slowapi middleware.

If POLAR_WEBHOOK_SECRET is absent from .env the endpoint returns 501 so
misconfigurations are surfaced immediately (no silent key issuance).
"""

from __future__ import annotations

import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, Request, status

from config import settings
from database.db import get_db
from services import webhook_service

logger = logging.getLogger(__name__)

router = APIRouter()

# Polar events we understand. Key issuance is tied to successful payment.
_HANDLED_EVENTS = {"order.paid", "order.created"}


@router.post("/polar", status_code=status.HTTP_200_OK)
async def polar_webhook(
    request: Request,
    db: aiosqlite.Connection = Depends(get_db),
) -> dict:
    """Receive and process Polar.sh webhook events.

    Polar retries on any non-2xx response, so we always return 200 for correctly
    signed payloads, even if the event is unrecognised, unpaid, or duplicate.
    Only return non-2xx for configuration errors (501), bad signatures (403),
    or invalid signed JSON (400).
    """
    secret = getattr(settings, "polar_webhook_secret", "")
    if not secret:
        logger.error("POLAR_WEBHOOK_SECRET not configured; webhook endpoint disabled")
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Webhook integration not configured on this server.",
        )

    raw_body = await request.body()
    if not webhook_service.verify_polar_signature(
        raw_body,
        request.headers.get("webhook-id"),
        request.headers.get("webhook-timestamp"),
        request.headers.get("webhook-signature"),
        secret,
    ):
        logger.warning(
            "Rejected Polar webhook with invalid signature from %s",
            request.client.host if request.client else "unknown",
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid webhook signature.",
        )

    try:
        payload = await request.json()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid JSON body.",
        ) from exc

    event_type: str = payload.get("type", "")
    event_data: dict = payload.get("data", {})

    if event_type not in _HANDLED_EVENTS:
        logger.info("Polar webhook: ignoring unhandled event type '%s'", event_type)
        return {"status": "ignored", "event": event_type}

    key: str | None = None

    if event_type == "order.paid":
        key = await webhook_service.handle_order_paid(event_data, db)
    elif event_type == "order.created":
        key = await webhook_service.handle_order_created(event_data, db)

    return {
        "status": "processed" if key else "skipped",
        "event": event_type,
        "issued": key is not None,
    }
