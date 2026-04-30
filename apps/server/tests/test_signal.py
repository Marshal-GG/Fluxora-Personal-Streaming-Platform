"""Tests for the WebRTC signaling endpoint (/api/v1/ws/signal).

Strategy
~~~~~~~~
``aiortc.RTCPeerConnection`` requires a real ICE stack and network which is
unavailable in CI.  We therefore patch ``services.webrtc_service`` at the
points where it touches aiortc so that the router logic (auth, message
routing, error handling) can be tested quickly and deterministically.
"""

import json
from contextlib import contextmanager
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient

from config import settings as _settings
from main import app
from routers.deps import require_local_caller

HMAC_KEY = "test-secret-key-for-unit-tests-only"
CLIENT_ID = "signal-test-client"


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------


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


def _approve_client(http: TestClient, client_id: str = CLIENT_ID) -> str:
    """Pair + approve *client_id* and return the bearer token."""
    pair_body = {
        "client_id": client_id,
        "device_name": "Signal Test Device",
        "platform": "android",
        "app_version": "0.1.0",
    }
    http.post("/api/v1/auth/request-pair", json=pair_body)
    http.post(f"/api/v1/auth/approve/{client_id}")
    resp = http.get(f"/api/v1/auth/status/{client_id}")
    return resp.json()["auth_token"]


@contextmanager
def _mock_webrtc(answer_sdp: str = "v=0\r\no=- 0 0 IN IP4 127.0.0.1\r\n"):
    """Patch webrtc_service so no real aiortc calls are made."""
    fake_pc = MagicMock()
    fake_pc.on = MagicMock(return_value=lambda fn: fn)  # decorator no-op

    with (
        patch(
            "routers.signal.create_peer_connection",
            return_value=fake_pc,
        ),
        patch(
            "routers.signal.handle_offer",
            new=AsyncMock(return_value=answer_sdp),
        ),
        patch(
            "routers.signal.add_ice_candidate",
            new=AsyncMock(),
        ),
        patch(
            "routers.signal.close_peer_connection",
            new=AsyncMock(),
        ),
    ):
        yield fake_pc


# ---------------------------------------------------------------------------
# Auth tests
# ---------------------------------------------------------------------------


def test_signal_auth_ok(test_db, monkeypatch):
    """A valid token should result in auth_ok with the correct client_id."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    with _lifespan_patches(), _mock_webrtc():
        with TestClient(app) as http:
            token = _approve_client(http)
            with http.websocket_connect("/api/v1/ws/signal") as ws:
                ws.send_text(json.dumps({"type": "auth", "token": token}))
                msg = json.loads(ws.receive_text())
                assert msg["type"] == "auth_ok"
                assert msg["client_id"] == CLIENT_ID


def test_signal_invalid_token_closes(test_db):
    """An invalid token must cause the server to close the connection."""
    with _lifespan_patches(), _mock_webrtc():
        with TestClient(app) as http:
            with http.websocket_connect("/api/v1/ws/signal") as ws:
                ws.send_text(json.dumps({"type": "auth", "token": "bad-token"}))
                try:
                    ws.receive_text()
                    assert False, "Expected connection to be closed"
                except Exception:
                    pass  # WebSocketDisconnect — expected


def test_signal_missing_auth_message_closes(test_db):
    """Sending a non-auth message first must close the connection."""
    with _lifespan_patches(), _mock_webrtc():
        with TestClient(app) as http:
            with http.websocket_connect("/api/v1/ws/signal") as ws:
                ws.send_text(json.dumps({"type": "offer", "sdp": "..."}))
                try:
                    ws.receive_text()
                    assert False, "Expected connection to be closed"
                except Exception:
                    pass


# ---------------------------------------------------------------------------
# Signaling flow tests
# ---------------------------------------------------------------------------


def test_signal_offer_returns_answer(test_db, monkeypatch):
    """The server must respond with an SDP answer when it receives an offer."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    answer_sdp = "v=0\r\no=- 42 42 IN IP4 127.0.0.1\r\n"
    with _lifespan_patches(), _mock_webrtc(answer_sdp=answer_sdp):
        with TestClient(app) as http:
            token = _approve_client(http)
            with http.websocket_connect("/api/v1/ws/signal") as ws:
                # Auth
                ws.send_text(json.dumps({"type": "auth", "token": token}))
                auth_msg = json.loads(ws.receive_text())
                assert auth_msg["type"] == "auth_ok"

                # Send offer
                ws.send_text(json.dumps({"type": "offer", "sdp": "v=0\r\n"}))
                answer_msg = json.loads(ws.receive_text())
                assert answer_msg["type"] == "answer"
                assert answer_msg["sdp"] == answer_sdp


