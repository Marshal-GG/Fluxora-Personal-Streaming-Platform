"""Tests for the filesystem browser endpoint + service.

Builds a small temp directory tree, points a library's `root_paths`
at it, then exercises:

* root listing (default + show_hidden)
* subdirectory listing
* hidden-file filtering (dotfile + Windows hidden attribute when
  available)
* path-traversal block (`..` + absolute-path injection)
* indexed-status join with `media_files`
* parent-path computation
* errors: library not found / target not a directory / nonexistent path
"""

from __future__ import annotations

import json
import os
import sys
import uuid
from datetime import UTC, datetime
from pathlib import Path

import pytest


HMAC_KEY = "test-secret-key-for-unit-tests-only"


# ── Helpers ────────────────────────────────────────────────────────────────


async def _insert_library_with_root(test_db, *, root: Path, name: str = "lib") -> str:
    lib_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO libraries (id, name, type, root_paths, created_at)
        VALUES (?, ?, 'movies', ?, ?)
        """,
        (lib_id, name, json.dumps([str(root)]), now),
    )
    await test_db.commit()
    return lib_id


async def _insert_indexed_file(
    test_db, *, library_id: str, absolute_path: Path
) -> str:
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, library_id,
             created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            file_id,
            str(absolute_path),
            absolute_path.name,
            absolute_path.suffix.lower(),
            absolute_path.stat().st_size,
            library_id,
            now,
            now,
        ),
    )
    await test_db.commit()
    return file_id


@pytest.fixture
def tree(tmp_path: Path) -> Path:
    """Build:
        <root>/
            movie.mp4
            photo.jpg
            readme.txt
            .hidden_file
            sub/
                song.mp3
                nested/
                    doc.pdf
    """
    root = tmp_path / "library_root"
    root.mkdir()
    (root / "movie.mp4").write_bytes(b"\x00" * 1024)
    (root / "photo.jpg").write_bytes(b"\x00" * 512)
    (root / "readme.txt").write_text("hello")
    (root / ".hidden_file").write_text("secret")
    sub = root / "sub"
    sub.mkdir()
    (sub / "song.mp3").write_bytes(b"\x00" * 2048)
    nested = sub / "nested"
    nested.mkdir()
    (nested / "doc.pdf").write_bytes(b"%PDF-1.4")
    return root


# ── Root listing ───────────────────────────────────────────────────────────


async def test_browse_root_default_hides_dotfiles(client, test_db, tree):
    lib_id = await _insert_library_with_root(test_db, root=tree)
    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    assert r.status_code == 200
    body = r.json()
    assert body["library_id"] == lib_id
    assert body["relative_path"] == ""
    assert body["parent_path"] is None
    names = [e["name"] for e in body["entries"]]
    # `.hidden_file` should NOT appear by default
    assert ".hidden_file" not in names
    # The four visible siblings, dirs-first then files alphabetical
    assert names == ["sub", "movie.mp4", "photo.jpg", "readme.txt"]


async def test_browse_root_show_hidden_includes_dotfiles(
    client, test_db, tree
):
    lib_id = await _insert_library_with_root(test_db, root=tree)
    r = await client.get(
        f"/api/v1/library/{lib_id}/browse?show_hidden=true"
    )
    assert r.status_code == 200
    names = [e["name"] for e in r.json()["entries"]]
    assert ".hidden_file" in names


# ── Subdirectory listing + parent path ─────────────────────────────────────


async def test_browse_subdirectory_lists_children(client, test_db, tree):
    lib_id = await _insert_library_with_root(test_db, root=tree)
    r = await client.get(f"/api/v1/library/{lib_id}/browse?path=sub")
    assert r.status_code == 200
    body = r.json()
    assert body["relative_path"] == "sub"
    assert body["parent_path"] == ""
    names = [e["name"] for e in body["entries"]]
    assert names == ["nested", "song.mp3"]


async def test_browse_nested_subdirectory_parent_is_one_level_up(
    client, test_db, tree
):
    lib_id = await _insert_library_with_root(test_db, root=tree)
    r = await client.get(f"/api/v1/library/{lib_id}/browse?path=sub/nested")
    assert r.status_code == 200
    body = r.json()
    assert body["relative_path"] == "sub/nested"
    assert body["parent_path"] == "sub"
    names = [e["name"] for e in body["entries"]]
    assert names == ["doc.pdf"]


# ── Kind dispatch ──────────────────────────────────────────────────────────


async def test_browse_assigns_correct_kinds(client, test_db, tree):
    lib_id = await _insert_library_with_root(test_db, root=tree)
    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    assert by_name["sub"]["kind"] == "directory"
    assert by_name["movie.mp4"]["kind"] == "video"
    assert by_name["photo.jpg"]["kind"] == "image"
    assert by_name["readme.txt"]["kind"] == "other"


# ── Indexed-status join ────────────────────────────────────────────────────


async def test_browse_marks_indexed_files(client, test_db, tree):
    lib_id = await _insert_library_with_root(test_db, root=tree)
    movie_path = tree / "movie.mp4"
    file_id = await _insert_indexed_file(
        test_db, library_id=lib_id, absolute_path=movie_path
    )

    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    assert by_name["movie.mp4"]["is_indexed"] is True
    assert by_name["movie.mp4"]["file_id"] == file_id
    # photo.jpg never inserted into media_files
    assert by_name["photo.jpg"]["is_indexed"] is False
    assert by_name["photo.jpg"]["file_id"] is None
    # Directories never carry a file_id
    assert by_name["sub"]["file_id"] is None


# ── Phase A M1: indexed-entry media payload ────────────────────────────────


async def _insert_indexed_video(
    test_db,
    *,
    library_id: str,
    absolute_path: Path,
    width: int = 1920,
    height: int = 1080,
    duration_sec: float = 6420.5,
    codec_name: str = "h264",
    hdr_format: str | None = None,
    audio_tracks_json: str | None = None,
) -> str:
    """Insert a probed media_files row with width/height/codec metadata."""
    import json as _json
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, library_id,
             width, height, duration_sec, codec_name, hdr_format,
             audio_tracks, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            file_id,
            str(absolute_path),
            absolute_path.name,
            absolute_path.suffix.lower(),
            absolute_path.stat().st_size,
            library_id,
            width,
            height,
            duration_sec,
            codec_name,
            hdr_format,
            audio_tracks_json
            or _json.dumps([{"index": 0, "codec": "aac"}]),
            now,
            now,
        ),
    )
    await test_db.commit()
    return file_id


async def _insert_thumbnail_row(
    test_db,
    *,
    file_id: str,
    status: str,
    generated_at: str | None = None,
) -> None:
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT OR REPLACE INTO media_thumbnails
            (file_id, status, priority, generated_at, attempts,
             created_at, updated_at)
        VALUES (?, ?, 0, ?, 0, ?, ?)
        """,
        (file_id, status, generated_at, now, now),
    )
    await test_db.commit()


