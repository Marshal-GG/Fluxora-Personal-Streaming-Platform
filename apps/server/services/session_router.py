"""Session router — multi-encoder priority chain + fallback orchestration.

Slice C of the GPU UX plan ([docs/10_planning/10_gpu_ux_plan.md] §3).

The operator configures a priority chain like
``["h264_nvenc", "h264_qsv", "libx264"]`` in ``user_settings.transcoding_chain``.
On every transcode session start, ``pick_encoder(chain, session_id)`` walks
the chain and returns the first encoder whose live-session count is below
its ``concurrent_session_cap`` (NVENC = 3 on consumer cards; others have
no cap).  When every encoder in the chain is at cap, we still return the
last entry so FFmpeg can produce a clear error rather than a generic 503.

Routing decisions are recorded in a 50-entry FIFO ring buffer for the
desktop's "last fallback events" diagnostic panel.  The buffer is in-memory
only — historical analysis across server restarts uses
``stream_sessions.encoder_used`` (migration 021).

The router is **transcode-only**.  Stream-copy sessions don't invoke any
encoder, so they don't count against any cap and don't go through this
module at all.
"""

from __future__ import annotations

import json
import logging
from collections import deque
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from services.encoder_registry import ENCODER_REGISTRY

logger = logging.getLogger(__name__)


# ── module state ─────────────────────────────────────────────────────────────


# session_id → encoder name.  Populated by `pick_encoder`, cleared by
# `release_session`.  Used for cap accounting and to surface the actual
# encoder per session via `get_session_encoder`.
_session_encoders: dict[str, str] = {}


@dataclass(frozen=True)
class FallbackEvent:
    """One routing decision recorded in the ring buffer."""

    timestamp: str  # ISO-8601 UTC
    session_id: str
    requested_encoder: str  # First encoder in the chain.
    actual_encoder: str  # Encoder we picked.
    reason: str
    """One of:
    - ``configured`` — first chain entry was available; no fallback.
    - ``gpu_session_cap_hit`` — first entry was at cap, fell to next.
    - ``all_encoders_saturated`` — every entry at cap; using last anyway.
    - ``encoder_unknown`` — a chain entry isn't in the registry; skipped.
    """


# Ring buffer of recent routing decisions.  50 entries is enough to cover
# the typical "what just happened on this overloaded server?" window
# without growing memory unboundedly.
_history: deque[FallbackEvent] = deque(maxlen=50)


# ── public API ───────────────────────────────────────────────────────────────


def parse_chain(raw: str | None) -> list[str]:
    """Decode the JSON-encoded chain stored in ``user_settings.transcoding_chain``.

    Returns ``[]`` for NULL / empty / malformed input.  Callers fall back
    to a sensible default in that case (typically
    ``[transcoding_encoder, "libx264"]``).
    """
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
    except (TypeError, ValueError):
        logger.warning("Could not parse transcoding_chain %r as JSON", raw)
        return []
    if not isinstance(parsed, list):
        logger.warning(
            "transcoding_chain JSON is not a list (got %s)", type(parsed).__name__
        )
        return []
    return [str(x) for x in parsed if isinstance(x, str)]


def encode_chain(chain: list[str]) -> str:
    """Serialise a chain to a JSON-encoded string for storage."""
    return json.dumps(list(chain))


def _active_session_count_for_encoder(encoder: str) -> int:
    return sum(1 for e in _session_encoders.values() if e == encoder)


def pick_encoder(
    chain: list[str],
    session_id: str,
    *,
    default_encoder: str = "libx264",
) -> tuple[str, str]:
    """Walk the priority chain; return ``(encoder, reason)``.

    The reason string is one of the values documented on
    :class:`FallbackEvent.reason`.  The session is reserved against the
    chosen encoder's cap until ``release_session(session_id)`` is called
    in ``stop_stream``.

    Args:
        chain: Operator's priority list.  Empty list falls back to
            ``[default_encoder]``.
        session_id: The new session's ID — used for cap accounting.
        default_encoder: The encoder to use if ``chain`` is empty.  This is
            the operator's old-style ``transcoding_encoder`` setting.
    """
    effective_chain = list(chain) if chain else [default_encoder]
    requested = effective_chain[0]
    chosen: str | None = None
    reason = "configured"

    for encoder in effective_chain:
        meta = ENCODER_REGISTRY.get(encoder)
        if meta is None:
            logger.warning(
                "Skipping unknown encoder %r in chain (session=%s)",
                encoder,
                session_id,
            )
            continue
        cap = meta.concurrent_session_cap
        live = _active_session_count_for_encoder(encoder)
        if cap is None or live < cap:
            chosen = encoder
            if encoder != requested:
                reason = "gpu_session_cap_hit"
            break

    if chosen is None:
        # Either every chain entry is at cap, or nothing in the chain was
        # in the registry at all.  Fall through to the last *known* entry
        # so FFmpeg can produce a clear error; if no entry was known,
        # fall through to the default encoder.
        for encoder in reversed(effective_chain):
            if encoder in ENCODER_REGISTRY:
                chosen = encoder
                reason = "all_encoders_saturated"
                break
        if chosen is None:
            chosen = default_encoder
            reason = "encoder_unknown"

    _session_encoders[session_id] = chosen
    event = FallbackEvent(
        timestamp=datetime.now(UTC).isoformat(),
        session_id=session_id,
        requested_encoder=requested,
        actual_encoder=chosen,
        reason=reason,
    )
    _history.append(event)
    if reason != "configured":
        logger.info(
            "Session router: session=%s requested=%s actual=%s reason=%s",
            session_id,
            requested,
            chosen,
            reason,
        )
    return chosen, reason


def release_session(session_id: str) -> None:
    """Free the session's encoder slot.  Called from ``stop_stream``."""
    _session_encoders.pop(session_id, None)


def get_session_encoder(session_id: str) -> str | None:
    """Return the encoder this session was assigned, or None if unknown."""
    return _session_encoders.get(session_id)


def get_history() -> list[dict[str, Any]]:
    """Return a JSON-friendly copy of the ring buffer (newest last)."""
    return [
        {
            "timestamp": e.timestamp,
            "session_id": e.session_id,
            "requested_encoder": e.requested_encoder,
            "actual_encoder": e.actual_encoder,
            "reason": e.reason,
        }
        for e in _history
    ]


def reset_state() -> None:
    """Test hook — clear sessions + history."""
    _session_encoders.clear()
    _history.clear()
