"""HTTP-level tests for the library transcode router.

Plan: docs/10_planning/18_library_transcode_plan.md.

Verifies status codes / payload shapes for the five endpoints, plus
the auth gate (token-or-local — same as the files router).  The
service layer is exercised by ``test_transcode_service.py``; this
file focuses on wiring.
"""

import time
import uuid
from datetime import UTC, datetime

import pytest
from httpx import AsyncClient

from services import transcode_service

HMAC_KEY = "test-secret-key-for-unit-tests-only"


async def _get_token(client: AsyncClient, monkeypatch) -> str:
    monkeypatch.setattr("routers.auth.settings.token_hmac_key", HMAC_KEY)
    pair_body = {
        "client_id": "transcode-test-client",
        "device_name": "Test Device",
        "platform": "android",
        "app_version": "0.1.0",
    }
    await client.post("/api/v1/auth/request-pair", json=pair_body)
    await client.post("/api/v1/auth/approve/transcode-test-client")
    status = await client.get("/api/v1/auth/status/transcode-test-client")
    return status.json()["auth_token"]


async def _insert_file(
    test_db,
    *,
    codec: str | None = "av1",
    transcoded_path: str | None = None,
) -> str:
    file_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, duration_sec,
             library_id, codec_name, transcoded_path,
             created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            file_id,
            f"/media/{file_id}.mkv",
            f"file-{file_id[:6]}.mkv",
            ".mkv",
            10_000_000,
            120.0,
            None,
            codec,
            transcoded_path,
            now,
            now,
        ),
    )
    await test_db.commit()
    return file_id


@pytest.fixture(autouse=True)
def stub_resolve_encoder(monkeypatch):
    """Force ``libx264`` so tests don't shell out to ffmpeg -encoders."""

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)
    yield


# ── GET /candidates ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_candidates_local_no_auth_required(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="av1")
    resp = await client.get("/api/v1/transcode/candidates")
    assert resp.status_code == 200
    payload = resp.json()
    assert any(c["file_id"] == fid for c in payload)


@pytest.mark.asyncio
async def test_candidates_excludes_h264(client: AsyncClient, test_db):
    await _insert_file(test_db, codec="h264")
    resp = await client.get("/api/v1/transcode/candidates")
    assert resp.status_code == 200
    assert resp.json() == []


# ── POST /queue ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_queue_creates_jobs(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="av1")
    resp = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [fid]}
    )
    assert resp.status_code == 201
    body = resp.json()
    assert len(body["job_ids"]) == 1


@pytest.mark.asyncio
async def test_queue_empty_list_rejected(client: AsyncClient):
    resp = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": []}
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_queue_too_many_rejected(client: AsyncClient):
    resp = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [str(i) for i in range(51)]}
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_queue_unknown_file_returns_400(client: AsyncClient):
    resp = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": ["bogus-id"]}
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_queue_non_candidate_returns_400(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="h264")
    resp = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [fid]}
    )
    assert resp.status_code == 400


# ── GET /jobs ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_jobs_no_filter(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="av1")
    create = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [fid]}
    )
    assert create.status_code == 201

    resp = await client.get("/api/v1/transcode/jobs")
    assert resp.status_code == 200
    rows = resp.json()
    assert len(rows) == 1
    assert rows[0]["status"] == "queued"
    assert rows[0]["file_id"] == fid


@pytest.mark.asyncio
async def test_list_jobs_status_filter(client: AsyncClient, test_db):
    fid_a = await _insert_file(test_db, codec="av1")
    fid_b = await _insert_file(test_db, codec="vp9")

    resp_a = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [fid_a]}
    )
    job_a = resp_a.json()["job_ids"][0]
    resp_b = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [fid_b]}
    )
    assert resp_b.status_code == 201

    # Mark job_a done so we can filter it out.
    await test_db.execute(
        "UPDATE transcode_jobs SET status = 'done' WHERE id = ?", (job_a,)
    )
    await test_db.commit()

    resp = await client.get("/api/v1/transcode/jobs?status=queued")
    assert resp.status_code == 200
    rows = resp.json()
    assert len(rows) == 1
    assert rows[0]["status"] == "queued"


# ── DELETE /jobs/{id} ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_cancel_queued_job(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="av1")
    create = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [fid]}
    )
    job_id = create.json()["job_ids"][0]

    resp = await client.delete(f"/api/v1/transcode/jobs/{job_id}")
    assert resp.status_code == 204


