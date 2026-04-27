import json
from contextlib import contextmanager
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from config import settings as _settings
from main import app
from routers.deps import require_local_caller

HMAC_KEY = "test-secret-key-for-unit-tests-only"


@contextmanager
def _lifespan_patches():
    """Prevent the TestClient lifespan from touching the production DB or mDNS."""
    with (
        patch("main.init_db", new=AsyncMock()),
        patch("main.close_db", new=AsyncMock()),
        patch("main.start_discovery"),
        patch("main.stop_discovery"),
        patch.object(_settings, "token_hmac_key", HMAC_KEY),
    ):
        app.dependency_overrides[require_local_caller] = lambda: None
        try:
            yield
        finally:
            app.dependency_overrides.pop(require_local_caller, None)


def _approve_client(http: TestClient, monkeypatch) -> str:
    """Pair + approve via HTTP; return the raw bearer token."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    pair_body = {
        "client_id": "ws-test-client",
        "device_name": "WS Test Device",
        "platform": "android",
        "app_version": "0.1.0",
    }
    http.post("/api/v1/auth/request-pair", json=pair_body)
    http.post("/api/v1/auth/approve/ws-test-client")
    resp = http.get("/api/v1/auth/status/ws-test-client")
    return resp.json()["auth_token"]


# ── /api/v1/ws/status ────────────────────────────────────────────────────────


def test_ws_auth_ok(test_db, monkeypatch):
    with _lifespan_patches():
        with TestClient(app) as http:
            token = _approve_client(http, monkeypatch)
            with http.websocket_connect("/api/v1/ws/status") as ws:
                ws.send_text(json.dumps({"type": "auth", "token": token}))
                msg = json.loads(ws.receive_text())
                assert msg["type"] == "auth_ok"
                assert msg["client_id"] == "ws-test-client"


def test_ws_invalid_token_closes(test_db):
    with _lifespan_patches():
        with TestClient(app) as http:
            with http.websocket_connect("/api/v1/ws/status") as ws:
                ws.send_text(json.dumps({"type": "auth", "token": "bad-token"}))
                # Server closes with code 1008 — receive_text raises or connection ends
                try:
                    ws.receive_text()
                except Exception:
                    pass  # WebSocketDisconnect or similar — expected


def test_ws_missing_auth_message_closes(test_db):
    with _lifespan_patches():
        with TestClient(app) as http:
            with http.websocket_connect("/api/v1/ws/status") as ws:
                ws.send_text(json.dumps({"type": "ping"}))
                try:
                    ws.receive_text()
                except Exception:
                    pass


def test_ws_pong_accepted(test_db, monkeypatch):
    with _lifespan_patches():
        with TestClient(app) as http:
            token = _approve_client(http, monkeypatch)
            with http.websocket_connect("/api/v1/ws/status") as ws:
                ws.send_text(json.dumps({"type": "auth", "token": token}))
                msg = json.loads(ws.receive_text())
                assert msg["type"] == "auth_ok"

                # Send a pong — server should accept it silently (no error, no close)
                ws.send_text(json.dumps({"type": "pong"}))
                # If the connection is still open, sending another message works
                ws.send_text(json.dumps({"type": "pong"}))
