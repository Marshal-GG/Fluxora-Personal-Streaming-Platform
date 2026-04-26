# Database Schema

> **Category:** Data  
> **Status:** Active — Sourced from Planning Session (2026-04-27)

---

## Database Type

**SQLite** — Local-first, embedded, no external server required.  
WAL (Write-Ahead Logging) mode enabled for concurrent reads.

**File location:** `~/.fluxora/fluxora.db` (server-side)

---

## Schema Definitions

```sql
-- Libraries table
CREATE TABLE libraries (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    type        TEXT NOT NULL CHECK(type IN ('movies','tv','music','files')),
    root_paths  TEXT NOT NULL,  -- JSON array of directory paths
    last_scanned TIMESTAMP,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Media files table
CREATE TABLE media_files (
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

-- Clients table
CREATE TABLE clients (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    platform    TEXT NOT NULL CHECK(platform IN ('android','ios','windows','macos','linux')),
    last_seen   TIMESTAMP NOT NULL,
    is_trusted  BOOLEAN NOT NULL DEFAULT 0,
    auth_token  TEXT NOT NULL
);

-- Stream sessions table
CREATE TABLE stream_sessions (
    id                 TEXT PRIMARY KEY,
    file_id            TEXT NOT NULL REFERENCES media_files(id),
    client_id          TEXT NOT NULL REFERENCES clients(id),
    started_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at           TIMESTAMP,
    connection_type    TEXT NOT NULL CHECK(connection_type IN ('lan','webrtc_p2p','turn_relay')),
    bytes_transferred  INTEGER DEFAULT 0,
    progress_sec       REAL DEFAULT 0
);

-- Settings singleton
CREATE TABLE user_settings (
    id                       INTEGER PRIMARY KEY CHECK(id = 1),
    server_name              TEXT NOT NULL DEFAULT 'Fluxora Server',
    transcoding_enabled      BOOLEAN NOT NULL DEFAULT 1,
    max_concurrent_streams   INTEGER NOT NULL DEFAULT 3,
    subscription_tier        TEXT NOT NULL DEFAULT 'free'
                             CHECK(subscription_tier IN ('free','plus','pro','ultimate')),
    tmdb_api_key             TEXT
);
```

---

## Indexes

| Table | Column(s) | Type | Purpose |
|-------|-----------|------|---------|
| `media_files` | `library_id` | B-Tree | Fast library → files lookup |
| `media_files` | `path` | Unique | Prevent duplicate indexing |
| `media_files` | `tmdb_id` | B-Tree | Metadata join |
| `stream_sessions` | `client_id` | B-Tree | Client history lookup |
| `stream_sessions` | `file_id` | B-Tree | File stream history |
| `stream_sessions` | `ended_at` | B-Tree | Active session queries (WHERE ended_at IS NULL) |

---

## Migration Strategy

- Phase 1-3: Manual SQL migration files in `server/migrations/`
- Naming: `001_initial_schema.sql`, `002_add_settings.sql`, etc.
- Applied on server startup via lightweight migration runner
- Future: evaluate Alembic if complexity increases
