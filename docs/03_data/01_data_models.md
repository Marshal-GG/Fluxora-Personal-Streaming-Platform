# Data Models

> **Category:** Data  
> **Status:** Active - Updated 2026-05-02 (TMDB fields, resume progress, license keys, Polar orders + customer_email, transcoding settings, Groups + stream-gate, Profile fields, Notification entity, ActivityEvent entity, UserSettings 18 new §7.10 columns, LogRecord computed entity)

---

## Core Entities

### Entity: `MediaFile`
> Represents a file in a library or browsable directory

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✅ | Primary key |
| path | TEXT | ✅ | Absolute path on server filesystem |
| name | TEXT | ✅ | Display name / filename |
| extension | TEXT | ✅ | File extension (mp4, mkv, mp3, etc.) |
| size_bytes | INTEGER | ✅ | File size |
| duration_sec | REAL | ❌ | Duration (if media) |
| library_id | TEXT | ❌ | FK → Library |
| tmdb_id | INTEGER | ❌ | TMDB metadata ID |
| title | TEXT | ❌ | TMDB canonical title (migration 004) |
| overview | TEXT | ❌ | TMDB plot synopsis (migration 004) |
| poster_url | TEXT | ❌ | TMDB poster image URL (migration 004) |
| last_progress_sec | REAL | ✅ | Resume position in seconds; default 0.0 (migration 005) |
| created_at | TIMESTAMP | ✅ | When indexed |
| updated_at | TIMESTAMP | ✅ | Last scan update |

---

### Entity: `Library`
> A named collection of media directories

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✅ | Primary key |
| name | TEXT | ✅ | e.g., "Movies", "TV Shows", "Music" |
| type | TEXT | ✅ | Enum: `movies`, `tv`, `music`, `files` |
| root_paths | TEXT (JSON) | ✅ | Array of root directories |
| last_scanned | TIMESTAMP | ❌ | Last library scan time |
| created_at | TIMESTAMP | ✅ | |

---

### Entity: `StreamSession`
> Tracks an active or historical streaming session

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✅ | Primary key |
| file_id | TEXT | ✅ | FK → MediaFile |
| client_id | TEXT | ✅ | FK → Client |
| started_at | TIMESTAMP | ✅ | Stream start time |
| ended_at | TIMESTAMP | ❌ | Stream end (null = active) |
| connection_type | TEXT | ✅ | Enum: `lan`, `webrtc_p2p`, `turn_relay` |
| bytes_transferred | INTEGER | ❌ | Total bytes served |
| progress_sec | REAL | ❌ | Last known playback position |

---

### Entity: `Client`
> A registered client device

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✅ | Primary key |
| name | TEXT | ✅ | Device display name |
| platform | TEXT | ✅ | Enum: `android`, `ios`, `windows`, `macos`, `linux` |
| last_seen | TIMESTAMP | ✅ | Last connection time |
| is_trusted | BOOLEAN | ✅ | Whether server has approved this client |
| auth_token | TEXT | ✅ | HMAC-SHA256 hash of bearer token — raw token never stored |
| status | TEXT | ✅ | Enum: `pending`, `approved`, `rejected` (added migration 003) |

---

