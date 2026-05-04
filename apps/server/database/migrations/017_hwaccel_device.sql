-- Migration 017: Add optional hardware-accelerator device path to user_settings.
--
-- Relevant only for VAAPI on Linux. NULL means "auto" — the server uses
-- /dev/dri/renderD128 as the default when this column is NULL.
-- Windows and macOS users never need to set this; it is silently ignored
-- for non-VAAPI encoders.
--
-- Users with multiple AMD / Intel GPUs on a single Linux box can point this
-- at the correct /dev/dri/renderD129 (or whichever node their GPU is on).

ALTER TABLE user_settings
    ADD COLUMN transcoding_hwaccel_device TEXT DEFAULT NULL;
