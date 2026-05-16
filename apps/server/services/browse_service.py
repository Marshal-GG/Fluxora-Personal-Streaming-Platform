"""Filesystem-browser for the desktop Library page.

The classic library views surface only what the scanner indexed into
`media_files` (videos + the handful of recognised media extensions).
The desktop's library card click-through now opens an Explorer-style
folder browser that walks the actual filesystem under one of the
library's `root_paths`.  Browse responses are joined against
`media_files` so the client can dispatch indexed entries to the
streaming pipeline + flag unindexed ones for "Open in file manager".

Security stance:

* The requested path is rebuilt as `<root>/<relative>` and resolved
  via `Path.resolve(strict=False)`.  After resolution the result is
  walked back up through its parents to confirm one of the library's
  `root_paths` is a strict ancestor — defeats `..` traversal,
  symlink-out-of-tree, and absolute-path injection.
* `root_paths` are user-configured at library creation time; we never
  trust the request to nominate a root.

Hidden file detection:

* On POSIX: name starts with `.`
* On Windows: `FILE_ATTRIBUTE_HIDDEN` bit set on the entry's
  `st_file_attributes`.
* Dotfiles are also treated as hidden on Windows for consistency.

`is_indexed` + `file_id` join: a SQLite lookup keyed on absolute
filesystem path (`media_files.path`) tells us whether the entry has
been scanned — drives the client's smart-dispatch (play vs open in
file manager).  The lookup is bounded by a single SELECT IN clause
over the entries we're about to return; max page size is small
enough that this stays cheap.
"""

from __future__ import annotations

import json
import logging
import stat
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Literal

import aiosqlite

logger = logging.getLogger(__name__)


# ── Extension → file-kind dispatch ─────────────────────────────────────────
# Matches the dispatch table in services.thumbnail_service but kept
# separate so a thumbnail-extension change doesn't accidentally drag
# unrelated kinds into the browser.  Order: video, image, audio,
# pdf, then a small set of "common doc" types we badge for the UI but
# can't render directly (clicks fall through to "Open in file manager").

_VIDEO_EXTENSIONS = frozenset(
    {".mp4", ".mkv", ".mov", ".avi", ".webm", ".wmv", ".flv", ".m4v", ".ts"}
)
_IMAGE_EXTENSIONS = frozenset(
    {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".gif", ".bmp",
     ".tiff", ".tif"}
)
_AUDIO_EXTENSIONS = frozenset(
    {".mp3", ".m4a", ".flac", ".ogg", ".opus", ".wav", ".aac"}
)
_PDF_EXTENSIONS = frozenset({".pdf"})


FileKind = Literal["directory", "video", "image", "audio", "pdf", "other"]


def _kind_for_path(path: Path, *, is_dir: bool) -> FileKind:
    if is_dir:
        return "directory"
    ext = path.suffix.lower()
    if ext in _VIDEO_EXTENSIONS:
        return "video"
    if ext in _IMAGE_EXTENSIONS:
        return "image"
    if ext in _AUDIO_EXTENSIONS:
        return "audio"
    if ext in _PDF_EXTENSIONS:
        return "pdf"
    return "other"


# ── Hidden detection ───────────────────────────────────────────────────────


def _is_hidden(entry: Path, lstat_result: object) -> bool:
    """Return True if the entry should be treated as hidden.

    Dotfile name on every platform + Windows hidden attribute when
    available (Python 3.12 exposes `st_file_attributes` on Windows).
    """
    if entry.name.startswith("."):
        return True
    # Windows-only: stat's st_file_attributes carries the NTFS flags.
    attrs = getattr(lstat_result, "st_file_attributes", None)
    if attrs is not None:
        # FILE_ATTRIBUTE_HIDDEN = 0x2; FILE_ATTRIBUTE_SYSTEM = 0x4 (also
        # hide system files unless show_hidden is True — matches Explorer).
        if attrs & 0x2 or attrs & 0x4:
            return True
    return False


# ── Data classes ───────────────────────────────────────────────────────────