### Entity: `UserSettings`
> Global server configuration and operator profile metadata

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | INTEGER | ✅ | Always 1 (singleton) |
| server_name | TEXT | ✅ | Display name of server |
| transcoding_enabled | BOOLEAN | ✅ | Whether FFmpeg transcoding is on |
| max_concurrent_streams | INTEGER | ✅ | Stream limit (auto-set by tier change) |
| subscription_tier | TEXT | ✅ | Enum: `free`, `plus`, `pro`, `ultimate` |
| tmdb_api_key | TEXT | ❌ | User's TMDB key |
| license_key | TEXT | ❌ | Paid-plan license key; format `FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>`, 5 segments (migration 006) |
| transcoding_encoder | TEXT | ✅ | FFmpeg video encoder: `libx264`, `h264_nvenc`, `h264_qsv`, `h264_vaapi`; default `libx264` (migration 010) |
| transcoding_preset | TEXT | ✅ | FFmpeg speed preset: `ultrafast`…`veryslow`; default `veryfast` (migration 010) |
| transcoding_crf | INTEGER | ✅ | Constant Rate Factor 0–51; lower = better quality; default 23 (migration 010) |
| display_name | TEXT | ❌ | Operator display name shown in the Profile screen (migration 012) |
| email | TEXT | ❌ | Operator email address (migration 012) |
| avatar_path | TEXT | ❌ | Absolute path to a local avatar image file (migration 012) |
| profile_created_at | TEXT | ❌ | UTC ISO-8601 timestamp; backfilled to migration-apply time for the pre-existing row (migration 012) |
| last_login_at | TEXT | ❌ | Reserved for v2; always `null` in v1 (migration 012) |
| language | TEXT | ❌ | UI language code; default `'en'` (migration 015) |
| auto_start_on_boot | BOOLEAN | ❌ | Start server on OS boot; default `0` (migration 015) |
| auto_restart_on_crash | BOOLEAN | ❌ | Restart server after crash; default `1` (migration 015) |
| minimize_to_system_tray | BOOLEAN | ❌ | Hide to tray instead of close; default `1` (migration 015) |
| theme_accent | TEXT | ❌ | Reserved for future accent override; always `null` in v1 — brand locked to violet (migration 015) |
| default_library_view | TEXT | ❌ | Default library render mode; `'grid'` or `'list'`; default `'grid'` (migration 015) |
| scan_libraries_on_startup | BOOLEAN | ❌ | Auto-scan all libraries at server start; default `1` (migration 015) |
| generate_thumbnails | BOOLEAN | ❌ | Auto-generate media thumbnails after scan; default `1` (migration 015) |
| preferred_mode | TEXT | ❌ | Network mode preference: `'auto'`, `'lan'`, `'webrtc'`; default `'auto'` (migration 015) |
| enable_mdns | BOOLEAN | ❌ | Broadcast mDNS on LAN; default `1` (migration 015) |
| enable_webrtc | BOOLEAN | ❌ | Allow WebRTC for WAN streaming; default `1` (migration 015) |
| relay_server_url | TEXT | ❌ | Override TURN relay URL; `null` = use server default (migration 015) |
| default_quality | TEXT | ❌ | Default stream quality: `'auto'`, `'4k'`, `'1080p'`, `'720p'`, `'480p'`; default `'auto'` (migration 015) |
| ai_segment_duration_seconds | INTEGER | ❌ | HLS segment duration in seconds for AI-driven adaptive streaming; default `4` (migration 015) |
| enable_pairing_required | BOOLEAN | ❌ | Require explicit pairing approval before client access; default `1` (migration 015) |
| session_timeout_minutes | INTEGER | ❌ | Idle session lifetime in minutes; range 1–1440; default `60` (migration 015) |
| enable_log_export | BOOLEAN | ❌ | Allow log export via API; default `1` (migration 015) |
| custom_server_url | TEXT | ❌ | Operator-specified public URL; overrides `FLUXORA_PUBLIC_URL` env var; `null` = use env (migration 015) |

> **Computed field — not stored:** `avatar_letter` is derived server-side by `profile_service.get_profile()`. Priority: first non-whitespace character of `display_name` → first character of the `email` local-part → `'F'`.

---

### Entity: `PolarOrder`
> Tracks paid Polar orders that have already issued a Fluxora license key

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| order_id | TEXT | ✅ | Polar order ID; primary key and idempotency key |
| customer_email | TEXT | ❌ | Customer email from Polar payload; stored for manual key delivery (migration 009) |
| tier | TEXT | ✅ | Fluxora tier decoded from Polar product metadata |
| license_key | TEXT | ✅ | Generated Fluxora license key; never logged or returned by webhook |
| processed_at | TEXT | ✅ | UTC timestamp when the order was processed |

---

### Entity: `Group`
> A named bundle of clients that share a common set of streaming restrictions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✅ | Primary key |
| name | TEXT | ✅ | Display name (max 120 chars) |
| description | TEXT | ❌ | Optional free-text description |
| status | TEXT | ✅ | Enum: `active`, `inactive`; default `active` |
| created_at | TEXT | ✅ | UTC ISO-8601 timestamp |
| updated_at | TEXT | ✅ | UTC ISO-8601 timestamp |
| member_count | INTEGER | — | Computed: number of members (not stored) |
| restrictions | GroupRestrictions | — | Embedded from `group_restrictions` row (never null in API response; all fields default to null = no restriction) |

