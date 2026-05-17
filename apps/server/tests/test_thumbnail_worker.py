"""Unit tests for ``services/thumbnail_worker.py``.

Covers the public surface used by the scan path + files router + lifespan
(``enqueue`` / ``boost_library`` / ``regenerate_library`` / ``_claim_one``)
and the failure-notification aggregation.  The extraction step itself is
covered by ``test_thumbnail_service.py``; here we mock the extractor so
we can exercise state transitions deterministically.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from services import thumbnail_worker
from services.thumbnail_service import ThumbnailResult

# ── helpers ────────────────────────────────────────────────────────────────


async def _insert_library(test_db, *, name: str = "lib") -> str:
    lib_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO libraries
            (id, name, type, root_paths, created_at)
        VALUES (?, ?, 'movies', '[]', ?)
        """,
        (lib_id, name, now),
    )
    await test_db.commit()
    return lib_id


async def _insert_file(
    test_db,
    *,
    library_id: str | None = None,
    extension: str = ".mp4",
    duration_sec: float | None = 100.0,
    hdr_format: str | None = None,
) -> str:
    """Insert a media_files row + auto-enqueue a thumbnail.

    Production parity: ``library_service.scan_library`` calls
    ``thumbnail_worker.enqueue`` after each INSERT into media_files,
    so the migration's existing-rows backfill plus the scan-path hook
    guarantee every file has a thumb row.  Tests that need a thumb row
    to exist (every test claiming or processing) rely on this fixture
    doing the enqueue for them.
    """
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, duration_sec,
             library_id, hdr_format, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            file_id,
            f"/tmp/{file_id}{extension}",
            f"{file_id}{extension}",
            extension,
            1000,
            duration_sec,
            library_id,
            hdr_format,
            now,
            now,
        ),
    )
    await thumbnail_worker.enqueue(test_db, file_id)
    await test_db.commit()
    return file_id


async def _fetch_thumb(test_db, file_id: str) -> dict | None:
    async with test_db.execute(
        "SELECT * FROM media_thumbnails WHERE file_id = ?", (file_id,)
    ) as cur:
        row = await cur.fetchone()
    return dict(row) if row else None


# ── enqueue ────────────────────────────────────────────────────────────────


async def test_enqueue_creates_pending_row(test_db):
    fid = await _insert_file(test_db)
    # Migration 037's backfill seeds existing files as pending — so the
    # row should already exist.  This test exercises the explicit
    # enqueue call shape regardless.
    await thumbnail_worker.enqueue(test_db, fid)
    await test_db.commit()
    row = await _fetch_thumb(test_db, fid)
    assert row is not None
    assert row["status"] == "pending"


async def test_enqueue_is_idempotent(test_db):
    fid = await _insert_file(test_db)
    await thumbnail_worker.enqueue(test_db, fid)
    await thumbnail_worker.enqueue(test_db, fid)
    await thumbnail_worker.enqueue(test_db, fid)
    await test_db.commit()
    async with test_db.execute(
        "SELECT COUNT(*) AS n FROM media_thumbnails WHERE file_id = ?",
        (fid,),
    ) as cur:
        row = await cur.fetchone()
    assert row["n"] == 1


# ── boost_library ──────────────────────────────────────────────────────────


async def test_boost_library_bumps_priority(test_db):
    lib_id = await _insert_library(test_db)
    fids = [await _insert_file(test_db, library_id=lib_id) for _ in range(3)]
    # Migration backfill already enqueued these; defensive enqueue too.
    for fid in fids:
        await thumbnail_worker.enqueue(test_db, fid)
    await test_db.commit()

    boosted = await thumbnail_worker.boost_library(test_db, lib_id)
    assert boosted == 3
    for fid in fids:
        row = await _fetch_thumb(test_db, fid)
        assert row["priority"] == 10


