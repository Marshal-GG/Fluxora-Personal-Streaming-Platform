"""Unit tests for the library transcode service.

Plan: docs/10_planning/18_library_transcode_plan.md.

Coverage:

* candidate detection picks AV1/VP9, ignores h264, ignores already-
  transcoded files
* queue dedup across the input list + skip when an active job exists
* cancel of a queued job marks it cancelled
* cancel of a terminal (done) job returns False
* retry of a failed job creates a fresh queued one + preserves the
  original error column
* list_jobs filters by status correctly
* crash-recovery sweep on start_worker boot turns orphan running rows
  into failed
"""

import time
import uuid
from datetime import UTC, datetime

import pytest

from services import transcode_service

HMAC_KEY = "test-secret-key-for-unit-tests-only"


async def _insert_file(
    test_db,
    *,
    codec: str | None = "av1",
    library_id: str | None = None,
    transcoded_path: str | None = None,
) -> str:
    """Insert a media_files row with the given video codec.

    Mirrors the helpers in ``test_files.py`` / ``test_stream.py`` so
    every transcode test starts from the same shape of row.  When
    ``library_id`` is ``None`` the row is detached (FK is nullable
    via ``ON DELETE SET NULL``).
    """
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
            library_id,
            codec,
            transcoded_path,
            now,
            now,
        ),
    )
    await test_db.commit()
    return file_id


# ── candidates ─────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_candidates_picks_av1_and_vp9_only(test_db):
    av1 = await _insert_file(test_db, codec="av1")
    vp9 = await _insert_file(test_db, codec="vp9")
    await _insert_file(test_db, codec="h264")
    await _insert_file(test_db, codec="hevc")
    await _insert_file(test_db, codec=None)

    results = await transcode_service.candidates(test_db)
    ids = {c.file_id for c in results}
    assert av1 in ids
    assert vp9 in ids
    assert len(ids) == 2


@pytest.mark.asyncio
async def test_candidates_ignores_already_transcoded(test_db):
    pending = await _insert_file(test_db, codec="av1")
    await _insert_file(
        test_db, codec="av1", transcoded_path="/media/already.h264.mkv"
    )

    results = await transcode_service.candidates(test_db)
    ids = {c.file_id for c in results}
    assert ids == {pending}


@pytest.mark.asyncio
async def test_candidates_estimate_uses_codec_multiplier(test_db):
    av1 = await _insert_file(test_db, codec="av1")
    vp9 = await _insert_file(test_db, codec="vp9")

    by_id = {c.file_id: c for c in await transcode_service.candidates(test_db)}
    # Source is 10 MB; estimator uses 2.0x for AV1, 1.5x for VP9.
    assert by_id[av1].est_output_size_bytes == 20_000_000
    assert by_id[vp9].est_output_size_bytes == 15_000_000


# ── queue ─────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_queue_dedups_same_file_id_in_one_request(test_db, monkeypatch):
    fid = await _insert_file(test_db, codec="av1")

    # Force libx264 so we don't run an `ffmpeg -encoders` probe in tests.
    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    job_ids = await transcode_service.queue(test_db, [fid, fid, fid])
    assert len(job_ids) == 1


@pytest.mark.asyncio
async def test_queue_skips_files_with_active_jobs(test_db, monkeypatch):
    fid = await _insert_file(test_db, codec="av1")

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    first = await transcode_service.queue(test_db, [fid])
    assert len(first) == 1

    # Second call should silently skip — active job still queued.
    second = await transcode_service.queue(test_db, [fid])
    assert second == []


@pytest.mark.asyncio
async def test_queue_rejects_non_candidate_file(test_db, monkeypatch):
    fid = await _insert_file(test_db, codec="h264")

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    with pytest.raises(ValueError):
        await transcode_service.queue(test_db, [fid])


@pytest.mark.asyncio
async def test_queue_rejects_unknown_file_id(test_db, monkeypatch):
    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    with pytest.raises(ValueError):
        await transcode_service.queue(test_db, ["does-not-exist"])