---

### Entity: `GroupMember`
> Join record linking a Client to a Group

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| group_id | TEXT (UUID) | ✅ | FK → Group (CASCADE DELETE) |
| client_id | TEXT (UUID) | ✅ | FK → Client (CASCADE DELETE) |
| added_at | TEXT | ✅ | UTC ISO-8601 timestamp when the member was added |

Composite primary key: `(group_id, client_id)`. A client may belong to multiple groups simultaneously.

---

### Entity: `GroupRestrictions`
> Optional streaming restrictions attached to a Group (at most one row per Group)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| group_id | TEXT (UUID) | ✅ | PK + FK → Group (CASCADE DELETE) |
| allowed_libraries | TEXT (JSON) | ❌ | JSON array of library UUIDs; `null` = all libraries allowed |
| bandwidth_cap_mbps | INTEGER | ❌ | Maximum throughput in Mbps; `null` = unlimited (advisory in v1) |
| time_window | TEXT (JSON) | ❌ | JSON `{"start_h": 0-23, "end_h": 0-23, "days": [0-6]}`; `null` = always allowed. `days` uses Python weekday convention (0 = Monday … 6 = Sunday). If `end_h <= start_h` the window wraps midnight. |
| max_rating | TEXT | ❌ | Content-rating ceiling (e.g. `"PG-13"`); `null` = no restriction (advisory in v1 — `media_files` has no rating column yet) |

---

### Entity: `Notification`
> An in-app notification persisted in SQLite and fanned out live to WebSocket subscribers

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✅ | Primary key |
| type | TEXT | ✅ | Enum: `info`, `warning`, `error`, `success` — visual severity |
| category | TEXT | ✅ | Enum: `system`, `client`, `license`, `transcode`, `storage` — logical source |
| title | TEXT | ✅ | Short notification heading |
| message | TEXT | ✅ | Full notification body |
| related_kind | TEXT | ❌ | Type of the related entity, e.g. `"client"`, `"session"` |
| related_id | TEXT | ❌ | UUID of the related entity |
| created_at | TEXT | ✅ | UTC ISO-8601 timestamp |
| read_at | TEXT | ❌ | UTC ISO-8601 timestamp; `null` = unread |
| dismissed_at | TEXT | ❌ | UTC ISO-8601 timestamp; `null` = visible (not dismissed) |

---

