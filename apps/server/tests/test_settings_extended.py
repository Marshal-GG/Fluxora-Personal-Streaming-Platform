"""Tests for the 18 extended user_settings columns (migration 015)."""

import pytest
from httpx import AsyncClient

# ── 1. Defaults populated after migration ────────────────────────────────────


@pytest.mark.asyncio
async def test_defaults_populated_after_migration(client: AsyncClient) -> None:
    res = await client.get("/api/v1/settings")
    assert res.status_code == 200
    body = res.json()

    # Booleans
    assert body["auto_start_on_boot"] is False
    assert body["auto_restart_on_crash"] is True
    assert body["minimize_to_system_tray"] is True
    assert body["scan_libraries_on_startup"] is True
    assert body["generate_thumbnails"] is True
    assert body["enable_mdns"] is True
    assert body["enable_webrtc"] is True
    assert body["enable_pairing_required"] is True
    assert body["enable_log_export"] is True

    # Strings
    assert body["language"] == "en"
    assert body["default_library_view"] == "grid"
    assert body["preferred_mode"] == "auto"
    assert body["default_quality"] == "auto"

    # Integers
    assert body["ai_segment_duration_seconds"] == 4
    assert body["session_timeout_minutes"] == 60

    # Nullable (no default)
    assert body["theme_accent"] is None
    assert body["relay_server_url"] is None
    assert body["custom_server_url"] is None


# ── 2. Per-field PATCH round-trip ────────────────────────────────────────────


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "field, value",
    [
        # str
        ("language", "fr"),
        ("default_library_view", "list"),
        ("preferred_mode", "lan"),
        ("default_quality", "1080p"),
        # bool
        ("auto_start_on_boot", True),
        ("enable_mdns", False),
        ("generate_thumbnails", False),
        # int
        ("session_timeout_minutes", 120),
        ("ai_segment_duration_seconds", 6),
        # nullable str
        ("relay_server_url", "stun:turn.example.com:3478"),
        ("custom_server_url", "https://my.server.example.com"),
    ],
)
async def test_patch_individual_field_roundtrip(
    client: AsyncClient, field: str, value: object
) -> None:
    res = await client.patch("/api/v1/settings", json={field: value})
    assert res.status_code == 200, res.text
    assert res.json()[field] == value


# ── 3. Multi-field atomic PATCH ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_patch_multiple_fields_atomic(client: AsyncClient) -> None:
    payload = {
        "language": "de",
        "auto_restart_on_crash": False,
        "session_timeout_minutes": 30,
        "default_quality": "720p",
        "relay_server_url": "turn:relay.example.com:3478",
    }
    res = await client.patch("/api/v1/settings", json=payload)
    assert res.status_code == 200
    body = res.json()
    for field, expected in payload.items():
        assert body[field] == expected, f"Mismatch for {field!r}"

    # Unrelated field should be untouched
    assert body["default_library_view"] == "grid"


# ── 4. Invalid enum value rejected ──────────────────────────────────────────


@pytest.mark.asyncio
async def test_invalid_enum_rejected_by_pydantic(client: AsyncClient) -> None:
    res = await client.patch(
        "/api/v1/settings", json={"default_library_view": "octopus"}
    )
    assert res.status_code == 422

    res2 = await client.patch("/api/v1/settings", json={"preferred_mode": "bluetooth"})
    assert res2.status_code == 422

    res3 = await client.patch("/api/v1/settings", json={"default_quality": "8k"})
    assert res3.status_code == 422


# ── 5. session_timeout_minutes bounds ───────────────────────────────────────


@pytest.mark.asyncio
async def test_session_timeout_bounds(client: AsyncClient) -> None:
    # Below minimum
    res = await client.patch("/api/v1/settings", json={"session_timeout_minutes": 0})
    assert res.status_code == 422

    # Above maximum (> 1440 minutes = 24 h)
    res = await client.patch("/api/v1/settings", json={"session_timeout_minutes": 2000})
    assert res.status_code == 422

    # Valid value
    res = await client.patch("/api/v1/settings", json={"session_timeout_minutes": 60})
    assert res.status_code == 200
    assert res.json()["session_timeout_minutes"] == 60


# ── 6. Existing fields still work (regression) ───────────────────────────────


@pytest.mark.asyncio
async def test_existing_fields_still_work(client: AsyncClient) -> None:
    res = await client.patch(
        "/api/v1/settings",
        json={"server_name": "Refactored Box", "transcoding_crf": 28},
    )
    assert res.status_code == 200
    body = res.json()
    assert body["server_name"] == "Refactored Box"
    assert body["transcoding_crf"] == 28
    # Extended fields must still be present with their defaults
    assert body["language"] == "en"
    assert body["session_timeout_minutes"] == 60


