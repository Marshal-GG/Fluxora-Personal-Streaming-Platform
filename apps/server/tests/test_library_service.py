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


# ── _clean_tmdb_query ────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "raw,cleaned",
    [
        # Field-observed cases — underscores between every token
        # broke TMDB's tokeniser; trailing year poisoned the match
        # even after underscore-cleanup.  Both fixes apply together,
        # so the cleaned query is title-only.
        (
            "Harry_Potter_and_the_Half_Blood_Prince_2009",
            "Harry Potter and the Half Blood Prince",
        ),
        (
            "Harry_Potter_and_the_Order_of_the_Phoenix_2007",
            "Harry Potter and the Order of the Phoenix",
        ),
        # Torrent-scene dot-separated names — year + quality/codec
        # tokens get stripped together so the TMDB query is just the
        # title.  Without this, "Inception 2010 1080p BluRay x264"
        # returns total_results=0 from TMDB.
        ("Inception.2010.1080p.BluRay.x264", "Inception"),
        ("Inception.2010.1080p.WEB-DL.AAC.HEVC", "Inception"),
        ("The Matrix.1999.4K.HDR.Atmos", "The Matrix"),
        # Year wrapped in parens — common in Plex naming convention.
        ("Inception (2010)", "Inception"),
        ("The Matrix [1999]", "The Matrix"),
        # Year with leading dash — also common.
        ("Inception - 2010", "Inception"),
        # Year mid-string with NORMAL text after — must be left alone.
        # The strip only fires when year-and-after runs cleanly to
        # end-of-string through known scene-noise tokens; "sequel"
        # and "notes" are normal words, so the pattern doesn't match.
        ("Blade Runner 2049 sequel notes", "Blade Runner 2049 sequel notes"),
        # Mixed separators + multi-space collapse + trim.
        ("  The   Matrix  ", "The Matrix"),
        ("Already Clean", "Already Clean"),
        ("", ""),
        # Underscore-only / dot-only stem — collapses to empty.  The
        # caller treats empty as "skip the search" so we don't emit
        # `?query=` (which would 422 the TMDB endpoint anyway).
        ("___", ""),
        ("...", ""),
    ],
)
def test_clean_tmdb_query(raw: str, cleaned: str) -> None:
    assert library_service._clean_tmdb_query(raw) == cleaned


@pytest.mark.asyncio
async def test_enrich_with_tmdb_uses_cleaned_query() -> None:
    """The TMDB call must receive the cleaned (underscore-stripped)
    string, not the raw filename stem.  Without the cleanup, common
    naming conventions (`Title_With_Underscores_2009`) silently
    return zero TMDB matches and leave the file un-enriched."""
    from unittest.mock import MagicMock

    fake_svc = MagicMock()
    fake_svc.search = AsyncMock(return_value=None)

    fake_db = MagicMock()
    fake_db.execute = AsyncMock()
    fake_db.commit = AsyncMock()

    file_stems = [
        ("file-1", "Harry_Potter_and_the_Half_Blood_Prince_2009"),
        ("file-2", "Inception.2010.1080p.BluRay"),
    ]

    with patch.object(library_service, "TmdbService", return_value=fake_svc):
        await library_service._enrich_with_tmdb(
            fake_db, file_stems, "fake-api-key",
        )

    queried = {call.args[0] for call in fake_svc.search.await_args_list}
    assert queried == {
        # Trailing year + scene-noise tokens both stripped — see
        # _TRAILING_SCENE_NOISE in library_service for the rationale;
        # field tests confirmed TMDB returns total_results=0 with the
        # year-and-quality-tokens, 1+ with just the title.
        "Harry Potter and the Half Blood Prince",
        "Inception",
    }


@pytest.mark.asyncio
async def test_enrich_with_tmdb_skips_when_cleanup_yields_empty() -> None:
    """Stems made entirely of separators clean to empty; the search
    must be skipped rather than firing `?query=` (which TMDB rejects
    with a 422 and produces a noisy log line)."""
    from unittest.mock import MagicMock

    fake_svc = MagicMock()
    fake_svc.search = AsyncMock(return_value=None)
    fake_db = MagicMock()
    fake_db.execute = AsyncMock()
    fake_db.commit = AsyncMock()

    with patch.object(library_service, "TmdbService", return_value=fake_svc):
        await library_service._enrich_with_tmdb(
            fake_db, [("file-empty", "___")], "fake-api-key",
        )

    fake_svc.search.assert_not_awaited()


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
    # were skipped before any HTTP call.  Notice ``Inception (2010)``
    # has its parenthesised year stripped by _clean_tmdb_query before
    # reaching TmdbService.search.
    assert fake_svc.search.await_count == 2
    queried_stems = {call.args[0] for call in fake_svc.search.await_args_list}
    assert queried_stems == {"Inception", "The Matrix"}


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


# ── enrich_library_tmdb ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_enrich_library_tmdb_no_api_key_returns_zeros() -> None:
    """No-op when the operator hasn't set FLUXORA_TMDB_KEY — must return
    zeros rather than crashing or making a network call."""
    from unittest.mock import MagicMock

    fake_db = MagicMock()
    result = await library_service.enrich_library_tmdb(
        fake_db, "lib-1", api_key="",
    )
    assert result == {"matched": 0, "enriched": 0, "skipped_dvr": 0}