@dataclass(frozen=True)
class IndexedMedia:
    """Metadata pulled from `media_files` + `media_thumbnails` +
    `stream_sessions` for indexed entries.  Phase A of plan 28 —
    surfaces enough info for the right detail panel to render without
    a second HTTP round-trip.

    `thumbnail_status` widens the M2 server-side enum with one extra
    client-only value:

      * `pending` / `generating` / `ready` / `failed` / `skipped` —
        verbatim from the `media_thumbnails.status` column.
      * `stale` — synthesised by `_attach_index_status` when
        `media_files.updated_at > media_thumbnails.generated_at`,
        i.e. the source file was modified after the current thumbnail
        was rendered.  Worker is auto-re-queued; client treats this
        the same as `pending` for UI purposes (shows the failed-thumb
        warning icon faded, hides the regenerate button since one is
        already in flight).
    """

    width: int | None
    height: int | None
    duration_sec: float | None
    codec_name: str | None
    hdr_format: str | None        # HDR10 / HLG / DolbyVision / null
    audio_codec: str | None       # primary track's codec from audio_tracks
    thumbnail_status: str | None  # see docstring
    thumbnail_generated_at_unix: int | None  # for ?v= cache-buster
    indexed_at_iso: str | None    # media_files.created_at
    is_streaming: bool            # active stream_session row exists

    def to_json(self) -> dict:
        return {
            "width": self.width,
            "height": self.height,
            "duration_sec": self.duration_sec,
            "codec_name": self.codec_name,
            "hdr_format": self.hdr_format,
            "audio_codec": self.audio_codec,
            "thumbnail_status": self.thumbnail_status,
            "thumbnail_generated_at_unix": self.thumbnail_generated_at_unix,
            "indexed_at_iso": self.indexed_at_iso,
            "is_streaming": self.is_streaming,
        }


@dataclass(frozen=True)
class BrowseEntry:
    name: str
    kind: FileKind
    is_dir: bool
    is_hidden: bool
    size_bytes: int
    modified_iso: str  # ISO-8601 UTC
    mtime_unix: int    # raw mtime for client-side stale-thumb checks

    # Indexed-status fields are filled in by `_attach_index_status` from
    # a single SQL lookup over `media_files`.  `file_id` is the row id;
    # consumers can call `/stream/start/{file_id}` / `/files/{file_id}/
    # content` / `/files/{file_id}/thumbnail` for indexed entries.
    is_indexed: bool = False
    file_id: str | None = None

    # Phase A: when `is_indexed`, this carries width / height / codec /
    # duration / HDR / audio codec / thumbnail status + generated_at /
    # indexed_at + currently-streaming flag.  Lets the desktop detail
    # panel render without a second HTTP request.  `None` for non-
    # indexed entries and directories.
    media: IndexedMedia | None = None

    def to_json(self) -> dict:
        return {
            "name": self.name,
            "kind": self.kind,
            "is_dir": self.is_dir,
            "is_hidden": self.is_hidden,
            "size_bytes": self.size_bytes,
            "modified_iso": self.modified_iso,
            "mtime_unix": self.mtime_unix,
            "is_indexed": self.is_indexed,
            "file_id": self.file_id,
            "media": self.media.to_json() if self.media else None,
        }


@dataclass(frozen=True)
class BrowseResponse:
    library_id: str
    root_path: str          # the resolved root the relative path lives under
    relative_path: str      # normalised relative path (forward slashes)
    parent_path: str | None  # one level up, or None at the library root
    entries: list[BrowseEntry]

    def to_json(self) -> dict:
        return {
            "library_id": self.library_id,
            "root_path": self.root_path,
            "relative_path": self.relative_path,
            "parent_path": self.parent_path,
            "entries": [e.to_json() for e in self.entries],
        }


# ── Path resolution + security ─────────────────────────────────────────────


class BrowseError(Exception):
    """Raised on any path / security failure.  Caller maps to 4xx."""

    def __init__(self, status_code: int, detail: str) -> None:
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail


