-- Extended user_settings columns for the 6-tab Settings screen of the desktop redesign
-- (General / Network / Streaming / Security / Advanced / About).
-- theme_accent is nullable with no default — forward-compat placeholder only
-- (brand locked to #A855F7 at the design layer, per Decision #4).

-- General tab
ALTER TABLE user_settings ADD COLUMN language TEXT NOT NULL DEFAULT 'en';
ALTER TABLE user_settings ADD COLUMN auto_start_on_boot BOOLEAN NOT NULL DEFAULT 0;
ALTER TABLE user_settings ADD COLUMN auto_restart_on_crash BOOLEAN NOT NULL DEFAULT 1;
ALTER TABLE user_settings ADD COLUMN minimize_to_system_tray BOOLEAN NOT NULL DEFAULT 1;
ALTER TABLE user_settings ADD COLUMN theme_accent TEXT;
ALTER TABLE user_settings ADD COLUMN default_library_view TEXT NOT NULL DEFAULT 'grid';
ALTER TABLE user_settings ADD COLUMN scan_libraries_on_startup BOOLEAN NOT NULL DEFAULT 1;
ALTER TABLE user_settings ADD COLUMN generate_thumbnails BOOLEAN NOT NULL DEFAULT 1;

-- Network tab
ALTER TABLE user_settings ADD COLUMN preferred_mode TEXT NOT NULL DEFAULT 'auto';
ALTER TABLE user_settings ADD COLUMN enable_mdns BOOLEAN NOT NULL DEFAULT 1;
ALTER TABLE user_settings ADD COLUMN enable_webrtc BOOLEAN NOT NULL DEFAULT 1;
ALTER TABLE user_settings ADD COLUMN relay_server_url TEXT;

-- Streaming tab
ALTER TABLE user_settings ADD COLUMN default_quality TEXT NOT NULL DEFAULT 'auto';
ALTER TABLE user_settings ADD COLUMN ai_segment_duration_seconds INTEGER NOT NULL DEFAULT 4;

-- Security tab
ALTER TABLE user_settings ADD COLUMN enable_pairing_required BOOLEAN NOT NULL DEFAULT 1;
ALTER TABLE user_settings ADD COLUMN session_timeout_minutes INTEGER NOT NULL DEFAULT 60;

-- Advanced tab
ALTER TABLE user_settings ADD COLUMN enable_log_export BOOLEAN NOT NULL DEFAULT 1;
ALTER TABLE user_settings ADD COLUMN custom_server_url TEXT;