@pytest.mark.asyncio
async def test_enrich_library_tmdb_only_targets_unenriched_files(
    test_db,
) -> None:
    """Files that already have a `tmdb_id` must be excluded from the
    rescan — otherwise running the action twice would double-charge
    against the TMDB rate limit and overwrite operator-curated
    metadata for no reason."""
    import uuid
    from unittest.mock import MagicMock

    library_id = str(uuid.uuid4())
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths)"
        " VALUES (?, ?, ?, ?)",
        (library_id, "test-lib", "movies", '["/x"]'),
    )

    # Three files: one unenriched, one already enriched, one in a
    # different library (must be ignored).
    other_lib = str(uuid.uuid4())
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths)"
        " VALUES (?, ?, ?, ?)",
        (other_lib, "other", "movies", '["/y"]'),
    )

    now = "2026-05-05T00:00:00+00:00"
    await test_db.executemany(
        "INSERT INTO media_files"
        " (id, path, name, extension, size_bytes,"
        "  library_id, tmdb_id, created_at, updated_at)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
            ("f-needs", "/x/inception.mkv", "Inception.mkv", ".mkv",
             1, library_id, None, now, now),
            ("f-done", "/x/matrix.mkv", "The Matrix.mkv", ".mkv",
             1, library_id, 603, now, now),
            ("f-other", "/y/ali.mkv", "Ali.mkv", ".mkv",
             1, other_lib, None, now, now),
        ],
    )
    await test_db.commit()

    fake_svc = MagicMock()
    fake_svc.search = AsyncMock(return_value=None)
    with patch.object(library_service, "TmdbService", return_value=fake_svc):
        result = await library_service.enrich_library_tmdb(
            test_db, library_id, api_key="dummy",
        )

    # Only the unenriched file in the target library was queried.
    assert fake_svc.search.await_count == 1
    queried_stems = {call.args[0] for call in fake_svc.search.await_args_list}
    assert queried_stems == {"Inception"}
    # The dict shape mirrors what the endpoint surfaces.
    assert result["matched"] == 1
    assert result["enriched"] == 0  # search returned None
    assert result["skipped_dvr"] == 0


@pytest.mark.asyncio
async def test_enrich_library_tmdb_skips_dvr_pattern_by_default(
    test_db,
) -> None:
    import uuid
    from unittest.mock import MagicMock

    library_id = str(uuid.uuid4())
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths)"
        " VALUES (?, ?, ?, ?)",
        (library_id, "test-lib", "movies", '["/x"]'),
    )
    now = "2026-05-05T00:00:00+00:00"
    await test_db.executemany(
        "INSERT INTO media_files"
        " (id, path, name, extension, size_bytes,"
        "  library_id, tmdb_id, created_at, updated_at)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
            ("f-real", "/x/inception.mkv", "Inception.mkv", ".mkv",
             1, library_id, None, now, now),
            ("f-dvr", "/x/cap.ts",
             "Genshin Impact 2026.04.09 - 21.16.23.02.ts", ".ts",
             1, library_id, None, now, now),
        ],
    )
    await test_db.commit()

    fake_svc = MagicMock()
    fake_svc.search = AsyncMock(return_value=None)
    with patch.object(library_service, "TmdbService", return_value=fake_svc):
        result = await library_service.enrich_library_tmdb(
            test_db, library_id, api_key="dummy",
        )

    # The DVR-style stem must NOT have been queried.
    queried_stems = {call.args[0] for call in fake_svc.search.await_args_list}
    assert queried_stems == {"Inception"}
    assert result["matched"] == 2
    assert result["skipped_dvr"] == 1


@pytest.mark.asyncio
async def test_enrich_library_tmdb_include_dvr_overrides_skip(
    test_db,
) -> None:
    """``include_dvr=True`` is the explicit opt-in for archives where
    capture-style filenames *do* contain real titles.  Must search
    every file, not just the non-DVR ones."""
    import uuid
    from unittest.mock import MagicMock

    library_id = str(uuid.uuid4())
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths)"
        " VALUES (?, ?, ?, ?)",
        (library_id, "test-lib", "movies", '["/x"]'),
    )
    now = "2026-05-05T00:00:00+00:00"
    await test_db.execute(
        "INSERT INTO media_files"
        " (id, path, name, extension, size_bytes,"
        "  library_id, tmdb_id, created_at, updated_at)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        ("f-dvr", "/x/cap.ts",
         "Some Show 2025.05.01 - 18.30.00.ts", ".ts",
         1, library_id, None, now, now),
    )
    await test_db.commit()

    fake_svc = MagicMock()
    fake_svc.search = AsyncMock(return_value=None)
    with patch.object(library_service, "TmdbService", return_value=fake_svc):
        result = await library_service.enrich_library_tmdb(
            test_db, library_id, api_key="dummy", include_dvr=True,
        )

    assert fake_svc.search.await_count == 1
    assert result["skipped_dvr"] == 0  # we opted in
