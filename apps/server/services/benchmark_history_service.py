"""Persistence for encoder benchmark runs (migration 024).

Stores complete benchmark runs (top-level metadata + per-encoder results
JSON) so the desktop's Benchmark tab can render a historical sidebar — the
operator can compare today's NVENC throughput to last week's after a driver
update, or revisit the result that justified a particular encoder-chain
choice.

Capped to ``_HISTORY_LIMIT`` recent entries via :func:`prune_history` —
runs are cheap to recreate and the operator only ever cares about recent
comparisons.  Pruning happens after each save so the table stays bounded
without a separate background task.

Design notes
------------
* Per-encoder result rows live inside a single JSON column rather than
  their own table.  We always fetch full runs together (the sidebar shows
  the same data the live results pane does); a relational split would add
  a join + an order-preservation hassle for no query benefit at this
  scale.
* ``encoder_count`` is denormalized so list-summary queries don't parse
  the JSON body for every entry.
"""

from __future__ import annotations

import json
import logging
from dataclasses import asdict, is_dataclass
from typing import Any

import aiosqlite

from services.benchmark_service import EncoderBenchmarkResult

logger = logging.getLogger(__name__)


# Cap on rows kept in ``benchmark_runs``.  Older entries get deleted after
# every save so the table stays bounded.  50 covers ~weeks of comparisons
# at typical operator usage (one or two runs per driver / hardware change)
# without unbounded growth.
_HISTORY_LIMIT = 50


def _result_to_dict(result: EncoderBenchmarkResult) -> dict[str, Any]:
    """Serialise an :class:`EncoderBenchmarkResult` for the JSON column.

    Uses :func:`dataclasses.asdict` since the dataclass fields map 1:1 to
    the JSON keys the desktop entity expects (verified by the round-trip
    test).
    """
    if not is_dataclass(result):
        raise TypeError(
            f"expected EncoderBenchmarkResult dataclass, got {type(result)!r}"
        )
    return asdict(result)


