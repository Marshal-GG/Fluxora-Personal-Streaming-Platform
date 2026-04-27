import uuid
from datetime import UTC, datetime

import pytest
from httpx import AsyncClient

HMAC_KEY = "test-secret-key-for-unit-tests-only"


async def _get_token(client: AsyncClient, monkeypatch) -> str:
    """Pair and approve a test client; return the bearer token."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    pair_body = {
        "client_id": "files-test-client",
        "device_name": "Test Device",
        "platform": "android",
        "app_version": "0.1.0",
    }
    await client.post("/api/v1/auth/request-pair", json=pair_body)
    await client.post("/api/v1/auth/approve/files-test-client")
    status = await client.get("/api/v1/auth/status/files-test-client")
    return status.json()["auth_token"]


async def _insert_file(test_db, library_id: str | None = None) -> str:
    """Insert a media_files row directly; return the file id."""
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, duration_sec,
             library_id, tmdb_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            file_id,
            f"/media/movies/{file_id}.mp4",
            "test.mp4",
            ".mp4",
            1024000,
            120.5,
            library_id,
            None,
            now,
            now,
        ),
    )
    await test_db.commit()
    return file_id


# ── GET /api/v1/files ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_files_requires_auth(client: AsyncClient):
    response = await client.get("/api/v1/files")
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_list_files_empty(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    response = await client.get(
        "/api/v1/files", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_list_files_returns_inserted_file(
    client: AsyncClient, monkeypatch, test_db
):
    token = await _get_token(client, monkeypatch)
    await _insert_file(test_db)

    response = await client.get(
        "/api/v1/files", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    files = response.json()
    assert len(files) == 1
    assert files[0]["name"] == "test.mp4"
    assert files[0]["extension"] == ".mp4"
    assert files[0]["size_bytes"] == 1024000


@pytest.mark.asyncio
async def test_list_files_filter_by_library(client: AsyncClient, monkeypatch, test_db):
    import json

    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    lib_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?,?,?,?,?)",
        (lib_id, "Movies", "movies", json.dumps(["/media"]), now),
    )
    await test_db.commit()

    await _insert_file(test_db, library_id=lib_id)
    await _insert_file(test_db, library_id=None)

    all_files = (await client.get("/api/v1/files", headers=headers)).json()
    assert len(all_files) == 2

    url = f"/api/v1/files?library_id={lib_id}"
    filtered = (await client.get(url, headers=headers)).json()
    assert len(filtered) == 1
    assert filtered[0]["library_id"] == lib_id


# ── GET /api/v1/files/{id} ───────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_file_by_id(client: AsyncClient, monkeypatch, test_db):
    token = await _get_token(client, monkeypatch)
    file_id = await _insert_file(test_db)

    response = await client.get(
        f"/api/v1/files/{file_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == file_id
    assert data["duration_sec"] == pytest.approx(120.5)


@pytest.mark.asyncio
async def test_get_file_not_found(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    response = await client.get(
        "/api/v1/files/nonexistent-id",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404
