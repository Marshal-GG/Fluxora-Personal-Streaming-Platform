"""Tests for POST /api/v1/webhook/polar and webhook_service internals."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_SECRET = "testsecret1234"


def _make_signature_headers(
    body: bytes,
    *,
    secret: str = _SECRET,
    webhook_id: str = "msg_test_123",
    timestamp: int | None = None,
) -> dict[str, str]:
    ts = str(timestamp or int(time.time()))
    signed_payload = b".".join([webhook_id.encode(), ts.encode(), body])
    digest = base64.b64encode(
        hmac.new(secret.encode(), signed_payload, hashlib.sha256).digest()
    ).decode()
    return {
        "webhook-id": webhook_id,
        "webhook-timestamp": ts,
        "webhook-signature": f"v1,{digest}",
    }


def _polar_order_payload(
    *,
    tier: str = "plus",
    order_id: str = "ord_abc123",
    event_type: str = "order.paid",
    paid: bool = True,
) -> dict:
    return {
        "type": event_type,
        "timestamp": "2026-04-29T10:00:00Z",
        "data": {
            "id": order_id,
            "status": "paid" if paid else "pending",
            "paid": paid,
            "billing_reason": "purchase",
            "customer": {"email": "buyer@example.com"},
            "product": {
                "metadata": {"tier": tier},
            },
        },
    }


# ---------------------------------------------------------------------------
# webhook_service unit tests (no HTTP)
# ---------------------------------------------------------------------------


def test_verify_signature_valid() -> None:
    from services.webhook_service import verify_polar_signature

    body = b'{"type":"order.paid"}'
    headers = _make_signature_headers(body)
    assert (
        verify_polar_signature(
            body,
            headers["webhook-id"],
            headers["webhook-timestamp"],
            headers["webhook-signature"],
            _SECRET,
        )
        is True
    )


def test_verify_signature_wrong_secret() -> None:
    from services.webhook_service import verify_polar_signature

    body = b'{"type":"order.paid"}'
    headers = _make_signature_headers(body, secret="wrong_secret")
    assert (
        verify_polar_signature(
            body,
            headers["webhook-id"],
            headers["webhook-timestamp"],
            headers["webhook-signature"],
            _SECRET,
        )
        is False
    )


def test_verify_signature_missing_header() -> None:
    from services.webhook_service import verify_polar_signature

    assert verify_polar_signature(b"body", "msg_1", "123", None, _SECRET) is False


def test_verify_signature_bad_prefix() -> None:
    from services.webhook_service import verify_polar_signature

    body = b"body"
    assert (
        verify_polar_signature(
            body,
            "msg_1",
            str(int(time.time())),
            "sha256=abc",
            _SECRET,
        )
        is False
    )


def test_verify_signature_tampered_body() -> None:
    from services.webhook_service import verify_polar_signature

    body = b'{"type":"order.paid"}'
    headers = _make_signature_headers(body)
    tampered = b'{"type":"order.paid","extra":true}'
    assert (
        verify_polar_signature(
            tampered,
            headers["webhook-id"],
            headers["webhook-timestamp"],
            headers["webhook-signature"],
            _SECRET,
        )
        is False
    )


def test_verify_signature_expired_timestamp() -> None:
    from services.webhook_service import verify_polar_signature

    body = b'{"type":"order.paid"}'
    headers = _make_signature_headers(body, timestamp=int(time.time()) - 600)
    assert (
        verify_polar_signature(
            body,
            headers["webhook-id"],
            headers["webhook-timestamp"],
            headers["webhook-signature"],
            _SECRET,
        )
        is False
    )


def test_verify_signature_accepts_rotated_signature_list() -> None:
    from services.webhook_service import verify_polar_signature

    body = b'{"type":"order.paid"}'
    headers = _make_signature_headers(body)
    headers["webhook-signature"] = (
        "v1,badSignatureValue " + headers["webhook-signature"]
    )

    assert (
        verify_polar_signature(
            body,
            headers["webhook-id"],
            headers["webhook-timestamp"],
            headers["webhook-signature"],
            _SECRET,
        )
        is True
    )


# ---------------------------------------------------------------------------
# webhook_service async unit tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_handle_order_paid_issues_key() -> None:
    from services.webhook_service import handle_order_paid

    db = AsyncMock()
    payload = _polar_order_payload(tier="plus", order_id="ord_neworder1")

    with (
        patch("services.webhook_service._order_already_processed", return_value=False),
        patch(
            "services.license_service.generate_key",
            return_value="FLUXORA-PLUS-99991231-DEADBEEF",
        ) as mock_gen,
        patch("services.webhook_service._record_order", new_callable=AsyncMock),
    ):
        key = await handle_order_paid(payload["data"], db)

    assert key == "FLUXORA-PLUS-99991231-DEADBEEF"
    mock_gen.assert_called_once_with("plus", 365, nonce="ord_neworder1")


@pytest.mark.asyncio
async def test_handle_order_paid_skips_duplicate() -> None:
    from services.webhook_service import handle_order_paid

    db = AsyncMock()
    payload = _polar_order_payload(order_id="ord_duplicate")

    with patch("services.webhook_service._order_already_processed", return_value=True):
        key = await handle_order_paid(payload["data"], db)

    assert key is None


@pytest.mark.asyncio
async def test_handle_order_created_unpaid_returns_none() -> None:
    from services.webhook_service import handle_order_created

    db = AsyncMock()
    payload = _polar_order_payload(
        event_type="order.created",
        order_id="ord_pending",
        paid=False,
    )
    key = await handle_order_created(payload["data"], db)
    assert key is None


@pytest.mark.asyncio
async def test_handle_order_created_paid_issues_key() -> None:
    from services.webhook_service import handle_order_created

    db = AsyncMock()
    payload = _polar_order_payload(
        event_type="order.created",
        tier="pro",
        order_id="ord_paid_created",
        paid=True,
    )

    with (
        patch("services.webhook_service._order_already_processed", return_value=False),
        patch(
            "services.license_service.generate_key",
            return_value="FLUXORA-PRO-99991231-CAFEBABE",
        ) as mock_gen,
        patch("services.webhook_service._record_order", new_callable=AsyncMock),
    ):
        key = await handle_order_created(payload["data"], db)

    assert key == "FLUXORA-PRO-99991231-CAFEBABE"
    mock_gen.assert_called_once_with("pro", 365, nonce="ord_paid_created")


@pytest.mark.asyncio
async def test_handle_order_paid_unknown_tier_returns_none() -> None:
    from services.webhook_service import handle_order_paid

    db = AsyncMock()
    payload = _polar_order_payload(tier="enterprise", order_id="ord_badtier")
    key = await handle_order_paid(payload["data"], db)
    assert key is None


@pytest.mark.asyncio
async def test_handle_order_paid_missing_id_returns_none() -> None:
    from services.webhook_service import handle_order_paid

    db = AsyncMock()
    key = await handle_order_paid({}, db)
    assert key is None


# ---------------------------------------------------------------------------
# HTTP integration tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_webhook_polar_no_secret_returns_501(client: AsyncClient) -> None:
    payload = json.dumps(_polar_order_payload()).encode()

    with patch("routers.webhook.settings") as mock_settings:
        mock_settings.polar_webhook_secret = ""
        res = await client.post(
            "/api/v1/webhook/polar",
            content=payload,
            headers={"Content-Type": "application/json"},
        )

    assert res.status_code == 501


@pytest.mark.asyncio
async def test_webhook_polar_bad_signature_returns_403(client: AsyncClient) -> None:
    payload = json.dumps(_polar_order_payload()).encode()
    headers = _make_signature_headers(payload, secret="wrong_secret")
    headers["Content-Type"] = "application/json"

    with patch("routers.webhook.settings") as mock_settings:
        mock_settings.polar_webhook_secret = _SECRET
        res = await client.post(
            "/api/v1/webhook/polar",
            content=payload,
            headers=headers,
        )

    assert res.status_code == 403


@pytest.mark.asyncio
async def test_webhook_polar_valid_order_paid_returns_200(
    client: AsyncClient,
) -> None:
    payload_dict = _polar_order_payload(order_id="ord_integration1")
    payload_bytes = json.dumps(payload_dict).encode()
    headers = _make_signature_headers(payload_bytes)
    headers["Content-Type"] = "application/json"

    with (
        patch("routers.webhook.settings") as mock_settings,
        patch("services.webhook_service._order_already_processed", return_value=False),
        patch(
            "services.license_service.generate_key",
            return_value="FLUXORA-PLUS-99991231-AABBCCDD",
        ),
        patch("services.webhook_service._record_order", new_callable=AsyncMock),
    ):
        mock_settings.polar_webhook_secret = _SECRET
        res = await client.post(
            "/api/v1/webhook/polar",
            content=payload_bytes,
            headers=headers,
        )

    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "processed"
    assert body["issued"] is True
    assert body["event"] == "order.paid"
    assert "license_key" not in body


@pytest.mark.asyncio
async def test_webhook_polar_unhandled_event_returns_ignored(
    client: AsyncClient,
) -> None:
    payload_dict = {"type": "refund.created", "data": {}}
    payload_bytes = json.dumps(payload_dict).encode()
    headers = _make_signature_headers(payload_bytes)
    headers["Content-Type"] = "application/json"

    with patch("routers.webhook.settings") as mock_settings:
        mock_settings.polar_webhook_secret = _SECRET
        res = await client.post(
            "/api/v1/webhook/polar",
            content=payload_bytes,
            headers=headers,
        )

    assert res.status_code == 200
    assert res.json()["status"] == "ignored"


@pytest.mark.asyncio
async def test_webhook_polar_duplicate_order_returns_skipped(
    client: AsyncClient,
) -> None:
    payload_dict = _polar_order_payload(order_id="ord_dup999")
    payload_bytes = json.dumps(payload_dict).encode()
    headers = _make_signature_headers(payload_bytes)
    headers["Content-Type"] = "application/json"

    with (
        patch("routers.webhook.settings") as mock_settings,
        patch("services.webhook_service._order_already_processed", return_value=True),
    ):
        mock_settings.polar_webhook_secret = _SECRET
        res = await client.post(
            "/api/v1/webhook/polar",
            content=payload_bytes,
            headers=headers,
        )

    assert res.status_code == 200
    assert res.json()["status"] == "skipped"


@pytest.mark.asyncio
async def test_webhook_polar_signed_invalid_json_returns_400(
    client: AsyncClient,
) -> None:
    payload = b"not-json"
    headers = _make_signature_headers(payload)
    headers["Content-Type"] = "application/json"

    with patch("routers.webhook.settings") as mock_settings:
        mock_settings.polar_webhook_secret = _SECRET
        res = await client.post(
            "/api/v1/webhook/polar",
            content=payload,
            headers=headers,
        )

    assert res.status_code == 400
