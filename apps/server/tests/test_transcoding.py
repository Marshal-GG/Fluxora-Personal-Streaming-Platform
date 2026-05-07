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


# ── /api/v1/transcoding/benchmark ───────────────────────────────────────────


@pytest.mark.asyncio
async def test_benchmark_empty_body_uses_default_duration(client: AsyncClient):
    """No body / no fields → default 8 s duration + 30 fps applied and
    echoed back in the response."""
    from services import benchmark_service

    captured: dict[str, int | None] = {}

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        captured["duration"] = duration_sec
        captured["fps"] = fps
        captured["encoders"] = list(encoders)
        return [
            benchmark_service.EncoderBenchmarkResult(
                encoder=enc,
                vendor="software" if enc.startswith("libx") else "nvidia",
                codec="h264",
                width=resolutions[0][0],
                height=resolutions[0][1],
                passed=True,
                error=None,
                fps=30.0,
                speed_x=1.5,
                bitrate_kbps=850.0,
                encoded_frames=240,
                elapsed_sec=5.3,
                realtime_multiplier=1.5,
                init_ms=120,
                gpu_utilization_percent=None,
                vram_used_mb=None,
                concurrent_session_cap=None,
                recommended_concurrent=1,
            )
            for enc in encoders
        ]

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=["libx264", "h264_nvenc"],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post("/api/v1/transcoding/benchmark")

    assert resp.status_code == 200
    body = resp.json()
    assert body["duration_sec"] == 8
    assert body["fps"] == 30
    assert captured["duration"] == 8
    assert captured["fps"] == 30
    assert captured["encoders"] == ["libx264", "h264_nvenc"]
    assert {r["encoder"] for r in body["results"]} == {"libx264", "h264_nvenc"}
    assert body["results"][0]["passed"] is True
    assert body["results"][0]["fps"] == 30.0


@pytest.mark.asyncio
async def test_benchmark_explicit_duration_is_clamped(client: AsyncClient):
    """A duration above the cap is clamped to the maximum (20 s)."""
    from services import benchmark_service

    captured: dict[str, int] = {}

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        captured["duration"] = duration_sec
        captured["fps"] = fps
        return []

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=[],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post(
            "/api/v1/transcoding/benchmark", json={"duration_sec": 20}
        )

    assert resp.status_code == 200
    assert captured["duration"] == 20


@pytest.mark.asyncio
async def test_benchmark_accepts_60_fps(client: AsyncClient):
    """Operator-supplied fps=60 is honoured + threaded through to the
    service + echoed back in the response shape."""
    from services import benchmark_service

    captured: dict[str, int] = {}

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        captured["fps"] = fps
        return []

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=[],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post(
            "/api/v1/transcoding/benchmark", json={"fps": 60}
        )

    assert resp.status_code == 200
    body = resp.json()
    assert body["fps"] == 60
    assert captured["fps"] == 60


@pytest.mark.asyncio
async def test_benchmark_verify_caps_flag_threads_to_service(
    client: AsyncClient,
):
    """When the body sets ``verify_caps=true`` the service is invoked with
    that flag + the response echoes it back so the desktop can render the
    "verified" state correctly."""
    from services import benchmark_service

    captured: dict[str, bool] = {}

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        captured["verify_caps"] = verify_caps
        return []

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=[],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post(
            "/api/v1/transcoding/benchmark", json={"verify_caps": True}
        )

    assert resp.status_code == 200
    body = resp.json()
    assert body["verify_caps"] is True
    assert captured["verify_caps"] is True


@pytest.mark.asyncio
async def test_benchmark_verify_caps_defaults_to_false(client: AsyncClient):
    """Empty body → verify_caps=false (the safer default — probe briefly
    saturates the GPU so it must be opt-in)."""
    from services import benchmark_service

    captured: dict[str, bool] = {}

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        captured["verify_caps"] = verify_caps
        return []

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=[],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post("/api/v1/transcoding/benchmark")

    assert resp.status_code == 200
    body = resp.json()
    assert body["verify_caps"] is False
    assert captured["verify_caps"] is False


