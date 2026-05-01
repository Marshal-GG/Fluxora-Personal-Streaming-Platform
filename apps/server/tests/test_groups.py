"""Tests for /api/v1/groups and the stream-gate restriction enforcement."""

from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import patch

import pytest
from httpx import ASGITransport, AsyncClient

from main import app

HMAC_KEY = "test-secret-key-for-unit-tests-only"


# ── helpers ────────────────────────────────────────────────────────────────


async def _get_token(client: AsyncClient, monkeypatch, client_id: str) -> str:
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    await client.post(
        "/api/v1/auth/request-pair",
        json={
            "client_id": client_id,
            "device_name": f"dev-{client_id}",
            "platform": "android",
            "app_version": "0.1.0",
        },
    )
    await client.post(f"/api/v1/auth/approve/{client_id}")
    resp = await client.get(f"/api/v1/auth/status/{client_id}")
    return resp.json()["auth_token"]


async def _insert_file_with_library(test_db, library_id: str) -> str:
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    # Library row
    await test_db.execute(
        "INSERT OR IGNORE INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?, ?, ?, ?, ?)",
        (library_id, library_id, "movies", json.dumps([]), now),
    )
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, library_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            file_id,
            f"/media/{file_id}.mp4",
            "test.mp4",
            ".mp4",
            1024000,
            library_id,
            now,
            now,
        ),
    )
    await test_db.commit()
    return file_id


