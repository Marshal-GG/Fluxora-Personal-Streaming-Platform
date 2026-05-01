import asyncio
import json
import logging
import shutil
import uuid
from datetime import UTC, datetime
from pathlib import Path

import aiosqlite
from fastapi import UploadFile

from services.tmdb_service import TmdbService

logger = logging.getLogger(__name__)

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


async def list_libraries(db: aiosqlite.Connection) -> list[dict]:
    async with db.execute("SELECT * FROM libraries ORDER BY created_at") as cur:
        rows = await cur.fetchall()

    result = []
    for row in rows:
        async with db.execute(
            "SELECT COUNT(*) FROM media_files WHERE library_id = ?", (row["id"],)
        ) as count_cur:
            count_row = await count_cur.fetchone()
        file_count = count_row[0] if count_row else 0

        lib_dict = dict(row)
        if "root_paths" in lib_dict and isinstance(lib_dict["root_paths"], str):
            lib_dict["root_paths"] = json.loads(lib_dict["root_paths"])
        result.append({**lib_dict, "file_count": file_count})
    return result


async def get_library(db: aiosqlite.Connection, library_id: str) -> dict | None:
    async with db.execute("SELECT * FROM libraries WHERE id = ?", (library_id,)) as cur:
        row = await cur.fetchone()
    if row is None:
        return None

    async with db.execute(
        "SELECT COUNT(*) FROM media_files WHERE library_id = ?", (library_id,)
    ) as count_cur:
        count_row = await count_cur.fetchone()
    file_count = count_row[0] if count_row else 0
    lib_dict = dict(row)
    if "root_paths" in lib_dict and isinstance(lib_dict["root_paths"], str):
        lib_dict["root_paths"] = json.loads(lib_dict["root_paths"])
    return {**lib_dict, "file_count": file_count}


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
    """
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


async def _enrich_with_tmdb(
    db: aiosqlite.Connection,
    file_stems: list[tuple[str, str]],
    api_key: str,
) -> None:
    """Query TMDB for each (file_id, stem) pair and persist metadata."""
    svc = TmdbService(api_key)
    enriched = 0

    for file_id, stem in file_stems:
        # Yield to event loop regularly to avoid starving other coroutines
        await asyncio.sleep(0)

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
    logger.info("TMDB enrichment done: %d/%d files updated", enriched, len(file_stems))


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

    root_paths: list[str] = row["root_paths"]
    if not root_paths:
        raise ValueError("Library has no root paths configured.")

    target_dir = Path(root_paths[0])
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

        # Best-effort TMDB enrichment
        if tmdb_api_key:
            await _enrich_with_tmdb(db, [(file_id, file_path.stem)], tmdb_api_key)

    result = await get_file(db, file_id)
    if result is None:
        raise RuntimeError(f"Failed to retrieve uploaded file record: {file_id}")
    return result
