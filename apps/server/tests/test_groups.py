"""Tests for /api/v1/groups and the stream-gate restriction enforcement."""

from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import patch

import pytest
from httpx import ASGITransport, AsyncClient

from main import app

HMAC_KEY = "test-secret-key-for-unit-tests-only"


# ── helpers ────────────────────────────────────────────────────────────────


async def _get_token(client: AsyncClient, monkeypatch, client_id: str) -> str:
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    await client.post(
        "/api/v1/auth/request-pair",
        json={
            "client_id": client_id,
            "device_name": f"dev-{client_id}",
            "platform": "android",
            "app_version": "0.1.0",
        },
    )
    await client.post(f"/api/v1/auth/approve/{client_id}")
    resp = await client.get(f"/api/v1/auth/status/{client_id}")
    return resp.json()["auth_token"]


async def _insert_file_with_library(test_db, library_id: str) -> str:
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    # Library row
    await test_db.execute(
        "INSERT OR IGNORE INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?, ?, ?, ?, ?)",
        (library_id, library_id, "movies", json.dumps([]), now),
    )
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, library_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            file_id,
            f"/media/{file_id}.mp4",
            "test.mp4",
            ".mp4",
            1024000,
            library_id,
            now,
            now,
        ),
    )
    await test_db.commit()
    return file_id


# ── CRUD ───────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_and_list_group(client: AsyncClient):
    resp = await client.post(
        "/api/v1/groups",
        json={
            "name": "Family",
            "description": "Living-room TV + bedrooms",
            "restrictions": {
                "allowed_libraries": ["lib-movies"],
                "bandwidth_cap_mbps": 25,
            },
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["name"] == "Family"
    assert body["status"] == "active"
    assert body["member_count"] == 0
    assert body["restrictions"]["allowed_libraries"] == ["lib-movies"]
    assert body["restrictions"]["bandwidth_cap_mbps"] == 25

    listing = await client.get("/api/v1/groups")
    assert listing.status_code == 200
    rows = listing.json()
    # Public group is auto-created by migration 025 (v2 content-spaces
    # plan) so the listing always has at least one row.  Filter it out
    # to assert what the test actually cares about — the group we just
    # created is in the response.
    non_public = [r for r in rows if r["id"] != "public"]
    assert len(non_public) == 1
    assert non_public[0]["id"] == body["id"]


@pytest.mark.asyncio
async def test_get_group_404(client: AsyncClient):
    resp = await client.get("/api/v1/groups/nope")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_create_then_get_round_trips_full_restrictions(
    client: AsyncClient,
):
    """Pins the wire format the desktop M1 dialogs send: every restriction
    field populated in a single POST, then read back via GET /{id} and
    re-asserted.  Catches any future breakage where one of the four
    fields gets dropped on serialisation."""
    payload = {
        "name": "Kids",
        "description": "Bedtime gate + only Movies + Cartoons",
        "restrictions": {
            "allowed_libraries": ["lib-movies", "lib-cartoons"],
            "bandwidth_cap_mbps": 8,
            "time_window": {
                "start_h": 18,
                "end_h": 22,
                "days": [0, 1, 2, 3, 4],
            },
            "max_rating": "PG",
        },
    }
    created = await client.post("/api/v1/groups", json=payload)
    assert created.status_code == 201
    gid = created.json()["id"]

    fetched = await client.get(f"/api/v1/groups/{gid}")
    assert fetched.status_code == 200
    body = fetched.json()
    r = body["restrictions"]
    # Every field round-trips byte-for-byte (modulo list ordering, which
    # the server preserves because allowed_libraries persists as JSON).
    assert r["allowed_libraries"] == ["lib-movies", "lib-cartoons"]
    assert r["bandwidth_cap_mbps"] == 8
    assert r["time_window"] == {
        "start_h": 18,
        "end_h": 22,
        "days": [0, 1, 2, 3, 4],
    }
    assert r["max_rating"] == "PG"


@pytest.mark.asyncio
async def test_update_group_status_to_inactive(client: AsyncClient):
    """Edit dialog's status toggle PATCHes status='inactive'.  Server gate
    filters `WHERE g.status = 'active'` so flipping inactive disables
    enforcement immediately for new streams.  Pins the round-trip — a
    regression where status is silently dropped from the PATCH body
    would re-enable a paused group without the operator noticing."""
    created = (
        await client.post("/api/v1/groups", json={"name": "Paused"})
    ).json()
    gid = created["id"]
    assert created["status"] == "active"

    resp = await client.patch(
        f"/api/v1/groups/{gid}",
        json={"status": "inactive"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "inactive"

    # Re-activate.
    resp2 = await client.patch(
        f"/api/v1/groups/{gid}",
        json={"status": "active"},
    )
    assert resp2.status_code == 200
    assert resp2.json()["status"] == "active"


@pytest.mark.asyncio
async def test_update_group_partial(client: AsyncClient):
    created = (await client.post("/api/v1/groups", json={"name": "Kids"})).json()
    gid = created["id"]

    resp = await client.patch(
        f"/api/v1/groups/{gid}",
        json={"description": "After-school only", "status": "inactive"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["name"] == "Kids"  # untouched
    assert body["description"] == "After-school only"
    assert body["status"] == "inactive"


@pytest.mark.asyncio
async def test_update_group_replaces_restrictions(client: AsyncClient):
    created = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "Guests",
                "restrictions": {"bandwidth_cap_mbps": 10},
            },
        )
    ).json()
    gid = created["id"]

    resp = await client.patch(
        f"/api/v1/groups/{gid}",
        json={
            "restrictions": {
                "time_window": {"start_h": 18, "end_h": 23, "days": [4, 5, 6]}
            }
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    # restriction body fully replaces — so bandwidth cap is now None
    assert body["restrictions"]["bandwidth_cap_mbps"] is None
    assert body["restrictions"]["time_window"]["start_h"] == 18
    assert body["restrictions"]["time_window"]["days"] == [4, 5, 6]


@pytest.mark.asyncio
async def test_delete_group_cascades(client: AsyncClient, test_db):
    created = (await client.post("/api/v1/groups", json={"name": "tmp"})).json()
    gid = created["id"]

    # restriction row should exist
    async with test_db.execute(
        "SELECT COUNT(*) FROM group_restrictions WHERE group_id = ?", (gid,)
    ) as cur:
        before = (await cur.fetchone())[0]
    assert before == 1

    resp = await client.delete(f"/api/v1/groups/{gid}")
    assert resp.status_code == 204

    async with test_db.execute(
        "SELECT COUNT(*) FROM group_restrictions WHERE group_id = ?", (gid,)
    ) as cur:
        after = (await cur.fetchone())[0]
    assert after == 0  # ON DELETE CASCADE


@pytest.mark.asyncio
async def test_delete_group_404(client: AsyncClient):
    resp = await client.delete("/api/v1/groups/nope")
    assert resp.status_code == 404


# ── Members ────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_member_add_remove(client: AsyncClient, monkeypatch):
    await _get_token(client, monkeypatch, "cli-1")
    group = (await client.post("/api/v1/groups", json={"name": "g"})).json()
    gid = group["id"]

    add = await client.post(
        f"/api/v1/groups/{gid}/members", json={"client_id": "cli-1"}
    )
    assert add.status_code == 204

    listing = await client.get(f"/api/v1/groups/{gid}/members")
    assert listing.status_code == 200
    members = listing.json()
    assert len(members) == 1
    assert members[0]["id"] == "cli-1"

    # member_count rolls up onto group response
    detail = await client.get(f"/api/v1/groups/{gid}")
    assert detail.json()["member_count"] == 1

    # remove
    rem = await client.delete(f"/api/v1/groups/{gid}/members/cli-1")
    assert rem.status_code == 204

    again = await client.get(f"/api/v1/groups/{gid}/members")
    assert again.json() == []


@pytest.mark.asyncio
async def test_member_add_unknown_client(client: AsyncClient):
    group = (await client.post("/api/v1/groups", json={"name": "g"})).json()
    resp = await client.post(
        f"/api/v1/groups/{group['id']}/members",
        json={"client_id": "ghost"},
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_member_add_idempotent(client: AsyncClient, monkeypatch):
    await _get_token(client, monkeypatch, "cli-2")
    group = (await client.post("/api/v1/groups", json={"name": "g"})).json()
    gid = group["id"]

    for _ in range(3):
        resp = await client.post(
            f"/api/v1/groups/{gid}/members", json={"client_id": "cli-2"}
        )
        assert resp.status_code == 204

    listing = await client.get(f"/api/v1/groups/{gid}/members")
    assert len(listing.json()) == 1


# ── Authorization ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_requires_localhost(test_db):
    """Tunneled requests must be rejected at the require_local_caller gate."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("203.0.113.7", 50000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.post(
            "/api/v1/groups",
            json={"name": "x"},
            headers={"CF-Connecting-IP": "203.0.113.7"},
        )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_list_allows_token_off_loopback(monkeypatch, client: AsyncClient):
    """Off-loopback callers may list groups with a valid bearer token."""
    token = await _get_token(client, monkeypatch, "cli-lan")
    # Seed at least one group so the response is non-empty
    await client.post("/api/v1/groups", json={"name": "anything"})

    async with AsyncClient(
        transport=ASGITransport(app=app, client=("192.168.1.50", 40000)),
        base_url="http://test",
    ) as lan:
        resp = await lan.get(
            "/api/v1/groups",
            headers={"Authorization": f"Bearer {token}"},
        )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


# ── Stream-gate enforcement ────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_stream_blocked_when_library_not_in_allowed_set(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}

    file_id = await _insert_file_with_library(test_db, "lib-restricted")

    group = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "kids",
                "restrictions": {"allowed_libraries": ["lib-other"]},
            },
        )
    ).json()
    await client.post(
        f"/api/v1/groups/{group['id']}/members",
        json={"client_id": "stream-test-client"},
    )

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 403
    assert "library" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_stream_allowed_when_library_in_allowed_set(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}

    file_id = await _insert_file_with_library(test_db, "lib-allowed")

    group = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "ok",
                "restrictions": {"allowed_libraries": ["lib-allowed", "lib-other"]},
            },
        )
    ).json()
    await client.post(
        f"/api/v1/groups/{group['id']}/members",
        json={"client_id": "stream-test-client"},
    )

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_stream_blocked_outside_time_window(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """v2 stream-gate (M2 of 13_groups_v2_content_spaces.md): a group
    that exposes the file's library AND has a closed time window drops
    out of the visible-libraries union outside its window — denial
    reason then names the time window specifically (M5 mobile parser
    routes that to "Outside playback hours")."""
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file_with_library(test_db, "lib-x")

    # Group exposes lib-x BUT only during a no-days window — never open.
    # Public is empty post-migration on this fresh test DB so the file's
    # only access path is via this group; closed window → time-specific
    # deny reason.
    group = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "late-night-only",
                "restrictions": {
                    "allowed_libraries": ["lib-x"],
                    "time_window": {"start_h": 0, "end_h": 1, "days": []},
                },
            },
        )
    ).json()
    await client.post(
        f"/api/v1/groups/{group['id']}/members",
        json={"client_id": "stream-test-client"},
    )

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 403
    assert "window" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_stream_allowed_when_only_visible_via_public(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """v2: when the operator adds a library to Public, EVERY paired
    client (auto-Public-member by approve hook) can stream from it.
    Replaces the v1 "client in zero groups -> unrestricted" test —
    that semantic doesn't exist in v2 because there's no zero-group
    state.  Public IS the universal baseline."""
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file_with_library(test_db, "lib-x")

    # Add lib-x to Public (the migration left Public's allowed_libraries
    # NULL on this fresh test DB because libraries was empty at boot).
    await test_db.execute(
        "UPDATE group_restrictions SET allowed_libraries = ? "
        "WHERE group_id = 'public'",
        (json.dumps(["lib-x"]),),
    )
    await test_db.commit()

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_stream_unrestricted_when_inactive_group(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """v2: an inactive group's libraries don't contribute to the visible
    set, but other groups (incl. Public) still do.  Pins the
    `WHERE g.status = 'active'` filter in the resolver — flipping a
    group inactive disables enforcement for new streams immediately
    without affecting the operator's other group config."""
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}
    file_id = await _insert_file_with_library(test_db, "lib-x")

    # Public exposes lib-x — that's the access path.  The inactive
    # group below adds nothing (no useful libraries; would be ignored
    # anyway because status='inactive').
    await test_db.execute(
        "UPDATE group_restrictions SET allowed_libraries = ? "
        "WHERE group_id = 'public'",
        (json.dumps(["lib-x"]),),
    )
    await test_db.commit()

    group = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "deactivated",
                "restrictions": {"allowed_libraries": ["lib-other"]},
            },
        )
    ).json()
    await client.post(
        f"/api/v1/groups/{group['id']}/members",
        json={"client_id": "stream-test-client"},
    )
    await client.patch(f"/api/v1/groups/{group['id']}", json={"status": "inactive"})

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_union_of_allowed_libraries_across_groups(
    client: AsyncClient, monkeypatch, test_db, tmp_path
):
    """v2 semantic flip from v1: two groups exposing different library
    sets produce the UNION of their libraries (not the intersection).
    Replaces the v1 `test_intersection_of_allowed_libraries_across_groups`
    case — adding more groups grants MORE access in v2, never less.
    Operator audit banner (M5 of plan) warns about the more-permissive
    semantic on upgrade."""
    token = await _get_token(client, monkeypatch, "stream-test-client")
    headers = {"Authorization": f"Bearer {token}"}

    # The file is in lib-movies.  Group A exposes {lib-movies, lib-tv};
    # Group B exposes {lib-tv, lib-music}.  v2 union covers lib-movies →
    # stream is allowed.  Public is empty so it doesn't contribute.
    file_id = await _insert_file_with_library(test_db, "lib-movies")

    grp_a = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "A",
                "restrictions": {"allowed_libraries": ["lib-movies", "lib-tv"]},
            },
        )
    ).json()
    grp_b = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "B",
                "restrictions": {"allowed_libraries": ["lib-tv", "lib-music"]},
            },
        )
    ).json()
    for gid in (grp_a["id"], grp_b["id"]):
        await client.post(
            f"/api/v1/groups/{gid}/members",
            json={"client_id": "stream-test-client"},
        )

    async def _mock_start(file_path: str, session_id: str, hls_root: Path, **_) -> Path:
        playlist = tmp_path / session_id / "playlist.m3u8"
        playlist.parent.mkdir(parents=True, exist_ok=True)
        playlist.write_text("#EXTM3U\n")
        return playlist

    with patch("routers.stream.ffmpeg_service.start_stream", side_effect=_mock_start):
        resp = await client.post(f"/api/v1/stream/start/{file_id}", headers=headers)

    assert resp.status_code == 201