async def test_browse_indexed_video_returns_media_metadata(
    client, test_db, tree
):
    """Phase A: indexed video entries carry width/height/duration/codec
    + audio_codec parsed from audio_tracks JSON + indexed_at_iso."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    movie_path = tree / "movie.mp4"
    import json as _json
    file_id = await _insert_indexed_video(
        test_db,
        library_id=lib_id,
        absolute_path=movie_path,
        width=3840,
        height=2160,
        duration_sec=7200.0,
        codec_name="hevc",
        hdr_format="HDR10",
        audio_tracks_json=_json.dumps(
            [{"index": 0, "codec": "eac3", "channels": 6}]
        ),
    )

    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    media = by_name["movie.mp4"]["media"]
    assert media is not None
    assert media["width"] == 3840
    assert media["height"] == 2160
    assert media["duration_sec"] == 7200.0
    assert media["codec_name"] == "hevc"
    assert media["hdr_format"] == "HDR10"
    assert media["audio_codec"] == "eac3"
    assert media["indexed_at_iso"] is not None
    assert media["is_streaming"] is False

    # Suppress unused warning
    assert file_id is not None


async def test_browse_unindexed_entry_has_null_media(client, test_db, tree):
    """Files not in media_files return media=null (vs an empty dict)."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    assert by_name["photo.jpg"]["media"] is None
    assert by_name["readme.txt"]["media"] is None


