import pytest
from httpx import ASGITransport, AsyncClient

from main import app

HMAC_KEY = "test-secret-key-for-unit-tests-only"

PAIR_BODY = {
    "client_id": "client-uuid-001",
    "device_name": "Test Phone",
    "platform": "android",
    "app_version": "0.1.0",
}


# ── /api/v1/info ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_info_returns_defaults(client: AsyncClient):
    response = await client.get("/api/v1/info")
    assert response.status_code == 200
    data = response.json()
    assert data["server_name"] == "Fluxora Server"
    assert data["version"] == "0.1.0"
    assert data["tier"] == "free"


@pytest.mark.asyncio
async def test_get_info_reflects_settings_row(client: AsyncClient, test_db):
    await test_db.execute(
        "UPDATE user_settings SET server_name = ?, subscription_tier = ? WHERE id = 1",
        ("My Home Server", "plus"),
    )
    await test_db.commit()

    response = await client.get("/api/v1/info")
    assert response.status_code == 200
    data = response.json()
    assert data["server_name"] == "My Home Server"
    assert data["tier"] == "plus"


# ── Pairing flow ─────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_request_pair_creates_pending_client(client: AsyncClient):
    response = await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    assert response.status_code == 200
    data = response.json()
    assert data["client_id"] == PAIR_BODY["client_id"]
    assert data["status"] == "pending_approval"


@pytest.mark.asyncio
async def test_auth_status_pending(client: AsyncClient):
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)

    response = await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")
    assert response.status_code == 200
    assert response.json()["status"] == "pending_approval"


@pytest.mark.asyncio
async def test_auth_status_unknown_client_returns_404(client: AsyncClient):
    response = await client.get("/api/v1/auth/status/nonexistent-id")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_full_approval_flow(client: AsyncClient, monkeypatch):
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)

    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await client.post(f"/api/v1/auth/approve/{PAIR_BODY['client_id']}")

    status_resp = await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")
    assert status_resp.status_code == 200
    data = status_resp.json()
    assert data["status"] == "approved"
    assert data["auth_token"] is not None
    assert len(data["auth_token"]) > 10


@pytest.mark.asyncio
async def test_rejection_flow(client: AsyncClient):
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await client.post(f"/api/v1/auth/reject/{PAIR_BODY['client_id']}")

    status_resp = await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")
    assert status_resp.status_code == 200
    assert status_resp.json()["status"] == "rejected"


@pytest.mark.asyncio
async def test_protected_route_requires_token(client: AsyncClient):
    response = await client.delete(f"/api/v1/auth/revoke/{PAIR_BODY['client_id']}")
    assert response.status_code == 403


# ── Localhost restriction ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_approve_blocked_from_lan(test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("192.168.1.100", 50000)),
        base_url="http://test",
    ) as lan:
        resp = await lan.post("/api/v1/auth/approve/any-id")
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_reject_blocked_from_lan(test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("192.168.1.100", 50000)),
        base_url="http://test",
    ) as lan:
        resp = await lan.post("/api/v1/auth/reject/any-id")
    assert resp.status_code == 403
