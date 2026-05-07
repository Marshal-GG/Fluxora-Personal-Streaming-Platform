import pytest
from httpx import ASGITransport, AsyncClient

from main import app

HMAC_KEY = "test-secret-key-for-unit-tests-only"

PAIR_BODY = {
    "client_id": "client-uuid-001",
    "device_name": "Test Phone",
    "platform": "android",
    "app_version": "0.1.0",
}


# ── /api/v1/info ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_info_returns_defaults(client: AsyncClient):
    response = await client.get("/api/v1/info")
    assert response.status_code == 200
    data = response.json()
    assert data["server_name"] == "Fluxora Server"
    assert data["version"] == "0.1.0"
    assert data["tier"] == "free"


@pytest.mark.asyncio
async def test_get_info_reflects_settings_row(client: AsyncClient, test_db):
    await test_db.execute(
        "UPDATE user_settings SET server_name = ?, subscription_tier = ? WHERE id = 1",
        ("My Home Server", "plus"),
    )
    await test_db.commit()

    response = await client.get("/api/v1/info")
    assert response.status_code == 200
    data = response.json()
    assert data["server_name"] == "My Home Server"
    assert data["tier"] == "plus"


@pytest.mark.asyncio
async def test_get_info_custom_server_url_overrides_env(
    client: AsyncClient, test_db, monkeypatch
):
    """user_settings.custom_server_url takes precedence over the env var."""
    monkeypatch.setattr(
        "routers.info.settings.fluxora_public_url",
        "https://from-env.example.com",
    )
    await test_db.execute(
        "UPDATE user_settings SET custom_server_url = ? WHERE id = 1",
        ("https://from-db.example.com",),
    )
    await test_db.commit()

    response = await client.get("/api/v1/info")
    assert response.status_code == 200
    assert response.json()["remote_url"] == "https://from-db.example.com"


@pytest.mark.asyncio
async def test_get_info_falls_back_to_env_when_custom_url_blank(
    client: AsyncClient, test_db, monkeypatch
):
    """Empty/whitespace custom_server_url falls through to the env var."""
    monkeypatch.setattr(
        "routers.info.settings.fluxora_public_url",
        "https://from-env.example.com",
    )
    await test_db.execute(
        "UPDATE user_settings SET custom_server_url = ? WHERE id = 1",
        ("   ",),
    )
    await test_db.commit()

    response = await client.get("/api/v1/info")
    assert response.status_code == 200
    assert response.json()["remote_url"] == "https://from-env.example.com"


# ── Pairing flow ─────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_request_pair_creates_pending_client(client: AsyncClient):
    response = await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    assert response.status_code == 200
    data = response.json()
    assert data["client_id"] == PAIR_BODY["client_id"]
    assert data["status"] == "pending_approval"


@pytest.mark.asyncio
async def test_auth_status_pending(client: AsyncClient):
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)

    response = await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")
    assert response.status_code == 200
    assert response.json()["status"] == "pending_approval"


@pytest.mark.asyncio
async def test_auth_status_unknown_client_returns_404(client: AsyncClient):
    response = await client.get("/api/v1/auth/status/nonexistent-id")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_full_approval_flow(client: AsyncClient, monkeypatch):
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)

    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await client.post(f"/api/v1/auth/approve/{PAIR_BODY['client_id']}")

    status_resp = await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")
    assert status_resp.status_code == 200
    data = status_resp.json()
    assert data["status"] == "approved"
    assert data["auth_token"] is not None
    assert len(data["auth_token"]) > 10


@pytest.mark.asyncio
async def test_rejection_flow(client: AsyncClient):
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await client.post(f"/api/v1/auth/reject/{PAIR_BODY['client_id']}")

    status_resp = await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")
    assert status_resp.status_code == 200
    assert status_resp.json()["status"] == "rejected"


