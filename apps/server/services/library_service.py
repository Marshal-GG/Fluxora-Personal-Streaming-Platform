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

from services.ffmpeg_service import _probe_audio_tracks, probe_video
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


# Whitespace collapse for the cleaned query — a single regex matches
# any run of one-or-more whitespace characters.
_WHITESPACE_RUN = re.compile(r"\s+")

# Known torrent-scene quality / source / codec / encoder tokens.
# Used to strip the trailing metadata block from filenames like
# ``Inception.2010.1080p.BluRay.x264.AAC``.  Conservative — only
# tokens we've seen in real Fluxora installs.  Over-listing risks
# eating content that's part of a legitimate title.
_SCENE_NOISE_TOKENS = (
    # Resolution / quality
    r"1080p|2160p|720p|480p|4k|"
    # Source
    r"bluray|blu-?ray|brrip|webrip|web-?dl|hdrip|dvdrip|hdtv|"
    # Video codec
    r"x264|x265|h\.?264|h\.?265|hevc|av1|xvid|"
    # Release tag
    r"repack|proper|extended|"
    # HDR / dynamic range
    r"hdr|hdr10|dv|"
    # Audio codec
    r"ac3|aac|dts|atmos|truehd"
)

# Trailing scene-noise stripper.  Matches a 4-digit year (1900-2099),
# optionally wrapped in ``()`` / ``[]`` and/or preceded by a ``-``,
# followed by zero or more known scene-noise tokens, all the way to
# the end of the cleaned query.  Year alone with no following tokens
# is also stripped (the simple ``Title YYYY`` case).  Field-confirmed
# against ``Harry Potter and the Half Blood Prince 2009`` returning
# zero TMDB matches with the year, one match without.
#
# The pattern intentionally does NOT match a mid-string year that's
# followed by ordinary text (e.g. ``Blade Runner 2049 sequel notes``)
# — the year-and-after must run cleanly to end-of-string before the
# strip fires, so legitimate titles containing a year are preserved.
_TRAILING_SCENE_NOISE = re.compile(
    # Allow whitespace inside the bracket group so ``Inception - 2010``
    # (dash + space + year) and ``Inception ( 2010 )`` both match.
    r"\s*[-([\s]*\b(?:19|20)\d{2}\b[)\]\s]*"
    rf"(?:\s+(?:{_SCENE_NOISE_TOKENS}))*"
    r"\s*$",
    re.IGNORECASE,
)


