-- License key column for subscription validation (validation integration TBD)
ALTER TABLE user_settings ADD COLUMN license_key TEXT;
