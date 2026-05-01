import asyncio
import json
import logging

import aiosqlite
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from fastapi.websockets import WebSocketState

from config import settings
from database.db import get_db
from routers.deps import LOOPBACK
from services.auth_service import get_trusted_client_by_token
from services.system_stats_service import SystemStatsService

logger = logging.getLogger(__name__)

router = APIRouter()

_PING_INTERVAL = 30  # seconds
_PONG_TIMEOUT = 10  # seconds
_STATS_INTERVAL_SEC = 1.1


def _is_local_websocket(websocket: WebSocket) -> bool:
    """Whether the WS connection originated from the local machine.

    Extracted as a module-level helper so tests can monkeypatch it; the
    Starlette test client reports `client.host == "testclient"`.
    """
    host = websocket.client.host if websocket.client else ""
    return host in LOOPBACK


async def _authenticate(websocket: WebSocket, db: aiosqlite.Connection):
    """Extract and validate the bearer token from the first text message."""
    try:
        raw = await asyncio.wait_for(websocket.receive_text(), timeout=10.0)
    except TimeoutError:
        await websocket.close(code=1008, reason="Auth timeout")
        return None

    try:
        msg = json.loads(raw)
    except ValueError:
        await websocket.close(code=1008, reason="Invalid auth message")
        return None

    if msg.get("type") != "auth" or not msg.get("token"):
        await websocket.close(code=1008, reason="Expected auth message")
        return None

    client = await get_trusted_client_by_token(
        db, msg["token"], settings.token_hmac_key
    )
    if client is None:
        await websocket.close(code=1008, reason="Invalid token")
        return None

    return client


@router.websocket("/status")
async def ws_status(websocket: WebSocket):
    """
    Real-time stream-status channel.

    Handshake:
      1. Client connects.
      2. Client sends: {"type": "auth", "token": "<bearer>"}
      3. Server replies: {"type": "auth_ok", "client_id": "..."}

    During session:
      - Server sends ping every 30 s: {"type": "ping"}
      - Client must reply: {"type": "pong"}
      - Client may send: {"type": "progress", "session_id": "...", "progress_sec": 42.0}
      - Server acknowledges progress updates in the DB.
    """
    await websocket.accept()

    db = await get_db()
    client = await _authenticate(websocket, db)
    if client is None:
        return

    client_id: str = client["id"]
    await websocket.send_text(json.dumps({"type": "auth_ok", "client_id": client_id}))
    logger.info("WS connected: client=%s", client_id)

    try:
        await _session_loop(websocket, db, client_id)
    except WebSocketDisconnect:
        logger.warning("WS disconnected: client=%s", client_id)
    except Exception:
        logger.error("WS error: client=%s", client_id, exc_info=True)
    finally:
        if websocket.client_state != WebSocketState.DISCONNECTED:
            await websocket.close()
        logger.info("WS closed: client=%s", client_id)


async def _session_loop(
    websocket: WebSocket,
    db: aiosqlite.Connection,
    client_id: str,
) -> None:
    """Run the ping/pong keepalive and handle incoming progress updates."""
    pending_pong = False

    async def _send_ping() -> None:
        nonlocal pending_pong
        await websocket.send_text(json.dumps({"type": "ping"}))
        pending_pong = True

    ping_task = asyncio.create_task(_ping_loop(websocket, _send_ping))
    try:
        while True:
            try:
                raw = await asyncio.wait_for(
                    websocket.receive_text(), timeout=_PONG_TIMEOUT + 1
                )
            except TimeoutError:
                if pending_pong:
                    logger.warning("WS pong timeout: client=%s — closing", client_id)
                    break
                continue

            try:
                msg = json.loads(raw)
            except ValueError:
                continue

            msg_type = msg.get("type")

            if msg_type == "pong":
                pending_pong = False

            elif msg_type == "progress":
                session_id = msg.get("session_id")
                progress_sec = msg.get("progress_sec")
                if session_id and isinstance(progress_sec, int | float):
                    await db.execute(
                        """
                        UPDATE stream_sessions
                           SET progress_sec = ?
                         WHERE id = ? AND client_id = ? AND ended_at IS NULL
                        """,
                        (float(progress_sec), session_id, client_id),
                    )
                    await db.commit()
    finally:
        ping_task.cancel()
        try:
            await ping_task
        except asyncio.CancelledError:
            pass


async def _ping_loop(websocket: WebSocket, send_ping) -> None:
    """Send a ping frame every _PING_INTERVAL seconds."""
    while True:
        await asyncio.sleep(_PING_INTERVAL)
        if websocket.client_state == WebSocketState.DISCONNECTED:
            break
        await send_ping()


@router.websocket("/stats")
async def ws_stats(websocket: WebSocket):
    """Live system-stats stream — sidebar / status bar / sparklines.

    Auth: localhost connections (desktop control panel) accept immediately.
    Non-localhost connections must complete the same `{"type":"auth",
    "token":"..."}` handshake as `/status` before any stats are sent.

    Each connection gets its own `SystemStatsService` instance so the
    network-rate baseline is per-connection — multiple subscribers don't
    fight over the shared rate cache.

    Frame format:
        {"type": "stats", "data": <StatsPayload>}
    """
    await websocket.accept()

    is_local = _is_local_websocket(websocket)

    db = await get_db()

    if not is_local:
        client = await _authenticate(websocket, db)
        if client is None:
            return
        client_id: str = client["id"]
        await websocket.send_text(
            json.dumps({"type": "auth_ok", "client_id": client_id})
        )
        logger.info("WS stats connected: client=%s", client_id)
    else:
        logger.info("WS stats connected: localhost")

    stats = SystemStatsService()
    try:
        while True:
            if websocket.client_state == WebSocketState.DISCONNECTED:
                break
            payload = await stats.collect(db)
            await websocket.send_text(json.dumps({"type": "stats", "data": payload}))
            await asyncio.sleep(_STATS_INTERVAL_SEC)
    except WebSocketDisconnect:
        logger.info("WS stats disconnected")
    except Exception:
        logger.error("WS stats error", exc_info=True)
    finally:
        if websocket.client_state != WebSocketState.DISCONNECTED:
            await websocket.close()