def _clean_tmdb_query(stem: str) -> str:
    """Normalise a filename stem into a TMDB-friendly search query.

    Field-observed problems with raw stems:

    - **Underscores instead of spaces** —
      ``Harry_Potter_and_the_Half_Blood_Prince_2009`` returned no TMDB
      match because the search engine doesn't tokenise across ``_``.
      ``Harry Potter and the Half Blood Prince`` matches first try.
    - **Dot-separated words** — ``Inception.2010.1080p.BluRay`` is
      common from torrent-scene naming.  Same fix: dots → spaces.
    - **Trailing release year + scene metadata** — TMDB's fuzzy
      ``?query=`` treats every word as a content keyword that must
      appear in the title/overview.  Movies don't have their release
      year, resolution, or codec in the title, so leaving those
      tokens in the query poisons the match.  Stripped here via
      ``_TRAILING_SCENE_NOISE``; legitimate titles containing a
      year (Blade Runner 2049, 2001 A Space Odyssey) are preserved
      because the strip only fires when year-and-after runs cleanly
      to end-of-string.
    - **Multiple spaces / leading-trailing whitespace** after the
      substitutions; collapsed to single spaces with ``_WHITESPACE_RUN``.
    """
    cleaned = stem.replace("_", " ").replace(".", " ")
    cleaned = _TRAILING_SCENE_NOISE.sub("", cleaned)
    return _WHITESPACE_RUN.sub(" ", cleaned).strip()


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

    Validation is **platform-agnostic** — a Linux server may legitimately
    receive Windows-style paths in the DB (cross-platform DB replication,
    library row originating from a Windows install) and the validator
    must accept them.  `os.path.isabs` is OS-specific (False for `C:\\…`
    on Linux), so it's replaced by an explicit prefix check that accepts
    both Unix (`/…`) and Windows (`C:\\…` or `C:/…`, drive letter + sep)
    absolute forms.
    """
    if not path_str or not path_str.strip():
        return False
    if path_str.startswith("[") or "\x00" in path_str:
        return False
    # Unix-style absolute path.
    if path_str.startswith("/"):
        return True
    # Windows-style absolute path: drive letter + colon + separator.
    if (
        len(path_str) >= 3
        and path_str[0].isalpha()
        and path_str[1] == ":"
        and path_str[2] in ("\\", "/")
    ):
        return True
    return False


_MEDIA_EXTENSIONS = {
    # Video — FFmpeg frame extraction for thumbnails.
    ".mp4",
    ".mkv",
    ".avi",
    ".mov",
    ".wmv",
    ".flv",
    ".webm",
    ".m4v",
    ".mpg",
    ".mpeg",
    ".ts",
    ".3gp",
    # Audio — FFmpeg APIC extraction for embedded album art thumbnails.
    ".mp3",
    ".flac",
    ".aac",
    ".wav",
    ".ogg",
    ".opus",
    ".m4a",
    # Images — FFmpeg image input for direct thumbnail rendering.
    # Matches the kinds Windows Explorer auto-thumbnails on first scan
    # so a library walk picks them up without manual indexing.
    ".jpg",
    ".jpeg",
    ".png",
    ".gif",
    ".bmp",
    ".tiff",
    ".tif",
    ".webp",
    ".heic",
    ".heif",
    ".ico",
    # JPEG XR / HD Photo (.jxr) — NVIDIA GeForce Experience HDR
    # screenshots.  Thumbnails extracted via Windows WIC since
    # FFmpeg can't decode JXR.
    ".jxr",
    # Documents — PyMuPDF first-page extraction for PDFs; cover-page
    # for the e-book / comic formats falls back to the kind icon if
    # the extractor can't reach inside the container.
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

    `cover_urls` is up to 4 covers for the library card.  TMDB poster
    URLs come first (real art > extracted frame); if fewer than 4 TMDB
    posters exist for the library, the remaining slots are filled by
    server-relative thumbnail URLs of the form
    ``/api/v1/files/<file_id>/thumbnail?v=<gen_unix>`` so a half-
    enriched library still renders a populated mosaic.

    The ``?v=`` suffix is a cache-buster — the endpoint ignores it, but
    when a thumbnail is regenerated ``generated_at`` shifts so the URL
    changes and the client image cache invalidates.

    Plan 27: TMDB-first union with media_thumbnails 'ready' rows.
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

    # Per-library TMDB toggle: when disabled, skip the poster_url pass
    # entirely + don't exclude TMDB-having files from the thumbnail
    # pass.  Hides any persisted TMDB art without dropping the rows
    # from the DB, so flipping the toggle back on restores the mosaic
    # without re-fetching anything from TMDB.
    tmdb_enabled = await _is_tmdb_enabled(db, library_id)

    cover_urls: list[str] = []
    if tmdb_enabled:
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

    # Plan 27: fill any remaining slots from generated thumbnails.
    # When TMDB is enabled, exclude files that already have a TMDB
    # poster_url so we don't show duplicate art (TMDB + extracted frame
    # from the same file).  When TMDB is disabled, take every file with
    # a ready thumbnail regardless of its poster_url column.
    needed = 4 - len(cover_urls)
    if needed > 0:
        poster_filter = (
            " AND (mf.poster_url IS NULL OR mf.poster_url = '')"
            if tmdb_enabled
            else ""
        )
        async with db.execute(
            f"""
            SELECT mf.id AS file_id,
                   CAST(strftime('%s', t.generated_at) AS INTEGER) AS gen_unix
              FROM media_files mf
              JOIN media_thumbnails t ON t.file_id = mf.id
             WHERE mf.library_id = ?
               AND t.status = 'ready'
               {poster_filter}
             ORDER BY t.generated_at DESC
             LIMIT ?
            """,
            (library_id, needed),
        ) as cur:
            thumb_rows = await cur.fetchall()
        cover_urls.extend(
            f"/api/v1/files/{r['file_id']}/thumbnail?v={r['gen_unix'] or 0}"
            for r in thumb_rows
        )

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


# Sentinel for tri-state PATCH — distinguishes "kwarg omitted" from
# "kwarg explicitly set to None".  Mirrors the router's ``_UNSET`` so
# both layers can speak the same shape.
_UNSET: object = object()


async def update_library(
    db: aiosqlite.Connection,
    library_id: str,
    *,
    name: str | None = None,
    root_paths: list[str] | None = None,
    av1_stream_copy_override: object = _UNSET,
    vp9_stream_copy_override: object = _UNSET,
    tmdb_enabled: object = _UNSET,
) -> dict | None:
    """Partial update of a library. Returns the refreshed row or None if not found.

    Plan 19 §M8 — the two ``<codec>_stream_copy_override`` kwargs are
    tri-state: ``_UNSET`` (default) means "don't touch", ``None``
    explicitly clears the override (inherit global), and ``True`` /
    ``False`` pin the behaviour for this library.

    Migration 040 — ``tmdb_enabled`` is two-state (bool) but uses the
    same ``_UNSET`` sentinel so omitting it means "don't touch."
    """
    has_av1_override = av1_stream_copy_override is not _UNSET
    has_vp9_override = vp9_stream_copy_override is not _UNSET
    has_tmdb_toggle = tmdb_enabled is not _UNSET
    if (
        name is None
        and root_paths is None
        and not has_av1_override
        and not has_vp9_override
        and not has_tmdb_toggle
    ):
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
    if has_av1_override:
        sets.append("av1_stream_copy_override = ?")
        params.append(
            None
            if av1_stream_copy_override is None
            else int(bool(av1_stream_copy_override))
        )
    if has_vp9_override:
        sets.append("vp9_stream_copy_override = ?")
        params.append(
            None
            if vp9_stream_copy_override is None
            else int(bool(vp9_stream_copy_override))
        )
    if has_tmdb_toggle:
        sets.append("tmdb_enabled = ?")
        params.append(int(bool(tmdb_enabled)))

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
    *,
    tmdb_enabled: bool = True,
) -> dict:
    library_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    paths_json = json.dumps(root_paths)

    await db.execute(
        """
        INSERT INTO libraries
            (id, name, type, root_paths, created_at, tmdb_enabled)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (library_id, name, lib_type, paths_json, now, int(tmdb_enabled)),
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
        "tmdb_enabled": int(tmdb_enabled),
    }


