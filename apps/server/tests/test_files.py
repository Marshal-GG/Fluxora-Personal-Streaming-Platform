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
async def test_list_files_local_access_without_auth(client: AsyncClient):
    # files endpoint uses validate_token_or_local — localhost needs no bearer token
    response = await client.get("/api/v1/files")
    assert response.status_code == 200
    assert response.json() == []


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


# ── GET /api/v1/files/recent ─────────────────────────────────────────────────


async def _insert_file_at(test_db, name: str, created_at: str) -> str:
    """Insert a media_files row with an explicit created_at; return file id."""
    file_id = str(uuid.uuid4())
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
            name,
            ".mp4",
            1024,
            None,
            None,
            None,
            created_at,
            created_at,
        ),
    )
    await test_db.commit()
    return file_id


@pytest.mark.asyncio
async def test_recent_files_orders_newest_first(
    client: AsyncClient, monkeypatch, test_db
):
    token = await _get_token(client, monkeypatch)
    await _insert_file_at(test_db, "old.mp4", "2024-01-01T00:00:00Z")
    await _insert_file_at(test_db, "mid.mp4", "2025-06-15T00:00:00Z")
    await _insert_file_at(test_db, "new.mp4", "2026-05-01T00:00:00Z")

    resp = await client.get(
        "/api/v1/files/recent",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    rows = resp.json()
    assert [r["name"] for r in rows] == ["new.mp4", "mid.mp4", "old.mp4"]


@pytest.mark.asyncio
async def test_recent_files_respects_limit(client: AsyncClient, monkeypatch, test_db):
    token = await _get_token(client, monkeypatch)
    for i in range(5):
        await _insert_file_at(test_db, f"f{i}.mp4", f"2026-05-0{i + 1}T00:00:00Z")

    resp = await client.get(
        "/api/v1/files/recent?limit=2",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert len(resp.json()) == 2


@pytest.mark.asyncio
async def test_recent_files_clamps_oversized_limit(client: AsyncClient, monkeypatch):
    await _get_token(client, monkeypatch)
    # FastAPI's Query(le=50) returns 422 for limit > 50; the mobile client
    # must not be able to ask for an unbounded recent feed.
    resp = await client.get(
        "/api/v1/files/recent?limit=999",
        headers={"Authorization": "Bearer x"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_recent_files_does_not_match_file_id_route(
    client: AsyncClient, monkeypatch, test_db
):
    """Sanity: `/files/recent` must hit list_recent_files, not get_file with
    file_id="recent". Route order in files.py guarantees this."""
    token = await _get_token(client, monkeypatch)
    resp = await client.get(
        "/api/v1/files/recent",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    # Returns a list, not a single object — proves the recent route won.
    assert isinstance(resp.json(), list)


# ── GET /api/v1/files/search (Phase B §3 row 2) ─────────────────────────────


async def _insert_named_file(test_db, *, name: str, title: str | None = None) -> str:
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, duration_sec,
             library_id, tmdb_id, title, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (file_id, f"/m/{name}", name, ".mp4", 1024, None, None, None, title, now, now),
    )
    await test_db.commit()
    return file_id


@pytest.mark.asyncio
async def test_search_matches_filename_substring(
    client: AsyncClient, monkeypatch, test_db
):
    token = await _get_token(client, monkeypatch)
    await _insert_named_file(test_db, name="Inception.mkv")
    await _insert_named_file(test_db, name="Interstellar.mkv")
    await _insert_named_file(test_db, name="The Martian.mkv")

    resp = await client.get(
        "/api/v1/files/search?q=inter",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    names = [f["name"] for f in resp.json()]
    assert names == ["Interstellar.mkv"]


@pytest.mark.asyncio
async def test_search_matches_tmdb_title_when_filename_doesnt(
    client: AsyncClient, monkeypatch, test_db
):
    token = await _get_token(client, monkeypatch)
    await _insert_named_file(test_db, name="abc123.mp4", title="Velvet Horizon")

    resp = await client.get(
        "/api/v1/files/search?q=velvet",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    files = resp.json()
    assert len(files) == 1
    assert files[0]["title"] == "Velvet Horizon"


@pytest.mark.asyncio
async def test_search_is_case_insensitive(client: AsyncClient, monkeypatch, test_db):
    token = await _get_token(client, monkeypatch)
    await _insert_named_file(test_db, name="Inception.mkv")

    resp = await client.get(
        "/api/v1/files/search?q=INCEPTION",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert len(resp.json()) == 1


@pytest.mark.asyncio
async def test_search_escapes_wildcards(client: AsyncClient, monkeypatch, test_db):
    """Searching for a literal `_` must match `_` only, not any character.
    The service escapes `_` and `%` before passing to LIKE."""
    token = await _get_token(client, monkeypatch)
    await _insert_named_file(test_db, name="season-1.mp4")
    await _insert_named_file(test_db, name="season_1.mp4")

    resp = await client.get(
        "/api/v1/files/search?q=season_",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    names = [f["name"] for f in resp.json()]
    assert names == ["season_1.mp4"]


@pytest.mark.asyncio
async def test_search_rejects_empty_query(client: AsyncClient, monkeypatch):
    await _get_token(client, monkeypatch)
    resp = await client.get(
        "/api/v1/files/search?q=",
        headers={"Authorization": "Bearer x"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_search_clamps_oversized_limit(client: AsyncClient, monkeypatch):
    await _get_token(client, monkeypatch)
    resp = await client.get(
        "/api/v1/files/search?q=anything&limit=999",
        headers={"Authorization": "Bearer x"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_search_does_not_match_file_id_route(client: AsyncClient, monkeypatch):
    """Sanity: `/files/search` must hit search_files, not get_file with
    file_id='search'.  Route order in files.py guarantees this."""
    token = await _get_token(client, monkeypatch)
    resp = await client.get(
        "/api/v1/files/search?q=nothing-matches",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert resp.json() == []


# ── POST /api/v1/files/{id}/reset-progress ───────────────────────────────────


async def _set_progress(test_db, file_id: str, sec: float) -> None:
    await test_db.execute(
        "UPDATE media_files SET last_progress_sec = ? WHERE id = ?",
        (sec, file_id),
    )
    await test_db.commit()


async def _read_progress(test_db, file_id: str) -> float | None:
    async with test_db.execute(
        "SELECT last_progress_sec FROM media_files WHERE id = ?", (file_id,),
    ) as cur:
        row = await cur.fetchone()
    return row["last_progress_sec"] if row else None


@pytest.mark.asyncio
async def test_reset_progress_zeros_last_progress_sec(
    client: AsyncClient, monkeypatch, test_db
):
    token = await _get_token(client, monkeypatch)
    file_id = await _insert_file(test_db)
    await _set_progress(test_db, file_id, 90.0)

    resp = await client.post(
        f"/api/v1/files/{file_id}/reset-progress",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 204
    assert await _read_progress(test_db, file_id) == 0.0


@pytest.mark.asyncio
async def test_reset_progress_404s_on_unknown_file(
    client: AsyncClient, monkeypatch
):
    token = await _get_token(client, monkeypatch)
    resp = await client.post(
        "/api/v1/files/no-such-file/reset-progress",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_reset_progress_local_caller_skips_visibility(
    client: AsyncClient, test_db
):
    """Localhost caller (no bearer token) should be able to reset
    progress on any file regardless of group visibility — same
    semantics as the get_file route."""
    file_id = await _insert_file(test_db)
    await _set_progress(test_db, file_id, 47.5)

    resp = await client.post(f"/api/v1/files/{file_id}/reset-progress")
    assert resp.status_code == 204
    assert await _read_progress(test_db, file_id) == 0.0


@pytest.mark.asyncio
async def test_reset_progress_404s_when_library_not_visible(
    client: AsyncClient, monkeypatch, test_db
):
    """A bearer-token caller whose groups don't expose the file's
    library should receive 404 (not 403, to avoid id enumeration of
    gated content) — same semantics as get_file.  We mock
    `group_service.get_visible_libraries` to return an empty set so
    the assertion holds independent of the test client's actual group
    state."""
    from unittest.mock import AsyncMock, patch
    from services.group_service import VisibleLibraries

    token = await _get_token(client, monkeypatch)

    library_id = str(uuid.uuid4())
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?, ?, ?, ?, ?)",
        (
            library_id,
            "Hidden",
            "movies",
            '["/hidden"]',
            datetime.now(UTC).isoformat(),
        ),
    )
    await test_db.commit()
    file_id = await _insert_file(test_db, library_id=library_id)
    await _set_progress(test_db, file_id, 30.0)

    empty_visible = VisibleLibraries(library_ids=frozenset(), groups=())
    with patch(
        "services.group_service.get_visible_libraries",
        new=AsyncMock(return_value=empty_visible),
    ):
        # CF-Connecting-IP forces the loopback dep onto the validate_token
        # path so the bearer token is actually consulted (and our `_client`
        # ends up non-None inside the route, firing the visibility check).
        resp = await client.post(
            f"/api/v1/files/{file_id}/reset-progress",
            headers={
                "Authorization": f"Bearer {token}",
                "CF-Connecting-IP": "203.0.113.1",
            },
        )
    assert resp.status_code == 404
    # Progress untouched.
    assert await _read_progress(test_db, file_id) == 30.0