# ── CRUD ───────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_and_list_group(client: AsyncClient):
    resp = await client.post(
        "/api/v1/groups",
        json={
            "name": "Family",
            "description": "Living-room TV + bedrooms",
            "restrictions": {
                "allowed_libraries": ["lib-movies"],
                "bandwidth_cap_mbps": 25,
            },
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["name"] == "Family"
    assert body["status"] == "active"
    assert body["member_count"] == 0
    assert body["restrictions"]["allowed_libraries"] == ["lib-movies"]
    assert body["restrictions"]["bandwidth_cap_mbps"] == 25

    listing = await client.get("/api/v1/groups")
    assert listing.status_code == 200
    rows = listing.json()
    assert len(rows) == 1
    assert rows[0]["id"] == body["id"]


@pytest.mark.asyncio
async def test_get_group_404(client: AsyncClient):
    resp = await client.get("/api/v1/groups/nope")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_update_group_partial(client: AsyncClient):
    created = (await client.post("/api/v1/groups", json={"name": "Kids"})).json()
    gid = created["id"]

    resp = await client.patch(
        f"/api/v1/groups/{gid}",
        json={"description": "After-school only", "status": "inactive"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["name"] == "Kids"  # untouched
    assert body["description"] == "After-school only"
    assert body["status"] == "inactive"


@pytest.mark.asyncio
async def test_update_group_replaces_restrictions(client: AsyncClient):
    created = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "Guests",
                "restrictions": {"bandwidth_cap_mbps": 10},
            },
        )
    ).json()
    gid = created["id"]

    resp = await client.patch(
        f"/api/v1/groups/{gid}",
        json={
            "restrictions": {
                "time_window": {"start_h": 18, "end_h": 23, "days": [4, 5, 6]}
            }
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    # restriction body fully replaces — so bandwidth cap is now None
    assert body["restrictions"]["bandwidth_cap_mbps"] is None
    assert body["restrictions"]["time_window"]["start_h"] == 18
    assert body["restrictions"]["time_window"]["days"] == [4, 5, 6]


@pytest.mark.asyncio
async def test_delete_group_cascades(client: AsyncClient, test_db):
    created = (await client.post("/api/v1/groups", json={"name": "tmp"})).json()
    gid = created["id"]

    # restriction row should exist
    async with test_db.execute(
        "SELECT COUNT(*) FROM group_restrictions WHERE group_id = ?", (gid,)
    ) as cur:
        before = (await cur.fetchone())[0]
    assert before == 1

    resp = await client.delete(f"/api/v1/groups/{gid}")
    assert resp.status_code == 204

    async with test_db.execute(
        "SELECT COUNT(*) FROM group_restrictions WHERE group_id = ?", (gid,)
    ) as cur:
        after = (await cur.fetchone())[0]
    assert after == 0  # ON DELETE CASCADE


@pytest.mark.asyncio
async def test_delete_group_404(client: AsyncClient):
    resp = await client.delete("/api/v1/groups/nope")
    assert resp.status_code == 404


# ── Members ────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_member_add_remove(client: AsyncClient, monkeypatch):
    await _get_token(client, monkeypatch, "cli-1")
    group = (await client.post("/api/v1/groups", json={"name": "g"})).json()
    gid = group["id"]

    add = await client.post(
        f"/api/v1/groups/{gid}/members", json={"client_id": "cli-1"}
    )
    assert add.status_code == 204

    listing = await client.get(f"/api/v1/groups/{gid}/members")
    assert listing.status_code == 200
    members = listing.json()
    assert len(members) == 1
    assert members[0]["id"] == "cli-1"

    # member_count rolls up onto group response
    detail = await client.get(f"/api/v1/groups/{gid}")
    assert detail.json()["member_count"] == 1

    # remove
    rem = await client.delete(f"/api/v1/groups/{gid}/members/cli-1")
    assert rem.status_code == 204

    again = await client.get(f"/api/v1/groups/{gid}/members")
    assert again.json() == []


@pytest.mark.asyncio
async def test_member_add_unknown_client(client: AsyncClient):
    group = (await client.post("/api/v1/groups", json={"name": "g"})).json()
    resp = await client.post(
        f"/api/v1/groups/{group['id']}/members",
        json={"client_id": "ghost"},
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_member_add_idempotent(client: AsyncClient, monkeypatch):
    await _get_token(client, monkeypatch, "cli-2")
    group = (await client.post("/api/v1/groups", json={"name": "g"})).json()
    gid = group["id"]

    for _ in range(3):
        resp = await client.post(
            f"/api/v1/groups/{gid}/members", json={"client_id": "cli-2"}
        )
        assert resp.status_code == 204

    listing = await client.get(f"/api/v1/groups/{gid}/members")
    assert len(listing.json()) == 1


# ── Authorization ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_requires_localhost(test_db):
    """Tunneled requests must be rejected at the require_local_caller gate."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("203.0.113.7", 50000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.post(
            "/api/v1/groups",
            json={"name": "x"},
            headers={"CF-Connecting-IP": "203.0.113.7"},
        )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_list_allows_token_off_loopback(monkeypatch, client: AsyncClient):
    """Off-loopback callers may list groups with a valid bearer token."""
    token = await _get_token(client, monkeypatch, "cli-lan")
    # Seed at least one group so the response is non-empty
    await client.post("/api/v1/groups", json={"name": "anything"})

    async with AsyncClient(
        transport=ASGITransport(app=app, client=("192.168.1.50", 40000)),
        base_url="http://test",
    ) as lan:
        resp = await lan.get(
            "/api/v1/groups",
            headers={"Authorization": f"Bearer {token}"},
        )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


# ── Stream-gate enforcement ────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_stream_blocked_when_library_not_in_allowed_set(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}

    file_id = await _insert_file_with_library(test_db, "lib-restricted")

    group = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "kids",
                "restrictions": {"allowed_libraries": ["lib-other"]},
            },
        )
    ).json()
    await client.post(
        f"/api/v1/groups/{group['id']}/members",
        json={"client_id": "stream-test-client"},
    )

    async def _mock_start(file_path: str, session_id: str, hls_root: Path) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 403
    assert "library" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_stream_allowed_when_library_in_allowed_set(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}

    file_id = await _insert_file_with_library(test_db, "lib-allowed")

    group = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "ok",
                "restrictions": {"allowed_libraries": ["lib-allowed", "lib-other"]},
            },
        )
    ).json()
    await client.post(
        f"/api/v1/groups/{group['id']}/members",
        json={"client_id": "stream-test-client"},
    )

    async def _mock_start(file_path: str, session_id: str, hls_root: Path) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_stream_blocked_outside_time_window(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file_with_library(test_db, "lib-x")

    # Window with no allowed days → outside-window for every weekday
    group = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "late-night-only",
                "restrictions": {"time_window": {"start_h": 0, "end_h": 1, "days": []}},
            },
        )
    ).json()
    await client.post(
        f"/api/v1/groups/{group['id']}/members",
        json={"client_id": "stream-test-client"},
    )

    async def _mock_start(file_path: str, session_id: str, hls_root: Path) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 403
    assert "window" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_stream_unrestricted_when_inactive_group(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """Restrictions on an `inactive` group must NOT apply."""
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file_with_library(test_db, "lib-x")

    group = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "deactivated",
                "restrictions": {"allowed_libraries": ["lib-other"]},
            },
        )
    ).json()
    await client.post(
        f"/api/v1/groups/{group['id']}/members",
        json={"client_id": "stream-test-client"},
    )
    await client.patch(f"/api/v1/groups/{group['id']}", json={"status": "inactive"})

    async def _mock_start(file_path: str, session_id: str, hls_root: Path) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_intersection_of_allowed_libraries_across_groups(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """Two groups → their `allowed_libraries` intersect."""
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}

    # The file is in lib-movies. Group A allows {lib-movies, lib-tv};
    # Group B allows {lib-tv, lib-music}. Intersection = {lib-tv}, so the
    # stream must be blocked.
    file_id = await _insert_file_with_library(test_db, "lib-movies")

    grp_a = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "A",
                "restrictions": {"allowed_libraries": ["lib-movies", "lib-tv"]},
            },
        )
    ).json()
    grp_b = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "B",
                "restrictions": {"allowed_libraries": ["lib-tv", "lib-music"]},
            },
        )
    ).json()
    for gid in (grp_a["id"], grp_b["id"]):
        await client.post(
            f"/api/v1/groups/{gid}/members",
            json={"client_id": "stream-test-client"},
        )

    async def _mock_start(file_path: str, session_id: str, hls_root: Path) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 403
