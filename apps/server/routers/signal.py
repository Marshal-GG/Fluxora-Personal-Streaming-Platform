"""WebRTC signaling router.

Exposes a single WebSocket endpoint: ``/api/v1/ws/signal``

The signaling channel is responsible for exchanging SDP and ICE candidates
so that the mobile client and the server can establish a direct peer-to-peer
WebRTC connection for internet streaming.

Message protocol
~~~~~~~~~~~~~~~~

Handshake (identical to ``/ws/status``):

  1. Client connects.
  2. Client sends::

       {"type": "auth", "token": "<bearer>"}

  3. Server replies on success::

       {"type": "auth_ok", "client_id": "<uuid>"}

Signaling messages (after auth):

  Client → Server (SDP offer)::

      {"type": "offer", "sdp": "<SDP string>"}

  Server → Client (SDP answer)::

      {"type": "answer", "sdp": "<SDP string>"}

  Client → Server (ICE candidate)::

      {"type": "ice-candidate", "candidate": "<candidate line>",
       "sdpMid": "<mid>", "sdpMLineIndex": <index>}

  Server → Client (server-side ICE candidate)::

      {"type": "ice-candidate", "candidate": "<candidate line>",
       "sdpMid": "<mid>", "sdpMLineIndex": <index>}

Error messages::

      {"type": "error", "code": "<code>", "detail": "<message>"}

Connection teardown:
  When the WebSocket closes (for any reason) the server closes and
  unregisters the peer connection automatically.
"""

from __future__ import annotations

import asyncio
import json
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from fastapi.websockets import WebSocketState

from config import settings
from database.db import get_db
from services.auth_service import get_trusted_client_by_token
from services.webrtc_service import (
    add_ice_candidate,
    close_peer_connection,
    create_peer_connection,
    handle_offer,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _ws_send(websocket: WebSocket, payload: dict) -> None:
    """Send a JSON payload; silently discard if the socket is closed."""
    if websocket.client_state == WebSocketState.DISCONNECTED:
        return
    try:
        await websocket.send_text(json.dumps(payload))
    except Exception:
        pass


async def _authenticate(websocket: WebSocket) -> str | None:
    """Perform the auth handshake.

    Returns the authenticated *client_id* or ``None`` if auth failed
    (the socket will have been closed already).
    """
    try:
        raw = await asyncio.wait_for(websocket.receive_text(), timeout=10.0)
    except TimeoutError:
        await websocket.close(code=1008, reason="Auth timeout")
        return None

    try:
        msg = json.loads(raw)
    except ValueError:
        await websocket.close(code=1008, reason="Invalid JSON")
        return None

    if msg.get("type") != "auth" or not msg.get("token"):
        await websocket.close(code=1008, reason="Expected auth message")
        return None

    db = await get_db()
    client = await get_trusted_client_by_token(db, msg["token"], settings.token_hmac_key)
    if client is None:
        await websocket.close(code=1008, reason="Invalid or revoked token")
        return None

    return str(client["id"])


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


@router.websocket("/signal")
async def ws_signal(websocket: WebSocket) -> None:
    """WebRTC signaling channel.

    Each connected client gets its own ``RTCPeerConnection`` managed by
    ``webrtc_service``.  This handler shuttles SDP and ICE messages between
    the client and the service until the socket disconnects.
    """
    await websocket.accept()

    client_id = await _authenticate(websocket)
    if client_id is None:
        return

    await _ws_send(websocket, {"type": "auth_ok", "client_id": client_id})
    logger.info("Signal WS connected: client=%s", client_id)

    # Create a fresh RTCPeerConnection for this session.
    pc = create_peer_connection(client_id)

    # Forward server-generated ICE candidates to the client.
    @pc.on("icecandidate")
    async def _on_ice_candidate(candidate) -> None:  # type: ignore[override]
        if candidate is None:
            # End-of-candidates — nothing to send.
            return
        await _ws_send(
            websocket,
            {
                "type": "ice-candidate",
                "candidate": f"candidate:{candidate.candidate}",
                "sdpMid": candidate.sdpMid,
                "sdpMLineIndex": candidate.sdpMLineIndex,
            },
        )

    try:
        await _signal_loop(websocket, client_id)
    except WebSocketDisconnect:
        logger.info("Signal WS disconnected: client=%s", client_id)
    except Exception:
        logger.exception("Signal WS error: client=%s", client_id)
    finally:
        await close_peer_connection(client_id)
        if websocket.client_state != WebSocketState.DISCONNECTED:
            await websocket.close()
        logger.info("Signal WS closed: client=%s", client_id)


async def _signal_loop(websocket: WebSocket, client_id: str) -> None:
    """Read signaling messages from the client until the socket closes."""
    while True:
        raw = await websocket.receive_text()

        try:
            msg = json.loads(raw)
        except ValueError:
            await _ws_send(websocket, {"type": "error", "code": "invalid_json",
                                       "detail": "Message must be valid JSON"})
            continue

        msg_type = msg.get("type")

        if msg_type == "offer":
            sdp = msg.get("sdp")
            if not sdp:
                await _ws_send(websocket, {"type": "error", "code": "missing_sdp",
                                           "detail": "offer must include 'sdp'"})
                continue
            try:
                answer_sdp = await handle_offer(client_id, sdp)
            except Exception:
                logger.exception("Failed to handle SDP offer: client=%s", client_id)
                await _ws_send(websocket, {"type": "error", "code": "offer_failed",
                                           "detail": "Failed to process SDP offer"})
                continue
            await _ws_send(websocket, {"type": "answer", "sdp": answer_sdp})
            logger.info("SDP answer sent: client=%s", client_id)

        elif msg_type == "ice-candidate":
            candidate = {
                "candidate": msg.get("candidate", ""),
                "sdpMid": msg.get("sdpMid"),
                "sdpMLineIndex": msg.get("sdpMLineIndex"),
            }
            await add_ice_candidate(client_id, candidate)

        else:
            logger.debug(
                "Unknown signal message type=%r: client=%s", msg_type, client_id
            )
            await _ws_send(websocket, {"type": "error", "code": "unknown_type",
                                       "detail": f"Unknown message type: {msg_type!r}"})
