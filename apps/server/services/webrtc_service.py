"""WebRTC signaling service.

Manages the lifecycle of ``aiortc.RTCPeerConnection`` objects on behalf of
trusted mobile clients.  The signaling channel (``/api/v1/ws/signal``) is
responsible only for exchanging SDP and ICE candidates; the actual media
data travels peer-to-peer once the connection is established.

Architecture
~~~~~~~~~~~~
  Mobile client ──WS──► /ws/signal ──► webrtc_service ──► RTCPeerConnection
                                                    │
                                         aiortc (Python WebRTC)
                                                    │
                                    ◄──── STUN/TURN negotiation ─────►
                                                    │
                                    ◄──────── media data channel ──────►

STUN/TURN
~~~~~~~~~
  Default: Google public STUN servers (no cost, suitable for development).
  Production: override ``WEBRTC_STUN_URLS`` / ``WEBRTC_TURN_*`` env vars.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

from aiortc import (
    RTCConfiguration,
    RTCIceServer,
    RTCPeerConnection,
    RTCSessionDescription,
)
from aiortc.contrib.media import MediaRelay

from config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# ICE server configuration
# ---------------------------------------------------------------------------


def _ice_servers() -> list[RTCIceServer]:
    """Build the ICE server list from config/env.

    Falls back to Google public STUN if no explicit config is provided.
    TURN credentials are optional — without them the connection may fail
    on symmetric NAT, but works fine on most home routers.
    """
    stun_urls = getattr(settings, "webrtc_stun_urls", None) or [
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302",
    ]
    servers = [RTCIceServer(urls=stun_urls)]

    turn_url = getattr(settings, "webrtc_turn_url", None)
    turn_user = getattr(settings, "webrtc_turn_username", None)
    turn_pass = getattr(settings, "webrtc_turn_password", None)
    if turn_url and turn_user and turn_pass:
        servers.append(
            RTCIceServer(urls=[turn_url], username=turn_user, credential=turn_pass)
        )
        logger.info("TURN server configured: %s", turn_url)
    else:
        logger.debug("No TURN server configured — using STUN only")

    return servers


_RTC_CONFIG = RTCConfiguration(iceServers=_ice_servers())
_relay = MediaRelay()


# ---------------------------------------------------------------------------
# Session registry
# ---------------------------------------------------------------------------


@dataclass
class _PeerSession:
    """Tracks a single WebRTC peer connection for one client."""

    client_id: str
    pc: RTCPeerConnection
    pending_candidates: list[dict] = field(default_factory=list)


_sessions: dict[str, _PeerSession] = {}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def create_peer_connection(client_id: str) -> RTCPeerConnection:
    """Create and register a new ``RTCPeerConnection`` for *client_id*.

    If a stale session already exists for this client it is closed first.
    """
    _close_existing(client_id)
    pc = RTCPeerConnection(configuration=_RTC_CONFIG)
    _sessions[client_id] = _PeerSession(client_id=client_id, pc=pc)
    logger.info("WebRTC peer connection created: client=%s", client_id)
    return pc


async def handle_offer(client_id: str, sdp: str) -> str:
    """Process an SDP offer from the client and return the server's SDP answer.

    Steps:
    1. Set the remote description (client's offer).
    2. Create an answer.
    3. Set the local description (server's answer).
    4. Return the answer SDP string — the caller must send this to the client.
    """
    session = _sessions.get(client_id)
    if session is None:
        raise KeyError(f"No peer connection found for client={client_id!r}")

    pc = session.pc
    offer = RTCSessionDescription(sdp=sdp, type="offer")
    await pc.setRemoteDescription(offer)
    logger.debug("Remote description set (offer): client=%s", client_id)

    # Drain any ICE candidates that arrived before the remote description.
    for candidate_dict in session.pending_candidates:
        await _add_ice_candidate(pc, candidate_dict)
    session.pending_candidates.clear()

    answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
    logger.debug("Local description set (answer): client=%s", client_id)
    return pc.localDescription.sdp


async def add_ice_candidate(client_id: str, candidate: dict) -> None:
    """Add a remote ICE candidate for the peer connection.

    If the remote description has not been set yet, the candidate is queued
    and applied after the offer is processed.
    """
    session = _sessions.get(client_id)
    if session is None:
        logger.warning("ICE candidate for unknown client=%s — discarding", client_id)
        return

    pc = session.pc
    if pc.remoteDescription is None:
        # Offer hasn't arrived yet — queue the candidate.
        session.pending_candidates.append(candidate)
        logger.debug("ICE candidate queued (no remote desc yet): client=%s", client_id)
    else:
        await _add_ice_candidate(pc, candidate)


async def close_peer_connection(client_id: str) -> None:
    """Close and unregister the peer connection for *client_id* (if any)."""
    _close_existing(client_id)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _add_ice_candidate(pc: RTCPeerConnection, candidate: dict) -> None:
    from aiortc.sdp import candidate_from_sdp

    sdp_line = candidate.get("candidate", "")
    if not sdp_line:
        # End-of-candidates signal — safe to ignore.
        return

    try:
        ice_candidate = candidate_from_sdp(sdp_line.removeprefix("candidate:"))
        ice_candidate.sdpMid = candidate.get("sdpMid")
        ice_candidate.sdpMLineIndex = candidate.get("sdpMLineIndex")
        await pc.addIceCandidate(ice_candidate)
    except Exception:
        logger.warning("Failed to add ICE candidate — skipping", exc_info=True)


def _close_existing(client_id: str) -> None:
    session = _sessions.pop(client_id, None)
    if session is not None:
        # Schedule the close on the running event loop. Callers always run
        # inside an async context (websocket handler), so a running loop is
        # guaranteed; if not, we fall back to logging and dropping the close.
        import asyncio

        try:
            loop = asyncio.get_running_loop()
            loop.create_task(session.pc.close())
        except RuntimeError:
            logger.warning(
                "No running event loop to close peer connection: client=%s",
                client_id,
            )
        logger.info("WebRTC peer connection closed: client=%s", client_id)
