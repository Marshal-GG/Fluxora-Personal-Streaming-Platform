import asyncio
import json
import logging
import os
import re
import shutil
import uuid
from datetime import UTC, datetime
from pathlib import Path

import aiosqlite
from fastapi import UploadFile

from services.ffmpeg_service import probe_video
from services.tmdb_service import TmdbService

logger = logging.getLogger(__name__)


# Per-library scan locks.  Two `POST /library/{id}/scan` calls in flight
# for the same library raced each other in the field — each ran the
# full directory walk + INSERT loop + per-file TMDB enrichment, so a
# double-clicked Scan button produced double the TMDB API calls and
# double the activity-log entries.  This lock makes the second caller
# wait for the first to finish; once it acquires the lock it sees no
# new files (the first call already inserted them) and returns 0
# almost instantly.
_scan_locks: dict[str, asyncio.Lock] = {}


def _get_scan_lock(library_id: str) -> asyncio.Lock:
    lock = _scan_locks.get(library_id)
    if lock is None:
        lock = asyncio.Lock()
        _scan_locks[library_id] = lock
    return lock


# Filename patterns that look like DVR / tuner captures.  These never
# match a real TMDB title because the embedded timestamp poisons the
# search query — "Genshin Impact 2026.04.09 - 21.16.23.02" is almost
# certainly a 4K-capture-card recording, not a movie.  Detected by the
# presence of a "YYYY.MM.DD" or "YYYY-MM-DD" date component anywhere in
# the stem (capture software conventions vary; the date-only marker
# catches all the variants we've seen).  When this matches we skip the
# TMDB API call entirely — saves an HTTP round-trip per file and stops
# the desktop log from filling with "TMDB enrichment done: 0/N" lines
# during library indexing.
_DVR_CAPTURE_PATTERN = re.compile(
    r"\d{4}[.\-]\d{2}[.\-]\d{2}",
)


def _looks_like_dvr_capture(stem: str) -> bool:
    """Return True when the filename stem contains a date marker that
    typical DVR / capture-card recordings include but real TMDB
    titles never do."""
    return bool(_DVR_CAPTURE_PATTERN.search(stem))


def _is_valid_absolute_media_path(path_str: str) -> bool:
    """Reject obviously-corrupt paths before they hit FFmpeg.

    Three known failure modes have produced unreadable rows in the past:

    1. ``root_paths`` accidentally consumed as a JSON-encoded string
       instead of a parsed list — ``root_paths[0]`` returns the literal
       ``'['`` character, so the joined path becomes ``[\\filename.ext``
       with no drive letter.  FFmpeg later fails with ``Error opening
       input: No such file or directory`` and the user sees a transcode
       notification with no actionable diagnostic.
    2. Windows path missing the drive letter (``\\filename.ext``).
    3. Empty or whitespace-only path.

    Returns False for any of these so ``scan_library`` /
    ``upload_file_to_library`` can refuse the row before INSERT.
    """
    if not path_str or not path_str.strip():
        return False
    if not os.path.isabs(path_str):
        return False
    if path_str.startswith("[") or "\x00" in path_str:
        return False
    return True

_MEDIA_EXTENSIONS = {
    ".mp4",
    ".mkv",
    ".avi",
    ".mov",
    ".wmv",
    ".flv",
    ".webm",
    ".m4v",
    ".mp3",
    ".flac",
    ".aac",
    ".wav",
    ".ogg",
    ".m4a",
    ".pdf",
    ".epub",
    ".cbz",
    ".cbr",
}

# Subset of _MEDIA_EXTENSIONS that ffprobe can extract video stream metadata
# for. Audio/document extensions are skipped — running ffprobe on a PDF
# wastes a subprocess and yields nothing useful.
_PROBEABLE_EXTENSIONS = {
    ".mp4",
    ".mkv",
    ".avi",
    ".mov",
    ".wmv",
    ".flv",
    ".webm",
    ".m4v",
}


