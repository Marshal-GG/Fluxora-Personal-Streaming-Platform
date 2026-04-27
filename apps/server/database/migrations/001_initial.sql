-- Libraries
CREATE TABLE IF NOT EXISTS libraries (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    type         TEXT NOT NULL CHECK(type IN ('movies','tv','music','files')),
    root_paths   TEXT NOT NULL,  -- JSON array of directory paths
    last_scanned TIMESTAMP,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Media files
CREATE TABLE IF NOT EXISTS media_files (
    id           TEXT PRIMARY KEY,
    path         TEXT NOT NULL UNIQUE,
    name         TEXT NOT NULL,
    extension    TEXT NOT NULL,
    size_bytes   INTEGER NOT NULL,
    duration_sec REAL,
    library_id   TEXT REFERENCES libraries(id) ON DELETE SET NULL,
    tmdb_id      INTEGER,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_media_files_library_id ON media_files(library_id);
CREATE INDEX IF NOT EXISTS idx_media_files_tmdb_id    ON media_files(tmdb_id);

-- Clients (auth_token stores HMAC-SHA256 hash — never the raw token)
CREATE TABLE IF NOT EXISTS clients (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    platform    TEXT NOT NULL CHECK(platform IN ('android','ios','windows','macos','linux')),
    last_seen   TIMESTAMP NOT NULL,
    is_trusted  BOOLEAN NOT NULL DEFAULT 0,
    auth_token  TEXT NOT NULL
);

-- Settings singleton (only one row, id must be 1)
CREATE TABLE IF NOT EXISTS user_settings (
    id                     INTEGER PRIMARY KEY CHECK(id = 1),
    server_name            TEXT    NOT NULL DEFAULT 'Fluxora Server',
    transcoding_enabled    BOOLEAN NOT NULL DEFAULT 1,
    max_concurrent_streams INTEGER NOT NULL DEFAULT 3,
    subscription_tier      TEXT    NOT NULL DEFAULT 'free'
                           CHECK(subscription_tier IN ('free','plus','pro','ultimate')),
    tmdb_api_key           TEXT
);

INSERT OR IGNORE INTO user_settings (id) VALUES (1);
