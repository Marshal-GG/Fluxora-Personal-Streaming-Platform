"""Tests for ``services/benchmark_history_service.py`` and the three
``/benchmark/history*`` router endpoints.

The history layer persists encoder benchmark runs so the desktop can render
a sidebar of recent runs the operator can revisit (e.g. comparing today's
NVENC throughput to last week's after a driver update).
"""

from __future__ import annotations

from datetime import UTC, datetime
from unittest.mock import patch

import pytest
from httpx import ASGITransport, AsyncClient

from main import app
from services import benchmark_history_service, benchmark_service, transcoding_service


def _result(
    encoder: str = "h264_nvenc",
    *,
    width: int = 1280,
    height: int = 720,
) -> benchmark_service.EncoderBenchmarkResult:
    """Helper — minimal valid result for persistence tests."""
    meta = benchmark_service.ENCODER_REGISTRY[encoder]
    return benchmark_service.EncoderBenchmarkResult(
        encoder=encoder,
        vendor=meta.vendor,
        codec=meta.codec,
        width=width,
        height=height,
        passed=True,
        error=None,
        fps=120.0,
        speed_x=4.0,
        bitrate_kbps=1500.0,
        encoded_frames=240,
        elapsed_sec=2.0,
        realtime_multiplier=4.0,
        init_ms=300,
        gpu_utilization_percent=42.5,
        vram_used_mb=520,
        concurrent_session_cap=meta.concurrent_session_cap,
        recommended_concurrent=4,
        verified_concurrent=7,
    )


# ── Service layer ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_save_then_get_round_trips_full_payload(test_db) -> None:
    """A saved run round-trips through ``get_benchmark_run`` with every
    metric intact — the JSON blob preserves nested dataclass fields."""
    started = datetime(2026, 5, 7, 10, 0, 0, tzinfo=UTC).isoformat()
    finished = datetime(2026, 5, 7, 10, 0, 30, tzinfo=UTC).isoformat()

    run_id = await benchmark_history_service.save_benchmark_run(
        test_db,
        started_at=started,
        finished_at=finished,
        duration_sec=8,
        fps=30,
        width=1920,
        height=1080,
        verify_caps=True,
        results=[_result("h264_nvenc"), _result("hevc_nvenc")],
    )
    assert run_id > 0

    fetched = await benchmark_history_service.get_benchmark_run(test_db, run_id)
    assert fetched is not None
    assert fetched["id"] == run_id
    assert fetched["fps"] == 30
    assert fetched["width"] == 1920
    assert fetched["height"] == 1080
    assert fetched["verify_caps"] is True
    assert fetched["encoder_count"] == 2
    assert len(fetched["results"]) == 2
    first = fetched["results"][0]
    assert first["encoder"] == "h264_nvenc"
    assert first["verified_concurrent"] == 7
    assert first["gpu_utilization_percent"] == 42.5


@pytest.mark.asyncio
async def test_list_benchmark_runs_returns_summaries_newest_first(test_db) -> None:
    """List endpoint omits per-encoder results and sorts newest first."""
    base = datetime(2026, 5, 1, tzinfo=UTC)
    for i in range(3):
        await benchmark_history_service.save_benchmark_run(
            test_db,
            started_at=base.replace(day=1 + i).isoformat(),
            finished_at=base.replace(day=1 + i).isoformat(),
            duration_sec=8,
            fps=30,
            width=1280,
            height=720,
            verify_caps=False,
            results=[_result("libx264")],
        )

    summaries = await benchmark_history_service.list_benchmark_runs(test_db)
    assert len(summaries) == 3
    # Newest first — day 3 → day 1.
    assert summaries[0]["started_at"].startswith("2026-05-03")
    assert summaries[2]["started_at"].startswith("2026-05-01")
    # Summaries don't carry per-encoder results.
    assert "results" not in summaries[0]
    assert summaries[0]["encoder_count"] == 1