async def test_boost_library_idempotent(test_db):
    """Re-boosting rows that are already at priority=10 is a no-op."""
    lib_id = await _insert_library(test_db)
    fid = await _insert_file(test_db, library_id=lib_id)
    await thumbnail_worker.enqueue(test_db, fid)

    first = await thumbnail_worker.boost_library(test_db, lib_id)
    second = await thumbnail_worker.boost_library(test_db, lib_id)
    assert first == 1
    assert second == 0  # already boosted


async def test_boost_library_only_pending_rows(test_db):
    """Rows in 'ready' / 'failed' / 'skipped' states aren't bumped."""
    lib_id = await _insert_library(test_db)
    fid = await _insert_file(test_db, library_id=lib_id)
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        "UPDATE media_thumbnails SET status='ready', updated_at=? WHERE file_id=?",
        (now, fid),
    )
    await test_db.commit()

    boosted = await thumbnail_worker.boost_library(test_db, lib_id)
    assert boosted == 0
    row = await _fetch_thumb(test_db, fid)
    assert row["priority"] == 0  # unchanged


# ── _claim_one ─────────────────────────────────────────────────────────────


async def test_claim_picks_highest_priority_first(test_db):
    """When two rows are pending, the boosted one is claimed first."""
    lib_a = await _insert_library(test_db, name="A")
    lib_b = await _insert_library(test_db, name="B")
    # Create A's file first (older created_at) but boost B.
    await _insert_file(test_db, library_id=lib_a)
    # ensure created_at diverges
    import asyncio

    await asyncio.sleep(0.01)
    fid_b = await _insert_file(test_db, library_id=lib_b)
    await thumbnail_worker.boost_library(test_db, lib_b)
    await test_db.commit()

    claim = await thumbnail_worker._claim_one(test_db)
    assert claim is not None
    # Boosted B should win even though A is older.
    assert claim["file_id"] == fid_b
    assert claim["library_id"] == lib_b


async def test_claim_atomicity(test_db):
    """Two concurrent claims on the same row only succeed for one caller."""
    fid = await _insert_file(test_db)
    await thumbnail_worker.enqueue(test_db, fid)
    await test_db.commit()

    # Run two claims back-to-back; second should return None because
    # the first flipped the row to status='generating'.
    first = await thumbnail_worker._claim_one(test_db)
    second = await thumbnail_worker._claim_one(test_db)
    assert first is not None
    assert first["file_id"] == fid
    assert second is None