async def get_storage_breakdown(db: aiosqlite.Connection) -> dict:
    """Aggregated storage usage across all libraries — Dashboard donut.

    Returns counts grouped by library `type` (movies / tv / music / files)
    plus the combined disk capacity of every unique mount point that backs
    at least one library root. Mount-point dedup uses `os.stat().st_dev` so
    two libraries on the same disk only count toward capacity once.
    """
    async with db.execute(
        """
        SELECT l.type, COALESCE(SUM(m.size_bytes), 0) AS total
          FROM libraries l
          LEFT JOIN media_files m ON m.library_id = l.id
         GROUP BY l.type
        """
    ) as cur:
        type_rows = await cur.fetchall()

    by_type = {"movies": 0, "tv": 0, "music": 0, "files": 0}
    for row in type_rows:
        if row["type"] in by_type:
            by_type[row["type"]] = int(row["total"] or 0)

    total_bytes = sum(by_type.values())

    async with db.execute("SELECT root_paths FROM libraries") as cur:
        lib_rows = await cur.fetchall()

    seen_devices: set[int] = set()
    capacity_bytes = 0
    for lib_row in lib_rows:
        try:
            paths = json.loads(lib_row["root_paths"])
        except (ValueError, TypeError):
            continue
        if not isinstance(paths, list):
            continue
        for raw in paths:
            try:
                p = Path(str(raw))
                if not p.exists():
                    continue
                dev = p.stat().st_dev
                if dev in seen_devices:
                    continue
                seen_devices.add(dev)
                capacity_bytes += shutil.disk_usage(p).total
            except OSError as exc:
                logger.warning("Could not stat library root %s: %s", raw, exc)
                continue

    if capacity_bytes > 0 and total_bytes / capacity_bytes > 0.9:
        percent = round(total_bytes / capacity_bytes * 100, 1)
        try:
            from services import notification_service

            async with db.execute(
                """
                SELECT id FROM notifications
                 WHERE category = 'storage'
                   AND related_id = 'primary'
                   AND created_at > datetime('now', '-1 day')
                   AND dismissed_at IS NULL
                 LIMIT 1
                """
            ) as _cur:
                _existing = await _cur.fetchone()
            if _existing is None:
                await notification_service.create(
                    db,
                    type="warning",
                    category="storage",
                    title="Storage almost full",
                    message=f"{percent}% of your library disk is used.",
                    related_kind="storage",
                    related_id="primary",
                )
        except Exception:
            logger.warning("Failed to emit storage notification", exc_info=True)

    return {
        "total_bytes": total_bytes,
        "capacity_bytes": capacity_bytes,
        "by_type": by_type,
    }


async def _library_aggregates(
    db: aiosqlite.Connection, library_id: str
) -> tuple[int, int, list[str]]:
    """Return (file_count, total_size_bytes, cover_urls) for a library.

    `cover_urls` is up to 4 of the most recently-updated `poster_url` values
    among the library's enriched media files. Empty list if none enriched.
    """
    async with db.execute(
        """
        SELECT COUNT(*) AS cnt,
               COALESCE(SUM(size_bytes), 0) AS total
          FROM media_files
         WHERE library_id = ?
        """,
        (library_id,),
    ) as cur:
        row = await cur.fetchone()
    file_count = int(row["cnt"]) if row else 0
    total_size = int(row["total"]) if row else 0

    async with db.execute(
        """
        SELECT poster_url
          FROM media_files
         WHERE library_id = ? AND poster_url IS NOT NULL AND poster_url != ''
         ORDER BY updated_at DESC
         LIMIT 4
        """,
        (library_id,),
    ) as cur:
        cover_rows = await cur.fetchall()
    cover_urls = [r["poster_url"] for r in cover_rows]

    return file_count, total_size, cover_urls


async def list_libraries(db: aiosqlite.Connection) -> list[dict]:
    async with db.execute("SELECT * FROM libraries ORDER BY created_at") as cur:
        rows = await cur.fetchall()

    result = []
    for row in rows:
        file_count, total_size, cover_urls = await _library_aggregates(db, row["id"])
        lib_dict = dict(row)
        if "root_paths" in lib_dict and isinstance(lib_dict["root_paths"], str):
            lib_dict["root_paths"] = json.loads(lib_dict["root_paths"])
        result.append(
            {
                **lib_dict,
                "file_count": file_count,
                "total_size_bytes": total_size,
                "cover_urls": cover_urls,
            }
        )
    return result