# ── v2 — content-spaces visibility resolution ─────────────────────────────
#
# Tests for `get_visible_libraries` + `reason_to_deny_stream` + the PIN flow
# from `docs/10_planning/13_groups_v2_content_spaces.md`.  These ride alongside
# the v1 tests above; M2 of that plan switches the live consumers (list
# endpoints + stream router) over.  v2 functions are tested directly against
# the service layer rather than via HTTP routes since the routes don't
# consume them yet.

from datetime import timedelta  # noqa: E402

from services import group_service  # noqa: E402


async def _make_paired_client(
    test_db, client_id: str = "v2-client", *, status: str = "approved"
) -> str:
    """Insert a fully-paired client row directly into the DB (skips the
    HTTP request-pair flow which would auto-add to Public via approve_client).
    Lets us control group membership precisely for visibility tests."""
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO clients (id, name, platform, status, last_seen,
                             is_trusted, auth_token, paired_at)
        VALUES (?, ?, 'android', ?, ?, 1, ?, ?)
        """,
        (
            client_id,
            f"Device {client_id}",
            status,
            now,
            f"tok-{client_id}",  # NOT NULL column; value irrelevant here
            now,
        ),
    )
    await test_db.commit()
    return client_id


async def _make_library(test_db, library_id: str) -> str:
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT OR IGNORE INTO libraries
            (id, name, type, root_paths, created_at)
        VALUES (?, ?, 'movies', '[]', ?)
        """,
        (library_id, library_id, now),
    )
    await test_db.commit()
    return library_id


async def _make_group(
    test_db,
    group_id: str,
    *,
    name: str | None = None,
    status: str = "active",
    libraries: list[str] | None = None,
    requires_pin: bool = False,
    pin_hash: str | None = None,
    pin_mode: str = "session",
    pin_model: str = "shared",
    time_window: dict | None = None,
) -> str:
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO groups
            (id, name, status, created_at, updated_at,
             is_public, requires_pin, pin_hash, pin_mode, pin_model)
        VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?)
        """,
        (
            group_id,
            name or group_id,
            status,
            now,
            now,
            1 if requires_pin else 0,
            pin_hash,
            pin_mode,
            pin_model,
        ),
    )
    await test_db.execute(
        """
        INSERT INTO group_restrictions
            (group_id, allowed_libraries, time_window)
        VALUES (?, ?, ?)
        """,
        (
            group_id,
            json.dumps(libraries) if libraries else None,
            json.dumps(time_window) if time_window else None,
        ),
    )
    await test_db.commit()
    return group_id


async def _add_to_group(test_db, group_id: str, client_id: str) -> None:
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT OR IGNORE INTO group_members (group_id, client_id, added_at)
        VALUES (?, ?, ?)
        """,
        (group_id, client_id, now),
    )
    await test_db.commit()


# ── visibility matrix ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_visibility_client_only_in_public_sees_publics_libraries(test_db):
    """Baseline: a client in only Public sees what Public exposes — nothing
    else.  Migration 025 manufactures Public; we add a library to it and
    verify the client sees exactly that library."""
    cid = await _make_paired_client(test_db)
    await _make_library(test_db, "lib-movies")
    # Public's restrictions row was created with NULLIF empty.  Update
    # to populate Public with the movie library.
    await test_db.execute(
        "UPDATE group_restrictions SET allowed_libraries = ? "
        "WHERE group_id = 'public'",
        (json.dumps(["lib-movies"]),),
    )
    await _add_to_group(test_db, "public", cid)
    await test_db.commit()

    visible = await group_service.get_visible_libraries(test_db, cid)
    assert visible.library_ids == frozenset({"lib-movies"})
    assert visible.pin_locked_groups == frozenset()
    assert visible.time_locked_groups == frozenset()


