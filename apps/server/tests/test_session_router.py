"""Tests for services/session_router.py + /api/v1/transcoding/fallback-history."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from services import session_router


@pytest.fixture(autouse=True)
def _reset_router_state():
    session_router.reset_state()
    yield
    session_router.reset_state()


# ── parse_chain / encode_chain ───────────────────────────────────────────────


def test_parse_chain_handles_null():
    assert session_router.parse_chain(None) == []


def test_parse_chain_handles_empty_string():
    assert session_router.parse_chain("") == []


def test_parse_chain_decodes_json_list():
    raw = '["h264_nvenc", "h264_qsv", "libx264"]'
    assert session_router.parse_chain(raw) == [
        "h264_nvenc",
        "h264_qsv",
        "libx264",
    ]


def test_parse_chain_rejects_malformed_json():
    assert session_router.parse_chain("not-json") == []


def test_parse_chain_rejects_non_list_json():
    assert session_router.parse_chain('{"oops": true}') == []


def test_parse_chain_filters_non_string_entries():
    """A bad entry shouldn't poison the whole chain."""
    raw = '["h264_nvenc", 42, null, "libx264"]'
    assert session_router.parse_chain(raw) == ["h264_nvenc", "libx264"]


def test_encode_chain_round_trips():
    chain = ["h264_nvenc", "libx264"]
    encoded = session_router.encode_chain(chain)
    assert session_router.parse_chain(encoded) == chain


# ── pick_encoder — chain semantics ───────────────────────────────────────────


def test_pick_encoder_returns_first_when_uncapped():
    chosen, reason = session_router.pick_encoder(["libx264", "h264_nvenc"], "session-1")
    assert chosen == "libx264"
    assert reason == "configured"


def test_pick_encoder_returns_first_when_below_cap():
    """h264_nvenc has a cap of 3; with 0 active, we get it."""
    chosen, reason = session_router.pick_encoder(["h264_nvenc", "libx264"], "session-1")
    assert chosen == "h264_nvenc"
    assert reason == "configured"


def test_pick_encoder_falls_through_when_first_at_cap():
    """Reserve 3 NVENC sessions; the next one should fall through to libx264."""
    for i in range(3):
        chosen, _ = session_router.pick_encoder(
            ["h264_nvenc", "libx264"], f"prereq-{i}"
        )
        assert chosen == "h264_nvenc"
    chosen, reason = session_router.pick_encoder(["h264_nvenc", "libx264"], "fallback")
    assert chosen == "libx264"
    assert reason == "gpu_session_cap_hit"


def test_pick_encoder_uses_default_when_chain_empty():
    chosen, reason = session_router.pick_encoder(
        [], "session-1", default_encoder="hevc_nvenc"
    )
    assert chosen == "hevc_nvenc"
    assert reason == "configured"


def test_pick_encoder_skips_unknown_chain_entries():
    """A typo in the chain shouldn't break routing — skip + log + try next."""
    chosen, reason = session_router.pick_encoder(
        ["nonexistent_codec_xyz", "libx264"], "session-1"
    )
    assert chosen == "libx264"
    # reason is 'gpu_session_cap_hit' because the requested (first chain
    # entry) wasn't the one we picked — same semantic as cap fall-through.
    assert reason == "gpu_session_cap_hit"


def test_pick_encoder_all_saturated_returns_last_known():
    """Every entry at cap → fall through to the last *known* entry anyway
    so FFmpeg can produce a clear error rather than a 503."""
    # Saturate both NVENC encoders (cap 3 each).
    for i in range(3):
        session_router.pick_encoder(["h264_nvenc"], f"prereq-h-{i}")
    for i in range(3):
        session_router.pick_encoder(["hevc_nvenc"], f"prereq-x-{i}")

    chosen, reason = session_router.pick_encoder(
        ["h264_nvenc", "hevc_nvenc"], "overflow"
    )
    assert chosen == "hevc_nvenc"
    assert reason == "all_encoders_saturated"


def test_release_session_frees_cap_slot():
    """After releasing a session, its slot is available again."""
    for i in range(3):
        session_router.pick_encoder(["h264_nvenc"], f"prereq-{i}")
    # 4th would fall through to default_encoder if no chain alt.
    session_router.release_session("prereq-0")
    chosen, reason = session_router.pick_encoder(["h264_nvenc"], "post-release")
    assert chosen == "h264_nvenc"
    assert reason == "configured"


def test_release_session_is_idempotent():
    """Releasing a non-existent session must not raise."""
    session_router.release_session("never-existed")  # no exception


def test_get_session_encoder_returns_assigned():
    session_router.pick_encoder(["h264_nvenc"], "session-1")
    assert session_router.get_session_encoder("session-1") == "h264_nvenc"
    assert session_router.get_session_encoder("unknown-session") is None


# ── ring buffer / history ───────────────────────────────────────────────────


def test_get_history_records_routing_decisions():
    session_router.pick_encoder(["libx264"], "s1")
    session_router.pick_encoder(["h264_nvenc", "libx264"], "s2")
    history = session_router.get_history()
    assert len(history) == 2
    assert history[0]["session_id"] == "s1"
    assert history[0]["actual_encoder"] == "libx264"
    assert history[1]["session_id"] == "s2"
    assert history[1]["actual_encoder"] == "h264_nvenc"


def test_get_history_caps_at_50_entries():
    """FIFO ring buffer; oldest entries drop when capacity exceeded."""
    for i in range(60):
        session_router.pick_encoder(["libx264"], f"s{i}")
    history = session_router.get_history()
    assert len(history) == 50
    # Oldest 10 dropped — first remaining is s10.
    assert history[0]["session_id"] == "s10"
    assert history[-1]["session_id"] == "s59"


# ── /api/v1/transcoding/fallback-history endpoint ────────────────────────────


@pytest.mark.asyncio
async def test_fallback_history_endpoint_returns_recent_events(
    client: AsyncClient,
):
    session_router.pick_encoder(["h264_nvenc", "libx264"], "test-session")
    resp = await client.get("/api/v1/transcoding/fallback-history")
    assert resp.status_code == 200
    body = resp.json()
    assert "events" in body
    assert len(body["events"]) == 1
    assert body["events"][0]["session_id"] == "test-session"
    assert body["events"][0]["actual_encoder"] == "h264_nvenc"


@pytest.mark.asyncio
async def test_fallback_history_endpoint_empty_when_no_sessions(
    client: AsyncClient,
):
    resp = await client.get("/api/v1/transcoding/fallback-history")
    assert resp.status_code == 200
    assert resp.json() == {"events": []}
