-- Plan 27 M1 — per-file thumbnail extraction tracking.
--
-- Status-tracked queue consumed by services/thumbnail_worker.py.  Scan
-- path appends rows with `INSERT OR IGNORE`; the background worker
-- claims pending rows via `UPDATE ... RETURNING` (atomic across slots)
-- and dispatches to services/thumbnail_service.py for the actual
-- FFmpeg / PyMuPDF call.  Generated JPEGs are written to
-- `<data_dir>/thumbnails/<file_id>.jpg`.
--
-- Status state machine:
--   pending     -> generating -> ready
--                              \-> failed   (transient, retried up to max_attempts)
--                              \-> skipped  (permanent — no thumb possible)
--
-- `priority` column: 0 = default FIFO; 10 = boosted (operator opened
-- this file's library; routers/files.py stamps the boost so the just-
-- opened library jumps to the front of the queue).  No decay — stays at
-- 10 until the worker processes the row.
--
-- Separate table (not columns on media_files) so:
--   • hot media_files schema stays lean,
--   • worker UPDATEs don't bump media_files.updated_at (which would
--     confuse TMDB enrichment ordering),
--   • ON DELETE CASCADE cleans rows when files are removed from the
--     library; orphan JPEGs on disk are swept by a separate ticker.

CREATE TABLE media_thumbnails (
    file_id        TEXT PRIMARY KEY REFERENCES media_files(id) ON DELETE CASCADE,
    status         TEXT NOT NULL CHECK (status IN ('pending', 'generating', 'ready', 'failed', 'skipped')),
    priority       INTEGER NOT NULL DEFAULT 0,
    generated_at   TIMESTAMP NULL,
    attempts       INTEGER NOT NULL DEFAULT 0,
    error_message  TEXT NULL,
    created_at     TIMESTAMP NOT NULL,
    updated_at     TIMESTAMP NOT NULL
);

-- Partial index on the worker's hot query: `WHERE status='pending'
-- ORDER BY priority DESC, created_at ASC LIMIT 1`.  Keeps the claim
-- O(log K) where K = pending count, not O(log N) where N = total files.
CREATE INDEX idx_thumbs_pending
    ON media_thumbnails(priority DESC, created_at ASC)
    WHERE status = 'pending';

-- Backfill: every existing media_files row gets a pending thumb so the
-- worker chews through the existing library after deployment.  Bounded
-- by the table size (single INSERT ... SELECT, < 1 s for 10 K rows in
-- SQLite per local benchmark).  No-op for empty installs.
INSERT INTO media_thumbnails (file_id, status, priority, created_at, updated_at)
SELECT id, 'pending', 0, datetime('now'), datetime('now')
  FROM media_files
 WHERE id NOT IN (SELECT file_id FROM media_thumbnails);