def _normalise_relative(relative: str) -> str:
    """Strip leading slashes + normalise separators.  Empty == root."""
    rel = (relative or "").replace("\\", "/").strip()
    # Lop off any leading slashes so we don't accidentally turn relative
    # paths into absolute ones on join.
    while rel.startswith("/"):
        rel = rel[1:]
    # Collapse `//` and trailing slashes.
    while "//" in rel:
        rel = rel.replace("//", "/")
    while rel.endswith("/"):
        rel = rel[:-1]
    return rel


def _resolve_under_root(
    roots: list[Path], relative: str
) -> tuple[Path, Path]:
    """Resolve `relative` against one of `roots`.

    Returns `(matched_root, resolved_absolute)`.  Raises `BrowseError`
    when the request escapes every root, references a nonexistent
    location, or points at a non-directory.
    """
    rel = _normalise_relative(relative)

    # Empty relative means the library root.  Need to figure out WHICH
    # root the client wants: if the library has a single root_path we
    # use it; multi-root libraries use the first root for the empty
    # case and surface the siblings via a synthetic "Library Roots"
    # listing in a future iteration (out of scope for v1; client should
    # navigate via the breadcrumb to explore other roots).
    if not rel:
        if not roots:
            raise BrowseError(404, "library has no root_paths configured")
        candidate = roots[0]
        try:
            resolved = candidate.resolve(strict=True)
        except FileNotFoundError as e:
            raise BrowseError(
                404, f"library root not found on disk: {candidate}"
            ) from e
        if not resolved.is_dir():
            raise BrowseError(
                400, f"library root is not a directory: {resolved}"
            )
        return candidate, resolved

    # When a non-empty relative path is supplied, attempt resolution
    # under each root in turn — the first match wins.  This covers
    # multi-root libraries where the relative path could live under any
    # of the configured tops.  Each root is canonicalised before the
    # ancestor check so a symlink farm doesn't fool us.
    last_err: Exception | None = None
    for root in roots:
        try:
            root_resolved = root.resolve(strict=True)
        except FileNotFoundError as e:
            last_err = e
            continue
        candidate = (root_resolved / rel).resolve(strict=False)
        # Containment check: the candidate must be either the root
        # itself OR a strict descendant.  `Path.is_relative_to` does
        # this idiomatically on 3.9+.
        try:
            inside = candidate.is_relative_to(root_resolved)
        except ValueError:
            inside = False
        if not inside:
            continue
        if not candidate.exists():
            last_err = FileNotFoundError(str(candidate))
            continue
        if not candidate.is_dir():
            raise BrowseError(
                400, f"target is not a directory: {candidate}"
            )
        return root_resolved, candidate

    if isinstance(last_err, FileNotFoundError):
        raise BrowseError(404, "path not found under any library root")
    raise BrowseError(403, "path escapes every library root")


# ── Listing ────────────────────────────────────────────────────────────────


def _list_entries(target: Path, *, show_hidden: bool) -> list[BrowseEntry]:
    """Walk the directory non-recursively.  Sort: directories first,
    then files, each alphabetical (case-insensitive)."""
    raw: list[BrowseEntry] = []
    try:
        scan = list(target.iterdir())
    except (PermissionError, OSError) as e:
        logger.warning("browse: failed to iterdir %s: %s", target, e)
        raise BrowseError(403, "permission denied reading directory") from e

    for child in scan:
        try:
            st = child.lstat()
        except OSError as e:
            logger.debug("browse: lstat skip %s (%s)", child, e)
            continue
        hidden = _is_hidden(child, st)
        if hidden and not show_hidden:
            continue
        is_dir = stat.S_ISDIR(st.st_mode) or (
            child.is_dir() if not stat.S_ISLNK(st.st_mode) else False
        )
        # For symlinks, follow once so the kind reflects the target
        # (matches Explorer's behaviour for shortcuts to directories).
        if stat.S_ISLNK(st.st_mode):
            try:
                target_st = child.stat()
                is_dir = stat.S_ISDIR(target_st.st_mode)
            except OSError:
                # Broken symlink — show as 'other', size 0.
                is_dir = False
        kind = _kind_for_path(child, is_dir=is_dir)
        size = 0 if is_dir else int(st.st_size)

        modified = datetime.fromtimestamp(st.st_mtime, tz=UTC).isoformat()
        raw.append(
            BrowseEntry(
                name=child.name,
                kind=kind,
                is_dir=is_dir,
                is_hidden=hidden,
                size_bytes=size,
                modified_iso=modified,
                mtime_unix=int(st.st_mtime),
            )
        )

    raw.sort(key=lambda e: (0 if e.is_dir else 1, e.name.lower()))
    return raw


