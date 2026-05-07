-- Migration 024: Benchmark run history.
--
-- Persists encoder benchmark runs so the desktop's Benchmark tab can show
-- a historical sidebar — the operator can compare today's NVENC throughput
-- to last week's after a driver update, or revisit the result that justified
-- a particular encoder-chain choice.
--
-- Per-encoder result rows live inside a JSON blob (results_json) rather than
-- their own table because we always fetch full runs together (the sidebar
-- shows the same data the live results pane does), never per-encoder slices.
-- A relational split would add a join + an order-preservation hassle for no
-- query benefit at this scale.
--
-- ``encoder_count`` is denormalized for the list-summary endpoint so we can
-- render "8 encoders" in the sidebar without parsing the JSON body for
-- every entry.
--
-- The history is capped to the most recent ~50 entries by the service layer
-- (``benchmark_history_service.prune_history``) — runs are cheap to recreate
-- and the operator only ever cares about recent comparisons.

CREATE TABLE IF NOT EXISTS benchmark_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at TEXT NOT NULL,
    finished_at TEXT NOT NULL,
    duration_sec INTEGER NOT NULL,
    fps INTEGER NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    verify_caps INTEGER NOT NULL DEFAULT 0,
    encoder_count INTEGER NOT NULL,
    results_json TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_benchmark_runs_started_at
    ON benchmark_runs(started_at DESC);