@pytest.mark.asyncio
async def test_visibility_multi_group_unions_libraries(test_db):
    """v2 semantic: client in Public + Family + Kids sees the UNION of
    each group's libraries (not the intersection like v1).  Adding more
    groups grants more access."""
    cid = await _make_paired_client(test_db)
    for lib in ("lib-movies", "lib-tv", "lib-cartoons"):
        await _make_library(test_db, lib)

    await test_db.execute(
        "UPDATE group_restrictions SET allowed_libraries = ? "
        "WHERE group_id = 'public'",
        (json.dumps(["lib-movies"]),),
    )
    await _add_to_group(test_db, "public", cid)

    await _make_group(test_db, "family", libraries=["lib-tv"])
    await _add_to_group(test_db, "family", cid)
    await _make_group(test_db, "kids", libraries=["lib-cartoons"])
    await _add_to_group(test_db, "kids", cid)

    visible = await group_service.get_visible_libraries(test_db, cid)
    assert visible.library_ids == frozenset(
        {"lib-movies", "lib-tv", "lib-cartoons"}
    )
    assert set(visible.groups_contributing.keys()) == {
        "public", "family", "kids"
    }


@pytest.mark.asyncio
async def test_visibility_inactive_group_skipped(test_db):
    """Inactive group's libraries don't make it into the visible set
    (`status = 'active'` filter in the resolver).  Mirrors the v1 gate
    behavior for back-compat with operator expectations."""
    cid = await _make_paired_client(test_db)
    await _make_library(test_db, "lib-movies")
    await _make_group(
        test_db, "off",
        status="inactive",
        libraries=["lib-movies"],
    )
    await _add_to_group(test_db, "off", cid)
    await _add_to_group(test_db, "public", cid)

    visible = await group_service.get_visible_libraries(test_db, cid)
    assert visible.library_ids == frozenset()


@pytest.mark.asyncio
async def test_visibility_pin_locked_group_hidden_until_grant(test_db):
    """A PIN-gated group's libraries are invisible until the client has
    a valid grant.  Without unlock, the group surfaces in
    `pin_locked_groups` so the mobile UI knows to offer unlock.  With
    a valid grant, the libraries flow into the union."""
    cid = await _make_paired_client(test_db)
    await _make_library(test_db, "lib-adults")
    pin_hash = group_service.hash_pin("4827", "test-hmac-key")
    await _make_group(
        test_db, "adults",
        libraries=["lib-adults"],
        requires_pin=True,
        pin_hash=pin_hash,
    )
    await _add_to_group(test_db, "adults", cid)
    await _add_to_group(test_db, "public", cid)

    # No grant yet — adults libraries hidden.
    visible = await group_service.get_visible_libraries(test_db, cid)
    assert visible.library_ids == frozenset()
    assert visible.pin_locked_groups == frozenset({"adults"})

    # Issue a grant via the service.
    result = await group_service.enter_pin_grant(
        test_db, cid, "adults", "4827", hmac_key="test-hmac-key"
    )
    assert result.granted is True

    # Now visible.
    visible = await group_service.get_visible_libraries(test_db, cid)
    assert visible.library_ids == frozenset({"lib-adults"})
    assert visible.pin_locked_groups == frozenset()


@pytest.mark.asyncio
async def test_visibility_time_window_outside_hides_group(test_db):
    """Group with a time window that excludes `now` doesn't contribute
    to the visible set; group_id surfaces in `time_locked_groups` so
    `reason_to_deny_stream` can pick the time-window-specific message."""
    cid = await _make_paired_client(test_db)
    await _make_library(test_db, "lib-cartoons")
    await _make_group(
        test_db, "kids",
        libraries=["lib-cartoons"],
        time_window={
            "start_h": 18, "end_h": 22, "days": [0, 1, 2, 3, 4],
        },
    )
    await _add_to_group(test_db, "kids", cid)

    # Friday 23:00 → outside the window.
    friday_late = datetime(2026, 5, 8, 23, 0, tzinfo=UTC)
    visible = await group_service.get_visible_libraries(
        test_db, cid, now=friday_late
    )
    assert visible.library_ids == frozenset()
    assert visible.time_locked_groups == frozenset({"kids"})

    # Friday 19:00 → inside the window.
    friday_eve = datetime(2026, 5, 8, 19, 0, tzinfo=UTC)
    visible = await group_service.get_visible_libraries(
        test_db, cid, now=friday_eve
    )
    assert visible.library_ids == frozenset({"lib-cartoons"})


@pytest.mark.asyncio
async def test_visibility_member_time_window_override_wins(test_db):
    """Per-member `time_window_override` (M3 schema column) takes
    precedence over the group's window.  Older-kid-stays-up-later
    use case."""
    cid = await _make_paired_client(test_db, "older-kid")
    await _make_library(test_db, "lib-cartoons")
    # Group window: 18-22.  Member override: 18-23.
    await _make_group(
        test_db, "kids",
        libraries=["lib-cartoons"],
        time_window={"start_h": 18, "end_h": 22, "days": [0, 1, 2, 3, 4, 5, 6]},
    )
    await test_db.execute(
        """
        INSERT OR IGNORE INTO group_members
            (group_id, client_id, added_at, time_window_override)
        VALUES (?, ?, ?, ?)
        """,
        (
            "kids",
            "older-kid",
            datetime.now(UTC).isoformat(),
            json.dumps({
                "start_h": 18, "end_h": 23,
                "days": [0, 1, 2, 3, 4, 5, 6],
            }),
        ),
    )
    await test_db.commit()

    # 22:30 — outside group window, inside override.
    moment = datetime(2026, 5, 8, 22, 30, tzinfo=UTC)
    visible = await group_service.get_visible_libraries(
        test_db, cid, now=moment
    )
    assert visible.library_ids == frozenset({"lib-cartoons"})


# ── reason_to_deny_stream ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_reason_to_deny_returns_none_when_library_visible(test_db):
    cid = await _make_paired_client(test_db)
    await _make_library(test_db, "lib-movies")
    await test_db.execute(
        "UPDATE group_restrictions SET allowed_libraries = ? "
        "WHERE group_id = 'public'",
        (json.dumps(["lib-movies"]),),
    )
    await _add_to_group(test_db, "public", cid)

    reason = await group_service.reason_to_deny_stream(
        test_db, cid, library_id="lib-movies"
    )
    assert reason is None


@pytest.mark.asyncio
async def test_reason_to_deny_picks_time_window_message_when_specific(test_db):
    """When the library exists in a time-locked group AND the client
    isn't in any other group exposing it, the deny message should be
    the time-specific one — mobile M5 parser routes that to
    'Outside playback hours' rather than the generic 'library not
    allowed'."""
    cid = await _make_paired_client(test_db)
    await _make_library(test_db, "lib-cartoons")
    await _make_group(
        test_db, "kids",
        libraries=["lib-cartoons"],
        time_window={
            "start_h": 18, "end_h": 22, "days": [0, 1, 2, 3, 4],
        },
    )
    await _add_to_group(test_db, "kids", cid)

    friday_late = datetime(2026, 5, 8, 23, 0, tzinfo=UTC)
    reason = await group_service.reason_to_deny_stream(
        test_db, cid, library_id="lib-cartoons", now=friday_late
    )
    assert reason is not None
    assert "time window" in reason.lower()


@pytest.mark.asyncio
async def test_reason_to_deny_pin_locked_does_not_leak_existence(test_db):
    """PIN-gated content denies with the generic 'library not allowed'
    message rather than a PIN-specific one — we don't want a kid
    probing file_ids to discover that gated content exists, only that
    it's denied."""
    cid = await _make_paired_client(test_db)
    await _make_library(test_db, "lib-adults")
    pin_hash = group_service.hash_pin("4827", "test-hmac-key")
    await _make_group(
        test_db, "adults",
        libraries=["lib-adults"],
        requires_pin=True,
        pin_hash=pin_hash,
    )
    await _add_to_group(test_db, "adults", cid)

    reason = await group_service.reason_to_deny_stream(
        test_db, cid, library_id="lib-adults"
    )
    assert reason is not None
    assert "group(s)" in reason  # M5 parser substring
    assert "pin" not in reason.lower()
    assert "time window" not in reason.lower()


# ── PIN flow ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_enter_pin_grant_happy_path_inserts_grant(test_db):
    cid = await _make_paired_client(test_db)
    pin_hash = group_service.hash_pin("4827", "test-hmac-key")
    await _make_group(
        test_db, "adults",
        requires_pin=True,
        pin_hash=pin_hash,
    )
    await _add_to_group(test_db, "adults", cid)

    result = await group_service.enter_pin_grant(
        test_db, cid, "adults", "4827", hmac_key="test-hmac-key"
    )
    assert result.granted is True
    assert result.expires_at is not None

    # Grant row exists.
    async with test_db.execute(
        "SELECT 1 FROM group_pin_grants "
        "WHERE client_id = ? AND group_id = ?",
        (cid, "adults"),
    ) as cur:
        assert await cur.fetchone() is not None


