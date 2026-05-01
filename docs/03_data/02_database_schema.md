# Database Schema

> **Category:** Data  
> **Status:** Active - Updated 2026-05-02 (migrations 004-014; TMDB, resume, license_key, tier alignment, Polar orders + customer email, transcoding settings, Groups + stream-gate, Profile fields, Notifications, ActivityEvents)

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
    id                TEXT PRIMARY KEY,
    path              TEXT NOT NULL UNIQUE,
    name              TEXT NOT NULL,
    extension         TEXT NOT NULL,
    size_bytes        INTEGER NOT NULL,
    duration_sec      REAL,
    library_id        TEXT REFERENCES libraries(id) ON DELETE SET NULL,
    tmdb_id           INTEGER,
    title             TEXT,              -- migration 004: TMDB title
    overview          TEXT,              -- migration 004: TMDB overview/synopsis
    poster_url        TEXT,              -- migration 004: TMDB poster URL
    last_progress_sec REAL NOT NULL DEFAULT 0.0,  -- migration 005: resume position
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Clients table (auth_token = HMAC-SHA256 hash of raw token — never stored in plain)
CREATE TABLE clients (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    platform    TEXT NOT NULL CHECK(platform IN ('android','ios','windows','macos','linux')),
    last_seen   TIMESTAMP NOT NULL,
    is_trusted  BOOLEAN NOT NULL DEFAULT 0,
    auth_token  TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending'  -- added by migration 003
);
-- status values: 'pending' | 'approved' | 'rejected'

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
    max_concurrent_streams   INTEGER NOT NULL DEFAULT 1,  -- migration 007: corrected to match free-tier limit
    subscription_tier        TEXT NOT NULL DEFAULT 'free'
                             CHECK(subscription_tier IN ('free','plus','pro','ultimate')),
    tmdb_api_key             TEXT,
    license_key              TEXT,      -- migration 006: user's paid-plan license key
    transcoding_encoder      TEXT NOT NULL DEFAULT 'libx264',   -- migration 010
    transcoding_preset       TEXT NOT NULL DEFAULT 'veryfast',  -- migration 010
    transcoding_crf          INTEGER NOT NULL DEFAULT 23,       -- migration 010
    -- migration 012: operator profile metadata
    display_name             TEXT,      -- operator display name
    email                    TEXT,      -- operator email address
    avatar_path              TEXT,      -- absolute path to local avatar image
    profile_created_at       TEXT,      -- backfilled to migration-apply time for the existing row
    last_login_at            TEXT       -- reserved for v2; always NULL in v1
);

-- Polar paid-order idempotency table
CREATE TABLE polar_orders (
    order_id       TEXT PRIMARY KEY,
    customer_email TEXT,             -- migration 009: for owner lookup
    tier           TEXT NOT NULL,
    license_key    TEXT NOT NULL,
    processed_at   TEXT NOT NULL
);