@pytest.mark.asyncio
async def test_benchmark_accepts_resolution_and_echoes_in_response(
    client: AsyncClient,
):
    """Operator-supplied width/height threads to the service + the
    response echoes the snapped tier so the desktop can label results
    with the workload that was actually measured."""
    from services import benchmark_service

    captured: dict[str, int] = {}

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        captured["width"] = resolutions[0][0]
        captured["height"] = resolutions[0][1]
        return []

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=[],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post(
            "/api/v1/transcoding/benchmark",
            json={"width": 1920, "height": 1080},
        )

    assert resp.status_code == 200
    body = resp.json()
    assert body["width"] == 1920
    assert body["height"] == 1080
    assert captured["width"] == 1920
    assert captured["height"] == 1080


@pytest.mark.asyncio
async def test_benchmark_resolution_snaps_to_known_tier(client: AsyncClient):
    """An off-tier resolution (1366×768 SDR laptop) gets snapped to the
    nearest documented tier — 720p in this case — so the benchmark
    history doesn't accumulate one-off resolutions."""
    from services import benchmark_service

    captured: dict[str, int] = {}

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        captured["width"] = resolutions[0][0]
        captured["height"] = resolutions[0][1]
        return []

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=[],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post(
            "/api/v1/transcoding/benchmark",
            json={"width": 1366, "height": 768},
        )

    assert resp.status_code == 200
    body = resp.json()
    assert body["width"] == 1280
    assert body["height"] == 720
    assert captured["width"] == 1280
    assert captured["height"] == 720


@pytest.mark.asyncio
async def test_benchmark_accepts_matrix_mode_resolutions_list(client: AsyncClient):
    """When the request carries ``resolutions: [...]`` the service receives
    the full list, the response echoes it back, and the per-row width/height
    on each result reflect the matrix iteration.  Matrix mode is the only
    way the operator selects multiple tiers in one click."""
    from services import benchmark_service

    captured: dict[str, list] = {}

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        captured["resolutions"] = list(resolutions)
        out = []
        for w, h in resolutions:
            for enc in encoders:
                out.append(
                    benchmark_service.EncoderBenchmarkResult(
                        encoder=enc,
                        vendor="software",
                        codec="h264",
                        width=w,
                        height=h,
                        passed=True,
                        error=None,
                        fps=30.0,
                        speed_x=1.0,
                        bitrate_kbps=500.0,
                        encoded_frames=240,
                        elapsed_sec=8.0,
                        realtime_multiplier=1.0,
                        init_ms=200,
                        gpu_utilization_percent=None,
                        vram_used_mb=None,
                        concurrent_session_cap=None,
                        recommended_concurrent=1,
                    )
                )
        return out

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=["libx264"],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post(
            "/api/v1/transcoding/benchmark",
            json={
                "resolutions": [
                    {"width": 1280, "height": 720},
                    {"width": 1920, "height": 1080},
                    {"width": 3840, "height": 2160},
                ]
            },
        )

    assert resp.status_code == 200
    body = resp.json()
    # Service was invoked with the full list.
    assert captured["resolutions"] == [(1280, 720), (1920, 1080), (3840, 2160)]
    # Response echoes the operator's selection.
    assert body["resolutions"] == [
        {"width": 1280, "height": 720},
        {"width": 1920, "height": 1080},
        {"width": 3840, "height": 2160},
    ]
    # Top-level width/height = the FIRST tier (back-compat for old clients).
    assert body["width"] == 1280
    assert body["height"] == 720
    # Each result self-describes its (width, height) — 3 resolutions × 1
    # encoder = 3 results, each with the matching tier.
    assert len(body["results"]) == 3
    res_widths = [r["width"] for r in body["results"]]
    assert res_widths == [1280, 1920, 3840]


@pytest.mark.asyncio
async def test_benchmark_resolutions_list_takes_precedence_over_width_height(
    client: AsyncClient,
):
    """When both ``resolutions`` and the legacy ``width``/``height`` are
    set, the list wins — the desktop never sends both, but a confused
    third-party caller shouldn't get a corrupted run."""
    from services import benchmark_service

    captured: dict[str, list] = {}

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        captured["resolutions"] = list(resolutions)
        return []

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=[],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post(
            "/api/v1/transcoding/benchmark",
            json={
                "width": 3840,
                "height": 2160,
                "resolutions": [{"width": 1280, "height": 720}],
            },
        )

    assert resp.status_code == 200
    # ``resolutions`` wins; legacy width/height are ignored.
    assert captured["resolutions"] == [(1280, 720)]


