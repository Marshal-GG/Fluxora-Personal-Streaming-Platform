import pytest
from httpx import AsyncClient

HMAC_KEY = "test-secret-key-for-unit-tests-only"

CREATE_BODY = {
    "name": "My Movies",
    "type": "movies",
    "root_paths": ["/media/movies", "/nas/movies"],
}


async def _get_token(client: AsyncClient, monkeypatch) -> str:
    """Pair and approve a test client; return the bearer token."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    pair_body = {
        "client_id": "lib-test-client",
        "device_name": "Test Device",
        "platform": "android",
        "app_version": "0.1.0",
    }
    await client.post("/api/v1/auth/request-pair", json=pair_body)
    await client.post("/api/v1/auth/approve/lib-test-client")
    status = await client.get("/api/v1/auth/status/lib-test-client")
    return status.json()["auth_token"]


# ── GET /api/v1/library ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_libraries_requires_auth(client: AsyncClient):
    response = await client.get("/api/v1/library")
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_list_libraries_empty(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    response = await client.get(
        "/api/v1/library", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    assert response.json() == []


# ── POST /api/v1/library ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_library(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    response = await client.post("/api/v1/library", json=CREATE_BODY, headers=headers)
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "My Movies"
    assert data["type"] == "movies"
    assert data["root_paths"] == ["/media/movies", "/nas/movies"]
    assert data["file_count"] == 0
    assert data["last_scanned"] is None
    assert "id" in data
    assert "created_at" in data


@pytest.mark.asyncio
async def test_create_library_appears_in_list(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    await client.post("/api/v1/library", json=CREATE_BODY, headers=headers)
    response = await client.get("/api/v1/library", headers=headers)
    assert response.status_code == 200
    libraries = response.json()
    assert len(libraries) == 1
    assert libraries[0]["name"] == "My Movies"


# ── GET /api/v1/library/{id} ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_library_by_id(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    created = (
        await client.post("/api/v1/library", json=CREATE_BODY, headers=headers)
    ).json()
    library_id = created["id"]

    response = await client.get(f"/api/v1/library/{library_id}", headers=headers)
    assert response.status_code == 200
    assert response.json()["id"] == library_id


@pytest.mark.asyncio
async def test_get_library_not_found(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    response = await client.get("/api/v1/library/nonexistent-id", headers=headers)
    assert response.status_code == 404


# ── DELETE /api/v1/library/{id} ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_delete_library(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    created = (
        await client.post("/api/v1/library", json=CREATE_BODY, headers=headers)
    ).json()
    library_id = created["id"]

    response = await client.delete(f"/api/v1/library/{library_id}", headers=headers)
    assert response.status_code == 204

    response = await client.get(f"/api/v1/library/{library_id}", headers=headers)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_delete_library_not_found(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    response = await client.delete("/api/v1/library/nonexistent-id", headers=headers)
    assert response.status_code == 404
