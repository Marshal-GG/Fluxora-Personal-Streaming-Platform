# API Contracts

> **Category:** API  
> **Status:** Active - Updated 2026-05-09 (deep doc audit — fixed status-code drift on `/notifications/{id}/read` + `/notifications/read-all` (204 in code, doc said 200), schema drift on `/groups/{id}/enter` + `/groups/{id}/grant-status` (no `group_id` in body; `grant-status` does not return `pin_mode`), added missing `5/minute` rate limit on `/auth/request-pair` + `10/minute` on `/stream/start/{file_id}`, added missing `transcoding_hwaccel_device` settings field, added `cover_urls` on library responses, tightened `ai_segment_duration_seconds` bounds to `[1, 30]`, added `total_resolutions` + `current_resolution_*` fields on benchmark progress + `resolution_count` on benchmark history entries, expanded HLS file-serving description to cover `.m4s` / `init.mp4`, refreshed activity event types list).  2026-05-08 (new `DELETE /api/v1/auth/clients/me` self-revoke for the mobile sign-out flow — mobile redesign audit §17.3 #3 + new `POST /api/v1/files/{file_id}/reset-progress` for the "Start over" affordance — streaming pipeline plan §4.10). 2026-05-04 (**Phase 6 follow-ups:** `POST /api/v1/stream/start/{file_id}` gained `?tonemap=true` query param; `StreamStartResponse` gains `hdr_format: string | null` + `tonemapped: bool` fields. GPU UX Slice A: new `GET /api/v1/transcoding/advisor` endpoint; `/transcoding/status` gains `encoder_test_error` + `encoder_tested_at` fields; `transcoding_encoder` allowed values expanded to all 10 registry encoders; `/stream/start` 503 detail now carries the FFmpeg stderr tail. Earlier 2026-05-04: Phase B real-data backfill: new `GET /api/v1/files/search?q=&limit=`, new `GET /api/v1/auth/clients/me/continue-watching?limit=`, new `GET /api/v1/auth/clients/me/stats` returning `{hours, movies, shows}`. Phase A real-data backfill: new `GET /api/v1/files/recent`; new `GET /api/v1/auth/clients/me`; `POST /api/v1/auth/request-pair` accepts optional `email`; `MediaFileResponse` extended with FFprobe + episode aggregation fields; pairing flow now resets a previously-approved client back to `pending` instead of returning 409). 2026-05-03: library-screen P0/P1: new `PATCH /api/v1/library/{id}` + `total_size_bytes` field on every library response; `library.update` activity event; type field is now immutable per ADR-016; disk-file deletion is policy-locked per ADR-017. 2026-05-02 batch: new endpoints for the desktop redesign: `/info/stats` + `/ws/stats`, `/info/restart`, `/info/stop`, `/library/storage-breakdown`; previous round added orders, upload, delete file, stream sessions, progress; auth model updated for files/library; transcoding settings fields validated as enums + CRF bounded 0-51; license keys are 5-part only; Groups CRUD + member management + stream-gate; Profile endpoints; Notifications REST + WS added; Activity event log added; §7.8 `GET /api/v1/transcoding/status`; §7.9 `GET /api/v1/logs` + `WS /api/v1/ws/logs`; §7.10 settings PATCH extended with 18 new fields; §7.11 orders pagination + `/orders/portal-url`

---

## API Style

**REST over HTTP** — FastAPI (Python)  
**Streaming:** HLS over HTTP (`.m3u8` + `.ts`)  
**Real-time:** WebSocket for signaling and status  

---

## Base URLs

| Environment | URL |
|-------------|-----|
| Local (LAN) | `http://{server_local_ip}:8000` |
| Internet (TURN) | Tunneled through WebRTC data channel |

---

## Authentication

Most endpoints require a bearer token issued after client pairing:
```
Authorization: Bearer {auth_token}
```

**Auth modes:**

| Mode | Dependency | Used by |
|------|-----------|---------|
| Bearer token required | `validate_token` | Stream + HLS endpoints, all `/api/v1/ws/*` WebSockets (when not localhost), every `/auth/clients/me*` route (`GET`, `PATCH`, `DELETE`, `/stats`, `/continue-watching`, `/visible-libraries`), and the bearer-only PIN unlock surfaces (`POST /groups/{id}/enter`, `POST /groups/{id}/enroll`, `POST /groups/{id}/enroll/change`, `DELETE /groups/{id}/grant`, `GET /groups/{id}/grant-status`) |
| Bearer token OR localhost | `validate_token_or_local` | `/files`, `/library`, `GET /info/stats`, `GET /groups`, `GET /groups/{id}`, `GET /groups/{id}/members`, `GET /notifications`, `POST /notifications/{id}/read`, `POST /notifications/read-all`, `DELETE /notifications/{id}`, `GET /activity`, `GET /logs` — desktop control panel needs no token |
| Localhost only | `require_local_caller` | `/auth/approve`, `/auth/reject`, `/auth/revoke`, `/auth/clients`, `GET /auth/clients/{id}/visible-libraries`, `/settings`, `/orders`, `/orders/portal-url`, `/stream/sessions`, `GET /transcoding/status`, `GET /transcoding/advisor`, `GET /transcoding/devices`, `GET /transcoding/fallback-history`, `POST /transcoding/benchmark`, `GET /transcoding/benchmark/progress`, `GET /transcoding/benchmark/history`, `GET /transcoding/benchmark/history/{id}`, `DELETE /transcoding/benchmark/history/{id}`, `POST /info/restart`, `POST /info/stop`, `POST /info/support-bundle`, `POST /groups`, `PATCH /groups/{id}`, `DELETE /groups/{id}`, `POST /groups/{id}/members`, `PATCH /groups/{id}/members/{cid}`, `DELETE /groups/{id}/members/{cid}`, `DELETE /groups/{id}/members/{cid}/pin`, `POST /groups/{id}/grants/reset`, `POST /groups/{id}/master-override`, `GET /profile`, `PATCH /profile` |
| No auth | — | `/info`, `/healthz`, `/auth/request-pair`, `/auth/status/{client_id}`, `/webhook/polar` |

**Heartbeat side effect (migration 023, 2026-05-06):** every successful `validate_token` resolution writes `clients.last_seen = NOW()` and `clients.last_ip = request.client.host` for the resolving client. This is best-effort — wrapped in try/except + WARNING log so a transient SQLite write failure can't 401 a valid request — but it changes the semantics of `last_seen` from "frozen at pair / approval" to "live within one poll cycle." Tunneled requests (cloudflared) record the loopback IP because `CF-Connecting-IP` isn't consumed in this path; documented limitation. See [`docs/03_data/02_database_schema.md`](../03_data/02_database_schema.md) migration 023 row.

---

## Endpoints

### `GET /api/v1/info`
**Description:** Returns server identity — used during discovery and to learn the server's public URL after pairing.  
**Auth:** None required.  
**Status:** ✅ Implemented

**Response:**
```json
{
  "server_name": "My Fluxora Server",
  "version": "1.0.0",
  "tier": "plus",
  "remote_url": "https://fluxora-api.marshalx.dev"
}
```

`remote_url` precedence (highest first, as of 2026-05-06):

1. `user_settings.custom_server_url` — operator-editable from the desktop **Settings → Advanced → Public URL Advertisement** card. Lets the operator change the advertised URL without restarting the server. Whitespace-only values are ignored (treated as unset).
2. `FLUXORA_PUBLIC_URL` env var — set at process start, read once into `config.settings`.
3. `null` — no public URL configured; off-LAN clients can't reach the server until one is set.

Clients persist `remote_url` after the first successful pair and use it from off-LAN networks (decision D1 in [`docs/05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md#decisions-locked)). The DB-first precedence means an operator can flip the published URL at runtime — useful when migrating between tunnels or testing a custom domain — without bouncing the server.

---

### `GET /api/v1/healthz`
**Description:** Lightweight liveness probe. Constant body, no DB hit, no auth. Used by Cloudflare Tunnel for ingress health checks and by clients deciding whether the public URL is reachable.  
**Auth:** None required.  
**Status:** ✅ Implemented

**Response:**
```json
{ "ok": true }
```

> Excluded from the OpenAPI schema — not part of the v1 contract; format may evolve. Anything heavier (system stats, license info) belongs at `/info` or `/info/stats`.

---

### `POST /api/v1/info/restart`
**Description:** Schedule a graceful server restart. Returns immediately; the server signals itself with `SIGINT` ~300 ms later so the response can flush. Auto-relaunch requires a process supervisor (systemd, NSSM, Windows Service) — without one the server simply exits and must be re-started manually.  
**Auth:** Localhost only.  
**Status:** ✅ Implemented

**Response:** `202 Accepted`
```json
{ "status": "restart_requested" }
```

---

### `POST /api/v1/info/stop`
**Description:** Schedule a graceful server shutdown. Same mechanics as `/info/restart` but logged as a shutdown.  
**Auth:** Localhost only.  
**Status:** ✅ Implemented

**Response:** `202 Accepted`
```json
{ "status": "shutdown_requested" }
```

---

### `POST /api/v1/info/support-bundle`
**Description:** Generate an in-memory gzipped tar archive of operator-side debug state for field triage. Builds the bundle synchronously and returns the bytes — caller saves to disk via OS file picker. Bundle stays well under 50 MB on a normal home server (logs are the largest member; rotation caps individual log files at ~10 MB and the bundle includes at most 5 log files).  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented (2026-05-06)

**Response:** `200 OK`
- `Content-Type: application/gzip`
- `Content-Disposition: attachment; filename="fluxora-support-<UTC stamp>.tar.gz"` (e.g. `fluxora-support-20260506_143055.tar.gz`)
- Body: gzipped tar bytes

Archive structure:
```
metadata.json         # generated_at, server_version, python_version, platform, data_dir
system/stats.json     # one psutil snapshot via system_stats.collect()
system/encoders.json  # encoder self-test results from transcoding_service.get_test_results()
settings/redacted.json  # user_settings row, with secret fields replaced (see redaction below)
database/schema.sql   # sqlite_master DDL only — never row data
logs/<filename>       # active rotating log file + up to 4 rotated siblings
```

**Redaction policy** (`settings/redacted.json`): the fields `tmdb_api_key`, `license_key`, `email` from `user_settings` are replaced with the string `***REDACTED***` when their value is non-null; null values stay null. This preserves the "this was configured" signal for triage without leaking the value. All other settings fields round-trip verbatim.

**Failure-isolation policy:** each sub-collector (`metadata`, `stats`, `settings`, `schema`, `encoders`, `logs`) is wrapped in try/except. A single collector failure ships a partial bundle whose corresponding member contains `{"_collect_error": "<repr>"}` rather than failing the whole download. The `metadata.json` member is generated first and is the most likely to succeed.

**Errors:** `403` not from localhost.

---

### `GET /api/v1/info/stats`
**Description:** Live system stats — CPU, RAM, network throughput, uptime, LAN IP, internet connectivity, active stream count. Backs the redesigned sidebar System Status block, the bottom status bar, and the Dashboard sparklines.  
**Auth:** Bearer token OR localhost (`validate_token_or_local`). Matches the `/ws/stats` WebSocket auth pattern.  
**Status:** ✅ Implemented

**Response:**
```json
{
  "uptime_seconds": 9912,
  "lan_ip": "192.168.1.105",
  "public_address": null,
  "internet_connected": true,
  "cpu_percent": 18.4,
  "ram_percent": 42.1,
  "ram_used_bytes": 6800000000,
  "ram_total_bytes": 16000000000,
  "network_in_mbps": 8.42,
  "network_out_mbps": 2.10,
  "active_streams": 1
}
```

**Notes:**
- `public_address` is currently always `null` — STUN-based discovery lands in a separate PR.
- `network_in_mbps` / `network_out_mbps` are computed as the rate **since the last call**. The first call returns `0.0` for both because there is no baseline yet.
- Loopback interfaces are excluded from the network rate.
- `internet_connected` is a TCP probe to `1.1.1.1:80`, cached for 30 seconds to avoid hammering CloudFlare.

---

### `POST /api/v1/auth/request-pair`
**Description:** Client initiates pairing. Creates a pending client record on the server, or — if a row with this `client_id` already exists — resets it back to `pending` and clears any previously-issued bearer token. Same-`client_id` re-pair is the supported recovery path for re-installed apps and restored device backups; it intentionally invalidates the prior token immediately so a stolen token cannot survive a re-pair.  
**Auth:** None required.  
**Rate limit:** 5/minute per client IP — pair-request flooding is the classic enumeration vector against an unauthenticated endpoint, so the limiter caps both initial pair attempts and re-pair recoveries.  
**Status:** ✅ Implemented

**Request:**
```json
{
  "client_id": "uuid-generated-by-client",
  "device_name": "Pixel 8 Pro",
  "platform": "android",
  "app_version": "0.1.0",
  "email": "alex@fluxora.io"
}
```

`email` is optional. Captured during the mobile pairing flow's optional contact step (Phase A backfill plan §9.1); echoed back to the operator via `GET /auth/clients/me` and used solely for surfacing in the profile screen — it is never used as an identity key.

**Response:**
```json
{
  "client_id": "uuid",
  "status": "pending_approval"
}
```

---

### `GET /api/v1/auth/status/{client_id}`
**Description:** Poll for pairing approval. Returns the raw bearer token once on first approved poll — client must store it immediately.  
**Auth:** None required.  
**Status:** ✅ Implemented

**Response (pending):**
```json
{ "status": "pending_approval", "auth_token": null }
```

**Response (approved — token only returned on first poll):**
```json
{ "status": "approved", "auth_token": "raw-token-store-in-secure-storage" }
```

**Response (rejected):**
```json
{ "status": "rejected", "auth_token": null }
```

---

### `POST /api/v1/auth/approve/{client_id}`
**Description:** Control Panel approves a pending pair request.  
**Auth:** Localhost only — `require_local_caller` dependency rejects requests from non-loopback IPs with `403`.  
**Status:** ✅ Implemented

**Response:**
```json
{ "client_id": "uuid", "status": "approved" }
```

**Errors:** `403` not from localhost · `404` client not found · `409` client already approved/rejected (a fresh `POST /auth/request-pair` from the same `client_id` resets the row back to `pending` and resolves the 409 — the operator does not have to revoke + re-add)

---

### `POST /api/v1/auth/reject/{client_id}`
**Description:** Control Panel rejects a pending pair request.  
**Auth:** Localhost only — same `require_local_caller` restriction as `/approve`.  
**Status:** ✅ Implemented

**Response:**
```json
{ "client_id": "uuid", "status": "rejected" }
```

---

### `DELETE /api/v1/auth/revoke/{client_id}`
**Description:** Revoke an approved client's access. Takes effect immediately. Emits a `client.revoke` activity event.  
**Auth:** Localhost only (`require_local_caller`). Operator action surfaced from the desktop Clients screen — clients cannot revoke each other.  
**Status:** ✅ Implemented

**Response:** `204 No Content`

---

### `GET /api/v1/auth/clients`
**Description:** List all paired clients (all statuses) with their last-known IP and one in-flight stream session (when present). Used by the desktop control panel's Clients screen — table rows + detail panel.  
**Auth:** Localhost only — `require_local_caller` dependency rejects non-loopback callers with `403`.  
**Status:** ✅ Implemented

**Response:**
```json
{
  "clients": [
    {
      "id": "uuid",
      "name": "Pixel 8 Pro",
      "platform": "android",
      "status": "approved",
      "last_seen": "2026-05-06T12:00:00",
      "is_trusted": true,
      "last_ip": "192.168.1.42",
      "active_session": {
        "session_id": "uuid",
        "started_at": "2026-05-06T11:55:00",
        "encoder_used": "h264_nvenc",
        "media_title": "Inception"
      },
      "groups": [
        {"id": "uuid", "name": "Family", "status": "active"},
        {"id": "uuid", "name": "Kids",   "status": "active"}
      ]
    }
  ],
  "total": 1
}
```

- `last_ip` (migration 023): socket-level IP captured at pair time and refreshed on every authenticated request. `null` for rows that haven't sent an authenticated request since the upgrade. Tunneled requests (cloudflared) record the loopback IP — the `CF-Connecting-IP` header is NOT consumed in the heartbeat path; documented limitation, not a bug.
- `last_seen` semantics: as of migration 023 this is now refreshed by `auth_service.update_client_heartbeat()` from the `validate_token` dependency. **Before migration 023** the column was effectively frozen at pair / approval — any consumer that read this field as "last poll time" was reading stale data. Audit any UI that surfaces this value to confirm it now means what it says.
- `active_session`: `null` when the client has no `stream_sessions` row with `ended_at IS NULL`. When multiple in-flight sessions exist for a single client (defensive — v1 caps `concurrent_session_cap` at 1 per encoder), the most recently started one wins via `ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY started_at DESC) = 1`. `media_title` falls back to `media_files.name` when the file has no TMDB-derived `title`.
- `encoder_used` is the encoder picked by `session_router` at session start. `null` for stream-copy sessions (FFmpeg `-c:v copy`) since no encoder was selected.
- `groups` (M3 of `12_groups_remediation_plan.md`, 2026-05-07): list of `GroupSummary` objects (`{id, name, status}`) for every group the client belongs to. Empty list when the client is in no groups — never `null` or absent, so consumers can read unconditionally. Aggregated server-side via SQLite's `json_group_array(json_object(...))` over `group_members` ⨝ `groups`; pre-M3 callers that don't know the field still parse fine because the desktop entity defaults it to `[]`. Heavier per-group fields (`restrictions`, `member_count`, `created_at`, `updated_at`) live on `/groups/{id}` only — not duplicated here.

**Errors:** `403` not from localhost

---

### `GET /api/v1/auth/clients/me`
**Description:** Per-client profile surface — the calling client's display name, optional email, platform, pair timestamp, last-seen, and the operator's current subscription tier. Backs the mobile profile screen (Phase A backfill plan §9.1).  
**Auth:** Bearer token required (`validate_token`). The bearer resolves to a single client row; there is no `client_id` parameter — clients can only see their own profile.  
**Status:** ✅ Implemented

**Response:**
```json
{
  "id": "uuid",
  "display_name": "Alex's iPhone",
  "email": "alex@fluxora.io",
  "platform": "ios",
  "paired_at": "2026-03-15T10:14:22.123Z",
  "last_seen": "2026-05-04T08:30:00.000Z",
  "tier": "plus"
}
```

`email` and `paired_at` may be `null` for clients paired before the migration-016 columns existed. `display_name` reads from the existing `clients.name` column — `name` doubles as display name; the API field is renamed for clarity. `tier` is read live from `user_settings.subscription_tier` so a freshly-applied license upgrade is reflected on the next mobile profile refresh.

**Errors:** `401` missing/invalid bearer

---

### `PATCH /api/v1/auth/clients/me`
**Description:** Self-rename. Lets the calling client update its own `display_name` (the `clients.name` column under the hood). Backs the mobile Account screen's "Edit device name" affordance (mobile settings remediation plan M2.5, Open Question #1 follow-up). Bearer-only by design — the target `client_id` is resolved from the token, so the request cannot be spoofed to rename a different client's row. The operator-driven rename path is a separate concern (when added) on a localhost-gated route. Records a `client.profile_updated` activity event with `actor_kind='client'`.  
**Auth:** Bearer token required (`validate_token`).  
**Status:** ✅ Implemented (2026-05-08)

**Request Body:**
```json
{ "display_name": "Alex's iPhone 15" }
```

- `display_name` is trimmed before length checks; `[1, 50]` characters after trim.
- Pure-whitespace input, empty strings, and strings containing control characters (`\x00`–`\x1f`) are rejected with 422 — these would corrupt the operator's Clients screen and are a common log-injection vector.

**Response:** Same shape as `GET /auth/clients/me` (the row is re-fetched after the UPDATE so `last_seen` reflects the bump from the request itself).
```json
{
  "id": "uuid",
  "display_name": "Alex's iPhone 15",
  "email": "alex@fluxora.io",
  "platform": "ios",
  "paired_at": "2026-03-15T10:14:22.123Z",
  "last_seen": "2026-05-08T12:00:00.000Z",
  "tier": "plus"
}
```

**Errors:** `401` missing/invalid bearer · `422` invalid body (blank, too long, control chars)

---

### `DELETE /api/v1/auth/clients/me`
**Description:** Self-revoke. Calling client's bearer + row are torched in the same teardown the operator-driven `DELETE /auth/revoke/{id}` performs (status → `rejected`, `auth_token` zeroed, `is_trusted` dropped). Backs the mobile sign-out flow (mobile redesign audit §17.3 #3) — without this the bearer would stay valid server-side until natural expiry, leaving a window where a stolen-and-not-yet-cleared device token could still authenticate. Records a `client.revoke` activity event with `actor_kind='client'` (vs `'operator'` for desktop-driven revokes) so the operator's Activity feed surfaces self-initiated sign-outs.  
**Auth:** Bearer token required (`validate_token`).  
**Status:** ✅ Implemented (2026-05-08)

**Response:** `204 No Content`  
**Errors:** `401` missing/invalid bearer

---

### `GET /api/v1/auth/clients/me/stats`
**Description:** Per-client watch statistics — backs the mobile Profile stats row (Phase B backfill plan §3 row 3). Returns `{hours, movies, shows}` aggregated from `stream_sessions` + `media_files` for the calling client. All three values are non-negative integers and degrade gracefully — a fresh client returns `{0, 0, 0}` rather than 404.  
**Auth:** Bearer token required (`validate_token`).  
**Status:** ✅ Implemented

**Response:**
```json
{ "hours": 5, "movies": 2, "shows": 0 }
```

- `hours` is `SUM(progress_sec) / 3600` rounded down across the user's `stream_sessions`.
- `movies` is the count of distinct movie file ids the user has at least one stream session against (joined to `libraries.type = 'movies'`).
- `shows` is the count of distinct `tmdb_show_id` values across the user's stream sessions. Stays at 0 until Phase D back-fills `tmdb_show_id` for TV episodes — this is intentional honesty rather than a guessed-up number.

**Errors:** `401` missing / invalid bearer

---

### `GET /api/v1/auth/clients/me/continue-watching`
**Description:** Files with non-zero resume position that aren't effectively complete — backs the mobile Home "Continue watching" rail (Phase B backfill plan §3 row 1). Sorted by `media_files.updated_at DESC`. Excludes rows where `last_progress_sec >= duration_sec * 0.95` so a watched-to-the-end file stops resurfacing.  
**Auth:** Bearer token required (`validate_token`). Path namespace stays symmetric with `/auth/clients/me/...`; v1 reads the global `last_progress_sec` column on `media_files` (single-tenant home server).  
**Status:** ✅ Implemented

**Query Params:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | int (1-50) | `12` | Max rows; bounded server-side |

**Response:** Array of `MediaFileResponse` objects with the same shape as `GET /files`.  
**Errors:** `401` missing / invalid bearer

---

### `GET /api/v1/files/search`
**Description:** Search media files by `name` + TMDB `title` (case-insensitive substring match). Backs the mobile Search tab (Phase B backfill plan §3 row 2). v1 uses SQL `LIKE` per decision §5 row 1 — FTS5 is the v2 swap-in. The service escapes `_` and `%` before passing to LIKE so a search for `season_1` matches the literal `_`, not any character.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Query Params:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `q` | string (1-200) | — | Required. Empty / oversized queries return 422 |
| `limit` | int (1-50) | `20` | Max rows; clamped server-side |

**Response:** Array of `MediaFileResponse` objects.  
**Errors:** `401` invalid bearer · `422` empty `q` or `limit` outside `[1, 50]`

---

### `GET /api/v1/files`
**Description:** List indexed media files. Optionally filter by library.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Query Params:**
| Param | Type | Description |
|-------|------|-------------|
| `library_id` | string (UUID) | Filter to a specific library (optional) |

**Response:**
```json
[
  {
    "id": "uuid",
    "path": "/media/movies/Inception.mkv",
    "name": "Inception.mkv",
    "extension": ".mkv",
    "size_bytes": 8000000000,
    "duration_sec": 8880.0,
    "library_id": "uuid",
    "tmdb_id": 27205,
    "title": "Inception",
    "overview": "A thief who steals corporate secrets through...",
    "poster_url": "https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
    "resume_sec": 342.5,
    "width": 3840,
    "height": 2160,
    "codec_name": "hevc",
    "hdr_format": "HDR10",
    "tmdb_show_id": null,
    "season_number": null,
    "episode_number": null,
    "created_at": "2026-04-27T10:00:00+00:00",
    "updated_at": "2026-04-27T10:00:00+00:00"
  }
]
```

> **Notes:**
> - `title`, `overview`, `poster_url` are `null` until the library has been enriched via TMDB.
> - `resume_sec` defaults to `0.0` until the client reports playback progress via WebSocket.
> - `width`, `height`, `codec_name`, `hdr_format` are populated by ffprobe at scan time (migration 016). They remain `null` for non-video extensions and on rows scanned before the migration until the next scan touches them. `hdr_format` is one of `"HDR10"` / `"HLG"` / `"DolbyVision"` / `null` (SDR).
> - `tmdb_show_id` / `season_number` / `episode_number` are populated for TV episode files; `null` on movies. Phase D back-fills these via TMDB on the next library scan.

---

### `GET /api/v1/files/recent`
**Description:** Most-recently-added media files, newest first (sorted by `created_at DESC`). Backs the mobile Home "Recently added" rail (Phase A backfill plan §9.1).  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Query Params:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | int (1-50) | `20` | Max rows to return; clamped at 50 by the route |

**Response:** Array of `MediaFileResponse` objects with the same shape as `GET /files`.  
**Errors:** `401` invalid bearer · `422` `limit` outside `[1, 50]`

---

### `GET /api/v1/files/{file_id}`
**Description:** Get a single indexed media file by ID.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** Same schema as list item above.  
**Errors:** `404` file not found

---

### `GET /api/v1/files/{file_id}/content`
**Description:** Serve the raw bytes of a media file. Backs the M11 beyond-video viewers (PDF, photo, music) that load the file as a network source, and the "Open in..." action that downloads the file to a temp path on the device before handing it off to the OS share sheet. Group visibility applies — bearer-token callers receive 404 (not 403) when the file's library is outside their content space, matching the existing `GET /{file_id}` enumeration-prevention pattern.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented (2026-05-08)

**Response:** Raw file bytes with `Content-Type` MIME-detected from extension via `mimetypes.guess_type` (falls back to `application/octet-stream`); `Content-Disposition: attachment; filename={name}`.  
**Errors:** `404` file not found in DB · `404` file's library not visible to client · `404` file not found on disk

---

### `POST /api/v1/files/upload`
**Description:** Upload a file directly to a library. Multipart form — file saved to the library's first `root_path`. TMDB enrichment runs automatically if a TMDB key is configured.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Request:** `multipart/form-data`
| Field | Type | Description |
|-------|------|-------------|
| `library_id` | string (UUID) | Target library |
| `file` | binary | The file to upload |

**Response:** `201 Created` — the indexed `MediaFileResponse` for the uploaded file.  
**Errors:** `400` invalid library or bad file · `404` library not found · `500` write error

---

### `DELETE /api/v1/files/{file_id}`
**Description:** Remove a media file record from the index (does not delete the file from disk).  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** `204 No Content`  
**Errors:** `404` file not found

---

### `POST /api/v1/files/{file_id}/reset-progress`
**Description:** Reset the file's `last_progress_sec` to 0 so the next playback starts from 0:00. Backs the "Start over" affordance on the title detail screen (streaming pipeline plan §4.10).  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented (2026-05-08)

**Response:** `204 No Content`  
**Errors:** `404` file not found OR file's library is not visible to the caller (groups don't expose it). Bearer-token callers receive 404 (not 403) on the visibility miss to prevent enumeration of gated content. Localhost callers skip the visibility filter.

---

### `GET /api/v1/library`
**Description:** List all libraries.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:**
```json
[
  {
    "id": "uuid",
    "name": "Movies",
    "type": "movies",
    "root_paths": ["/media/movies"],
    "last_scanned": null,
    "created_at": "2026-04-27T10:00:00+00:00",
    "file_count": 142,
    "total_size_bytes": 1_380_000_000_000,
    "cover_urls": [
      "https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
      "https://image.tmdb.org/t/p/w500/aBcD....jpg"
    ]
  }
]
```

`total_size_bytes` is computed via `SUM(media_files.size_bytes)` in the `list_libraries` / `get_library` SQL — `0` for libraries with no files.

`cover_urls` is a small ordered list of TMDB poster URLs sampled from the library's most-recently-enriched files — backs the desktop Library card collage.  Empty list when the library has no TMDB-enriched files yet (no posters available); never `null`.  Defaulted to `[]` server-side so older clients deserialising the response don't break.

---

### `POST /api/v1/library`
**Description:** Create a new library.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Request:**
```json
{
  "name": "Movies",
  "type": "movies",
  "root_paths": ["/media/movies", "/nas/movies"]
}
```

Valid `type` values: `movies` · `tv` · `music` · `files`

**Response:** `201 Created` with the created library object (same schema as list item).

---

### `GET /api/v1/library/storage-breakdown`
**Description:** Aggregated storage usage across all libraries — backs the redesigned Dashboard donut. Sums `media_files.size_bytes` grouped by library `type`, plus combined disk capacity of every unique mount point that backs at least one library root.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:**
```json
{
  "total_bytes": 2992000000000,
  "capacity_bytes": 4400000000000,
  "by_type": {
    "movies": 1380000000000,
    "tv":     980000000000,
    "music":  340000000000,
    "files":  292000000000
  }
}
```

**Notes:**
- Mount-point dedup uses `os.stat().st_dev` so two libraries on the same disk only count toward `capacity_bytes` once.
- A library whose `root_paths` are inaccessible still counts toward `total_bytes` (its media files), but contributes `0` to `capacity_bytes`.
- All four `by_type` keys are always present, even when zero.

---

### `GET /api/v1/library/{library_id}`
**Description:** Get a single library by ID.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** Same schema as list item.  
**Errors:** `404` library not found

---

### `PATCH /api/v1/library/{library_id}`
**Description:** Update an existing library's `name` and/or `root_paths`. The library `type` is **immutable** — type changes would orphan or mis-render scanned files (ADR-016). Records a `library.update` activity event.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Request:** all fields optional; at least one must be provided.
```json
{
  "name": "Movies (4K)",
  "root_paths": ["/media/movies", "/nas/movies"]
}
```

**Response:** `200 OK` with the updated library object (same schema as list item, including the recomputed `total_size_bytes`).  
**Errors:** `404` library not found · `400` no fields supplied · `422` validation failure

---

### `DELETE /api/v1/library/{library_id}`
**Description:** Delete a library entry and its file index from the database. **Files on disk are never touched** — this is a hard policy lock (ADR-017). Records a `library.delete` activity event.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** `204 No Content`  
**Errors:** `404` library not found

---

### `POST /api/v1/library/{library_id}/scan`
**Description:** Walk the library's `root_paths`, index all discovered media files by extension, enrich metadata via TMDB, and update `last_scanned`. Runs under a per-library `asyncio.Lock` so two concurrent scan requests for the same library serialise (the second sees no new files and returns 0).  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:**
```json
{ "library_id": "uuid", "files_added": 42 }
```

**Errors:** `404` library not found · `500` scan failed (I/O error)

---

### `POST /api/v1/library/{library_id}/enrich-tmdb`
**Description:** Re-run TMDB enrichment for files in the library that lack a `tmdb_id`. Distinct from `/scan` — `/scan` only enriches files added in *this* scan, so files that were skipped by TMDB on first import (no API key configured at the time, capture-style filename, transient TMDB outage) stay un-enriched until this endpoint is called. Only touches rows where `tmdb_id IS NULL`; never overwrites operator-curated metadata.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Query params:**
- `include_dvr` (bool, default `false`) — bypass the DVR-filename skip heuristic so capture-style filenames (`<title> YYYY.MM.DD - HH.MM.SS`) get TMDB-searched anyway. Most users leave this off; enable only when you know your capture archive's filenames *do* contain real titles.

**Response:**
```json
{
  "library_id": "uuid",
  "matched": 42,        // files in the library with tmdb_id IS NULL
  "enriched": 17,       // files actually updated (got a TMDB hit + DB write)
  "skipped_dvr": 5      // files skipped by the DVR-filename heuristic
}
```

When `FLUXORA_TMDB_KEY` is not configured, returns zeros + a `detail` field instead of erroring:

```json
{
  "library_id": "uuid",
  "matched": 0, "enriched": 0, "skipped_dvr": 0,
  "detail": "TMDB API key not configured"
}
```

**Errors:** `404` library not found · `500` rescan failed (TMDB outage / DB error)

---

### `GET /api/v1/stream/sessions`
**Description:** List all currently active stream sessions (no `ended_at`). Admin view for the Desktop Control Panel.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Response:**
```json
[
  {
    "id": "uuid",
    "file_id": "uuid",
    "client_id": "uuid",
    "started_at": "2026-05-01T10:00:00+00:00",
    "ended_at": null,
    "connection_type": "lan",
    "bytes_transferred": 0,
    "progress_sec": 120.5
  }
]
```

---

### `POST /api/v1/stream/start/{file_id}`
**Description:** Spawn an FFmpeg HLS process for a file and return the playlist URL.  Server picks one of two pipelines automatically based on the source's video codec (recorded in `media_files.codec_name` per migration 016, lazy-probed at stream-start for files that pre-date that migration):

- **Stream-copy** when source is `h264` (mpegts segments) or `hevc` (fmp4 segments) — FFmpeg just remuxes, dropping CPU usage by ~95% versus a full transcode. **Plan 21 (2026-05-12):** audio is also stream-copied when the source audio codec is in `{aac, ac3, eac3, opus, flac}` and HDR tonemap is inactive; non-AAC audio stream-copy forces the session to fmp4 segments. Audio is re-encoded to AAC 256 kb/s (bumped from 128 kb/s in plan 21) with source channel count preserved when stream-copy is not applicable.
- **Full transcode** for everything else — applies the operator's configured `transcoding_encoder` / `preset` / `crf` from `user_settings`.

The decision is invisible to the client — the response shape is identical for both paths. The server log records which pipeline ran (`mode=stream-copy(h264/mpegts)` / `stream-copy(hevc/fmp4)` / `transcode(libx264)`).

**Query params:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `tonemap` | `bool` | `false` | When `true` and the source has an HDR format (HDR10 / HLG / DolbyVision per `media_files.hdr_format`), the server forces transcode mode and applies a zscale + Hable tonemap filter chain to convert BT.2020 PQ → BT.709 SDR.  No-op for SDR sources — the flag is accepted but `tonemapped` in the response will be `false`.  Tonemap forces CPU-side decode (drops the GPU input pipeline) because the `zscale` and `tonemap` filters cannot consume CUDA frames. |
| `seek_sec` | `float` | `null` | Optional starting source-time in seconds.  When omitted, the server falls back to the file's `last_progress_sec` (resume-point).  Validated `≥ 0` and `< file duration` server-side — both validation failures return **400 Bad Request** (not 422) with a `detail` field naming the violation.  The server snaps the requested seek to the previous segment boundary (`floor(seek_sec / hls_time) * hls_time`) so segment numbering aligns with the encoded output; the snapped value is echoed back as `applied_seek_sec` so the mobile client can render source-time on the scrubber.  Streaming pipeline plan §16 M1. |

**Auth:** Bearer token required.  
**Rate limit:** 10/minute per client IP — stream-start is FFmpeg-spawn-heavy; the limiter prevents an over-eager retry loop or rogue caller from pinning the encoder pool.  
**Status:** ✅ Implemented

**Response:** `201 Created`
```json
{
  "session_id": "uuid",
  "file_id": "uuid",
  "playlist_url": "http://192.168.1.10:8000/api/v1/hls/uuid/playlist.m3u8",
  "resume_sec": 0.0,
  "hdr_format": "HDR10",
  "tonemapped": false,
  "applied_seek_sec": 0.0
}
```

| Field | Type | Notes |
|-------|------|-------|
| `session_id` | `string` | UUID for subsequent progress / stop calls |
| `file_id` | `string` | Echo of the request path param |
| `playlist_url` | `string` | HLS playlist URL to open in the player |
| `resume_sec` | `float` | Playback position to seek to on open (0.0 = start) |
| `hdr_format` | `string \| null` | Source HDR format: `"HDR10"`, `"HLG"`, `"DolbyVision"`, or `null` for SDR.  Drives the player's HDR badge and tonemap toggle visibility. |
| `tonemapped` | `bool` | `true` when the server is actively tonemapping HDR → SDR for this session.  Echoes `tonemap && hdr_format != null`. |
| `applied_seek_sec` | `float` | Segment-snapped source-time the encoder actually started at (= `floor((seek_sec or last_progress_sec) / hls_time) * hls_time`).  The client adds this to libmpv's playlist-local position to render source-time on the scrubber after a seek-restart.  `0.0` for fresh-start sessions.  Streaming pipeline plan §16 scrubber-offset patch. |

**Errors:** `400` `seek_sec` negative or `≥ file duration` · `404` file not found · `429` concurrency limit reached or rate-limit (10/min per IP) · `503` FFmpeg failed (the response body now carries the first FFmpeg stderr line so the operator notification can surface the real reason — e.g. `"No NVENC capable devices found"`, not a generic "FFmpeg failed")

---

### `GET /api/v1/stream/{session_id}`
**Description:** Get stream session details.  
**Auth:** Bearer token required.  
**Status:** ✅ Implemented

**Response:**
```json
{
  "id": "uuid",
  "file_id": "uuid",
  "client_id": "uuid",
  "started_at": "2026-04-27T10:00:00+00:00",
  "ended_at": null,
  "connection_type": "lan",
  "bytes_transferred": 0,
  "progress_sec": 0.0
}
```

---

### `PATCH /api/v1/stream/{session_id}/progress`
**Description:** Record the client's current playback position. Persists to both `stream_sessions.progress_sec` and `media_files.last_progress_sec` for resume support.  
**Auth:** Bearer token required (must own the session).  
**Status:** ✅ Implemented

**Request:**
```json
{ "progress_sec": 342.5 }
```

**Response:** `204 No Content`  
**Errors:** `403` not your session · `404` session not found

---

### `POST /api/v1/stream/{session_id}/seek`
**Description:** Re-spawn the active FFmpeg from a non-zero timestamp.  Required because the original architecture only encodes from `t=0`; the static VOD playlist + 5 s segment-wait absorb forward seeks within seconds of the encoded boundary, but a far-ahead seek lands in territory FFmpeg has not produced and the player 404s.  This endpoint kills the active FFmpeg, wipes produced segments, and re-spawns with `-ss <seek_sec>` + `-start_number <K>` (where `K = floor(seek_sec / hls_time)`).  The server rewrites `playlist.m3u8` in place with `#EXT-X-MEDIA-SEQUENCE:<K>`, `#EXT-X-DISCONTINUITY-SEQUENCE` bumped per restart, and `#EXT-X-DISCONTINUITY` before the first listed segment.  
**Auth:** Bearer token required (must own the session).  
**Rate limit:** 30/min per IP (a runaway scrubber can't melt the encoder).  
**Status:** ✅ Implemented

**Query params:**
- `seek_sec` (float, required, ≥ 0) — the wall-clock second within the source to seek to. Aligned to a segment boundary internally so the segment numbering stays consistent with the rewritten playlist.
- `tonemap` (bool, default `false`) — preserves session tonemap state across seeks. The client must forward whatever `tonemapped` value it received from `/start` (or the most-recently toggled value via the mobile overflow menu) so a seek doesn't silently revert tonemap to off.

**Response:** `200 OK`
```json
{ "applied_seek_sec": 287.0 }
```

| Field | Type | Notes |
|-------|------|-------|
| `applied_seek_sec` | `float` | Segment-snapped source-time the encoder actually re-spawned at (= `floor(seek_sec / hls_time) * hls_time`).  Mobile cubit stores this as `_playlistOffsetSec` so the scrubber renders source-time after the seek-restart, not playlist-local-time which would reset to 0 on each restart.  Streaming pipeline plan §16 scrubber-offset patch (was 204 No Content prior to 2026-05-08). |

The playlist URL itself is unchanged — only the *contents* of `playlist.m3u8` change.  Clients that have already loaded the playlist must re-open it on the same URL (for `media_kit` / `libmpv`, that means calling `Player.open(Media(url))` again).  The server cannot push a playlist refresh; this is by HLS-spec design.

**Errors:**
- `400` `seek_sec must be non-negative`
- `403` `Not your session`
- `404` `Session not found` (unknown id, or session has ended_at set)
- `404` `Source file no longer exists` (file deleted between start and this seek)
- `429` rate-limit (above 30/min per IP)
- `503` `Seek restart failed: <FFmpeg stderr first line>` (FFmpeg failed to spawn, e.g. tonemap timeout)

**Concurrent calls:** an in-process `asyncio.Lock` per session serialises restart sequences.  Two POSTs in flight will execute one-at-a-time; the second observes the first's post-state and re-spawns from the second `seek_sec`.  The end state matches "only the second seek took effect", which is what the user expects from a debounced seek-bar drag.

---

### `DELETE /api/v1/stream/{session_id}`
**Description:** Stop a stream session, kill the FFmpeg process, and delete HLS segments.  
**Auth:** Bearer token required (must own the session); localhost callers can stop any session.  
**Status:** ✅ Implemented

**Response:** `204 No Content`  
**Errors:** `403` not your session · `404` session not found

---

### `GET /api/v1/hls/{session_id}/{filename}`
**Description:** Serve a single file from the HLS session directory — the playlist, an mpegts segment (stream-copy of h264 sources), an fmp4 segment + init segment (stream-copy of hevc sources or transcode output), or the rewritten playlist after a seek-restart.  Backed by one route handler in `apps/server/routers/stream.py::serve_hls` that resolves `filename` against `settings.hls_tmp_path / session_id`, with a path-traversal guard rejecting `..`, `/`, `\\`.  Excluded from the OpenAPI schema (`include_in_schema=False`) because the path shape is FFmpeg-implementation-defined and not part of the public v1 contract.  
**Auth:** Bearer token required + caller must own the session (`stream_sessions.client_id == me`); cross-client hijacking returns 403.  Localhost is NOT a shortcut here — the desktop CP doesn't consume HLS, so the bearer-only path is enough.  
**Status:** ✅ Implemented

**Content-Type by filename suffix:**

| Suffix | Content-Type | Used for |
|--------|--------------|----------|
| `.m3u8` | `application/vnd.apple.mpegurl` | The playlist itself |
| `.ts` | `video/MP2T` | mpegts segments (stream-copy of h264 sources) |
| `.m4s` / `.mp4` | `video/mp4` | fmp4 segments + the `init.mp4` initialization segment.  Mis-typing `init.mp4` as `application/octet-stream` makes media_kit / Safari refuse to parse the moov, which silently kills playback — the explicit branch in the route guards against that regression. |

**Notes:**
- When a filename starting with `seg` or equal to `init.mp4` doesn't exist on disk yet, the route waits up to 2 s in 100 ms slices for FFmpeg to produce it (worker-pinning budget tightened from 5 s → 2 s on 2026-05-08, streaming pipeline plan §4.3).  This bridges the gap between a player-side seek and FFmpeg's first written segment when the static VOD playlist lists segments faster than the encoder can produce them.  Tonemap restarts (≥10 s gap) rely on the mobile player's `_SeekingOverlay` + media_kit's 404-retry loop instead.
- Path traversal: `..`, `/`, `\\` in the filename → 400.  Resolved path outside the session dir → 403.
- Segment that genuinely never appears (encode failed / file ended early) → 404 after the retry budget elapses.

**Errors:** `400` invalid filename (path-traversal characters) · `403` not your session / resolved path outside session dir · `404` session not found / segment not found

---

### `WebSocket /api/v1/ws/stats`
**Description:** Live system-stats stream — same payload as `GET /api/v1/info/stats`, pushed every 1.1 seconds. Consumed by the desktop control panel's sidebar / status bar / sparklines.  
**Auth:** Localhost connections (desktop control panel running on the server machine) skip the auth handshake. Non-localhost connections must complete the same `{"type":"auth","token":"<bearer>"}` handshake as `/status`.  
**Status:** ✅ Implemented

Each connection gets its own network-rate baseline — multiple subscribers do not interfere with each other's rate calculations.

**Frame format:**
```json
{ "type": "stats", "data": { /* same shape as /info/stats */ } }
```

---

### `WebSocket /api/v1/ws/status`
**Description:** Real-time stream-status channel — token auth, ping/pong keepalive, progress tracking.  
**Status:** ✅ Implemented

**Handshake:**
```
Client connects → sends auth message → server replies auth_ok
```

```json
// Client → Server (first message, within 10 s)
{ "type": "auth", "token": "<bearer>" }

// Server → Client (on success)
{ "type": "auth_ok", "client_id": "uuid" }
```

**During session:**
```json
// Server → Client every 30 s
{ "type": "ping" }

// Client → Server (must reply within 10 s or connection is closed)
{ "type": "pong" }

// Client → Server (optional — updates progress_sec in DB)
{ "type": "progress", "session_id": "uuid", "progress_sec": 342.5 }
```

---

### `WebSocket /api/v1/ws/signal`
**Description:** WebRTC signaling channel — exchanges SDP offer/answer and ICE candidates so that the mobile client and server can establish a direct peer-to-peer WebRTC connection for internet streaming.  
**Status:** ✅ Implemented

**Handshake (identical to `/ws/status`):**
```json
// Client → Server (first message, within 10 s)
{ "type": "auth", "token": "<bearer>" }

// Server → Client (on success)
{ "type": "auth_ok", "client_id": "uuid" }
```

**Signaling messages:**
```json
// Client → Server (SDP offer)
{ "type": "offer", "sdp": "<SDP string>" }

// Server → Client (SDP answer)
{ "type": "answer", "sdp": "<SDP string>" }

// ICE candidates (both directions)
{ "type": "ice-candidate", "candidate": "<candidate line>",
  "sdpMid": "<mid>", "sdpMLineIndex": <index> }
```

**Error replies:**
```json
{ "type": "error", "code": "<code>", "detail": "<message>" }
```
| Code | Cause |
|------|-------|
| `invalid_json` | Message body is not valid JSON |
| `missing_sdp` | `offer` message has no `sdp` field |
| `offer_failed` | Server-side `RTCPeerConnection` error |
| `unknown_type` | Unrecognised message type |

---

### `GET /api/v1/settings`
**Description:** Return the current server settings.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Response:**
```json
{
  "server_name": "My Fluxora Server",
  "subscription_tier": "plus",
  "max_concurrent_streams": 3,
  "transcoding_enabled": true,
  "license_key": null,
  "license_status": "none",
  "license_tier": null,
  "transcoding_encoder": "libx264",
  "transcoding_preset": "veryfast",
  "transcoding_crf": 23,
  "transcoding_hwaccel_device": null,
  "transcoding_chain": null,
  "language": "en",
  "auto_start_on_boot": false,
  "auto_restart_on_crash": true,
  "minimize_to_system_tray": true,
  "theme_accent": null,
  "default_library_view": "grid",
  "scan_libraries_on_startup": true,
  "generate_thumbnails": true,
  "preferred_mode": "auto",
  "enable_mdns": true,
  "enable_webrtc": true,
  "relay_server_url": null,
  "default_quality": "auto",
  "ai_segment_duration_seconds": 4,
  "enable_pairing_required": true,
  "session_timeout_minutes": 60,
  "enable_log_export": true,
  "custom_server_url": null
}
```

`license_status` enumerates `none` / `valid` / `expired` / `invalid` / `no_secret`.  `license_tier` is the tier encoded in the key (when valid or `no_secret`), else `null`.  `transcoding_hwaccel_device` is the optional VAAPI render-node path (Linux only; null = auto-detect `/dev/dri/renderD128`).

---

### `PATCH /api/v1/settings`
**Description:** Update one or more server settings. Changing `tier` automatically adjusts `max_concurrent_streams` to match the tier limit. Only fields explicitly passed in the request body are written to the DB — omitted fields are unchanged.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Request (all fields optional):**
```json
{
  "server_name": "My Fluxora Server",
  "tier": "plus",
  "license_key": "FLUXORA-PLUS-20270429-CAFE-A1B2C3D4",
  "transcoding_enabled": true,
  "transcoding_encoder": "h264_nvenc",
  "transcoding_preset": "fast",
  "transcoding_crf": 20,
  "transcoding_hwaccel_device": "/dev/dri/renderD128",
  "transcoding_chain": ["h264_nvenc", "h264_qsv", "libx264"],
  "language": "en",
  "auto_start_on_boot": false,
  "auto_restart_on_crash": true,
  "minimize_to_system_tray": true,
  "theme_accent": null,
  "default_library_view": "grid",
  "scan_libraries_on_startup": true,
  "generate_thumbnails": true,
  "preferred_mode": "auto",
  "enable_mdns": true,
  "enable_webrtc": true,
  "relay_server_url": null,
  "default_quality": "auto",
  "ai_segment_duration_seconds": 4,
  "enable_pairing_required": true,
  "session_timeout_minutes": 60,
  "enable_log_export": true,
  "custom_server_url": null
}
```

Changing `transcoding_encoder` or `transcoding_hwaccel_device` triggers a background encoder self-test re-run after the PATCH commits (so the operator sees an updated `encoder_test_passed` / `encoder_test_error` on the next `/transcoding/status` poll without bouncing the server).  Every successful PATCH also writes a `settings.change` activity event with the field-name list in `payload.fields`; field *values* are never logged so a license key or custom URL can't leak via the audit feed.

**Field constraints (Pydantic-enforced — invalid values return 422):**

| Field | Allowed values |
|-------|----------------|
| `license_key` | `FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>` — exactly 5 dash-separated segments |
| `transcoding_encoder` | `libx264` · `libx265` · `h264_nvenc` · `hevc_nvenc` · `h264_qsv` · `hevc_qsv` · `h264_vaapi` · `hevc_vaapi` · `h264_videotoolbox` · `hevc_videotoolbox` |
| `transcoding_preset` | `ultrafast` · `superfast` · `veryfast` · `faster` · `fast` · `medium` · `slow` · `slower` · `veryslow` |
| `transcoding_crf` | Integer in `[0, 51]` (0 = lossless, 23 = default, 51 = worst quality) |
| `default_library_view` | `grid` · `list` |
| `preferred_mode` | `auto` · `lan` · `webrtc` |
| `default_quality` | `auto` · `4k` · `1080p` · `720p` · `480p` |
| `session_timeout_minutes` | Integer in `[1, 1440]` (1 minute to 24 hours) |
| `ai_segment_duration_seconds` | Integer in `[1, 30]` |
| `transcoding_hwaccel_device` | Optional string; VAAPI render-node path on Linux (`/dev/dri/renderD128` etc.); `null` for auto-detect / non-Linux |
| `transcoding_chain` | Optional list of registry encoder names; empty list / `null` falls back to the default chain `[transcoding_encoder, "libx264"]`.  Validation lives in the service layer: unknown encoder name → 422; chain where every entry is identical → 422 |

**Tier values and stream limits:**

| Tier | Concurrent streams |
|------|-------------------|
| `free` | 1 |
| `plus` | 3 |
| `pro` | 10 |
| `ultimate` | 9999 (unlimited) |

**Response:** Same schema as `GET /api/v1/settings`.  
**Errors:** `422` invalid tier or blank server_name or constraint violation · `403` not from localhost

---

### `GET /api/v1/orders`
**Description:** List processed Polar orders with their generated license keys. Paginated. Intended for the Desktop Control Panel owner screen to forward keys to customers manually.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Query params:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | integer | `20` | Max orders per page; range `1..200` |
| `cursor` | integer | `0` | Zero-based row offset for the next page |

**Response:**
```json
{
  "orders": [
    {
      "order_id": "polar-order-uuid",
      "customer_email": "user@example.com",
      "tier": "plus",
      "license_key": "FLUXORA-PLUS-20270429-ABCD1234-<sig>",
      "processed_at": "2026-05-01T10:00:00Z"
    }
  ],
  "total": 1,
  "total_all": 1,
  "next_cursor": null
}
```

`next_cursor` is `null` when the last page has been reached. Pass it as the `cursor` param for the next request. `total_all` is the full count across all pages regardless of `limit`.

**Errors:** `403` not from localhost

---

### `GET /api/v1/orders/portal-url`
**Description:** Return the Polar customer-portal URL for the current operator. The customer portal uses Polar's magic-link flow — the URL itself encodes no per-customer session token; Polar emails a link after the customer submits their address. Returns `404` when `FLUXORA_POLAR_PORTAL_URL` is unset.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Response:**
```json
{ "url": "https://polar.sh/fluxora/portal" }
```

**Errors:** `403` not from localhost · `404` env var `FLUXORA_POLAR_PORTAL_URL` not set

---

### `POST /api/v1/webhook/polar`
**Description:** Receives Polar payment webhook events and issues a signed Fluxora license key after a paid order.  
**Auth:** Public endpoint, but every request must pass Polar Standard Webhooks signature validation.  
**Status:** ✅ Implemented

**Required headers:**
| Header | Description |
|--------|-------------|
| `webhook-id` | Polar delivery ID; included in the signed payload |
| `webhook-timestamp` | Unix timestamp; rejected outside the replay window |
| `webhook-signature` | Standard Webhooks signature list, e.g. `v1,<base64>` |

**Handled events:**
| Event | Behavior |
|-------|----------|
| `order.paid` | Generate and store a license key if the order was not processed before |
| `order.created` | Generate only if the payload is already marked paid; unpaid orders are skipped |
| Any other event | Return `200` with `status: "ignored"` |

**Response:**
```json
{
  "status": "processed",
  "event": "order.paid",
  "issued": true
}
```

**Notes:**
- `POLAR_WEBHOOK_SECRET` must be configured or the endpoint returns `501`.
- Invalid signatures return `403`; signed invalid JSON returns `400`.
- Duplicate paid orders return `200` with `status: "skipped"` to avoid retry loops.
- License keys are stored server-side and are not logged or returned in webhook responses.

---

---

### `GET /api/v1/groups`
**Description:** List all groups with their member counts and restrictions.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:**
```json
[
  {
    "id": "uuid",
    "name": "Kids",
    "description": "Children's profiles — PG only",
    "status": "active",
    "created_at": "2026-05-01T10:00:00+00:00",
    "updated_at": "2026-05-01T10:00:00+00:00",
    "member_count": 2,
    "restrictions": {
      "allowed_libraries": ["uuid-library-1"],
      "bandwidth_cap_mbps": null,
      "time_window": {"start_h": 15, "end_h": 21, "days": [0,1,2,3,4,5,6]},
      "max_rating": "PG"
    },

    "is_public": false,
    "requires_pin": false,
    "pin_mode": "session",
    "icon": null,
    "color": null,
    "max_concurrent_streams": null
  }
]
```

**v2 (content-spaces) fields** — added by migration 025 (2026-05-07).  Older clients that pre-date the migration parse these as defaulted nulls and continue to function.

| Field | Type | Meaning |
|---|---|---|
| `is_public` | bool | True for the auto-managed Public group (id=`'public'`).  Exactly one row may carry this — enforced by a UNIQUE partial index. |
| `requires_pin` | bool | True if a PIN must be entered before this group's libraries become visible to a member. |
| `pin_mode` | `'session'` \| `'per-entry'` | How long a PIN grant lasts: `session` = 12 h, `per-entry` = 5 min (refreshes on every navigation; for adult / sensitive content). |
| `pin_model` | `'shared'` \| `'per-client'` | M8 — `shared` = one PIN per group, every member uses the same secret.  `per-client` = each member device enrolls its own PIN (compromise blast radius is one device).  Default `shared`. |
| `icon` | string? | Operator-set icon key (`'home'`, `'kids'`, `'lock'`, …); v2 Tier-2 visual identity. |
| `color` | string? | Operator-set hex color (`'#A855F7'`); v2 Tier-2 visual identity. |
| `max_concurrent_streams` | int? | Per-group concurrent stream cap (v2 Tier-2 enforcement); NULL = unlimited. |

**Public group semantics:** every approved client is auto-added to the Public group on `auth_service.approve_client`.  Public cannot be deleted (the route returns 400).  `allowed_libraries` semantic is **additive** in v2 — multi-group visibility is the union of every group's `allowed_libraries`, not the v1 intersection.

---

### `POST /api/v1/groups`
**Description:** Create a new group. Status defaults to `active`.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Request:**
```json
{
  "name": "Kids",
  "description": "Optional description",
  "restrictions": {
    "allowed_libraries": ["uuid-library-1"],
    "bandwidth_cap_mbps": null,
    "time_window": {"start_h": 15, "end_h": 21, "days": [0,1,2,3,4,5,6]},
    "max_rating": "PG"
  },

  "pin": "8472",
  "pin_mode": "session",
  "icon": "kids",
  "color": "#22C55E",
  "max_concurrent_streams": 2
}
```

`restrictions` is optional — omit it or pass `null` to create a group with no restrictions. All restriction fields default to `null` (no restriction of that kind).

**v2 (content-spaces) fields** — all optional.  When `pin` is supplied, the server stores `HMAC-SHA256(pin, settings.pin_hmac_key)` in `pin_hash` and sets `requires_pin = true`.  PIN must be 4-8 numeric digits and not in the obvious-PIN blocklist (`0000`, `1234`, `1111`, …) — server returns 400 with the violation reason if it isn't.  `pin_mode` defaults to `'session'`.

**M8 — `pin_model`** controls whether the group has one shared PIN or per-client enrollment.  When `pin_model='per-client'`, the request must NOT include `pin` — per-client groups have no shared secret at create time; each member device enrolls its own PIN via `/enroll`.  Server enforces this with a 400 if both are supplied.

**Response:** `201 Created` — `GroupResponse` (same schema as list item above).

---

### `GET /api/v1/groups/{id}`
**Description:** Get a single group by ID.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** `GroupResponse` (same schema as list item).  
**Errors:** `404` group not found

---

### `PATCH /api/v1/groups/{id}`
**Description:** Update a group's name, description, status, and/or restrictions. All fields are optional.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Request (all fields optional):**
```json
{
  "name": "Kids (updated)",
  "description": "New description",
  "status": "inactive",
  "restrictions": {
    "allowed_libraries": null,
    "bandwidth_cap_mbps": 10,
    "time_window": null,
    "max_rating": null
  },

  "pin": "8472",
  "pin_mode": "per-entry",
  "icon": "kids",
  "color": "#22C55E",
  "max_concurrent_streams": 2
}
```

**`pin` semantic** (v2):

| Value | Effect |
|---|---|
| `null` (key omitted) | Leave the PIN unchanged. |
| `""` (empty string) | Remove the PIN; `requires_pin` flips to `false` and every existing grant for the group is deleted. |
| `"<4-8 digits>"` | Set / change the PIN.  Existing grants are deleted — every member device must re-enter on next access.  Strength-validated against the obvious-PIN blocklist; 400 on rejection. |

`pin_mode` only takes effect when the group ends up with a PIN; passing it without `pin` for a non-gated group is a no-op.  Public group (`id='public'`) rejects `requires_pin` flips and `is_public` mutations (returns 400).

**`pin_model` semantic on PATCH (M8):**

| `pin_model` value | Effect |
|---|---|
| `null` (key omitted) | Leave mode unchanged. |
| `'shared'` | Switch to shared mode.  **`pin` must be supplied in the same call** — otherwise the group ends up gated with no shared secret to enter.  Server rejects with 400 if missing.  All per-client enrollment rows are deleted; existing grants kept (members aren't kicked off mid-session). |
| `'per-client'` | Switch to per-client mode.  Shared `pin_hash` cleared; existing grants kept; on grant expiry each member is prompted to enroll their own PIN via `/enroll`. |

**Response:** Updated `GroupResponse`.  
**Errors:** `400` invalid PIN / cannot mutate Public · `404` group not found · `403` not from localhost

---

### `DELETE /api/v1/groups/{id}`
**Description:** Delete a group. `ON DELETE CASCADE` removes its member rows and restrictions row automatically.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Response:** `204 No Content`  
**Errors:** `404` group not found · `403` not from localhost

---

### `GET /api/v1/groups/{id}/members`
**Description:** List all members of a group. Each item includes the client fields plus `added_at`.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Query parameters:**

| Param | Effect |
|---|---|
| `include=pin_state` | M3 of [`14_groups_management_page.md`](../10_planning/14_groups_management_page.md).  Augments each row with `enrollment_state`, `has_active_grant`, `grant_expires_at`, `recent_failed_attempts` so the desktop Members tab can render PIN status badges without N+1 fanout.  Older callers that don't pass `include` get the v1 shape unchanged. |

**Response (default shape):**
```json
[
  {
    "id": "uuid",
    "name": "Pixel 8 Pro",
    "platform": "android",
    "last_seen": "2026-05-01T12:00:00",
    "is_trusted": true,
    "status": "approved",
    "added_at": "2026-05-01T10:00:00+00:00"
  }
]
```

**Response (`?include=pin_state`):**
```json
[
  {
    "id": "uuid",
    "name": "Pixel 8 Pro",
    "platform": "android",
    "last_seen": "2026-05-01T12:00:00",
    "is_trusted": true,
    "status": "approved",
    "added_at": "2026-05-01T10:00:00+00:00",
    "enrollment_state": "enrolled",
    "has_active_grant": true,
    "grant_expires_at": "2026-05-08T10:00:00+00:00",
    "recent_failed_attempts": 0
  }
]
```

| Pin-state field | Meaning |
|---|---|
| `enrollment_state` | `'not_required'` (shared mode or no-PIN group) / `'enrolled'` (per-client mode + has enrollment row) / `'not_enrolled'` (per-client mode + awaiting first-time enrollment). |
| `has_active_grant` | True iff a non-expired `group_pin_grants` row exists for this `(group, client)`. |
| `grant_expires_at` | ISO timestamp or null. |
| `recent_failed_attempts` | Failed `/enter` + `/enroll/change` attempts in the last 60 s — drives the "Locked out" badge when ≥5. |

**Errors:** `404` group not found

---

### `POST /api/v1/groups/{id}/members`
**Description:** Add a client to a group. Idempotent — adding an already-present client succeeds silently.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Request:**
```json
{ "client_id": "uuid" }
```

**Response:** `204 No Content`  
**Errors:** `404` group or client not found · `403` not from localhost

---

### `DELETE /api/v1/groups/{id}/members/{client_id}`
**Description:** Remove a client from a group.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Response:** `204 No Content`  
**Errors:** `404` group member not found · `403` not from localhost

---

### `PATCH /api/v1/groups/{id}/members/{client_id}`
**Description:** Update per-member overrides on a group membership row (M5 of [`docs/10_planning/14_groups_management_page.md`](../10_planning/14_groups_management_page.md)).  Currently surfaces `time_window_override` only — operator can extend or contract a member's effective window without affecting other members of the same group ("older kid stays up later").  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented (2026-05-07)

**Request (all fields optional):**
```json
{
  "time_window_override": {
    "start_h": 18,
    "end_h": 23,
    "days": [0, 1, 2, 3, 4, 5, 6]
  }
}
```

**Sentinel for "clear the override":** pass `{"start_h": 0, "end_h": 0, "days": []}` and the server treats it as `UPDATE … SET time_window_override = NULL`.  This keeps the JSON shape consistent across set/clear paths instead of mixing in a magic null.

**Response:** `204 No Content`  
**Errors:** `404` group member not found · `403` not from localhost

---

### `GET /api/v1/auth/clients/me/visible-libraries`
**Description:** Mobile-side "what does my client see right now" — same shape the desktop View As tab returns, scoped to the bearer-identified calling client.  Powers the M6 Profile-screen group cards (Locked / Unlocked / Visible Libraries).  
**Auth:** Bearer token only.  
**Status:** ✅ Implemented (2026-05-07)

**Response shape:** identical to `GET /clients/{id}/visible-libraries` below, with `client_id` set to the calling client's id.

**Errors:** `401` invalid / missing token

---

### `GET /api/v1/auth/clients/{client_id}/visible-libraries`
**Description:** Operator "View as" debug surface — returns the `VisibleLibraries` snapshot for a target client right now (M5 of `14_groups_management_page.md`, §M7 Tier-2 of `13_groups_v2_content_spaces.md`).  Renders the kid's library list as the kid would see it, with provenance ("granted by Public") + locked-state buckets so the operator understands *why* a library is or isn't visible.  
**Auth:** Localhost only — `require_local_caller`.  Reveals operator-only access-control state across the operator's whole client base; not for paired-client consumption.  
**Status:** ✅ Implemented (2026-05-07)

**Response:**
```json
{
  "client_id": "uuid",
  "library_ids": ["lib-movies", "lib-songs"],
  "groups_contributing": {
    "public": ["lib-movies", "lib-songs"],
    "kids": ["lib-cartoons"]
  },
  "pin_locked_groups": ["adults"],
  "enrollment_required_groups": [],
  "time_locked_groups": ["bedtime-only"],
  "groups": [
    {
      "id": "public",
      "name": "Public",
      "icon": "public",
      "color": "#94A3B8",
      "is_public": true,
      "is_active": true,
      "requires_pin": false,
      "pin_model": "shared",
      "pin_mode": "session",
      "is_enrolled": false,
      "in_time_window": true,
      "is_unlocked": true,
      "grant_expires_at": null
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `library_ids` | Sorted set of library ids visible to the client right now. |
| `groups_contributing` | Map of group id → libraries that group granted.  Drives the "← granted by Public" provenance captions on the desktop View As tab. |
| `pin_locked_groups` | Groups the client is a member of but hasn't unlocked.  Mobile would route to the PIN entry surface; desktop View As just labels the row. |
| `enrollment_required_groups` | M8 — per-client groups awaiting first-time enrollment. |
| `time_locked_groups` | Groups outside their time window right now. |
| `groups` | Flat list of every group the client is a member of with full per-group metadata.  M6 mobile UX uses this to render the Locked / Unlocked / Visible Libraries Profile cards from one round-trip — no fanout to `/groups` + `N × /grant-status`.  Each item carries `id`, `name`, `icon`, `color`, `is_public`, `is_active`, `requires_pin`, `pin_model`, `pin_mode`, `is_enrolled`, `in_time_window`, `is_unlocked`, `grant_expires_at`. |

**Honesty caveats:** doesn't simulate "what would the kid see if I added them to Family right now" — only current membership.  Hypotheticals are out of scope; operator manipulates membership directly to test.  PIN-gated groups appear in `pin_locked_groups` — if the kid hasn't unlocked Adults, View As doesn't show Adults libraries.

**Errors:** `404` client not found · `403` not from localhost

---

### `POST /api/v1/groups/{id}/enter`
**Description:** Submit a PIN to unlock a PIN-gated group for the calling client.  On success the server inserts a row in `group_pin_grants` valid for 12 h (`pin_mode='session'`) or 5 min (`'per-entry'`); the group's `allowed_libraries` then appear in `get_visible_libraries(client_id)` until the grant expires.  
**Auth:** Bearer token (calling client's grant) **or** localhost (master override; PIN compare skipped — see notes).  
**Status:** ✅ Implemented (v2 M4, 2026-05-07)

**Request:**
```json
{ "pin": "8472" }
```

**Response (200):**
```json
{
  "expires_at": "2026-05-08T10:00:00+00:00",
  "pin_mode": "session"
}
```

The route returns the `_PinEnterResponse` Pydantic shape directly — `group_id` is NOT echoed in the body since it's already in the URL.  `pin_mode` is fetched from the row post-grant so the mobile UI can size the "this unlock lasts 12 hours" / "5 minutes" caption correctly.

**Errors:**
- `400` group is not PIN-gated (`requires_pin = false`) · `400` per-client mode + no enrollment yet (caller should hit `/enroll` first)
- `401` wrong PIN — `detail` is `"Incorrect PIN (N attempts remaining)"`
- `404` group not found
- `429` too many failed attempts — 5 fails / 60 s / `(client, group)` tuple triggers a 60 s lockout; `detail` is `"Too many failed PIN attempts — try again in a minute"`.  No `Retry-After` header is set; the lockout window is operator-fixed, not server-advertised.

**Master override:** the dedicated `POST /api/v1/groups/{id}/master-override?client_id=...` endpoint (below) is the operator-side recovery path; do not bypass on `/enter` itself.

---

### `DELETE /api/v1/groups/{id}/grant`
**Description:** Drop the calling client's PIN grant for a group ("Lock" action).  Idempotent — returns 204 even if no grant existed.  
**Auth:** Bearer token (drops own grant) **or** localhost (drops the grant for any client supplied via `?client_id=...`; master operator action).  
**Status:** ✅ Implemented (v2 M4, 2026-05-07)

**Response:** `204 No Content`  
**Errors:** `404` group not found

---

### `GET /api/v1/groups/{id}/grant-status`
**Description:** Check whether the calling client currently holds a valid PIN grant for the group.  Used by the mobile "Locked / Unlocked" surfaces on the Profile screen to seed initial state without prompting.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented (v2 M4, 2026-05-07)

**Response:**
```json
{
  "unlocked": true,
  "expires_at": "2026-05-08T10:00:00+00:00",
  "pin_model": "per-client",
  "enrollment_state": "enrolled"
}
```

When `unlocked = false`, `expires_at` is `null`.  `group_id` is NOT echoed (caller already has it in the URL); `pin_mode` is NOT included on this surface — read it from `GET /groups/{id}` if you need the session-vs-per-entry value.

**M8 fields** — let the mobile UI route to the right surface without a follow-up call:

| `enrollment_state` | Meaning |
|---|---|
| `'not_required'` | Shared mode (no per-client enrollment concept), or group isn't gated. |
| `'enrolled'` | Per-client mode + this client has an enrollment row.  Mobile shows the entry surface. |
| `'enrollment_required'` | Per-client mode + no enrollment yet.  Mobile shows the *enrollment* surface ("Set up a PIN") instead of the entry surface. |

**Errors:** `404` group not found

---

### `POST /api/v1/groups/{id}/enroll`
**Description:** First-time per-client PIN enrollment for a `pin_model='per-client'` group (M8).  Records the calling client's PIN and immediately issues a session-length grant (the user just typed it — no need to re-enter).  
**Auth:** Bearer token only.  
**Status:** ✅ Implemented (v2 M8, 2026-05-07)

**Request:** `{ "pin": "5283" }`  
**Response:** same shape as `/enter` — `{expires_at, pin_mode}` (no `group_id` in body; caller already has it in the URL).  
**Errors:**
- `400` strength rejection / not-pin-required / wrong mode (group is shared) / already-enrolled (use `/enroll/change`) / not-enrolled (use `/enter`)
- `403` calling client isn't a member of the group
- `404` group not found
- `409` PIN already enrolled — call `/enroll/change` instead

---

### `POST /api/v1/groups/{id}/enroll/change`
**Description:** Replace the calling client's per-client PIN.  Verifies `old_pin` against the brute-force rate limiter so this endpoint can't be used to guess the existing PIN.  
**Auth:** Bearer token only.  
**Status:** ✅ Implemented (v2 M8, 2026-05-07)

**Request:** `{ "old_pin": "5283", "new_pin": "9182" }`  
**Response:** `204 No Content` (existing grant carries — the user already authenticated successfully).  
**Errors:**
- `400` strength rejection on new_pin / wrong mode / not-enrolled
- `401` `old_pin` is wrong (with `attempts_remaining` in detail)
- `404` group not found
- `429` rate limited (5 fails / 60 s / `(client, group)` tuple)

---

### `DELETE /api/v1/groups/{id}/members/{client_id}/pin`
**Description:** Operator action — drop a member's per-client PIN enrollment so they re-enroll on next access.  Also drops any active grant for that member so visibility flips immediately.  Idempotent — clearing a non-existent enrollment returns 204.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented (v2 M8, 2026-05-07)

**Use case:** member's device suspected compromised; operator wants to invalidate just that one PIN without rotating the whole group's secret (which would force every member to re-enter).

**Response:** `204 No Content`  
**Errors:** `403` not from localhost

---

### `POST /api/v1/groups/{id}/grants/reset`
**Description:** Bulk-drop every active PIN grant for a group.  Operator-side "Reset all PINs" Danger Zone action for shared-mode groups (M7 follow-up of [`docs/10_planning/14_groups_management_page.md`](../10_planning/14_groups_management_page.md)).  Members re-enter the shared PIN on next access.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented (2026-05-07)

**Per-client mode:** this route only touches `group_pin_grants`, not `group_member_pins`.  For per-client mode the equivalent operation is `DELETE /groups/{id}/members/{cid}/pin` per member (the per-client recovery path); the desktop "Reset all PINs" action walks members + calls that endpoint sequentially.

**Response:** `200 OK` with `{"dropped": int}` — count of grants deleted (drives the desktop snackbar feedback).  Idempotent — calling on a group with no active grants returns `{"dropped": 0}`.  
**Errors:** `403` not from localhost · `404` group not found

**Audit:** when `dropped > 0`, emits one `group.pin.grants-reset` activity event with the count in `payload`.

---

### `POST /api/v1/groups/{id}/master-override?client_id={client_id}`
**Description:** Operator-side recovery — issue a 12 h grant for `client_id` on a PIN-gated group **without** supplying the PIN.  Used when the operator forgets the group PIN or when a member's device is locked out.  
**Auth:** Localhost only — `require_local_caller` (the desktop CP is the only legitimate caller; off-loopback callers get 403).  No bearer credential is ever accepted; the auth boundary is "is the caller running on the server box?"  
**Status:** ✅ Implemented (v2 M4, 2026-05-07)

**Why localhost-only and not a password:** there is **no master PIN or shared secret stored anywhere** that an attacker could exfiltrate.  The override authority is the network proximity to the server itself — physical access to the operator's box.  An attacker who already has localhost access to the machine running the database can bypass the entire access-control layer with `sqlite3` regardless; the override endpoint simply gives the desktop CP a clean recovery action without requiring the operator to drop to a SQL CLI.

**Response (200):** same shape as `/enter`.  
**Errors:** `400` group is not PIN-gated · `403` not from localhost · `404` group not found

**Audit:** every override writes a row to `group_pin_attempts` with `success=1` and an INFO-level server log line.  The desktop CP surfaces these in the operator activity feed (Tier-2 work).

---

### `GET /api/v1/profile`
**Description:** Return the operator profile stored in `user_settings`. Includes the computed `avatar_letter` field (not stored in DB).  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Response:**
```json
{
  "display_name": "Marshal",
  "email": "marshalgcom@gmail.com",
  "avatar_letter": "M",
  "avatar_path": null,
  "created_at": "2026-05-01T10:00:00Z",
  "last_login_at": null
}
```

**`avatar_letter` computation (server-side):**
1. First non-whitespace character of `display_name` (if set)
2. Else first character of `email` local-part (portion before `@`) if set
3. Else `'F'` (Fluxora fallback)

All fields except `avatar_letter` are nullable and will be `null` if not yet configured.

**Errors:** `403` not from localhost

---

### `PATCH /api/v1/profile`
**Description:** Update the operator profile fields. Pass a field to update it; pass `null` to leave it unchanged; pass `""` (empty string) to clear it.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

**Request (all fields optional):**
```json
{
  "display_name": "Marshal",
  "email": "marshalgcom@gmail.com"
}
```

**Field constraints (Pydantic-enforced — invalid values return 422):**

| Field | Constraint |
|-------|-----------|
| `display_name` | Optional string; max length enforced; `""` clears the field; `null` leaves unchanged |
| `email` | Optional string; max length enforced; `""` clears the field; `null` leaves unchanged |

> **Out of scope (v1):** `POST /api/v1/profile/password` (no operator-password concept in Fluxora's single-owner localhost model) and `POST /api/v1/profile/avatar` (multipart upload deferred until the desktop UI consumes it).

**Response:** `ProfileResponse` — same schema as `GET /api/v1/profile`, with updated values.  
**Errors:** `403` not from localhost · `422` field exceeds max length

---

---

### `GET /api/v1/notifications`
**Description:** List notifications. Returns the most recent 50 by default; pass `unread=true` to filter to unread-only, `limit=N` to override the page size.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Query params:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `unread` | boolean | `false` | If `true`, return only notifications where `read_at IS NULL` |
| `limit` | integer | `50` | Maximum number of notifications to return |

**Response:**
```json
[
  {
    "id": "uuid",
    "type": "warning",
    "category": "storage",
    "title": "Storage usage high",
    "message": "Library storage is above 90% capacity.",
    "related_kind": null,
    "related_id": null,
    "created_at": "2026-05-02T10:00:00Z",
    "read_at": null,
    "dismissed_at": null
  }
]
```

---

### `POST /api/v1/notifications/{id}/read`
**Description:** Mark a single notification as read. The service sets `read_at` to the current UTC timestamp and is idempotent — calling on an already-read row no-ops at the SQL layer.  Note: the route raises 404 when the row was *already* read or dismissed (the underlying `notification_service.mark_read` returns `False` on no-op rows, not just on missing ids), so a client that double-taps the same notification can see one 204 followed by a 404 — not a bug, just the no-op-as-404 contract.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** `204 No Content`  
**Errors:** `404` notification not found, already read, or already dismissed

---

### `POST /api/v1/notifications/read-all`
**Description:** Mark every unread notification as read in a single SQL `UPDATE`.  Used by the desktop notification bell's "Mark all read" action.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** `204 No Content`

---

### `DELETE /api/v1/notifications/{id}`
**Description:** Dismiss (soft-delete) a notification. Sets `dismissed_at` to the current UTC timestamp. Dismissed notifications are excluded from future `GET /notifications` responses.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** `204 No Content`  
**Errors:** `404` notification not found

---

### `WebSocket /api/v1/ws/notifications`
**Description:** Live notification stream. The server pushes a frame whenever a new notification is created (by any producer — pairing requests, license expiry, transcode failures, storage warnings). Each connected client gets its own asyncio queue (max 100 items). Slow consumers drop frames rather than blocking producers.  
**Auth:** Loopback connections skip auth (desktop control panel on the server machine). Non-loopback connections must send the same `{"type":"auth","token":"<bearer>"}` first-message handshake used by `/ws/stats`.  
**Status:** ✅ Implemented

**Frame format (server → client):**
```json
{
  "type": "notification",
  "data": {
    "id": "uuid",
    "type": "info",
    "category": "client",
    "title": "New pair request",
    "message": "Pixel 8 Pro is requesting to pair.",
    "related_kind": "client",
    "related_id": "client-uuid",
    "created_at": "2026-05-02T10:00:00Z",
    "read_at": null,
    "dismissed_at": null
  }
}
```

**Notification producers:**

| Producer | Category | Type | Trigger |
|----------|----------|------|---------|
| `auth_service.create_pair_request` | `client` | `info` | New device requests pairing; `related_id` = client UUID |
| `license_service.emit_license_expiry_warnings` | `license` | `error` (expired) or `warning` (within 30 days) | Called once at server startup after `init_db`; 1-day cooldown de-dupe |
| `routers/stream.py start_stream` (FFmpeg failure block) | `transcode` | `error` | FFmpeg process fails to start or crashes; `related_id` = session UUID |
| `library_service.get_storage_breakdown` | `storage` | `warning` | Storage usage exceeds 90%; 1-day cooldown de-dupe |

All emitter call-sites are wrapped in `try/except` with logging — a notification-write failure never breaks the underlying flow.

---

---

### `GET /api/v1/activity`
**Description:** List activity events (audit log). Returns the most recent events first. Used by the desktop Activity screen and the Dashboard "Recent Activity" widget (`?limit=4`).  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Query params:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | integer | `50` | Max number of events; `1..200` — values outside this range return `422` |
| `since` | string (ISO-8601) | `null` | Return only events strictly after this timestamp |
| `type` | string | `null` | Event-type prefix filter; e.g. `stream.` matches `stream.start` + `stream.end`; pass the full type for an exact match |

**Response:**
```json
[
  {
    "id": "uuid",
    "type": "stream.start",
    "actor_kind": "client",
    "actor_id": "client-uuid",
    "target_kind": "session",
    "target_id": "session-uuid",
    "summary": "My Phone started watching movie.mkv",
    "payload": {"file_id": "file-uuid", "connection_type": "lan"},
    "created_at": "2026-05-02T10:00:00Z"
  }
]
```

**Event types shipped in v1:**

| Type | Actor kind | Target kind | Trigger |
|------|-----------|------------|---------|
| `stream.start` | `client` | `session` | Client starts a stream session |
| `stream.end` | `client` | `session` | Stream session is stopped |
| `client.pair` | `client` | `client` | Device sends a pair request |
| `client.approve` | `operator` | `client` | Operator approves a client |
| `client.reject` | `operator` | `client` | Operator rejects a client |
| `client.revoke` | `operator` or `client` | `client` | Operator-driven revoke via `DELETE /auth/revoke/{id}` (`actor_kind=operator`) OR mobile self-revoke via `DELETE /auth/clients/me` (`actor_kind=client`) |
| `client.profile_updated` | `client` | `client` | Calling client renamed itself via `PATCH /auth/clients/me` |
| `library.scan` | `system` | `library` | Library scan adds 1+ files (no-op scans are not recorded) |
| `library.create` | `client` or `operator` | `library` | New library created via `POST /library` |
| `library.update` | `client` or `operator` | `library` | Existing library renamed / root_paths edited via `PATCH /library/{id}` |
| `library.delete` | `client` or `operator` | `library` | Library deleted via `DELETE /library/{id}` (file rows torched; on-disk files untouched per ADR-017) |
| `file.upload` | `client` or `operator` | `file` | Upload via `POST /files/upload` |
| `file.delete` | `client` or `operator` | `file` | Index-row delete via `DELETE /files/{id}` |
| `settings.change` | `operator` | `settings` | `PATCH /settings` succeeds; `payload.fields` lists field names changed (values redacted) |
| `group.pin.grants-reset` | `operator` | `group` | `POST /groups/{id}/grants/reset` drops ≥1 grant; `payload.dropped` carries the count |

All producer call-sites are wrapped in `try/except` with logging — an activity-write failure never breaks the underlying flow.

**Errors:** `422` limit out of bounds · `401` off-loopback caller without token

---

---

### `GET /api/v1/transcoding/status`
**Description:** Return live transcoding status — which encoder is active, which encoders are available on this machine, per-encoder load + GPU engine + self-test result, and the list of currently active transcode sessions with per-session metadata.
**Auth:** Localhost only — `require_local_caller`.
**Status:** ✅ Implemented

**Response:**
```json
{
  "active_encoder": "libx264",
  "available_encoders": ["libx264", "h264_nvenc"],
  "encoder_loads": [
    {
      "encoder": "libx264",
      "active_sessions": 1,
      "cpu_utilization_percent": 42.5,
      "gpu_utilization_percent": null,
      "vram_used_mb": null,
      "gpu_engine": null,
      "encoder_test_passed": true,
      "encoder_test_error": null,
      "encoder_test_suggestion": null,
      "encoder_tested_at": "2026-05-04T15:30:00+00:00"
    },
    {
      "encoder": "h264_qsv",
      "active_sessions": 0,
      "cpu_utilization_percent": null,
      "gpu_utilization_percent": null,
      "vram_used_mb": null,
      "gpu_engine": "qsv",
      "encoder_test_passed": false,
      "encoder_test_error": "Error creating a MFX session: -9.",
      "encoder_test_suggestion": "Update Intel Graphics driver to a oneVPL Runtime build (driver 31.x or newer).",
      "encoder_tested_at": "2026-05-04T15:30:00+00:00"
    }
  ],
  "active_sessions": [
    {
      "id": "session-uuid",
      "client_id": "client-uuid",
      "client_name": "Pixel 8 Pro",
      "media_title": "Inception",
      "input_codec": "h264",
      "output_codec": "h264",
      "fps": null,
      "speed_x": null,
      "progress": 342.5
    }
  ]
}
```

**Notes:**
- `available_encoders` is discovered by parsing `ffmpeg -encoders` output; result is cached for the server lifetime.
- `gpu_engine` is the underlying hardware backend (`cuda` / `qsv` / `vaapi` / `videotoolbox`); `null` for software encoders. Drives the desktop's CPU/GPU pill.
- `encoder_test_passed` is the result of the most recent `test_encoder()` self-test (~1 s of synthetic encode against `lavfi testsrc`). Software encoders always pass. `null` if no test has run yet.
- `encoder_test_error` carries the first non-empty stderr line (≤240 chars) from a failed self-test — drives the desktop's failed-encoder tooltip / modal so the operator knows *why* (missing driver vs. missing FFmpeg build feature vs. timeout).
- `encoder_test_suggestion` is the plain-language remediation produced by `transcoding_service.classify_encoder_failure(encoder, error)` when the failure matches one of the field-reported patterns (Intel old driver predating oneVPL → MFX session: -9; no Intel iGPU on this machine; NVENC GeForce 3-session cap). `null` when the failure isn't recognised — caller falls through to displaying the raw `encoder_test_error`. The same suggestion is also surfaced via a notification (`category=transcode`, `related_kind=encoder`, `related_id=<encoder>`) on every server startup that re-detects the failure (deduped on `dismissed_at IS NULL` so a restart loop doesn't spam).
- `encoder_tested_at` is the ISO-8601 UTC timestamp of the last self-test run; surfaces as "tested HH:MM" in the encoder availability panel.
- `gpu_utilization_percent` / `vram_used_mb` are populated only for the *active* encoder (per-vendor probe: `nvidia-smi` / `intel_gpu_top` / `radeontop` / `system_profiler`). `null` on non-active rows and on probe failure (best-effort).
- `fps` and `speed_x` on active sessions are v1 placeholders — `null` until real-time FFmpeg progress parsing lands.

**Errors:** `403` not from localhost

---

### `GET /api/v1/transcoding/advisor`
**Description:** Return a recommendation for the operator's current encoder choice. Pure function over current settings + detected encoders + last self-test results. Drives the desktop Settings → Streaming recommendation banner.
**Auth:** Localhost only — `require_local_caller`.
**Status:** ✅ Implemented

**Response:**
```json
{
  "recommended_encoder": "h264_nvenc",
  "reason_code": "cpu_fallback",
  "reason_text": "You're transcoding on CPU (libx264). NVIDIA NVENC is detected and tested — switch to h264_nvenc for ~10-30× faster transcoding.",
  "severity": "info"
}
```

**Reason codes:**
| Code | Meaning | Severity |
|------|---------|----------|
| `none` | Active encoder is fine; no banner. | `none` |
| `cpu_fallback` | Active is software, a tested-passing GPU encoder is available. | `info` |
| `failed_active` | Active encoder failed last self-test. `recommended_encoder` is the best tested-passing fallback (preferring same codec), or `null` if every encoder failed. | `warning` |
| `hevc_compat` | Active outputs HEVC (fmp4 segments). Older Roku / Chromecast 1st gen / pre-2017 smart TVs may stutter. Informational only — `recommended_encoder` is `null`. | `info` |

**Notes:**
- Untested encoders are never recommended — only encoders with `encoder_test_passed: true` qualify.
- Vendor preference for the GPU upgrade rule: NVIDIA → Intel → AMD → Apple.
- `reason_text` is operator-facing copy; the desktop renders it verbatim in the recommendation banner.

**Errors:** `403` not from localhost

---

### `GET /api/v1/transcoding/devices`
**Description:** Detected CPU + GPU inventory on the server host. Drives the desktop's "Detected Hardware" card and (later) the VAAPI device-path picker. Result is cached for the lifetime of the server process — hardware doesn't change at runtime, and probes are slow (~500 ms cold on Windows). Slice B of the GPU UX plan.
**Auth:** Localhost only — `require_local_caller`.
**Status:** ✅ Implemented

**Response:**
```json
{
  "cpus": [
    {"vendor": "Intel", "model": "Core i7-9750H @ 2.60GHz", "threads": 12}
  ],
  "gpus": [
    {
      "vendor": "intel",
      "model": "Intel(R) UHD Graphics 630",
      "vram_mb": 1024,
      "driver_version": "26.20.100.7262",
      "dev_path": null,
      "encoder_support": ["h264_qsv", "hevc_qsv"]
    },
    {
      "vendor": "nvidia",
      "model": "NVIDIA GeForce RTX 2060",
      "vram_mb": 6144,
      "driver_version": "596.36",
      "dev_path": null,
      "encoder_support": ["h264_nvenc", "hevc_nvenc"]
    }
  ]
}
```

**Per-platform probe commands:**
| OS | CPU | GPU |
|----|-----|-----|
| Linux | `/proc/cpuinfo` | `lspci -nn -d ::0300` + `nvidia-smi -L` + `/dev/dri/render*` |
| Windows | `wmic cpu get Name,NumberOfLogicalProcessors` | `wmic path Win32_VideoController` + `nvidia-smi --query-gpu=…` |
| macOS | `sysctl -n machdep.cpu.brand_string` | `system_profiler SPDisplaysDataType -json` |

**Notes:**
- All probes are best-effort. A missing tool / parse failure logs at WARNING and falls through to an empty list rather than raising.
- `vendor` is normalised to one of `nvidia` / `intel` / `amd` / `apple` / `unknown` from free-form vendor-or-model strings.
- `vram_mb` on Windows comes from `wmic path Win32_VideoController.AdapterRAM` which caps at ~4 GB on 32-bit builds; we supplement NVIDIA rows with `nvidia-smi`'s accurate VRAM total.
- `dev_path` is the Linux VAAPI render-node path (`/dev/dri/renderD128` etc.); always `null` on Windows / macOS.
- `encoder_support` is **registry-derived** (`encoder_registry.py` filtered by vendor + current `sys.platform`), not probed. Pair with `/transcoding/status`'s `available_encoders` to know what FFmpeg actually has.

**Errors:** `403` not from localhost

---

### `GET /api/v1/transcoding/fallback-history`
**Description:** Recent encoder routing decisions from `services/session_router.py`'s in-memory ring buffer (max 50 entries). Backs the desktop's "Recent encoder fallbacks" diagnostic panel — answers "why did N+1 fall through to libx264?" without making the operator dig through server logs. Slice C of the GPU UX plan.
**Auth:** Localhost only — `require_local_caller`.
**Status:** ✅ Implemented

**Response:**
```json
{
  "events": [
    {
      "timestamp": "2026-05-04T15:30:12.123456+00:00",
      "session_id": "session-uuid",
      "requested_encoder": "h264_nvenc",
      "actual_encoder": "h264_qsv",
      "reason": "gpu_session_cap_hit"
    }
  ]
}
```

**Reason values:**
| Reason | Meaning |
|--------|---------|
| `configured` | First chain entry was available; no fallback. |
| `gpu_session_cap_hit` | First entry was at its `concurrent_session_cap` (NVENC = 3 on consumer cards); fell to next entry. |
| `all_encoders_saturated` | Every entry in the chain was at cap; using the last entry anyway so FFmpeg can produce a clear error. |
| `encoder_unknown` | Every chain entry was a typo / unknown to the registry; using the default encoder. |

**Notes:**
- Ring buffer is **in-memory only**; resets on server restart. Historical analysis across restarts uses `stream_sessions.encoder_used` (migration 021).
- Newest events appear last in the response.
- The desktop panel only renders the last 5 entries — the buffer is sized for ~30 minutes of typical fallback churn.

**Errors:** `403` not from localhost

---

### `POST /api/v1/transcoding/benchmark`
**Description:** Run a synthetic FFmpeg encode through every detected encoder and return per-encoder fps / speed / bitrate / realtime-multiplier. Backs the desktop Encoder Settings → "Run Benchmark" button. Long-running by design (sequential per-encoder × ~5–10 s wall-clock each on hardware encoders, materially longer if libx264/libx265 is in the chain on a slow CPU). The endpoint enforces a 35 s ceiling per encoder so the call has a hard upper bound regardless of how slow the hardware is. Clients should set a receive timeout of at least 90 s (the desktop uses 3 min).
**Auth:** Localhost only — `require_local_caller`.
**Status:** ✅ Implemented (2026-05-07)

**Request body** (optional — empty body uses the defaults):
```json
{
  "duration_sec": 8,
  "fps": 30
}
```

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `duration_sec` | int? | 2–20 (Pydantic-validated; 422 outside) | Source clip length per encoder. Server-side `clamp_duration` also applies the [2, 20] floor/ceiling defensively. Defaults to 8 s. |
| `fps` | int? | 24–60 (Pydantic-validated; 422 outside) | Source frame rate. Higher fps roughly halves each encoder's realtime multiplier — useful for gauging 60 fps capability (sports, gaming captures, smartphone footage). 60 is the cap because the player doesn't render high-refresh material specially, so 120 fps would tell the operator nothing actionable about a media-streaming workload. Defaults to 30. |
| `verify_caps` | bool | true / false | When true, hw encoders that carry a registry session cap get an extra concurrent-stress probe — spawns up to `max(8, registry_cap*3)` short parallel encodes per such encoder and counts survivors. The empirical answer to "what's my actual NVENC cap" because the registry value (3) is just a vendor default; driver 530+, RTX 40-series, and patched drivers may exceed it. Briefly saturates the GPU (~2 s wall-clock per hw encoder) so it's opt-in. Defaults to false. (The desktop client always sends `true` so the chip is honest by default.) |
| `width` | int? | 320–3840 (Pydantic-validated; 422 outside) | **Single-resolution only** (back-compat). Source frame width. Server-side `clamp_resolution` snaps the (`width`, `height`) pair to the nearest documented tier (720p / 1080p / 4K). Defaults to 1280. Ignored when `resolutions` is set. |
| `height` | int? | 240–2160 (Pydantic-validated; 422 outside) | **Single-resolution only** (back-compat). Source frame height. Paired with `width`; same snap behaviour. Defaults to 720. Ignored when `resolutions` is set. |
| `resolutions` | list[ResolutionTuple]? | each tuple's width 320–3840, height 240–2160 | **Matrix mode (2026-05-07).** When set, the benchmark runs each encoder against every resolution in this list sequentially (outer loop is per-resolution, inner loop is per-encoder); the result list contains `len(encoders) × len(resolutions)` rows, each self-describing its source resolution via the new per-row `width` + `height` fields. Server-side `clamp_resolutions` snaps every pair to a known tier and drops duplicates that collapse onto the same one — operator submitting both `(1280, 720)` and `(1366, 768)` ends up with a single 720p entry. Empty / null falls back to single-resolution mode (above). Each `ResolutionTuple` is `{"width": <int>, "height": <int>}`. |

**Matrix-mode example body:**
```json
{
  "fps": 30,
  "resolutions": [
    {"width": 1280, "height": 720},
    {"width": 1920, "height": 1080},
    {"width": 3840, "height": 2160}
  ]
}
```

**Response:**

Each result row carries `width` + `height` so the desktop can render matrix-mode tables without inferring per-row dimensions from the parent run. Top-level `width`/`height` are the **first tested resolution** (= primary tier); the new `resolutions` echo lists every tested tier in operator-selection order.

```json
{
  "id": 42,
  "started_at": "2026-05-07T15:30:12.123456+00:00",
  "finished_at": "2026-05-07T15:30:35.987654+00:00",
  "duration_sec": 8,
  "fps": 30,
  "width": 1280,
  "height": 720,
  "resolutions": [
    {"width": 1280, "height": 720},
    {"width": 1920, "height": 1080},
    {"width": 3840, "height": 2160}
  ],
  "verify_caps": true,
  "results": [
    {
      "encoder": "h264_nvenc",
      "vendor": "nvidia",
      "codec": "h264",
      "width": 1280,
      "height": 720,
      "passed": true,
      "error": null,
      "fps": 174.0,
      "speed_x": 5.72,
      "bitrate_kbps": 1100.0,
      "encoded_frames": 240,
      "elapsed_sec": 1.40,
      "realtime_multiplier": 5.71,
      "init_ms": 480,
      "gpu_utilization_percent": 34.0,
      "vram_used_mb": 580,
      "concurrent_session_cap": 3,
      "recommended_concurrent": 3
    },
    {
      "encoder": "libx264",
      "vendor": "software",
      "codec": "h264",
      "passed": true,
      "error": null,
      "fps": 28.0,
      "speed_x": 0.93,
      "bitrate_kbps": 980.0,
      "encoded_frames": 240,
      "elapsed_sec": 8.6,
      "realtime_multiplier": 0.93,
      "init_ms": 45,
      "gpu_utilization_percent": null,
      "vram_used_mb": null,
      "concurrent_session_cap": null,
      "recommended_concurrent": 1
    },
    {
      "encoder": "hevc_qsv",
      "vendor": "intel",
      "codec": "hevc",
      "passed": false,
      "error": "[hevc_qsv @ 0x1] Error querying encoder params: unsupported (-3)",
      "fps": null,
      "speed_x": null,
      "bitrate_kbps": null,
      "encoded_frames": null,
      "elapsed_sec": 1.2,
      "realtime_multiplier": null,
      "init_ms": null,
      "gpu_utilization_percent": null,
      "vram_used_mb": null,
      "concurrent_session_cap": null,
      "recommended_concurrent": null
    }
  ]
}
```

**Per-result fields (Tier 1 surfaced 2026-05-07):**
| Field | Source | Notes |
|-------|--------|-------|
| `vendor` | Registry | `software` / `nvidia` / `intel` / `amd` / `apple`. Drives desktop vendor-section grouping. |
| `codec` | Registry | `h264` / `hevc` (future: `av1`). |
| `init_ms` | Streamed stderr | Wall-clock from spawn → first `frame=N≥1` line. Stream-start latency budget. |
| `gpu_utilization_percent` | Per-vendor probe at midpoint | nvidia-smi / intel_gpu_top / radeontop / system_profiler. Null on software / probe-missing / probe-fail. |
| `vram_used_mb` | Same | Same caveats. |
| `concurrent_session_cap` | Registry | NVENC consumer cards = 3; software/QSV/VAAPI/VideoToolbox = null. **This is a vendor-documented default**, not a measured ceiling — driver 530+ removed the consumer cap on RTX 40-series and community patches lift it on older cards. |
| `verified_concurrent` | Cap probe | Empirical session cap from `probe_concurrent_cap`. Only populated when `verify_caps=true` AND the encoder has a registry cap. May exceed `concurrent_session_cap` on patched / driver-530+ / RTX-40 setups — that's the actionable signal the operator needs. Re-derives `recommended_concurrent` against this value when present. |
| `recommended_concurrent` | Derived | `min(effective_cap, floor(speed_x))` where effective_cap is the verified value when present, else the registry default. The "how many streams can I sustain at realtime" answer the desktop chip surfaces. |

**Notes:**
- `realtime_multiplier` = `duration_sec / elapsed_sec`. Values > 1 mean the encoder runs faster than realtime (could drive a live stream); values < 1 mean it would underrun. Desktop UI colours the speed cell emerald (≥1×) vs amber (<1×).
- `recommended_concurrent` is computed from `speed_x` (FFmpeg's encoder-side measurement, less startup-polluted than wall-clock) — falls back to `realtime_multiplier` when speed_x is missing. Floor-clamped to ≥1 if the encoder finished at all (sub-realtime encoders can still drive a single laggy stream).
- The midpoint GPU probe sleeps `max(0.25, duration_sec/2)` seconds, then runs the same probe the live status panel uses. Failures are silent (gpu/vram fields stay null) so a missing `nvidia-smi` doesn't fail the whole benchmark.
- Failed rows are NOT dropped — they round-trip with `passed=false` + `error` so the operator sees *why* an encoder couldn't be benchmarked. The error line is picked via a marker-aware walker (`error`/`failed`/`unsupported`/...) rather than blindly grabbing the first stderr line, which is FFmpeg's input-header chatter.
- Encoders are walked sequentially. Concurrent runs would contend for GPU + CPU and produce noise that defeats the comparison.
- Source is `lavfi testsrc` at 1280×720@30, encoded with `medium` preset + CRF 23, muxed as `mpegts` to stdout DEVNULL (`-f null -` would discard bytes before the muxer measured them, leaving every progress line with `bitrate=N/A`).

**Errors:** `403` not from localhost; `422` `duration_sec` outside [2, 20]

---

### `GET /api/v1/transcoding/benchmark/progress`
**Description:** Live progress snapshot for an in-flight benchmark run.  Polled by the desktop ~every 500 ms while its own `POST /benchmark` is in flight so the operator sees per-encoder status (current encoder + `encoding` vs `verifying_cap` step) instead of a featureless spinner.  Returns `{"running": false, ...nulls}` when no benchmark is in flight; module-level read on the server, no DB hit.
**Auth:** Localhost only — `require_local_caller`.
**Status:** ✅ Implemented (2026-05-07)

**Response (running):**
```json
{
  "running": true,
  "started_at": "2026-05-07T15:30:12.123456+00:00",
  "total_encoders": 6,
  "completed": 2,
  "current_encoder": "h264_nvenc",
  "current_step": "encoding",
  "current_index": 3,
  "total_resolutions": 3,
  "current_resolution_index": 1,
  "current_resolution_width": 1920,
  "current_resolution_height": 1080
}
```

**Response (idle):**
```json
{
  "running": false,
  "started_at": null,
  "total_encoders": null,
  "completed": null,
  "current_encoder": null,
  "current_step": null,
  "current_index": null,
  "total_resolutions": null,
  "current_resolution_index": null,
  "current_resolution_width": null,
  "current_resolution_height": null
}
```

**Matrix-mode fields** (`total_resolutions` + `current_resolution_*`): in single-resolution runs `total_resolutions=1` and the index stays at `1` throughout, so the desktop can read these unconditionally without branching.  Matrix runs report progress per-resolution so the operator sees `(720p · h264_nvenc)` advance through `(1080p · h264_nvenc)` as the outer loop walks resolutions.

**`current_step` values:**
| Value | Meaning |
|-------|---------|
| `starting` | Between trigger and first encoder spawn (only visible for the first ~50 ms). |
| `encoding` | Running the main per-encoder benchmark (`benchmark_encoder`). |
| `verifying_cap` | Running the concurrent-stress probe (`probe_concurrent_cap`) for an hw encoder that carries a registry session cap. |

**Notes:**
- The desktop computes a determinate progress fraction as `(completed + (current_index > completed ? 0.5 : 0)) / total_encoders` — half-credit for the in-flight encoder so the bar moves smoothly between completion ticks.
- Backed by a module-level `_progress: dict | None` in `services/benchmark_service.py` that's cleared in a `finally` block, so a crash mid-run doesn't leave a phantom-running state.

**Errors:** `403` not from localhost

---

### `GET /api/v1/transcoding/benchmark/history`
**Description:** List recent benchmark-run summaries (no per-encoder results) for the desktop's Benchmark history sidebar.  Newest first.  Backed by the `benchmark_runs` table (migration 024); auto-pruned to 50 entries by `benchmark_history_service.prune_history` on every save.
**Auth:** Localhost only — `require_local_caller`.
**Status:** ✅ Implemented (2026-05-07)

**Query params:**
| Param | Type | Range | Description |
|-------|------|-------|-------------|
| `limit` | int | 1–50 | Cap on returned entries.  Defaults to 20. |

**Response:**
```json
{
  "entries": [
    {
      "id": 17,
      "started_at": "2026-05-07T15:30:12.123456+00:00",
      "finished_at": "2026-05-07T15:30:35.987654+00:00",
      "duration_sec": 8,
      "fps": 60,
      "width": 1920,
      "height": 1080,
      "verify_caps": true,
      "encoder_count": 6,
      "resolution_count": 1
    }
  ]
}
```

`resolution_count` is derived server-side by counting distinct `(width, height)` tuples in the stored `results_json`.  Old rows written before matrix mode shipped have all results at the same resolution → `resolution_count == 1`, which the desktop renders as the legacy `1080p · 30 fps · 6 enc` format; matrix runs render `3 res · 30 fps · 18 enc` instead.  Defaulted to `1` for backwards compat.

**Errors:** `403` not from localhost

---

### `GET /api/v1/transcoding/benchmark/history/{run_id}`
**Description:** Fetch one stored run's full body — same shape as the live `POST /benchmark` response.  The desktop calls this when the operator clicks an entry in the history sidebar.
**Auth:** Localhost only — `require_local_caller`.
**Status:** ✅ Implemented (2026-05-07)

**Response:** identical to `POST /benchmark` (carries the same `id`, workload metadata, and per-encoder `results` array).

**Errors:** `403` not from localhost; `404` unknown id

---

### `DELETE /api/v1/transcoding/benchmark/history/{run_id}`
**Description:** Delete one stored run.  No body returned.
**Auth:** Localhost only — `require_local_caller`.
**Status:** ✅ Implemented (2026-05-07)

**Response:** `204 No Content` on success.

**Errors:** `403` not from localhost; `404` unknown id

---

## Library Transcode (Plan 18)

User-driven, opt-in pre-transcode of AV1 / VP9 sources to H.264 sidecars stored next to the original (`<basename>.h264.<ext>`). Once a sidecar exists, `POST /stream/start/{file_id}` automatically uses it (stream-copies, no live transcode). Single-worker FIFO queue; concurrency = 1; H.264 + AAC only. Plan: [`docs/10_planning/18_library_transcode_plan.md`](../10_planning/18_library_transcode_plan.md).

### `GET /api/v1/transcode/candidates`
**Description:** List `media_files` rows whose video codec is AV1 or VP9 and which don't already have a transcoded sidecar.
**Auth:** Bearer token **or** localhost — `validate_token_or_local`.
**Status:** ✅ Implemented (2026-05-09)

**Response:** `200 OK` + JSON array of `TranscodeCandidate`:

```json
[
  {
    "file_id": "abc-123",
    "name": "Avicii - The Nights.mkv",
    "library_id": "lib-xyz",
    "size_bytes": 62914560,
    "video_codec": "av1",
    "duration_sec": 190.6,
    "est_output_size_bytes": 125829120
  }
]
```

`est_output_size_bytes` is a coarse client-facing estimate (2.0× source for AV1, 1.5× for VP9) — the desktop renders it with a `≈` prefix to make the fuzziness obvious.

### `POST /api/v1/transcode/queue`
**Description:** Enqueue one or more files for transcoding. Skips files that already have a queued/running job (silent — they don't appear in the returned `job_ids`). Picks `h264_nvenc` if available in the encoder registry, else falls back to `libx264`.
**Auth:** Bearer token **or** localhost.
**Rate limit:** `10/minute` per `real_ip_key`.
**Status:** ✅ Implemented (2026-05-09)

**Request body** (`TranscodeQueueRequest`):

```json
{ "file_ids": ["abc-123", "def-456"] }
```

| Field | Type | Constraints |
|-------|------|-------------|
| `file_ids` | `list[str]` | Required; 1-50 items (Pydantic `min_length=1, max_length=50`). |

**Response:** `201 Created`:

```json
{ "job_ids": [42, 43] }
```

**Errors:**
- `400` — file_id doesn't exist, or file isn't a candidate (not AV1/VP9, or already has `transcoded_path`).
- `422` — empty list / over 50 items.

### `GET /api/v1/transcode/jobs`
**Description:** List transcode jobs, optionally filtered by status.
**Auth:** Bearer token **or** localhost.
**Status:** ✅ Implemented (2026-05-09)

**Query parameters:**

| Param | Type | Description |
|-------|------|-------------|
| `status` | `str?` | Comma-separated subset of `queued`, `running`, `done`, `failed`, `cancelled`. Empty / omitted = all. Unknown value = 422. |

**Response:** `200 OK` + JSON array of `TranscodeJobResponse`:

```json
[
  {
    "id": 42,
    "file_id": "abc-123",
    "file_name": "Avicii - The Nights.mkv",
    "status": "running",
    "progress_pct": 31.4,
    "eta_sec": 47,
    "error": null,
    "output_path": null,
    "encoder": "h264_nvenc",
    "created_at": 1715212345,
    "started_at": 1715212350,
    "finished_at": null
  }
]
```

`progress_pct` is `0.0`–`100.0` (not `0.0`–`1.0`). `eta_sec` and `output_path` are populated only on `running` / `done`. `error` carries the last 240 chars of FFmpeg stderr on `failed`.

### `DELETE /api/v1/transcode/jobs/{job_id}`
**Description:** Cancel a queued or running job. For running jobs the worker SIGTERMs the FFmpeg process and unlinks the partial output file.
**Auth:** Bearer token **or** localhost.
**Status:** ✅ Implemented (2026-05-09)

**Response:** `204 No Content` on success.

**Errors:**
- `404` — unknown job id.
- `409` — job is already `done` / `failed` / `cancelled` (terminal state).

### `POST /api/v1/transcode/jobs/{job_id}/retry`
**Description:** Re-enqueue a failed or cancelled job. The original row is left untouched (its `error` column remains the History tab's record of what went wrong); a new `queued` row is inserted with the same `file_id` / `encoder` / `quality_preset`.
**Auth:** Bearer token **or** localhost.
**Status:** ✅ Implemented (2026-05-09)

**Response:** `201 Created` (`TranscodeRetryResponse`):

```json
{ "new_job_id": 44 }
```

**Errors:**
- `404` — unknown job id.
- `409` — job is `queued` / `running` / `done` (only `failed` / `cancelled` can retry).

### `GET /api/v1/transcode/storage`
**Description:** Aggregate snapshot of the server's transcoded-sidecar disk usage. Polled by the desktop's `_StorageStrip` widget every 5 s while the Transcode screen is mounted. Cheap query (one SUM, two GROUP BYs, one `shutil.disk_usage` syscall).
**Auth:** Bearer token **or** localhost — `validate_token_or_local`.
**Status:** ✅ Implemented (plan 19 §M3, 2026-05-09); `by_library` field added 2026-05-10 (plan-19 close-out followup).

**Response:** `200 OK` (`TranscodeStorageResponse`):

```json
{
  "cache_root": "D:\\Fluxora\\transcodes",
  "storage_mode": "dedicated",
  "transcoded_size_bytes": 5832019712,
  "transcoded_file_count": 12,
  "free_bytes_at_cache_root": 909521817600,
  "by_codec": {
    "av1": {"count": 8, "bytes": 4500000000},
    "vp9": {"count": 4, "bytes": 1300000000}
  },
  "by_library": {
    "lib-uuid-123": {
      "library_name": "Movies",
      "count": 8,
      "bytes": 4500000000
    },
    "lib-uuid-456": {
      "library_name": "TV",
      "count": 4,
      "bytes": 1300000000
    },
    "(orphaned)": {
      "library_name": "(orphaned)",
      "count": 0,
      "bytes": 0
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `cache_root` | `str` | Resolved absolute path sidecars are landing at. Reflects `user_settings.transcode_cache_root` or the data-dir-default fallback when unset. |
| `storage_mode` | `Literal['dedicated', 'inline']` | Per `user_settings.transcode_storage_mode`. |
| `transcoded_size_bytes` / `transcoded_file_count` | `int` | Aggregate sums across all transcoded sidecars (any library). |
| `free_bytes_at_cache_root` | `int` | `shutil.disk_usage(cache_root).free`. Walks up to the first existing parent if `cache_root` itself isn't on disk yet. `0` on `OSError`. |
| `by_codec` | `dict[str, {count, bytes}]` | Per-source-codec breakdown. Codec keys arrive lower-cased (`av1`, `vp9`, `hevc`, …). Empty when the cache is empty. |
| `by_library` | `dict[str, {library_name, count, bytes}]` | Per-library breakdown — feeds the desktop's library-delete confirmation modal so the operator sees the actual N + GB the sidecar-cleanup checkbox is about to wipe. Files whose `library_id` is NULL or points at a previously-deleted library bucket under the synthetic `(orphaned)` key. Empty when the cache is empty. |

**Errors:** none on the success path; standard `401` / `403` from auth.

---

### `PATCH /api/v1/settings` — `transcoding_chain` field
The settings PATCH body gained a `transcoding_chain: list[str] | null` field for Slice C. Each entry must be a known encoder in the registry. The list is JSON-encoded into `user_settings.transcoding_chain` (migration 020). Validation rules:

- Empty list `[]` → stored as NULL → server uses the default chain (`[transcoding_encoder, "libx264"]`).
- Unknown encoder name → 422 with detail naming the offending entry.
- Chain where every entry is the same encoder → 422 (`"transcoding_chain must contain distinct encoders or be empty"`).

The response's `transcoding_chain` field decodes back to a list (or null). The desktop's `EncoderPriorityList` widget renders + reorders.

### `PATCH /api/v1/settings` — `streaming_mode` field
Plan 19 §M7 + plan 20 — global streaming-mode toggle. Three values, `Literal['auto', 'client-decode', 'server-transcode']` (Pydantic-validated; 422 outside).

| Value | Behaviour | Default |
|-------|-----------|---------|
| `client-decode` | Stream-copies h264/hevc/av1/vp9; client hardware-decodes. No fallback. Player error surfaces to the user. **Recommended for modern, uniform device pools.** | ✅ v1 launch default |
| `auto` | Stream-copies first (same as `client-decode`). Within 6 s of `PlayerReady`, if mobile player emits any error, POSTs `/fallback-transcode` → server transcodes + records `(client_id, source_codec)` in `client_codec_blocklist`. Future sessions for that `(client, codec)` pair start directly in transcode. **Opt-in.** | Mixed device pools |
| `server-transcode` | Always transcodes AV1/VP9 to H.264. Works on every device but uses significant CPU/GPU per active stream. | Legacy / opt-in |

Stored on `user_settings.streaming_mode` (migration 028 — two values; widened to three by migration 032). H.264 + HEVC sources stream-copy regardless of mode. Sidecar pickup wins regardless of mode. The `client_codec_blocklist` is **only consulted** when `streaming_mode='auto'`; strict modes ignore it. The desktop's 3-option `_StreamingModeCard` (in `EncoderSettingsScreen`) reads + writes this field.

---

### `POST /api/v1/stream/{session_id}/fallback-transcode`
**Description:** Opt-in auto-fallback endpoint. Called by the mobile player when it emits an error within 6 s of `PlayerReady` under `streaming_mode='auto'`. Records the `(client_id, source_codec)` pair in `client_codec_blocklist`, flips the session to transcode, restarts FFmpeg from the caller-supplied playhead position, and returns the (unchanged) playlist URL so the player can reload.  
**Auth:** Bearer token (same as other stream endpoints).  
**Rate limit:** 10 per minute.  
**Status:** ✅ Plan 20.

**Path param:** `session_id` — the active session UUID.

**Request body:**
```json
{ "current_position_sec": 12.5 }
```
`current_position_sec` is `float ≥ 0` (required). Caller supplies the current playhead position so the server can restart FFmpeg from that offset rather than guessing.

**Response 200:**
```json
{
  "session_id": "abc-...",
  "playlist_url": "http://…/hls/abc-…/playlist.m3u8",
  "forced_transcode": true
}
```

**Status codes:**
| Code | Condition |
|------|-----------|
| 200 | Fallback applied; `forced_transcode: true`; new playlist URL for `player.open()` |
| 404 | Session not found or already ended |
| 403 | Session not owned by the calling client |
| 409 | `streaming_mode` is not `'auto'`; strict modes never transparently switch pipelines |
| 422 | `current_position_sec` missing / negative |
| 429 | Rate limit exceeded (10/min) |

**Blocklist semantics:** the `(client_id, source_codec)` row is written via `INSERT OR IGNORE` — calling this endpoint multiple times for the same pair is idempotent. On the next `/stream/start` for this client + codec combination, `client_codec_service.is_blocked(db, client_id, source_codec)` returns `True` and the session starts directly in transcode mode without the optimistic stream-copy probe.

---

### `POST /api/v1/stream/start/{file_id}` — `streaming_mode` + `audio_streaming_mode` in response
Plan 20 added a `streaming_mode` field to `StreamStartResponse` so the mobile client knows whether to arm the 6 s auto-fallback watcher. Plan 21 added `audio_streaming_mode` so the mobile client also knows whether to arm the audio-specific fallback watcher.

```json
{
  "session_id": "abc-...",
  "playlist_url": "http://…/hls/abc-…/playlist.m3u8",
  "resume_sec": 0,
  "applied_seek_sec": 0,
  "hdr_format": null,
  "tonemapped": false,
  "streaming_mode": "client-decode",
  "audio_streaming_mode": "stream-copy"
}
```

`streaming_mode` is one of `'auto' | 'client-decode' | 'server-transcode'`. The mobile `PlayerCubit` only arms the 6 s video error watcher when `response.streamingMode == 'auto'`; other modes let player errors bubble unchanged.

`audio_streaming_mode` is one of `'stream-copy' | 'transcode'`. Default is `'transcode'`. The mobile `PlayerCubit` only arms the 6 s audio fallback watcher when **both** `response.streamingMode == 'auto'` AND `response.audioStreamingMode == 'stream-copy'`; the video and audio watchers are independent and can fire simultaneously in the same session.

Audio stream-copy is attempted when:
- The source audio codec is in the allowlist `{aac, ac3, eac3, opus, flac}`
- HDR tonemap is not active for the session (tonemap forces audio re-encode for PTS alignment)
- The client does not already have a `client_audio_codec_blocklist` row for this `(client_id, audio_codec)` pair

### `POST /api/v1/stream/{session_id}/fallback-audio-transcode`
**Description:** Opt-in audio-only fallback endpoint. Called by the mobile player when it detects an audio decode error within 6 s of `PlayerReady` under `streaming_mode='auto'` and `audio_streaming_mode='stream-copy'`. Records the `(client_id, audio_codec)` pair in `client_audio_codec_blocklist`, forces audio re-encode for the session, restarts FFmpeg from the caller-supplied playhead position with audio transcoded to AAC 256 k while keeping video unchanged, and returns the (unchanged) playlist URL so the player can reload.
**Auth:** Bearer token (same as other stream endpoints).
**Rate limit:** 10 per minute.
**Status:** ✅ Plan 21.

**Path param:** `session_id` — the active session UUID.

**Request body:**
```json
{ "current_position_sec": 42.5 }
```

`current_position_sec` must be `≥ 0`.

**Response (200):**
```json
{
  "session_id": "abc-...",
  "playlist_url": "http://…/hls/abc-…/playlist.m3u8",
  "forced_audio_transcode": true
}
```

**Status codes:**

| Code | Condition |
|------|-----------|
| 200 | Audio fallback applied; `forced_audio_transcode: true`; playlist URL for `player.open()` |
| 404 | Session not found or already ended |
| 403 | Session not owned by the calling client |
| 409 | `streaming_mode` is not `'auto'`; strict modes never transparently switch audio pipelines |
| 422 | `current_position_sec` missing / negative |
| 429 | Rate limit exceeded (10/min) |

**Blocklist semantics:** the `(client_id, audio_codec)` row is written via `INSERT OR IGNORE` — calling this endpoint multiple times for the same pair is idempotent. On the next `/stream/start` for this client + audio codec combination, `client_audio_codec_service.is_blocked(db, client_id, audio_codec)` returns `True` and the session starts with `_session_force_audio_transcode = True` without attempting audio stream-copy.

**Relation to video fallback:** this endpoint is independent of `POST /fallback-transcode`. A session can have both video and audio forced to transcode simultaneously. Video stays stream-copy when only audio failed.

---

### `GET /api/v1/logs`
**Description:** List structured log records from the server's JSON log file with filtering and cursor-based pagination.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Query params:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `level` | string | — | Filter to records at or above this level (e.g. `WARNING` returns `WARNING`, `ERROR`, `CRITICAL`) |
| `source` | string | — | Prefix filter on the logger `name` field (e.g. `fluxora.stream` matches all stream-router logs) |
| `since` | string (ISO-8601) | — | Return only records with `ts` strictly after this timestamp |
| `until` | string (ISO-8601) | — | Return only records with `ts` strictly before this timestamp |
| `q` | string | — | Case-insensitive substring search against the `message` field |
| `limit` | integer | `200` | Max records per page; range `1..1000` |
| `cursor` | integer | `0` | Zero-based line offset into the log file (returned as `next_cursor` from previous page) |

**Response:**
```json
{
  "items": [
    {
      "ts": "2026-05-02T10:00:00.123Z",
      "level": "INFO",
      "source": "fluxora.stream",
      "message": "Stream session abc123 started for client Pixel 8 Pro"
    }
  ],
  "next_cursor": 200
}
```

`next_cursor` is `null` when the end of the log file has been reached for the current filter set.

**Errors:** `401` off-loopback caller without token · `422` invalid `limit`

---

### `WebSocket /api/v1/ws/logs`
**Description:** Live log tail — emits a frame for every new log record as the server writes it. Uses the same in-process `BroadcastHandler` that is attached to the root Python logger at startup; each connected subscriber gets its own asyncio queue. Slow consumers drop frames (queue capped at 100 items) rather than blocking log producers.  
**Auth:** Loopback connections skip auth. Non-loopback connections must send the same `{"type":"auth","token":"<bearer>"}` first-message handshake as `/ws/stats`.  
**Status:** ✅ Implemented

**Frame format (server → client):**
```json
{
  "type": "log",
  "data": {
    "ts": "2026-05-02T10:00:00.123Z",
    "level": "WARNING",
    "source": "fluxora.library",
    "message": "Storage usage is above 90%"
  }
}
```

---

## Error Codes

| Code | Meaning |
|------|---------|
| 400 | Bad Request — missing or invalid params |
| 401 | Unauthorized — missing or invalid token |
| 403 | Forbidden — client not trusted / invalid webhook signature |
| 404 | Not Found — file or library not found |
| 429 | Too Many Requests — stream concurrency limit |
| 500 | Internal Server Error |
| 501 | Not Implemented — webhook integration not configured |
| 503 | FFmpeg unavailable |

---

## Versioning Strategy

- Current: `/api/v1/` prefix — public contract, additive changes only
- Breaking changes (removed fields, changed types, removed endpoints) require `/api/v2/`
- Never remove or rename a field in an existing v1 response schema
