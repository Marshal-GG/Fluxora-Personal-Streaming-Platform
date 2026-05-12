"""Unit tests for the library transcode service.

Plan: docs/10_planning/18_library_transcode_plan.md
+ docs/10_planning/19_library_transcode_followups.md (M1 / M2 / M6).

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
* plan 19 §M1 — quality preset chooser produces the right NVENC /
  libx264 args for `smaller` / `recommended` / `mastering`
* plan 19 §M2 — sidecar path resolution under both storage modes
* plan 19 §M6 — `.webm` sources force `.mkv` extension
* plan 19 §M6 — partial-output cleanup on crash recovery
"""

import time
import uuid
from datetime import UTC, datetime
from pathlib import Path

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
    await _insert_file(test_db, codec="av1", transcoded_path="/media/already.h264.mkv")

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


# ── Plan 19 §M1 — quality preset chooser ──────────────────────────────────


def test_quality_preset_recommended_maps_to_cq23_for_nvenc():
    args = transcode_service._resolve_preset_args("recommended", "h264_nvenc")
    assert "-cq" in args
    assert args[args.index("-cq") + 1] == "23"
    assert "-preset" in args
    assert args[args.index("-preset") + 1] == "slow"


def test_quality_preset_smaller_maps_to_cq28_for_nvenc():
    args = transcode_service._resolve_preset_args("smaller", "h264_nvenc")
    assert args[args.index("-cq") + 1] == "28"
    assert args[args.index("-preset") + 1] == "p4"


def test_quality_preset_mastering_maps_to_cq19_for_nvenc():
    args = transcode_service._resolve_preset_args("mastering", "h264_nvenc")
    assert args[args.index("-cq") + 1] == "19"


def test_quality_preset_recommended_maps_to_crf23_for_libx264():
    args = transcode_service._resolve_preset_args("recommended", "libx264")
    assert "-crf" in args
    assert args[args.index("-crf") + 1] == "23"
    assert args[args.index("-preset") + 1] == "slow"


def test_quality_preset_smaller_maps_to_crf28_for_libx264():
    args = transcode_service._resolve_preset_args("smaller", "libx264")
    assert args[args.index("-crf") + 1] == "28"
    assert args[args.index("-preset") + 1] == "medium"


def test_quality_preset_legacy_string_aliases_to_mastering():
    """Pre-plan-19 rows carry `slow_cq19` / `slow_crf19`; both map to
    the new `mastering` preset so historical jobs retain behaviour."""
    nvenc_args = transcode_service._resolve_preset_args("slow_cq19", "h264_nvenc")
    libx264_args = transcode_service._resolve_preset_args("slow_crf19", "libx264")
    assert nvenc_args[nvenc_args.index("-cq") + 1] == "19"
    assert libx264_args[libx264_args.index("-crf") + 1] == "19"


def test_quality_preset_unknown_falls_back_to_recommended():
    args = transcode_service._resolve_preset_args("nonexistent", "h264_nvenc")
    assert args[args.index("-cq") + 1] == "23"  # recommended


def test_build_ffmpeg_cmd_uses_recommended_preset_by_default():
    cmd = transcode_service._build_ffmpeg_cmd(
        source_path="/src.mkv",
        output_path="/out.mkv",
        encoder="libx264",
        source_audio_codec="aac",
        preset_name=None,
    )
    assert cmd[cmd.index("-crf") + 1] == "23"


def test_build_ffmpeg_cmd_honours_smaller_preset():
    cmd = transcode_service._build_ffmpeg_cmd(
        source_path="/src.mkv",
        output_path="/out.mkv",
        encoder="libx264",
        source_audio_codec="aac",
        preset_name="smaller",
    )
    assert cmd[cmd.index("-crf") + 1] == "28"
    assert cmd[cmd.index("-preset") + 1] == "medium"


@pytest.mark.asyncio
async def test_queue_rejects_unknown_preset(test_db, monkeypatch):
    fid = await _insert_file(test_db, codec="av1")

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    with pytest.raises(ValueError):
        await transcode_service.queue(test_db, [fid], preset="ultra-mastering")