async def test_browse_directory_has_null_media(client, test_db, tree):
    """Directories never carry a media payload."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    assert by_name["sub"]["media"] is None


async def test_browse_includes_thumbnail_status_when_ready(
    client, test_db, tree
):
    """When media_thumbnails.status='ready', entry's media.thumbnail_status
    is 'ready' + thumbnail_generated_at_unix is populated."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    file_id = await _insert_indexed_video(
        test_db, library_id=lib_id, absolute_path=tree / "movie.mp4"
    )
    gen_at = datetime.now(UTC).isoformat()
    await _insert_thumbnail_row(
        test_db, file_id=file_id, status="ready", generated_at=gen_at
    )

    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    media = by_name["movie.mp4"]["media"]
    assert media["thumbnail_status"] == "ready"
    assert media["thumbnail_generated_at_unix"] is not None
    assert media["thumbnail_generated_at_unix"] > 0


async def test_browse_includes_thumbnail_pending_status(
    client, test_db, tree
):
    """Pending thumbnails report status='pending', no generated_at_unix."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    file_id = await _insert_indexed_video(
        test_db, library_id=lib_id, absolute_path=tree / "movie.mp4"
    )
    await _insert_thumbnail_row(test_db, file_id=file_id, status="pending")

    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    media = by_name["movie.mp4"]["media"]
    assert media["thumbnail_status"] == "pending"
    assert media["thumbnail_generated_at_unix"] is None


async def test_browse_detects_stale_thumbnail_and_marks_status_stale(
    client, test_db, tree
):
    """When media_files.updated_at > media_thumbnails.generated_at, the
    response's thumbnail_status is 'stale' (synthesised client-only
    value) + the underlying media_thumbnails row gets flipped back to
    'pending' for the worker to pick up.  Source-file-replaced-in-place
    scenario."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    file_id = await _insert_indexed_video(
        test_db, library_id=lib_id, absolute_path=tree / "movie.mp4"
    )
    # Thumbnail was generated a while back (yesterday).
    old_iso = "2026-05-15T10:00:00+00:00"
    await _insert_thumbnail_row(
        test_db, file_id=file_id, status="ready", generated_at=old_iso
    )
    # Source file was updated AFTER the thumbnail.  We just inserted
    # the row with `updated_at` = now() above, so the timestamp ordering
    # naturally puts source after thumbnail.
    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    media = by_name["movie.mp4"]["media"]
    assert media["thumbnail_status"] == "stale"

    # The auto-re-queue must have flipped the worker's row back to pending.
    async with test_db.execute(
        "SELECT status, priority FROM media_thumbnails WHERE file_id=?",
        (file_id,),
    ) as cur:
        row = await cur.fetchone()
    assert row["status"] == "pending"
    # Priority bumped to 5 so the operator sees the re-render promptly.
    assert row["priority"] == 5


async def test_browse_currently_streaming_badge(client, test_db, tree):
    """is_streaming=true on entries with an active stream_sessions row."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    file_id = await _insert_indexed_video(
        test_db, library_id=lib_id, absolute_path=tree / "movie.mp4"
    )
    # Insert an active stream session for the file.
    session_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO stream_sessions
            (id, file_id, connection_type, started_at, ended_at)
        VALUES (?, ?, 'lan', ?, NULL)
        """,
        (session_id, file_id, now),
    )
    await test_db.commit()

    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    assert by_name["movie.mp4"]["media"]["is_streaming"] is True

    # Now end the session — is_streaming should flip to false.
    await test_db.execute(
        "UPDATE stream_sessions SET ended_at=? WHERE id=?",
        (datetime.now(UTC).isoformat(), session_id),
    )
    await test_db.commit()
    r2 = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name2 = {e["name"]: e for e in r2.json()["entries"]}
    assert by_name2["movie.mp4"]["media"]["is_streaming"] is False


