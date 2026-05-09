# Database Schema

> **Category:** Data  
> **Status:** Active - Updated 2026-05-09 (migrations 001-026; TMDB, resume, license_key, tier alignment, Polar orders + customer email, transcoding settings, Groups + stream-gate, Profile fields, Notifications, ActivityEvents, extended settings §7.10, FFprobe + episode aggregation + per-client email/paired_at, hwaccel_device (nullable), encoder sanitiser, license-key sanitiser, encoder priority chain (Slice C), per-session encoder_used, corrupt-path data cleanup, `clients.last_ip` + per-request heartbeat, `benchmark_runs` history table, Groups v2 content-spaces redesign (Public group + PIN gate + grant/attempt ledgers + per-member time-window override + icon/color/concurrent-stream cap), Groups v2 §M8 hybrid PIN model (per-client enrollment ledger). Drift fixes 2026-05-09: stream-session NOT NULL on `bytes_transferred`/`progress_sec`; `language` NOT NULL; `transcoding_hwaccel_device` re-stated as nullable; explicit index names in the index table.)

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
    width             INTEGER,           -- migration 016: ffprobe video width
    height            INTEGER,           -- migration 016: ffprobe video height
    codec_name        TEXT,              -- migration 016: ffprobe video codec
    hdr_format        TEXT,              -- migration 016: 'HDR10' | 'HLG' | 'DolbyVision' | NULL (SDR)
    tmdb_show_id      INTEGER,           -- migration 016: parent show TMDB id (TV episodes only)
    season_number     INTEGER,           -- migration 016: TV episodes only
    episode_number    INTEGER,           -- migration 016: TV episodes only
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Clients table (auth_token = HMAC-SHA256 hash of raw token — never stored in plain)
CREATE TABLE clients (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,         -- doubles as display_name (mobile pairing flow)
    platform    TEXT NOT NULL CHECK(platform IN ('android','ios','windows','macos','linux')),
    last_seen   TIMESTAMP NOT NULL,    -- refreshed on every authenticated request via validate_token (migration 023 changed semantics from "frozen at pair/approval" to "live")
    is_trusted  BOOLEAN NOT NULL DEFAULT 0,
    auth_token  TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending', -- added by migration 003
    email       TEXT,                  -- migration 016: optional contact captured at pair time
    paired_at   TEXT,                  -- migration 016: ISO timestamp of first approval
    last_ip     TEXT                   -- migration 023: socket-level IP at pair + every authenticated request; NULL until first authenticated traffic
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
    bytes_transferred  INTEGER NOT NULL DEFAULT 0,
    progress_sec       REAL    NOT NULL DEFAULT 0,
    encoder_used       TEXT     -- migration 021: encoder picked by session_router (NULL on stream-copy)
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
    last_login_at            TEXT,      -- reserved for v2; always NULL in v1
    -- migration 015: extended settings (18 new columns)
    -- General
    language                 TEXT NOT NULL DEFAULT 'en',
    auto_start_on_boot       BOOLEAN NOT NULL DEFAULT 0,
    auto_restart_on_crash    BOOLEAN NOT NULL DEFAULT 1,
    minimize_to_system_tray  BOOLEAN NOT NULL DEFAULT 1,
    theme_accent             TEXT,      -- forward-compat; NULL in v1 (brand locked to violet)
    default_library_view     TEXT NOT NULL DEFAULT 'grid',  -- 'grid' | 'list'
    scan_libraries_on_startup BOOLEAN NOT NULL DEFAULT 1,
    generate_thumbnails      BOOLEAN NOT NULL DEFAULT 1,
    -- Network
    preferred_mode           TEXT NOT NULL DEFAULT 'auto',  -- 'auto' | 'lan' | 'webrtc'
    enable_mdns              BOOLEAN NOT NULL DEFAULT 1,
    enable_webrtc            BOOLEAN NOT NULL DEFAULT 1,
    relay_server_url         TEXT,      -- override TURN relay; NULL = use default
    -- Streaming
    default_quality          TEXT NOT NULL DEFAULT 'auto',  -- 'auto' | '4k' | '1080p' | '720p' | '480p'
    ai_segment_duration_seconds INTEGER NOT NULL DEFAULT 4,
    -- Security
    enable_pairing_required  BOOLEAN NOT NULL DEFAULT 1,
    session_timeout_minutes  INTEGER NOT NULL DEFAULT 60,   -- range 1–1440
    -- Advanced
    enable_log_export        BOOLEAN NOT NULL DEFAULT 1,
    custom_server_url        TEXT,      -- operator-specified public URL; NULL = use env var
    -- migration 017: VAAPI device path (nullable; NULL = auto, /dev/dri/renderD128 default)
    transcoding_hwaccel_device TEXT DEFAULT NULL,
    -- migration 020: encoder priority chain (Slice C of GPU UX plan)
    transcoding_chain          TEXT DEFAULT NULL  -- JSON-encoded list e.g. '["h264_nvenc","h264_qsv","libx264"]'; NULL = use default chain
);

