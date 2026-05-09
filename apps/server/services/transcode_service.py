"""User-initiated library transcode service.

Plan: docs/10_planning/18_library_transcode_plan.md.

Single-worker FIFO that pre-transcodes AV1 / VP9 sources to H.264
sidecars stored next to the original file.  Once a sidecar exists,
``ffmpeg_service.start_stream`` falls into the existing direct-remux
H.264 branch and stream-copies it instead of doing live software
decode -> NVENC.

Public surface:

* ``candidates(db)`` — list AV1/VP9 files without a sidecar.
* ``queue(db, file_ids)`` — accept a batch of file ids; insert one
  ``transcode_jobs`` row per accepted candidate, return the new ids.
* ``cancel(db, job_id)`` — mark a queued job cancelled or SIGTERM the
  running FFmpeg if the job is in flight.
* ``list_jobs(db, statuses)`` — return jobs filtered by status set.
* ``get_job(db, job_id)`` — return one job.
* ``retry(db, job_id)`` — clone a failed/cancelled job into a new
  queued one.
* ``start_worker()`` / ``stop_worker()`` — lifespan hooks.

The worker is a single asyncio task.  Concurrency is locked at 1 for
v1; raising it is a future settings-driven enhancement.
"""

from __future__ import annotations

import asyncio
import logging
import time
from pathlib import Path
from typing import Any

import aiosqlite

from models.transcode import (
    TranscodeCandidate,
    TranscodeJobResponse,
)
from services.ffmpeg_service import _ffmpeg_bin, _probe_audio_params

logger = logging.getLogger(__name__)


# ── encoder selection ──────────────────────────────────────────────────────

# Quality presets.  v1 ships a single preset string per encoder so the
# UI doesn't need to expose a picker.  ``slow_cq19`` and ``slow_crf19``
# are visually equivalent (~2x source size, transparent on a typical
# 1080p source).
_QUALITY_PRESET_NVENC = "slow_cq19"
_QUALITY_PRESET_LIBX264 = "slow_crf19"

# Output-size estimator — coarse multipliers from §3 of the plan.
# Used by candidates() so the desktop can render an aggregate disk
# footprint without re-implementing the math client-side.
_OUTPUT_SIZE_MULTIPLIER = {
    "av1": 2.0,
    "vp9": 1.5,
}

# Codec names accepted as candidates.  Matched case-insensitively
# against ``media_files.codec_name`` (see migration 016).
_CANDIDATE_CODECS = ("av1", "vp9")