@pytest.mark.asyncio
async def test_benchmark_rejects_out_of_range_fps(client: AsyncClient):
    """Pydantic validates fps to [24, 60].  120 fps is high-refresh-display
    territory and would tell us nothing useful for media streaming — 422
    fires before the service is ever invoked."""
    resp = await client.post(
        "/api/v1/transcoding/benchmark", json={"fps": 120}
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_benchmark_rejects_out_of_range_duration(client: AsyncClient):
    """Pydantic validates the field range — 99 is out of bounds, 422 fires
    before the service is ever invoked."""
    resp = await client.post(
        "/api/v1/transcoding/benchmark", json={"duration_sec": 99}
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_benchmark_passes_failures_through_to_response(
    client: AsyncClient,
):
    """Failed encoder rows must round-trip — the desktop renders them as a
    'failed' line so operators see *why* an encoder couldn't be benchmarked."""
    from services import benchmark_service

    async def _fake_run(
        encoders,
        *,
        duration_sec,
        fps,
        resolutions,
        hwaccel_device,
        verify_caps,
    ):
        return [
            benchmark_service.EncoderBenchmarkResult(
                encoder="h264_qsv",
                vendor="intel",
                codec="h264",
                width=resolutions[0][0],
                height=resolutions[0][1],
                passed=False,
                error="MFX session: -9",
                fps=None,
                speed_x=None,
                bitrate_kbps=None,
                encoded_frames=None,
                elapsed_sec=2.1,
                realtime_multiplier=None,
                init_ms=None,
                gpu_utilization_percent=None,
                vram_used_mb=None,
                concurrent_session_cap=None,
                recommended_concurrent=None,
            )
        ]

    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=["h264_qsv"],
        ),
        patch.object(benchmark_service, "run_benchmark", side_effect=_fake_run),
    ):
        resp = await client.post("/api/v1/transcoding/benchmark")

    body = resp.json()
    failed = body["results"][0]
    assert failed["passed"] is False
    assert failed["error"] == "MFX session: -9"
    assert failed["fps"] is None


@pytest.mark.asyncio
async def test_benchmark_progress_idle_returns_running_false(client: AsyncClient):
    """When no benchmark is in flight the endpoint reports ``running=false``
    with every other field null — the desktop polls this between runs to
    decide whether to render the live progress card."""
    from services import benchmark_service

    # Ensure the global is clean (other tests may have raced).
    benchmark_service._progress = None

    resp = await client.get("/api/v1/transcoding/benchmark/progress")
    assert resp.status_code == 200
    body = resp.json()
    assert body["running"] is False
    assert body["current_encoder"] is None
    assert body["total_encoders"] is None


@pytest.mark.asyncio
async def test_benchmark_progress_returns_snapshot_when_running(
    client: AsyncClient,
):
    """Stuff the global directly to simulate an in-flight run; the
    endpoint should hand back the snapshot with running=true."""
    from services import benchmark_service

    benchmark_service._progress = {
        "started_at": "2026-05-07T15:30:12.123456+00:00",
        "total_encoders": 6,
        "completed": 2,
        "current_encoder": "h264_nvenc",
        "current_step": "encoding",
        "current_index": 3,
    }
    try:
        resp = await client.get("/api/v1/transcoding/benchmark/progress")
        assert resp.status_code == 200
        body = resp.json()
        assert body["running"] is True
        assert body["current_encoder"] == "h264_nvenc"
        assert body["current_step"] == "encoding"
        assert body["current_index"] == 3
        assert body["total_encoders"] == 6
        assert body["completed"] == 2
    finally:
        benchmark_service._progress = None


@pytest.mark.asyncio
async def test_benchmark_progress_requires_localhost(test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("198.51.100.4", 51000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.get(
            "/api/v1/transcoding/benchmark/progress",
            headers={"CF-Connecting-IP": "198.51.100.4"},
        )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_benchmark_requires_localhost(test_db):
    """Off-loopback callers get 403 — the endpoint exposes operator-tier
    diagnostics and must not be reachable through the tunnel."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("198.51.100.4", 51000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.post(
            "/api/v1/transcoding/benchmark",
            headers={"CF-Connecting-IP": "198.51.100.4"},
        )
    assert resp.status_code == 403
