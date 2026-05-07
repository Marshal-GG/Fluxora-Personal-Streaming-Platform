import uuid
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from main import app

HMAC_KEY = "test-secret-key-for-unit-tests-only"


async def _get_token(client: AsyncClient, monkeypatch) -> str:
    """Pair and approve a test client; return the bearer token."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    pair_body = {
        "client_id": "stream-test-client",
        "device_name": "Test Device",
        "platform": "android",
        "app_version": "0.1.0",
    }
    await client.post("/api/v1/auth/request-pair", json=pair_body)
    await client.post("/api/v1/auth/approve/stream-test-client")
    status = await client.get("/api/v1/auth/status/stream-test-client")
    return status.json()["auth_token"]


async def _insert_file(test_db) -> str:
    """Insert a media file and return its id."""
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (file_id, f"/media/{file_id}.mp4", "test.mp4", ".mp4", 1024000, now, now),
    )
    await test_db.commit()
    return file_id


def _mock_start_stream(playlist_path: Path):
    """Return an async mock that writes a minimal m3u8 and resolves to playlist_path."""

    async def _start(
        file_path: str, session_id: str, hls_root: Path, **_
    ) -> Path:
        playlist_path.parent.mkdir(parents=True, exist_ok=True)
        playlist_path.write_text("#EXTM3U\n#EXT-X-VERSION:3\n")
        return playlist_path

    return _start


# ── POST /api/v1/stream/start/{file_id} ─────────────────────────────────────


@pytest.mark.asyncio
async def test_start_stream_requires_auth(client: AsyncClient, test_db):
    file_id = await _insert_file(test_db)
    response = await client.post(f"/api/v1/stream/start/{file_id}")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_start_stream_file_not_found(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    with patch("routers.stream.ffmpeg_service.start_stream", new_callable=AsyncMock):
        response = await client.post(
            "/api/v1/stream/start/nonexistent-id",
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_start_stream_ffmpeg_not_found(client: AsyncClient, monkeypatch, test_db):
    token = await _get_token(client, monkeypatch)
    file_id = await _insert_file(test_db)

    async def _raise(*args, **kwargs):
        raise FileNotFoundError("FFmpeg not found")

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_raise):
        response = await client.post(
            f"/api/v1/stream/start/{file_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 503
    assert "FFmpeg" in response.json()["detail"]


@pytest.mark.asyncio
async def test_start_stream_success(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    token = await _get_token(client, monkeypatch)
    file_id = await _insert_file(test_db)

    captured_session_id: list[str] = []

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        captured_session_id.append(session_id)
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        response = await client.post(
            f"/api/v1/stream/start/{file_id}",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 201
    data = response.json()
    assert data["file_id"] == file_id
    assert "session_id" in data
    assert "playlist.m3u8" in data["playlist_url"]
    assert data["session_id"] == captured_session_id[0]


# ── GET /api/v1/stream/{session_id} ─────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_session(client: AsyncClient, monkeypatch, test_db, tmp_path):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    response = await client.get(f"/api/v1/stream/{session_id}", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == session_id
    assert data["file_id"] == file_id
    assert data["ended_at"] is None


@pytest.mark.asyncio
async def test_get_session_not_found(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    response = await client.get(
        "/api/v1/stream/nonexistent-id",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404


# ── DELETE /api/v1/stream/{session_id} ──────────────────────────────────────


@pytest.mark.asyncio
async def test_stop_stream(client: AsyncClient, monkeypatch, test_db, tmp_path):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    with (
        patch(
            "routers.stream.ffmpeg_service.stop_stream",
            new_callable=AsyncMock,
        ) as mock_stop,
        patch("routers.stream.ffmpeg_service.cleanup_session_dir") as mock_clean,
    ):
        response = await client.delete(f"/api/v1/stream/{session_id}", headers=headers)

    assert response.status_code == 204
    mock_stop.assert_awaited_once_with(session_id)
    mock_clean.assert_called_once()

    # Session should now show ended_at
    get_resp = await client.get(f"/api/v1/stream/{session_id}", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["ended_at"] is not None


@pytest.mark.asyncio
async def test_stop_stream_wrong_client(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """A second client cannot stop another client's session."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)

    # Pair a second client
    await client.post(
        "/api/v1/auth/request-pair",
        json={
            "client_id": "other-client",
            "device_name": "Other",
            "platform": "ios",
            "app_version": "0.1.0",
        },
    )
    await client.post("/api/v1/auth/approve/other-client")
    other_status = await client.get("/api/v1/auth/status/other-client")
    other_token = other_status.json()["auth_token"]

    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    async with AsyncClient(
        transport=ASGITransport(app=app, client=("192.168.1.100", 50000)),
        base_url="http://test",
    ) as lan:
        response = await lan.delete(
            f"/api/v1/stream/{session_id}",
            headers={"Authorization": f"Bearer {other_token}"},
        )
    assert response.status_code == 403


# ── HLS serving ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_serve_hls_playlist(client: AsyncClient, monkeypatch, test_db, tmp_path):
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n#EXT-X-VERSION:3\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    # Point HLS router at the tmp_path where mock wrote the file
    with patch("routers.stream.settings") as mock_settings:
        mock_settings.hls_tmp_path = tmp_path
        response = await client.get(
            f"/api/v1/hls/{session_id}/playlist.m3u8", headers=headers
        )

    assert response.status_code == 200
    assert "EXTM3U" in response.text


@pytest.mark.asyncio
async def test_serve_hls_path_traversal_rejected(client: AsyncClient, monkeypatch):
    token = await _get_token(client, monkeypatch)
    response = await client.get(
        "/api/v1/hls/some-session/../../../etc/passwd",
        headers={"Authorization": f"Bearer {token}"},
    )
    # FastAPI decodes %2F but the path parameter itself should be blocked
    assert response.status_code in {400, 404, 422}


# ── _input_decoder_args (NVIDIA cuvid hint) ──────────────────────────────────


def test_input_decoder_args_av1_nvenc_returns_av1_cuvid():
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _input_decoder_args

    assert _input_decoder_args("av1", ENCODER_REGISTRY["h264_nvenc"]) == [
        "-c:v",
        "av1_cuvid",
    ]


def test_input_decoder_args_hevc_nvenc_returns_hevc_cuvid():
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _input_decoder_args

    assert _input_decoder_args("hevc", ENCODER_REGISTRY["hevc_nvenc"]) == [
        "-c:v",
        "hevc_cuvid",
    ]


def test_input_decoder_args_non_nvidia_returns_empty():
    """QSV / VAAPI / VideoToolbox / software all fall through to FFmpeg's
    auto-selection — only NVENC has the broken-decoder workaround today."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _input_decoder_args

    for enc in ("h264_qsv", "h264_vaapi", "h264_videotoolbox", "libx264"):
        assert _input_decoder_args("av1", ENCODER_REGISTRY[enc]) == []


def test_input_decoder_args_unknown_codec_returns_empty():
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _input_decoder_args

    assert (
        _input_decoder_args("speedrun-mvp9", ENCODER_REGISTRY["h264_nvenc"]) == []
    )


def test_input_decoder_args_none_codec_returns_empty():
    """Untested files (codec_name still NULL) get no decoder hint — defer
    to FFmpeg's auto-selection."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _input_decoder_args

    assert _input_decoder_args(None, ENCODER_REGISTRY["h264_nvenc"]) == []