@pytest.mark.asyncio
async def test_get_benchmark_run_returns_none_for_unknown_id(test_db) -> None:
    assert await benchmark_history_service.get_benchmark_run(test_db, 99999) is None


@pytest.mark.asyncio
async def test_delete_benchmark_run_removes_row(test_db) -> None:
    run_id = await benchmark_history_service.save_benchmark_run(
        test_db,
        started_at="2026-05-07T10:00:00+00:00",
        finished_at="2026-05-07T10:00:30+00:00",
        duration_sec=8,
        fps=30,
        width=1280,
        height=720,
        verify_caps=False,
        results=[_result("libx264")],
    )
    assert await benchmark_history_service.delete_benchmark_run(test_db, run_id) is True
    # Second delete on the same id is a no-op (row already gone).
    assert (
        await benchmark_history_service.delete_benchmark_run(test_db, run_id) is False
    )
    assert await benchmark_history_service.get_benchmark_run(test_db, run_id) is None


@pytest.mark.asyncio
async def test_prune_history_drops_old_entries_keeping_newest(test_db) -> None:
    """The save path auto-prunes; this asserts the behaviour directly so a
    future agent changing ``_HISTORY_LIMIT`` understands the contract."""
    base = datetime(2026, 5, 1, tzinfo=UTC)
    for i in range(5):
        await benchmark_history_service.save_benchmark_run(
            test_db,
            started_at=base.replace(day=1 + i).isoformat(),
            finished_at=base.replace(day=1 + i).isoformat(),
            duration_sec=8,
            fps=30,
            width=1280,
            height=720,
            verify_caps=False,
            results=[_result("libx264")],
        )

    pruned = await benchmark_history_service.prune_history(test_db, keep=2)
    assert pruned == 3
    summaries = await benchmark_history_service.list_benchmark_runs(test_db)
    assert len(summaries) == 2
    # Newest two preserved.
    assert summaries[0]["started_at"].startswith("2026-05-05")
    assert summaries[1]["started_at"].startswith("2026-05-04")


# ── Router layer ─────────────────────────────────────────────────────────────


@pytest.fixture(autouse=True)
def _reset_encoder_cache():
    transcoding_service._AVAILABLE_CACHE = None
    yield
    transcoding_service._AVAILABLE_CACHE = None


async def _seed_run(client: AsyncClient) -> int:
    """Run the live POST /benchmark with a stubbed service so tests don't
    need real FFmpeg.  Returns the new row's id."""

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        # Mirror the production resolution-outer × encoder-inner ordering so
        # the persisted results carry the right (encoder, resolution) tuples.
        out = []
        for w, h in resolutions:
            for enc in encoders:
                out.append(_result(enc, width=w, height=h))
        return out

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=["h264_nvenc", "libx264"],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post("/api/v1/transcoding/benchmark")
    assert resp.status_code == 200
    return resp.json()["id"]


@pytest.mark.asyncio
async def test_post_benchmark_persists_and_returns_id(client: AsyncClient) -> None:
    """Every successful benchmark run lands in the history table; the
    response carries the new row's id so the desktop can keep the visible
    result aligned with the history sidebar."""
    run_id = await _seed_run(client)
    assert run_id > 0
    # Confirm the row landed in the history.
    resp = await client.get("/api/v1/transcoding/benchmark/history")
    assert resp.status_code == 200
    body = resp.json()
    assert any(entry["id"] == run_id for entry in body["entries"])


@pytest.mark.asyncio
async def test_get_benchmark_history_entry_returns_full_body(
    client: AsyncClient,
) -> None:
    run_id = await _seed_run(client)
    resp = await client.get(f"/api/v1/transcoding/benchmark/history/{run_id}")
    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == run_id
    assert len(body["results"]) == 2
    assert body["results"][0]["encoder"] in ("h264_nvenc", "libx264")