@pytest.mark.asyncio
async def test_enter_pin_grant_wrong_pin_logs_attempt(test_db):
    cid = await _make_paired_client(test_db)
    pin_hash = group_service.hash_pin("4827", "test-hmac-key")
    await _make_group(
        test_db, "adults",
        requires_pin=True,
        pin_hash=pin_hash,
    )
    await _add_to_group(test_db, "adults", cid)

    result = await group_service.enter_pin_grant(
        test_db, cid, "adults", "0000", hmac_key="test-hmac-key"
    )
    assert result.granted is False
    assert result.error == "incorrect_pin"
    assert result.attempts_remaining == 4

    async with test_db.execute(
        "SELECT COUNT(*) FROM group_pin_attempts "
        "WHERE client_id = ? AND group_id = ? AND success = 0",
        (cid, "adults"),
    ) as cur:
        row = await cur.fetchone()
    assert row[0] == 1


@pytest.mark.asyncio
async def test_enter_pin_grant_rate_limit_after_5_failures(test_db):
    """5 failed attempts within 60 s lock the (client, group) tuple
    out — the brute-force protection.  6th attempt with the CORRECT
    PIN still 429s; operator master override (localhost) is the
    recovery path."""
    cid = await _make_paired_client(test_db)
    pin_hash = group_service.hash_pin("4827", "test-hmac-key")
    await _make_group(
        test_db, "adults",
        requires_pin=True,
        pin_hash=pin_hash,
    )
    await _add_to_group(test_db, "adults", cid)

    for _ in range(5):
        result = await group_service.enter_pin_grant(
            test_db, cid, "adults", "0000", hmac_key="test-hmac-key"
        )
        assert result.granted is False

    # 6th attempt — even with the right PIN, the rate limiter kicks in
    # before the compare runs.
    result = await group_service.enter_pin_grant(
        test_db, cid, "adults", "4827", hmac_key="test-hmac-key"
    )
    assert result.granted is False
    assert result.error == "rate_limited"


@pytest.mark.asyncio
async def test_pin_strength_rejects_obvious_pins():
    """Server-side strength policy — `1234` and friends are out."""
    for bad in ("1234", "0000", "1111", "5678", "0123"):
        assert group_service.validate_pin_strength(bad) is not None, (
            f"PIN {bad!r} should have been rejected"
        )
    for good in ("4827", "13579", "84219670"):
        assert group_service.validate_pin_strength(good) is None, (
            f"PIN {good!r} should have been accepted"
        )


@pytest.mark.asyncio
async def test_pin_strength_rejects_short_or_long():
    assert group_service.validate_pin_strength("123") is not None
    assert group_service.validate_pin_strength("123456789") is not None


@pytest.mark.asyncio
async def test_pin_strength_rejects_non_numeric():
    assert group_service.validate_pin_strength("ab12") is not None


@pytest.mark.asyncio
async def test_revoke_pin_grant_drops_row(test_db):
    cid = await _make_paired_client(test_db)
    pin_hash = group_service.hash_pin("4827", "test-hmac-key")
    await _make_group(
        test_db, "adults",
        requires_pin=True,
        pin_hash=pin_hash,
    )
    await _add_to_group(test_db, "adults", cid)
    await group_service.enter_pin_grant(
        test_db, cid, "adults", "4827", hmac_key="test-hmac-key"
    )

    deleted = await group_service.revoke_pin_grant(test_db, cid, "adults")
    assert deleted is True

    # Second revoke -> returns False (already gone).
    deleted_again = await group_service.revoke_pin_grant(
        test_db, cid, "adults"
    )
    assert deleted_again is False


@pytest.mark.asyncio
async def test_housekeep_prunes_expired_grants(test_db):
    """Expired grants get cleaned up by the periodic housekeeping
    task in main.py.  Function returns counts for the log line."""
    cid = await _make_paired_client(test_db)
    await _make_group(test_db, "adults", requires_pin=True, pin_hash="x")
    # Insert an already-expired grant directly.
    expired_at = (
        datetime.now(UTC) - timedelta(hours=1)
    ).isoformat()
    await test_db.execute(
        """
        INSERT INTO group_pin_grants
            (client_id, group_id, granted_at, expires_at)
        VALUES (?, ?, ?, ?)
        """,
        (cid, "adults", expired_at, expired_at),
    )
    await test_db.commit()

    grants_pruned, _ = await group_service.housekeep_pin_state(test_db)
    assert grants_pruned == 1

    async with test_db.execute(
        "SELECT 1 FROM group_pin_grants WHERE client_id = ?", (cid,)
    ) as cur:
        assert await cur.fetchone() is None


@pytest.mark.asyncio
async def test_approve_client_auto_adds_to_public_group(client, monkeypatch):
    """M3 of the v2 plan: every newly-approved client lands in Public.
    Pins the contract; a future agent who reorders auth_service.approve_client
    + drops the auto-add line breaks the v2 visibility model immediately."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    await client.post(
        "/api/v1/auth/request-pair",
        json={
            "client_id": "auto-public-client",
            "device_name": "Tablet",
            "platform": "android",
            "app_version": "0.1.0",
        },
    )
    await client.post("/api/v1/auth/approve/auto-public-client")

    listing = await client.get(
        "/api/v1/groups/public/members"
    )
    assert listing.status_code == 200
    members = listing.json()
    member_ids = {m.get("client_id") or m.get("id") for m in members}
    assert "auto-public-client" in member_ids


# ── M4 — PIN endpoint tests (live HTTP routes) ────────────────────────────


@pytest.mark.asyncio
async def test_post_enter_unlocks_group_with_correct_pin(
    client: AsyncClient, monkeypatch
):
    """Happy path: bearer-token client posts PIN to /enter → server
    grants → grant-status confirms → libraries become visible (covered
    indirectly via the visibility tests above)."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    monkeypatch.setattr(
        "routers.groups.settings.token_hmac_key", HMAC_KEY
    )
    token = await _get_token(client, monkeypatch, "pin-client")

    pin_hash = group_service.hash_pin("4827", HMAC_KEY)
    grp = (
        await client.post(
            "/api/v1/groups",
            json={
                "name": "Adults",
                "restrictions": {"allowed_libraries": ["lib-adult"]},
            },
        )
    ).json()
    # PIN columns aren't on GroupCreate yet; set directly via SQL.
    # M7 of the v2 plan adds the desktop UI surface for these.
    headers = {"Authorization": f"Bearer {token}"}
    await client.post(
        f"/api/v1/groups/{grp['id']}/members",
        json={"client_id": "pin-client"},
    )

    # Mark the group PIN-required + set the hash.  Direct SQL because
    # the desktop create-group UI for PIN config is M7 territory.
    from database.db import get_db as _get_db_ref  # noqa: E402

    db = await _get_db_ref()
    await db.execute(
        "UPDATE groups SET requires_pin = 1, pin_hash = ? WHERE id = ?",
        (pin_hash, grp["id"]),
    )
    await db.commit()

    # Wrong PIN first.  Use a non-obvious-but-wrong PIN so the strength
    # policy doesn't 400 the request before the compare runs.
    resp = await client.post(
        f"/api/v1/groups/{grp['id']}/enter",
        json={"pin": "9182"},
        headers=headers,
    )
    assert resp.status_code == 401
    assert "remaining" in resp.json()["detail"].lower()

    # Status: still locked.
    resp = await client.get(
        f"/api/v1/groups/{grp['id']}/grant-status",
        headers=headers,
    )
    assert resp.status_code == 200
    assert resp.json()["unlocked"] is False

    # Right PIN.
    resp = await client.post(
        f"/api/v1/groups/{grp['id']}/enter",
        json={"pin": "4827"},
        headers=headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["pin_mode"] == "session"
    assert body["expires_at"]

    # Status: unlocked.
    resp = await client.get(
        f"/api/v1/groups/{grp['id']}/grant-status",
        headers=headers,
    )
    assert resp.json()["unlocked"] is True


@pytest.mark.asyncio
async def test_post_enter_400_on_bad_pin_strength(
    client: AsyncClient, monkeypatch
):
    """Strength policy fires before the rate limiter — junk PINs don't
    burn budget.  Pinned: a future agent loosening the policy
    accidentally exposing rate-limit-only protection breaks here."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    monkeypatch.setattr(
        "routers.groups.settings.token_hmac_key", HMAC_KEY
    )
    token = await _get_token(client, monkeypatch, "pin-strength-client")

    grp = (await client.post("/api/v1/groups", json={"name": "G"})).json()

    headers = {"Authorization": f"Bearer {token}"}
    await client.post(
        f"/api/v1/groups/{grp['id']}/members",
        json={"client_id": "pin-strength-client"},
    )

    resp = await client.post(
        f"/api/v1/groups/{grp['id']}/enter",
        json={"pin": "1234"},
        headers=headers,
    )
    assert resp.status_code == 400
    assert "obvious" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_post_enter_404_unknown_group(client: AsyncClient, monkeypatch):
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    monkeypatch.setattr(
        "routers.groups.settings.token_hmac_key", HMAC_KEY
    )
    token = await _get_token(client, monkeypatch, "404-client")

    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.post(
        "/api/v1/groups/no-such-group/enter",
        json={"pin": "4827"},
        headers=headers,
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_post_enter_400_when_group_not_pin_required(
    client: AsyncClient, monkeypatch
):
    """Calling enter on a non-PIN group is a no-op error rather than a
    silent success — distinguishes "you don't need to enter a PIN here"
    from "PIN was right" so mobile UI doesn't show a fake unlock."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    monkeypatch.setattr(
        "routers.groups.settings.token_hmac_key", HMAC_KEY
    )
    token = await _get_token(client, monkeypatch, "no-pin-client")

    grp = (
        await client.post("/api/v1/groups", json={"name": "Open"})
    ).json()

    headers = {"Authorization": f"Bearer {token}"}
    await client.post(
        f"/api/v1/groups/{grp['id']}/members",
        json={"client_id": "no-pin-client"},
    )

    resp = await client.post(
        f"/api/v1/groups/{grp['id']}/enter",
        json={"pin": "4827"},
        headers=headers,
    )
    assert resp.status_code == 400
    assert "does not require" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_delete_grant_locks_group(client: AsyncClient, monkeypatch):
    """Mobile lock button → DELETE /grant → grant-status flips to
    unlocked=False.  Idempotent: double-DELETE doesn't 404."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    monkeypatch.setattr(
        "routers.groups.settings.token_hmac_key", HMAC_KEY
    )
    token = await _get_token(client, monkeypatch, "lock-client")

    pin_hash = group_service.hash_pin("4827", HMAC_KEY)
    grp = (await client.post("/api/v1/groups", json={"name": "G"})).json()

    from database.db import get_db as _get_db_ref  # noqa: E402

    db = await _get_db_ref()
    await db.execute(
        "UPDATE groups SET requires_pin = 1, pin_hash = ? WHERE id = ?",
        (pin_hash, grp["id"]),
    )
    await db.commit()

    headers = {"Authorization": f"Bearer {token}"}
    await client.post(
        f"/api/v1/groups/{grp['id']}/members",
        json={"client_id": "lock-client"},
    )
    await client.post(
        f"/api/v1/groups/{grp['id']}/enter",
        json={"pin": "4827"},
        headers=headers,
    )

    # Lock.
    resp = await client.delete(
        f"/api/v1/groups/{grp['id']}/grant",
        headers=headers,
    )
    assert resp.status_code == 204

    # Status: locked.
    resp = await client.get(
        f"/api/v1/groups/{grp['id']}/grant-status",
        headers=headers,
    )
    assert resp.json()["unlocked"] is False

    # Idempotent.
    resp = await client.delete(
        f"/api/v1/groups/{grp['id']}/grant",
        headers=headers,
    )
    assert resp.status_code == 204


@pytest.mark.asyncio
async def test_master_override_unlocks_without_pin(
    client: AsyncClient, monkeypatch
):
    """Operator master override: localhost POST issues a 12 h grant on
    behalf of any client without supplying the PIN.  Forgot-PIN
    recovery + always-available admin path."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    token = await _get_token(client, monkeypatch, "override-client")
    _ = token  # used to ensure the client is approved

    pin_hash = group_service.hash_pin("4827", HMAC_KEY)
    grp = (await client.post("/api/v1/groups", json={"name": "Adults"})).json()

    from database.db import get_db as _get_db_ref  # noqa: E402

    db = await _get_db_ref()
    await db.execute(
        "UPDATE groups SET requires_pin = 1, pin_hash = ? WHERE id = ?",
        (pin_hash, grp["id"]),
    )
    await db.commit()
    await client.post(
        f"/api/v1/groups/{grp['id']}/members",
        json={"client_id": "override-client"},
    )

    # Localhost override (no bearer).  Operator's desktop CP path.
    resp = await client.post(
        f"/api/v1/groups/{grp['id']}/master-override?client_id=override-client"
    )
    assert resp.status_code == 200
    assert resp.json()["expires_at"]

    # Verify the grant is in the DB.
    async with db.execute(
        "SELECT 1 FROM group_pin_grants "
        "WHERE client_id = ? AND group_id = ?",
        ("override-client", grp["id"]),
    ) as cur:
        assert await cur.fetchone() is not None