async def test_browse_entry_carries_mtime_unix(client, test_db, tree):
    """Plan 28 Phase A: every entry carries an `mtime_unix` field for
    client-side stale-thumb math (independent of the server's stale
    detection — operator might mass-touch files outside our flow)."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    assert by_name["movie.mp4"]["mtime_unix"] > 0
    assert isinstance(by_name["movie.mp4"]["mtime_unix"], int)
    # Directories also carry mtime
    assert by_name["sub"]["mtime_unix"] > 0


async def test_browse_audio_codec_handles_malformed_json(
    client, test_db, tree
):
    """audio_tracks parsing tolerates garbage — returns null instead of
    raising."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    movie = tree / "movie.mp4"
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, library_id,
             width, height, codec_name, audio_tracks, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            file_id, str(movie), movie.name, movie.suffix.lower(),
            movie.stat().st_size, lib_id, 1920, 1080, "h264",
            "this is not json",  # malformed
            now, now,
        ),
    )
    await test_db.commit()

    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    media = by_name["movie.mp4"]["media"]
    assert media["audio_codec"] is None
    assert media["width"] == 1920  # other fields still populate


# ── Security: path traversal block ─────────────────────────────────────────


async def test_browse_blocks_dot_dot_traversal(client, test_db, tree):
    lib_id = await _insert_library_with_root(test_db, root=tree)
    # `sub/..` resolves back to the root — that's allowed (still inside).
    # `..` from root tries to escape — block.
    r = await client.get(f"/api/v1/library/{lib_id}/browse?path=..")
    assert r.status_code in (403, 404)
    # Deeper escape attempt
    r2 = await client.get(
        f"/api/v1/library/{lib_id}/browse?path=../../etc"
    )
    assert r2.status_code in (403, 404)


async def test_browse_blocks_absolute_path_injection(client, test_db, tree):
    lib_id = await _insert_library_with_root(test_db, root=tree)
    # A leading slash gets normalised away — the request becomes
    # equivalent to `<root>/etc`, which doesn't exist → 404.
    r = await client.get(f"/api/v1/library/{lib_id}/browse?path=/etc")
    assert r.status_code == 404


async def test_browse_nonexistent_path_returns_404(client, test_db, tree):
    lib_id = await _insert_library_with_root(test_db, root=tree)
    r = await client.get(
        f"/api/v1/library/{lib_id}/browse?path=does/not/exist"
    )
    assert r.status_code == 404


async def test_browse_unknown_library_returns_404(client, tree):
    r = await client.get(
        f"/api/v1/library/{uuid.uuid4()}/browse"
    )
    assert r.status_code == 404


# ── Empty / corrupt library ────────────────────────────────────────────────