def test_input_decoder_args_h265_alias_resolves_to_hevc_cuvid():
    """Some sources report `h265` instead of `hevc` for the same codec."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _input_decoder_args

    assert _input_decoder_args("h265", ENCODER_REGISTRY["h264_nvenc"]) == [
        "-c:v",
        "hevc_cuvid",
    ]


# ── _is_cuvid_failure (retry classifier) ─────────────────────────────────────


def test_is_cuvid_failure_detects_chroma_format_error():
    """Real-world stderr from RTX 30 / HDR AV1 source — must trigger retry."""
    from services.ffmpeg_service import _is_cuvid_failure

    tail = (
        "[av1_cuvid @ 000001f3248e4fc0] Codec av1_cuvid is not supported "
        "with this chroma format.\n"
        "[vist#0:0/av1 @ 000001f3248e5840] [dec:av1_cuvid @ 000001f3248e5080] "
        "Error while opening decoder: Invalid argument\n"
    )
    assert _is_cuvid_failure(tail) is True


def test_is_cuvid_failure_detects_generic_cuvid_tag():
    from services.ffmpeg_service import _is_cuvid_failure

    assert _is_cuvid_failure(
        "[hevc_cuvid @ 0x1] some other cuvid-tagged failure"
    ) is True


def test_is_cuvid_failure_does_not_match_unrelated_failures():
    """Generic decode errors / file-not-found / encoder errors must NOT
    trigger the cuvid retry — software fallback won't help for those."""
    from services.ffmpeg_service import _is_cuvid_failure

    assert _is_cuvid_failure("Error opening input: No such file or directory") is False
    assert _is_cuvid_failure("[av1 @ 0x1] Failed to get pixel format") is False
    assert _is_cuvid_failure("") is False
    assert _is_cuvid_failure("Could not open codec libx264") is False


def test_is_cuvid_failure_detects_av1_nvdec_unavailable_on_turing():
    """RTX 2060 (Turing) has no AV1 NVDEC.  Surfaces as
    `Your platform doesn't support hardware accelerated AV1 decoding`
    + `Failed setup for format cuda: hwaccel initialisation returned
    error`.  Retry must drop the entire CUDA input pipeline, not just
    the cuvid hint."""
    from services.ffmpeg_service import _is_cuvid_failure

    tail = (
        "[av1 @ 0x1] Failed setup for format cuda: hwaccel initialisation "
        "returned error.\n"
        "[av1 @ 0x1] Your platform doesn't support hardware accelerated "
        "AV1 decoding.\n"
    )
    assert _is_cuvid_failure(tail) is True


def test_is_cuvid_failure_detects_hwaccel_init_error():
    """Generic `-hwaccel cuda` setup failures must trigger the retry."""
    from services.ffmpeg_service import _is_cuvid_failure

    assert _is_cuvid_failure(
        "[hevc @ 0x1] Failed setup for format cuda: hwaccel initialisation "
        "returned error."
    ) is True


def test_is_cuvid_failure_detects_lacking_capabilities():
    """`Hardware is lacking required capabilities` is the specific
    NVDEC-doesn't-support-this-codec error from libavutil."""
    from services.ffmpeg_service import _is_cuvid_failure

    assert _is_cuvid_failure(
        "[av1 @ 0x1] Hardware is lacking required capabilities"
    ) is True


# ── _ensure_fmp4_init_segment ───────────────────────────────────────────────


@pytest.mark.asyncio
async def test_ensure_fmp4_init_segment_skips_when_file_already_exists(
    tmp_path,
):
    """If FFmpeg's HLS muxer DID write init.mp4, don't regenerate it —
    just return True without spawning anything."""
    from unittest.mock import AsyncMock, patch

    from services.ffmpeg_service import _ensure_fmp4_init_segment

    init_path = tmp_path / "init.mp4"
    init_path.write_bytes(b"existing init segment moov data")

    mock = AsyncMock()
    with patch(
        "services.ffmpeg_service.asyncio.create_subprocess_exec", mock
    ):
        result = await _ensure_fmp4_init_segment(tmp_path, "irrelevant.mp4")

    assert result is True
    assert mock.call_count == 0  # short-circuited; no FFmpeg spawned


@pytest.mark.asyncio
async def test_ensure_fmp4_init_segment_treats_zero_byte_file_as_missing(
    tmp_path,
):
    """A zero-byte init.mp4 (FFmpeg created the file but wrote nothing)
    should trigger regeneration."""
    from unittest.mock import AsyncMock, patch

    from services.ffmpeg_service import _ensure_fmp4_init_segment

    (tmp_path / "init.mp4").write_bytes(b"")  # 0 bytes

    fake_proc = AsyncMock()
    fake_proc.wait = AsyncMock(return_value=0)
    fake_proc.returncode = 0

    async def fake_create(*args, **kwargs):
        # Simulate FFmpeg writing real bytes to the path before exit.
        (tmp_path / "init.mp4").write_bytes(b"new init data")
        return fake_proc

    with (
        patch(
            "services.ffmpeg_service.asyncio.create_subprocess_exec",
            side_effect=fake_create,
        ),
        patch("services.ffmpeg_service._ffmpeg_bin", return_value="ffmpeg"),
    ):
        result = await _ensure_fmp4_init_segment(tmp_path, "src.mp4")

    assert result is True
    assert (tmp_path / "init.mp4").stat().st_size > 0


@pytest.mark.asyncio
async def test_ensure_fmp4_init_segment_returns_false_on_ffmpeg_missing(
    tmp_path,
):
    from unittest.mock import patch

    from services.ffmpeg_service import _ensure_fmp4_init_segment

    with patch(
        "services.ffmpeg_service._ffmpeg_bin",
        side_effect=FileNotFoundError("no ffmpeg"),
    ):
        result = await _ensure_fmp4_init_segment(tmp_path, "src.mp4")

    assert result is False
    assert not (tmp_path / "init.mp4").exists()


# ── HDR tonemap path ────────────────────────────────────────────────────────


def test_build_ffmpeg_cmd_injects_tonemap_chain_when_requested(tmp_path):
    """apply_hdr_tonemap=True must inject the zscale + Hable chain
    into -vf ahead of any encoder filter chain."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _build_ffmpeg_cmd

    cmd = _build_ffmpeg_cmd(
        file_path="/tmp/source.mp4",
        session_dir=tmp_path,
        playlist=tmp_path / "playlist.m3u8",
        meta=ENCODER_REGISTRY["libx264"],
        preset="veryfast",
        crf=23,
        hwaccel_device=None,
        source_codec="hevc",
        direct_remux=False,
        direct_remux_hevc=False,
        use_gpu_input=False,
        apply_hdr_tonemap=True,
    )
    # The -vf chain must be present and contain the tonemap step.
    assert "-vf" in cmd
    vf_value = cmd[cmd.index("-vf") + 1]
    assert "tonemap=tonemap=hable" in vf_value
    assert "zscale=t=linear" in vf_value
    assert "format=yuv420p" in vf_value


def test_build_ffmpeg_cmd_omits_tonemap_when_not_requested(tmp_path):
    """The default path must NOT inject the tonemap chain — passing it
    through libx264 unconditionally would re-process every SDR file."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _build_ffmpeg_cmd

    cmd = _build_ffmpeg_cmd(
        file_path="/tmp/source.mp4",
        session_dir=tmp_path,
        playlist=tmp_path / "playlist.m3u8",
        meta=ENCODER_REGISTRY["libx264"],
        preset="veryfast",
        crf=23,
        hwaccel_device=None,
        source_codec="h264",
        direct_remux=False,
        direct_remux_hevc=False,
        use_gpu_input=False,
        apply_hdr_tonemap=False,
    )
    # libx264 has no encoder vf_chain, so no -vf flag at all.
    assert "-vf" not in cmd


