"""Library transcode REST surface.

Plan: docs/10_planning/18_library_transcode_plan.md.

| Method | Path                                            | Auth                |
|--------|-------------------------------------------------|---------------------|
| GET    | /api/v1/transcode/candidates                    | token-or-local      |
| POST   | /api/v1/transcode/queue                         | token-or-local      |
| GET    | /api/v1/transcode/jobs                          | token-or-local      |
| DELETE | /api/v1/transcode/jobs/{id}                     | token-or-local      |
| POST   | /api/v1/transcode/jobs/{id}/retry               | token-or-local      |

The desktop control panel is the primary consumer; mobile clients
never see this surface.  The same auth gate as ``/api/v1/files`` is
used so a tunneled desktop request still gets through with a bearer
token and a localhost desktop request bypasses auth.
"""

import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from database.db import get_db
from models.transcode import (
    TranscodeCandidate,
    TranscodeJobResponse,
    TranscodeQueueRequest,
    TranscodeQueueResponse,
    TranscodeRetryResponse,
    TranscodeStorageResponse,
)
from routers.deps import validate_token_or_local
from services import transcode_service

logger = logging.getLogger(__name__)

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)


# ── GET /api/v1/transcode/candidates ───────────────────────────────────────


@router.get("/candidates", response_model=list[TranscodeCandidate])
async def list_candidates(
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[TranscodeCandidate]:
    """List AV1/VP9 files that don't yet have a transcoded sidecar."""
    return await transcode_service.candidates(db)


# ── POST /api/v1/transcode/queue ───────────────────────────────────────────


@router.post(
    "/queue",
    response_model=TranscodeQueueResponse,
    status_code=status.HTTP_201_CREATED,
)
@limiter.limit("10/minute")
async def queue_jobs(
    body: TranscodeQueueRequest,
    request: Request,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> TranscodeQueueResponse:
    """Enqueue one transcode job per accepted candidate.

    Validation:

    * Empty list -> 400 (caught by the ``min_length=1`` constraint).
    * Any non-existent / non-candidate file id -> 400 with a useful
      detail string identifying the offending id.
    * Files that already have a queued / running job are skipped
      silently — the returned ``job_ids`` only contains the newly-
      created ids.
    """
    try:
        job_ids = await transcode_service.queue(db, body.file_ids, preset=body.preset)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    return TranscodeQueueResponse(job_ids=job_ids)


# ── GET /api/v1/transcode/storage ──────────────────────────────────────────


@router.get("/storage", response_model=TranscodeStorageResponse)
async def get_storage(
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> TranscodeStorageResponse:
    """Plan 19 §M3 — aggregate transcode-cache disk usage.

    Polled by the desktop's storage-strip widget every 5 s while the
    Transcode screen is mounted, so the query stays cheap (one SUM,
    one COUNT, grouped per source codec, plus a single
    ``shutil.disk_usage`` syscall).
    """
    payload = await transcode_service.storage_aggregate(db)
    return TranscodeStorageResponse(**payload)


# ── GET /api/v1/transcode/jobs ─────────────────────────────────────────────


_VALID_STATUSES = ("queued", "running", "done", "failed", "cancelled")


@router.get("/jobs", response_model=list[TranscodeJobResponse])
async def list_jobs(
    request: Request,
    status_filter: str | None = Query(default=None, alias="status"),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[TranscodeJobResponse]:
    """List jobs, optionally filtered by ``?status=`` (CSV).

    ``?status=running,queued`` returns only those.  Empty / missing
    => all rows.  Unknown status values are dropped silently rather
    than 400'd so a forward-compat client doesn't break the panel.
    """
    statuses: list[str] | None = None
    if status_filter:
        statuses = [
            s.strip() for s in status_filter.split(",") if s.strip() in _VALID_STATUSES
        ]
        if not statuses:
            # Caller asked to filter but every value was unknown — return
            # empty rather than the full list to honor the intent.
            return []
    return await transcode_service.list_jobs(db, statuses)


# ── DELETE /api/v1/transcode/jobs/{id} ─────────────────────────────────────


@router.delete("/jobs/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_job(
    job_id: int,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> None:
    """Cancel a queued or running job."""
    # Look up so we can distinguish 404 from 409 cleanly.
    existing = await transcode_service.get_job(db, job_id)
    if existing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="job not found"
        )
    if existing.status not in ("queued", "running"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"job already terminal (status={existing.status})",
        )
    ok = await transcode_service.cancel(db, job_id)
    if not ok:
        # Race: terminal between the GET and the cancel.  Surface 409.
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="job is no longer cancellable",
        )


# ── POST /api/v1/transcode/jobs/{id}/retry ─────────────────────────────────


@router.post(
    "/jobs/{job_id}/retry",
    response_model=TranscodeRetryResponse,
    status_code=status.HTTP_201_CREATED,
)
async def retry_job(
    job_id: int,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> TranscodeRetryResponse:
    """Clone a failed/cancelled job into a new queued one."""
    try:
        new_id = await transcode_service.retry(db, job_id)
    except LookupError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=str(exc)
        ) from exc
    return TranscodeRetryResponse(new_job_id=new_id)
