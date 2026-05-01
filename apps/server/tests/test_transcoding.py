"""Tests for /api/v1/transcoding/status."""

from __future__ import annotations

from unittest.mock import patch

import pytest
from httpx import ASGITransport, AsyncClient

from main import app
from services import transcoding_service


@pytest.fixture(autouse=True)
def _reset_encoder_cache():
    """Clear the process-wide available-encoders cache between tests."""
    transcoding_service._AVAILABLE_CACHE = None
    yield
    transcoding_service._AVAILABLE_CACHE = None


@pytest.mark.asyncio
async def test_status_returns_default_shape(client: AsyncClient):
    """Empty server, no FFmpeg installed → still returns a coherent payload."""
    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=["libx264"],
        ),
        patch.object(transcoding_service, "_probe_nvidia", return_value=(None, None)),
    ):
        resp = await client.get("/api/v1/transcoding/status")
    assert resp.status_code == 200
    body = resp.json()
    assert body["active_encoder"] == "libx264"
    assert body["available_encoders"] == ["libx264"]
    assert body["active_sessions"] == []
    # encoder_loads has at least one entry, no live sessions
    loads = {row["encoder"]: row for row in body["encoder_loads"]}
    assert loads["libx264"]["active_sessions"] == 0


@pytest.mark.asyncio
async def test_status_lists_known_intersection(client: AsyncClient):
    """Available encoders = intersection of known × ffmpeg-reports."""
    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=["libx264", "h264_nvenc"],
        ),
        patch.object(transcoding_service, "_probe_nvidia", return_value=(None, None)),
    ):
        resp = await client.get("/api/v1/transcoding/status")
    body = resp.json()
    encs = body["available_encoders"]
    assert "libx264" in encs
    assert "h264_nvenc" in encs
    assert "h264_qsv" not in encs


@pytest.mark.asyncio
async def test_nvidia_probe_populates_load_when_active(client: AsyncClient, test_db):
    """When configured encoder is h264_nvenc and probe returns data, those
    fields populate; when active_encoder is libx264, the NVENC row stays null
    (probe only runs for the active encoder)."""
    # Switch the configured encoder to NVENC
    await test_db.execute(
        "UPDATE user_settings SET transcoding_encoder = 'h264_nvenc' WHERE id = 1"
    )
    await test_db.commit()

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=["libx264", "h264_nvenc"],
        ),
        patch.object(transcoding_service, "_probe_nvidia", return_value=(34.0, 580)),
    ):
        resp = await client.get("/api/v1/transcoding/status")
    body = resp.json()
    nvenc = next(row for row in body["encoder_loads"] if row["encoder"] == "h264_nvenc")
    assert nvenc["gpu_utilization_percent"] == 34.0
    assert nvenc["vram_used_mb"] == 580


@pytest.mark.asyncio
async def test_active_sessions_join_media_and_clients(client: AsyncClient, test_db):
    """An active session should surface media_title and client_name + a
    clamped progress fraction."""
    # Seed a client + media file + active session
    await test_db.execute(
        "INSERT INTO clients"
        " (id, name, platform, last_seen, is_trusted, auth_token, status)"
        " VALUES ('c1', 'Living Room TV', 'android',"
        " '2026-05-01T00:00:00Z', 1, 'h', 'approved')"
    )
    await test_db.execute(
        "INSERT INTO media_files (id, path, name, extension, size_bytes,"
        " title, duration_sec, last_progress_sec)"
        " VALUES ('f1', '/m.mkv', 'Inception.mkv', 'mkv', 1, 'Inception',"
        " 7200, 1800)"
    )
    await test_db.execute(
        "INSERT INTO stream_sessions"
        " (id, file_id, client_id, started_at, progress_sec, connection_type)"
        " VALUES ('sess-1', 'f1', 'c1', '2026-05-01T00:00:00Z', 1800, 'lan')"
    )
    await test_db.commit()

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=["libx264"],
        ),
        patch.object(transcoding_service, "_probe_nvidia", return_value=(None, None)),
    ):
        resp = await client.get("/api/v1/transcoding/status")
    body = resp.json()
    sessions = body["active_sessions"]
    assert len(sessions) == 1
    s = sessions[0]
    assert s["id"] == "sess-1"
    assert s["client_name"] == "Living Room TV"
    assert s["media_title"] == "Inception"
    assert s["progress"] == pytest.approx(0.25)


@pytest.mark.asyncio
async def test_progress_null_when_no_duration(client: AsyncClient, test_db):
    await test_db.execute(
        "INSERT INTO clients"
        " (id, name, platform, last_seen, is_trusted, auth_token, status)"
        " VALUES ('c2', 'Phone', 'ios',"
        " '2026-05-01T00:00:00Z', 1, 'h', 'approved')"
    )
    await test_db.execute(
        "INSERT INTO media_files (id, path, name, extension, size_bytes)"
        " VALUES ('f2', '/m.mkv', 'unknown.mkv', 'mkv', 1)"
    )
    await test_db.execute(
        "INSERT INTO stream_sessions"
        " (id, file_id, client_id, started_at, progress_sec, connection_type)"
        " VALUES ('sess-2', 'f2', 'c2', '2026-05-01T00:00:00Z', 100, 'lan')"
    )
    await test_db.commit()
    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=["libx264"],
        ),
        patch.object(transcoding_service, "_probe_nvidia", return_value=(None, None)),
    ):
        resp = await client.get("/api/v1/transcoding/status")
    s = resp.json()["active_sessions"][0]
    assert s["progress"] is None


@pytest.mark.asyncio
async def test_status_requires_localhost(test_db):
    """Tunneled / off-loopback caller is rejected (admin endpoint)."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("203.0.113.7", 50000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.get(
            "/api/v1/transcoding/status",
            headers={"CF-Connecting-IP": "203.0.113.7"},
        )
    assert resp.status_code == 403