def test_build_ffmpeg_cmd_chains_tonemap_with_vaapi_filters(tmp_path):
    """VAAPI's `format=nv12|vaapi,hwupload` filter chain must be appended
    *after* the tonemap chain so the GPU upload step sees yuv420p output."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _build_ffmpeg_cmd

    cmd = _build_ffmpeg_cmd(
        file_path="/tmp/source.mp4",
        session_dir=tmp_path,
        playlist=tmp_path / "playlist.m3u8",
        meta=ENCODER_REGISTRY["h264_vaapi"],
        preset="veryfast",
        crf=23,
        hwaccel_device="/dev/dri/renderD128",
        source_codec="hevc",
        direct_remux=False,
        direct_remux_hevc=False,
        use_gpu_input=False,
        apply_hdr_tonemap=True,
    )
    vf_value = cmd[cmd.index("-vf") + 1]
    # Tonemap chain comes first, then the VAAPI upload filter.
    tonemap_pos = vf_value.find("tonemap=")
    hwupload_pos = vf_value.find("hwupload")
    assert tonemap_pos >= 0
    assert hwupload_pos >= 0
    assert tonemap_pos < hwupload_pos


def test_build_ffmpeg_cmd_keeps_stream_copy_unchanged_with_tonemap(tmp_path):
    """direct_remux=True ignores apply_hdr_tonemap — the caller is
    responsible for forcing transcode mode (see start_stream's
    apply_hdr_tonemap branch).  No -vf is injected."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _build_ffmpeg_cmd

    cmd = _build_ffmpeg_cmd(
        file_path="/tmp/source.mp4",
        session_dir=tmp_path,
        playlist=tmp_path / "playlist.m3u8",
        meta=ENCODER_REGISTRY["libx264"],
        preset="veryfast",
        crf=23,
        hwaccel_device=None,
        source_codec="hevc",
        direct_remux=True,  # streamcopy
        direct_remux_hevc=True,
        use_gpu_input=False,
        apply_hdr_tonemap=True,
    )
    assert "-c:v" in cmd
    # Stream-copy: -c:v copy
    assert cmd[cmd.index("-c:v") + 1] == "copy"
    assert "-vf" not in cmd


# ── _write_static_vod_playlist ──────────────────────────────────────────────


def test_write_static_vod_playlist_lists_every_segment(tmp_path):
    """A 30-second clip at hls_time=10 produces 3 segments listed in the
    playlist; the seek bar in any HLS-VOD player will span all 30 s
    without waiting for FFmpeg to finish writing."""
    from services.ffmpeg_service import _write_static_vod_playlist

    playlist = tmp_path / "playlist.m3u8"
    n = _write_static_vod_playlist(
        playlist=playlist,
        duration_sec=30.0,
        hls_time=10.0,
        use_fmp4=False,
    )
    assert n == 3
    text = playlist.read_text(encoding="utf-8")
    assert "#EXT-X-PLAYLIST-TYPE:VOD" in text
    assert "#EXT-X-ENDLIST" in text
    assert "seg00000.ts" in text
    assert "seg00001.ts" in text
    assert "seg00002.ts" in text
    assert "seg00003.ts" not in text


def test_write_static_vod_playlist_handles_partial_last_segment(tmp_path):
    """A 25-second clip at hls_time=10 → 3 segments where the last is 5 s."""
    from services.ffmpeg_service import _write_static_vod_playlist

    playlist = tmp_path / "playlist.m3u8"
    _write_static_vod_playlist(
        playlist=playlist,
        duration_sec=25.0,
        hls_time=10.0,
        use_fmp4=False,
    )
    text = playlist.read_text(encoding="utf-8")
    # Sum of EXTINF durations should equal source duration (within FP tolerance).
    import re
    extinfs = re.findall(r"#EXTINF:([\d.]+),", text)
    total = sum(float(d) for d in extinfs)
    assert abs(total - 25.0) < 0.01


def test_write_static_vod_playlist_emits_init_segment_for_fmp4(tmp_path):
    """fmp4 playlists need #EXT-X-MAP pointing at init.mp4 — the player
    fetches it before any segment to set up the decoder."""
    from services.ffmpeg_service import _write_static_vod_playlist

    playlist = tmp_path / "playlist.m3u8"
    _write_static_vod_playlist(
        playlist=playlist,
        duration_sec=10.0,
        hls_time=10.0,
        use_fmp4=True,
    )
    text = playlist.read_text(encoding="utf-8")
    assert '#EXT-X-MAP:URI="init.mp4"' in text
    assert "seg00000.m4s" in text
    # VERSION 6 required for #EXT-X-MAP per Apple HLS spec.
    assert "#EXT-X-VERSION:6" in text


def test_write_static_vod_playlist_zero_duration_writes_nothing(tmp_path):
    """Duration unknown / zero → return 0 + no playlist file written."""
    from services.ffmpeg_service import _write_static_vod_playlist

    playlist = tmp_path / "playlist.m3u8"
    n = _write_static_vod_playlist(
        playlist=playlist,
        duration_sec=0.0,
        hls_time=10.0,
        use_fmp4=False,
    )
    assert n == 0
    assert not playlist.exists()


@pytest.mark.asyncio
async def test_resolve_source_metadata_returns_codec_and_hdr(tmp_path, test_db):
    """Verify the (codec, hdr_format) tuple comes back from the DB row
    when both fields are populated."""
    import uuid
    from datetime import UTC, datetime

    from services.ffmpeg_service import _resolve_source_metadata

    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, duration_sec,
             library_id, tmdb_id, codec_name, hdr_format,
             created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            file_id, "/m/test.mkv", "test.mkv", ".mkv", 1024, 120.0,
            None, None, "hevc", "HDR10",
            now, now,
        ),
    )
    await test_db.commit()

    codec, hdr = await _resolve_source_metadata(test_db, "/m/test.mkv")
    assert codec == "hevc"
    assert hdr == "HDR10"


# ── _build_ffmpeg_cmd loglevel selection ────────────────────────────────────