async def _attach_index_status(
    db: aiosqlite.Connection,
    target: Path,
    entries: list[BrowseEntry],
) -> list[BrowseEntry]:
    """Fill `is_indexed` + `file_id` + (Phase A) the `media` payload by
    joining names against `media_files.path` and (where indexed) onto
    `media_thumbnails` + `stream_sessions`.

    Single SELECT IN over the file names with LEFT JOINs for thumbnail
    + currently-streaming — bounded by the directory listing length.
    Directories don't get an index lookup.

    Also synthesises `thumbnail_status='stale'` when
    `media_files.updated_at > media_thumbnails.generated_at` (the
    source file was modified after the thumbnail was rendered) + auto-
    re-queues the worker via `thumbnail_worker.enqueue` with the
    default priority.  Operator sees a stale-thumb regeneration kick
    off without manual intervention; client gets the status flag so it
    can render a "regenerating" indicator instead of a stale image.
    """
    file_names = [e.name for e in entries if not e.is_dir]
    if not file_names:
        return entries

    # SQLite's `LIKE` would let us pattern-match path prefix, but a more
    # explicit join uses `path` equality after we reconstruct the
    # absolute path for each candidate.  Build the list of (name,
    # absolute_path) up front and query in one IN-clause.
    candidates = {
        name: str((target / name).resolve(strict=False))
        for name in file_names
    }
    placeholders = ",".join("?" for _ in candidates)
    params: list[str] = list(candidates.values())

    # Single LEFT-JOINed query — pulls media_files row + thumbnail
    # status + generated_at + active-stream presence in one round-trip.
    # SQLite returns NULL for unmatched LEFT JOIN columns.
    query = f"""
        SELECT mf.id           AS file_id,
               mf.path          AS path,
               mf.width         AS width,
               mf.height        AS height,
               mf.duration_sec  AS duration_sec,
               mf.codec_name    AS codec_name,
               mf.hdr_format    AS hdr_format,
               mf.audio_tracks  AS audio_tracks,
               mf.created_at    AS indexed_at,
               mf.updated_at    AS source_updated_at,
               t.status         AS thumb_status,
               t.generated_at   AS thumb_generated_at,
               CAST(strftime('%s', t.generated_at) AS INTEGER)
                                AS thumb_generated_at_unix,
               EXISTS(
                   SELECT 1 FROM stream_sessions ss
                    WHERE ss.file_id = mf.id AND ss.ended_at IS NULL
               )                AS is_streaming
          FROM media_files mf
     LEFT JOIN media_thumbnails t ON t.file_id = mf.id
         WHERE mf.path IN ({placeholders})
    """
    async with db.execute(query, params) as cur:
        rows = await cur.fetchall()
    by_path = {row["path"]: row for row in rows}

    # Best-effort stale-thumb auto-re-queue.  Late import so the
    # service module stays decoupled from the worker (avoids a
    # circular-import risk during test collection).
    stale_file_ids: list[str] = []
    for row in rows:
        if (
            row["thumb_status"] == "ready"
            and row["source_updated_at"] is not None
            and row["thumb_generated_at"] is not None
            and row["source_updated_at"] > row["thumb_generated_at"]
        ):
            stale_file_ids.append(row["file_id"])
    if stale_file_ids:
        try:
            from services import thumbnail_worker

            now = datetime.now(UTC).isoformat()
            for file_id in stale_file_ids:
                # Mark the existing row pending + bump priority so the
                # worker picks it up before unrelated pending rows.
                await db.execute(
                    """
                    UPDATE media_thumbnails
                       SET status='pending', priority=5, updated_at=?
                     WHERE file_id=? AND status='ready'
                    """,
                    (now, file_id),
                )
            await db.commit()
        except Exception:  # pragma: no cover - defensive
            logger.warning(
                "stale-thumb auto-re-queue failed for %d file(s)",
                len(stale_file_ids),
                exc_info=True,
            )

    def _media_for(row) -> IndexedMedia:
        # Primary audio track codec — first entry's `codec` field from
        # the JSON-encoded audio_tracks column.  Best-effort; absent or
        # malformed payloads return None.
        audio_codec: str | None = None
        raw_audio = row["audio_tracks"]
        if raw_audio:
            try:
                decoded = json.loads(raw_audio)
                if isinstance(decoded, list) and decoded:
                    first = decoded[0]
                    if isinstance(first, dict):
                        codec_val = first.get("codec")
                        if isinstance(codec_val, str):
                            audio_codec = codec_val
            except (TypeError, ValueError):
                audio_codec = None

        thumb_status = row["thumb_status"]
        # Synthesise 'stale' for UI purposes (the underlying row was
        # just flipped back to 'pending' by the auto-re-queue above;
        # the client wants to know "this WAS ready but is now being
        # regenerated").
        if (
            row["file_id"] in stale_file_ids
            and thumb_status in ("ready", "pending")
        ):
            thumb_status = "stale"

        return IndexedMedia(
            width=row["width"],
            height=row["height"],
            duration_sec=row["duration_sec"],
            codec_name=row["codec_name"],
            hdr_format=row["hdr_format"],
            audio_codec=audio_codec,
            thumbnail_status=thumb_status,
            thumbnail_generated_at_unix=row["thumb_generated_at_unix"],
            indexed_at_iso=row["indexed_at"],
            is_streaming=bool(row["is_streaming"]),
        )

    return [
        BrowseEntry(
            name=e.name,
            kind=e.kind,
            is_dir=e.is_dir,
            is_hidden=e.is_hidden,
            size_bytes=e.size_bytes,
            modified_iso=e.modified_iso,
            mtime_unix=e.mtime_unix,
            is_indexed=(
                e.is_dir or candidates.get(e.name) in by_path
            ),
            file_id=(
                None
                if e.is_dir
                else (
                    by_path[candidates[e.name]]["file_id"]
                    if candidates.get(e.name) in by_path
                    else None
                )
            ),
            media=(
                None
                if e.is_dir or candidates.get(e.name) not in by_path
                else _media_for(by_path[candidates[e.name]])
            ),
        )
        for e in entries
    ]


