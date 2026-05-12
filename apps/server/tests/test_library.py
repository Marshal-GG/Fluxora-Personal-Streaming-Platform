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
async def test_list_libraries_local_access_without_auth(client: AsyncClient):
    # library endpoint uses validate_token_or_local — localhost needs no bearer token
    response = await client.get("/api/v1/library")
    assert response.status_code == 200
    assert response.json() == []


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
    assert data["total_size_bytes"] == 0
    assert data["cover_urls"] == []
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


# ── PATCH /api/v1/library/{id} ───────────────────────────────────────────────


@pytest.mark.asyncio
async def test_patch_library_rename(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    created = (
        await client.post("/api/v1/library", json=CREATE_BODY, headers=headers)
    ).json()
    library_id = created["id"]

    response = await client.patch(
        f"/api/v1/library/{library_id}",
        json={"name": "Renamed Movies"},
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["name"] == "Renamed Movies"
    assert response.json()["root_paths"] == ["/media/movies", "/nas/movies"]


@pytest.mark.asyncio
async def test_patch_library_change_roots(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    created = (
        await client.post("/api/v1/library", json=CREATE_BODY, headers=headers)
    ).json()
    library_id = created["id"]

    response = await client.patch(
        f"/api/v1/library/{library_id}",
        json={"root_paths": ["/new/movies"]},
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["root_paths"] == ["/new/movies"]
    assert response.json()["name"] == "My Movies"


@pytest.mark.asyncio
async def test_patch_library_empty_body(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    created = (
        await client.post("/api/v1/library", json=CREATE_BODY, headers=headers)
    ).json()

    response = await client.patch(
        f"/api/v1/library/{created['id']}",
        json={},
        headers=headers,
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_patch_library_empty_name(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    created = (
        await client.post("/api/v1/library", json=CREATE_BODY, headers=headers)
    ).json()

    response = await client.patch(
        f"/api/v1/library/{created['id']}",
        json={"name": "  "},
        headers=headers,
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_patch_library_empty_roots(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    created = (
        await client.post("/api/v1/library", json=CREATE_BODY, headers=headers)
    ).json()

    response = await client.patch(
        f"/api/v1/library/{created['id']}",
        json={"root_paths": []},
        headers=headers,
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_patch_library_not_found(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}

    response = await client.patch(
        "/api/v1/library/nonexistent-id",
        json={"name": "x"},
        headers=headers,
    )
    assert response.status_code == 404


# ── Plan 19 §M8 — per-library codec passthrough overrides ─────────────────


@pytest.mark.asyncio
async def test_patch_library_sets_av1_override_true(client: AsyncClient):
    created = (await client.post("/api/v1/library", json=CREATE_BODY)).json()
    library_id = created["id"]
    res = await client.patch(
        f"/api/v1/library/{library_id}",
        json={"av1_stream_copy_override": True},
    )
    assert res.status_code == 200
    assert res.json()["av1_stream_copy_override"] is True


@pytest.mark.asyncio
async def test_patch_library_sets_vp9_override_false(client: AsyncClient):
    created = (await client.post("/api/v1/library", json=CREATE_BODY)).json()
    library_id = created["id"]
    res = await client.patch(
        f"/api/v1/library/{library_id}",
        json={"vp9_stream_copy_override": False},
    )
    assert res.status_code == 200
    assert res.json()["vp9_stream_copy_override"] is False


@pytest.mark.asyncio
async def test_patch_library_clears_override_with_explicit_null(
    client: AsyncClient,
):
    """Setting the override to null on the wire clears it back to
    inherit-global (3-state).  Field absence means "don't change"."""
    created = (await client.post("/api/v1/library", json=CREATE_BODY)).json()
    library_id = created["id"]
    # First pin to True.
    await client.patch(
        f"/api/v1/library/{library_id}",
        json={"av1_stream_copy_override": True},
    )
    # Now clear back to inherit.
    res = await client.patch(
        f"/api/v1/library/{library_id}",
        json={"av1_stream_copy_override": None},
    )
    assert res.status_code == 200
    assert res.json()["av1_stream_copy_override"] is None


@pytest.mark.asyncio
async def test_get_library_returns_override_fields(client: AsyncClient):
    created = (await client.post("/api/v1/library", json=CREATE_BODY)).json()
    library_id = created["id"]
    res = await client.get(f"/api/v1/library/{library_id}")
    assert res.status_code == 200
    body = res.json()
    # Defaults to None / inherit until explicitly pinned.
    assert body["av1_stream_copy_override"] is None
    assert body["vp9_stream_copy_override"] is None


@pytest.mark.asyncio
async def test_delete_library_unlinks_sidecars_by_default(
    client: AsyncClient, test_db, tmp_path
):
    import uuid as _uuid
    from datetime import UTC, datetime

    created = (await client.post("/api/v1/library", json=CREATE_BODY)).json()
    library_id = created["id"]

    sidecar = tmp_path / "movie.h264.mkv"
    sidecar.write_bytes(b"sidecar")
    fid = str(_uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes,
             library_id, transcoded_path, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            fid,
            "/src/movie.mkv",
            "movie.mkv",
            ".mkv",
            1,
            library_id,
            str(sidecar),
            now,
            now,
        ),
    )
    await test_db.commit()

    res = await client.delete(f"/api/v1/library/{library_id}")
    assert res.status_code == 204
    assert not sidecar.exists()


@pytest.mark.asyncio
async def test_delete_library_preserves_sidecars_when_query_false(
    client: AsyncClient, test_db, tmp_path
):
    import uuid as _uuid
    from datetime import UTC, datetime

    created = (await client.post("/api/v1/library", json=CREATE_BODY)).json()
    library_id = created["id"]

    sidecar = tmp_path / "movie.h264.mkv"
    sidecar.write_bytes(b"sidecar")
    fid = str(_uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes,
             library_id, transcoded_path, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            fid,
            "/src/movie.mkv",
            "movie.mkv",
            ".mkv",
            1,
            library_id,
            str(sidecar),
            now,
            now,
        ),
    )
    await test_db.commit()

    res = await client.delete(f"/api/v1/library/{library_id}?delete_sidecars=false")
    assert res.status_code == 204
    assert sidecar.exists()
