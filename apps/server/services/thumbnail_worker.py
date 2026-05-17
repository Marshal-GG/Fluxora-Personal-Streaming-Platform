"""Per-file thumbnail worker.

Background asyncio worker pool that consumes the ``media_thumbnails``
queue and writes generated JPEGs to ``<data_dir>/thumbnails/<file_id>.jpg``.

Lifecycle is owned by ``main.py``'s lifespan: ``start_worker()`` after
``init_db`` + ``stop_worker()`` on shutdown.  Multi-slot via N parallel
coroutines (default 2) that all claim from the same FIFO-by-priority
queue using ``UPDATE ... RETURNING`` for atomic single-row claim.

The worker:

* re-reads the ``generate_thumbnails`` + ``thumbnail_width`` settings
  per claim cycle (so a settings PATCH takes effect within one tick),
* dispatches by file extension via ``services.thumbnail_service.
  kind_for_extension``,
* writes status transitions (pending → generating → ready / failed /
  skipped) inside one transaction per file,
* aggregates failure notifications per library (one summary at the
  threshold, dedup'd against open notifications), so the bell doesn't
  drown the operator,
* sweeps orphan JPEG files from disk every 6 h.

Module-level state lets ``main.py`` ``start_worker()`` / ``stop_worker()``
be called like the existing ``transcode_service`` pair.  Multiple
``start_worker`` calls are idempotent.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime
from pathlib import Path

import aiosqlite

from config import get_data_dir
from services import notification_service, thumbnail_service
from services.thumbnail_service import ThumbnailResult

logger = logging.getLogger(__name__)


# ── Tunables (module-level so tests can monkeypatch) ───────────────────────

# Number of worker coroutines.  Each owns one in-flight FFmpeg / PyMuPDF
# subprocess at a time.  Bumped 2 → 4 post-ship (2026-05-16) — most home
# servers have ≥ 8 logical cores idle when not actively transcoding, and
# operator feedback was that thumbnail generation felt much slower than
# Windows Explorer's thumbnail provider.  If the streaming pipeline
# starts feeling CPU contention during heavy scans, dial back to 2.
CONCURRENCY = 4

# Sleep between empty-queue probes.  Keeps CPU near-zero when there's
# nothing to do.
POLL_INTERVAL_SEC = 2.0

# How many times we retry a `failed` row before giving up.  Each retry
# bumps the attempts counter; once it hits the cap we leave the row at
# `failed` until something explicitly resets it (operator regeneration
# or manual DB intervention).
MAX_ATTEMPTS = 3

# Permanent-failure count threshold per library for emitting a summary
# notification.  Below this, failures are silent (logged + persisted in
# media_thumbnails.error_message, but no bell badge).
FAILURE_NOTIFICATION_THRESHOLD = 5

# Sweeper cadence — orphan JPEG cleanup on disk for files whose
# media_thumbnails row was dropped (cascade from media_files deletion).
SWEEPER_INTERVAL_SEC = 6 * 60 * 60  # 6 h


# ── Module-level state (managed by start_worker / stop_worker) ─────────────

_WORKER_TASKS: list[asyncio.Task] = []
_SWEEPER_TASK: asyncio.Task | None = None
_STOP_EVENT: asyncio.Event | None = None
_THUMBNAILS_DIR: Path | None = None

# Per-library completion counter for throttling `library_changed` event
# emissions.  Reset to 0 on emit + always emitted on the last-pending
# completion so cards refresh even when scan size < 5 files.  See
# `_emit_progress`.
_PROGRESS_REFRESH_COUNTERS: dict[str, int] = {}
_PROGRESS_REFRESH_THRESHOLD = 5


def _thumbnails_dir() -> Path:
    """Resolve + cache the thumbnails directory under the data dir."""
    global _THUMBNAILS_DIR
    if _THUMBNAILS_DIR is None:
        _THUMBNAILS_DIR = get_data_dir() / "thumbnails"
        _THUMBNAILS_DIR.mkdir(parents=True, exist_ok=True)
    return _THUMBNAILS_DIR


# ── Public surface called from scan path + files router ────────────────────


async def enqueue(db: aiosqlite.Connection, file_id: str, *, priority: int = 0) -> None:
    """Add a pending thumbnail row for ``file_id``.

    INSERT OR IGNORE — re-scanning an already-thumbed file is a no-op.
    Called from ``library_service.scan_library`` after each new
    media_files INSERT.  Single DB write; no FFmpeg, no path resolution.
    Keeps the scan path O(1) per file for thumbnail work.
    """
    now = datetime.now(UTC).isoformat()
    await db.execute(
        """
        INSERT OR IGNORE INTO media_thumbnails
            (file_id, status, priority, created_at, updated_at)
        VALUES (?, 'pending', ?, ?, ?)
        """,
        (file_id, priority, now, now),
    )


async def boost_library(db: aiosqlite.Connection, library_id: str) -> int:
    """Bump priority on pending thumbnails for the given library.

    Called from ``routers/files.py`` when the operator opens a library
    on the desktop — that library's pending thumbs jump to the front of
    the worker queue.  Idempotent: only rows at priority=0 are updated,
    so rapid re-opens don't accumulate.  Returns the rows updated for
    logging.
    """
    now = datetime.now(UTC).isoformat()
    await db.execute(
        """
        UPDATE media_thumbnails
           SET priority = 10, updated_at = ?
         WHERE file_id IN (
             SELECT id FROM media_files WHERE library_id = ?
         )
           AND status = 'pending'
           AND priority = 0
        """,
        (now, library_id),
    )
    # aiosqlite's cursor.rowcount is unreliable for UPDATE; use SQLite's
    # `changes()` function which reflects the last UPDATE's row count.
    async with db.execute("SELECT changes() AS n") as cur:
        row = await cur.fetchone()
    rows = int(row["n"]) if row else 0
    await db.commit()
    return rows


async def regenerate_file(db: aiosqlite.Connection, file_id: str) -> bool:
    """Reset a single thumbnail row to pending + delete the cached JPEG.

    Returns True when a `media_thumbnails` row was reset or freshly
    inserted; False when the source `media_files` row doesn't exist
    (caller should 404).

    Backs `POST /files/{file_id}/regenerate-thumbnail` — the right-click
    "Generate thumbnail" action for indexed entries (failed / stale /
    pending rows that the operator wants jumped to the front of the
    queue).  Mirror of `regenerate_library` scoped to one file with
    priority=10.
    """
    async with db.execute("SELECT id FROM media_files WHERE id = ?", (file_id,)) as cur:
        row = await cur.fetchone()
    if row is None:
        return False

    # Best-effort JPEG cleanup.  Missing file is fine — about to re-render.
    jpeg = _thumbnails_dir() / f"{file_id}.jpg"
    try:
        jpeg.unlink(missing_ok=True)
    except OSError:
        logger.warning(
            "Failed to delete thumbnail for regenerate: %s",
            jpeg,
            exc_info=True,
        )

    now = datetime.now(UTC).isoformat()
    await db.execute(
        """
        UPDATE media_thumbnails
           SET status = 'pending',
               attempts = 0,
               error_message = NULL,
               generated_at = NULL,
               priority = 10,
               updated_at = ?
         WHERE file_id = ?
        """,
        (now, file_id),
    )
    # INSERT OR IGNORE covers the "row never existed" case (file added
    # before the worker was wired up, or thumbnail enqueue failed at
    # scan time).
    await db.execute(
        """
        INSERT OR IGNORE INTO media_thumbnails
            (file_id, status, priority, created_at, updated_at)
        VALUES (?, 'pending', 10, ?, ?)
        """,
        (file_id, now, now),
    )
    await db.commit()
    return True


async def regenerate_library(db: aiosqlite.Connection, library_id: str) -> int:
    """Reset every thumbnail row for files in ``library_id`` to pending.

    Deletes the cached JPEGs on disk so the worker re-renders them at
    current settings (width, HDR tonemap, etc).  Called from
    ``POST /library/{id}/regenerate-thumbnails``.  Returns the count of
    files queued for re-render.

    Two efficiency gates compared to a naive "reset everything":
      * Files whose extension has no extractor (subtitles / archives /
        source files / etc.) are not reset — they'd just be re-marked
        `skipped` by the worker, wasting one claim+commit cycle per
        file.  Skipped status sticks.
      * Files that already sit at `status='skipped'` are left alone
        for the same reason.
      * The missing-row backfill is one `executemany` instead of N
        individual `INSERT OR IGNORE` round-trips, so a 10k-file
        library re-queues in one transaction trip rather than 10k.
    """
    async with db.execute(
        "SELECT id, extension FROM media_files WHERE library_id = ?",
        (library_id,),
    ) as c:
        file_rows = await c.fetchall()
    if not file_rows:
        return 0

    # Filter to only files that have an extractor; subtitle / archive /
    # text / source files stay un-touched (their `skipped` rows are
    # correct + permanent).
    extractable_ids = [
        r["id"]
        for r in file_rows
        if thumbnail_service.kind_for_extension(r["extension"] or "") is not None
    ]
    if not extractable_ids:
        return 0

    # Delete cached JPEGs.  Best-effort — missing files are fine, we're
    # about to re-render anyway.
    tdir = _thumbnails_dir()
    for fid in extractable_ids:
        jpeg = tdir / f"{fid}.jpg"
        try:
            jpeg.unlink(missing_ok=True)
        except OSError:
            logger.warning(
                "Failed to delete thumbnail for regenerate: %s", jpeg, exc_info=True
            )

    now = datetime.now(UTC).isoformat()
    placeholders = ",".join("?" for _ in extractable_ids)
    # `status != 'skipped'` so a file the operator previously could not
    # thumbnail (corrupt source, e.g.) but whose extractor exists stays
    # untouched until something explicitly re-tries it.  Today the
    # worker only emits `skipped` for the no-extractor case (those are
    # already excluded above), so this is defence in depth for the
    # extractor-returned-skipped paths (audio without APIC, encrypted
    # PDF).
    await db.execute(
        f"""
        UPDATE media_thumbnails
           SET status = 'pending',
               attempts = 0,
               error_message = NULL,
               generated_at = NULL,
               updated_at = ?
         WHERE file_id IN ({placeholders})
           AND status != 'skipped'
        """,
        (now, *extractable_ids),
    )
    # Insert any missing thumbnail rows in a single `executemany` —
    # cheaper than the per-id round-trip the previous version did.
    await db.executemany(
        """
        INSERT OR IGNORE INTO media_thumbnails
            (file_id, status, priority, created_at, updated_at)
        VALUES (?, 'pending', 10, ?, ?)
        """,
        [(fid, now, now) for fid in extractable_ids],
    )
    await db.commit()
    return len(extractable_ids)


# ── Worker loop ────────────────────────────────────────────────────────────


async def _claim_one(db: aiosqlite.Connection) -> dict | None:
    """Atomically claim one pending row and return its joined metadata.

    ``UPDATE ... RETURNING`` flips status=pending → status=generating
    in a single statement so two concurrent worker coroutines can't
    grab the same row.  Ordering is `priority DESC, created_at ASC` so
    boost'd rows are picked first, FIFO inside each priority band.

    Returns the joined media_files columns the extractor needs, or
    None when the queue is empty.
    """
    now = datetime.now(UTC).isoformat()
    # We can't combine UPDATE...RETURNING with a JOIN in SQLite — so
    # claim by id, then SELECT the joined row.  The two statements
    # are wrapped in a single transaction at the caller level to make
    # the claim atomic against other workers.
    async with db.execute(
        """
        UPDATE media_thumbnails
           SET status = 'generating', updated_at = ?
         WHERE file_id = (
             SELECT file_id FROM media_thumbnails
              WHERE status = 'pending' AND attempts < ?
              ORDER BY priority DESC, created_at ASC
              LIMIT 1
         )
        RETURNING file_id, attempts, priority
        """,
        (now, MAX_ATTEMPTS),
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        await db.commit()
        return None

    file_id = row["file_id"]
    attempts = row["attempts"]
    async with db.execute(
        """
        SELECT mf.id, mf.path, mf.extension, mf.duration_sec, mf.hdr_format,
               mf.library_id
          FROM media_files mf
         WHERE mf.id = ?
        """,
        (file_id,),
    ) as cur:
        file_row = await cur.fetchone()

    await db.commit()
    if file_row is None:
        # Source media_files row vanished between claim and lookup —
        # mark the thumbnail row as failed so we don't loop on it.
        await _mark_failed(
            db,
            file_id,
            attempts=attempts + 1,
            error="source row gone",
            library_id=None,
        )
        return None

    return {
        "file_id": file_id,
        "attempts": attempts,
        "path": file_row["path"],
        "extension": file_row["extension"],
        "duration_sec": file_row["duration_sec"],
        "hdr_format": file_row["hdr_format"],
        "library_id": file_row["library_id"],
    }


async def _mark_ready(db: aiosqlite.Connection, file_id: str, attempts: int) -> None:
    now = datetime.now(UTC).isoformat()
    await db.execute(
        """
        UPDATE media_thumbnails
           SET status = 'ready',
               generated_at = ?,
               attempts = ?,
               error_message = NULL,
               updated_at = ?
         WHERE file_id = ?
        """,
        (now, attempts, now, file_id),
    )
    await db.commit()


async def _mark_skipped(db: aiosqlite.Connection, file_id: str, error: str) -> None:
    now = datetime.now(UTC).isoformat()
    # Truncate error to fit a reasonable column size; full FFmpeg
    # stderr can be many KB.
    err = (error or "")[:512]
    await db.execute(
        """
        UPDATE media_thumbnails
           SET status = 'skipped',
               error_message = ?,
               updated_at = ?
         WHERE file_id = ?
        """,
        (err, now, file_id),
    )
    await db.commit()


async def _mark_failed(
    db: aiosqlite.Connection,
    file_id: str,
    *,
    attempts: int,
    error: str,
    library_id: str | None,
) -> None:
    now = datetime.now(UTC).isoformat()
    err = (error or "")[:512]
    await db.execute(
        """
        UPDATE media_thumbnails
           SET status = 'failed',
               attempts = ?,
               error_message = ?,
               updated_at = ?
         WHERE file_id = ?
        """,
        (attempts, err, now, file_id),
    )
    await db.commit()

    # Aggregated notification: only fire when this library's permanent-
    # failure count crosses the threshold AND there's no open thumbnail
    # notification already.  Dedup matches the existing producer pattern
    # in license / encoder / storage notifications.
    if library_id is not None and attempts >= MAX_ATTEMPTS:
        await _maybe_emit_failure_notification(db, library_id)


async def _emit_progress(db: aiosqlite.Connection, library_id: str | None) -> None:
    """Emit a `thumbnails_progress` WS event for this library + throttled
    `library_changed` so cover_urls refresh as thumbs land.

    Per-library counter throttles the `library_changed` emit to every
    Nth completion (default 5) or whenever the queue empties — so a
    1000-file scan generates ~200 cover_urls refreshes, not 1000, but a
    small 3-file library still sees its final completion trigger a
    refresh.

    The `thumbnails_progress` frame is fan-out unthrottled — bandwidth
    is negligible (~100 bytes per frame) and the client wants prompt
    updates to the progress bar.  Frame shape:
        {"type": "event", "kind": "thumbnails_progress",
         "data": {"library_id": "...", "pending": N, "ready": M, "total": T}}
    """
    if library_id is None:
        return
    # Pending includes 'generating' since those are claim-but-not-done
    # rows — visually the operator wants the bar to count them.
    async with db.execute(
        """
        SELECT
            SUM(CASE WHEN t.status IN ('pending', 'generating') THEN 1 ELSE 0 END)
                AS pending,
            SUM(CASE WHEN t.status = 'ready' THEN 1 ELSE 0 END) AS ready,
            COUNT(*) AS total
          FROM media_thumbnails t
          JOIN media_files m ON m.id = t.file_id
         WHERE m.library_id = ?
        """,
        (library_id,),
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        return

    pending = int(row["pending"] or 0)
    ready = int(row["ready"] or 0)
    total = int(row["total"] or 0)

    try:
        notification_service.broadcast_event(
            "thumbnails_progress",
            data={
                "library_id": library_id,
                "pending": pending,
                "ready": ready,
                "total": total,
            },
        )
    except Exception:
        logger.warning("Failed to emit thumbnails_progress event", exc_info=True)

    # Throttled cover_urls refresh: bump per-library counter; emit
    # `library_changed` every Nth completion + always when queue empties
    # for the library (so the operator sees the final cards land).
    count = _PROGRESS_REFRESH_COUNTERS.get(library_id, 0) + 1
    if count >= _PROGRESS_REFRESH_THRESHOLD or pending == 0:
        _PROGRESS_REFRESH_COUNTERS[library_id] = 0
        try:
            notification_service.broadcast_event("library_changed")
        except Exception:
            logger.warning(
                "Failed to emit library_changed after thumbnail completion",
                exc_info=True,
            )
    else:
        _PROGRESS_REFRESH_COUNTERS[library_id] = count


async def _maybe_emit_failure_notification(
    db: aiosqlite.Connection, library_id: str
) -> None:
    """Emit one summary notification per library when failure count
    crosses the threshold.

    Dedups against an existing open (``dismissed_at IS NULL``)
    notification for the same ``(category='thumbnail', related_id=
    library_id)`` so a restart loop or rapid-fire failures don't spam
    the bell.  Operator dismissing resets the cycle.
    """
    # Count permanent failures (attempts >= max) for this library.
    async with db.execute(
        """
        SELECT COUNT(*) AS n
          FROM media_thumbnails t
          JOIN media_files m ON m.id = t.file_id
         WHERE m.library_id = ?
           AND t.status = 'failed'
           AND t.attempts >= ?
        """,
        (library_id, MAX_ATTEMPTS),
    ) as cur:
        row = await cur.fetchone()
    count = int(row["n"]) if row else 0
    if count < FAILURE_NOTIFICATION_THRESHOLD:
        return

    # Dedup against an existing open notification for this library.
    async with db.execute(
        """
        SELECT 1 FROM notifications
         WHERE category = 'thumbnail'
           AND related_id = ?
           AND dismissed_at IS NULL
         LIMIT 1
        """,
        (library_id,),
    ) as cur:
        existing = await cur.fetchone()
    if existing is not None:
        return

    # Look up library name for the message body.
    async with db.execute(
        "SELECT name FROM libraries WHERE id = ?", (library_id,)
    ) as cur:
        lib_row = await cur.fetchone()
    lib_name = lib_row["name"] if lib_row else library_id

    try:
        await notification_service.create(
            db,
            type="warning",
            category="thumbnail",
            title=f"Thumbnail generation failed for {count} files",
            message=(
                f"Some files in library '{lib_name}' couldn't be thumbnailed. "
                "Check the server logs and verify FFmpeg is healthy."
            ),
            related_kind="library",
            related_id=library_id,
        )
    except Exception:
        logger.warning("Failed to write thumbnail failure notification", exc_info=True)


async def _recover_orphan_generating_rows(db: aiosqlite.Connection) -> int:
    """Reset any rows left at status='generating' from a previous crash.

    Bumps attempts so a poison input file can't get stuck cycling.
    Returns the count for logging.  Idempotent — running it twice in a
    row is a no-op the second time.
    """
    now = datetime.now(UTC).isoformat()
    await db.execute(
        """
        UPDATE media_thumbnails
           SET status = 'pending',
               attempts = attempts + 1,
               updated_at = ?
         WHERE status = 'generating'
        """,
        (now,),
    )
    async with db.execute("SELECT changes() AS n") as cur:
        row = await cur.fetchone()
    rows = int(row["n"]) if row else 0
    await db.commit()
    return rows


async def _get_current_settings(
    db: aiosqlite.Connection,
) -> tuple[bool, int]:
    """Return (generate_thumbnails enabled, thumbnail_width).

    Reads from user_settings.  The width column is added in migration 038
    (M4) — until that migration ships, we tolerate AttributeError /
    sqlite KeyError and fall back to the default 320.  This makes the
    worker safe to run between M2 and M4.
    """
    try:
        async with db.execute(
            "SELECT generate_thumbnails, thumbnail_width "
            "FROM user_settings WHERE id = 1"
        ) as cur:
            row = await cur.fetchone()
        if row is None:
            return True, 320
        enabled = bool(row["generate_thumbnails"])
        try:
            width = int(row["thumbnail_width"]) or 320
        except (KeyError, IndexError, TypeError):
            width = 320
        return enabled, width
    except aiosqlite.OperationalError:
        # Migration 038 not yet applied — fall back to the M1 default.
        async with db.execute(
            "SELECT generate_thumbnails FROM user_settings WHERE id = 1"
        ) as cur:
            row = await cur.fetchone()
        enabled = bool(row["generate_thumbnails"]) if row else True
        return enabled, 320


async def _process_one(db: aiosqlite.Connection, claim: dict) -> None:
    """Run the extractor for a single claimed row, then update status."""
    file_id = claim["file_id"]
    library_id = claim["library_id"]
    next_attempts = claim["attempts"] + 1

    src = Path(claim["path"])
    out = _thumbnails_dir() / f"{file_id}.jpg"

    kind = thumbnail_service.kind_for_extension(claim["extension"] or "")
    if kind is None:
        await _mark_skipped(db, file_id, "extension not supported")
        return

    _, width = await _get_current_settings(db)

    try:
        result: ThumbnailResult = await thumbnail_service.extract_thumbnail(
            src,
            out,
            kind=kind,
            width=width,
            duration_sec=claim["duration_sec"],
            hdr_format=claim["hdr_format"],
        )
    except Exception as e:
        logger.exception("Thumbnail extractor raised for %s", file_id)
        # Clean up any partial output before marking failed.
        try:
            out.unlink(missing_ok=True)
        except OSError:
            pass
        await _mark_failed(
            db,
            file_id,
            attempts=next_attempts,
            error=f"extractor raised: {e}",
            library_id=library_id,
        )
        return

    if result.success:
        await _mark_ready(db, file_id, next_attempts)
        await _emit_progress(db, library_id)
        return
    if result.skipped:
        # Permanent — clean partial output (defensive; skipped paths
        # don't write but FFmpeg can leave a 0-byte file on some
        # failure shapes) and persist.
        try:
            if out.exists() and out.stat().st_size == 0:
                out.unlink()
        except OSError:
            pass
        await _mark_skipped(db, file_id, result.error or "skipped")
        await _emit_progress(db, library_id)
        return

    # Transient failure — partial output likely useless; remove so the
    # endpoint's "file missing" guard works correctly.
    try:
        out.unlink(missing_ok=True)
    except OSError:
        pass
    await _mark_failed(
        db,
        file_id,
        attempts=next_attempts,
        error=result.error or "extractor reported failure",
        library_id=library_id,
    )
    await _emit_progress(db, library_id)


async def _worker_loop(slot_id: int) -> None:
    """Single worker coroutine.  Claims + processes one row at a time,
    sleeps between iterations when the queue is empty."""
    from database.db import get_db

    logger.info("Thumbnail worker slot %d started", slot_id)
    assert _STOP_EVENT is not None
    while not _STOP_EVENT.is_set():
        try:
            db = await get_db()
            enabled, _ = await _get_current_settings(db)
            if not enabled:
                # Setting toggled off — sleep, then re-check.
                try:
                    await asyncio.wait_for(
                        _STOP_EVENT.wait(), timeout=POLL_INTERVAL_SEC
                    )
                except TimeoutError:
                    pass
                continue

            claim = await _claim_one(db)
            if claim is None:
                # Empty queue — wait for the next tick or shutdown.
                try:
                    await asyncio.wait_for(
                        _STOP_EVENT.wait(), timeout=POLL_INTERVAL_SEC
                    )
                except TimeoutError:
                    pass
                continue

            await _process_one(db, claim)
        except asyncio.CancelledError:
            raise
        except Exception:
            # Top-level guard: any unexpected exception logs and sleeps,
            # then the loop continues.  A worker should never silently die.
            logger.exception(
                "Thumbnail worker slot %d hit an unexpected error; backing off",
                slot_id,
            )
            try:
                await asyncio.wait_for(_STOP_EVENT.wait(), timeout=POLL_INTERVAL_SEC)
            except TimeoutError:
                pass

    logger.info("Thumbnail worker slot %d stopped", slot_id)


# ── Orphan-JPEG sweeper ────────────────────────────────────────────────────


async def _sweep_orphan_jpegs() -> int:
    """Delete JPEGs on disk whose file_id is no longer in media_thumbnails.

    Caused by:
    * media_files row deleted (ON DELETE CASCADE drops the thumbnail
      row; the JPEG on disk is orphaned)
    * stray files dropped into the dir manually

    Bounded at 100 deletions per pass so a corrupted dir doesn't IO-storm.
    Returns the count deleted for logging.
    """
    from database.db import get_db

    tdir = _thumbnails_dir()
    if not tdir.exists():
        return 0

    db = await get_db()
    async with db.execute("SELECT file_id FROM media_thumbnails") as cur:
        known = {r["file_id"] for r in await cur.fetchall()}

    deleted = 0
    for path in tdir.iterdir():
        if deleted >= 100:
            break
        if not path.is_file() or path.suffix.lower() != ".jpg":
            continue
        file_id = path.stem
        if file_id in known:
            continue
        try:
            path.unlink()
            deleted += 1
        except OSError:
            logger.warning("Sweeper failed to delete %s", path, exc_info=True)
    return deleted


async def _sweeper_loop() -> None:
    """Run the orphan-JPEG sweeper on the configured cadence."""
    assert _STOP_EVENT is not None
    while not _STOP_EVENT.is_set():
        try:
            await asyncio.wait_for(_STOP_EVENT.wait(), timeout=SWEEPER_INTERVAL_SEC)
            # If we made it here, stop event fired — exit.
            return
        except TimeoutError:
            pass

        try:
            n = await _sweep_orphan_jpegs()
            if n:
                logger.info("Thumbnail sweeper: deleted %d orphan JPEGs", n)
        except Exception:
            logger.warning("Thumbnail sweeper raised", exc_info=True)


# ── Lifecycle ──────────────────────────────────────────────────────────────


async def start_worker() -> None:
    """Start the worker pool + sweeper.

    Idempotent — repeat calls are no-ops while the previous run is
    still active.  Runs the orphan-`generating` reset before spawning
    so workers don't double-claim rows the previous server instance
    left in flight.
    """
    global _STOP_EVENT, _SWEEPER_TASK

    if _WORKER_TASKS and any(not t.done() for t in _WORKER_TASKS):
        return

    from database.db import get_db

    db = await get_db()
    recovered = await _recover_orphan_generating_rows(db)
    if recovered:
        logger.info(
            "Thumbnail worker: reset %d orphan 'generating' rows from prior crash",
            recovered,
        )

    _STOP_EVENT = asyncio.Event()
    _WORKER_TASKS.clear()
    for i in range(CONCURRENCY):
        _WORKER_TASKS.append(
            asyncio.create_task(_worker_loop(i), name=f"thumbnail-worker-{i}")
        )
    _SWEEPER_TASK = asyncio.create_task(_sweeper_loop(), name="thumbnail-sweeper")
    logger.info("Thumbnail worker started with %d slot(s)", CONCURRENCY)


async def stop_worker() -> None:
    """Signal shutdown + wait briefly for workers to drain.

    Best-effort: workers that don't return within 5 s are cancelled.
    """
    global _STOP_EVENT, _SWEEPER_TASK

    if _STOP_EVENT is not None:
        _STOP_EVENT.set()

    tasks = list(_WORKER_TASKS)
    if _SWEEPER_TASK is not None:
        tasks.append(_SWEEPER_TASK)

    if tasks:
        try:
            await asyncio.wait_for(
                asyncio.gather(*tasks, return_exceptions=True),
                timeout=5.0,
            )
        except TimeoutError:
            logger.warning("Thumbnail worker did not drain in 5 s; cancelling tasks")
            for t in tasks:
                if not t.done():
                    t.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)

    _WORKER_TASKS.clear()
    _SWEEPER_TASK = None
    _STOP_EVENT = None
    logger.info("Thumbnail worker stopped")