@pytest.mark.asyncio
async def test_revoke_blocked_from_lan(test_db):
    """`DELETE /auth/revoke/{id}` is localhost-only — non-loopback rejected."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("192.168.1.100", 50000)),
        base_url="http://test",
    ) as lan:
        resp = await lan.delete("/api/v1/auth/revoke/any-id")
    assert resp.status_code == 403


# ── Localhost restriction ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_approve_blocked_from_lan(test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("192.168.1.100", 50000)),
        base_url="http://test",
    ) as lan:
        resp = await lan.post("/api/v1/auth/approve/any-id")
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_reject_blocked_from_lan(test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("192.168.1.100", 50000)),
        base_url="http://test",
    ) as lan:
        resp = await lan.post("/api/v1/auth/reject/any-id")
    assert resp.status_code == 403


# ── GET /clients ─────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_clients_empty(client: AsyncClient):
    response = await client.get("/api/v1/auth/clients")
    assert response.status_code == 200
    data = response.json()
    assert data["clients"] == []
    assert data["total"] == 0


@pytest.mark.asyncio
async def test_list_clients_returns_after_pair_request(client: AsyncClient):
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)

    response = await client.get("/api/v1/auth/clients")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    item = data["clients"][0]
    assert item["id"] == PAIR_BODY["client_id"]
    assert item["name"] == PAIR_BODY["device_name"]
    assert item["platform"] == PAIR_BODY["platform"]
    assert item["status"] == "pending"
    assert item["is_trusted"] is False
    # New fields from migration 023 + active-session join
    assert "last_ip" in item
    assert item["active_session"] is None


# ── Migration 023 — last_ip + active_session join ─────────────────────────────


@pytest.mark.asyncio
async def test_request_pair_persists_client_ip(test_db):
    """`request-pair` writes the request socket's host into clients.last_ip."""
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("192.168.1.42", 50000)),
        base_url="http://test",
    ) as lan:
        resp = await lan.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    assert resp.status_code == 200

    async with test_db.execute(
        "SELECT last_ip FROM clients WHERE id = ?", (PAIR_BODY["client_id"],)
    ) as cur:
        row = await cur.fetchone()
    assert row is not None
    assert row[0] == "192.168.1.42"


@pytest.mark.asyncio
async def test_list_clients_surfaces_last_ip_and_active_session(
    client: AsyncClient, test_db
):
    """End-to-end: pair, approve, start a synthetic session, then list."""
    # Pair via a non-loopback transport so request_pair captures an IP.
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("10.0.0.7", 51000)),
        base_url="http://test",
    ) as lan:
        await lan.post("/api/v1/auth/request-pair", json=PAIR_BODY)

    # Insert a media file + open stream session pointing at the client.
    await test_db.execute(
        "INSERT INTO media_files (id, path, name, extension, size_bytes, library_id) "
        "VALUES ('m1', '/tmp/m1.mp4', 'Inception', 'mp4', 1, NULL)"
    )
    await test_db.execute(
        "INSERT INTO stream_sessions (id, file_id, client_id, started_at, ended_at, "
        "                             connection_type, encoder_used) "
        "VALUES ('sess-1', 'm1', ?, '2026-05-06T01:00:00Z', NULL, 'lan', 'h264_nvenc')",
        (PAIR_BODY["client_id"],),
    )
    await test_db.commit()

    response = await client.get("/api/v1/auth/clients")
    assert response.status_code == 200
    item = response.json()["clients"][0]
    assert item["last_ip"] == "10.0.0.7"
    assert item["active_session"] is not None
    assert item["active_session"]["session_id"] == "sess-1"
    assert item["active_session"]["encoder_used"] == "h264_nvenc"
    assert item["active_session"]["media_title"] == "Inception"