async def save_benchmark_run(
    db: aiosqlite.Connection,
    *,
    started_at: str,
    finished_at: str,
    duration_sec: int,
    fps: int,
    width: int,
    height: int,
    verify_caps: bool,
    results: list[EncoderBenchmarkResult],
) -> int:
    """Insert a benchmark run and prune older entries.

    Returns the autoincrement ``id`` of the new row so the caller (the
    benchmark router) can include it in the response — the desktop uses
    it to keep the visible result row in sync with the history sidebar.
    """
    payload = json.dumps([_result_to_dict(r) for r in results])
    cursor = await db.execute(
        """
        INSERT INTO benchmark_runs (
            started_at, finished_at, duration_sec,
            fps, width, height, verify_caps,
            encoder_count, results_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            started_at,
            finished_at,
            duration_sec,
            fps,
            width,
            height,
            1 if verify_caps else 0,
            len(results),
            payload,
        ),
    )
    new_id = cursor.lastrowid
    await db.commit()
    if new_id is None:
        # SQLite always populates lastrowid for an AUTOINCREMENT INSERT;
        # this path exists only to satisfy the type checker.
        raise RuntimeError("benchmark_runs INSERT returned no lastrowid")

    await prune_history(db)
    logger.info(
        "Benchmark run persisted: id=%d encoders=%d %dx%d@%sfps",
        new_id,
        len(results),
        width,
        height,
        fps,
    )
    return int(new_id)


async def list_benchmark_runs(
    db: aiosqlite.Connection,
    *,
    limit: int = 20,
) -> list[dict[str, Any]]:
    """List recent run summaries (no per-encoder results) for the sidebar.

    Returns dicts shaped for the desktop's ``BenchmarkHistoryEntry`` entity.
    Newest first; soft-capped at ``limit`` (which the router clamps).

    ``resolution_count`` is derived per row by parsing ``results_json`` and
    counting distinct ``(width, height)`` tuples.  Old rows written before
    matrix mode shipped (no per-row width/height) collapse to 1.  At a
    50-row cap and ~5 KB per JSON blob, the per-listing cost is sub-ms;
    not worth a denormalized column.
    """
    async with db.execute(
        """
        SELECT id, started_at, finished_at, duration_sec,
               fps, width, height, verify_caps, encoder_count, results_json
          FROM benchmark_runs
         ORDER BY started_at DESC
         LIMIT ?
        """,
        (limit,),
    ) as cur:
        rows = await cur.fetchall()
    return [
        {
            "id": row["id"],
            "started_at": row["started_at"],
            "finished_at": row["finished_at"],
            "duration_sec": row["duration_sec"],
            "fps": row["fps"],
            "width": row["width"],
            "height": row["height"],
            "verify_caps": bool(row["verify_caps"]),
            "encoder_count": row["encoder_count"],
            "resolution_count": _count_resolutions(
                row["results_json"], row["width"], row["height"]
            ),
        }
        for row in rows
    ]


def _count_resolutions(
    results_json: str, fallback_width: int, fallback_height: int
) -> int:
    """Count distinct ``(width, height)`` tuples in a results blob.

    Pre-matrix rows (no per-row width/height) fall back to the run's
    primary dimensions and always return 1.  Malformed JSON returns 1
    rather than raising — the sidebar should never blow up because of
    a corrupt history row.
    """
    try:
        parsed = json.loads(results_json)
    except json.JSONDecodeError:
        return 1
    if not isinstance(parsed, list):
        return 1
    seen: set[tuple[int, int]] = set()
    for r in parsed:
        if not isinstance(r, dict):
            continue
        w = r.get("width", fallback_width)
        h = r.get("height", fallback_height)
        if isinstance(w, int) and isinstance(h, int):
            seen.add((w, h))
    return len(seen) or 1


def _distinct_resolutions(
    results_json: str, fallback_width: int, fallback_height: int
) -> list[tuple[int, int]]:
    """Walk ``results_json`` in order and collect distinct ``(w, h)`` tuples.

    Used by :func:`get_benchmark_run` to populate the response's
    ``resolutions`` echo.  Preserves first-occurrence order so the
    desktop gets the same tier sequence the operator selected
    originally.  Old rows fall back to a single-element list of the
    run's primary dimensions.
    """
    try:
        parsed = json.loads(results_json)
    except json.JSONDecodeError:
        return [(fallback_width, fallback_height)]
    if not isinstance(parsed, list):
        return [(fallback_width, fallback_height)]
    seen: set[tuple[int, int]] = set()
    out: list[tuple[int, int]] = []
    for r in parsed:
        if not isinstance(r, dict):
            continue
        w = r.get("width", fallback_width)
        h = r.get("height", fallback_height)
        if isinstance(w, int) and isinstance(h, int) and (w, h) not in seen:
            seen.add((w, h))
            out.append((w, h))
    if not out:
        out.append((fallback_width, fallback_height))
    return out


async def get_benchmark_run(
    db: aiosqlite.Connection, run_id: int
) -> dict[str, Any] | None:
    """Fetch a single full run by id, or None if it doesn't exist.

    The returned dict is shaped to match the live ``BenchmarkResponse``
    payload so the desktop can hand it to the same render path it uses
    for fresh runs.
    """
    async with db.execute(
        """
        SELECT id, started_at, finished_at, duration_sec,
               fps, width, height, verify_caps, encoder_count, results_json
          FROM benchmark_runs
         WHERE id = ?
        """,
        (run_id,),
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        return None
    try:
        results = json.loads(row["results_json"])
    except json.JSONDecodeError:
        logger.warning(
            "benchmark_runs id=%d has malformed results_json — returning empty",
            run_id,
        )
        results = []
    # Backfill per-row width/height for old rows written before matrix mode
    # shipped.  Their results blob doesn't carry width/height per encoder,
    # so we synthesize them from the run's primary dimensions.  New rows
    # already have these populated and pass through unchanged.
    primary_w = row["width"]
    primary_h = row["height"]
    if isinstance(results, list):
        for r in results:
            if isinstance(r, dict):
                r.setdefault("width", primary_w)
                r.setdefault("height", primary_h)
    return {
        "id": row["id"],
        "started_at": row["started_at"],
        "finished_at": row["finished_at"],
        "duration_sec": row["duration_sec"],
        "fps": row["fps"],
        "width": row["width"],
        "height": row["height"],
        "verify_caps": bool(row["verify_caps"]),
        "encoder_count": row["encoder_count"],
        "resolutions": _distinct_resolutions(row["results_json"], primary_w, primary_h),
        "results": results,
    }


async def delete_benchmark_run(db: aiosqlite.Connection, run_id: int) -> bool:
    """Delete one run.  Returns True iff a row actually went away."""
    cursor = await db.execute(
        "DELETE FROM benchmark_runs WHERE id = ?",
        (run_id,),
    )
    await db.commit()
    return (cursor.rowcount or 0) > 0


async def prune_history(db: aiosqlite.Connection, *, keep: int = _HISTORY_LIMIT) -> int:
    """Delete all but the ``keep`` most recent runs.  Returns count pruned.

    Called automatically after :func:`save_benchmark_run` so the table
    stays bounded without a separate background task.  Operators clearing
    history manually can re-invoke with ``keep=0`` to wipe everything.
    """
    cursor = await db.execute(
        """
        DELETE FROM benchmark_runs
         WHERE id NOT IN (
            SELECT id FROM benchmark_runs
             ORDER BY started_at DESC
             LIMIT ?
         )
        """,
        (keep,),
    )
    await db.commit()
    pruned = cursor.rowcount or 0
    if pruned > 0:
        logger.info("Pruned %d old benchmark_runs (keep=%d)", pruned, keep)
    return pruned
