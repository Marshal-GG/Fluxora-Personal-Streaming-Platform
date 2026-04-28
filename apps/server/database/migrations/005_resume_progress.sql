-- Resume-playback progress column on media_files
-- Stores the last known playback position in seconds so clients can resume.
ALTER TABLE media_files ADD COLUMN last_progress_sec REAL NOT NULL DEFAULT 0.0;