async def delete_library(
    db: aiosqlite.Connection,
    library_id: str,
    *,
    delete_sidecars: bool = True,
) -> bool:
    """Delete a library and (by default) its produced H.264 sidecars.

    Plan 19 §M8 — ``delete_sidecars=True`` (default) unlinks every
    on-disk transcoded sidecar belonging to the library before the
    row + CASCADE drops.  Best-effort: file-level errors are logged
    and skipped — a single read-only mount shouldn't block the
    operator from removing the library.

    Pass ``delete_sidecars=False`` to preserve the cache (e.g. when
    the operator plans to reattach the cache to a renamed library
    or relocate it).
    """
    async with db.execute(
        "SELECT id FROM libraries WHERE id = ?", (library_id,)
    ) as cur:
        if await cur.fetchone() is None:
            return False

    if delete_sidecars:
        async with db.execute(
            "SELECT transcoded_path FROM media_files"
            " WHERE library_id = ? AND transcoded_path IS NOT NULL",
            (library_id,),
        ) as cur:
            rows = await cur.fetchall()
        removed = 0
        for r in rows:
            sidecar = r["transcoded_path"]
            if not sidecar:
                continue
            try:
                p = Path(sidecar)
                p.unlink()
                removed += 1
            except FileNotFoundError:
                continue
            except OSError:
                logger.warning(
                    "delete_library: could not unlink sidecar %s",
                    sidecar,
                    exc_info=True,
                )
        if removed:
            logger.info(
                "delete_library: removed %d sidecar(s) for library %s",
                removed,
                library_id,
            )

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
    return await _apply_tmdb_mask(db, [dict(row) for row in rows])


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
    return await _apply_tmdb_mask(db, [dict(row) for row in rows])


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
    return await _apply_tmdb_mask(db, [dict(row) for row in rows])


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
    return await _apply_tmdb_mask(db, [dict(row) for row in rows])


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
    if row is None:
        return None
    masked = await _apply_tmdb_mask(db, [dict(row)])
    return masked[0]