async def test_browse_library_with_no_root_paths_returns_404(
    client, test_db
):
    """A library row with `root_paths='[]'` (or NULL) returns 404."""
    lib_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO libraries (id, name, type, root_paths, created_at)
        VALUES (?, 'empty', 'movies', '[]', ?)
        """,
        (lib_id, now),
    )
    await test_db.commit()

    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    assert r.status_code == 404


# ── Entry fields ───────────────────────────────────────────────────────────


async def test_browse_entries_carry_size_and_modified(client, test_db, tree):
    lib_id = await _insert_library_with_root(test_db, root=tree)
    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    by_name = {e["name"]: e for e in r.json()["entries"]}
    assert by_name["movie.mp4"]["size_bytes"] == 1024
    assert by_name["photo.jpg"]["size_bytes"] == 512
    assert by_name["sub"]["size_bytes"] == 0  # directories report 0
    # modified_iso must be a parseable timestamp
    datetime.fromisoformat(by_name["movie.mp4"]["modified_iso"])


# ── Windows hidden-attribute (skipped on non-Windows) ──────────────────────


@pytest.mark.skipif(sys.platform != "win32", reason="Windows-only attribute")
async def test_browse_respects_windows_hidden_attribute(
    client, test_db, tree
):
    """A file marked with `attrib +H` should be filtered by default."""
    visible = tree / "marked_hidden.bin"
    visible.write_bytes(b"\x00")
    # Apply FILE_ATTRIBUTE_HIDDEN via the OS.
    os.system(f'attrib +H "{visible}"')

    lib_id = await _insert_library_with_root(test_db, root=tree)

    r = await client.get(f"/api/v1/library/{lib_id}/browse")
    names = [e["name"] for e in r.json()["entries"]]
    assert "marked_hidden.bin" not in names

    r2 = await client.get(
        f"/api/v1/library/{lib_id}/browse?show_hidden=true"
    )
    names2 = [e["name"] for e in r2.json()["entries"]]
    assert "marked_hidden.bin" in names2


# ── Phase C: index-file / regenerate-thumbnail / scan-subtree ──────────────


async def test_index_file_inserts_media_files_row(client, test_db, tree):
    """Phase C: POST /library/{id}/index-file inserts a media_files row
    + enqueues a thumbnail, returns the new file_id."""
    lib_id = await _insert_library_with_root(test_db, root=tree)

    r = await client.post(
        f"/api/v1/library/{lib_id}/index-file?path=movie.mp4"
    )
    assert r.status_code == 200
    body = r.json()
    assert body["already_indexed"] is False
    assert body["queued_thumbnail"] is True
    assert len(body["file_id"]) > 0

    # media_files row was inserted at the absolute path
    async with test_db.execute(
        "SELECT id, path FROM media_files WHERE id = ?",
        (body["file_id"],),
    ) as cur:
        row = await cur.fetchone()
    assert row is not None
    assert row["path"] == str(tree / "movie.mp4")

    # Thumbnail row was enqueued at priority=10
    async with test_db.execute(
        "SELECT status, priority FROM media_thumbnails WHERE file_id = ?",
        (body["file_id"],),
    ) as cur:
        thumb_row = await cur.fetchone()
    assert thumb_row is not None
    assert thumb_row["status"] == "pending"
    assert thumb_row["priority"] == 10


async def test_index_file_is_idempotent(client, test_db, tree):
    """A second call against the same path returns the same file_id +
    already_indexed=True; doesn't re-INSERT or re-enqueue."""
    lib_id = await _insert_library_with_root(test_db, root=tree)

    r1 = await client.post(
        f"/api/v1/library/{lib_id}/index-file?path=movie.mp4"
    )
    assert r1.status_code == 200
    first_id = r1.json()["file_id"]

    r2 = await client.post(
        f"/api/v1/library/{lib_id}/index-file?path=movie.mp4"
    )
    assert r2.status_code == 200
    body = r2.json()
    assert body["file_id"] == first_id
    assert body["already_indexed"] is True


async def test_index_file_rejects_directory(client, test_db, tree):
    """Pointing index-file at a directory returns 400."""
    lib_id = await _insert_library_with_root(test_db, root=tree)

    r = await client.post(
        f"/api/v1/library/{lib_id}/index-file?path=sub"
    )
    assert r.status_code == 400
    assert "directory" in r.json()["detail"].lower()


async def test_index_file_rejects_unsupported_extension(
    client, test_db, tree
):
    """`readme.txt` (kind='other') is rejected with 400."""
    lib_id = await _insert_library_with_root(test_db, root=tree)

    r = await client.post(
        f"/api/v1/library/{lib_id}/index-file?path=readme.txt"
    )
    assert r.status_code == 400
    assert "unsupported" in r.json()["detail"].lower()


async def test_index_file_rejects_path_escape(client, test_db, tree):
    """`..`-style escapes return 403/404 — never 200."""
    lib_id = await _insert_library_with_root(test_db, root=tree)

    r = await client.post(
        f"/api/v1/library/{lib_id}/index-file?path=../escape.mp4"
    )
    # Resolves outside the root => 403 (escapes) or 404 (not found
    # after resolution) — either is acceptable so long as we don't
    # silently 200.
    assert r.status_code in (403, 404)


async def test_index_file_404_when_library_missing(client, test_db):
    """Library id that doesn't exist returns 404."""
    r = await client.post(
        "/api/v1/library/nonexistent-lib/index-file?path=movie.mp4"
    )
    assert r.status_code == 404


async def test_index_file_404_when_path_missing(client, test_db, tree):
    """File doesn't exist on disk => 404."""
    lib_id = await _insert_library_with_root(test_db, root=tree)

    r = await client.post(
        f"/api/v1/library/{lib_id}/index-file?path=does_not_exist.mp4"
    )
    assert r.status_code == 404


