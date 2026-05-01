"""Tests for GET /api/v1/library/storage-breakdown."""

from __future__ import annotations

import json


async def test_storage_breakdown_empty(client, test_db):
    """No libraries → all zeros."""
    resp = await client.get("/api/v1/library/storage-breakdown")
    assert resp.status_code == 200
    body = resp.json()
    assert body == {
        "total_bytes": 0,
        "capacity_bytes": 0,
        "by_type": {"movies": 0, "tv": 0, "music": 0, "files": 0},
    }


async def test_storage_breakdown_aggregates_by_type(client, test_db, tmp_path):
    """Two movies + one TV file → totals split correctly."""
    movies_root = tmp_path / "movies"
    tv_root = tmp_path / "tv"
    movies_root.mkdir()
    tv_root.mkdir()

    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?, ?, ?, ?, ?)",
        (
            "lib-mov",
            "Movies",
            "movies",
            json.dumps([str(movies_root)]),
            "2026-01-01T00:00:00Z",
        ),
    )
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?, ?, ?, ?, ?)",
        (
            "lib-tv",
            "TV",
            "tv",
            json.dumps([str(tv_root)]),
            "2026-01-01T00:00:00Z",
        ),
    )
    await test_db.execute(
        "INSERT INTO media_files"
        " (id, path, name, extension, size_bytes, library_id)"
        " VALUES ('m1', '/m1.mkv', 'm1.mkv', 'mkv', 1000, 'lib-mov')"
    )
    await test_db.execute(
        "INSERT INTO media_files"
        " (id, path, name, extension, size_bytes, library_id)"
        " VALUES ('m2', '/m2.mkv', 'm2.mkv', 'mkv', 2000, 'lib-mov')"
    )
    await test_db.execute(
        "INSERT INTO media_files"
        " (id, path, name, extension, size_bytes, library_id)"
        " VALUES ('t1', '/t1.mkv', 't1.mkv', 'mkv', 500, 'lib-tv')"
    )
    await test_db.commit()

    resp = await client.get("/api/v1/library/storage-breakdown")
    assert resp.status_code == 200
    body = resp.json()
    assert body["by_type"]["movies"] == 3000
    assert body["by_type"]["tv"] == 500
    assert body["by_type"]["music"] == 0
    assert body["by_type"]["files"] == 0
    assert body["total_bytes"] == 3500
    # capacity_bytes is whatever shutil.disk_usage reports for tmp_path's disk
    # — both libraries share the same disk so it should be counted once and > 0
    assert body["capacity_bytes"] > 0


async def test_storage_breakdown_skips_missing_root(client, test_db):
    """A library whose root doesn't exist still counts media-file sizes but
    doesn't add to capacity."""
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?, ?, ?, ?, ?)",
        (
            "lib-music",
            "Music",
            "music",
            json.dumps(["/nonexistent/path/that/does/not/exist"]),
            "2026-01-01T00:00:00Z",
        ),
    )
    await test_db.execute(
        "INSERT INTO media_files"
        " (id, path, name, extension, size_bytes, library_id)"
        " VALUES ('m1', '/m1.flac', 'm1.flac', 'flac', 4000, 'lib-music')"
    )
    await test_db.commit()

    resp = await client.get("/api/v1/library/storage-breakdown")
    assert resp.status_code == 200
    body = resp.json()
    assert body["by_type"]["music"] == 4000
    assert body["capacity_bytes"] == 0
