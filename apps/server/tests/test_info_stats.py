"""Tests for GET /api/v1/info/stats and the /ws/stats live stream."""

from __future__ import annotations

import json
from contextlib import contextmanager
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from config import settings as _settings
from main import app
from services.system_stats_service import SystemStatsService

HMAC_KEY = "test-secret-key-for-unit-tests-only"


@contextmanager
def _lifespan_patches():
    """Prevent the TestClient lifespan from touching production DB / mDNS."""
    with (
        patch("main.init_db", new=AsyncMock()),
        patch("main.close_db", new=AsyncMock()),
        patch("main.start_discovery"),
        patch("main.stop_discovery"),
        patch.object(_settings, "token_hmac_key", HMAC_KEY),
    ):
        yield


# ── REST: GET /api/v1/info/stats ─────────────────────────────────────────────


async def test_info_stats_returns_expected_shape(client, test_db):
    resp = await client.get("/api/v1/info/stats")
    assert resp.status_code == 200
    body = resp.json()

    expected_keys = {
        "uptime_seconds",
        "lan_ip",
        "public_address",
        "internet_connected",
        "cpu_percent",
        "ram_percent",
        "ram_used_bytes",
        "ram_total_bytes",
        "network_in_mbps",
        "network_out_mbps",
        "active_streams",
    }
    assert set(body.keys()) == expected_keys

    assert body["uptime_seconds"] >= 0
    assert isinstance(body["internet_connected"], bool)
    assert 0.0 <= body["cpu_percent"] <= 100.0
    assert 0.0 <= body["ram_percent"] <= 100.0
    assert body["ram_used_bytes"] >= 0
    assert (
        body["ram_total_bytes"] > body["ram_used_bytes"]
        or body["ram_total_bytes"] == body["ram_used_bytes"]
    )
    assert body["network_in_mbps"] >= 0.0
    assert body["network_out_mbps"] >= 0.0
    assert body["active_streams"] >= 0


async def test_info_stats_first_call_zero_network_rate(client, test_db):
    """First call has no rate baseline → both rates must be 0.0 exactly."""
    # Use a fresh service instance to guarantee no prior baseline
    fresh = SystemStatsService()
    payload = await fresh.collect(test_db)
    assert payload["network_in_mbps"] == 0.0
    assert payload["network_out_mbps"] == 0.0


async def test_info_stats_active_streams_counts_open_sessions(client, test_db):
    """One open session in stream_sessions → active_streams == 1."""
    await test_db.execute(
        "INSERT INTO clients (id, name, platform, last_seen, is_trusted, auth_token)"
        " VALUES ('c1', 'Test', 'android', '2026-01-01T00:00:00Z', 1, 'hash')"
    )
    await test_db.execute(
        "INSERT INTO media_files (id, path, name, extension, size_bytes)"
        " VALUES ('f1', '/test/movie.mkv', 'movie.mkv', 'mkv', 1000)"
    )
    await test_db.execute(
        "INSERT INTO stream_sessions"
        " (id, client_id, file_id, started_at, ended_at, connection_type)"
        " VALUES ('s1', 'c1', 'f1', '2026-01-01T00:00:00Z', NULL, 'lan')"
    )
    await test_db.commit()

    resp = await client.get("/api/v1/info/stats")
    assert resp.status_code == 200
    assert resp.json()["active_streams"] == 1


# ── WS: /api/v1/ws/stats — localhost path ────────────────────────────────────


def test_ws_stats_localhost_no_auth(test_db):
    """Localhost connection skips the auth handshake and starts streaming."""
    with _lifespan_patches():
        # Starlette TestClient reports client.host == "testclient", which
        # is not in LOOPBACK. Treat the test connection as local.
        with patch("routers.ws._is_local_websocket", return_value=True):
            with TestClient(app) as http:
                with http.websocket_connect("/api/v1/ws/stats") as ws:
                    msg = json.loads(ws.receive_text())
                    assert msg["type"] == "stats"
                    assert "data" in msg
                    assert "cpu_percent" in msg["data"]
                    assert "active_streams" in msg["data"]


def test_ws_stats_non_localhost_requires_auth(test_db):
    """Non-localhost connection without auth handshake → 1008 close."""
    with _lifespan_patches():
        with patch("routers.ws._is_local_websocket", return_value=False):
            with TestClient(app) as http:
                from starlette.websockets import WebSocketDisconnect

                try:
                    with http.websocket_connect("/api/v1/ws/stats") as ws:
                        ws.send_text(json.dumps({"type": "ping"}))
                        ws.receive_text()
                except WebSocketDisconnect as exc:
                    assert exc.code == 1008