-- Polar paid-order idempotency table
CREATE TABLE polar_orders (
    order_id       TEXT PRIMARY KEY,
    customer_email TEXT,             -- migration 009: for owner lookup
    tier           TEXT NOT NULL,
    license_key    TEXT NOT NULL,
    processed_at   TEXT NOT NULL
);

-- Client groups (migration 011, extended by 025 + 026)
-- A client can belong to multiple groups.  v2 (migration 025) flips the
-- `allowed_libraries` semantic from subtractive (v1: "ONLY these") to
-- additive (v2: "this group EXPOSES these").  Multi-group is UNION.
CREATE TABLE IF NOT EXISTS groups (
    id                       TEXT PRIMARY KEY,            -- UUID, or literal 'public' for the singleton Public row
    name                     TEXT NOT NULL,
    description              TEXT,
    status                   TEXT NOT NULL DEFAULT 'active'
                             CHECK(status IN ('active','inactive')),
    created_at               TEXT NOT NULL,
    updated_at               TEXT NOT NULL,
    -- migration 025 (v2 content-spaces redesign)
    is_public                INTEGER NOT NULL DEFAULT 0,  -- exactly one row may carry 1; UNIQUE partial idx_groups_public enforces
    icon                     TEXT,                        -- operator-set key ('home','kids','lock',...); v2 Tier-2 visual identity
    color                    TEXT,                        -- hex like '#A855F7'
    requires_pin             INTEGER NOT NULL DEFAULT 0,  -- gate is active when 1
    pin_hash                 TEXT,                        -- HMAC-SHA256(pin, settings.pin_hmac_key); shared mode only
    pin_mode                 TEXT NOT NULL DEFAULT 'session'
                             CHECK(pin_mode IN ('session','per-entry')),  -- grant TTL: session=12h, per-entry=5min
    max_concurrent_streams   INTEGER,                     -- per-group cap (Tier-2 enforcement); NULL = unlimited
    -- migration 026 (M8 — hybrid PIN model)
    pin_model                TEXT NOT NULL DEFAULT 'shared'
                             CHECK(pin_model IN ('shared','per-client'))  -- per-client → enrollments live in group_member_pins
);

-- Singleton-Public enforcement: exactly one row may carry is_public = 1.
CREATE UNIQUE INDEX IF NOT EXISTS idx_groups_public
    ON groups(is_public) WHERE is_public = 1;

CREATE TABLE IF NOT EXISTS group_members (
    group_id              TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    client_id             TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    added_at              TEXT NOT NULL,
    -- migration 025
    time_window_override  TEXT,        -- JSON {start_h, end_h, days[]}; NULL = inherit group's; per-member ("older kid stays up later")
    PRIMARY KEY (group_id, client_id)
);

CREATE TABLE IF NOT EXISTS group_restrictions (
    group_id           TEXT PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
    allowed_libraries  TEXT,        -- JSON array of library ids.  v2: this group EXPOSES these.  NULL = no libraries from this group.
    bandwidth_cap_mbps INTEGER,     -- advisory in v2; real enforcement deferred to v2 follow-up
    time_window        TEXT,        -- JSON {start_h, end_h, days:[0..6]}; NULL = always.  Member's time_window_override beats this.
    max_rating         TEXT         -- advisory in v2 until media_files.rating column lands
);

-- PIN grant ledger (migration 025).  A client unlocking a PIN-gated group
-- inserts a row; visibility resolution treats the group as unlocked while
-- a row with `expires_at > now` exists.  Pruned by housekeep_pin_state.
CREATE TABLE IF NOT EXISTS group_pin_grants (
    client_id   TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    group_id    TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    granted_at  TEXT NOT NULL,
    expires_at  TEXT NOT NULL,
    PRIMARY KEY (client_id, group_id)
);
CREATE INDEX IF NOT EXISTS idx_group_pin_grants_expiry
    ON group_pin_grants(expires_at);

