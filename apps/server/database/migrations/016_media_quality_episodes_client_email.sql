-- Phase A backfill plan §9.1 — three independent additions, one schema bump.
--
--  1. FFprobe-derived video metadata on media_files (quality badges + the
--     direct-play allowlist that ships in Phase G).
--  2. TV episode aggregation columns on media_files. Pre-folded so Phase D
--     does not need a second migration: episodes stay regular media_files
--     rows — a "show" is just `WHERE tmdb_show_id = ?`.
--  3. Per-client profile fields (`email`, `paired_at`) for the new
--     `GET /clients/me` endpoint and the desktop Clients screen's
--     "Paired Mar 15" label.
--
-- Existing rows are left null on the FFprobe + episode columns; the next
-- library scan back-fills FFprobe data, and the next TMDB scan back-fills
-- the show / season / episode triple. `paired_at` is back-filled to "now"
-- for already-paired clients so the desktop column never shows blank.

-- 1. FFprobe fields ----------------------------------------------------------
ALTER TABLE media_files ADD COLUMN width        INTEGER;
ALTER TABLE media_files ADD COLUMN height       INTEGER;
ALTER TABLE media_files ADD COLUMN codec_name   TEXT;
ALTER TABLE media_files ADD COLUMN hdr_format   TEXT;

-- 2. TV episode aggregation --------------------------------------------------
ALTER TABLE media_files ADD COLUMN tmdb_show_id   INTEGER;
ALTER TABLE media_files ADD COLUMN season_number  INTEGER;
ALTER TABLE media_files ADD COLUMN episode_number INTEGER;

CREATE INDEX IF NOT EXISTS idx_media_files_tmdb_show_id
    ON media_files(tmdb_show_id);

-- 3. Per-client profile fields ----------------------------------------------
ALTER TABLE clients ADD COLUMN email     TEXT;
ALTER TABLE clients ADD COLUMN paired_at TEXT;

UPDATE clients
   SET paired_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
 WHERE paired_at IS NULL;