# ── cancel ────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_cancel_queued_job_marks_cancelled(test_db, monkeypatch):
    fid = await _insert_file(test_db, codec="av1")

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    [job_id] = await transcode_service.queue(test_db, [fid])
    ok = await transcode_service.cancel(test_db, job_id)
    assert ok is True

    job = await transcode_service.get_job(test_db, job_id)
    assert job is not None
    assert job.status == "cancelled"
    assert job.finished_at is not None


@pytest.mark.asyncio
async def test_cancel_terminal_job_returns_false(test_db, monkeypatch):
    fid = await _insert_file(test_db, codec="av1")

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    [job_id] = await transcode_service.queue(test_db, [fid])
    # Manually transition the row to done.
    now = int(time.time())
    await test_db.execute(
        "UPDATE transcode_jobs SET status = 'done', finished_at = ? WHERE id = ?",
        (now, job_id),
    )
    await test_db.commit()

    ok = await transcode_service.cancel(test_db, job_id)
    assert ok is False


@pytest.mark.asyncio
async def test_cancel_unknown_job_returns_false(test_db):
    ok = await transcode_service.cancel(test_db, 99_999)
    assert ok is False


# ── retry ─────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_retry_failed_job_clones_with_original_error_preserved(
    test_db, monkeypatch
):
    fid = await _insert_file(test_db, codec="av1")

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    [job_id] = await transcode_service.queue(test_db, [fid])
    # Mark as failed with a captured error message.
    await test_db.execute(
        "UPDATE transcode_jobs SET status = 'failed', error = ?, finished_at = ?"
        " WHERE id = ?",
        ("Some FFmpeg error", int(time.time()), job_id),
    )
    await test_db.commit()

    new_id = await transcode_service.retry(test_db, job_id)
    assert new_id != job_id

    original = await transcode_service.get_job(test_db, job_id)
    new_job = await transcode_service.get_job(test_db, new_id)
    assert original is not None and new_job is not None
    assert original.status == "failed"
    assert original.error == "Some FFmpeg error"
    assert new_job.status == "queued"
    assert new_job.encoder == original.encoder


@pytest.mark.asyncio
async def test_retry_done_job_raises(test_db, monkeypatch):
    fid = await _insert_file(test_db, codec="av1")

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    [job_id] = await transcode_service.queue(test_db, [fid])
    await test_db.execute(
        "UPDATE transcode_jobs SET status = 'done' WHERE id = ?", (job_id,)
    )
    await test_db.commit()

    with pytest.raises(ValueError):
        await transcode_service.retry(test_db, job_id)


@pytest.mark.asyncio
async def test_retry_unknown_job_raises(test_db):
    with pytest.raises(LookupError):
        await transcode_service.retry(test_db, 99_999)


# ── list_jobs ─────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_jobs_filters_by_status(test_db, monkeypatch):
    fid_a = await _insert_file(test_db, codec="av1")
    fid_b = await _insert_file(test_db, codec="vp9")

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    [job_a] = await transcode_service.queue(test_db, [fid_a])
    [job_b] = await transcode_service.queue(test_db, [fid_b])

    # Mark a as done; b stays queued.
    await test_db.execute(
        "UPDATE transcode_jobs SET status = 'done' WHERE id = ?", (job_a,)
    )
    await test_db.commit()

    queued = await transcode_service.list_jobs(test_db, ["queued"])
    assert {j.id for j in queued} == {job_b}

    done = await transcode_service.list_jobs(test_db, ["done"])
    assert {j.id for j in done} == {job_a}

    everything = await transcode_service.list_jobs(test_db, None)
    assert {j.id for j in everything} == {job_a, job_b}


# ── crash recovery ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_recover_orphan_running_jobs_marks_them_failed(test_db, monkeypatch):
    fid = await _insert_file(test_db, codec="av1")

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    [job_id] = await transcode_service.queue(test_db, [fid])
    # Simulate a server crash — the previous run left this row in
    # 'running' with no live process behind it.
    await test_db.execute(
        "UPDATE transcode_jobs SET status = 'running', started_at = ? WHERE id = ?",
        (int(time.time()), job_id),
    )
    await test_db.commit()

    swept = await transcode_service._recover_orphan_running_jobs(test_db)
    assert swept == 1

    job = await transcode_service.get_job(test_db, job_id)
    assert job is not None
    assert job.status == "failed"
    assert job.error == "server restarted mid-job"