@pytest.mark.asyncio
async def test_get_benchmark_history_entry_404s_for_unknown_id(
    client: AsyncClient,
) -> None:
    resp = await client.get("/api/v1/transcoding/benchmark/history/99999")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_benchmark_history_entry(client: AsyncClient) -> None:
    run_id = await _seed_run(client)
    resp = await client.delete(f"/api/v1/transcoding/benchmark/history/{run_id}")
    assert resp.status_code == 204
    follow = await client.get(f"/api/v1/transcoding/benchmark/history/{run_id}")
    assert follow.status_code == 404


@pytest.mark.asyncio
async def test_delete_benchmark_history_entry_404s_for_unknown_id(
    client: AsyncClient,
) -> None:
    resp = await client.delete("/api/v1/transcoding/benchmark/history/99999")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_history_entry_carries_resolution_count_for_matrix_run(
    test_db,
) -> None:
    """List + get-by-id derive ``resolution_count`` from the persisted
    results blob.  A matrix run with 3 distinct resolutions across 6
    results must surface count=3 in the sidebar list AND hand back the
    full ``resolutions`` echo on get-by-id so the desktop can render the
    operator's tier selection."""
    run_id = await benchmark_history_service.save_benchmark_run(
        test_db,
        started_at="2026-05-07T18:00:00+00:00",
        finished_at="2026-05-07T18:01:30+00:00",
        duration_sec=8,
        fps=30,
        width=1280,  # primary tier (= first selected)
        height=720,
        verify_caps=False,
        results=[
            _result("libx264", width=1280, height=720),
            _result("h264_nvenc", width=1280, height=720),
            _result("libx264", width=1920, height=1080),
            _result("h264_nvenc", width=1920, height=1080),
            _result("libx264", width=3840, height=2160),
            _result("h264_nvenc", width=3840, height=2160),
        ],
    )

    listed = await benchmark_history_service.list_benchmark_runs(test_db)
    matched = next(row for row in listed if row["id"] == run_id)
    assert matched["resolution_count"] == 3
    assert matched["encoder_count"] == 6  # total rows, not distinct encoders

    full = await benchmark_history_service.get_benchmark_run(test_db, run_id)
    assert full is not None
    # Resolutions echoed in operator-selection order (first occurrence wins).
    assert full["resolutions"] == [
        (1280, 720),
        (1920, 1080),
        (3840, 2160),
    ]


@pytest.mark.asyncio
async def test_history_entry_resolution_count_defaults_to_one_for_legacy_rows(
    test_db,
) -> None:
    """Pre-matrix rows have all results at the run's primary resolution
    so the count derivation collapses to 1.  Required because the
    desktop reads the field unconditionally and a missing / 0 value
    would crash the sidebar caption."""
    run_id = await benchmark_history_service.save_benchmark_run(
        test_db,
        started_at="2026-05-06T10:00:00+00:00",
        finished_at="2026-05-06T10:01:00+00:00",
        duration_sec=8,
        fps=30,
        width=1920,
        height=1080,
        verify_caps=False,
        results=[
            _result("libx264", width=1920, height=1080),
            _result("h264_nvenc", width=1920, height=1080),
        ],
    )

    listed = await benchmark_history_service.list_benchmark_runs(test_db)
    matched = next(row for row in listed if row["id"] == run_id)
    assert matched["resolution_count"] == 1


@pytest.mark.asyncio
async def test_history_endpoints_require_localhost(test_db) -> None:
    """All three history endpoints are admin-tier — tunneled callers get
    403 just like the rest of /transcoding/*."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("198.51.100.4", 51000)),
        base_url="http://test",
    ) as remote:
        for verb, path in (
            ("get", "/api/v1/transcoding/benchmark/history"),
            ("get", "/api/v1/transcoding/benchmark/history/1"),
            ("delete", "/api/v1/transcoding/benchmark/history/1"),
        ):
            resp = await getattr(remote, verb)(
                path, headers={"CF-Connecting-IP": "198.51.100.4"}
            )
            assert resp.status_code == 403