def test_build_ffmpeg_cmd_uses_warning_loglevel_for_transcode(tmp_path):
    """Transcode sessions must use ``-loglevel warning`` so that
    suppressed-under-error failures (unsupported pixel format, missing
    decoder, hwaccel rejection) actually reach our captured stderr.
    The whole point of the new diagnostic regime is that
    ``<no stderr captured>`` should never appear when FFmpeg had
    something to say."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _build_ffmpeg_cmd

    cmd = _build_ffmpeg_cmd(
        file_path="/tmp/source.mp4",
        session_dir=tmp_path,
        playlist=tmp_path / "playlist.m3u8",
        meta=ENCODER_REGISTRY["libx264"],
        preset="veryfast",
        crf=23,
        hwaccel_device=None,
        source_codec="vp9",
        direct_remux=False,
        direct_remux_hevc=False,
        use_gpu_input=False,
        apply_hdr_tonemap=False,
    )
    assert "-loglevel" in cmd
    assert cmd[cmd.index("-loglevel") + 1] == "warning"


def test_build_ffmpeg_cmd_uses_error_loglevel_for_stream_copy(tmp_path):
    """Stream-copy keeps ``-loglevel error`` — its hot path is fully
    re-muxing source bitstream, which is verbose at ``warning`` (every
    keyframe gets a heuristic note from the HLS muxer) and noisy in
    the operator's log without adding diagnostic value."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _build_ffmpeg_cmd

    cmd = _build_ffmpeg_cmd(
        file_path="/tmp/source.mp4",
        session_dir=tmp_path,
        playlist=tmp_path / "playlist.m3u8",
        meta=ENCODER_REGISTRY["libx264"],
        preset="veryfast",
        crf=23,
        hwaccel_device=None,
        source_codec="h264",
        direct_remux=True,
        direct_remux_hevc=False,
        use_gpu_input=False,
        apply_hdr_tonemap=False,
    )
    assert cmd[cmd.index("-loglevel") + 1] == "error"


# ── _spawn_ffmpeg_attempt: pipeline-aware timeout + killed_after_timeout ────


def _fake_subprocess_proc(*, returncode_seq: list[int | None], pid: int = 4321):
    """Build an AsyncMock that mimics ``asyncio.subprocess.Process``.

    ``returncode_seq`` is consumed one entry at a time on each access of
    ``proc.returncode`` — pass ``[None, None, ..., 0]`` to simulate a
    process that's alive for the first N polls and then exits.
    Using a list lets us simulate "exited mid-poll-loop" cleanly.
    """
    from unittest.mock import AsyncMock, MagicMock

    proc = MagicMock()
    proc.pid = pid
    state = {"seq": list(returncode_seq), "final": returncode_seq[-1]}

    def _get_returncode(_self=None):
        if state["seq"]:
            return state["seq"].pop(0)
        return state["final"]

    type(proc).returncode = property(lambda self: _get_returncode())

    async def _wait():
        # Drain whatever the seq still has; final returncode wins.
        return state["final"] if state["final"] is not None else 0

    proc.wait = AsyncMock(side_effect=_wait)
    proc.terminate = MagicMock()
    proc.kill = MagicMock()
    return proc


@pytest.mark.asyncio
async def test_spawn_attempt_succeeds_when_playlist_appears(tmp_path):
    """The happy path — playlist file exists on the first poll, FFmpeg
    is still running, return (True, "", None, False)."""
    from unittest.mock import AsyncMock, patch

    from services import ffmpeg_service

    playlist = tmp_path / "playlist.m3u8"
    playlist.write_text("#EXTM3U\n")  # exists from the first iteration

    fake_proc = _fake_subprocess_proc(returncode_seq=[None])

    with patch(
        "asyncio.create_subprocess_exec",
        new=AsyncMock(return_value=fake_proc),
    ):
        (
            succeeded,
            tail,
            returncode,
            killed,
        ) = await ffmpeg_service._spawn_ffmpeg_attempt(
            ["ffmpeg", "-i", "x.mp4"],
            session_id="success-sid",
            playlist=playlist,
            playlist_timeout_sec=2.0,
        )

    assert succeeded is True
    assert tail == ""
    assert returncode is None
    assert killed is False
    fake_proc.terminate.assert_not_called()
    # Cleanup state on the module so the test doesn't leak into others.
    ffmpeg_service._active.pop("success-sid", None)
    ffmpeg_service._stderr_paths.pop("success-sid", None)


@pytest.mark.asyncio
async def test_spawn_attempt_returns_killed_after_timeout_when_playlist_never_appears(
    tmp_path,
):
    """The HDR-tonemap regression case: process is healthy, never
    voluntarily exits, but the playlist budget runs out.  We must
    return killed_after_timeout=True so the error path can surface
    a meaningful diagnostic instead of "exit code 1"."""
    from unittest.mock import AsyncMock, patch

    from services import ffmpeg_service

    playlist = tmp_path / "playlist.m3u8"  # never created

    fake_proc = _fake_subprocess_proc(returncode_seq=[None])

    with patch(
        "asyncio.create_subprocess_exec",
        new=AsyncMock(return_value=fake_proc),
    ):
        (
            succeeded,
            tail,
            returncode,
            killed,
        ) = await ffmpeg_service._spawn_ffmpeg_attempt(
            ["ffmpeg", "-i", "x.mp4"],
            session_id="timeout-sid",
            playlist=playlist,
            playlist_timeout_sec=0.3,  # short to keep the test snappy
        )

    assert succeeded is False
    assert killed is True
    fake_proc.terminate.assert_called_once()
    ffmpeg_service._active.pop("timeout-sid", None)
    ffmpeg_service._stderr_paths.pop("timeout-sid", None)


@pytest.mark.asyncio
async def test_spawn_attempt_returns_not_killed_when_process_exits_prematurely(
    tmp_path,
):
    """Process voluntarily exits before the playlist appears — that's a
    real FFmpeg failure (bad codec, missing input, etc.) and the
    caller should see killed_after_timeout=False so the operator gets
    "FFmpeg exited prematurely with code N" instead of the timeout
    diagnostic."""
    from unittest.mock import AsyncMock, patch

    from services import ffmpeg_service

    playlist = tmp_path / "playlist.m3u8"  # never created

    # Returncode is None on first poll (alive), 2 thereafter (exited).
    fake_proc = _fake_subprocess_proc(returncode_seq=[None, 2])

    with patch(
        "asyncio.create_subprocess_exec",
        new=AsyncMock(return_value=fake_proc),
    ):
        (
            succeeded,
            tail,
            returncode,
            killed,
        ) = await ffmpeg_service._spawn_ffmpeg_attempt(
            ["ffmpeg", "-i", "x.mp4"],
            session_id="exit-sid",
            playlist=playlist,
            playlist_timeout_sec=2.0,
        )

    assert succeeded is False
    assert killed is False
    assert returncode == 2
    fake_proc.terminate.assert_not_called()
    ffmpeg_service._active.pop("exit-sid", None)
    ffmpeg_service._stderr_paths.pop("exit-sid", None)


@pytest.mark.asyncio
async def test_spawn_attempt_respects_supplied_timeout(tmp_path):
    """The timeout parameter must drive how long we wait — a 0.2 s
    timeout returns timeout-killed in well under 1 s; a 5 s timeout
    would block the test indefinitely on the same input."""
    import time
    from unittest.mock import AsyncMock, patch

    from services import ffmpeg_service

    playlist = tmp_path / "playlist.m3u8"  # never appears

    fake_proc = _fake_subprocess_proc(returncode_seq=[None])

    with patch(
        "asyncio.create_subprocess_exec",
        new=AsyncMock(return_value=fake_proc),
    ):
        t0 = time.perf_counter()
        succeeded, _tail, _rc, killed = await ffmpeg_service._spawn_ffmpeg_attempt(
            ["ffmpeg", "-i", "x.mp4"],
            session_id="budget-sid",
            playlist=playlist,
            playlist_timeout_sec=0.2,
        )
        elapsed = time.perf_counter() - t0

    assert succeeded is False
    assert killed is True
    # Should be at least the timeout, but well under 5× — generous bound
    # to keep the test stable on a busy CI box.
    assert 0.18 <= elapsed < 1.5
    ffmpeg_service._active.pop("budget-sid", None)
    ffmpeg_service._stderr_paths.pop("budget-sid", None)