async def test_claim_skips_rows_at_max_attempts(test_db):
    fid = await _insert_file(test_db)
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        UPDATE media_thumbnails
           SET status='pending', attempts=?, updated_at=?
         WHERE file_id=?
        """,
        (thumbnail_worker.MAX_ATTEMPTS, now, fid),
    )
    await test_db.commit()

    claim = await thumbnail_worker._claim_one(test_db)
    assert claim is None


async def test_claim_handles_vanished_media_row(test_db):
    """If media_files row is deleted between INSERT into thumbnails and
    claim, the claim marks the thumbnail row as failed.  Shouldn't happen
    in practice (ON DELETE CASCADE) but tests the defensive branch."""
    # Manually insert a thumb row pointing to a non-existent file (bypass
    # FK by inserting the media_files row, then deleting after).
    fid = await _insert_file(test_db)
    await thumbnail_worker.enqueue(test_db, fid)
    await test_db.execute("DELETE FROM media_files WHERE id = ?", (fid,))
    await test_db.commit()

    # Cascade should have deleted the thumb row too, so claim returns None.
    claim = await thumbnail_worker._claim_one(test_db)
    assert claim is None


# ── _process_one (with mocked extractor) ───────────────────────────────────


async def test_process_marks_ready_on_success(test_db, monkeypatch, tmp_path):
    fid = await _insert_file(test_db, extension=".mp4")

    async def fake_extract(*_args, **_kwargs):
        return ThumbnailResult(success=True)

    monkeypatch.setattr("services.thumbnail_service.extract_thumbnail", fake_extract)
    monkeypatch.setattr(thumbnail_worker, "_THUMBNAILS_DIR", tmp_path)

    claim = {
        "file_id": fid,
        "attempts": 0,
        "path": "/tmp/fake.mp4",
        "extension": ".mp4",
        "duration_sec": 100.0,
        "hdr_format": None,
        "library_id": None,
    }
    await thumbnail_worker._process_one(test_db, claim)

    row = await _fetch_thumb(test_db, fid)
    assert row["status"] == "ready"
    assert row["generated_at"] is not None
    assert row["attempts"] == 1


async def test_process_marks_skipped_on_skip(test_db, monkeypatch, tmp_path):
    fid = await _insert_file(test_db, extension=".mp3")

    async def fake_extract(*_args, **_kwargs):
        return ThumbnailResult(
            success=False, skipped=True, error="no embedded album art"
        )

    monkeypatch.setattr("services.thumbnail_service.extract_thumbnail", fake_extract)
    monkeypatch.setattr(thumbnail_worker, "_THUMBNAILS_DIR", tmp_path)

    claim = {
        "file_id": fid,
        "attempts": 0,
        "path": "/tmp/fake.mp3",
        "extension": ".mp3",
        "duration_sec": None,
        "hdr_format": None,
        "library_id": None,
    }
    await thumbnail_worker._process_one(test_db, claim)

    row = await _fetch_thumb(test_db, fid)
    assert row["status"] == "skipped"
    assert "embedded album art" in row["error_message"]


async def test_process_marks_failed_and_increments_attempts(
    test_db, monkeypatch, tmp_path
):
    fid = await _insert_file(test_db)

    async def fake_extract(*_args, **_kwargs):
        return ThumbnailResult(success=False, error="ffmpeg exit=1")

    monkeypatch.setattr("services.thumbnail_service.extract_thumbnail", fake_extract)
    monkeypatch.setattr(thumbnail_worker, "_THUMBNAILS_DIR", tmp_path)

    claim = {
        "file_id": fid,
        "attempts": 1,  # second attempt
        "path": "/tmp/fake.mp4",
        "extension": ".mp4",
        "duration_sec": 100.0,
        "hdr_format": None,
        "library_id": None,
    }
    await thumbnail_worker._process_one(test_db, claim)

    row = await _fetch_thumb(test_db, fid)
    assert row["status"] == "failed"
    assert row["attempts"] == 2
    assert "ffmpeg exit=1" in row["error_message"]


async def test_process_unknown_extension_is_skipped(test_db, tmp_path, monkeypatch):
    fid = await _insert_file(test_db, extension=".txt")
    monkeypatch.setattr(thumbnail_worker, "_THUMBNAILS_DIR", tmp_path)
    claim = {
        "file_id": fid,
        "attempts": 0,
        "path": "/tmp/fake.txt",
        "extension": ".txt",
        "duration_sec": None,
        "hdr_format": None,
        "library_id": None,
    }
    await thumbnail_worker._process_one(test_db, claim)

    row = await _fetch_thumb(test_db, fid)
    assert row["status"] == "skipped"
    assert "not supported" in row["error_message"]


# ── Failure notification aggregation ───────────────────────────────────────


async def test_failure_notification_fires_at_threshold(test_db, monkeypatch, tmp_path):
    lib_id = await _insert_library(test_db)

    async def fake_extract(*_args, **_kwargs):
        return ThumbnailResult(success=False, error="broken")

    monkeypatch.setattr("services.thumbnail_service.extract_thumbnail", fake_extract)
    monkeypatch.setattr(thumbnail_worker, "_THUMBNAILS_DIR", tmp_path)

    threshold = thumbnail_worker.FAILURE_NOTIFICATION_THRESHOLD
    fids = [await _insert_file(test_db, library_id=lib_id) for _ in range(threshold)]

    # Push each file to max attempts so it lands at 'failed' permanently
    for fid in fids:
        claim = {
            "file_id": fid,
            "attempts": thumbnail_worker.MAX_ATTEMPTS - 1,
            "path": "/tmp/fake.mp4",
            "extension": ".mp4",
            "duration_sec": 100.0,
            "hdr_format": None,
            "library_id": lib_id,
        }
        await thumbnail_worker._process_one(test_db, claim)

    async with test_db.execute(
        "SELECT COUNT(*) AS n FROM notifications "
        "WHERE category='thumbnail' AND related_id=?",
        (lib_id,),
    ) as cur:
        row = await cur.fetchone()
    assert row["n"] == 1  # one summary, not N per-file


async def test_failure_notification_dedup_on_open(test_db, monkeypatch, tmp_path):
    lib_id = await _insert_library(test_db)

    async def fake_extract(*_args, **_kwargs):
        return ThumbnailResult(success=False, error="broken")

    monkeypatch.setattr("services.thumbnail_service.extract_thumbnail", fake_extract)
    monkeypatch.setattr(thumbnail_worker, "_THUMBNAILS_DIR", tmp_path)

    threshold = thumbnail_worker.FAILURE_NOTIFICATION_THRESHOLD
    fids = [
        await _insert_file(test_db, library_id=lib_id) for _ in range(threshold * 2)
    ]

    for fid in fids:
        claim = {
            "file_id": fid,
            "attempts": thumbnail_worker.MAX_ATTEMPTS - 1,
            "path": "/tmp/fake.mp4",
            "extension": ".mp4",
            "duration_sec": 100.0,
            "hdr_format": None,
            "library_id": lib_id,
        }
        await thumbnail_worker._process_one(test_db, claim)

    # Even with 2x threshold failures, only one open notification.
    async with test_db.execute(
        "SELECT COUNT(*) AS n FROM notifications "
        "WHERE category='thumbnail' AND related_id=? AND dismissed_at IS NULL",
        (lib_id,),
    ) as cur:
        row = await cur.fetchone()
    assert row["n"] == 1


async def test_failure_notification_below_threshold_is_silent(
    test_db, monkeypatch, tmp_path
):
    lib_id = await _insert_library(test_db)

    async def fake_extract(*_args, **_kwargs):
        return ThumbnailResult(success=False, error="broken")

    monkeypatch.setattr("services.thumbnail_service.extract_thumbnail", fake_extract)
    monkeypatch.setattr(thumbnail_worker, "_THUMBNAILS_DIR", tmp_path)

    # Only 2 failures — under the default threshold of 5
    fids = [await _insert_file(test_db, library_id=lib_id) for _ in range(2)]
    for fid in fids:
        claim = {
            "file_id": fid,
            "attempts": thumbnail_worker.MAX_ATTEMPTS - 1,
            "path": "/tmp/fake.mp4",
            "extension": ".mp4",
            "duration_sec": 100.0,
            "hdr_format": None,
            "library_id": lib_id,
        }
        await thumbnail_worker._process_one(test_db, claim)

    async with test_db.execute(
        "SELECT COUNT(*) AS n FROM notifications WHERE category='thumbnail'"
    ) as cur:
        row = await cur.fetchone()
    assert row["n"] == 0


# ── regenerate_library ─────────────────────────────────────────────────────


async def test_regenerate_resets_and_deletes_jpegs(test_db, monkeypatch, tmp_path):
    lib_id = await _insert_library(test_db)
    fids = [await _insert_file(test_db, library_id=lib_id) for _ in range(3)]

    # Pre-seed JPEGs on disk + mark each as ready
    monkeypatch.setattr(thumbnail_worker, "_THUMBNAILS_DIR", tmp_path)
    now = datetime.now(UTC).isoformat()
    for fid in fids:
        (tmp_path / f"{fid}.jpg").write_bytes(b"\xff\xd8fake")
        await test_db.execute(
            """
            UPDATE media_thumbnails
               SET status='ready', generated_at=?, updated_at=?
             WHERE file_id=?
            """,
            (now, now, fid),
        )
    await test_db.commit()

    count = await thumbnail_worker.regenerate_library(test_db, lib_id)
    assert count == 3

    # All thumb rows now pending, JPEGs deleted
    for fid in fids:
        row = await _fetch_thumb(test_db, fid)
        assert row["status"] == "pending"
        assert row["attempts"] == 0
        assert row["generated_at"] is None
        assert not (tmp_path / f"{fid}.jpg").exists()


async def test_regenerate_unknown_library_returns_zero(test_db):
    count = await thumbnail_worker.regenerate_library(test_db, "nope")
    assert count == 0


# ── Recovery on startup ────────────────────────────────────────────────────


async def test_recover_orphan_generating_rows(test_db):
    fid_a = await _insert_file(test_db)
    fid_b = await _insert_file(test_db)
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        "UPDATE media_thumbnails SET status='generating', attempts=0, updated_at=? "
        "WHERE file_id IN (?, ?)",
        (now, fid_a, fid_b),
    )
    await test_db.commit()

    recovered = await thumbnail_worker._recover_orphan_generating_rows(test_db)
    assert recovered == 2
    for fid in (fid_a, fid_b):
        row = await _fetch_thumb(test_db, fid)
        assert row["status"] == "pending"
        assert row["attempts"] == 1  # bumped


# ── Settings reader ────────────────────────────────────────────────────────


async def test_settings_reader_returns_default_width_pre_migration_038(test_db):
    """Until M4 ships migration 038, the thumbnail_width column doesn't
    exist; reader falls back to 320."""
    enabled, width = await thumbnail_worker._get_current_settings(test_db)
    assert enabled is True  # user_settings.generate_thumbnails default = 1
    assert width == 320


# ── Progress emission (post-ship visibility) ───────────────────────────────


async def test_emit_progress_counts_pending_ready_total(test_db, monkeypatch):
    """`_emit_progress` should compute pending+generating, ready, total for
    a library and fire a thumbnails_progress event with those counts."""
    lib_id = await _insert_library(test_db)
    f_pending = await _insert_file(test_db, library_id=lib_id)
    f_ready = await _insert_file(test_db, library_id=lib_id)
    f_other = await _insert_file(test_db, library_id=lib_id)
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        "UPDATE media_thumbnails SET status='ready', generated_at=?, "
        "updated_at=? WHERE file_id=?",
        (now, now, f_ready),
    )
    await test_db.commit()

    captured: list[tuple[str, dict | None]] = []
    monkeypatch.setattr(
        "services.notification_service.broadcast_event",
        lambda kind, data=None: captured.append((kind, data)),
    )

    # Reset throttle so the dedup doesn't interfere with this test.
    thumbnail_worker._PROGRESS_REFRESH_COUNTERS.clear()
    await thumbnail_worker._emit_progress(test_db, lib_id)

    # Exactly one thumbnails_progress event.
    progress_events = [c for c in captured if c[0] == "thumbnails_progress"]
    assert len(progress_events) == 1
    payload = progress_events[0][1]
    assert payload is not None
    assert payload["library_id"] == lib_id
    assert payload["pending"] == 2  # f_pending + f_other
    assert payload["ready"] == 1
    assert payload["total"] == 3

    # Suppress unused warning
    assert f_pending != f_other


async def test_emit_progress_throttles_library_changed(test_db, monkeypatch):
    """`library_changed` should fire every Nth call OR on the last-pending
    completion, not on every progress emission."""
    lib_id = await _insert_library(test_db)
    fid = await _insert_file(test_db, library_id=lib_id)
    # Mark this file ready so pending > 0 stays false-ish across calls
    # (we just want to drive the throttle logic).
    captured: list[tuple[str, dict | None]] = []
    monkeypatch.setattr(
        "services.notification_service.broadcast_event",
        lambda kind, data=None: captured.append((kind, data)),
    )
    thumbnail_worker._PROGRESS_REFRESH_COUNTERS.clear()

    # 4 calls below the threshold (5) — should NOT emit library_changed.
    # All 4 will see pending>0 because f stays in 'pending' status.
    for _ in range(4):
        await thumbnail_worker._emit_progress(test_db, lib_id)
    library_changed_events = [c for c in captured if c[0] == "library_changed"]
    assert (
        len(library_changed_events) == 0
    ), f"unexpected library_changed before threshold: {captured}"

    # 5th call — counter hits threshold → emit.
    await thumbnail_worker._emit_progress(test_db, lib_id)
    library_changed_events = [c for c in captured if c[0] == "library_changed"]
    assert len(library_changed_events) == 1
    # Counter resets to 0; another 4 calls below threshold should stay silent.
    captured.clear()
    for _ in range(4):
        await thumbnail_worker._emit_progress(test_db, lib_id)
    library_changed_events = [c for c in captured if c[0] == "library_changed"]
    assert len(library_changed_events) == 0

    # Suppress unused warning
    assert fid is not None


async def test_emit_progress_force_emits_when_queue_empties(test_db, monkeypatch):
    """Even below the throttle threshold, library_changed should fire if
    the library has zero pending+generating rows (last completion)."""
    lib_id = await _insert_library(test_db)
    fid = await _insert_file(test_db, library_id=lib_id)
    # Flip the only file to ready — pending should now read 0
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        "UPDATE media_thumbnails SET status='ready', generated_at=?, "
        "updated_at=? WHERE file_id=?",
        (now, now, fid),
    )
    await test_db.commit()

    captured: list[tuple[str, dict | None]] = []
    monkeypatch.setattr(
        "services.notification_service.broadcast_event",
        lambda kind, data=None: captured.append((kind, data)),
    )
    thumbnail_worker._PROGRESS_REFRESH_COUNTERS.clear()

    # First call — pending==0 short-circuits the throttle.
    await thumbnail_worker._emit_progress(test_db, lib_id)
    library_changed_events = [c for c in captured if c[0] == "library_changed"]
    assert len(library_changed_events) == 1


async def test_emit_progress_ignores_null_library_id(test_db, monkeypatch):
    """Files with library_id=NULL (orphan uploads) shouldn't trigger
    progress events — there's no library to scope the count to."""
    captured: list[tuple[str, dict | None]] = []
    monkeypatch.setattr(
        "services.notification_service.broadcast_event",
        lambda kind, data=None: captured.append((kind, data)),
    )
    await thumbnail_worker._emit_progress(test_db, None)
    assert captured == []