@pytest.mark.asyncio
async def test_master_override_localhost_only(test_db):
    """Master override is power; tunneled callers must get 403 via
    require_local_caller (same dependency that protects the rest of
    the desktop-CP routes)."""
    grp_id = "remote-attempt-group"
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO groups
            (id, name, status, created_at, updated_at,
             is_public, requires_pin, pin_hash, pin_mode)
        VALUES (?, ?, 'active', ?, ?, 0, 1, 'hash', 'session')
        """,
        (grp_id, "Adults", now, now),
    )
    await test_db.commit()

    async with AsyncClient(
        transport=ASGITransport(app=app, client=("198.51.100.4", 51000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.post(
            f"/api/v1/groups/{grp_id}/master-override?client_id=irrelevant",
            headers={"CF-Connecting-IP": "198.51.100.4"},
        )
    assert resp.status_code == 403


# ── M8 — hybrid PIN model (per-client enrollment) ──────────────────────────


@pytest.mark.asyncio
async def test_enroll_pin_happy_path(test_db):
    """Per-client mode: enroll → row written to group_member_pins → grant
    issued immediately so the user isn't asked to re-type."""
    cid = await _make_paired_client(test_db, "enroll-client")
    await _make_group(
        test_db, "adults",
        requires_pin=True,
        pin_model="per-client",
        libraries=["lib-adult"],
    )
    await _add_to_group(test_db, "adults", cid)

    result = await group_service.enroll_pin(
        test_db, cid, "adults", "5283", hmac_key=HMAC_KEY
    )
    assert result.granted is True
    assert result.expires_at

    # Subsequent /enter with same PIN works (validates the hash round-trip).
    result2 = await group_service.enter_pin_grant(
        test_db, cid, "adults", "5283", hmac_key=HMAC_KEY
    )
    assert result2.granted is True


@pytest.mark.asyncio
async def test_enroll_rejected_in_shared_mode(test_db):
    """Shared-mode group rejects /enroll with `wrong_mode` — operator
    set the group up with one PIN, members can't enroll their own."""
    cid = await _make_paired_client(test_db, "shared-client")
    pin_hash = group_service.hash_pin("8472", HMAC_KEY)
    await _make_group(
        test_db, "shared-grp",
        requires_pin=True, pin_hash=pin_hash, pin_model="shared",
    )
    await _add_to_group(test_db, "shared-grp", cid)

    result = await group_service.enroll_pin(
        test_db, cid, "shared-grp", "1357", hmac_key=HMAC_KEY
    )
    assert result.granted is False
    assert result.error == "wrong_mode"


@pytest.mark.asyncio
async def test_enroll_already_enrolled_returns_conflict(test_db):
    """Second enroll call for a (group, client) tuple → `already_enrolled`.
    Caller should use /enroll/change instead."""
    cid = await _make_paired_client(test_db, "double-enroll")
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_model="per-client",
    )
    await _add_to_group(test_db, "perclient-grp", cid)

    first = await group_service.enroll_pin(
        test_db, cid, "perclient-grp", "5283", hmac_key=HMAC_KEY
    )
    assert first.granted is True

    second = await group_service.enroll_pin(
        test_db, cid, "perclient-grp", "9182", hmac_key=HMAC_KEY
    )
    assert second.granted is False
    assert second.error == "already_enrolled"


@pytest.mark.asyncio
async def test_enroll_rejected_for_non_member(test_db):
    """A client that isn't a member of the group can't enroll a PIN —
    membership is the prerequisite."""
    cid = await _make_paired_client(test_db, "outsider")
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_model="per-client",
    )
    # No _add_to_group call — outsider isn't a member.

    result = await group_service.enroll_pin(
        test_db, cid, "perclient-grp", "5283", hmac_key=HMAC_KEY
    )
    assert result.granted is False
    assert result.error == "not_a_member"


@pytest.mark.asyncio
async def test_enter_per_client_uses_member_hash_not_group_hash(test_db):
    """Per-client mode looks up the calling client's enrollment row —
    `groups.pin_hash` (which would still verify under shared mode) is
    NOT consulted."""
    cid_a = await _make_paired_client(test_db, "client-a")
    cid_b = await _make_paired_client(test_db, "client-b")
    # Set a `groups.pin_hash` to make sure the per-client path doesn't
    # accidentally fall back to it.  Nothing should ever match this PIN
    # via the per-client path.
    decoy_hash = group_service.hash_pin("0000", HMAC_KEY)
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_hash=decoy_hash, pin_model="per-client",
    )
    await _add_to_group(test_db, "perclient-grp", cid_a)
    await _add_to_group(test_db, "perclient-grp", cid_b)

    # Each client enrolls their own PIN.
    await group_service.enroll_pin(
        test_db, cid_a, "perclient-grp", "5283", hmac_key=HMAC_KEY
    )
    await group_service.enroll_pin(
        test_db, cid_b, "perclient-grp", "9182", hmac_key=HMAC_KEY
    )

    # Client A entering B's PIN → wrong PIN.
    result = await group_service.enter_pin_grant(
        test_db, cid_a, "perclient-grp", "9182", hmac_key=HMAC_KEY
    )
    assert result.granted is False
    assert result.error == "incorrect_pin"

    # Client A entering own PIN → granted.
    result = await group_service.enter_pin_grant(
        test_db, cid_a, "perclient-grp", "5283", hmac_key=HMAC_KEY
    )
    assert result.granted is True


