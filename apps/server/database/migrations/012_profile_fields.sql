-- Operator profile metadata, surfaced by the desktop redesign's Profile screen.
-- Lives on the user_settings singleton (id=1). All five columns are nullable —
-- a fresh install has no profile until the operator fills it in.
--
-- `last_login_at` is unused in v1 (Fluxora's single-owner localhost model has
-- no login event), reserved for v2 when the desktop app starts touching it
-- on launch.

ALTER TABLE user_settings ADD COLUMN display_name TEXT;
ALTER TABLE user_settings ADD COLUMN email TEXT;
ALTER TABLE user_settings ADD COLUMN avatar_path TEXT;
ALTER TABLE user_settings ADD COLUMN profile_created_at TEXT;
ALTER TABLE user_settings ADD COLUMN last_login_at TEXT;

UPDATE user_settings
   SET profile_created_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
 WHERE id = 1
   AND profile_created_at IS NULL;