async def test_regenerate_file_thumbnail_resets_status(client, test_db, tree):
    """Phase C: POST /files/{id}/regenerate-thumbnail flips an existing
    `ready` row back to `pending` with priority=10 + deletes the JPEG."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    movie = tree / "movie.mp4"
    file_id = await _insert_indexed_file(
        test_db, library_id=lib_id, absolute_path=movie
    )
    await _insert_thumbnail_row(
        test_db,
        file_id=file_id,
        status="ready",
        generated_at=datetime.now(UTC).isoformat(),
    )

    r = await client.post(
        f"/api/v1/files/{file_id}/regenerate-thumbnail"
    )
    assert r.status_code == 200
    body = r.json()
    assert body["file_id"] == file_id
    assert body["status"] == "pending"

    async with test_db.execute(
        "SELECT status, priority, generated_at"
        "  FROM media_thumbnails WHERE file_id = ?",
        (file_id,),
    ) as cur:
        row = await cur.fetchone()
    assert row["status"] == "pending"
    assert row["priority"] == 10
    assert row["generated_at"] is None


async def test_regenerate_file_thumbnail_inserts_when_missing(
    client, test_db, tree
):
    """File has no `media_thumbnails` row yet — endpoint INSERT OR
    IGNOREs a fresh pending row at priority=10 instead of 404'ing."""
    lib_id = await _insert_library_with_root(test_db, root=tree)
    movie = tree / "movie.mp4"
    file_id = await _insert_indexed_file(
        test_db, library_id=lib_id, absolute_path=movie
    )

    r = await client.post(
        f"/api/v1/files/{file_id}/regenerate-thumbnail"
    )
    assert r.status_code == 200

    async with test_db.execute(
        "SELECT status, priority FROM media_thumbnails WHERE file_id = ?",
        (file_id,),
    ) as cur:
        row = await cur.fetchone()
    assert row is not None
    assert row["status"] == "pending"
    assert row["priority"] == 10


async def test_regenerate_file_thumbnail_404_when_file_missing(
    client, test_db
):
    """Unknown file_id => 404."""
    r = await client.post(
        "/api/v1/files/nonexistent-file-id/regenerate-thumbnail"
    )
    assert r.status_code == 404


async def test_scan_subtree_walks_only_one_directory(client, test_db, tree):
    """Phase C: POST /library/{id}/scan-subtree only ingests files under
    the requested subdir, not the rest of the library root."""
    lib_id = await _insert_library_with_root(test_db, root=tree)

    r = await client.post(
        f"/api/v1/library/{lib_id}/scan-subtree?path=sub"
    )
    assert r.status_code == 200
    body = r.json()
    assert body["library_id"] == lib_id
    # `sub/` contains `song.mp3` + `sub/nested/doc.pdf` — both are
    # _MEDIA_EXTENSIONS members.  Top-level `movie.mp4` / `photo.jpg`
    # are NOT in the subtree and must not be ingested.
    assert body["files_added"] == 2

    # Verify only sub-tree files landed in media_files
    async with test_db.execute(
        "SELECT path FROM media_files WHERE library_id = ?", (lib_id,)
    ) as cur:
        rows = await cur.fetchall()
    paths = {r["path"] for r in rows}
    assert str(tree / "sub" / "song.mp3") in paths
    assert str(tree / "sub" / "nested" / "doc.pdf") in paths
    assert str(tree / "movie.mp4") not in paths


async def test_scan_subtree_rejects_file_path(client, test_db, tree):
    """Pointing scan-subtree at a file (not a directory) returns 400."""
    lib_id = await _insert_library_with_root(test_db, root=tree)

    r = await client.post(
        f"/api/v1/library/{lib_id}/scan-subtree?path=movie.mp4"
    )
    assert r.status_code == 400


async def test_scan_subtree_rejects_path_escape(client, test_db, tree):
    """`..`-style escape returns 403/404."""
    lib_id = await _insert_library_with_root(test_db, root=tree)

    r = await client.post(
        f"/api/v1/library/{lib_id}/scan-subtree?path=../outside"
    )
    assert r.status_code in (403, 404)
