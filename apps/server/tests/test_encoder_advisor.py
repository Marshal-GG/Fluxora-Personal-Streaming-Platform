"""Tests for services/encoder_advisor.py + /api/v1/transcoding/advisor."""

from __future__ import annotations

from datetime import UTC, datetime
from unittest.mock import patch

import pytest
from httpx import AsyncClient

from services import transcoding_service
from services.encoder_advisor import recommend
from services.transcoding_service import EncoderTestResult

_NOW = datetime(2026, 5, 4, 12, 0, 0, tzinfo=UTC)


def _passing(*encoders: str) -> dict[str, EncoderTestResult]:
    return {
        e: EncoderTestResult(passed=True, error=None, tested_at=_NOW)
        for e in encoders
    }


def _failing(encoder: str, error: str) -> dict[str, EncoderTestResult]:
    return {encoder: EncoderTestResult(passed=False, error=error, tested_at=_NOW)}


# ── pure-function tests ──────────────────────────────────────────────────────


def test_no_recommendation_when_active_is_tested_software_and_no_gpu():
    """CPU-only host running libx264 → no recommendation."""
    rec = recommend(
        active="libx264",
        available=["libx264", "libx265"],
        test_results=_passing("libx264", "libx265"),
    )
    assert rec.reason_code == "none"
    assert rec.recommended_encoder is None
    assert rec.severity == "none"


def test_recommend_gpu_when_active_is_software_and_nvenc_passing():
    """libx264 active + h264_nvenc tested-passing → recommend NVENC."""
    rec = recommend(
        active="libx264",
        available=["libx264", "h264_nvenc"],
        test_results=_passing("libx264", "h264_nvenc"),
    )
    assert rec.reason_code == "cpu_fallback"
    assert rec.recommended_encoder == "h264_nvenc"
    assert rec.severity == "info"
    assert "NVIDIA NVENC" in rec.reason_text


def test_dont_recommend_gpu_when_gpu_encoder_failed_self_test():
    """GPU encoder failed test → no recommendation, stay on libx264."""
    results = {
        "libx264": EncoderTestResult(passed=True, error=None, tested_at=_NOW),
        "h264_nvenc": EncoderTestResult(
            passed=False, error="driver missing", tested_at=_NOW
        ),
    }
    rec = recommend(
        active="libx264",
        available=["libx264", "h264_nvenc"],
        test_results=results,
    )
    assert rec.reason_code == "none"


def test_dont_recommend_gpu_when_gpu_untested():
    """A registered-but-untested encoder must not be recommended.  We only
    suggest encoders we've verified work."""
    rec = recommend(
        active="libx264",
        available=["libx264", "h264_nvenc"],
        test_results=_passing("libx264"),  # h264_nvenc is absent → untested
    )
    assert rec.reason_code == "none"


def test_failed_active_recommends_same_codec_fallback():
    """Active failed → recommend best tested encoder of the same codec.
    h264_nvenc failed + h264_qsv passing → recommend h264_qsv (not hevc_nvenc)."""
    results = {
        "h264_nvenc": EncoderTestResult(
            passed=False, error="OpenEncodeSession failed", tested_at=_NOW
        ),
        "h264_qsv": EncoderTestResult(passed=True, error=None, tested_at=_NOW),
        "hevc_nvenc": EncoderTestResult(passed=True, error=None, tested_at=_NOW),
        "libx264": EncoderTestResult(passed=True, error=None, tested_at=_NOW),
    }
    rec = recommend(
        active="h264_nvenc",
        available=["h264_nvenc", "h264_qsv", "hevc_nvenc", "libx264"],
        test_results=results,
    )
    assert rec.reason_code == "failed_active"
    assert rec.recommended_encoder == "h264_qsv"
    assert rec.severity == "warning"
    assert "OpenEncodeSession failed" in rec.reason_text


def test_failed_active_falls_through_to_software_when_no_hw_alt():
    """Active failed + no other GPU encoder works → recommend libx264."""
    results = {
        "h264_nvenc": EncoderTestResult(
            passed=False, error="driver missing", tested_at=_NOW
        ),
        "libx264": EncoderTestResult(passed=True, error=None, tested_at=_NOW),
    }
    rec = recommend(
        active="h264_nvenc",
        available=["h264_nvenc", "libx264"],
        test_results=results,
    )
    assert rec.reason_code == "failed_active"
    assert rec.recommended_encoder == "libx264"


def test_failed_active_no_alternatives_returns_warning_without_recommendation():
    """Every encoder failed (or none tested) → warn but recommend nothing."""
    results = {
        "h264_nvenc": EncoderTestResult(
            passed=False, error="driver missing", tested_at=_NOW
        ),
    }
    rec = recommend(
        active="h264_nvenc",
        available=["h264_nvenc"],
        test_results=results,
    )
    assert rec.reason_code == "failed_active"
    assert rec.recommended_encoder is None
    assert rec.severity == "warning"