# ── Seek-restart: _build_ffmpeg_cmd seek_sec + start_segment_index ──────────


def test_build_ffmpeg_cmd_inserts_ss_before_input_when_seek_requested(tmp_path):
    """``-ss`` must come BEFORE ``-i`` so FFmpeg performs an input-side
    seek (decoder-fast for transcode, keyframe-snap for stream-copy).
    Output-side seek (after ``-i``) decodes from t=0 and discards
    frames — defeats the entire point of the restart."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _build_ffmpeg_cmd

    cmd = _build_ffmpeg_cmd(
        file_path="/tmp/source.mp4",
        session_dir=tmp_path,
        playlist=tmp_path / "playlist.m3u8",
        meta=ENCODER_REGISTRY["libx264"],
        preset="veryfast",
        crf=23,
        hwaccel_device=None,
        source_codec="vp9",
        direct_remux=False,
        direct_remux_hevc=False,
        use_gpu_input=False,
        seek_sec=72.0,
    )
    ss_idx = cmd.index("-ss")
    i_idx = cmd.index("-i")
    assert ss_idx < i_idx
    assert cmd[ss_idx + 1] == "72.000"


def test_build_ffmpeg_cmd_omits_ss_when_seek_is_zero(tmp_path):
    """Default path (initial spawn) must not inject ``-ss 0`` — some
    older FFmpeg builds error on a zero seek with hwaccel input
    pipelines.  Cleaner to leave the flag off."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _build_ffmpeg_cmd

    cmd = _build_ffmpeg_cmd(
        file_path="/tmp/source.mp4",
        session_dir=tmp_path,
        playlist=tmp_path / "playlist.m3u8",
        meta=ENCODER_REGISTRY["libx264"],
        preset="veryfast",
        crf=23,
        hwaccel_device=None,
        source_codec="h264",
        direct_remux=True,
        direct_remux_hevc=False,
        use_gpu_input=False,
    )
    assert "-ss" not in cmd


def test_build_ffmpeg_cmd_emits_start_number_when_index_nonzero(tmp_path):
    """``-start_number K`` is what makes FFmpeg's HLS muxer write
    ``seg<K>.ts`` instead of ``seg00000.ts`` — required so the
    rewritten static playlist's segment URLs match what FFmpeg actually
    produces on disk."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _build_ffmpeg_cmd

    cmd = _build_ffmpeg_cmd(
        file_path="/tmp/source.mp4",
        session_dir=tmp_path,
        playlist=tmp_path / "playlist.m3u8",
        meta=ENCODER_REGISTRY["libx264"],
        preset="veryfast",
        crf=23,
        hwaccel_device=None,
        source_codec="h264",
        direct_remux=True,
        direct_remux_hevc=False,
        use_gpu_input=False,
        start_segment_index=12,
    )
    sn_idx = cmd.index("-start_number")
    assert cmd[sn_idx + 1] == "12"


def test_build_ffmpeg_cmd_omits_start_number_when_index_zero(tmp_path):
    """The default initial spawn must not emit ``-start_number 0`` —
    that's already FFmpeg's default and adding the flag is just noise
    in the command line."""
    from services.encoder_registry import ENCODER_REGISTRY
    from services.ffmpeg_service import _build_ffmpeg_cmd

    cmd = _build_ffmpeg_cmd(
        file_path="/tmp/source.mp4",
        session_dir=tmp_path,
        playlist=tmp_path / "playlist.m3u8",
        meta=ENCODER_REGISTRY["libx264"],
        preset="veryfast",
        crf=23,
        hwaccel_device=None,
        source_codec="h264",
        direct_remux=True,
        direct_remux_hevc=False,
        use_gpu_input=False,
    )
    assert "-start_number" not in cmd


# ── Seek-restart: _write_static_vod_playlist with discontinuity ─────────────


def test_static_vod_playlist_shifts_media_sequence_for_seek(tmp_path):
    """A 60 s clip at hls_time=10 with start_segment_index=3 must
    list segments 3..5 only — segments 0..2 are not in this re-emitted
    view and the player's media-sequence counter aligns with FFmpeg's
    ``-start_number 3`` output on disk."""
    from services.ffmpeg_service import _write_static_vod_playlist

    playlist = tmp_path / "playlist.m3u8"
    n = _write_static_vod_playlist(
        playlist=playlist,
        duration_sec=60.0,
        hls_time=10.0,
        use_fmp4=False,
        start_segment_index=3,
        discontinuity_seq=1,
    )
    assert n == 3  # 3 segments: 3, 4, 5
    text = playlist.read_text(encoding="utf-8")
    assert "#EXT-X-MEDIA-SEQUENCE:3" in text
    assert "seg00003.ts" in text
    assert "seg00005.ts" in text
    # The pre-seek segments must not appear.
    assert "seg00000.ts" not in text
    assert "seg00002.ts" not in text


def test_static_vod_playlist_emits_discontinuity_marker_on_restart(tmp_path):
    """``discontinuity_seq > 0`` must produce both
    ``#EXT-X-DISCONTINUITY-SEQUENCE`` (header) and
    ``#EXT-X-DISCONTINUITY`` (right before the first listed segment)
    so the player flushes its decode buffer on reload."""
    from services.ffmpeg_service import _write_static_vod_playlist

    playlist = tmp_path / "playlist.m3u8"
    _write_static_vod_playlist(
        playlist=playlist,
        duration_sec=30.0,
        hls_time=10.0,
        use_fmp4=False,
        start_segment_index=1,
        discontinuity_seq=2,
    )
    text = playlist.read_text(encoding="utf-8")
    assert "#EXT-X-DISCONTINUITY-SEQUENCE:2" in text
    # Discontinuity tag must precede the first segment URL.
    disc_pos = text.find("#EXT-X-DISCONTINUITY\n")
    seg_pos = text.find("seg00001.ts")
    assert disc_pos > 0
    assert seg_pos > disc_pos


def test_static_vod_playlist_no_discontinuity_when_initial_spawn(tmp_path):
    """Initial spawn (start_segment_index=0, discontinuity_seq=0) must
    NOT emit any discontinuity tags — those would tell the player the
    file has internal cuts that aren't there.  Verifies the new
    parameters' defaults stay backward-compatible with prior behaviour."""
    from services.ffmpeg_service import _write_static_vod_playlist

    playlist = tmp_path / "playlist.m3u8"
    _write_static_vod_playlist(
        playlist=playlist,
        duration_sec=30.0,
        hls_time=10.0,
        use_fmp4=False,
    )
    text = playlist.read_text(encoding="utf-8")
    assert "#EXT-X-DISCONTINUITY" not in text  # neither -SEQUENCE nor bare