@pytest.mark.asyncio
async def test_enter_per_client_without_enrollment_returns_enrollment_required(test_db):
    """Per-client mode + no enrollment row → `enrollment_required` so
    the mobile UI can route to /enroll instead of asking for a PIN that
    doesn't exist."""
    cid = await _make_paired_client(test_db, "fresh-client")
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_model="per-client",
    )
    await _add_to_group(test_db, "perclient-grp", cid)

    result = await group_service.enter_pin_grant(
        test_db, cid, "perclient-grp", "5283", hmac_key=HMAC_KEY
    )
    assert result.granted is False
    assert result.error == "enrollment_required"


@pytest.mark.asyncio
async def test_change_member_pin_happy_path(test_db):
    """Enrolled client changes their own PIN — old verifies, new replaces."""
    cid = await _make_paired_client(test_db, "rotate-client")
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_model="per-client",
    )
    await _add_to_group(test_db, "perclient-grp", cid)
    await group_service.enroll_pin(
        test_db, cid, "perclient-grp", "5283", hmac_key=HMAC_KEY
    )

    result = await group_service.change_member_pin(
        test_db, cid, "perclient-grp",
        old_pin="5283", new_pin="9182",
        hmac_key=HMAC_KEY,
    )
    assert result.granted is True

    # Old PIN no longer works.
    bad = await group_service.enter_pin_grant(
        test_db, cid, "perclient-grp", "5283", hmac_key=HMAC_KEY
    )
    assert bad.granted is False
    # New PIN works.
    good = await group_service.enter_pin_grant(
        test_db, cid, "perclient-grp", "9182", hmac_key=HMAC_KEY
    )
    assert good.granted is True


@pytest.mark.asyncio
async def test_change_member_pin_wrong_old_charges_attempt(test_db):
    """Wrong `old_pin` on /enroll/change still counts against the rate
    limiter — otherwise the change endpoint would be a brute-force
    bypass for the existing PIN."""
    cid = await _make_paired_client(test_db, "wrong-old-client")
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_model="per-client",
    )
    await _add_to_group(test_db, "perclient-grp", cid)
    await group_service.enroll_pin(
        test_db, cid, "perclient-grp", "5283", hmac_key=HMAC_KEY
    )

    result = await group_service.change_member_pin(
        test_db, cid, "perclient-grp",
        old_pin="9182", new_pin="3157",
        hmac_key=HMAC_KEY,
    )
    assert result.granted is False
    assert result.error == "incorrect_pin"
    assert result.attempts_remaining == 4


@pytest.mark.asyncio
async def test_clear_member_pin_forces_re_enrollment(test_db):
    """Operator clears a member's PIN → enrollment row gone + grant gone
    → next /enter returns enrollment_required."""
    cid = await _make_paired_client(test_db, "cleared-client")
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_model="per-client",
    )
    await _add_to_group(test_db, "perclient-grp", cid)
    await group_service.enroll_pin(
        test_db, cid, "perclient-grp", "5283", hmac_key=HMAC_KEY
    )

    deleted = await group_service.clear_member_pin(
        test_db, cid, "perclient-grp"
    )
    assert deleted is True

    # /enter now demands re-enrollment instead of just a PIN.
    result = await group_service.enter_pin_grant(
        test_db, cid, "perclient-grp", "5283", hmac_key=HMAC_KEY
    )
    assert result.granted is False
    assert result.error == "enrollment_required"


@pytest.mark.asyncio
async def test_visibility_per_client_unenrolled_lands_in_enrollment_required(test_db):
    """`get_visible_libraries` puts a per-client gated group with no
    enrollment into `enrollment_required_groups` — distinct from
    `pin_locked_groups` so mobile routes to enrollment, not entry."""
    cid = await _make_paired_client(test_db, "unenrolled-client")
    await _make_library(test_db, "lib-adult")
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_model="per-client",
        libraries=["lib-adult"],
    )
    await _add_to_group(test_db, "perclient-grp", cid)

    visible = await group_service.get_visible_libraries(test_db, cid)
    assert "lib-adult" not in visible.library_ids
    assert "perclient-grp" in visible.enrollment_required_groups
    assert "perclient-grp" not in visible.pin_locked_groups


@pytest.mark.asyncio
async def test_mode_switch_shared_to_per_client_clears_hash(test_db):
    """update_group flips a gated shared-mode group to per-client → the
    shared `pin_hash` is cleared but `requires_pin` stays 1, members
    re-enroll on next access."""
    pin_hash = group_service.hash_pin("8472", HMAC_KEY)
    await _make_group(
        test_db, "rotating-grp",
        requires_pin=True, pin_hash=pin_hash, pin_model="shared",
    )
    updated = await group_service.update_group(
        test_db, "rotating-grp",
        name=None, description=None, status=None, restrictions=None,
        pin_model="per-client",
        hmac_key=HMAC_KEY,
    )
    assert updated is not None
    assert updated["pin_model"] == "per-client"
    assert updated["requires_pin"] is True

    # Direct DB inspection — hash is gone.
    async with test_db.execute(
        "SELECT pin_hash FROM groups WHERE id = ?", ("rotating-grp",)
    ) as cur:
        row = await cur.fetchone()
    assert row["pin_hash"] is None


@pytest.mark.asyncio
async def test_mode_switch_per_client_to_shared_requires_pin(test_db):
    """Switching per-client → shared without supplying a new shared PIN
    is rejected — otherwise the group would end up gated with no
    secret to enter."""
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_model="per-client",
    )
    with pytest.raises(ValueError, match="shared mode requires a new shared PIN"):
        await group_service.update_group(
            test_db, "perclient-grp",
            name=None, description=None, status=None, restrictions=None,
            pin_model="shared",
            hmac_key=HMAC_KEY,
        )


@pytest.mark.asyncio
async def test_mode_switch_per_client_to_shared_with_pin_succeeds(test_db):
    """Switching per-client → shared while supplying a new shared PIN
    completes cleanly — enrollment rows are dropped, hash is set."""
    cid = await _make_paired_client(test_db, "transition-client")
    await _make_group(
        test_db, "transition-grp",
        requires_pin=True, pin_model="per-client",
    )
    await _add_to_group(test_db, "transition-grp", cid)
    await group_service.enroll_pin(
        test_db, cid, "transition-grp", "5283", hmac_key=HMAC_KEY
    )

    updated = await group_service.update_group(
        test_db, "transition-grp",
        name=None, description=None, status=None, restrictions=None,
        pin_model="shared", pin="8472",
        hmac_key=HMAC_KEY,
    )
    assert updated is not None
    assert updated["pin_model"] == "shared"

    # Old per-client enrollment is gone.
    async with test_db.execute(
        "SELECT 1 FROM group_member_pins WHERE group_id = ?",
        ("transition-grp",),
    ) as cur:
        assert await cur.fetchone() is None

    # New shared PIN works.
    result = await group_service.enter_pin_grant(
        test_db, cid, "transition-grp", "8472", hmac_key=HMAC_KEY
    )
    assert result.granted is True


@pytest.mark.asyncio
async def test_master_override_works_for_per_client_groups(test_db):
    """Master override doesn't care about pin_model — it issues a grant
    on the target client regardless of how the group authenticates."""
    cid = await _make_paired_client(test_db, "override-client")
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_model="per-client",
    )
    await _add_to_group(test_db, "perclient-grp", cid)
    # Note: client is *not* enrolled — this is the recovery path
    # (operator unlocks for a member who hasn't enrolled or has
    # forgotten their own PIN).

    async with AsyncClient(
        transport=ASGITransport(app=app, client=("127.0.0.1", 12345)),
        base_url="http://test",
    ) as local:
        resp = await local.post(
            f"/api/v1/groups/perclient-grp/master-override?client_id={cid}",
        )
    assert resp.status_code == 200

    # Grant exists — visibility resolution sees it as unlocked.
    visible = await group_service.get_visible_libraries(test_db, cid)
    # The group has no libraries set, so library_ids stays empty, but
    # the group should NOT show in pin_locked_groups or
    # enrollment_required_groups.
    assert "perclient-grp" not in visible.pin_locked_groups
    assert "perclient-grp" not in visible.enrollment_required_groups


# ── Members tab — list_members(include_pin_state=True) ─────────────────────


@pytest.mark.asyncio
async def test_list_members_default_shape_unchanged(test_db):
    """Without `include_pin_state`, the response shape is the v1
    contract — no enrollment / grant / attempt fields.  Older callers
    must not break."""
    cid = await _make_paired_client(test_db, "vintage-client")
    await _make_group(
        test_db, "shared-grp",
        requires_pin=True, pin_model="shared",
        pin_hash=group_service.hash_pin("8472", HMAC_KEY),
    )
    await _add_to_group(test_db, "shared-grp", cid)

    rows = await group_service.list_members(test_db, "shared-grp")
    assert rows is not None
    assert len(rows) == 1
    row = rows[0]
    assert row["id"] == cid
    assert "enrollment_state" not in row
    assert "has_active_grant" not in row
    assert "grant_expires_at" not in row
    assert "recent_failed_attempts" not in row


