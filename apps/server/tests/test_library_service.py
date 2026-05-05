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


# ── DVR-capture filename heuristic (TMDB lookup skip) ─────────────────────────


@pytest.mark.parametrize(
    "stem,expected",
    [
        # Field-observed DVR / capture-card patterns (the user's actual
        # filenames as of 2026-05-05).  Date dot-separated.
        ("Genshin Impact 2026.04.09 - 21.16.23.02", True),
        ("Genshin Impact 2025.02.17 - 23.43.09.03.DVR", True),
        # Date dash-separated — common in Plex naming guides.
        ("Some Capture 2024-08-15 18.30.00", True),
        # Real movie titles — must NOT match.
        ("Inception (2010)", False),
        ("The Matrix", False),
        ("Avengers Endgame 2019", False),  # year alone, no date, fine
        # Edge cases — short strings, unusual chars, etc.
        ("", False),
        ("Show.S01E02.1080p", False),  # season/episode markers, not dates
    ],
)
def test_looks_like_dvr_capture(stem: str, expected: bool) -> None:
    assert library_service._looks_like_dvr_capture(stem) is expected


@pytest.mark.asyncio
async def test_enrich_with_tmdb_skips_dvr_pattern_filenames() -> None:
    """Files whose stems match the DVR pattern must NOT trigger a TMDB
    HTTP call — without this guard, scanning a capture archive
    produces an HTTP request per file, all returning no match, and a
    pile of '0/N files updated' log lines."""
    from unittest.mock import MagicMock

    # Mock out TmdbService so we can verify .search() is NOT called for
    # the DVR-style stems.  Ordinary stems still hit it.
    fake_svc = MagicMock()
    fake_svc.search = AsyncMock(return_value=None)

    fake_db = MagicMock()
    fake_db.execute = AsyncMock()
    fake_db.commit = AsyncMock()

    file_stems = [
        ("file-1", "Inception (2010)"),
        ("file-2", "Genshin Impact 2026.04.09 - 21.16.23.02"),
        ("file-3", "The Matrix"),
        ("file-4", "Some Capture 2024-08-15 18.30.00"),
    ]

    with patch.object(
        library_service, "TmdbService", return_value=fake_svc,
    ):
        await library_service._enrich_with_tmdb(
            fake_db, file_stems, "fake-api-key",
        )

    # Only the 2 non-DVR stems were queried.  The 2 DVR-style ones
    # were skipped before any HTTP call.
    assert fake_svc.search.await_count == 2
    queried_stems = {call.args[0] for call in fake_svc.search.await_args_list}
    assert queried_stems == {"Inception (2010)", "The Matrix"}


# ── Per-library scan lock ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_scan_library_serialises_concurrent_calls(test_db) -> None:
    """Two `scan_library` calls in flight for the same library must
    not run their directory walks + INSERTs + TMDB enrichment
    concurrently — that's what produced the duplicate `Scan complete`
    log lines + duplicate TMDB enrichment storms in the field."""
    import asyncio
    import uuid

    # Set up a library that points at a non-existent path so the inner
    # walk is fast (no real filesystem traversal).  The lock behaviour
    # is independent of what scan does inside.
    library_id = str(uuid.uuid4())
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths)"
        " VALUES (?, ?, ?, ?)",
        (
            library_id,
            "test-library",
            "movies",
            '["/nonexistent/path/that/will/skip"]',
        ),
    )
    await test_db.commit()

    # Force the inner _scan_library_locked to take measurable wall-time
    # so we can detect overlap.
    inflight = {"value": 0, "max_seen": 0}
    real_locked = library_service._scan_library_locked

    async def _slow_scan(db, lib_id, key):
        inflight["value"] += 1
        inflight["max_seen"] = max(inflight["max_seen"], inflight["value"])
        await asyncio.sleep(0.05)
        result = await real_locked(db, lib_id, key)
        inflight["value"] -= 1
        return result

    with patch.object(library_service, "_scan_library_locked", side_effect=_slow_scan):
        await asyncio.gather(
            library_service.scan_library(test_db, library_id),
            library_service.scan_library(test_db, library_id),
            library_service.scan_library(test_db, library_id),
        )

    # If the lock works, max concurrent _scan_library_locked invocations
    # is exactly 1.  Without the lock max_seen would be 3.
    assert inflight["max_seen"] == 1
    library_service._scan_locks.pop(library_id, None)


@pytest.mark.asyncio
async def test_scan_library_lock_does_not_block_different_libraries(test_db) -> None:
    """The lock is per-library; two scans on DIFFERENT libraries must
    run concurrently.  Otherwise the user would see Library B's scan
    stall behind Library A's slow recursive walk for no reason."""
    import asyncio
    import uuid

    lib_a = str(uuid.uuid4())
    lib_b = str(uuid.uuid4())
    for lid in (lib_a, lib_b):
        await test_db.execute(
            "INSERT INTO libraries (id, name, type, root_paths)"
            " VALUES (?, ?, ?, ?)",
            (lid, f"lib-{lid[:4]}", "movies", '["/nonexistent"]'),
        )
    await test_db.commit()

    inflight = {"value": 0, "max_seen": 0}
    real_locked = library_service._scan_library_locked

    async def _slow_scan(db, lib_id, key):
        inflight["value"] += 1
        inflight["max_seen"] = max(inflight["max_seen"], inflight["value"])
        await asyncio.sleep(0.05)
        result = await real_locked(db, lib_id, key)
        inflight["value"] -= 1
        return result

    with patch.object(library_service, "_scan_library_locked", side_effect=_slow_scan):
        await asyncio.gather(
            library_service.scan_library(test_db, lib_a),
            library_service.scan_library(test_db, lib_b),
        )

    # Different libraries → both can run at once.  max_seen = 2.
    assert inflight["max_seen"] == 2
    library_service._scan_locks.pop(lib_a, None)
    library_service._scan_locks.pop(lib_b, None)