async def delete_file(db: aiosqlite.Connection, file_id: str) -> bool:
    """Remove a file reference from the database."""
    file_info = await get_file(db, file_id)
    if not file_info:
        return False

    await db.execute("DELETE FROM media_files WHERE id = ?", (file_id,))
    await db.commit()
    logger.info("File reference deleted from library: %s", file_id)
    return True


def _sql_like_escape(value: str) -> str:
    """Escape `%`, `_`, and `|` so the result is safe inside a SQLite
    `LIKE ... ESCAPE '|'` pattern.  Used by [unindex_subtree] to build
    a prefix-match pattern that doesn't accidentally collide with
    real path characters."""
    return value.replace("|", "||").replace("%", "|%").replace("_", "|_")


async def unindex_subtree(
    db: aiosqlite.Connection,
    *,
    library_id: str,
    subtree_abs: Path,
) -> int:
    """Remove every `media_files` row whose path sits under [subtree_abs].

    Returns the count of removed rows.  Cascades to `media_thumbnails`
    (`ON DELETE CASCADE`); thumbnail JPEGs on disk are picked up by the
    orphan sweeper that already runs every 6 h, so callers don't need
    to walk the disk.  Files on disk are NOT deleted — this is purely a
    catalog operation, mirroring "Index this file" in reverse.

    Caller is responsible for resolving the path against the library's
    roots + containment.  Backs the right-click "Unindex this folder"
    action.
    """
    subtree_str = str(subtree_abs)
    sep = os.sep
    # Match: the subtree itself + any file whose path begins with
    # `<subtree><sep>`.  Escape `%` / `_` / `|` so paths containing
    # those characters don't shift the LIKE match.
    pattern = _sql_like_escape(subtree_str + sep) + "%"

    cur = await db.execute(
        "DELETE FROM media_files"
        " WHERE library_id = ?"
        "   AND (path = ? OR path LIKE ? ESCAPE '|')",
        (library_id, subtree_str, pattern),
    )
    removed = cur.rowcount or 0
    await cur.close()
    await db.commit()
    if removed:
        logger.info(
            "Unindexed %d file(s) under %s (library %s)",
            removed,
            subtree_str,
            library_id,
        )
    return removed