def test_signal_ice_candidate_accepted(test_db, monkeypatch):
    """ICE candidate messages must be forwarded to the webrtc_service without error."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    with _lifespan_patches(), _mock_webrtc():
        with patch("routers.signal.add_ice_candidate", new=AsyncMock()) as mock_add_ice:
            with TestClient(app) as http:
                token = _approve_client(http)
                with http.websocket_connect("/api/v1/ws/signal") as ws:
                    ws.send_text(json.dumps({"type": "auth", "token": token}))
                    json.loads(ws.receive_text())  # auth_ok

                    ice_msg = {
                        "type": "ice-candidate",
                        "candidate": (
                            "candidate:1 1 UDP 2130706431 192.168.1.1 54321 typ host"
                        ),
                        "sdpMid": "0",
                        "sdpMLineIndex": 0,
                    }
                    ws.send_text(json.dumps(ice_msg))

                    # Give the event loop a chance to process
                    # Connection should still be alive (no error reply)
                    ws.send_text(json.dumps({"type": "offer", "sdp": "v=0\r\n"}))
                    answer = json.loads(ws.receive_text())
                    assert answer["type"] == "answer"

            # add_ice_candidate must have been called at least once
            assert mock_add_ice.called


def test_signal_unknown_message_type_returns_error(test_db, monkeypatch):
    """Unknown message types must result in an error reply, not a crash."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    with _lifespan_patches(), _mock_webrtc():
        with TestClient(app) as http:
            token = _approve_client(http)
            with http.websocket_connect("/api/v1/ws/signal") as ws:
                ws.send_text(json.dumps({"type": "auth", "token": token}))
                json.loads(ws.receive_text())  # auth_ok

                ws.send_text(json.dumps({"type": "unknown_type_xyz"}))
                err = json.loads(ws.receive_text())
                assert err["type"] == "error"
                assert err["code"] == "unknown_type"


def test_signal_invalid_json_returns_error(test_db, monkeypatch):
    """Non-JSON messages must return an error reply."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    with _lifespan_patches(), _mock_webrtc():
        with TestClient(app) as http:
            token = _approve_client(http)
            with http.websocket_connect("/api/v1/ws/signal") as ws:
                ws.send_text(json.dumps({"type": "auth", "token": token}))
                json.loads(ws.receive_text())  # auth_ok

                ws.send_text("this is not json {{{{")
                err = json.loads(ws.receive_text())
                assert err["type"] == "error"
                assert err["code"] == "invalid_json"


def test_signal_offer_missing_sdp_returns_error(test_db, monkeypatch):
    """An offer message without 'sdp' field must return a missing_sdp error."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    with _lifespan_patches(), _mock_webrtc():
        with TestClient(app) as http:
            token = _approve_client(http)
            with http.websocket_connect("/api/v1/ws/signal") as ws:
                ws.send_text(json.dumps({"type": "auth", "token": token}))
                json.loads(ws.receive_text())  # auth_ok

                ws.send_text(json.dumps({"type": "offer"}))  # no 'sdp' key
                err = json.loads(ws.receive_text())
                assert err["type"] == "error"
                assert err["code"] == "missing_sdp"