### Entity: `LogRecord`
> A single structured log line emitted by the server. **Not stored in SQLite** — backed by the rotating JSON-line log file at `~/.fluxora/logs/server.log`. Returned by `GET /api/v1/logs` and streamed by `WS /api/v1/ws/logs`.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| ts | TEXT | ✅ | UTC ISO-8601 timestamp from the `asctime` JSON field |
| level | TEXT | ✅ | Log level: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` |
| source | TEXT | ✅ | Logger name (`name` field) — e.g. `fluxora.stream`, `uvicorn.access` |
| message | TEXT | ✅ | Human-readable log message |

> **Storage note:** The file handler in `main.py` uses `python-json-logger`'s `json` formatter — every line written to disk is a JSON object. `log_service.py` reads, parses, and filters these lines. The console handler in dev mode remains a human-readable string. When `GET /api/v1/logs` is called, `log_service` reads the current log file, applies `level`/`source`/`since`/`until`/`q` filters, and returns paginated `LogRecord` objects.

---

### Entity: `ActivityEvent`
> Append-only audit trail of notable server actions, feeding the desktop Activity screen and the Dashboard "Recent Activity" widget. Distinct from `Notification` — notifications are user-actionable alerts; activity events are the historical audit log.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✅ | Primary key |
| type | TEXT | ✅ | Event type in `<domain>.<verb>` form: `stream.start`, `stream.end`, `client.pair`, `client.approve`, `client.reject`, `library.scan` |
| actor_kind | TEXT | ❌ | Who initiated the action: `client`, `system`, `operator`, or `null` |
| actor_id | TEXT | ❌ | UUID of the actor entity (e.g. client_id); `null` for system/operator events |
| target_kind | TEXT | ❌ | Type of the affected entity: `session`, `client`, `file`, `library`, or `null` |
| target_id | TEXT | ❌ | UUID of the target entity |
| summary | TEXT | ✅ | Short human-readable line for the UI |
| payload | JSON | ❌ | Optional JSON blob for richer per-type detail; `null` if not set or invalid |
| created_at | TEXT | ✅ | UTC ISO-8601 timestamp |

Producer call sites (each wrapped in `try/except` — activity write failures are non-fatal):
- `routers/stream.py start_stream` → `stream.start`
- `routers/stream.py stop_stream` → `stream.end`
- `services/auth_service.py create_pair_request` → `client.pair`
- `services/auth_service.py approve_client` → `client.approve`
- `services/auth_service.py reject_client` → `client.reject`
- `services/library_service.py scan_library` (only when `added > 0`) → `library.scan`

---

## Relationships

```
Library ──1:N──▶ MediaFile
MediaFile ──1:N──▶ StreamSession
Client ──1:N──▶ StreamSession
UserSettings ──1:1──▶ (singleton)
PolarOrder ── independent idempotency table for payment webhooks
Group ──1:N──▶ GroupMember ──N:1──▶ Client
Group ──1:0..1──▶ GroupRestrictions
Notification ── independent event log; no FK constraints
ActivityEvent ── independent audit log; no FK constraints
```

---

## Enums & Constants

| Enum | Values |
|------|--------|
| `LibraryType` | `movies`, `tv`, `music`, `files` |
| `ConnectionType` | `lan`, `webrtc_p2p`, `turn_relay` |
| `Platform` | `android`, `ios`, `windows`, `macos`, `linux` |
| `SubscriptionTier` | `free`, `plus`, `pro`, `ultimate` |
| `GroupStatus` | `active`, `inactive` |
| `NotificationType` | `info`, `warning`, `error`, `success` |
| `NotificationCategory` | `system`, `client`, `license`, `transcode`, `storage` |
| `DefaultLibraryView` | `grid`, `list` |
| `PreferredMode` | `auto`, `lan`, `webrtc` |
| `DefaultQuality` | `auto`, `4k`, `1080p`, `720p`, `480p` |

---

## Validation Rules

- `MediaFile.path` must be an absolute path; must exist at time of indexing
- `StreamSession.ended_at` must be > `started_at` if set
- `UserSettings` is a singleton (only one row, id = 1)
- `Client.auth_token` stores the HMAC-SHA256 hash of the raw bearer token — never the raw token itself
- `PolarOrder.order_id` is unique; duplicate webhook deliveries must not issue duplicate license keys
- `PolarOrder.customer_email` stores only the email provided by Polar for manual key delivery — not used for any automated processing
- `Group.name` is 1–120 characters; `status` must be `active` or `inactive`
- `GroupMember` is idempotent — adding the same client twice (INSERT OR IGNORE) is safe
- `GroupRestrictions` rows are always present (created alongside the group); all restriction fields default to `null` (no restriction of that kind)
- A client can belong to any number of groups simultaneously; the stream-gate combines restrictions across every active group
- `UserSettings.display_name` and `UserSettings.email` have a server-enforced `max_length` (via `ProfileUpdate` Pydantic model); pass an empty string `""` to clear a field, pass `null` to leave it unchanged
- `UserSettings.avatar_letter` is computed on every read — it is never stored in the DB
- `UserSettings.default_library_view` must be `'grid'` or `'list'` (Pydantic `Literal` guard)
- `UserSettings.preferred_mode` must be `'auto'`, `'lan'`, or `'webrtc'` (Pydantic `Literal` guard)
- `UserSettings.default_quality` must be `'auto'`, `'4k'`, `'1080p'`, `'720p'`, or `'480p'` (Pydantic `Literal` guard)
- `UserSettings.session_timeout_minutes` must be in range `[1, 1440]` (1 minute to 24 hours)
- `UserSettings.ai_segment_duration_seconds` must be a positive integer
- `LogRecord` is never stored — it is always derived by reading and parsing the JSON log file