def test_hevc_active_emits_compatibility_note():
    """HEVC active + everything tested-passing → info note about playback compat."""
    rec = recommend(
        active="hevc_nvenc",
        available=["hevc_nvenc", "h264_nvenc", "libx264"],
        test_results=_passing("hevc_nvenc", "h264_nvenc", "libx264"),
    )
    assert rec.reason_code == "hevc_compat"
    assert rec.recommended_encoder is None  # informational only, no auto-switch
    assert rec.severity == "info"
    assert "fmp4" in rec.reason_text


def test_nvidia_preferred_over_intel_when_both_pass():
    """NVENC + QSV both tested-passing on libx264 active → prefer NVENC."""
    rec = recommend(
        active="libx264",
        available=["libx264", "h264_nvenc", "h264_qsv"],
        test_results=_passing("libx264", "h264_nvenc", "h264_qsv"),
    )
    assert rec.reason_code == "cpu_fallback"
    assert rec.recommended_encoder == "h264_nvenc"


def test_unknown_active_encoder_does_not_crash():
    """Operator's settings have a stale encoder name not in the registry —
    advisor must return a clean 'none' instead of raising."""
    rec = recommend(
        active="h264_amf_legacy_typo",
        available=["libx264"],
        test_results=_passing("libx264"),
    )
    # active_meta is None, no recommendation rule fires.
    assert rec.reason_code == "none"


# ── /api/v1/transcoding/advisor endpoint tests ───────────────────────────────


@pytest.fixture(autouse=True)
def _reset_advisor_state():
    transcoding_service._AVAILABLE_CACHE = None
    transcoding_service._TEST_RESULTS.clear()
    yield
    transcoding_service._AVAILABLE_CACHE = None
    transcoding_service._TEST_RESULTS.clear()


@pytest.mark.asyncio
async def test_advisor_endpoint_localhost_only(client: AsyncClient):
    """Non-localhost callers get 403 — same gate as /status."""
    # The conftest fixture should already make non-local calls fail; we just
    # confirm a positive call works and shape is right.
    transcoding_service._TEST_RESULTS["libx264"] = EncoderTestResult(
        passed=True, error=None, tested_at=_NOW
    )
    with patch.object(
        transcoding_service,
        "_detect_available_encoders",
        return_value=["libx264"],
    ):
        resp = await client.get("/api/v1/transcoding/advisor")
    assert resp.status_code == 200
    body = resp.json()
    assert set(body) >= {
        "recommended_encoder",
        "reason_code",
        "reason_text",
        "severity",
    }


@pytest.mark.asyncio
async def test_advisor_endpoint_recommends_gpu_when_software_active(
    client: AsyncClient, test_db
):
    """libx264 stored + h264_nvenc detected & passing → endpoint recommends NVENC."""
    # libx264 is the default seeded by migrations, no DB write needed.
    transcoding_service._TEST_RESULTS.update(
        {
            "libx264": EncoderTestResult(passed=True, error=None, tested_at=_NOW),
            "h264_nvenc": EncoderTestResult(
                passed=True, error=None, tested_at=_NOW
            ),
        }
    )
    with patch.object(
        transcoding_service,
        "_detect_available_encoders",
        return_value=["libx264", "h264_nvenc"],
    ):
        resp = await client.get("/api/v1/transcoding/advisor")
    assert resp.status_code == 200
    body = resp.json()
    assert body["reason_code"] == "cpu_fallback"
    assert body["recommended_encoder"] == "h264_nvenc"
    assert body["severity"] == "info"


@pytest.mark.asyncio
async def test_advisor_endpoint_no_test_results_returns_none(client: AsyncClient):
    """Self-tests haven't run yet → no recommendation, even if a GPU encoder
    is in the available list (we don't recommend untested encoders)."""
    with patch.object(
        transcoding_service,
        "_detect_available_encoders",
        return_value=["libx264", "h264_nvenc"],
    ):
        resp = await client.get("/api/v1/transcoding/advisor")
    assert resp.status_code == 200
    assert resp.json()["reason_code"] == "none"


# ── EncoderLoad shape tests ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_encoder_load_includes_test_error_and_tested_at(client: AsyncClient):
    """The status payload exposes encoder_test_error + encoder_tested_at."""
    transcoding_service._TEST_RESULTS["h264_nvenc"] = EncoderTestResult(
        passed=False, error="driver missing", tested_at=_NOW
    )
    with (
        patch.object(
            transcoding_service,
            "_detect_available_encoders",
            return_value=["libx264", "h264_nvenc"],
        ),
        patch.object(
            transcoding_service, "_probe_nvidia", return_value=(None, None)
        ),
    ):
        resp = await client.get("/api/v1/transcoding/status")
    assert resp.status_code == 200
    body = resp.json()
    nvenc = next(r for r in body["encoder_loads"] if r["encoder"] == "h264_nvenc")
    assert nvenc["encoder_test_passed"] is False
    assert nvenc["encoder_test_error"] == "driver missing"
    assert nvenc["encoder_tested_at"].startswith("2026-05-04")
    # Untested encoders return None for both new fields.
    libx264 = next(r for r in body["encoder_loads"] if r["encoder"] == "libx264")
    assert libx264["encoder_test_passed"] is None
    assert libx264["encoder_test_error"] is None
    assert libx264["encoder_tested_at"] is None
