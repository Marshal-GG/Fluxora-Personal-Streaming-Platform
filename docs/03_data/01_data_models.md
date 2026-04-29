# Data Models

> **Category:** Data  
> **Status:** Active - Updated 2026-04-29 (TMDB fields, resume progress, license keys, Polar orders)

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
> Global server configuration

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | INTEGER | ✅ | Always 1 (singleton) |
| server_name | TEXT | ✅ | Display name of server |
| transcoding_enabled | BOOLEAN | ✅ | Whether FFmpeg transcoding is on |
| max_concurrent_streams | INTEGER | ✅ | Stream limit (auto-set by tier change) |
| subscription_tier | TEXT | ✅ | Enum: `free`, `plus`, `pro`, `ultimate` |
| tmdb_api_key | TEXT | ❌ | User's TMDB key |
| license_key | TEXT | ❌ | Paid-plan license key; format-validated (migration 006) |

---

### Entity: `PolarOrder`
> Tracks paid Polar orders that have already issued a Fluxora license key

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| order_id | TEXT | ✅ | Polar order ID; primary key and idempotency key |
| tier | TEXT | ✅ | Fluxora tier decoded from Polar product metadata |
| license_key | TEXT | ✅ | Generated Fluxora license key; never logged or returned by webhook |
| processed_at | TEXT | ✅ | UTC timestamp when the order was processed |

---

## Relationships

```
Library ──1:N──▶ MediaFile
MediaFile ──1:N──▶ StreamSession
Client ──1:N──▶ StreamSession
UserSettings ──1:1──▶ (singleton)
PolarOrder ── independent idempotency table for payment webhooks
```

---

## Enums & Constants

| Enum | Values |
|------|--------|
| `LibraryType` | `movies`, `tv`, `music`, `files` |
| `ConnectionType` | `lan`, `webrtc_p2p`, `turn_relay` |
| `Platform` | `android`, `ios`, `windows`, `macos`, `linux` |
| `SubscriptionTier` | `free`, `plus`, `pro`, `ultimate` |

---

## Validation Rules

- `MediaFile.path` must be an absolute path; must exist at time of indexing
- `StreamSession.ended_at` must be > `started_at` if set
- `UserSettings` is a singleton (only one row, id = 1)
- `Client.auth_token` stores the HMAC-SHA256 hash of the raw bearer token — never the raw token itself
- `PolarOrder.order_id` is unique; duplicate webhook deliveries must not issue duplicate license keys
- `PolarOrder` intentionally does not store customer email or other payment PII
