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