async def get_library(db: aiosqlite.Connection, library_id: str) -> dict | None:
    async with db.execute("SELECT * FROM libraries WHERE id = ?", (library_id,)) as cur:
        row = await cur.fetchone()
    if row is None:
        return None

    file_count, total_size, cover_urls = await _library_aggregates(db, library_id)
    lib_dict = dict(row)
    if "root_paths" in lib_dict and isinstance(lib_dict["root_paths"], str):
        lib_dict["root_paths"] = json.loads(lib_dict["root_paths"])
    return {
        **lib_dict,
        "file_count": file_count,
        "total_size_bytes": total_size,
        "cover_urls": cover_urls,
    }


async def update_library(
    db: aiosqlite.Connection,
    library_id: str,
    *,
    name: str | None = None,
    root_paths: list[str] | None = None,
) -> dict | None:
    """Partial update of a library. Returns the refreshed row or None if not found."""
    if name is None and root_paths is None:
        return await get_library(db, library_id)

    async with db.execute(
        "SELECT id FROM libraries WHERE id = ?", (library_id,)
    ) as cur:
        if await cur.fetchone() is None:
            return None

    sets: list[str] = []
    params: list[object] = []
    if name is not None:
        sets.append("name = ?")
        params.append(name)
    if root_paths is not None:
        sets.append("root_paths = ?")
        params.append(json.dumps(root_paths))

    params.append(library_id)
    await db.execute(
        f"UPDATE libraries SET {', '.join(sets)} WHERE id = ?",
        tuple(params),
    )
    await db.commit()
    logger.info("Library updated: %s", library_id)
    return await get_library(db, library_id)


async def create_library(
    db: aiosqlite.Connection,
    name: str,
    lib_type: str,
    root_paths: list[str],
) -> dict:
    library_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    paths_json = json.dumps(root_paths)

    await db.execute(
        """
        INSERT INTO libraries (id, name, type, root_paths, created_at)
        VALUES (?, ?, ?, ?, ?)
        """,
        (library_id, name, lib_type, paths_json, now),
    )
    await db.commit()
    logger.info("Library created: %s (%s)", name, library_id)

    return {
        "id": library_id,
        "name": name,
        "type": lib_type,
        "root_paths": root_paths,
        "last_scanned": None,
        "created_at": now,
        "file_count": 0,
        "total_size_bytes": 0,
        "cover_urls": [],
    }


async def delete_library(db: aiosqlite.Connection, library_id: str) -> bool:
    async with db.execute(
        "SELECT id FROM libraries WHERE id = ?", (library_id,)
    ) as cur:
        if await cur.fetchone() is None:
            return False

    await db.execute("DELETE FROM libraries WHERE id = ?", (library_id,))
    await db.commit()
    logger.info("Library deleted: %s", library_id)
    return True


async def list_files(
    db: aiosqlite.Connection, library_id: str | None = None
) -> list[dict]:
    if library_id:
        async with db.execute(
            "SELECT * FROM media_files WHERE library_id = ? ORDER BY name",
            (library_id,),
        ) as cur:
            rows = await cur.fetchall()
    else:
        async with db.execute("SELECT * FROM media_files ORDER BY name") as cur:
            rows = await cur.fetchall()
    return [dict(row) for row in rows]


async def list_recent_files(db: aiosqlite.Connection, limit: int = 20) -> list[dict]:
    """Most-recently-added media files, newest first.

    Backs the mobile Home "Recently added" rail. `limit` is clamped at the
    router boundary to [1, 50]; this layer trusts whatever it is handed.
    """
    async with db.execute(
        "SELECT * FROM media_files ORDER BY created_at DESC LIMIT ?",
        (limit,),
    ) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


async def search_files(
    db: aiosqlite.Connection, query: str, limit: int = 20
) -> list[dict]:
    """Case-insensitive substring match on `name` + TMDB `title`.

    Phase B v1 — SQL `LIKE` is fine; FTS5 is documented as the v2 swap-in
    in the real-data backfill plan §5 row 1.  `query` is escaped for the
    `_` and `%` wildcard characters so a search for "season_1" doesn't
    silently match "season-1", "season_one", etc.
    """
    if not query:
        return []
    escaped = query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    pattern = f"%{escaped}%"
    async with db.execute(
        """
        SELECT * FROM media_files
         WHERE (name  LIKE ? ESCAPE '\\' COLLATE NOCASE
             OR title LIKE ? ESCAPE '\\' COLLATE NOCASE)
         ORDER BY created_at DESC
         LIMIT ?
        """,
        (pattern, pattern, limit),
    ) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