async def test_process_one_emits_progress_after_success(test_db, monkeypatch, tmp_path):
    """End-to-end: completing a thumbnail through _process_one fires
    thumbnails_progress for the parent library."""
    lib_id = await _insert_library(test_db)
    fid = await _insert_file(test_db, library_id=lib_id, extension=".mp4")

    async def fake_extract(*_args, **_kwargs):
        return ThumbnailResult(success=True)

    monkeypatch.setattr("services.thumbnail_service.extract_thumbnail", fake_extract)
    monkeypatch.setattr(thumbnail_worker, "_THUMBNAILS_DIR", tmp_path)

    captured: list[tuple[str, dict | None]] = []
    monkeypatch.setattr(
        "services.notification_service.broadcast_event",
        lambda kind, data=None: captured.append((kind, data)),
    )
    thumbnail_worker._PROGRESS_REFRESH_COUNTERS.clear()

    claim = {
        "file_id": fid,
        "attempts": 0,
        "path": "/tmp/fake.mp4",
        "extension": ".mp4",
        "duration_sec": 100.0,
        "hdr_format": None,
        "library_id": lib_id,
    }
    await thumbnail_worker._process_one(test_db, claim)

    progress_events = [c for c in captured if c[0] == "thumbnails_progress"]
    assert len(progress_events) == 1
    payload = progress_events[0][1]
    assert payload["library_id"] == lib_id
    assert payload["ready"] == 1
    assert payload["pending"] == 0
    assert payload["total"] == 1
