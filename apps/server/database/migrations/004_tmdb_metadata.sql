-- TMDB metadata columns (additive — safe to run on existing databases)
-- NOTE: tmdb_id was already added in migration 001 (initial schema).
ALTER TABLE media_files ADD COLUMN title       TEXT;
ALTER TABLE media_files ADD COLUMN overview    TEXT;
ALTER TABLE media_files ADD COLUMN poster_url  TEXT;