@pytest.mark.asyncio
async def test_queue_records_default_preset_when_omitted(test_db, monkeypatch):
    fid = await _insert_file(test_db, codec="av1")

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    [job_id] = await transcode_service.queue(test_db, [fid])
    async with test_db.execute(
        "SELECT quality_preset FROM transcode_jobs WHERE id = ?", (job_id,)
    ) as cur:
        row = await cur.fetchone()
    assert row["quality_preset"] == "recommended"


# ── Plan 19 §M2 — sidecar path resolution ──────────────────────────────────


def test_sidecar_path_dedicated_mirrors_library_tree(tmp_path):
    library_root = tmp_path / "lib"
    library_root.mkdir()
    (library_root / "Movies" / "2024").mkdir(parents=True)

    file_row = {
        "path": str(library_root / "Movies" / "2024" / "Dune.mkv"),
        "library_id": "lib-1",
    }
    library_row = {
        "id": "lib-1",
        "name": "Films",
        "root_paths": [str(library_root)],
    }
    settings_row = {
        "transcode_storage_mode": "dedicated",
        "transcode_cache_root": str(tmp_path / "cache"),
    }

    out = transcode_service._sidecar_path(file_row, settings_row, library_row)
    assert out == (tmp_path / "cache" / "Films" / "Movies" / "2024" / "Dune.h264.mkv")


def test_sidecar_path_inline_uses_subfolder(tmp_path):
    src = tmp_path / "Movies" / "Dune.mkv"
    src.parent.mkdir(parents=True)
    file_row = {"path": str(src), "library_id": None}
    settings_row = {"transcode_storage_mode": "inline"}

    out = transcode_service._sidecar_path(file_row, settings_row, None)
    assert out == src.parent / ".fluxora-transcodes" / "Dune.h264.mkv"


def test_sidecar_path_webm_forces_mkv(tmp_path):
    """M6 — H.264 can't be muxed into WebM; sidecar is forced to .mkv."""
    src = tmp_path / "clip.webm"
    file_row = {"path": str(src), "library_id": None}
    settings_row = {"transcode_storage_mode": "inline"}

    out = transcode_service._sidecar_path(file_row, settings_row, None)
    assert out.suffix == ".mkv"
    assert out.name == "clip.h264.mkv"


def test_sidecar_path_dedicated_falls_back_to_default_root_when_unset(tmp_path):
    library_root = tmp_path / "lib"
    library_root.mkdir()
    file_row = {"path": str(library_root / "x.mkv"), "library_id": "lib-1"}
    library_row = {"name": "L", "root_paths": [str(library_root)]}
    settings_row = {"transcode_storage_mode": "dedicated"}

    out = transcode_service._sidecar_path(file_row, settings_row, library_row)
    # Resolves under whichever default cache root the server picks; we
    # only assert the relative-to-library shape because the absolute
    # parent depends on the platform-correct data dir.
    assert out.name == "x.h264.mkv"
    assert "L" in out.parts


# ── Plan 19 §M6 — partial-output cleanup on crash recovery ─────────────────


@pytest.mark.asyncio
async def test_crash_recovery_unlinks_partial_sidecar(test_db, monkeypatch, tmp_path):
    """A crashed job's partial sidecar must be removed on next boot."""

    async def _fake_resolve():
        return "libx264"

    monkeypatch.setattr(transcode_service, "_resolve_encoder", _fake_resolve)

    # Set up a library + file pair so `_sidecar_path` resolves cleanly.
    import json
    import uuid as _uuid

    lib_id = str(_uuid.uuid4())
    lib_root = tmp_path / "lib"
    lib_root.mkdir()
    (lib_root / "src.mkv").write_bytes(b"\x00")
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?, ?, ?, ?, ?)",
        (
            lib_id,
            "L",
            "movies",
            json.dumps([str(lib_root)]),
            datetime.now(UTC).isoformat(),
        ),
    )
    fid = str(_uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, codec_name,
             library_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            fid,
            str(lib_root / "src.mkv"),
            "src.mkv",
            ".mkv",
            100,
            "av1",
            lib_id,
            now,
            now,
        ),
    )
    await test_db.commit()

    [job_id] = await transcode_service.queue(test_db, [fid])
    # Mark the job as orphan-running and pre-place a "partial" sidecar
    # at the path the resolver computes.  Settings default to dedicated
    # mode + default cache root.
    await test_db.execute(
        "UPDATE transcode_jobs SET status = 'running', started_at = ?" " WHERE id = ?",
        (int(time.time()), job_id),
    )
    await test_db.commit()

    # Force an inline cache so the sidecar lands under tmp_path
    # rather than the platform data dir.
    await test_db.execute(
        "UPDATE user_settings SET transcode_storage_mode = 'inline'" " WHERE id = 1"
    )
    await test_db.commit()

    sidecar = tmp_path / "lib" / ".fluxora-transcodes" / "src.h264.mkv"
    sidecar.parent.mkdir(parents=True, exist_ok=True)
    sidecar.write_bytes(b"partial-encode")
    assert sidecar.exists()

    swept = await transcode_service._recover_orphan_running_jobs(test_db)
    assert swept == 1
    assert not sidecar.exists()


