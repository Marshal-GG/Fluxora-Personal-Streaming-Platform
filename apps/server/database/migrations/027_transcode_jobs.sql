-- Library transcode plan (docs/10_planning/18_library_transcode_plan.md).
-- User-driven, opt-in pre-transcode of AV1 / VP9 sources to H.264
-- sidecars stored next to the original.  Once a sidecar exists,
-- ffmpeg_service.start_stream uses it as the playback path so the
-- session falls into the existing direct_remux_h264 branch and
-- stream-copies instead of doing live software-decode -> NVENC.

-- Sidecar columns on media_files.  All NULL until a transcode job
-- finishes successfully.
ALTER TABLE media_files ADD COLUMN transcoded_path TEXT;
ALTER TABLE media_files ADD COLUMN transcoded_size_bytes INTEGER;
ALTER TABLE media_files ADD COLUMN transcoded_at INTEGER;

-- Job queue.  Single-worker FIFO; rows live for the lifetime of the
-- server (status carries the terminal outcome so the desktop History
-- tab can show what happened).  ON DELETE CASCADE on file_id keeps
-- the queue clean if a library is rescanned and the row disappears.
CREATE TABLE IF NOT EXISTS transcode_jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id TEXT NOT NULL REFERENCES media_files(id) ON DELETE CASCADE,
    target_codec TEXT NOT NULL DEFAULT 'h264',
    encoder TEXT NOT NULL,
    quality_preset TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('queued', 'running', 'done', 'failed', 'cancelled')),
    progress_pct REAL NOT NULL DEFAULT 0.0,
    eta_sec INTEGER,
    error TEXT,
    output_path TEXT,
    created_at INTEGER NOT NULL,
    started_at INTEGER,
    finished_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_transcode_jobs_status ON transcode_jobs(status);
CREATE INDEX IF NOT EXISTS idx_transcode_jobs_file ON transcode_jobs(file_id);
