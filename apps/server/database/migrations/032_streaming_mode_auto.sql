-- Plan 20 — extend `streaming_mode` to allow 'auto'.
--
-- Plan 19 §M7 introduced two values ('client-decode', 'server-transcode')
-- via migration 028.  Plan 20 adds 'auto' as an opt-in third mode that
-- starts in stream-copy and transparently falls back to transcode on a
-- client-reported decode error.  'client-decode' remains the default
-- (matches the Recommended badge in the encoder-settings UI).
--
-- SQLite doesn't support `ALTER TABLE … DROP CONSTRAINT`, so we use
-- the column-copy dance: add a widened column, copy values forward,
-- drop the old column, rename the new one into place.

ALTER TABLE user_settings ADD COLUMN streaming_mode_new TEXT NOT NULL
    DEFAULT 'client-decode'
    CHECK(streaming_mode_new IN ('auto', 'client-decode', 'server-transcode'));
UPDATE user_settings SET streaming_mode_new = streaming_mode;
ALTER TABLE user_settings DROP COLUMN streaming_mode;
ALTER TABLE user_settings RENAME COLUMN streaming_mode_new TO streaming_mode;
