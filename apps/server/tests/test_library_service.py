"""Tests for library_service additions (path validator, duration backfill).

These cover the unit-level helpers that protect against the corrupt-path
class of bugs and the NULL-duration_sec class of bugs that left the
mobile seek bar growing segment-by-segment.
"""

from io import BytesIO
from unittest.mock import AsyncMock, patch

import pytest
from fastapi import UploadFile

from services import library_service


# ── _is_valid_absolute_media_path ──────────────────────────────────────────────


@pytest.mark.parametrize(
    "path,expected",
    [
        # Valid Windows drive paths
        ("C:\\Users\\me\\video.mkv", True),
        ("D:\\media\\movie.mp4", True),
        ("D:/media/movie.mp4", True),  # forward-slash drive form
        # Valid POSIX paths
        ("/media/library/movie.mkv", True),
        ("/home/user/v.mp4", True),
        # Invalid — the corruption signature from 2026-04
        ("[\\Avicii.mkv", False),
        ("[/Avicii.mkv", False),
        # Invalid — relative
        ("Avicii.mkv", False),
        ("subdir/file.mp4", False),
        # Invalid — empty / whitespace
        ("", False),
        ("   ", False),
        # Invalid — null byte
        ("/media/file\x00.mkv", False),
    ],
)
def test_is_valid_absolute_media_path(path: str, expected: bool) -> None:
    assert library_service._is_valid_absolute_media_path(path) is expected


# ── upload_file_to_library guards ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_upload_rejects_root_paths_as_string() -> None:
    """If root_paths is somehow returned as a JSON string instead of a
    parsed list, the upload helper must refuse rather than constructing
    a `[\\filename` path."""
    # Simulate the buggy 2026-04 code path — get_library yields
    # root_paths as a JSON-encoded *string* instead of a list.
    fake_get_library = AsyncMock(
        return_value={
            "id": "lib-1",
            "name": "test",
            "root_paths": '["D:\\\\media"]',  # JSON STRING, not parsed list
        }
    )
    db = AsyncMock()
    upload = UploadFile(filename="movie.mkv", file=BytesIO(b"\x00"))

    with patch.object(library_service, "get_library", fake_get_library):
        with pytest.raises(ValueError, match="malformed"):
            await library_service.upload_file_to_library(db, "lib-1", upload)


@pytest.mark.asyncio
async def test_upload_rejects_relative_root_path() -> None:
    fake_get_library = AsyncMock(
        return_value={
            "id": "lib-1",
            "name": "test",
            "root_paths": ["relative/dir"],  # not absolute
        }
    )
    db = AsyncMock()
    upload = UploadFile(filename="movie.mkv", file=BytesIO(b"\x00"))

    with patch.object(library_service, "get_library", fake_get_library):
        with pytest.raises(ValueError, match="not absolute"):
            await library_service.upload_file_to_library(db, "lib-1", upload)


# ── backfill_missing_durations ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_backfill_persists_duration(test_db, tmp_path) -> None:
    """The startup backfill must call _persist_probe on rows with NULL
    duration_sec on probeable extensions, and must stop iterating when
    no more NULL rows remain."""
    # Insert two probeable-extension rows (duration_sec NULL) and one
    # non-probeable row that the SQL filter must skip.
    fake_video = tmp_path / "movie.mkv"
    fake_video.write_bytes(b"\x00" * 16)  # not actually playable; we mock probe
    fake_audio = tmp_path / "music.mp3"
    fake_audio.write_bytes(b"\x00" * 16)

    await test_db.execute(
        "INSERT INTO media_files"
        " (id, path, name, extension, size_bytes, created_at, updated_at)"
        " VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))",
        ("vid-1", str(fake_video), "movie.mkv", ".mkv", 16),
    )
    await test_db.execute(
        "INSERT INTO media_files"
        " (id, path, name, extension, size_bytes, created_at, updated_at)"
        " VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))",
        ("aud-1", str(fake_audio), "music.mp3", ".mp3", 16),
    )
    await test_db.commit()

    fake_probe = AsyncMock(
        return_value={
            "width": 1920,
            "height": 1080,
            "codec_name": "hevc",
            "hdr_format": None,
            "duration_sec": 142.5,
        }
    )

    with patch.object(library_service, "probe_video", fake_probe):
        updated = await library_service.backfill_missing_durations(test_db)

    # Only the .mkv row is probeable; .mp3 is filtered out by the SQL.
    assert updated == 1
    fake_probe.assert_awaited_once()

    async with test_db.execute(
        "SELECT duration_sec FROM media_files WHERE id = 'vid-1'"
    ) as cur:
        row = await cur.fetchone()
    assert row["duration_sec"] == pytest.approx(142.5)

    async with test_db.execute(
        "SELECT duration_sec FROM media_files WHERE id = 'aud-1'"
    ) as cur:
        row = await cur.fetchone()
    assert row["duration_sec"] is None  # untouched


@pytest.mark.asyncio
async def test_backfill_keyset_pagination_does_not_loop(
    test_db, tmp_path
) -> None:
    """If a probe call fails to populate duration_sec (e.g. ffprobe
    silently returned no format.duration), the keyset pagination must
    skip past that id rather than re-fetching it forever."""
    fake_video = tmp_path / "movie.mkv"
    fake_video.write_bytes(b"\x00" * 16)

    await test_db.execute(
        "INSERT INTO media_files"
        " (id, path, name, extension, size_bytes, created_at, updated_at)"
        " VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))",
        ("vid-stuck", str(fake_video), "movie.mkv", ".mkv", 16),
    )
    await test_db.commit()

    # Probe succeeds but returns no duration — _persist_probe leaves
    # duration_sec NULL via COALESCE.  Backfill must still terminate.
    fake_probe = AsyncMock(
        return_value={
            "width": 1920,
            "height": 1080,
            "codec_name": "hevc",
            "hdr_format": None,
            "duration_sec": None,
        }
    )

    with patch.object(library_service, "probe_video", fake_probe):
        updated = await library_service.backfill_missing_durations(test_db)

    # _persist_probe was called once, returned without a duration, then
    # the loop's keyset pagination skipped past `vid-stuck` and exited.
    assert updated == 1
    assert fake_probe.await_count == 1