@pytest.mark.asyncio
async def test_list_clients_active_session_null_when_session_ended(
    client: AsyncClient, test_db
):
    """A closed session must not appear as the client's active_session."""
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await test_db.execute(
        "INSERT INTO media_files (id, path, name, extension, size_bytes, library_id) "
        "VALUES ('m2', '/tmp/m2.mp4', 'Movie', 'mp4', 1, NULL)"
    )
    await test_db.execute(
        "INSERT INTO stream_sessions (id, file_id, client_id, started_at, ended_at, "
        "                             connection_type) "
        "VALUES ('sess-2', 'm2', ?, '2026-05-06T00:00:00Z', "
        "        '2026-05-06T00:30:00Z', 'lan')",
        (PAIR_BODY["client_id"],),
    )
    await test_db.commit()

    response = await client.get("/api/v1/auth/clients")
    assert response.status_code == 200
    assert response.json()["clients"][0]["active_session"] is None


@pytest.mark.asyncio
async def test_list_clients_includes_group_memberships(
    client: AsyncClient, test_db
):
    """M3 (2026-05-07): the list_clients query LEFT-JOINs group_members
    via SQLite's `json_group_array` so the desktop Clients screen can
    render group chips on the detail panel without a follow-up fetch.
    Two groups, the client is in both → both surface in the response;
    a client outside any group returns `groups: []`.  Pins the wire
    shape the desktop M3 Clients-screen cross-link consumes."""
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)

    # Create two groups + add the paired client to both.
    g1 = (
        await client.post(
            "/api/v1/groups", json={"name": "Family"}
        )
    ).json()
    g2 = (
        await client.post(
            "/api/v1/groups", json={"name": "Kids"}
        )
    ).json()
    await client.post(
        f"/api/v1/groups/{g1['id']}/members",
        json={"client_id": PAIR_BODY["client_id"]},
    )
    await client.post(
        f"/api/v1/groups/{g2['id']}/members",
        json={"client_id": PAIR_BODY["client_id"]},
    )

    resp = await client.get("/api/v1/auth/clients")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["clients"]) == 1
    groups = body["clients"][0]["groups"]
    assert len(groups) == 2
    names = {g["name"] for g in groups}
    assert names == {"Family", "Kids"}
    # Each summary carries id + name + status — the heavier fields
    # (restrictions, member_count, created_at, updated_at) live on
    # /groups/{id} only, not in this list response.
    for g in groups:
        assert set(g.keys()) == {"id", "name", "status"}
        assert g["status"] == "active"


@pytest.mark.asyncio
async def test_list_clients_groups_empty_for_unaffiliated_client(
    client: AsyncClient, test_db
):
    """A client that's not in any group returns `groups: []`, not null
    or missing.  Lets the desktop render an empty chip row without a
    null check."""
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    resp = await client.get("/api/v1/auth/clients")
    assert resp.status_code == 200
    assert resp.json()["clients"][0]["groups"] == []


@pytest.mark.asyncio
async def test_list_clients_blocked_from_lan(test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("192.168.1.100", 50000)),
        base_url="http://test",
    ) as lan:
        resp = await lan.get("/api/v1/auth/clients")
    assert resp.status_code == 403


# ── Re-pair from the same client_id (Phase A — backfill plan §8.5 bug 1) ────


@pytest.mark.asyncio
async def test_request_pair_accepts_optional_email(client: AsyncClient, test_db):
    body = dict(PAIR_BODY, email="alex@fluxora.io")
    resp = await client.post("/api/v1/auth/request-pair", json=body)
    assert resp.status_code == 200

    async with test_db.execute(
        "SELECT email FROM clients WHERE id = ?", (PAIR_BODY["client_id"],)
    ) as cur:
        row = await cur.fetchone()
    assert row["email"] == "alex@fluxora.io"