async def scan_library(
    db: aiosqlite.Connection,
    library_id: str,
    tmdb_api_key: str | None = None,
    subtree_abs: str | None = None,
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

    When *subtree_abs* is provided, the walk is constrained to that
    absolute directory (which the caller has already validated to live
    under one of the library's `root_paths` — see
    `browse_service.resolve_subtree_for_scan`).  Backs the right-click
    "Scan this folder" action so the operator can rescan a single
    subdir without paying for a full library walk.
    """
    async with _get_scan_lock(library_id):
        return await _scan_library_locked(
            db, library_id, tmdb_api_key, subtree_abs
        )


async def _scan_library_locked(
    db: aiosqlite.Connection,
    library_id: str,
    tmdb_api_key: str | None,
    subtree_abs: str | None = None,
) -> int:
    row = await get_library(db, library_id)
    if row is None:
        raise ValueError(f"Library not found: {library_id}")

    if subtree_abs is not None:
        # Subtree mode: walk just the operator-selected directory.  The
        # caller has already enforced containment under root_paths.
        root_paths: list[str] = [subtree_abs]
    else:
        root_paths = row["root_paths"]
    now = datetime.now(UTC).isoformat()
    added = 0
    new_file_ids: list[tuple[str, str]] = []  # (file_id, stem for TMDB query)

    for root in root_paths:
        root_path = Path(root)
        if root_path.is_file():
            # Single-file library root — index it unconditionally.
            # Extension-based filtering used to live here; removed
            # so every file in the operator's library is reachable
            # from the mobile catalog views (which are keyed on
            # `file_id`, set only at scan time).  Thumbnails for
            # non-media kinds are still skipped cleanly by the
            # worker; ffprobe is gated by `_PROBEABLE_EXTENSIONS`
            # inside `_persist_probe`.
            candidates = [root_path]
        elif root_path.is_dir():
            # Walk the directory tree safely to avoid Windows symlink/permission crashes
            def safe_walk(start_path):
                import os

                paths = []
                for root_dir, dirs, files in os.walk(start_path, followlinks=False):
                    for f in files:
                        try:
                            p = Path(root_dir) / f
                            if p.is_file():
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
                "SELECT id, library_id, transcoded_path,"
                "       transcoded_source_mtime"
                "  FROM media_files WHERE path = ?",
                (path_str,),
            ) as cur:
                existing = await cur.fetchone()

            if existing:
                # Re-claim orphaned rows whose owner library was
                # deleted (`media_files.library_id` is `ON DELETE
                # SET NULL`, so a delete+recreate of the same root
                # leaves rows with `library_id IS NULL` that the
                # path-lookup above would otherwise skip — the
                # operator's re-scan would silently appear to add
                # nothing).  Only re-claim when the existing row is
                # actually orphaned; rows owned by another library
                # are left alone (overlapping roots are rare but
                # legal).
                if existing["library_id"] is None:
                    # Refresh `created_at` on re-claim so the
                    # operator-facing "added" date matches when they
                    # re-attached the library, not the stale first-
                    # scan date 9 days ago.  TMDB / resume / sidecar
                    # metadata stays intact (only the timestamp +
                    # ownership change).
                    await db.execute(
                        "UPDATE media_files"
                        "   SET library_id = ?,"
                        "       created_at = ?,"
                        "       updated_at = ?"
                        " WHERE id = ?",
                        (library_id, now, now, existing["id"]),
                    )
                    logger.info(
                        "library scan: re-claimed orphan %s for library %s",
                        path_str,
                        library_id,
                    )
                # Plan 19 §M6 — stale-sidecar detection.  If the
                # source has been overwritten since the sidecar was
                # produced (mtime advance), clear `transcoded_path`
                # so the next play uses the fresh source.  The on-
                # disk sidecar is left in place; the operator can
                # decide whether to clean up via the History tab.
                if (
                    existing["transcoded_path"] is not None
                    and existing["transcoded_source_mtime"] is not None
                ):
                    try:
                        current_mtime = int(file_path.stat().st_mtime)
                    except OSError:
                        current_mtime = None
                    if current_mtime is not None and current_mtime > int(
                        existing["transcoded_source_mtime"]
                    ):
                        await db.execute(
                            "UPDATE media_files SET transcoded_path = NULL"
                            " WHERE id = ?",
                            (existing["id"],),
                        )
                        logger.info(
                            "library scan: cleared stale sidecar for %s "
                            "(source mtime advanced %s -> %s)",
                            path_str,
                            existing["transcoded_source_mtime"],
                            current_mtime,
                        )
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
            # Best-effort enqueue for thumbnail generation.  The worker
            # pool consumes the queue asynchronously; this is a single
            # INSERT OR IGNORE — no FFmpeg in the scan path.
            #
            # Gate on `kind_for_extension(suffix)`: files with no
            # extractor (subtitles, archives, text, source files, etc.)
            # would otherwise sit in the queue, get claimed, and be
            # marked `skipped` — pure wasted I/O on libraries with lots
            # of non-media files.  Skip the enqueue entirely; the UI
            # treats "no thumbnail row" identically to "skipped row"
            # for display purposes (both render as kind icon + no
            # thumb).
            try:
                from services import thumbnail_service, thumbnail_worker

                if thumbnail_service.kind_for_extension(
                    file_path.suffix or ""
                ) is not None:
                    await thumbnail_worker.enqueue(db, file_id)
            except Exception:
                logger.warning(
                    "thumbnail enqueue failed for %s", file_id, exc_info=True
                )
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
    if (
        tmdb_api_key
        and new_file_ids
        and await _is_tmdb_enabled(db, library_id)
    ):
        await _enrich_with_tmdb(db, new_file_ids, tmdb_api_key)

    return added


async def _persist_probe(
    db: aiosqlite.Connection, file_id: str, file_path: Path
) -> None:
    """Probe the file via ffprobe and persist width/height/codec/hdr/duration
    plus the full audio-track list (plan 22 M2).

    No-op for non-video extensions or when ffprobe returns nothing useful.
    Best-effort — failures are logged and swallowed so they cannot abort a
    library scan.

    ``duration_sec`` is required by the static VOD playlist generator in
    ``ffmpeg_service.start_stream``; without it the mobile/desktop seek bar
    grows segment-by-segment instead of spanning the full file immediately.

    ``audio_tracks`` is a JSON-encoded list of per-track metadata produced
    by ``ffmpeg_service._probe_audio_tracks``.  The column is set to NULL
    when the probe returns ``[]`` (ffprobe failure / no audio streams) so
    that the ``/stream/start`` router's lazy-backfill path (plan 22 M3)
    can distinguish "never probed" from "probed and found nothing".  Two
    ffprobe subprocesses run per probeable file at scan time — the video
    probe (``probe_video``) and the audio-tracks probe; merging them is a
    plan-22-follow-up if scan latency becomes a problem.
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

    try:
        audio_tracks = await _probe_audio_tracks(str(file_path))
    except Exception:
        # _probe_audio_tracks already swallows ffprobe failures and
        # returns []; the try/except here is belt-and-braces against
        # an unforeseen synchronous raise (e.g. permission error
        # building the argv) and matches the swallow-and-log
        # discipline of the video-probe path immediately above.
        logger.warning("audio-track ffprobe raised for %s", file_path, exc_info=True)
        audio_tracks = []
    audio_tracks_json = json.dumps(audio_tracks) if audio_tracks else None

    await db.execute(
        """
        UPDATE media_files
           SET width = ?, height = ?, codec_name = ?, hdr_format = ?,
               duration_sec = COALESCE(?, duration_sec),
               audio_tracks = ?,
               updated_at = ?
         WHERE id = ?
        """,
        (
            info["width"],
            info["height"],
            info["codec_name"],
            info["hdr_format"],
            info.get("duration_sec"),
            audio_tracks_json,
            datetime.now(UTC).isoformat(),
            file_id,
        ),
    )


async def index_single_file(
    db: aiosqlite.Connection,
    *,
    library_id: str,
    absolute_path: Path,
    tmdb_api_key: str | None = None,
) -> dict:
    """Insert a single `media_files` row for *absolute_path*.

    Returns ``{file_id, already_indexed: bool, enriched: bool}``.  When
    the file already lives in `media_files` the existing row's id is
    returned with ``already_indexed=True`` and no further work is done.

    Caller is responsible for path resolution + containment.  Backs
    `POST /library/{id}/index-file?path=<relative>` (the right-click
    "Index this file" action).

    Best-effort TMDB enrichment when *tmdb_api_key* is set + the
    filename stem doesn't look like a DVR capture.  ffprobe metadata
    runs inline; thumbnail extraction is enqueued (worker picks up).
    """
    path_str = str(absolute_path)
    if not _is_valid_absolute_media_path(path_str):
        raise ValueError(f"invalid media path: {path_str!r}")

    # Idempotency check.  An already-indexed file just returns its id;
    # the operator sees the row flip to indexed and the menu reshuffles.
    async with db.execute(
        "SELECT id, library_id FROM media_files WHERE path = ?",
        (path_str,),
    ) as cur:
        existing = await cur.fetchone()
    if existing is not None:
        # Re-claim orphan rows whose owner library was deleted (matches
        # scan_library's behaviour).
        now = datetime.now(UTC).isoformat()
        if existing["library_id"] is None:
            await db.execute(
                "UPDATE media_files"
                "   SET library_id = ?, created_at = ?, updated_at = ?"
                " WHERE id = ?",
                (library_id, now, now, existing["id"]),
            )
            await db.commit()
        return {
            "file_id": existing["id"],
            "already_indexed": True,
            "enriched": False,
        }

    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    try:
        size = await asyncio.to_thread(
            lambda p=absolute_path: p.stat().st_size
        )
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
            absolute_path.name,
            absolute_path.suffix.lower(),
            size,
            library_id,
            now,
            now,
        ),
    )
    await _persist_probe(db, file_id, absolute_path)

    # Thumbnail enqueue — priority=10 so the operator sees the result
    # before unrelated pending rows from a recent scan.  Gated on
    # `kind_for_extension`: text / subtitle / archive / source files
    # have no extractor and would just be marked `skipped` by the
    # worker — saving the round-trip when the operator indexes them.
    try:
        from services import thumbnail_service, thumbnail_worker

        if thumbnail_service.kind_for_extension(
            absolute_path.suffix or ""
        ) is not None:
            await thumbnail_worker.enqueue(db, file_id, priority=10)
    except Exception:
        logger.warning(
            "thumbnail enqueue failed for %s", file_id, exc_info=True
        )

    enriched = False
    if (
        tmdb_api_key
        and not _looks_like_dvr_capture(absolute_path.stem)
        and await _is_tmdb_enabled(db, library_id)
    ):
        try:
            n = await _enrich_with_tmdb(
                db, [(file_id, absolute_path.stem)], tmdb_api_key
            )
            enriched = n > 0
        except Exception:
            logger.warning(
                "TMDB enrichment failed for %s", file_id, exc_info=True
            )

    await db.commit()
    logger.info(
        "Indexed single file: library=%s file_id=%s enriched=%s",
        library_id,
        file_id,
        enriched,
    )
    return {
        "file_id": file_id,
        "already_indexed": False,
        "enriched": enriched,
    }


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