async def list_continue_watching(
    db: aiosqlite.Connection, limit: int = 12
) -> list[dict]:
    """Files with non-zero resume position that aren't effectively complete.

    Phase B v1 — uses the global `last_progress_sec` column on `media_files`
    (single-tenant home server, so per-client progress isn't required).
    Excludes rows where `last_progress_sec >= duration_sec * 0.95` so a
    file watched to the end stops resurfacing.  Sorted by `updated_at DESC`
    — the stream-progress writer touches that column on every reported
    progress event, so the natural sort matches "recently watched".
    """
    async with db.execute(
        """
        SELECT * FROM media_files
         WHERE last_progress_sec > 0
           AND (duration_sec IS NULL OR last_progress_sec < duration_sec * 0.95)
         ORDER BY updated_at DESC
         LIMIT ?
        """,
        (limit,),
    ) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


async def get_client_stats(db: aiosqlite.Connection, client_id: str) -> dict:
    """Aggregate per-client watch stats — backs `/auth/clients/me/stats`.

    Returns three integers:
    - `hours`   — `SUM(progress_sec) / 3600`, rounded down.
    - `movies`  — distinct file ids the client has at least one stream
                  session against where the file's library is `movies`.
    - `shows`   — distinct `tmdb_show_id` values across the client's
                  stream sessions.  Always 0 until Phase D back-fills
                  `tmdb_show_id` for TV episodes — that's correct
                  ("we don't know how many shows you've watched") rather
                  than an inflated guess.

    All three queries are bounded by `client_id` so cross-client data
    never leaks even if the bearer token resolves to the wrong client by
    accident.
    """
    async with db.execute(
        """
        SELECT COALESCE(SUM(progress_sec), 0) AS total_seconds
          FROM stream_sessions
         WHERE client_id = ?
        """,
        (client_id,),
    ) as cur:
        row = await cur.fetchone()
    total_seconds = float(row["total_seconds"]) if row else 0.0
    hours = int(total_seconds // 3600)

    async with db.execute(
        """
        SELECT COUNT(DISTINCT s.file_id) AS cnt
          FROM stream_sessions s
          JOIN media_files m ON m.id = s.file_id
          JOIN libraries   l ON l.id = m.library_id
         WHERE s.client_id = ? AND l.type = 'movies'
        """,
        (client_id,),
    ) as cur:
        row = await cur.fetchone()
    movies = int(row["cnt"]) if row else 0

    async with db.execute(
        """
        SELECT COUNT(DISTINCT m.tmdb_show_id) AS cnt
          FROM stream_sessions s
          JOIN media_files m ON m.id = s.file_id
         WHERE s.client_id = ? AND m.tmdb_show_id IS NOT NULL
        """,
        (client_id,),
    ) as cur:
        row = await cur.fetchone()
    shows = int(row["cnt"]) if row else 0

    return {"hours": hours, "movies": movies, "shows": shows}


async def get_file(db: aiosqlite.Connection, file_id: str) -> dict | None:
    async with db.execute("SELECT * FROM media_files WHERE id = ?", (file_id,)) as cur:
        row = await cur.fetchone()
    return dict(row) if row else None


async def delete_file(db: aiosqlite.Connection, file_id: str) -> bool:
    """Remove a file reference from the database."""
    file_info = await get_file(db, file_id)
    if not file_info:
        return False

    await db.execute("DELETE FROM media_files WHERE id = ?", (file_id,))
    await db.commit()
    logger.info("File reference deleted from library: %s", file_id)
    return True


async def scan_library(
    db: aiosqlite.Connection,
    library_id: str,
    tmdb_api_key: str | None = None,
) -> int:
    """Walk root_paths, insert new media files; return count of new files added.

    If *tmdb_api_key* is provided, each newly-added file is enriched with TMDB
    metadata (title, overview, poster_url) on a best-effort basis.

    Runs under a per-library asyncio Lock so a double-clicked Scan button
    or two clients posting `/scan` concurrently can't run the same
    directory walk + INSERT loop + TMDB enrichment twice.  The second
    call waits for the first to finish, then sees no new files and
    returns 0 — much cheaper than the duplicate enrichment storm the
    races used to produce.
    """
    async with _get_scan_lock(library_id):
        return await _scan_library_locked(db, library_id, tmdb_api_key)


async def _scan_library_locked(
    db: aiosqlite.Connection,
    library_id: str,
    tmdb_api_key: str | None,
) -> int:
    row = await get_library(db, library_id)
    if row is None:
        raise ValueError(f"Library not found: {library_id}")

    root_paths: list[str] = row["root_paths"]
    now = datetime.now(UTC).isoformat()
    added = 0
    new_file_ids: list[tuple[str, str]] = []  # (file_id, stem for TMDB query)

    for root in root_paths:
        root_path = Path(root)
        if root_path.is_file():
            candidates = (
                [root_path] if root_path.suffix.lower() in _MEDIA_EXTENSIONS else []
            )
        elif root_path.is_dir():
            # Walk the directory tree safely to avoid Windows symlink/permission crashes
            def safe_walk(start_path):
                import os

                paths = []
                for root_dir, dirs, files in os.walk(start_path, followlinks=False):
                    for f in files:
                        try:
                            p = Path(root_dir) / f
                            if p.is_file() and p.suffix.lower() in _MEDIA_EXTENSIONS:
                                paths.append(p)
                        except Exception:
                            pass
                return paths

            candidates = await asyncio.to_thread(lambda p=root_path: safe_walk(str(p)))
        else:
            logger.warning("Scan root not found: %s", root)
            continue

        for file_path in candidates:
            path_str = str(file_path)
            if not _is_valid_absolute_media_path(path_str):
                logger.warning(
                    "Refusing to ingest media row with invalid path: %r "
                    "(library=%s)",
                    path_str,
                    library_id,
                )
                continue
            async with db.execute(
                "SELECT id FROM media_files WHERE path = ?", (path_str,)
            ) as cur:
                existing = await cur.fetchone()

            if existing:
                continue

            file_id = str(uuid.uuid4())
            try:
                size = await asyncio.to_thread(lambda p=file_path: p.stat().st_size)
            except OSError:
                size = 0

            await db.execute(
                """
                INSERT INTO media_files
                    (id, path, name, extension, size_bytes,
                     library_id, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    file_id,
                    path_str,
                    file_path.name,
                    file_path.suffix.lower(),
                    size,
                    library_id,
                    now,
                    now,
                ),
            )
            added += 1
            new_file_ids.append((file_id, file_path.stem))
            await _persist_probe(db, file_id, file_path)
            if added % 50 == 0:
                await asyncio.sleep(0)

    await db.execute(
        "UPDATE libraries SET last_scanned = ? WHERE id = ?", (now, library_id)
    )
    await db.commit()
    logger.info("Scan complete: library=%s added=%d", library_id, added)

    if added > 0:
        try:
            from services import activity_service

            await activity_service.record(
                db,
                type="library.scan",
                summary=f"Library scan added {added} file(s)",
                actor_kind="system",
                target_kind="library",
                target_id=library_id,
                payload={"files_added": added},
            )
        except Exception:
            logger.warning(
                "Failed to record library.scan activity event", exc_info=True
            )

    # ── TMDB enrichment (best-effort) ──────────────────────────────────────
    if tmdb_api_key and new_file_ids:
        await _enrich_with_tmdb(db, new_file_ids, tmdb_api_key)

    return added


async def _persist_probe(
    db: aiosqlite.Connection, file_id: str, file_path: Path
) -> None:
    """Probe the file via ffprobe and persist width/height/codec/hdr/duration.

    No-op for non-video extensions or when ffprobe returns nothing useful.
    Best-effort — failures are logged and swallowed so they cannot abort a
    library scan.

    ``duration_sec`` is required by the static VOD playlist generator in
    ``ffmpeg_service.start_stream``; without it the mobile/desktop seek bar
    grows segment-by-segment instead of spanning the full file immediately.
    """
    if file_path.suffix.lower() not in _PROBEABLE_EXTENSIONS:
        return
    try:
        info = await probe_video(str(file_path))
    except Exception:
        logger.warning("ffprobe raised for %s", file_path, exc_info=True)
        return
    if info is None:
        return
    await db.execute(
        """
        UPDATE media_files
           SET width = ?, height = ?, codec_name = ?, hdr_format = ?,
               duration_sec = COALESCE(?, duration_sec),
               updated_at = ?
         WHERE id = ?
        """,
        (
            info["width"],
            info["height"],
            info["codec_name"],
            info["hdr_format"],
            info.get("duration_sec"),
            datetime.now(UTC).isoformat(),
            file_id,
        ),
    )


async def backfill_missing_durations(
    db: aiosqlite.Connection, *, batch_size: int = 50, max_rows: int = 5000
) -> int:
    """Probe rows with NULL duration_sec on probeable extensions.

    The static VOD playlist generator in ``ffmpeg_service.start_stream``
    requires ``duration_sec`` to pre-compute the segment list — without
    it the player falls back to FFmpeg's growing playlist and the seek
    bar only spans segments written so far.  Files scanned before the
    probe-writes-duration fix have NULL ``duration_sec``; this runs at
    startup to bring them up to date.

    Iterates in batches of ``batch_size`` so we yield to the event loop
    between probes (each ffprobe spawn is ~100-300ms on Windows).  Caps
    out at ``max_rows`` total updates per invocation so a multi-thousand
    library can't pin the event loop forever on a single startup.

    Returns the count of rows successfully updated.  Best-effort —
    individual probe failures are logged and skipped.
    """
    placeholders = ",".join("?" * len(_PROBEABLE_EXTENSIONS))
    ext_list = list(_PROBEABLE_EXTENSIONS)

    total_updated = 0
    last_seen_id: str | None = None
    while total_updated < max_rows:
        if last_seen_id is None:
            sql = (
                f"SELECT id, path, extension FROM media_files"
                f" WHERE duration_sec IS NULL"
                f"   AND lower(extension) IN ({placeholders})"
                f" ORDER BY id LIMIT ?"
            )
            params = [*ext_list, batch_size]
        else:
            # Keyset pagination on `id` — avoids re-fetching the same
            # rows when a probe failed to fill duration_sec (e.g.
            # ffprobe missing, file unreadable).  Without this, those
            # rows would loop forever.
            sql = (
                f"SELECT id, path, extension FROM media_files"
                f" WHERE duration_sec IS NULL"
                f"   AND lower(extension) IN ({placeholders})"
                f"   AND id > ?"
                f" ORDER BY id LIMIT ?"
            )
            params = [*ext_list, last_seen_id, batch_size]
        async with db.execute(sql, params) as cur:
            rows = await cur.fetchall()
        if not rows:
            break

        for r in rows:
            last_seen_id = r["id"]
            path = Path(r["path"])
            if not path.is_file():
                continue
            try:
                await _persist_probe(db, r["id"], path)
                total_updated += 1
            except Exception:
                logger.warning(
                    "Duration backfill probe raised for id=%s",
                    r["id"],
                    exc_info=True,
                )
            await asyncio.sleep(0)

        await db.commit()

    return total_updated


async def _enrich_with_tmdb(
    db: aiosqlite.Connection,
    file_stems: list[tuple[str, str]],
    api_key: str,
) -> None:
    """Query TMDB for each (file_id, stem) pair and persist metadata.

    Stems matching the DVR / capture-card naming convention (a
    YYYY.MM.DD or YYYY-MM-DD date component anywhere in the name) are
    skipped without an HTTP call — TMDB never matches these and the
    log was filling with `0/N files updated` lines during library
    indexing of capture archives.
    """
    svc = TmdbService(api_key)
    enriched = 0
    skipped_dvr = 0

    for file_id, stem in file_stems:
        # Yield to event loop regularly to avoid starving other coroutines
        await asyncio.sleep(0)

        if _looks_like_dvr_capture(stem):
            skipped_dvr += 1
            continue

        meta = await svc.search(stem)
        if meta is None:
            continue

        await db.execute(
            """
            UPDATE media_files
            SET tmdb_id = ?, title = ?, overview = ?, poster_url = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                meta.tmdb_id,
                meta.title,
                meta.overview,
                meta.poster_url,
                datetime.now(UTC).isoformat(),
                file_id,
            ),
        )
        enriched += 1

    if enriched:
        await db.commit()
    logger.info(
        "TMDB enrichment done: %d/%d files updated (%d skipped as DVR captures)",
        enriched,
        len(file_stems),
        skipped_dvr,
    )