@pytest.mark.asyncio
async def test_repair_after_approval_resets_to_pending(
    client: AsyncClient, monkeypatch, test_db
):
    """After a client is approved, a fresh request-pair must reset the row to
    pending and invalidate the prior auth_token. Otherwise a re-installed app
    would hit the 409 from POST /approve and the operator would have to
    revoke + re-add manually."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)

    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await client.post(f"/api/v1/auth/approve/{PAIR_BODY['client_id']}")
    status_resp = await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")
    first_token = status_resp.json()["auth_token"]
    assert first_token

    # Same client_id pairs again — re-installed app, restored from backup, etc.
    repair_body = dict(PAIR_BODY, device_name="Test Phone (renamed)")
    resp = await client.post("/api/v1/auth/request-pair", json=repair_body)
    assert resp.status_code == 200

    async with test_db.execute(
        "SELECT name, status, is_trusted, auth_token FROM clients WHERE id = ?",
        (PAIR_BODY["client_id"],),
    ) as cur:
        row = await cur.fetchone()
    assert row["status"] == "pending"
    assert row["is_trusted"] == 0
    assert row["auth_token"] == ""
    assert row["name"] == "Test Phone (renamed)"

    # Old token must no longer authenticate any bearer-protected endpoint.
    files_resp = await client.get(
        "/api/v1/files",
        headers={
            "Authorization": f"Bearer {first_token}",
            "CF-Connecting-IP": "1.2.3.4",  # force token validation path
        },
    )
    assert files_resp.status_code == 401


@pytest.mark.asyncio
async def test_repair_after_rejection_resets_to_pending(client: AsyncClient, test_db):
    """Rejected clients must be able to re-request pairing without operator
    intervention — the pre-fix code only re-opened from rejected, not from
    approved, so this test pins the rejected→pending behaviour we still want."""
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await client.post(f"/api/v1/auth/reject/{PAIR_BODY['client_id']}")

    resp = await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    assert resp.status_code == 200

    async with test_db.execute(
        "SELECT status FROM clients WHERE id = ?", (PAIR_BODY["client_id"],)
    ) as cur:
        row = await cur.fetchone()
    assert row["status"] == "pending"


# ── GET /clients/me ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_clients_me_returns_profile(client: AsyncClient, monkeypatch, test_db):
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    body = dict(PAIR_BODY, email="alex@fluxora.io")
    await client.post("/api/v1/auth/request-pair", json=body)
    await client.post(f"/api/v1/auth/approve/{PAIR_BODY['client_id']}")
    token = (await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")).json()[
        "auth_token"
    ]

    resp = await client.get(
        "/api/v1/auth/clients/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == PAIR_BODY["client_id"]
    assert data["display_name"] == PAIR_BODY["device_name"]
    assert data["email"] == "alex@fluxora.io"
    assert data["platform"] == PAIR_BODY["platform"]
    assert data["paired_at"] is not None
    assert data["tier"] == "free"


@pytest.mark.asyncio
async def test_clients_me_requires_token(client: AsyncClient):
    resp = await client.get(
        "/api/v1/auth/clients/me",
        headers={"CF-Connecting-IP": "1.2.3.4"},  # force token validation
    )
    assert resp.status_code == 401


# ── DELETE /clients/me (mobile redesign audit §17.3 #3 — self-revoke) ───────


@pytest.mark.asyncio
async def test_clients_me_self_revoke_returns_204(
    client: AsyncClient, monkeypatch, test_db
):
    """Self-revoke happy path: the calling client's bearer token + row
    are torched, returning 204."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await client.post(f"/api/v1/auth/approve/{PAIR_BODY['client_id']}")
    token = (await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")).json()[
        "auth_token"
    ]

    resp = await client.delete(
        "/api/v1/auth/clients/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 204


@pytest.mark.asyncio
async def test_clients_me_self_revoke_invalidates_token(
    client: AsyncClient, monkeypatch, test_db
):
    """After self-revoke, the same bearer token must no longer
    authenticate the next request — that's the whole point of the
    fix.  Without server-side revoke the token would still work
    until natural expiry."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await client.post(f"/api/v1/auth/approve/{PAIR_BODY['client_id']}")
    token = (await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")).json()[
        "auth_token"
    ]

    # Confirm token works pre-revoke.
    pre = await client.get(
        "/api/v1/auth/clients/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert pre.status_code == 200

    # Self-revoke.
    await client.delete(
        "/api/v1/auth/clients/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    # Same token must now fail token-validated routes.
    post = await client.get(
        "/api/v1/auth/clients/me",
        headers={
            "Authorization": f"Bearer {token}",
            # Force the loopback dep onto the validate-token branch so
            # the bearer is actually consulted (httpx sees the request
            # as 127.0.0.1 by default, which would short-circuit to
            # localhost-allowed).
            "CF-Connecting-IP": "203.0.113.1",
        },
    )
    assert post.status_code == 401


@pytest.mark.asyncio
async def test_clients_me_self_revoke_requires_token(client: AsyncClient):
    """No bearer + non-loopback origin → 401.  Matches the rest of
    the `/clients/me/...` family."""
    resp = await client.delete(
        "/api/v1/auth/clients/me",
        headers={"CF-Connecting-IP": "1.2.3.4"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_clients_me_self_revoke_records_activity_event(
    client: AsyncClient, monkeypatch, test_db
):
    """The self-revoke path emits an activity event so the operator's
    Activity feed shows the sign-out.  Same row as operator-driven
    `client.revoke` events but with `actor_kind='client'` instead of
    `'operator'`."""
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await client.post(f"/api/v1/auth/approve/{PAIR_BODY['client_id']}")
    token = (await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")).json()[
        "auth_token"
    ]

    await client.delete(
        "/api/v1/auth/clients/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    async with test_db.execute(
        "SELECT type, actor_kind, actor_id, target_id, summary"
        " FROM activity_events"
        " WHERE type = 'client.revoke'"
        " ORDER BY created_at DESC LIMIT 1"
    ) as cur:
        row = await cur.fetchone()
    assert row is not None
    assert row["actor_kind"] == "client"
    assert row["actor_id"] == PAIR_BODY["client_id"]
    assert row["target_id"] == PAIR_BODY["client_id"]
    assert "self-revoke" in row["summary"]


# ── /clients/me/stats (Phase B backfill plan §3 row 3) ──────────────────────


async def _approve_and_token(client: AsyncClient, monkeypatch) -> str:
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    await client.post("/api/v1/auth/request-pair", json=PAIR_BODY)
    await client.post(f"/api/v1/auth/approve/{PAIR_BODY['client_id']}")
    status_resp = await client.get(f"/api/v1/auth/status/{PAIR_BODY['client_id']}")
    return status_resp.json()["auth_token"]


@pytest.mark.asyncio
async def test_clients_me_stats_zero_for_fresh_client(client: AsyncClient, monkeypatch):
    token = await _approve_and_token(client, monkeypatch)
    resp = await client.get(
        "/api/v1/auth/clients/me/stats",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"hours": 0, "movies": 0, "shows": 0}


@pytest.mark.asyncio
async def test_clients_me_stats_aggregates_sessions(
    client: AsyncClient, monkeypatch, test_db
):
    import json
    import uuid
    from datetime import UTC, datetime

    token = await _approve_and_token(client, monkeypatch)
    now = datetime.now(UTC).isoformat()

    # Two libraries — one movies, one tv.
    movies_lib = str(uuid.uuid4())
    tv_lib = str(uuid.uuid4())
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?,?,?,?,?)",
        (movies_lib, "Movies", "movies", json.dumps(["/m"]), now),
    )
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?,?,?,?,?)",
        (tv_lib, "Shows", "tv", json.dumps(["/t"]), now),
    )

    # Three movie files + two TV episodes (with shared tmdb_show_id) +
    # one TV episode in a different show.
    movie_a = str(uuid.uuid4())
    movie_b = str(uuid.uuid4())
    show_ep1 = str(uuid.uuid4())
    show_ep2 = str(uuid.uuid4())
    other_show_ep = str(uuid.uuid4())

    for fid, name, lib_id, show_id in [
        (movie_a, "a.mp4", movies_lib, None),
        (movie_b, "b.mp4", movies_lib, None),
        (show_ep1, "show1-s01e01.mp4", tv_lib, 100),
        (show_ep2, "show1-s01e02.mp4", tv_lib, 100),
        (other_show_ep, "show2-s01e01.mp4", tv_lib, 200),
    ]:
        await test_db.execute(
            """
            INSERT INTO media_files
                (id, path, name, extension, size_bytes, duration_sec,
                 library_id, tmdb_id, tmdb_show_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                fid,
                f"/{fid}-{name}",
                name,
                ".mp4",
                1024,
                3600.0,
                lib_id,
                None,
                show_id,
                now,
                now,
            ),
        )

    # Stream sessions: 2 hours on movie_a (7200s), 30min on movie_b (1800s),
    # 45min on show_ep1 + show_ep2 (2700s each), 60min on other_show_ep.
    for fid, secs in [
        (movie_a, 7200.0),
        (movie_b, 1800.0),
        (show_ep1, 2700.0),
        (show_ep2, 2700.0),
        (other_show_ep, 3600.0),
    ]:
        await test_db.execute(
            """
            INSERT INTO stream_sessions
                (id, file_id, client_id, started_at, connection_type,
                 progress_sec)
            VALUES (?, ?, ?, ?, 'lan', ?)
            """,
            (str(uuid.uuid4()), fid, PAIR_BODY["client_id"], now, secs),
        )
    await test_db.commit()

    resp = await client.get(
        "/api/v1/auth/clients/me/stats",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    # 7200 + 1800 + 2700 + 2700 + 3600 = 18000 s = 5 h.
    assert data["hours"] == 5
    # Two distinct movie file ids touched.
    assert data["movies"] == 2
    # Two distinct tmdb_show_id values across TV sessions (100, 200).
    assert data["shows"] == 2


@pytest.mark.asyncio
async def test_clients_me_stats_requires_token(client: AsyncClient):
    resp = await client.get(
        "/api/v1/auth/clients/me/stats",
        headers={"CF-Connecting-IP": "1.2.3.4"},
    )
    assert resp.status_code == 401


# ── /clients/me/continue-watching (Phase B §3 row 1) ────────────────────────


@pytest.mark.asyncio
async def test_continue_watching_excludes_zero_and_complete(
    client: AsyncClient, monkeypatch, test_db
):
    import uuid
    from datetime import UTC, datetime

    token = await _approve_and_token(client, monkeypatch)
    now = datetime.now(UTC).isoformat()

    fresh = str(uuid.uuid4())
    in_progress = str(uuid.uuid4())
    finished = str(uuid.uuid4())

    rows = [
        # last_progress_sec = 0 → not in continue-watching
        (fresh, "fresh.mp4", 0.0, 3600.0),
        # 600/3600 = 16% — counts
        (in_progress, "wip.mp4", 600.0, 3600.0),
        # 3500/3600 = 97% — past the 95% cutoff, doesn't count
        (finished, "done.mp4", 3500.0, 3600.0),
    ]
    for fid, name, prog, dur in rows:
        await test_db.execute(
            """
            INSERT INTO media_files
                (id, path, name, extension, size_bytes, duration_sec,
                 last_progress_sec, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (fid, f"/{name}", name, ".mp4", 1024, dur, prog, now, now),
        )
    await test_db.commit()

    resp = await client.get(
        "/api/v1/auth/clients/me/continue-watching",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    files = resp.json()
    ids = {f["id"] for f in files}
    assert ids == {in_progress}


@pytest.mark.asyncio
async def test_continue_watching_requires_token(client: AsyncClient):
    resp = await client.get(
        "/api/v1/auth/clients/me/continue-watching",
        headers={"CF-Connecting-IP": "1.2.3.4"},
    )
    assert resp.status_code == 401
