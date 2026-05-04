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