def test_static_vod_playlist_handles_seek_past_end_of_file(tmp_path):
    """If a misbehaving client seeks past the file's duration, the
    rewritten playlist must still be a valid VOD playlist (just empty)
    so the player resolves cleanly to end-of-stream rather than 404
    on the playlist itself."""
    from services.ffmpeg_service import _write_static_vod_playlist

    playlist = tmp_path / "playlist.m3u8"
    n = _write_static_vod_playlist(
        playlist=playlist,
        duration_sec=30.0,
        hls_time=10.0,
        use_fmp4=False,
        start_segment_index=99,
        discontinuity_seq=1,
    )
    assert n == 0
    text = playlist.read_text(encoding="utf-8")
    assert "#EXTM3U" in text
    assert "#EXT-X-PLAYLIST-TYPE:VOD" in text
    assert "#EXT-X-ENDLIST" in text
    # No segment URLs.
    assert "seg" not in text


# ── Seek-restart: restart_stream behaviour ──────────────────────────────────


@pytest.mark.asyncio
async def test_restart_stream_terminates_prior_ffmpeg(tmp_path):
    """``restart_stream`` must kill the previous spawn before starting a
    new one — the alternative is two FFmpegs writing to the same
    session directory at once.  We verify by checking the previous
    proc's ``terminate()`` was called."""
    from unittest.mock import AsyncMock, MagicMock, patch

    from services import ffmpeg_service

    session_id = "restart-sid-1"
    fake_proc = MagicMock()
    fake_proc.returncode = None  # alive
    fake_proc.terminate = MagicMock()
    fake_proc.kill = MagicMock()
    fake_proc.wait = AsyncMock(return_value=0)
    ffmpeg_service._active[session_id] = fake_proc

    # Stub start_stream so restart_stream's tail call doesn't actually
    # spawn ffmpeg.
    async def _fake_start(*a, **kw):
        return tmp_path / session_id / "playlist.m3u8"

    with patch.object(ffmpeg_service, "start_stream", side_effect=_fake_start):
        await ffmpeg_service.restart_stream(
            "/tmp/source.mp4", session_id, tmp_path, seek_sec=42.0,
        )

    fake_proc.terminate.assert_called_once()
    # Cleanup — remove the lock + counter so test isolation holds.
    ffmpeg_service._seek_locks.pop(session_id, None)
    ffmpeg_service._discontinuity_seq.pop(session_id, None)


@pytest.mark.asyncio
async def test_restart_stream_wipes_segments_and_init(tmp_path):
    """Pre-existing seg files + init.mp4 from the prior spawn must be
    deleted before the new spawn writes its first segment.  Otherwise
    the HLS router serves stale bytes for the new segment numbers
    until they get overwritten."""
    from unittest.mock import patch

    from services import ffmpeg_service

    session_id = "restart-sid-2"
    session_dir = tmp_path / session_id
    session_dir.mkdir()
    # Write three stale segment files + init.mp4.
    (session_dir / "seg00000.ts").write_bytes(b"stale-0")
    (session_dir / "seg00001.ts").write_bytes(b"stale-1")
    (session_dir / "init.mp4").write_bytes(b"stale-init")
    # An unrelated file (e.g. _ff_playlist.m3u8) MUST survive.
    (session_dir / "_ff_playlist.m3u8").write_text("#EXTM3U")

    async def _fake_start(*a, **kw):
        return session_dir / "playlist.m3u8"

    with patch.object(ffmpeg_service, "start_stream", side_effect=_fake_start):
        await ffmpeg_service.restart_stream(
            "/tmp/source.mp4", session_id, tmp_path, seek_sec=10.0,
        )

    assert not (session_dir / "seg00000.ts").exists()
    assert not (session_dir / "seg00001.ts").exists()
    assert not (session_dir / "init.mp4").exists()
    # Non-segment files must be left alone.
    assert (session_dir / "_ff_playlist.m3u8").exists()
    ffmpeg_service._seek_locks.pop(session_id, None)
    ffmpeg_service._discontinuity_seq.pop(session_id, None)


@pytest.mark.asyncio
async def test_restart_stream_bumps_discontinuity_sequence(tmp_path):
    """Each restart bumps the per-session discontinuity counter so the
    rewritten playlist's ``#EXT-X-DISCONTINUITY-SEQUENCE`` value
    increases monotonically across multiple seeks (HLS spec requires
    monotonic increase)."""
    from unittest.mock import patch

    from services import ffmpeg_service

    session_id = "restart-sid-3"
    captured_seqs: list[int] = []

    async def _fake_start(file_path, sid, root, **kwargs):
        captured_seqs.append(kwargs.get("discontinuity_seq", 0))
        return tmp_path / sid / "playlist.m3u8"

    with patch.object(ffmpeg_service, "start_stream", side_effect=_fake_start):
        await ffmpeg_service.restart_stream(
            "/tmp/source.mp4", session_id, tmp_path, seek_sec=10.0,
        )
        await ffmpeg_service.restart_stream(
            "/tmp/source.mp4", session_id, tmp_path, seek_sec=20.0,
        )
        await ffmpeg_service.restart_stream(
            "/tmp/source.mp4", session_id, tmp_path, seek_sec=30.0,
        )

    assert captured_seqs == [1, 2, 3]
    ffmpeg_service._seek_locks.pop(session_id, None)
    ffmpeg_service._discontinuity_seq.pop(session_id, None)


@pytest.mark.asyncio
async def test_restart_stream_serializes_concurrent_calls(tmp_path):
    """Two concurrent ``restart_stream`` calls for the same session
    must not run their kill/wipe/spawn sequences interleaved — that
    would produce a half-restarted state where the second call's kill
    targets the first call's freshly-spawned process and the session
    ends up dead.  The asyncio Lock is what guarantees serialisation;
    this test verifies the lock is actually being held."""
    import asyncio
    from unittest.mock import patch

    from services import ffmpeg_service

    session_id = "restart-sid-4"
    inflight_count = {"value": 0, "max_seen": 0}

    async def _slow_fake_start(*a, **kw):
        inflight_count["value"] += 1
        inflight_count["max_seen"] = max(
            inflight_count["max_seen"], inflight_count["value"]
        )
        await asyncio.sleep(0.05)
        inflight_count["value"] -= 1
        return tmp_path / session_id / "playlist.m3u8"

    with patch.object(ffmpeg_service, "start_stream", side_effect=_slow_fake_start):
        await asyncio.gather(
            ffmpeg_service.restart_stream(
                "/tmp/source.mp4", session_id, tmp_path, seek_sec=5.0,
            ),
            ffmpeg_service.restart_stream(
                "/tmp/source.mp4", session_id, tmp_path, seek_sec=10.0,
            ),
        )

    # If the lock works, max concurrent restart_stream invocations is 1.
    # Without the lock both would run in parallel and max_seen would be 2.
    assert inflight_count["max_seen"] == 1
    ffmpeg_service._seek_locks.pop(session_id, None)
    ffmpeg_service._discontinuity_seq.pop(session_id, None)