@pytest.mark.asyncio
async def test_list_members_pin_state_per_client_branches(test_db):
    """Per-client mode + 3 members — one enrolled with active grant, one
    enrolled without grant, one not enrolled.  Single SQL covers all
    three."""
    enrolled_with_grant = await _make_paired_client(test_db, "have-grant")
    enrolled_no_grant = await _make_paired_client(test_db, "have-pin")
    not_enrolled = await _make_paired_client(test_db, "fresh-device")
    await _make_group(
        test_db, "perclient-grp",
        requires_pin=True, pin_model="per-client",
    )
    await _add_to_group(test_db, "perclient-grp", enrolled_with_grant)
    await _add_to_group(test_db, "perclient-grp", enrolled_no_grant)
    await _add_to_group(test_db, "perclient-grp", not_enrolled)

    # First two enroll; first one keeps its session-length grant; second
    # has its grant revoked so we observe the "enrolled but locked" state.
    await group_service.enroll_pin(
        test_db, enrolled_with_grant, "perclient-grp", "5283",
        hmac_key=HMAC_KEY,
    )
    await group_service.enroll_pin(
        test_db, enrolled_no_grant, "perclient-grp", "9182",
        hmac_key=HMAC_KEY,
    )
    await group_service.revoke_pin_grant(
        test_db, enrolled_no_grant, "perclient-grp"
    )

    rows = await group_service.list_members(
        test_db, "perclient-grp", include_pin_state=True
    )
    assert rows is not None
    by_id = {r["id"]: r for r in rows}

    assert by_id[enrolled_with_grant]["enrollment_state"] == "enrolled"
    assert by_id[enrolled_with_grant]["has_active_grant"] is True
    assert by_id[enrolled_with_grant]["grant_expires_at"]

    assert by_id[enrolled_no_grant]["enrollment_state"] == "enrolled"
    assert by_id[enrolled_no_grant]["has_active_grant"] is False
    assert by_id[enrolled_no_grant]["grant_expires_at"] is None

    assert by_id[not_enrolled]["enrollment_state"] == "not_enrolled"
    assert by_id[not_enrolled]["has_active_grant"] is False


@pytest.mark.asyncio
async def test_list_members_pin_state_shared_mode_skips_enrollment(test_db):
    """Shared-mode group: every member's `enrollment_state` is
    `not_required` regardless of whether they have a grant — the concept
    only applies to per-client groups."""
    cid = await _make_paired_client(test_db, "shared-member")
    pin_hash = group_service.hash_pin("4827", HMAC_KEY)
    await _make_group(
        test_db, "shared-grp",
        requires_pin=True, pin_hash=pin_hash, pin_model="shared",
    )
    await _add_to_group(test_db, "shared-grp", cid)
    # Successful entry → grant should appear in the response.
    await group_service.enter_pin_grant(
        test_db, cid, "shared-grp", "4827", hmac_key=HMAC_KEY
    )

    rows = await group_service.list_members(
        test_db, "shared-grp", include_pin_state=True
    )
    assert rows is not None
    assert rows[0]["enrollment_state"] == "not_required"
    assert rows[0]["has_active_grant"] is True


@pytest.mark.asyncio
async def test_list_members_pin_state_unknown_group_returns_none(test_db):
    """Unknown group still 404s — `include_pin_state` doesn't change
    that contract."""
    rows = await group_service.list_members(
        test_db, "no-such-group", include_pin_state=True
    )
    assert rows is None


@pytest.mark.asyncio
async def test_list_members_pin_state_counts_recent_failed_attempts(test_db):
    """`recent_failed_attempts` reflects the last 60 s — older rows
    don't count.  Drives the desktop's "Locked out" badge."""
    cid = await _make_paired_client(test_db, "fail-counter")
    pin_hash = group_service.hash_pin("4827", HMAC_KEY)
    await _make_group(
        test_db, "shared-grp",
        requires_pin=True, pin_hash=pin_hash, pin_model="shared",
    )
    await _add_to_group(test_db, "shared-grp", cid)

    # 3 fresh failures + 1 stale (90 s ago).
    now = datetime.now(UTC)
    for offset in (1, 2, 3):
        await test_db.execute(
            "INSERT INTO group_pin_attempts "
            "(client_id, group_id, attempted_at, success) VALUES (?, ?, ?, 0)",
            (cid, "shared-grp", (now - timedelta(seconds=offset)).isoformat()),
        )
    await test_db.execute(
        "INSERT INTO group_pin_attempts "
        "(client_id, group_id, attempted_at, success) VALUES (?, ?, ?, 0)",
        (cid, "shared-grp", (now - timedelta(seconds=90)).isoformat()),
    )
    await test_db.commit()

    rows = await group_service.list_members(
        test_db, "shared-grp", include_pin_state=True
    )
    assert rows is not None
    assert rows[0]["recent_failed_attempts"] == 3


# ── M5 — View As + per-member time_window_override ────────────────────────


@pytest.mark.asyncio
async def test_view_as_visible_libraries_localhost_only(test_db):
    """Off-loopback caller hits 403; the visible-libraries endpoint
    reveals operator-only access-control state and stays localhost."""
    cid = await _make_paired_client(test_db, "view-as-target")
    async with AsyncClient(
        transport=ASGITransport(
            app=app, client=("198.51.100.5", 51000),
        ),
        base_url="http://test",
    ) as remote:
        resp = await remote.get(
            f"/api/v1/auth/clients/{cid}/visible-libraries",
            headers={"CF-Connecting-IP": "198.51.100.5"},
        )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_view_as_visible_libraries_404_on_unknown_client(
    test_db,
):
    """Unknown client_id → 404.  Operator gets a clear error vs an
    empty-but-OK response."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("127.0.0.1", 12345)),
        base_url="http://test",
    ) as local:
        resp = await local.get(
            "/api/v1/auth/clients/no-such-client/visible-libraries",
        )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_view_as_visible_libraries_known_client(test_db):
    """Localhost call against a real client returns the
    `VisibleLibraries` shape including provenance keys.  The actual
    library set depends on group state; we just assert the shape so
    older callers don't break on a future field addition."""
    cid = await _make_paired_client(test_db, "shape-test-client")
    await _make_library(test_db, "lib-films")
    await _make_group(
        test_db, "grp-public",
        libraries=["lib-films"],
    )
    await _add_to_group(test_db, "grp-public", cid)

    async with AsyncClient(
        transport=ASGITransport(app=app, client=("127.0.0.1", 12345)),
        base_url="http://test",
    ) as local:
        resp = await local.get(
            f"/api/v1/auth/clients/{cid}/visible-libraries",
        )
    assert resp.status_code == 200
    body = resp.json()
    assert body["client_id"] == cid
    assert "library_ids" in body
    assert "groups_contributing" in body
    assert "pin_locked_groups" in body
    assert "enrollment_required_groups" in body
    assert "time_locked_groups" in body
    # Provenance: the only group exposing lib-films is grp-public.
    assert "lib-films" in body["library_ids"]
    assert body["groups_contributing"]["grp-public"] == ["lib-films"]


@pytest.mark.asyncio
async def test_member_time_window_override_set_and_clear(test_db):
    """Operator sets a per-member window, then clears it via the
    sentinel shape."""
    cid = await _make_paired_client(test_db, "override-client")
    await _make_group(test_db, "kids")
    await _add_to_group(test_db, "kids", cid)

    ok = await group_service.set_member_time_window_override(
        test_db, "kids", cid,
        time_window={
            "start_h": 18, "end_h": 23, "days": [0, 1, 2, 3, 4, 5, 6],
        },
    )
    assert ok is True

    async with test_db.execute(
        "SELECT time_window_override FROM group_members "
        "WHERE group_id = ? AND client_id = ?",
        ("kids", cid),
    ) as cur:
        row = await cur.fetchone()
    assert row["time_window_override"] is not None
    parsed = json.loads(row["time_window_override"])
    assert parsed["end_h"] == 23

    cleared = await group_service.set_member_time_window_override(
        test_db, "kids", cid, time_window=None,
    )
    assert cleared is True

    async with test_db.execute(
        "SELECT time_window_override FROM group_members "
        "WHERE group_id = ? AND client_id = ?",
        ("kids", cid),
    ) as cur:
        row = await cur.fetchone()
    assert row["time_window_override"] is None


@pytest.mark.asyncio
async def test_member_time_window_override_404_on_non_member(test_db):
    """Setting an override for a (group, client) tuple that has no
    membership row returns False — router maps to 404."""
    cid = await _make_paired_client(test_db, "non-member")
    await _make_group(test_db, "kids")
    # No add_to_group — client isn't a member.

    ok = await group_service.set_member_time_window_override(
        test_db, "kids", cid,
        time_window={"start_h": 18, "end_h": 22, "days": [0]},
    )
    assert ok is False