# ── transcoding_chain (Slice C) ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_transcoding_chain_round_trips_as_list(client: AsyncClient):
    res = await client.patch(
        "/api/v1/settings",
        json={"transcoding_chain": ["h264_nvenc", "h264_qsv", "libx264"]},
    )
    assert res.status_code == 200
    body = res.json()
    assert body["transcoding_chain"] == [
        "h264_nvenc",
        "h264_qsv",
        "libx264",
    ]


@pytest.mark.asyncio
async def test_transcoding_chain_rejects_unknown_encoder(client: AsyncClient):
    res = await client.patch(
        "/api/v1/settings",
        json={"transcoding_chain": ["h264_nvenc", "made_up_encoder"]},
    )
    assert res.status_code == 422
    detail = res.json()["detail"]
    # detail can be a Pydantic-list or our wrapped service ValueError str.
    assert "made_up_encoder" in str(detail)


@pytest.mark.asyncio
async def test_transcoding_chain_rejects_all_duplicates(client: AsyncClient):
    """A chain like [libx264, libx264] is meaningless — surface as 422."""
    res = await client.patch(
        "/api/v1/settings",
        json={"transcoding_chain": ["libx264", "libx264"]},
    )
    assert res.status_code == 422
    assert "distinct" in str(res.json()["detail"])


# ── Plan 19 §M2 — transcode storage settings ──────────────────────────────


@pytest.mark.asyncio
async def test_transcode_storage_mode_default_is_dedicated(client: AsyncClient):
    res = await client.get("/api/v1/settings")
    assert res.status_code == 200
    assert res.json()["transcode_storage_mode"] == "dedicated"
    assert res.json()["transcode_cache_root"] is None


@pytest.mark.asyncio
async def test_transcode_storage_mode_round_trips(client: AsyncClient):
    res = await client.patch(
        "/api/v1/settings", json={"transcode_storage_mode": "inline"}
    )
    assert res.status_code == 200
    assert res.json()["transcode_storage_mode"] == "inline"


@pytest.mark.asyncio
async def test_transcode_storage_mode_rejects_unknown_literal(client: AsyncClient):
    res = await client.patch(
        "/api/v1/settings", json={"transcode_storage_mode": "loose"}
    )
    assert res.status_code == 422


@pytest.mark.asyncio
async def test_transcode_cache_root_rejects_relative_path(client: AsyncClient):
    res = await client.patch(
        "/api/v1/settings", json={"transcode_cache_root": "relative/cache"}
    )
    assert res.status_code == 422
    assert "absolute" in str(res.json()["detail"]).lower()


@pytest.mark.asyncio
async def test_transcode_cache_root_accepts_writable_absolute_path(
    client: AsyncClient, tmp_path
):
    res = await client.patch(
        "/api/v1/settings", json={"transcode_cache_root": str(tmp_path / "cache")}
    )
    assert res.status_code == 200
    assert res.json()["transcode_cache_root"] == str(tmp_path / "cache")


@pytest.mark.asyncio
async def test_transcode_cache_root_rejects_path_inside_library(
    client: AsyncClient, tmp_path
):
    """A cache root inside a library root would loop on rescan — every
    produced sidecar would be re-discovered and fail to match the
    candidate codec list."""
    lib_root = tmp_path / "lib"
    lib_root.mkdir()
    create_resp = await client.post(
        "/api/v1/library",
        json={"name": "L", "type": "movies", "root_paths": [str(lib_root)]},
    )
    assert create_resp.status_code == 201

    res = await client.patch(
        "/api/v1/settings",
        json={"transcode_cache_root": str(lib_root / "cache")},
    )
    assert res.status_code == 422
    assert "library" in str(res.json()["detail"]).lower()


@pytest.mark.asyncio
async def test_transcoding_chain_empty_list_clears(client: AsyncClient):
    """An empty list means 'use the default chain' — stored as null in DB,
    surfaced as null in the response."""
    # First populate it.
    await client.patch(
        "/api/v1/settings",
        json={"transcoding_chain": ["h264_nvenc", "libx264"]},
    )
    # Now clear it.
    res = await client.patch(
        "/api/v1/settings",
        json={"transcoding_chain": []},
    )
    assert res.status_code == 200
    assert res.json()["transcoding_chain"] is None