# Columns that come from TMDB enrichment.  Masked out of `media_files`
# rows whose library has `tmdb_enabled=0` so the operator's "turn off
# TMDB" toggle hides this metadata across every API surface without
# the read path having to know about each route individually.
_TMDB_MASKED_FIELDS: tuple[str, ...] = (
    "tmdb_id",
    "title",
    "overview",
    "poster_url",
    "tmdb_show_id",
    "season_number",
    "episode_number",
)


async def _apply_tmdb_mask(
    db: aiosqlite.Connection, rows: list[dict]
) -> list[dict]:
    """In-place null-out of TMDB-derived columns on rows whose library
    has `tmdb_enabled=0`.  Non-destructive — the DB still has the
    values; this masking is purely a response-shape concern so the
    operator's per-library toggle can hide existing TMDB data without
    a destructive wipe.  Re-enabling the library brings everything
    back instantly on the next list/get call.

    One batched SQL query covers all distinct `library_id`s in the
    input rows.  Safe to call with rows that lack `library_id` (e.g.
    orphan files) — those are returned untouched.
    """
    if not rows:
        return rows
    library_ids = {r["library_id"] for r in rows if r.get("library_id")}
    if not library_ids:
        return rows
    placeholders = ",".join("?" for _ in library_ids)
    async with db.execute(
        f"SELECT id, tmdb_enabled FROM libraries WHERE id IN ({placeholders})",
        tuple(library_ids),
    ) as cur:
        lib_rows = await cur.fetchall()
    disabled = {
        r["id"]
        for r in lib_rows
        if not (r["tmdb_enabled"] is None or r["tmdb_enabled"])
    }
    if not disabled:
        return rows
    for r in rows:
        if r.get("library_id") in disabled:
            for f in _TMDB_MASKED_FIELDS:
                if f in r:
                    r[f] = None
    return rows