-- PIN attempt ledger (migration 025) — brute-force protection.  5 fails
-- in 60 s per (client, group) → rate-limited (429 + retry-after).  Rows
-- older than 24 h pruned by housekeep_pin_state.
CREATE TABLE IF NOT EXISTS group_pin_attempts (
    client_id    TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    group_id     TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    attempted_at TEXT NOT NULL,
    success      INTEGER NOT NULL CHECK(success IN (0, 1))
);
CREATE INDEX IF NOT EXISTS idx_group_pin_attempts_lookup
    ON group_pin_attempts(client_id, group_id, attempted_at DESC);

-- Per-member PIN enrollment ledger (migration 026 — M8 hybrid PIN model).
-- One row per (group, member device) when the group is in
-- pin_model='per-client'.  Each member device chooses its own PIN on first
-- access; operator never sees the plaintext.  Recovery = DELETE the row,
-- which forces re-enrollment on next access.  Empty in shared-mode groups.
CREATE TABLE IF NOT EXISTS group_member_pins (
    group_id    TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    client_id   TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    pin_hash    TEXT NOT NULL,                     -- HMAC-SHA256(pin, settings.pin_hmac_key)
    enrolled_at TEXT NOT NULL,
    PRIMARY KEY (group_id, client_id)
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

### `benchmark_runs` (Migration 024)

```sql
-- One row per encoder-benchmark run.  Metadata columns describe the
-- workload + the run window; the per-encoder results live inside the
-- JSON blob (always fetched together with the parent — no relational
-- query benefit at this scale).
CREATE TABLE IF NOT EXISTS benchmark_runs (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at    TEXT NOT NULL,                       -- ISO-8601 UTC
    finished_at   TEXT NOT NULL,                       -- ISO-8601 UTC
    duration_sec  INTEGER NOT NULL,                    -- source clip length
    fps           INTEGER NOT NULL,                    -- source frame rate
    width         INTEGER NOT NULL,                    -- source width
    height        INTEGER NOT NULL,                    -- source height
    verify_caps   INTEGER NOT NULL DEFAULT 0,          -- bool 0/1
    encoder_count INTEGER NOT NULL,                    -- denormalized for list rendering
    results_json  TEXT NOT NULL                        -- JSON array of EncoderBenchmarkResult
);

CREATE INDEX IF NOT EXISTS idx_benchmark_runs_started_at
    ON benchmark_runs(started_at DESC);
```

---

### `transcode_jobs` (Migration 027)

```sql
-- One row per user-initiated pre-transcode job (plan 18).  The desktop
-- Transcode page enqueues here; a single FIFO worker in
-- `services/transcode_service.py` claims the oldest queued row,
-- transitions it to `running`, runs FFmpeg, and updates progress in
-- place via `-progress pipe:2` parsing.  Crash-recovery on app boot
-- sweeps any orphan `running` rows and marks them `failed`.
CREATE TABLE IF NOT EXISTS transcode_jobs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id         TEXT NOT NULL REFERENCES media_files(id) ON DELETE CASCADE,
    target_codec    TEXT NOT NULL DEFAULT 'h264',                 -- v1 only writes 'h264'; column is future-proofed
    encoder         TEXT NOT NULL,                                -- 'h264_nvenc' / 'libx264' / etc.
    quality_preset  TEXT NOT NULL,                                -- v1 only writes 'slow_cq19' (NVENC) / 'slow_crf19' (libx264)
    status          TEXT NOT NULL CHECK(status IN
                        ('queued','running','done','failed','cancelled')),
    progress_pct    REAL NOT NULL DEFAULT 0.0,                    -- 0.0–100.0
    eta_sec         INTEGER,                                      -- nullable; populated only while running
    error           TEXT,                                         -- last 240 chars of stderr on failure
    output_path     TEXT,                                         -- nullable until status='done'
    created_at      INTEGER NOT NULL,                             -- epoch seconds
    started_at      INTEGER,
    finished_at     INTEGER
);
```

Migration 027 also adds three sidecar columns to `media_files`:

```sql
ALTER TABLE media_files ADD COLUMN transcoded_path TEXT;            -- absolute path to '<basename>.h264.<ext>' sidecar
ALTER TABLE media_files ADD COLUMN transcoded_size_bytes INTEGER;
ALTER TABLE media_files ADD COLUMN transcoded_at INTEGER;           -- epoch seconds; lets future stale-detection compare to source mtime
```

When `media_files.transcoded_path` is non-NULL and the file exists on disk, `routers/stream.py::POST /stream/start` reads from that path instead of `media_files.path` — playback then takes the H.264 stream-copy fast path. If the sidecar row is set but the file is missing on disk (operator deleted it manually), playback falls back to the source and logs a warning (orphan-row case, deliberate; rescan would relink under §10 of plan 18 once §10 ships).

---

## Indexes

| Table | Column(s) | Type | Purpose |
|-------|-----------|------|---------|
| `media_files` | `library_id` | B-Tree (`idx_media_files_library_id`) | Fast library → files lookup |
| `media_files` | `path` | Implicit UNIQUE (column-level) | Prevent duplicate indexing |
| `media_files` | `tmdb_id` | B-Tree (`idx_media_files_tmdb_id`) | Metadata join |
| `media_files` | `tmdb_show_id` | B-Tree (`idx_media_files_tmdb_show_id`) | Phase D show → episodes aggregate query (`WHERE tmdb_show_id = ? ORDER BY season_number, episode_number`) |
| `stream_sessions` | `client_id` | B-Tree (`idx_stream_sessions_client_id`) | Client history lookup |
| `stream_sessions` | `file_id` | B-Tree (`idx_stream_sessions_file_id`) | File stream history |
| `stream_sessions` | `ended_at` | B-Tree (`idx_stream_sessions_ended_at`) | Active session queries (`WHERE ended_at IS NULL`) |
| `group_members` | `client_id` | B-Tree (`idx_group_members_client`) | Fast lookup of all groups a client belongs to (stream-gate query) |
| `groups` | `is_public` (partial WHERE `is_public = 1`) | UNIQUE (`idx_groups_public`) | Enforces the singleton Public group at the schema level |
| `group_pin_grants` | `expires_at` | B-Tree (`idx_group_pin_grants_expiry`) | Housekeeping prune of expired grants |
| `group_pin_attempts` | `(client_id, group_id, attempted_at DESC)` | B-Tree (`idx_group_pin_attempts_lookup`) | Rate-limit window scan for failed PIN attempts |
| `notifications` | `(read_at, dismissed_at, created_at DESC)` | B-Tree (`idx_notifications_unread`) | Fast unread / visible notification queries |
| `activity_events` | `created_at DESC` | B-Tree (`idx_activity_created`) | Default most-recent-first list query |
| `activity_events` | `(type, created_at DESC)` | B-Tree (`idx_activity_type_created`) | Type-prefix filter + ordering |
| `benchmark_runs` | `started_at DESC` | B-Tree (`idx_benchmark_runs_started_at`) | Newest-first list for the desktop benchmark history sidebar |
| `transcode_jobs` | `status` | B-Tree (`idx_transcode_jobs_status`) | Worker poll picks oldest `queued`; UI Queue tab filters non-terminal statuses |
| `transcode_jobs` | `file_id` | B-Tree (`idx_transcode_jobs_file`) | "Already enqueued?" dedup check on POST /transcode/queue |

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
| `015_extended_settings.sql` | Adds 18 columns to `user_settings` (skips `max_concurrent_streams` which already exists from 001): General — `language`, `auto_start_on_boot`, `auto_restart_on_crash`, `minimize_to_system_tray`, `theme_accent`, `default_library_view`, `scan_libraries_on_startup`, `generate_thumbnails`; Network — `preferred_mode`, `enable_mdns`, `enable_webrtc`, `relay_server_url`; Streaming — `default_quality`, `ai_segment_duration_seconds`; Security — `enable_pairing_required`, `session_timeout_minutes`; Advanced — `enable_log_export`, `custom_server_url`. |
| `016_media_quality_episodes_client_email.sql` | Three independent additions for Phase A of the real-data backfill: (a) FFprobe-derived `width`, `height`, `codec_name`, `hdr_format` on `media_files` (quality badges + Phase G direct-play allowlist); (b) TV episode aggregation columns `tmdb_show_id`, `season_number`, `episode_number` on `media_files` plus `idx_media_files_tmdb_show_id` (Phase D ships pure-SQL show endpoints — no new `episodes` table); (c) `email` and `paired_at` on `clients` for the new `GET /auth/clients/me` profile endpoint. `paired_at` is back-filled to migration-apply time for already-paired rows so the desktop's "Paired Mar 15" label never shows blank. |
| `017_hwaccel_device.sql` | Adds nullable `transcoding_hwaccel_device TEXT DEFAULT NULL` to `user_settings`. `NULL` = auto (server uses `/dev/dri/renderD128` as the VAAPI default). Used by `ffmpeg_service` for the VAAPI `-hwaccel_device` flag on multi-GPU Linux. Silently ignored on Windows / macOS / for non-VAAPI encoders. |
| `018_sanitize_encoder.sql` | Cleans `user_settings.transcoding_encoder` rows that hold legacy encoder values (e.g. `h264_amf`) not in the current 10-encoder registry `Literal` set — resets them to `libx264`. Prevents Pydantic 422 on every settings save after an encoder is removed from the registry. |
| `019_sanitize_license_key.sql` | Sanitises stale `user_settings.license_key` values to NULL when they don't match the current 5-segment FLUXORA shape (`FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<HMAC8>`). The 4-segment legacy shape from phase-4 was tightened to 5 segments without a migration; this closes that gap. Uses pure SQL `length - length(replace(key, '-', ''))` to count dashes without regex. Idempotent. |
| `020_encoder_chain.sql` | Adds `transcoding_chain TEXT DEFAULT NULL` to `user_settings`. Stored as JSON-encoded list (chains are tiny + single-tenant; never queried relationally). Walked by `services/session_router.py` on every transcode session start; NULL falls back to the default chain `[transcoding_encoder, "libx264"]`. Slice C of the GPU UX plan. |
| `021_session_encoder.sql` | Adds `encoder_used TEXT DEFAULT NULL` to `stream_sessions`. Populated by the stream router from `session_router.get_session_encoder(session_id)` on INSERT — null on stream-copy sessions. Drives the desktop's per-session encoder pill + supports historical "why did N+1 fall back yesterday?" diagnostics across server restarts (the in-memory ring buffer in `session_router` only covers the current process lifetime). |
| `022_remove_corrupt_media_paths.sql` | One-shot data migration. Deletes `media_files` rows whose `path` is non-absolute or starts with `[\` / `[/` — the residue of a prior buggy upload path that consumed `Library.root_paths` JSON character-wise so `root_paths[0]` returned `'['`. Deletes their dependent `stream_sessions` first to satisfy the `file_id REFERENCES media_files(id)` foreign key. Idempotent: a future run finds no matching rows once `library_service._is_valid_absolute_media_path` blocks new bad rows from landing. |
| `023_clients_last_ip.sql` | Adds nullable `last_ip TEXT` to `clients`. Populated by `auth_service.create_pair_request` (initial pair, captures `request.client.host`) and `auth_service.update_client_heartbeat` (called from the `validate_token` dependency on every authenticated request). Drives the desktop Clients screen's IP column (table + detail panel). Two semantics changes piggyback on this migration: (a) `last_seen` was previously frozen at pair / approval — the heartbeat write now refreshes it on every authenticated request too; (b) the heartbeat path is wrapped in try/except + WARNING log so a transient SQLite write failure can't 401 a valid request. **Known limitation:** when the request arrives via the Cloudflare Tunnel, `request.client.host` is the cloudflared loopback (`127.0.0.1`), not the real public IP — the `CF-Connecting-IP` header isn't currently consumed in the heartbeat path. Acceptable in v1: the field's primary use case is LAN device identification for pair-debug. |
| `024_benchmark_history.sql` | Creates the `benchmark_runs` table for encoder-benchmark history persistence. Top-level metadata columns (`started_at`, `finished_at`, `duration_sec`, `fps`, `width`, `height`, `verify_caps`, `encoder_count`) + a `results_json TEXT` blob holding the per-encoder array as JSON (always fetched together with the parent run; relational split would add a join + order-preservation hassle for no query benefit at this scale). Indexed on `started_at DESC` to support the desktop sidebar's newest-first list. Auto-pruned to 50 entries by `benchmark_history_service.prune_history` after every save — runs are cheap to recreate and the operator only ever cares about recent comparisons. New endpoints: `GET /api/v1/transcoding/benchmark/history`, `GET /api/v1/transcoding/benchmark/history/{id}`, `DELETE /api/v1/transcoding/benchmark/history/{id}` (all localhost-only). `POST /transcoding/benchmark` persists every run before responding and returns the new `id` so the desktop's history sidebar can keep the visible result aligned with the highlighted row. |
| `025_groups_v2_content_spaces.sql` | Groups v2 content-spaces redesign (plan: `docs/10_planning/13_groups_v2_content_spaces.md`). Adds 7 columns to `groups` (`is_public`, `icon`, `color`, `requires_pin`, `pin_hash`, `pin_mode`, `max_concurrent_streams`) + UNIQUE partial `idx_groups_public ON groups(is_public) WHERE is_public = 1` enforcing the singleton.  Adds `time_window_override TEXT` to `group_members` (per-member override of the group's window — "older kid stays up later").  Creates `group_pin_grants` (PIN unlock ledger) + `group_pin_attempts` (brute-force ledger) with their indexes.  Manufactures the singleton Public group with a friendly description + violet-grey color + 'public' icon.  Backfills `group_restrictions.allowed_libraries` for Public with `NULLIF(json_group_array(id), '[]') FROM libraries` — fresh installs (no libraries) store NULL (Public exposes nothing yet); upgrades store the full library set (Public exposes everything so v1 paired clients don't lose visibility on the upgrade).  The NULLIF dance is critical: v1's intersect logic reads `'[]'` as "block everything" which would 403 every stream-start for clients only in Public.  Auto-adds every approved client to Public so post-migration paired devices keep a baseline visibility.  **Semantic flip:** `group_restrictions.allowed_libraries` flips from subtractive ("client can ONLY stream from these") to additive ("this group EXPOSES these to its members"); JSON value is identical, only interpretation changes.  Operator audit recommended post-migration — see plan §M5. |
| `026_groups_per_client_pins.sql` | Groups v2 §M8 — hybrid PIN model.  Adds `pin_model TEXT NOT NULL DEFAULT 'shared' CHECK(pin_model IN ('shared','per-client'))` to `groups`; existing rows default to `shared` so no behavior change for already-shipped data.  Creates `group_member_pins(group_id, client_id, pin_hash, enrolled_at)` ledger.  Per-client mode: each member device chooses + remembers its own PIN on first access; operator never sees the plaintext.  Recovery path = `DELETE FROM group_member_pins` for that (group, client), forcing re-enrollment on next access (operator-facing route is `DELETE /api/v1/groups/{id}/members/{cid}/pin`, localhost-only).  Compromise blast radius for per-client = one device, vs whole household for shared mode. |
| `027_transcode_jobs.sql` | Plan 18 — user-driven library transcode.  Adds three sidecar columns to `media_files`: `transcoded_path TEXT`, `transcoded_size_bytes INTEGER`, `transcoded_at INTEGER`.  Creates `transcode_jobs` (id, file_id FK, target_codec, encoder, quality_preset, status CHECK in {queued,running,done,failed,cancelled}, progress_pct REAL, eta_sec, error, output_path, created_at, started_at, finished_at) with indexes on `status` and `file_id`.  Drives the desktop Transcode page's 3-tab UI (Candidates / Queue / History); FIFO worker in `services/transcode_service.py` claims `queued` rows and runs FFmpeg `-progress pipe:2` to populate `progress_pct` + `eta_sec` in place.  When `media_files.transcoded_path` is non-NULL and the file exists on disk, `routers/stream.py::POST /stream/start` reads from that path instead of `media_files.path` so playback stream-copies the H.264 sidecar (no live transcode). |
| `028_streaming_mode.sql` | Plan 19 §M7 — global streaming-mode toggle on `user_settings`.  `streaming_mode TEXT NOT NULL DEFAULT 'client-decode' CHECK(streaming_mode IN ('client-decode','server-transcode'))`.  When `client-decode` (the v1 launch default) `ffmpeg_service.start_stream` extends the direct-remux check to AV1 + VP9 sources — they ride the same fmp4 stream-copy path HEVC already uses, no transcode at all.  When `server-transcode` (legacy fallback for older device pools) AV1/VP9 fall through to the live-transcode-to-H.264 branch from plan 18.  Sidecar pickup wins regardless of mode — files already transcoded via plan 18 keep stream-copying their H.264 sidecar.  Operator toggles via Settings → Encoder Settings → Streaming Mode. |