async def upload_file_to_library(
    db: aiosqlite.Connection,
    library_id: str,
    file: UploadFile,
    tmdb_api_key: str | None = None,
) -> dict:
    """Uploads a file to the first root path of a library and inserts it into the DB."""
    row = await get_library(db, library_id)
    if row is None:
        raise ValueError(f"Library not found: {library_id}")

    root_paths = row["root_paths"]
    if not root_paths:
        raise ValueError("Library has no root paths configured.")

    # Defensive — `get_library` parses the JSON-encoded root_paths column
    # before returning, but a buggy code path in 2026-04 once handed
    # through the raw JSON string, causing `root_paths[0]` to return the
    # literal `[` character.  The resulting `Path('[') / filename` was
    # written to the DB with a corrupt path that FFmpeg later refused to
    # open.  This guard makes that failure mode loud rather than silent.
    if not isinstance(root_paths, list) or not all(
        isinstance(p, str) for p in root_paths
    ):
        raise ValueError(
            "Library root_paths is malformed; expected list[str], got "
            f"{type(root_paths).__name__}.  Refusing to upload."
        )

    target_dir = Path(root_paths[0])
    if not target_dir.is_absolute():
        raise ValueError(
            f"Library root_paths[0] is not absolute: {root_paths[0]!r}.  "
            "Refusing to upload."
        )
    target_dir.mkdir(parents=True, exist_ok=True)

    if not file.filename:
        raise ValueError("No filename provided in upload.")

    # Strip any directory components from the filename to prevent path traversal.
    safe_name = Path(file.filename).name
    if not safe_name or safe_name in (".", ".."):
        raise ValueError("Invalid filename.")

    file_path = target_dir / safe_name
    # Canonicalise and confirm the resolved path stays inside target_dir.
    try:
        file_path.resolve().relative_to(target_dir.resolve())
    except ValueError:
        raise ValueError("Invalid filename: path traversal detected.")
    path_str = str(file_path)
    if not _is_valid_absolute_media_path(path_str):
        raise ValueError(
            f"Constructed upload path failed validation: {path_str!r}."
        )

    # Save the file to disk
    def _save_file():
        with file_path.open("wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

    await asyncio.to_thread(_save_file)

    # Check if exists
    async with db.execute(
        "SELECT id FROM media_files WHERE path = ?", (path_str,)
    ) as cur:
        existing = await cur.fetchone()

    now = datetime.now(UTC).isoformat()
    if existing:
        file_id = existing[0]
        # Update size and updated_at
        try:
            size = await asyncio.to_thread(lambda p=file_path: p.stat().st_size)
        except OSError:
            size = 0

        await db.execute(
            """
            UPDATE media_files
            SET size_bytes = ?, updated_at = ?
            WHERE id = ?
            """,
            (size, now, file_id),
        )
        await db.commit()
    else:
        file_id = str(uuid.uuid4())
        try:
            size = await asyncio.to_thread(lambda p=file_path: p.stat().st_size)
        except OSError:
            size = 0

        await db.execute(
            """
            INSERT INTO media_files
                (id, path, name, extension, size_bytes,
                 library_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                file_id,
                path_str,
                file_path.name,
                file_path.suffix.lower(),
                size,
                library_id,
                now,
                now,
            ),
        )
        await db.commit()

        await _persist_probe(db, file_id, file_path)
        await db.commit()

        # Best-effort TMDB enrichment
        if tmdb_api_key:
            await _enrich_with_tmdb(db, [(file_id, file_path.stem)], tmdb_api_key)

    result = await get_file(db, file_id)
    if result is None:
        raise RuntimeError(f"Failed to retrieve uploaded file record: {file_id}")
    return result