@pytest.mark.asyncio
async def test_cancel_unknown_job_returns_404(client: AsyncClient):
    resp = await client.delete("/api/v1/transcode/jobs/99999")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_cancel_terminal_job_returns_409(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="av1")
    create = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [fid]}
    )
    job_id = create.json()["job_ids"][0]
    await test_db.execute(
        "UPDATE transcode_jobs SET status = 'done' WHERE id = ?", (job_id,)
    )
    await test_db.commit()

    resp = await client.delete(f"/api/v1/transcode/jobs/{job_id}")
    assert resp.status_code == 409


# ── POST /jobs/{id}/retry ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_retry_failed_job_returns_201(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="av1")
    create = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [fid]}
    )
    job_id = create.json()["job_ids"][0]
    await test_db.execute(
        "UPDATE transcode_jobs SET status = 'failed', error = ?, finished_at = ?"
        " WHERE id = ?",
        ("boom", int(time.time()), job_id),
    )
    await test_db.commit()

    resp = await client.post(f"/api/v1/transcode/jobs/{job_id}/retry")
    assert resp.status_code == 201
    body = resp.json()
    assert body["new_job_id"] != job_id


@pytest.mark.asyncio
async def test_retry_unknown_job_returns_404(client: AsyncClient):
    resp = await client.post("/api/v1/transcode/jobs/99999/retry")
    assert resp.status_code == 404


# ── Plan 19 §M1 — preset field on POST /queue ──────────────────────────────


@pytest.mark.asyncio
async def test_queue_accepts_preset_field(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="av1")
    resp = await client.post(
        "/api/v1/transcode/queue",
        json={"file_ids": [fid], "preset": "smaller"},
    )
    assert resp.status_code == 201
    job_id = resp.json()["job_ids"][0]
    async with test_db.execute(
        "SELECT quality_preset FROM transcode_jobs WHERE id = ?", (job_id,)
    ) as cur:
        row = await cur.fetchone()
    assert row["quality_preset"] == "smaller"


@pytest.mark.asyncio
async def test_queue_rejects_unknown_preset_with_422(client: AsyncClient):
    resp = await client.post(
        "/api/v1/transcode/queue",
        json={"file_ids": ["any"], "preset": "ultra"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_queue_default_preset_is_recommended(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="av1")
    resp = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [fid]}
    )
    assert resp.status_code == 201
    job_id = resp.json()["job_ids"][0]
    async with test_db.execute(
        "SELECT quality_preset FROM transcode_jobs WHERE id = ?", (job_id,)
    ) as cur:
        row = await cur.fetchone()
    assert row["quality_preset"] == "recommended"


# ── Plan 19 §M3 — GET /storage ─────────────────────────────────────────────


@pytest.mark.asyncio
async def test_storage_returns_zero_payload_when_empty(client: AsyncClient):
    resp = await client.get("/api/v1/transcode/storage")
    assert resp.status_code == 200
    body = resp.json()
    assert body["transcoded_size_bytes"] == 0
    assert body["transcoded_file_count"] == 0
    assert body["by_codec"] == {}
    assert body["storage_mode"] == "dedicated"
    assert isinstance(body["cache_root"], str) and body["cache_root"]
    assert "free_bytes_at_cache_root" in body


@pytest.mark.asyncio
async def test_storage_includes_transcoded_rows(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="av1")
    await test_db.execute(
        "UPDATE media_files SET transcoded_path = ?, transcoded_size_bytes = ?"
        " WHERE id = ?",
        ("/sidecar/x.h264.mkv", 4_242, fid),
    )
    await test_db.commit()
    resp = await client.get("/api/v1/transcode/storage")
    assert resp.status_code == 200
    body = resp.json()
    assert body["transcoded_file_count"] == 1
    assert body["transcoded_size_bytes"] == 4_242
    assert body["by_codec"]["av1"]["count"] == 1


@pytest.mark.asyncio
async def test_retry_running_job_returns_409(client: AsyncClient, test_db):
    fid = await _insert_file(test_db, codec="av1")
    create = await client.post(
        "/api/v1/transcode/queue", json={"file_ids": [fid]}
    )
    job_id = create.json()["job_ids"][0]
    await test_db.execute(
        "UPDATE transcode_jobs SET status = 'running' WHERE id = ?", (job_id,)
    )
    await test_db.commit()

    resp = await client.post(f"/api/v1/transcode/jobs/{job_id}/retry")
    assert resp.status_code == 409
