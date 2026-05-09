"""Pydantic models for the user-initiated library transcode feature.

Plan: docs/10_planning/18_library_transcode_plan.md.

These models are the wire contract between the desktop control panel
and the new ``/api/v1/transcode/...`` router.  Mobile clients never see
this surface — pre-transcode is a desktop-only workflow.
"""

from typing import Literal

from pydantic import BaseModel, Field

JobStatus = Literal["queued", "running", "done", "failed", "cancelled"]


class TranscodeCandidate(BaseModel):
    """One file eligible for pre-transcode.

    Returned by ``GET /api/v1/transcode/candidates``.  ``video_codec`` is
    the lower-cased ffprobe codec name (``av1`` / ``vp9``).
    ``est_output_size_bytes`` is a coarse estimate (2.0x source for AV1,
    1.5x for VP9) — the desktop renders it with a tilde to make the
    fuzziness visible to the operator.
    """

    file_id: str
    name: str
    library_id: str
    size_bytes: int
    video_codec: str
    duration_sec: float | None = None
    est_output_size_bytes: int


class TranscodeQueueRequest(BaseModel):
    """Body for ``POST /api/v1/transcode/queue``.

    Up to 50 file ids per request — the desktop's multi-select UI fits
    well below that ceiling, and the cap stops a runaway client from
    enqueueing thousands of rows in one POST.
    """

    file_ids: list[str] = Field(min_length=1, max_length=50)


class TranscodeQueueResponse(BaseModel):
    """Newly-created job ids — one per accepted candidate.

    Files that were already enqueued (queued / running) are skipped
    silently and do not appear in the returned list.  Callers that need
    to reconcile UI state should follow up with ``GET /jobs``.
    """

    job_ids: list[int]


class TranscodeJobResponse(BaseModel):
    """One row from ``transcode_jobs`` joined with ``media_files.name``.

    Returned by ``GET /jobs`` (list) and ``GET /jobs/{id}`` (single).
    Field naming mirrors the SQL column names so the desktop tab can
    bind directly without a remap layer.
    """

    id: int
    file_id: str
    file_name: str
    status: JobStatus
    progress_pct: float
    eta_sec: int | None = None
    error: str | None = None
    output_path: str | None = None
    encoder: str
    created_at: int
    started_at: int | None = None
    finished_at: int | None = None


class TranscodeRetryResponse(BaseModel):
    """Returned by ``POST /jobs/{id}/retry``.

    The original failed/cancelled job is left untouched (its ``error``
    column is the History tab's record of what went wrong); a new
    queued job is inserted and its id is returned.
    """

    new_job_id: int