# ── Public surface ─────────────────────────────────────────────────────────


async def browse_library(
    db: aiosqlite.Connection,
    *,
    library_id: str,
    relative_path: str,
    show_hidden: bool,
) -> BrowseResponse:
    """Return a `BrowseResponse` for the requested library path.

    Raises `BrowseError(status_code, detail)` on any
    validation/security/IO error so the router can map to the right
    HTTP status without leaking internals.
    """
    async with db.execute(
        "SELECT id, root_paths FROM libraries WHERE id = ?",
        (library_id,),
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        raise BrowseError(404, "library not found")

    raw_roots = row["root_paths"]
    try:
        decoded = json.loads(raw_roots) if isinstance(raw_roots, str) else raw_roots
    except (TypeError, ValueError) as e:
        raise BrowseError(500, "library root_paths corrupted") from e
    if not isinstance(decoded, list) or not decoded:
        raise BrowseError(404, "library has no root_paths configured")

    roots = [Path(str(r)) for r in decoded if isinstance(r, str) and r]
    if not roots:
        raise BrowseError(404, "library has no usable root_paths")

    matched_root, target = _resolve_under_root(roots, relative_path)
    entries = _list_entries(target, show_hidden=show_hidden)
    entries = await _attach_index_status(db, target, entries)

    rel_norm = _normalise_relative(relative_path)
    # Parent path: drop the last segment; None when we're at the root.
    parent: str | None
    if rel_norm:
        parts = rel_norm.split("/")
        parent = "/".join(parts[:-1]) if len(parts) > 1 else ""
    else:
        parent = None

    return BrowseResponse(
        library_id=library_id,
        root_path=str(matched_root),
        relative_path=rel_norm,
        parent_path=parent,
        entries=entries,
    )