@pytest.mark.asyncio
async def test_stop_stream_cleans_up_seek_lock_and_counter(tmp_path):
    """``stop_stream`` must remove the per-session lock + discontinuity
    counter so they don't accumulate forever in a long-running server
    where many sessions come and go."""
    from services import ffmpeg_service

    session_id = "stop-cleanup-sid"
    # Pre-populate as if a seek had occurred during this session.
    ffmpeg_service._seek_locks[session_id] = __import__("asyncio").Lock()
    ffmpeg_service._discontinuity_seq[session_id] = 4

    await ffmpeg_service.stop_stream(session_id)

    assert session_id not in ffmpeg_service._seek_locks
    assert session_id not in ffmpeg_service._discontinuity_seq


# ── POST /api/v1/stream/{session_id}/seek endpoint ──────────────────────────


@pytest.mark.asyncio
async def test_seek_endpoint_calls_restart_stream(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """The happy path — owner POSTs /seek, restart_stream is invoked
    with the right file path + seek_sec, response is 204."""
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    captured = {}

    async def _mock_restart(
        file_path: str, sid: str, hls_root: Path, **kwargs
    ) -> Path:
        captured["file_path"] = file_path
        captured["session_id"] = sid
        captured["seek_sec"] = kwargs.get("seek_sec")
        captured["tonemap_hdr"] = kwargs.get("tonemap_hdr")
        return hls_root / sid / "playlist.m3u8"

    with patch(
        "routers.stream.ffmpeg_service.restart_stream", side_effect=_mock_restart
    ):
        response = await client.post(
            f"/api/v1/stream/{session_id}/seek?seek_sec=120.5",
            headers=headers,
        )

    assert response.status_code == 204
    assert captured["session_id"] == session_id
    assert captured["seek_sec"] == 120.5
    assert captured["tonemap_hdr"] is False  # default


@pytest.mark.asyncio
async def test_seek_endpoint_rejects_non_owner(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """A second client cannot seek another client's session."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    await client.post(
        "/api/v1/auth/request-pair",
        json={
            "client_id": "seek-other",
            "device_name": "Other",
            "platform": "ios",
            "app_version": "0.1.0",
        },
    )
    await client.post("/api/v1/auth/approve/seek-other")
    other_status = await client.get("/api/v1/auth/status/seek-other")
    other_token = other_status.json()["auth_token"]

    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    response = await client.post(
        f"/api/v1/stream/{session_id}/seek?seek_sec=10",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_seek_endpoint_rejects_negative_seek(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """Negative seek_sec is meaningless and must 400 — not silently
    pass through to FFmpeg, which would error in a confusing way."""
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    response = await client.post(
        f"/api/v1/stream/{session_id}/seek?seek_sec=-5", headers=headers,
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_seek_endpoint_404s_on_unknown_session(
    client: AsyncClient, monkeypatch
):
    token = await _get_token(client, monkeypatch)
    response = await client.post(
        "/api/v1/stream/no-such-session/seek?seek_sec=10",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_seek_endpoint_forwards_tonemap_flag(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """Mobile preserves tonemap state across seeks by passing the flag.
    Endpoint must forward it through to ``restart_stream`` so the
    re-spawned FFmpeg keeps the tonemap chain (or doesn't)."""
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    session_id = start.json()["session_id"]

    captured_tonemap: dict = {}

    async def _mock_restart(
        file_path: str, sid: str, hls_root: Path, **kwargs
    ) -> Path:
        captured_tonemap["value"] = kwargs.get("tonemap_hdr")
        return hls_root / sid / "playlist.m3u8"

    with patch(
        "routers.stream.ffmpeg_service.restart_stream", side_effect=_mock_restart
    ):
        response = await client.post(
            f"/api/v1/stream/{session_id}/seek?seek_sec=10&tonemap=true",
            headers=headers,
        )

    assert response.status_code == 204
    assert captured_tonemap["value"] is True


# ── start_stream dedup: kill prior active session for same (client, file) ───


@pytest.mark.asyncio
async def test_start_stream_kills_prior_session_for_same_client_and_file(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """A second `/start` for the same (client_id, file_id) while the
    first is still active must terminate the prior FFmpeg + cleanup
    its session dir + stamp ended_at on the prior row.  Without this
    the GPU/CPU usage doubles per re-spin until the prior session's
    natural lifecycle cleans it up — the symptom the user reported as
    'each stream gpu and cpu going crazy'."""
    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    spawned: list[str] = []

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        spawned.append(session_id)
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    stop_calls: list[str] = []

    async def _mock_stop(session_id: str) -> None:
        stop_calls.append(session_id)

    cleanup_calls: list[str] = []

    def _mock_cleanup(session_id: str, hls_root: Path) -> None:
        cleanup_calls.append(session_id)

    with (
        patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start),
        patch("routers.stream.ffmpeg_service.stop_stream", side_effect=_mock_stop),
        patch("routers.stream.ffmpeg_service.cleanup_session_dir",
              side_effect=_mock_cleanup),
    ):
        first = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
        first_sid = first.json()["session_id"]
        # Second /start while the first is still active — same (client, file).
        second = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
        second_sid = second.json()["session_id"]

    # Both starts succeeded; the second was given a fresh session id.
    assert first.status_code == 201
    assert second.status_code == 201
    assert first_sid != second_sid

    # The prior FFmpeg was killed + its dir cleaned up exactly once.
    assert stop_calls == [first_sid]
    assert cleanup_calls == [first_sid]

    # The first session row is now marked ended.
    async with test_db.execute(
        "SELECT id, ended_at FROM stream_sessions WHERE id = ?", (first_sid,),
    ) as cur:
        row = await cur.fetchone()
    assert row is not None
    assert row["ended_at"] is not None


@pytest.mark.asyncio
async def test_start_stream_does_not_kill_other_clients_sessions(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """The dedup is keyed on `(client_id, file_id)` — a different
    client streaming the same file must NOT be terminated when the
    first client starts.  Otherwise two paired devices in the same
    household couldn't watch the same movie at once."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)

    # Pair a second client — its sessions must survive the first's restart.
    await client.post(
        "/api/v1/auth/request-pair",
        json={
            "client_id": "second-tv",
            "device_name": "Living Room TV",
            "platform": "android",
            "app_version": "0.1.0",
        },
    )
    await client.post("/api/v1/auth/approve/second-tv")
    other_status = await client.get("/api/v1/auth/status/second-tv")
    other_token = other_status.json()["auth_token"]

    token_main = await _get_token(client, monkeypatch)
    headers_main = {"Authorization": f"Bearer {token_main}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    stop_calls: list[str] = []

    async def _mock_stop(session_id: str) -> None:
        stop_calls.append(session_id)

    with (
        patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start),
        patch("routers.stream.ffmpeg_service.stop_stream", side_effect=_mock_stop),
        patch("routers.stream.ffmpeg_service.cleanup_session_dir"),
    ):
        # Second client starts streaming the file first.
        await client.post(
            f"/api/v1/stream/start/{file_id}",
            headers={"Authorization": f"Bearer {other_token}"},
        )
        # First client now starts the same file — must NOT touch the
        # second client's session.
        await client.post(f"/api/v1/stream/start/{file_id}", headers=headers_main)

    assert stop_calls == []  # nothing was torn down


# ── start_stream failure path cleanup ───────────────────────────────────────


@pytest.mark.asyncio
async def test_ffmpeg_start_stream_cleans_session_dir_on_failure(tmp_path):
    """When ffmpeg_service.start_stream raises, the partial session
    directory must be removed — without this, on a long-running server
    with a buggy source file (or a temporarily-broken encoder) the
    HLS tmp tree fills with empty `seg00000.ts` artifacts of every
    failed attempt."""
    from unittest.mock import AsyncMock, MagicMock, patch

    from services import ffmpeg_service

    session_id = "fail-cleanup-sid"
    hls_root = tmp_path
    session_dir = hls_root / session_id
    # Pre-create the dir + a partial segment so we can verify removal.
    session_dir.mkdir()
    (session_dir / "seg00000.ts").write_bytes(b"partial")

    # Force `_spawn_ffmpeg_attempt` to fail so start_stream raises.
    async def _spawn_fail(*a, **kw):
        return False, "boom: simulated", 99, False

    fake_settings = MagicMock()
    fake_settings.get = MagicMock(return_value=None)

    async def _fake_get_settings(_db):
        return {"transcoding_encoder": "libx264", "transcoding_preset": "veryfast"}

    fake_db = MagicMock()
    fake_db.execute = MagicMock(return_value=_AsyncCM(_FakeCur([])))

    async def _fake_get_db():
        return fake_db

    with (
        patch.object(ffmpeg_service, "_spawn_ffmpeg_attempt", side_effect=_spawn_fail),
        patch.object(
            ffmpeg_service,
            "_resolve_source_metadata",
            new=AsyncMock(return_value=("h264", None)),
        ),
        patch("services.settings_service.get_settings",
              side_effect=_fake_get_settings),
        patch("database.db.get_db", side_effect=_fake_get_db),
    ):
        with pytest.raises(RuntimeError):
            await ffmpeg_service.start_stream(
                "/tmp/source.mp4", session_id, hls_root,
            )

    # Failure path must have removed the partial session dir.
    assert not session_dir.exists()


class _AsyncCM:
    """Minimal async context manager wrapping a DB cursor stub for the
    `async with db.execute(...) as cur` pattern."""

    def __init__(self, cur):
        self._cur = cur

    async def __aenter__(self):
        return self._cur

    async def __aexit__(self, *a):
        return None


class _FakeCur:
    def __init__(self, rows):
        self._rows = rows

    async def fetchone(self):
        return self._rows[0] if self._rows else None

    async def fetchall(self):
        return list(self._rows)


# ── update_progress debounce ────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_update_progress_debounces_media_files_writes(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """Three progress ticks at 5 s / 10 s / 15 s should produce only
    ONE `media_files.last_progress_sec` write (the first), because the
    deltas are below the 30 s debounce threshold.  Updates to
    `stream_sessions.progress_sec` happen on every tick (transient
    live value).  This is the WAL-rate fix for the user's report of
    `fluxora.db-wal` accumulating 36+ writes/min on a single stream."""
    from routers import stream as stream_router

    # Reset the per-test in-memory dedup so prior test runs don't bleed.
    stream_router._last_persisted_progress.clear()

    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    sid = start.json()["session_id"]

    async def _read_media_progress() -> float | None:
        async with test_db.execute(
            "SELECT last_progress_sec FROM media_files WHERE id = ?", (file_id,),
        ) as cur:
            row = await cur.fetchone()
        return row["last_progress_sec"] if row else None

    # First tick — must persist (no prior baseline).
    await client.patch(
        f"/api/v1/stream/{sid}/progress",
        json={"progress_sec": 5.0},
        headers=headers,
    )
    assert await _read_media_progress() == 5.0

    # Second tick — delta = 5 s, below threshold; must NOT update media_files.
    await client.patch(
        f"/api/v1/stream/{sid}/progress",
        json={"progress_sec": 10.0},
        headers=headers,
    )
    assert await _read_media_progress() == 5.0  # unchanged

    # Third tick — delta = 5 s from last persisted, still below threshold.
    await client.patch(
        f"/api/v1/stream/{sid}/progress",
        json={"progress_sec": 15.0},
        headers=headers,
    )
    assert await _read_media_progress() == 5.0  # still unchanged

    # Tick at 35 s — delta = 30 s exactly, write goes through.
    await client.patch(
        f"/api/v1/stream/{sid}/progress",
        json={"progress_sec": 35.0},
        headers=headers,
    )
    assert await _read_media_progress() == 35.0

    # Stream_sessions.progress_sec must reflect the latest tick regardless.
    async with test_db.execute(
        "SELECT progress_sec FROM stream_sessions WHERE id = ?", (sid,),
    ) as cur:
        row = await cur.fetchone()
    assert row["progress_sec"] == 35.0


@pytest.mark.asyncio
async def test_stop_stream_flushes_final_progress_to_media_files(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """Progress debounce trades resume-marker accuracy for WAL-rate;
    `stop_stream` must close that gap by copying the live
    `stream_sessions.progress_sec` to `media_files.last_progress_sec`
    on a clean close.  Otherwise a user who watches to 14:55 of a
    15:00 movie and closes cleanly resumes at the last persisted
    debounced value (could be 14:30) instead of 14:55."""
    from routers import stream as stream_router
    stream_router._last_persisted_progress.clear()

    token = await _get_token(client, monkeypatch)
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file(test_db)

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        start = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)
    sid = start.json()["session_id"]

    # Persisted progress = 5 s; live = 12 s (debounce window means
    # the 12 s never reached media_files).
    await client.patch(
        f"/api/v1/stream/{sid}/progress",
        json={"progress_sec": 5.0},
        headers=headers,
    )
    await client.patch(
        f"/api/v1/stream/{sid}/progress",
        json={"progress_sec": 12.0},
        headers=headers,
    )
    async with test_db.execute(
        "SELECT last_progress_sec FROM media_files WHERE id = ?", (file_id,),
    ) as cur:
        row = await cur.fetchone()
    assert row["last_progress_sec"] == 5.0

    # Clean stop — must flush 12 s to media_files.
    with (
        patch("routers.stream.ffmpeg_service.stop_stream",
              new_callable=AsyncMock),
        patch("routers.stream.ffmpeg_service.cleanup_session_dir"),
    ):
        await client.delete(f"/api/v1/stream/{sid}", headers=headers)

    async with test_db.execute(
        "SELECT last_progress_sec FROM media_files WHERE id = ?", (file_id,),
    ) as cur:
        row = await cur.fetchone()
    assert row["last_progress_sec"] == 12.0

    # The in-memory dict entry must be cleared so it doesn't accumulate
    # forever on a long-running server.
    assert sid not in stream_router._last_persisted_progress


# ── Log rotation regression pin ─────────────────────────────────────────────


def test_log_config_uses_rotating_file_handler_with_10mb_cap():
    """Pin the rotating-file-handler config so a future "let's just
    use a plain FileHandler" refactor regresses immediately.  The
    user's data dir doesn't have unbounded room — 10 MB × 5 backups
    is the sweet spot of "enough history to diagnose a yesterday
    issue" without filling a small SSD."""
    from main import _LOG_CONFIG_COMMON

    fh = _LOG_CONFIG_COMMON["handlers"]["file"]
    assert fh["class"] == "logging.handlers.RotatingFileHandler"
    assert fh["maxBytes"] == 10 * 1024 * 1024
    assert fh["backupCount"] == 5
