import uuid
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

HMAC_KEY = "test-secret-key-for-unit-tests-only"


async def _get_token(client: AsyncClient, monkeypatch) -> str:
    """Pair and approve a test client; return the bearer token."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    pair_body = {
        "client_id": "stream-test-client",
        "device_name": "Test Device",
        "platform": "android",
        "app_version": "0.1.0",
    }
    await client.post("/api/v1/auth/request-pair", json=pair_body)
    await client.post("/api/v1/auth/approve/stream-test-client")
    status = await client.get("/api/v1/auth/status/stream-test-client")
    return status.json()["auth_token"]


async def _insert_file(test_db) -> str:
    """Insert a media file and return its id."""
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (file_id, f"/media/{file_id}.mp4", "test.mp4", ".mp4", 1024000, now, now),
    )
    await test_db.commit()
    return file_id


def _mock_start_stream(playlist_path: Path):
    """Return an async mock that writes a minimal m3u8 and resolves to playlist_path."""

    async def _start(file_path: str, session_id: str, hls_root: Path) -> Path:
        playlist_path.parent.mkdir(parents=True, exist_ok=True)
        playlist_path.write_text("#EXTM3U\n#EXT-X-VERSION:3\n")
        return playlist_path

    return _start


# ── POST /api/v1/stream/start/{file_id} ─────────────────────────────────────


@pytest.mark.asyncio
async def test_start_stream_requires_auth(client: AsyncClient, test_db):
    file_id = await _insert_file(test_db)
    response = await client.post(f"/api/v1/stream/start/{file_id}")
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_start_stream_file_not_found(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    with patch("routers.stream.ffmpeg_service.start_stream", new_callable=AsyncMock):
        response = await client.post(
            "/api/v1/stream/start/nonexistent-id",
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_start_stream_ffmpeg_not_found(client: AsyncClient, monkeypatch, test_db):
    token = await _get_token(client, monkeypatch)
    file_id = await _insert_file(test_db)

    async def _raise(*args, **kwargs):
        raise FileNotFoundError("FFmpeg not found")

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_raise):
        response = await client.post(
            f"/api/v1/stream/start/{file_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 503
    assert "FFmpeg" in response.json()["detail"]


@pytest.mark.asyncio
async def test_start_stream_success(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    token = await _get_token(client, monkeypatch)
    file_id = await _insert_file(test_db)

    captured_session_id: list[str] = []

    async def _mock_start(file_path: str, session_id: str, hls_root: Path) -> Path:
        captured_session_id.append(session_id)
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        response = await client.post(
            f"/api/v1/stream/start/{file_id}",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 201
    data = response.json()
    assert data["file_id"] == file_id
    assert "session_id" in data
    assert "playlist.m3u8" in data["playlist_url"]
    assert data["session_id"] == captured_session_id[0]


# ── GET /api/v1/stream/{session_id} ─────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_session(client: AsyncClient, monkeypatch, test_db, tmp_path):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    response = await client.get(f"/api/v1/stream/{session_id}", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == session_id
    assert data["file_id"] == file_id
    assert data["ended_at"] is None


@pytest.mark.asyncio
async def test_get_session_not_found(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    response = await client.get(
        "/api/v1/stream/nonexistent-id",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404


# ── DELETE /api/v1/stream/{session_id} ──────────────────────────────────────


@pytest.mark.asyncio
async def test_stop_stream(client: AsyncClient, monkeypatch, test_db, tmp_path):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    with (
        patch(
            "routers.stream.ffmpeg_service.stop_stream",
            new_callable=AsyncMock,
        ) as mock_stop,
        patch("routers.stream.ffmpeg_service.cleanup_session_dir") as mock_clean,
    ):
        response = await client.delete(f"/api/v1/stream/{session_id}", headers=headers)

    assert response.status_code == 204
    mock_stop.assert_awaited_once_with(session_id)
    mock_clean.assert_called_once()

    # Session should now show ended_at
    get_resp = await client.get(f"/api/v1/stream/{session_id}", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["ended_at"] is not None


@pytest.mark.asyncio
async def test_stop_stream_wrong_client(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """A second client cannot stop another client's session."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)

    # Pair a second client
    await client.post(
        "/api/v1/auth/request-pair",
        json={
            "client_id": "other-client",
            "device_name": "Other",
            "platform": "ios",
            "app_version": "0.1.0",
        },
    )
    await client.post("/api/v1/auth/approve/other-client")
    other_status = await client.get("/api/v1/auth/status/other-client")
    other_token = other_status.json()["auth_token"]

    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    response = await client.delete(
        f"/api/v1/stream/{session_id}",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert response.status_code == 403


# ── HLS serving ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_serve_hls_playlist(client: AsyncClient, monkeypatch, test_db, tmp_path):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n#EXT-X-VERSION:3\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    # Point HLS router at the tmp_path where mock wrote the file
    with patch("routers.stream.settings") as mock_settings:
        mock_settings.hls_tmp_path = tmp_path
        response = await client.get(
            f"/api/v1/hls/{session_id}/playlist.m3u8", headers=headers
        )

    assert response.status_code == 200
    assert "EXTM3U" in response.text


@pytest.mark.asyncio
async def test_serve_hls_path_traversal_rejected(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    response = await client.get(
        "/api/v1/hls/some-session/../../../etc/passwd",
        headers={"Authorization": f"Bearer {token}"},
    )
    # FastAPI decodes %2F but the path parameter itself should be blocked
    assert response.status_code in {400, 404, 422}