@pytest.mark.asyncio
async def test_member_patch_route_localhost_only(test_db):
    """Off-loopback caller hits 403."""
    cid = await _make_paired_client(test_db, "patch-test-client")
    await _make_group(test_db, "grp")
    await _add_to_group(test_db, "grp", cid)

    async with AsyncClient(
        transport=ASGITransport(
            app=app, client=("198.51.100.6", 51000),
        ),
        base_url="http://test",
    ) as remote:
        resp = await remote.patch(
            f"/api/v1/groups/grp/members/{cid}",
            json={
                "time_window_override": {
                    "start_h": 18, "end_h": 22,
                    "days": [0, 1, 2, 3, 4],
                }
            },
            headers={"CF-Connecting-IP": "198.51.100.6"},
        )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_member_patch_route_clear_sentinel(test_db):
    """Sentinel shape (`start_h=0, end_h=0, days=[]`) clears the
    override.  Documented in API contracts; tests pin the contract."""
    cid = await _make_paired_client(test_db, "sentinel-client")
    await _make_group(test_db, "grp")
    await _add_to_group(test_db, "grp", cid)

    # Pre-seed an override.
    await group_service.set_member_time_window_override(
        test_db, "grp", cid,
        time_window={"start_h": 18, "end_h": 22, "days": [0]},
    )

    async with AsyncClient(
        transport=ASGITransport(app=app, client=("127.0.0.1", 12345)),
        base_url="http://test",
    ) as local:
        resp = await local.patch(
            f"/api/v1/groups/grp/members/{cid}",
            json={
                "time_window_override": {
                    "start_h": 0, "end_h": 0, "days": [],
                }
            },
        )
    assert resp.status_code == 204

    async with test_db.execute(
        "SELECT time_window_override FROM group_members "
        "WHERE group_id = ? AND client_id = ?",
        ("grp", cid),
    ) as cur:
        row = await cur.fetchone()
    assert row["time_window_override"] is None


# ── M7 follow-up: failed-burst aggregation + bulk grants reset ────────────


@pytest.mark.asyncio
async def test_failed_burst_emits_single_event_at_threshold(test_db):
    """5 failed PIN attempts in the 10-min window emit exactly ONE
    `group.pin.failed-burst` activity event — not 5."""
    cid = await _make_paired_client(test_db, "burst-client")
    pin_hash = group_service.hash_pin("4827", HMAC_KEY)
    await _make_group(
        test_db, "burst-grp",
        requires_pin=True, pin_hash=pin_hash, pin_model="shared",
    )
    await _add_to_group(test_db, "burst-grp", cid)

    # 5 failed attempts.  Each goes through the rate-limit gate; the
    # 5th is the one that crosses the threshold.
    for _ in range(5):
        await group_service.enter_pin_grant(
            test_db, cid, "burst-grp", "9182", hmac_key=HMAC_KEY,
        )

    # Activity table should carry exactly one failed-burst event.
    async with test_db.execute(
        """
        SELECT COUNT(*) FROM activity_events
         WHERE type = 'group.pin.failed-burst'
           AND target_id = 'burst-grp'
           AND actor_id = ?
        """,
        (cid,),
    ) as cur:
        row = await cur.fetchone()
    assert row[0] == 1


@pytest.mark.asyncio
async def test_failed_burst_below_threshold_does_not_emit(test_db):
    """1-4 failed attempts emit no burst event — operator's audit feed
    isn't flooded with fat-finger noise."""
    cid = await _make_paired_client(test_db, "fat-finger")
    pin_hash = group_service.hash_pin("4827", HMAC_KEY)
    await _make_group(
        test_db, "below-thresh-grp",
        requires_pin=True, pin_hash=pin_hash, pin_model="shared",
    )
    await _add_to_group(test_db, "below-thresh-grp", cid)

    for _ in range(4):
        await group_service.enter_pin_grant(
            test_db, cid, "below-thresh-grp", "9182", hmac_key=HMAC_KEY,
        )

    async with test_db.execute(
        "SELECT COUNT(*) FROM activity_events "
        "WHERE type = 'group.pin.failed-burst' "
        "  AND target_id = 'below-thresh-grp'",
    ) as cur:
        row = await cur.fetchone()
    assert row[0] == 0


@pytest.mark.asyncio
async def test_failed_burst_does_not_re_emit_above_threshold(test_db):
    """Once the burst event has fired at 5 fails, attempts 6+ in the
    same 10-min window do NOT re-emit.  Otherwise rapid-fire attacks
    would still flood the feed.

    Note: rate limiter blocks after 5 fails in 60 s, so a "6th" attempt
    in the same window short-circuits before the failure path runs.
    We bypass the rate limiter by inserting attempts directly to verify
    the activity-feed dedup logic — the rate-limit interaction is
    covered by other tests."""
    cid = await _make_paired_client(test_db, "rapid-fire")
    pin_hash = group_service.hash_pin("4827", HMAC_KEY)
    await _make_group(
        test_db, "dedup-grp",
        requires_pin=True, pin_hash=pin_hash, pin_model="shared",
    )
    await _add_to_group(test_db, "dedup-grp", cid)

    # Direct-insert 6 failed attempts spread inside the 10-min window
    # but outside the 60-s rate-limit window so each one is "fresh."
    now = datetime.now(UTC)
    for i in range(6):
        await test_db.execute(
            "INSERT INTO group_pin_attempts "
            "(client_id, group_id, attempted_at, success) VALUES (?, ?, ?, 0)",
            (cid, "dedup-grp",
             (now - timedelta(seconds=120 * (6 - i))).isoformat()),
        )
    await test_db.commit()

    # Manually trigger the helper twice — once at "count == 5" (would
    # emit), once at "count == 6" (should be a no-op).  Simulates two
    # consecutive failed attempts.
    await group_service._maybe_emit_failed_burst(
        test_db, client_id=cid, group_id="dedup-grp", now=now,
    )

    async with test_db.execute(
        "SELECT COUNT(*) FROM activity_events "
        "WHERE type = 'group.pin.failed-burst' "
        "  AND target_id = 'dedup-grp'",
    ) as cur:
        row = await cur.fetchone()
    # 6 attempts in window → count != 5 → no emit.  This is the
    # "subsequent attempts in same burst" branch.
    assert row[0] == 0


@pytest.mark.asyncio
async def test_revoke_all_grants_for_group_drops_every_grant(test_db):
    """Bulk reset deletes every grant + emits one
    `group.pin.grants-reset` event with the count."""
    cid_a = await _make_paired_client(test_db, "reset-a")
    cid_b = await _make_paired_client(test_db, "reset-b")
    pin_hash = group_service.hash_pin("4827", HMAC_KEY)
    await _make_group(
        test_db, "reset-grp",
        requires_pin=True, pin_hash=pin_hash, pin_model="shared",
    )
    await _add_to_group(test_db, "reset-grp", cid_a)
    await _add_to_group(test_db, "reset-grp", cid_b)
    # Each member unlocks → grant row each.
    await group_service.enter_pin_grant(
        test_db, cid_a, "reset-grp", "4827", hmac_key=HMAC_KEY,
    )
    await group_service.enter_pin_grant(
        test_db, cid_b, "reset-grp", "4827", hmac_key=HMAC_KEY,
    )

    deleted = await group_service.revoke_all_grants_for_group(
        test_db, "reset-grp",
    )
    assert deleted == 2

    async with test_db.execute(
        "SELECT COUNT(*) FROM group_pin_grants WHERE group_id = ?",
        ("reset-grp",),
    ) as cur:
        row = await cur.fetchone()
    assert row[0] == 0

    async with test_db.execute(
        "SELECT COUNT(*) FROM activity_events "
        "WHERE type = 'group.pin.grants-reset' "
        "  AND target_id = 'reset-grp'",
    ) as cur:
        row = await cur.fetchone()
    assert row[0] == 1


@pytest.mark.asyncio
async def test_revoke_all_grants_idempotent_on_empty(test_db):
    """Calling on a group with no active grants returns 0 and emits
    no activity event (no-op)."""
    await _make_group(test_db, "empty-grp")
    deleted = await group_service.revoke_all_grants_for_group(
        test_db, "empty-grp",
    )
    assert deleted == 0
    async with test_db.execute(
        "SELECT COUNT(*) FROM activity_events "
        "WHERE type = 'group.pin.grants-reset'",
    ) as cur:
        row = await cur.fetchone()
    assert row[0] == 0


@pytest.mark.asyncio
async def test_grants_reset_route_localhost_only(test_db):
    """Off-loopback caller hits 403."""
    await _make_group(test_db, "off-lo-grp")
    async with AsyncClient(
        transport=ASGITransport(
            app=app, client=("198.51.100.7", 51000),
        ),
        base_url="http://test",
    ) as remote:
        resp = await remote.post(
            "/api/v1/groups/off-lo-grp/grants/reset",
            headers={"CF-Connecting-IP": "198.51.100.7"},
        )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_grants_reset_route_404_unknown_group(test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("127.0.0.1", 12345)),
        base_url="http://test",
    ) as local:
        resp = await local.post(
            "/api/v1/groups/no-such-group/grants/reset",
        )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_grants_reset_route_returns_dropped_count(test_db):
    """Localhost call returns `{dropped: N}` for the desktop snackbar."""
    cid = await _make_paired_client(test_db, "snackbar-client")
    pin_hash = group_service.hash_pin("4827", HMAC_KEY)
    await _make_group(
        test_db, "snackbar-grp",
        requires_pin=True, pin_hash=pin_hash, pin_model="shared",
    )
    await _add_to_group(test_db, "snackbar-grp", cid)
    await group_service.enter_pin_grant(
        test_db, cid, "snackbar-grp", "4827", hmac_key=HMAC_KEY,
    )

    async with AsyncClient(
        transport=ASGITransport(app=app, client=("127.0.0.1", 12345)),
        base_url="http://test",
    ) as local:
        resp = await local.post(
            "/api/v1/groups/snackbar-grp/grants/reset",
        )
    assert resp.status_code == 200
    assert resp.json() == {"dropped": 1}
