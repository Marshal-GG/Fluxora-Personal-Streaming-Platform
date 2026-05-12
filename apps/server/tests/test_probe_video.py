"""Tests for ffmpeg_service.probe_video — specifically the duration_sec
extraction that was missing before May 2026 and broke the static VOD
playlist generator.

The probe is mocked at the asyncio.create_subprocess_exec boundary so
no real ffprobe binary is required.
"""

import json
from unittest.mock import AsyncMock, patch

import pytest

from services import ffmpeg_service


def _fake_proc(stdout_payload: dict, returncode: int = 0):
    """Build an AsyncMock that mimics asyncio.subprocess.Process.communicate()."""
    proc = AsyncMock()
    proc.communicate = AsyncMock(
        return_value=(json.dumps(stdout_payload).encode("utf-8"), b"")
    )
    proc.returncode = returncode
    return proc


@pytest.mark.asyncio
async def test_probe_video_extracts_duration_from_format() -> None:
    payload = {
        "streams": [
            {
                "width": 1920,
                "height": 1080,
                "codec_name": "hevc",
                "color_transfer": "smpte2084",
            }
        ],
        "format": {"duration": "142.512"},
    }

    with (
        patch.object(ffmpeg_service, "_ffprobe_bin", return_value="ffprobe"),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(return_value=_fake_proc(payload)),
        ),
    ):
        info = await ffmpeg_service.probe_video("/fake/movie.mkv")

    assert info is not None
    assert info["duration_sec"] == pytest.approx(142.512)
    assert info["width"] == 1920
    assert info["codec_name"] == "hevc"


@pytest.mark.asyncio
async def test_probe_video_returns_none_duration_when_format_missing() -> None:
    payload = {
        "streams": [{"width": 640, "height": 480, "codec_name": "h264"}],
        # no "format" key — some unusual containers
    }

    with (
        patch.object(ffmpeg_service, "_ffprobe_bin", return_value="ffprobe"),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(return_value=_fake_proc(payload)),
        ),
    ):
        info = await ffmpeg_service.probe_video("/fake/movie.mkv")

    assert info is not None
    assert info["duration_sec"] is None  # nothing to extract; probe still succeeds


@pytest.mark.asyncio
async def test_probe_video_treats_zero_duration_as_unknown() -> None:
    """A '0.000000' duration field is meaningless for HLS playlist
    generation — treat it the same as a missing field so the static
    VOD playlist code falls back to the incremental playlist instead of
    emitting a single-segment playlist."""
    payload = {
        "streams": [{"width": 1280, "height": 720, "codec_name": "h264"}],
        "format": {"duration": "0.000000"},
    }

    with (
        patch.object(ffmpeg_service, "_ffprobe_bin", return_value="ffprobe"),
        patch(
            "asyncio.create_subprocess_exec",
            new=AsyncMock(return_value=_fake_proc(payload)),
        ),
    ):
        info = await ffmpeg_service.probe_video("/fake/movie.mkv")

    assert info is not None
    assert info["duration_sec"] is None


@pytest.mark.asyncio
async def test_probe_video_returns_none_when_ffprobe_missing() -> None:
    with patch.object(ffmpeg_service, "_ffprobe_bin", return_value=None):
        info = await ffmpeg_service.probe_video("/fake/movie.mkv")
    assert info is None
