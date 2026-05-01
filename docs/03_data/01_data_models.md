# Data Models

> **Category:** Data  
> **Status:** Active - Updated 2026-05-01 (TMDB fields, resume progress, license keys, Polar orders + customer_email, transcoding settings, Groups + stream-gate, Profile fields)

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

## Relationships

```
Library ──1:N──▶ MediaFile
MediaFile ──1:N──▶ StreamSession
Client ──1:N──▶ StreamSession
UserSettings ──1:1──▶ (singleton)
PolarOrder ── independent idempotency table for payment webhooks
Group ──1:N──▶ GroupMember ──N:1──▶ Client
Group ──1:0..1──▶ GroupRestrictions
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