async def _detect_h264_nvenc_available() -> bool:
    """Return True iff this FFmpeg build advertises ``h264_nvenc`` in
    its encoder list.  Mirrors the heuristic used elsewhere in the
    server: a single ``ffmpeg -encoders`` probe, cheap, no caching at
    this layer (the streaming-pipeline transcoding_service already
    caches process-wide).
    """
    try:
        bin_path = _ffmpeg_bin()
    except FileNotFoundError:
        return False
    try:
        proc = await asyncio.create_subprocess_exec(
            bin_path,
            "-hide_banner",
            "-encoders",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        out, _ = await asyncio.wait_for(proc.communicate(), timeout=5.0)
    except (TimeoutError, OSError) as exc:
        logger.warning("ffmpeg -encoders probe failed: %s", exc)
        return False
    return b"h264_nvenc" in (out or b"")


async def _resolve_encoder() -> str:
    """Pick the encoder for new jobs.  ``h264_nvenc`` if FFmpeg has it,
    else ``libx264``.  No quality-preset choice — v1 ships one preset
    per encoder.
    """
    if await _detect_h264_nvenc_available():
        return "h264_nvenc"
    return "libx264"


def _quality_preset_for(encoder: str) -> str:
    """Return the canonical preset string we persist on the job row.

    The string is descriptive only — the FFmpeg cmd builder maps it
    back to actual flags.  Stored on the job row so the History tab
    can display "what was actually used" without re-deriving it from
    the encoder name.
    """
    if encoder == "h264_nvenc":
        return _QUALITY_PRESET_NVENC
    return _QUALITY_PRESET_LIBX264


def _sidecar_path(source_path: str) -> Path:
    """Return the sidecar path for ``source_path``.

    ``Avicii.mkv`` -> ``Avicii.h264.mkv``.  Lives next to the source
    so the operator's existing backup tooling follows it naturally
    and removing the source removes the sidecar at the same time.
    """
    src = Path(source_path)
    return src.with_name(f"{src.stem}.h264{src.suffix}")


def _est_output_size(codec: str | None, size_bytes: int) -> int:
    """Coarse estimator — see ``_OUTPUT_SIZE_MULTIPLIER``."""
    if not codec:
        return size_bytes
    mult = _OUTPUT_SIZE_MULTIPLIER.get(codec.lower(), 1.5)
    return int(size_bytes * mult)


# ── candidate listing ─────────────────────────────────────────────────────


async def candidates(db: aiosqlite.Connection) -> list[TranscodeCandidate]:
    """Return AV1/VP9 files that don't yet have a sidecar.

    Excludes any file whose ``transcoded_path`` is non-NULL (already
    transcoded) — even if the sidecar has since been deleted on disk.
    The History tab is responsible for surfacing the "sidecar missing"
    state.
    """
    async with db.execute(
        """
        SELECT id, name, library_id, size_bytes, codec_name, duration_sec
          FROM media_files
         WHERE LOWER(codec_name) IN ('av1','vp9')
           AND transcoded_path IS NULL
         ORDER BY name COLLATE NOCASE
        """
    ) as cur:
        rows = await cur.fetchall()

    out: list[TranscodeCandidate] = []
    for r in rows:
        codec = (r["codec_name"] or "").lower()
        out.append(
            TranscodeCandidate(
                file_id=r["id"],
                name=r["name"],
                library_id=r["library_id"] or "",
                size_bytes=int(r["size_bytes"] or 0),
                video_codec=codec,
                duration_sec=(
                    float(r["duration_sec"]) if r["duration_sec"] is not None else None
                ),
                est_output_size_bytes=_est_output_size(
                    codec, int(r["size_bytes"] or 0)
                ),
            )
        )
    return out


# ── queue / cancel / list / retry ─────────────────────────────────────────


async def _file_is_candidate(
    db: aiosqlite.Connection, file_id: str
) -> tuple[bool, str | None]:
    """Validate that ``file_id`` exists, is AV1/VP9, and has no sidecar.

    Returns ``(True, None)`` on success, ``(False, reason)`` otherwise
    so the router can return 400 with a useful detail.
    """
    async with db.execute(
        "SELECT codec_name, transcoded_path FROM media_files WHERE id = ?",
        (file_id,),
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        return False, f"file_id not found: {file_id}"
    codec = (row["codec_name"] or "").lower()
    if codec not in _CANDIDATE_CODECS:
        return False, f"file is not an AV1/VP9 candidate: {file_id} (codec={codec})"
    if row["transcoded_path"]:
        return False, f"file already has a transcoded sidecar: {file_id}"
    return True, None


async def _has_active_job(db: aiosqlite.Connection, file_id: str) -> bool:
    async with db.execute(
        "SELECT 1 FROM transcode_jobs"
        " WHERE file_id = ? AND status IN ('queued','running')"
        " LIMIT 1",
        (file_id,),
    ) as cur:
        row = await cur.fetchone()
    return row is not None


async def queue(
    db: aiosqlite.Connection,
    file_ids: list[str],
    encoder: str | None = None,
) -> list[int]:
    """Enqueue transcode jobs for the given file ids.

    De-dupes within the input list (same file id twice => one job).
    Skips files that already have a queued / running job (returns
    quietly — caller reconciles via ``GET /jobs``).  Validates each
    file is a real AV1/VP9 candidate; the first invalid id raises
    ``ValueError`` which the router converts to 400.
    """
    # De-dupe the input list while preserving order.  ``set()`` would
    # lose order, which would scramble the returned ``job_ids`` list
    # relative to the request — confusing for the desktop UI.
    seen: set[str] = set()
    deduped: list[str] = []
    for fid in file_ids:
        if fid in seen:
            continue
        seen.add(fid)
        deduped.append(fid)

    chosen_encoder = encoder or await _resolve_encoder()
    preset = _quality_preset_for(chosen_encoder)
    now = int(time.time())

    job_ids: list[int] = []
    for fid in deduped:
        ok, reason = await _file_is_candidate(db, fid)
        if not ok:
            raise ValueError(reason or f"invalid file_id: {fid}")
        if await _has_active_job(db, fid):
            logger.info(
                "transcode queue: skipping %s (already has a queued/running job)",
                fid,
            )
            continue
        cur = await db.execute(
            """
            INSERT INTO transcode_jobs
                (file_id, target_codec, encoder, quality_preset, status,
                 progress_pct, created_at)
            VALUES (?, 'h264', ?, ?, 'queued', 0.0, ?)
            """,
            (fid, chosen_encoder, preset, now),
        )
        job_ids.append(int(cur.lastrowid))
    if job_ids:
        await db.commit()

    # Wake the worker so a freshly queued job doesn't sit idle for the
    # full poll interval.  Best-effort — if there's no worker running
    # (test paths that never started one) the wake is a no-op.
    _wake_worker()
    return job_ids


async def cancel(db: aiosqlite.Connection, job_id: int) -> bool:
    """Cancel a queued or running job.

    * Queued -> mark cancelled, never spawned.
    * Running -> SIGTERM the FFmpeg process (worker handles cleanup
      on the way out via the cancellation flag), mark cancelled.
    * Terminal (done/failed/cancelled) or missing -> return False.
    """
    async with db.execute(
        "SELECT status FROM transcode_jobs WHERE id = ?", (job_id,)
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        return False
    status = row["status"]
    if status not in ("queued", "running"):
        return False

    now = int(time.time())
    if status == "queued":
        await db.execute(
            "UPDATE transcode_jobs SET status = 'cancelled', finished_at = ?"
            " WHERE id = ?",
            (now, job_id),
        )
        await db.commit()
        logger.info("transcode job %s cancelled (was queued)", job_id)
        return True

    # status == 'running' — terminate the FFmpeg process if the worker
    # has tracked one for this job.  The worker loop handles partial-
    # output deletion + DB transition on its own when the process
    # exits, but we set the cancel flag + write 'cancelled' here so
    # the API returns the new status atomically.
    proc = _RUNNING_PROCS.get(job_id)
    if proc is not None and proc.returncode is None:
        try:
            # Use SIGTERM on POSIX, terminate() on Windows (which sends
            # a TerminateProcess underneath).  Both produce a non-zero
            # returncode that the worker classifies as cancellation
            # via the ``_CANCEL_FLAGS`` set.
            _CANCEL_FLAGS.add(job_id)
            proc.terminate()
        except Exception:
            logger.warning(
                "Failed to terminate FFmpeg for job %s", job_id, exc_info=True
            )
    await db.execute(
        "UPDATE transcode_jobs SET status = 'cancelled', finished_at = ?"
        " WHERE id = ?",
        (now, job_id),
    )
    await db.commit()
    logger.info("transcode job %s cancelled (was running)", job_id)
    return True


async def list_jobs(
    db: aiosqlite.Connection,
    statuses: list[str] | None = None,
) -> list[TranscodeJobResponse]:
    """List jobs.  ``statuses=None`` => all; otherwise filter to that set."""
    sql = (
        "SELECT j.*, f.name AS file_name FROM transcode_jobs j"
        " LEFT JOIN media_files f ON f.id = j.file_id"
    )
    params: tuple[Any, ...] = ()
    if statuses:
        placeholders = ",".join("?" * len(statuses))
        sql += f" WHERE j.status IN ({placeholders})"
        params = tuple(statuses)
    sql += " ORDER BY j.id DESC"
    async with db.execute(sql, params) as cur:
        rows = await cur.fetchall()
    return [_row_to_job(r) for r in rows]


async def get_job(
    db: aiosqlite.Connection, job_id: int
) -> TranscodeJobResponse | None:
    async with db.execute(
        "SELECT j.*, f.name AS file_name FROM transcode_jobs j"
        " LEFT JOIN media_files f ON f.id = j.file_id"
        " WHERE j.id = ?",
        (job_id,),
    ) as cur:
        row = await cur.fetchone()
    return _row_to_job(row) if row else None


async def retry(db: aiosqlite.Connection, job_id: int) -> int:
    """Clone a failed/cancelled job into a new queued one.

    Raises:
        LookupError: job not found.
        ValueError: job is not in a retryable terminal state.
    """
    async with db.execute(
        "SELECT file_id, encoder, quality_preset, status FROM transcode_jobs"
        " WHERE id = ?",
        (job_id,),
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        raise LookupError(f"transcode job {job_id} not found")
    if row["status"] not in ("failed", "cancelled"):
        raise ValueError(
            f"transcode job {job_id} is not retryable (status={row['status']})"
        )

    # Skip if there's already a fresh queued/running job for the same
    # file — clicking Retry twice quickly shouldn't double-enqueue.
    if await _has_active_job(db, row["file_id"]):
        async with db.execute(
            "SELECT id FROM transcode_jobs"
            " WHERE file_id = ? AND status IN ('queued','running')"
            " ORDER BY id DESC LIMIT 1",
            (row["file_id"],),
        ) as cur:
            existing = await cur.fetchone()
        if existing:
            return int(existing["id"])

    now = int(time.time())
    cur = await db.execute(
        """
        INSERT INTO transcode_jobs
            (file_id, target_codec, encoder, quality_preset, status,
             progress_pct, created_at)
        VALUES (?, 'h264', ?, ?, 'queued', 0.0, ?)
        """,
        (row["file_id"], row["encoder"], row["quality_preset"], now),
    )
    new_id = int(cur.lastrowid)
    await db.commit()
    _wake_worker()
    return new_id


def _row_to_job(row: aiosqlite.Row) -> TranscodeJobResponse:
    return TranscodeJobResponse(
        id=int(row["id"]),
        file_id=row["file_id"],
        file_name=row["file_name"] or "",
        status=row["status"],
        progress_pct=float(row["progress_pct"] or 0.0),
        eta_sec=int(row["eta_sec"]) if row["eta_sec"] is not None else None,
        error=row["error"],
        output_path=row["output_path"],
        encoder=row["encoder"],
        created_at=int(row["created_at"]),
        started_at=(
            int(row["started_at"]) if row["started_at"] is not None else None
        ),
        finished_at=(
            int(row["finished_at"]) if row["finished_at"] is not None else None
        ),
    )


# ── worker loop ──────────────────────────────────────────────────────────

# Module-level state for the single worker task.  Kept inside the
# module so tests that import the service get a clean view; ``main.py``
# owns the lifecycle via ``start_worker`` / ``stop_worker``.
_WORKER_TASK: asyncio.Task[None] | None = None
_WORKER_WAKEUP: asyncio.Event | None = None
_WORKER_STOP: asyncio.Event | None = None

# Track the live FFmpeg subprocess per job_id so ``cancel()`` can
# terminate it.  Cleared in the worker as soon as the process exits.
_RUNNING_PROCS: dict[int, asyncio.subprocess.Process] = {}

# Set of job_ids the API requested cancellation for.  The worker reads
# this on FFmpeg exit to distinguish a user-driven cancel (returncode
# from SIGTERM) from a genuine encoder error.
_CANCEL_FLAGS: set[int] = set()

# Worker poll interval — how long the loop waits between DB scans
# when the queue is empty.  The wake-event makes typical latency
# sub-second; this is the upper bound when the event was missed.
_POLL_INTERVAL_SEC = 2.0

# Progress update cadence.  FFmpeg's ``-progress`` writes lines fast;
# we throttle the DB UPDATE so a 30-minute encode doesn't generate
# 30 000 writes.
_PROGRESS_UPDATE_INTERVAL_SEC = 1.5


def _wake_worker() -> None:
    if _WORKER_WAKEUP is not None and not _WORKER_WAKEUP.is_set():
        _WORKER_WAKEUP.set()


async def start_worker() -> None:
    """Start the single worker task.  Idempotent — repeat calls are no-ops.

    Called from ``main.py`` lifespan after ``init_db``.  Also runs the
    crash-recovery sweep that re-marks any orphan ``running`` rows
    as failed (server died mid-job last time).
    """
    global _WORKER_TASK, _WORKER_WAKEUP, _WORKER_STOP

    if _WORKER_TASK is not None and not _WORKER_TASK.done():
        return

    from database.db import get_db

    db = await get_db()
    await _recover_orphan_running_jobs(db)

    _WORKER_WAKEUP = asyncio.Event()
    _WORKER_STOP = asyncio.Event()
    _WORKER_TASK = asyncio.create_task(_worker_loop(), name="transcode-worker")
    logger.info("Transcode worker started")


async def stop_worker() -> None:
    """Cancel the worker + any in-flight FFmpeg process.

    Best-effort.  Called from the FastAPI lifespan shutdown branch.
    """
    global _WORKER_TASK

    if _WORKER_STOP is not None:
        _WORKER_STOP.set()
    if _WORKER_WAKEUP is not None:
        _WORKER_WAKEUP.set()

    # Terminate any in-flight FFmpeg so a Ctrl-C doesn't leave a
    # zombie burning CPU.  The worker's exit branch handles partial-
    # file cleanup + the DB transition on its own.
    for job_id, proc in list(_RUNNING_PROCS.items()):
        if proc.returncode is None:
            _CANCEL_FLAGS.add(job_id)
            try:
                proc.terminate()
            except Exception:
                logger.warning(
                    "stop_worker: failed to terminate FFmpeg for job %s",
                    job_id,
                    exc_info=True,
                )

    if _WORKER_TASK is not None:
        try:
            await asyncio.wait_for(_WORKER_TASK, timeout=10.0)
        except (TimeoutError, asyncio.CancelledError):
            _WORKER_TASK.cancel()
        except Exception:
            logger.warning("Transcode worker raised on shutdown", exc_info=True)
        _WORKER_TASK = None
    logger.info("Transcode worker stopped")


async def _recover_orphan_running_jobs(db: aiosqlite.Connection) -> int:
    """On boot, mark any ``running`` rows from a previous server run
    as failed so the worker doesn't think a long-dead PID still owns
    them.  Runs *before* ``_worker_loop`` accepts new work.
    """
    now = int(time.time())
    result = await db.execute(
        """
        UPDATE transcode_jobs
           SET status = 'failed',
               error = 'server restarted mid-job',
               finished_at = ?
         WHERE status = 'running'
        """,
        (now,),
    )
    await db.commit()
    if result.rowcount:
        logger.warning(
            "Recovered %d orphan running transcode job(s) on startup",
            result.rowcount,
        )
    return int(result.rowcount or 0)


async def _worker_loop() -> None:
    """Single-tenant FIFO worker.

    Polls for the oldest queued job, transitions it through
    running -> done/failed/cancelled.  Survives encoder errors —
    a failed job logs and the loop continues.  Exits when
    ``_WORKER_STOP`` is set.
    """
    from database.db import get_db

    assert _WORKER_STOP is not None
    assert _WORKER_WAKEUP is not None

    db = await get_db()
    while not _WORKER_STOP.is_set():
        job_row = await _pop_queued(db)
        if job_row is None:
            try:
                await asyncio.wait_for(
                    _WORKER_WAKEUP.wait(), timeout=_POLL_INTERVAL_SEC
                )
            except TimeoutError:
                pass
            _WORKER_WAKEUP.clear()
            continue

        job_id = int(job_row["id"])
        try:
            await _run_job(db, job_row)
        except Exception:
            # Last-line defence — a bug in the dispatcher must not kill
            # the worker.  Mark the job failed so it doesn't re-poll
            # forever and continue to the next one.
            logger.exception("transcode worker: dispatch raised for job %s", job_id)
            try:
                await _mark_failed(
                    db, job_id, error="worker dispatch raised; see server logs"
                )
            except Exception:
                logger.exception(
                    "transcode worker: failed to mark job %s failed"
                    " after dispatch error",
                    job_id,
                )


async def _pop_queued(db: aiosqlite.Connection) -> aiosqlite.Row | None:
    """Atomically claim the oldest queued job.

    SQLite has no ``SELECT ... FOR UPDATE``; the single-worker
    invariant makes the SELECT-then-UPDATE pattern safe (no other
    consumer will race us for the row).  ``status=running`` is
    written here so the API's status feed reflects the transition
    immediately.
    """
    now = int(time.time())
    async with db.execute(
        "SELECT * FROM transcode_jobs WHERE status = 'queued'"
        " ORDER BY id ASC LIMIT 1"
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        return None
    await db.execute(
        "UPDATE transcode_jobs SET status = 'running', started_at = ?,"
        " progress_pct = 0.0 WHERE id = ?",
        (now, row["id"]),
    )
    await db.commit()
    return row


async def _run_job(db: aiosqlite.Connection, job_row: aiosqlite.Row) -> None:
    """Run a single FFmpeg invocation for the given job.

    Steps:

    1. Resolve source path + sidecar path.  If the sidecar already
       exists on disk, fail the job with ``output_path_collision``.
    2. Probe the source's audio codec to pick ``-c:a copy`` vs
       ``-c:a aac``.
    3. Build the FFmpeg command with the encoder-appropriate quality
       flags.
    4. Spawn the subprocess; parse stderr for ``out_time_ms=...`` to
       drive ``progress_pct`` + ``eta_sec`` updates.
    5. On exit: success -> stat the output, write
       ``media_files.transcoded_*`` columns, mark job done.
       Failure -> capture stderr tail, delete partial output, mark
       failed.  Cancellation -> mark cancelled (status was already
       written by ``cancel()`` but this branch handles
       ``stop_worker()`` shutdowns).
    """
    job_id = int(job_row["id"])
    file_id = job_row["file_id"]
    encoder = job_row["encoder"]

    async with db.execute(
        "SELECT path, duration_sec FROM media_files WHERE id = ?", (file_id,)
    ) as cur:
        file_row = await cur.fetchone()
    if file_row is None:
        await _mark_failed(db, job_id, error="source file row missing")
        return

    source_path = file_row["path"]
    duration_sec: float | None = (
        float(file_row["duration_sec"]) if file_row["duration_sec"] else None
    )
    output_path = _sidecar_path(source_path)

    # output_path_collision — fail loudly rather than overwrite a
    # mystery file the operator left next to the source.
    if output_path.exists():
        msg = f"output path collision: {output_path}"
        logger.warning("transcode job %s aborted — %s", job_id, msg)
        await _mark_failed(db, job_id, error=msg)
        return

    # Probe audio so the cmd builder can choose copy vs re-encode.
    audio_codec_name: str | None = None
    try:
        info = await _probe_audio_params(source_path)
        if info is not None:
            raw = info.get("codec_name")
            if isinstance(raw, str):
                audio_codec_name = raw.lower()
    except Exception:
        # Diagnostic only; default to re-encode if probe fails.
        logger.debug(
            "transcode audio probe failed for %s", source_path, exc_info=True
        )

    cmd = _build_ffmpeg_cmd(
        source_path=source_path,
        output_path=str(output_path),
        encoder=encoder,
        source_audio_codec=audio_codec_name,
    )

    logger.info(
        "transcode job %s starting: file_id=%s encoder=%s output=%s",
        job_id,
        file_id,
        encoder,
        output_path,
    )

    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.PIPE,
        )
    except (OSError, FileNotFoundError) as exc:
        await _mark_failed(db, job_id, error=f"failed to spawn FFmpeg: {exc}")
        return

    _RUNNING_PROCS[job_id] = proc
    stderr_tail: list[str] = []  # ring of recent lines for failure capture
    started_wallclock = time.time()

    try:
        await _drive_progress(
            db,
            job_id,
            proc,
            duration_sec=duration_sec,
            started_wallclock=started_wallclock,
            stderr_tail=stderr_tail,
        )
    finally:
        _RUNNING_PROCS.pop(job_id, None)

    cancelled = job_id in _CANCEL_FLAGS
    _CANCEL_FLAGS.discard(job_id)

    rc = proc.returncode if proc.returncode is not None else 1

    if cancelled:
        # cancel() already wrote 'cancelled' synchronously.  Just
        # delete the partial output.
        _cleanup_partial(output_path)
        logger.info("transcode job %s exited after cancellation (rc=%s)", job_id, rc)
        return

    if rc == 0:
        try:
            size_bytes = output_path.stat().st_size
        except OSError:
            size_bytes = 0
        await _mark_done(
            db,
            job_id,
            file_id=file_id,
            output_path=str(output_path),
            output_size_bytes=size_bytes,
        )
        logger.info(
            "transcode job %s done: %s (%d bytes)",
            job_id,
            output_path,
            size_bytes,
        )
        return

    # Failure path — capture stderr tail, delete partial output.
    tail_text = "".join(stderr_tail)[-240:]
    _cleanup_partial(output_path)
    await _mark_failed(
        db,
        job_id,
        error=tail_text or f"FFmpeg exited with code {rc}",
    )
    logger.warning(
        "transcode job %s failed (rc=%s) — see error column in DB", job_id, rc
    )


def _build_ffmpeg_cmd(
    *,
    source_path: str,
    output_path: str,
    encoder: str,
    source_audio_codec: str | None,
) -> list[str]:
    """Return the argv for the FFmpeg encode.

    Encoder flags follow §4.5 of the plan:
    NVENC -> ``-preset slow -cq 19 -profile:v high -pix_fmt yuv420p``
    libx264 -> ``-preset slow -crf 19 -profile:v high -pix_fmt yuv420p``

    Audio: ``-c:a copy`` when the source is AAC, else re-encode to
    AAC 192k.
    """
    bin_path = _ffmpeg_bin()
    cmd: list[str] = [
        bin_path,
        "-y",
        "-hide_banner",
        "-loglevel",
        "info",
        "-progress",
        "pipe:2",
        "-i",
        source_path,
        "-map",
        "0",
        "-c:v",
        encoder,
    ]
    if encoder == "h264_nvenc":
        cmd += [
            "-preset", "slow",
            "-cq", "19",
            "-profile:v", "high",
            "-pix_fmt", "yuv420p",
        ]
    else:
        # libx264 (or any other unknown encoder gets the software flags).
        cmd += [
            "-preset", "slow",
            "-crf", "19",
            "-profile:v", "high",
            "-pix_fmt", "yuv420p",
        ]

    if source_audio_codec == "aac":
        cmd += ["-c:a", "copy"]
    else:
        cmd += ["-c:a", "aac", "-b:a", "192k"]

    cmd += ["-c:s", "copy", "-movflags", "+faststart", output_path]
    return cmd


async def _drive_progress(
    db: aiosqlite.Connection,
    job_id: int,
    proc: asyncio.subprocess.Process,
    *,
    duration_sec: float | None,
    started_wallclock: float,
    stderr_tail: list[str],
) -> None:
    """Read FFmpeg's stderr line-by-line, parse ``out_time_ms`` for
    progress, and update ``transcode_jobs`` no more often than
    ``_PROGRESS_UPDATE_INTERVAL_SEC``.

    Also keeps the last ~2 KiB of stderr text in ``stderr_tail`` so
    the caller can write it to ``transcode_jobs.error`` on failure.
    """
    last_db_update = 0.0
    if proc.stderr is None:
        # We asked for stderr=PIPE; this branch shouldn't happen in
        # practice but guards against a future refactor.
        await proc.wait()
        return

    while True:
        try:
            raw = await proc.stderr.readline()
        except (ValueError, OSError):
            break
        if not raw:
            break
        try:
            line = raw.decode("utf-8", errors="replace")
        except Exception:
            line = ""
        if line:
            stderr_tail.append(line)
            # Cap memory — keep the last ~120 lines (~10 KiB).
            if len(stderr_tail) > 200:
                del stderr_tail[: len(stderr_tail) - 200]

        # Parse out_time_ms.  FFmpeg's `-progress pipe:2` emits one
        # KEY=VALUE per line.  We only care about out_time_ms here.
        out_time_us = _parse_out_time_us(line)
        if out_time_us is None:
            continue
        now = time.time()
        if now - last_db_update < _PROGRESS_UPDATE_INTERVAL_SEC:
            continue
        last_db_update = now

        progress_pct, eta_sec = _compute_progress(
            out_time_us=out_time_us,
            duration_sec=duration_sec,
            elapsed_wallclock=now - started_wallclock,
        )
        try:
            await db.execute(
                "UPDATE transcode_jobs SET progress_pct = ?, eta_sec = ?"
                " WHERE id = ?",
                (progress_pct, eta_sec, job_id),
            )
            await db.commit()
        except Exception:
            # DB hiccup must not crash the worker — log and keep going.
            logger.warning(
                "transcode job %s progress update raised", job_id, exc_info=True
            )

    # Drain to completion; rc is read by the caller.
    await proc.wait()


def _parse_out_time_us(line: str) -> int | None:
    """Return microseconds of source time encoded so far, or None.

    FFmpeg emits ``out_time_ms=<microseconds>`` (yes, despite the
    name — the unit is microseconds in modern builds).  The older
    ``out_time_us`` key is also accepted for safety.
    """
    if "=" not in line:
        return None
    key, _, value = line.partition("=")
    key = key.strip()
    value = value.strip()
    if key not in ("out_time_ms", "out_time_us"):
        return None
    try:
        return int(value)
    except ValueError:
        return None


def _compute_progress(
    *,
    out_time_us: int,
    duration_sec: float | None,
    elapsed_wallclock: float,
) -> tuple[float, int | None]:
    """Convert FFmpeg's progress signal into (pct, eta_sec)."""
    if not duration_sec or duration_sec <= 0:
        return 0.0, None
    out_time_sec = max(0.0, out_time_us / 1_000_000.0)
    pct = max(0.0, min(100.0, (out_time_sec / duration_sec) * 100.0))
    if out_time_sec <= 0 or elapsed_wallclock <= 0:
        return pct, None
    rate = out_time_sec / elapsed_wallclock  # encoded-seconds per wall-second
    if rate <= 0:
        return pct, None
    remaining_source_sec = max(0.0, duration_sec - out_time_sec)
    eta = int(remaining_source_sec / rate)
    return pct, eta


def _cleanup_partial(output_path: Path) -> None:
    """Best-effort delete of a partial output file."""
    try:
        if output_path.exists():
            output_path.unlink()
            logger.info("transcode: removed partial output %s", output_path)
    except OSError:
        logger.warning(
            "transcode: failed to remove partial output %s",
            output_path,
            exc_info=True,
        )


async def _mark_failed(
    db: aiosqlite.Connection, job_id: int, *, error: str
) -> None:
    now = int(time.time())
    await db.execute(
        "UPDATE transcode_jobs SET status = 'failed', error = ?,"
        " finished_at = ? WHERE id = ?",
        (error, now, job_id),
    )
    await db.commit()


async def _mark_done(
    db: aiosqlite.Connection,
    job_id: int,
    *,
    file_id: str,
    output_path: str,
    output_size_bytes: int,
) -> None:
    now = int(time.time())
    await db.execute(
        """
        UPDATE media_files
           SET transcoded_path = ?,
               transcoded_size_bytes = ?,
               transcoded_at = ?
         WHERE id = ?
        """,
        (output_path, output_size_bytes, now, file_id),
    )
    await db.execute(
        """
        UPDATE transcode_jobs
           SET status = 'done',
               progress_pct = 100.0,
               eta_sec = 0,
               output_path = ?,
               finished_at = ?
         WHERE id = ?
        """,
        (output_path, now, job_id),
    )
    await db.commit()


__all__ = [
    "candidates",
    "queue",
    "cancel",
    "list_jobs",
    "get_job",
    "retry",
    "start_worker",
    "stop_worker",
]