async def _is_tmdb_enabled(
    db: aiosqlite.Connection, library_id: str
) -> bool:
    """Return the per-library TMDB toggle (migration 040).

    Defaults to True for any library row whose `tmdb_enabled` column
    is missing (pre-migration row) or 1.  Returns False only when the
    operator has explicitly disabled TMDB for this library.  Used by
    every enrichment site to gate `_enrich_with_tmdb` and by the read
    path (`_library_aggregates` / `_attach_index_status`) to mask
    already-persisted TMDB columns.
    """
    async with db.execute(
        "SELECT tmdb_enabled FROM libraries WHERE id = ?", (library_id,)
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        # Unknown library — be conservative + allow.  Caller's own
        # library_id validation handles the "should this even run"
        # question; we only own the toggle gate.
        return True
    val = row["tmdb_enabled"]
    return val is None or bool(val)


async def _enrich_with_tmdb(
    db: aiosqlite.Connection,
    file_stems: list[tuple[str, str]],
    api_key: str,
    *,
    skip_dvr: bool = True,
) -> int:
    """Query TMDB for each (file_id, stem) pair and persist metadata.

    Returns the number of files actually enriched (got a TMDB hit AND
    DB row was updated).

    Stems matching the DVR / capture-card naming convention (a
    YYYY.MM.DD or YYYY-MM-DD date component anywhere in the name) are
    skipped by default — TMDB never matches these and the log was
    filling with `0/N files updated` lines during library indexing of
    capture archives.  Pass ``skip_dvr=False`` to opt into searching
    capture-style filenames anyway (e.g. when the user manually
    triggers a TMDB rescan from the desktop UI for a library that
    happens to mix capture archives with real media).

    The TMDB base URLs are read from ``settings.fluxora_tmdb_base_url``
    / ``settings.fluxora_tmdb_image_base_url`` so an operator on a
    network that blocks ``api.themoviedb.org`` can route through their
    own Cloudflare Worker (or similar reverse proxy).  Empty values
    fall back to the canonical TMDB URLs.
    """
    from config import settings

    svc = TmdbService(
        api_key,
        base_url=settings.fluxora_tmdb_base_url or None,
        poster_base_url=settings.fluxora_tmdb_image_base_url or None,
    )
    enriched = 0
    skipped_dvr = 0

    for file_id, stem in file_stems:
        # Yield to event loop regularly to avoid starving other coroutines
        await asyncio.sleep(0)

        # DVR pattern check runs against the *raw* stem — the date
        # markers (e.g. "2025.02.17") are exactly what _clean_tmdb_query
        # would dilute, so we must inspect them before the cleanup
        # collapses the dots to spaces.
        if skip_dvr and _looks_like_dvr_capture(stem):
            skipped_dvr += 1
            continue

        query = _clean_tmdb_query(stem)
        if not query:
            continue
        meta = await svc.search(query)
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
    return enriched


async def enrich_library_tmdb(
    db: aiosqlite.Connection,
    library_id: str,
    api_key: str,
    *,
    include_dvr: bool = False,
) -> dict:
    """Re-run TMDB enrichment over every existing file in [library_id]
    that currently has no ``tmdb_id``.

    Used by the desktop's "Rescan TMDB" button.  Distinct from
    ``scan_library`` (which only enriches files added in *this* scan)
    so a user who corrects a typo in their library's root path, or
    adds the TMDB API key after the initial scan, can fill in the
    gaps without deleting + re-creating the rows (which would lose
    resume markers, watch history, encoder pinning, etc).

    Returns a dict ``{matched, enriched, skipped_dvr}``:

    - ``matched`` — files in the library that had ``tmdb_id IS NULL``
      and were considered for enrichment.
    - ``enriched`` — files actually updated (got a TMDB hit + DB row
      written).
    - ``skipped_dvr`` — files skipped because of the DVR-pattern
      heuristic.  Only > 0 when ``include_dvr=False``.

    ``include_dvr=True`` bypasses the DVR-filename skip; useful when
    the user knows their capture archive *does* have title-bearing
    filenames and they want to force-search them.
    """
    if not api_key:
        return {"matched": 0, "enriched": 0, "skipped_dvr": 0}
    # Per-library TMDB toggle — return zeros so the operator's "Rescan
    # TMDB" button no-ops cleanly instead of silently disabling the
    # toggle from under them.
    if not await _is_tmdb_enabled(db, library_id):
        return {"matched": 0, "enriched": 0, "skipped_dvr": 0}
    async with db.execute(
        "SELECT id, name FROM media_files" " WHERE library_id = ? AND tmdb_id IS NULL",
        (library_id,),
    ) as cur:
        rows = await cur.fetchall()
    file_stems = [(r["id"], Path(r["name"]).stem) for r in rows]
    enriched = await _enrich_with_tmdb(
        db,
        file_stems,
        api_key,
        skip_dvr=not include_dvr,
    )
    skipped_dvr = 0
    if not include_dvr:
        skipped_dvr = sum(1 for _, stem in file_stems if _looks_like_dvr_capture(stem))
    logger.info(
        "TMDB rescan done: library=%s matched=%d enriched=%d skipped_dvr=%d",
        library_id,
        len(file_stems),
        enriched,
        skipped_dvr,
    )
    return {
        "matched": len(file_stems),
        "enriched": enriched,
        "skipped_dvr": skipped_dvr,
    }


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
        raise ValueError(f"Constructed upload path failed validation: {path_str!r}.")

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

        # Re-claim if this row was orphaned by a prior library
        # delete (`library_id IS NULL`).  COALESCE preserves a
        # different non-null library_id rather than stealing the
        # row across libraries.
        await db.execute(
            """
            UPDATE media_files
            SET size_bytes = ?, updated_at = ?,
                library_id = COALESCE(library_id, ?)
            WHERE id = ?
            """,
            (size, now, library_id, file_id),
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

        # Best-effort TMDB enrichment (gated on per-library toggle)
        if tmdb_api_key and await _is_tmdb_enabled(db, library_id):
            await _enrich_with_tmdb(db, [(file_id, file_path.stem)], tmdb_api_key)

    result = await get_file(db, file_id)
    if result is None:
        raise RuntimeError(f"Failed to retrieve uploaded file record: {file_id}")
    return result