# ── Plan 19 §M3 — storage aggregate ────────────────────────────────────────


@pytest.mark.asyncio
async def test_storage_aggregate_returns_zeros_when_empty(test_db):
    payload = await transcode_service.storage_aggregate(test_db)
    assert payload["transcoded_size_bytes"] == 0
    assert payload["transcoded_file_count"] == 0
    assert payload["by_codec"] == {}
    assert payload["storage_mode"] == "dedicated"
    assert Path(payload["cache_root"]).is_absolute()


@pytest.mark.asyncio
async def test_storage_aggregate_groups_by_codec(test_db):
    # Two transcoded AV1 files + one transcoded VP9 file.
    for size, codec in [(1_000, "av1"), (2_000, "av1"), (5_000, "vp9")]:
        fid = str(uuid.uuid4())
        now = datetime.now(UTC).isoformat()
        await test_db.execute(
            """
            INSERT INTO media_files
                (id, path, name, extension, size_bytes, codec_name,
                 transcoded_path, transcoded_size_bytes,
                 created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                fid,
                f"/m/{fid}.mkv",
                f"f-{fid[:6]}.mkv",
                ".mkv",
                size * 2,
                codec,
                f"/sidecar/{fid}.mkv",
                size,
                now,
                now,
            ),
        )
    await test_db.commit()

    payload = await transcode_service.storage_aggregate(test_db)
    assert payload["transcoded_file_count"] == 3
    assert payload["transcoded_size_bytes"] == 8_000
    assert payload["by_codec"]["av1"]["count"] == 2
    assert payload["by_codec"]["av1"]["bytes"] == 3_000
    assert payload["by_codec"]["vp9"]["count"] == 1
    assert payload["by_codec"]["vp9"]["bytes"] == 5_000


# ── Plan 19 §M6 — stale-sidecar detection ─────────────────────────────────


@pytest.mark.asyncio
async def test_stale_sidecar_detection_clears_path_on_mtime_advance(test_db, tmp_path):
    """Library scan re-discovering a file whose source mtime advanced
    past `transcoded_source_mtime` clears the row's transcoded_path."""
    import json as _json
    import uuid as _uuid

    from services import library_service as _libsvc

    src = tmp_path / "lib" / "movie.mkv"
    src.parent.mkdir()
    src.write_bytes(b"original")

    lib_id = str(_uuid.uuid4())
    await test_db.execute(
        "INSERT INTO libraries (id, name, type, root_paths, created_at)"
        " VALUES (?, ?, ?, ?, ?)",
        (
            lib_id,
            "L",
            "movies",
            _json.dumps([str(src.parent)]),
            datetime.now(UTC).isoformat(),
        ),
    )
    fid = str(_uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    # Stamp `transcoded_source_mtime` deliberately in the past so any
    # current mtime advance will trigger the stale clear.
    old_mtime = int(src.stat().st_mtime) - 1_000
    await test_db.execute(
        """
        INSERT INTO media_files
            (id, path, name, extension, size_bytes, codec_name,
             transcoded_path, transcoded_source_mtime,
             library_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            fid,
            str(src),
            "movie.mkv",
            ".mkv",
            8,
            "av1",
            "/sidecar/movie.h264.mkv",
            old_mtime,
            lib_id,
            now,
            now,
        ),
    )
    await test_db.commit()

    await _libsvc.scan_library(test_db, lib_id)

    async with test_db.execute(
        "SELECT transcoded_path FROM media_files WHERE id = ?", (fid,)
    ) as cur:
        row = await cur.fetchone()
    assert row["transcoded_path"] is None