-- Client groups (migration 011)
-- A client can belong to multiple groups; restrictions are stream-gate enforced.
CREATE TABLE IF NOT EXISTS groups (
    id          TEXT PRIMARY KEY,            -- UUID
    name        TEXT NOT NULL,
    description TEXT,
    status      TEXT NOT NULL DEFAULT 'active'
                CHECK(status IN ('active','inactive')),
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS group_members (
    group_id  TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    added_at  TEXT NOT NULL,
    PRIMARY KEY (group_id, client_id)
);

CREATE TABLE IF NOT EXISTS group_restrictions (
    group_id           TEXT PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
    allowed_libraries  TEXT,        -- JSON array of library ids; NULL = all
    bandwidth_cap_mbps INTEGER,     -- NULL = unlimited
    time_window        TEXT,        -- JSON {start_h, end_h, days:[0..6]}; NULL = always
    max_rating         TEXT         -- e.g. "PG-13"; NULL = none
);

-- Notifications table (migration 013)
-- In-app notifications surfaced by the desktop sidebar bell.
-- type CHECK: 'info'|'warning'|'error'|'success'
-- category CHECK: 'system'|'client'|'license'|'transcode'|'storage'
CREATE TABLE IF NOT EXISTS notifications (
    id            TEXT PRIMARY KEY,    -- UUID
    type          TEXT NOT NULL CHECK(type IN ('info','warning','error','success')),
    category      TEXT NOT NULL CHECK(category IN ('system','client','license','transcode','storage')),
    title         TEXT NOT NULL,
    message       TEXT NOT NULL,
    related_kind  TEXT,                -- e.g. 'client', 'session' (nullable)
    related_id    TEXT,                -- UUID of related entity (nullable)
    created_at    TEXT NOT NULL,       -- UTC ISO-8601
    read_at       TEXT,                -- NULL = unread
    dismissed_at  TEXT                 -- NULL = visible
);

-- Activity events table (migration 014)
-- Append-only audit trail fed by producer services (auth, stream, library).
-- Desktop Activity screen + Dashboard "Recent Activity" widget polls this.
-- producer errors are swallowed — a missing row must never break the flow.
CREATE TABLE IF NOT EXISTS activity_events (
    id          TEXT PRIMARY KEY,            -- UUID
    type        TEXT NOT NULL,               -- e.g. stream.start, client.pair, file.upload
    actor_kind  TEXT,                        -- 'client' | 'system' | 'operator' | NULL
    actor_id    TEXT,                        -- e.g. client_id; NULL for system/operator events
    target_kind TEXT,                        -- 'session' | 'client' | 'file' | 'library' | NULL
    target_id   TEXT,                        -- entity id of the target
    summary     TEXT NOT NULL,               -- short human-readable line for the UI
    payload     TEXT,                        -- optional JSON for detail
    created_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_activity_created
    ON activity_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_activity_type_created
    ON activity_events(type, created_at DESC);
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
| `group_members` | `client_id` | B-Tree | Fast lookup of all groups a client belongs to (stream-gate query) |
| `notifications` | `(read_at, dismissed_at, created_at DESC)` | B-Tree (`idx_notifications_unread`) | Fast unread / visible notification queries |
| `activity_events` | `created_at DESC` | B-Tree (`idx_activity_created`) | Default most-recent-first list query |
| `activity_events` | `(type, created_at DESC)` | B-Tree (`idx_activity_type_created`) | Type-prefix filter + ordering |

---

## Migration Strategy

- Phase 1-3: Manual SQL migration files in `apps/server/database/migrations/`
- Naming: `NNN_description.sql` — zero-padded, applied in alphabetical order
- Applied on server startup via `database/db.py` migration runner (`_migrations` tracking table)
- Future: evaluate Alembic if complexity increases

### Applied Migrations

| File | What it does |
|------|-------------|
| `001_initial.sql` | Creates `libraries`, `media_files`, `clients`, `user_settings`; seeds settings row |
| `002_sessions.sql` | Creates `stream_sessions` with indexes |
| `003_client_status.sql` | Adds `status` column to `clients` (`pending`/`approved`/`rejected`) |
| `004_tmdb_metadata.sql` | Adds `title`, `overview`, `poster_url` to `media_files` |
| `005_resume_progress.sql` | Adds `last_progress_sec REAL NOT NULL DEFAULT 0.0` to `media_files` |
| `006_settings_license.sql` | Adds `license_key TEXT` to `user_settings` |
| `007_align_tier_limits.sql` | Corrects `max_concurrent_streams` to match actual tier limits (`free=1, plus=3, pro=10, ultimate=9999`) on the existing row |
| `008_polar_orders.sql` | Creates `polar_orders` to make Polar paid-order license issuance idempotent without storing customer email |
| `009_order_customer_email.sql` | Adds `customer_email` to `polar_orders` table for manual owner lookup. |
| `010_transcoding_settings.sql` | Adds `transcoding_encoder`, `transcoding_preset`, `transcoding_crf` to `user_settings`; defaults: `libx264`, `veryfast`, `23`. |
| `011_groups.sql` | Creates `groups`, `group_members`, `group_restrictions`; adds `idx_group_members_client` index. Enables client-group stream-gate enforcement. |
| `012_profile_fields.sql` | Adds 5 nullable columns to `user_settings`: `display_name TEXT`, `email TEXT`, `avatar_path TEXT`, `profile_created_at TEXT` (backfilled to migration-apply time for the existing row), `last_login_at TEXT` (reserved for v2; null in v1). |
| `013_notifications.sql` | Creates `notifications` table (id UUID PK, type/category with CHECK constraints, title, message, related_kind?, related_id?, created_at, read_at?, dismissed_at?); adds `idx_notifications_unread` on `(read_at, dismissed_at, created_at DESC)`. |
| `014_activity_events.sql` | Creates `activity_events` table (id UUID PK, type, actor_kind?, actor_id?, target_kind?, target_id?, summary, payload JSON?, created_at); adds `idx_activity_created` on `(created_at DESC)` and `idx_activity_type_created` on `(type, created_at DESC)`. |
