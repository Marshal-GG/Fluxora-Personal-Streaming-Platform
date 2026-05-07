# API Contracts

> **Category:** API  
> **Status:** Active - Updated 2026-05-04 (**Phase 6 follow-ups:** `POST /api/v1/stream/start/{file_id}` gained `?tonemap=true` query param; `StreamStartResponse` gains `hdr_format: string | null` + `tonemapped: bool` fields. GPU UX Slice A: new `GET /api/v1/transcoding/advisor` endpoint; `/transcoding/status` gains `encoder_test_error` + `encoder_tested_at` fields; `transcoding_encoder` allowed values expanded to all 10 registry encoders; `/stream/start` 503 detail now carries the FFmpeg stderr tail. Earlier 2026-05-04: Phase B real-data backfill: new `GET /api/v1/files/search?q=&limit=`, new `GET /api/v1/auth/clients/me/continue-watching?limit=`, new `GET /api/v1/auth/clients/me/stats` returning `{hours, movies, shows}`. Phase A real-data backfill: new `GET /api/v1/files/recent`; new `GET /api/v1/auth/clients/me`; `POST /api/v1/auth/request-pair` accepts optional `email`; `MediaFileResponse` extended with FFprobe + episode aggregation fields; pairing flow now resets a previously-approved client back to `pending` instead of returning 409). 2026-05-03: library-screen P0/P1: new `PATCH /api/v1/library/{id}` + `total_size_bytes` field on every library response; `library.update` activity event; type field is now immutable per ADR-016; disk-file deletion is policy-locked per ADR-017. 2026-05-02 batch: new endpoints for the desktop redesign: `/info/stats` + `/ws/stats`, `/info/restart`, `/info/stop`, `/library/storage-breakdown`; previous round added orders, upload, delete file, stream sessions, progress; auth model updated for files/library; transcoding settings fields validated as enums + CRF bounded 0-51; license keys are 5-part only; Groups CRUD + member management + stream-gate; Profile endpoints; Notifications REST + WS added; Activity event log added; §7.8 `GET /api/v1/transcoding/status`; §7.9 `GET /api/v1/logs` + `WS /api/v1/ws/logs`; §7.10 settings PATCH extended with 18 new fields; §7.11 orders pagination + `/orders/portal-url`

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
| Bearer token required | `validate_token` | Stream, HLS, WebSocket endpoints, `GET /auth/clients/me` |
| Bearer token OR localhost | `validate_token_or_local` | `/files`, `/library`, `GET /info/stats`, `GET /groups`, `GET /groups/{id}`, `GET /groups/{id}/members`, `GET /notifications`, `POST /notifications/{id}/read`, `POST /notifications/read-all`, `DELETE /notifications/{id}`, `GET /activity`, `GET /logs` — desktop control panel needs no token |
| Localhost only | `require_local_caller` | `/auth/approve`, `/auth/reject`, `/auth/revoke`, `/auth/clients`, `/settings`, `/orders`, `/orders/portal-url`, `/stream/sessions`, `GET /transcoding/status`, `POST /transcoding/benchmark`, `GET /transcoding/benchmark/progress`, `GET /transcoding/benchmark/history`, `GET /transcoding/benchmark/history/{id}`, `DELETE /transcoding/benchmark/history/{id}`, `POST /info/restart`, `POST /info/stop`, `POST /info/support-bundle`, `POST /groups`, `PATCH /groups/{id}`, `DELETE /groups/{id}`, `POST /groups/{id}/members`, `DELETE /groups/{id}/members/{cid}`, `GET /profile`, `PATCH /profile` |
| No auth | — | `/info`, `/auth/request-pair`, `/auth/status`, `/webhook/polar` |

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
      }
    }
  ],
  "total": 1
}
```

- `last_ip` (migration 023): socket-level IP captured at pair time and refreshed on every authenticated request. `null` for rows that haven't sent an authenticated request since the upgrade. Tunneled requests (cloudflared) record the loopback IP — the `CF-Connecting-IP` header is NOT consumed in the heartbeat path; documented limitation, not a bug.
- `last_seen` semantics: as of migration 023 this is now refreshed by `auth_service.update_client_heartbeat()` from the `validate_token` dependency. **Before migration 023** the column was effectively frozen at pair / approval — any consumer that read this field as "last poll time" was reading stale data. Audit any UI that surfaces this value to confirm it now means what it says.
- `active_session`: `null` when the client has no `stream_sessions` row with `ended_at IS NULL`. When multiple in-flight sessions exist for a single client (defensive — v1 caps `concurrent_session_cap` at 1 per encoder), the most recently started one wins via `ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY started_at DESC) = 1`. `media_title` falls back to `media_files.name` when the file has no TMDB-derived `title`.
- `encoder_used` is the encoder picked by `session_router` at session start. `null` for stream-copy sessions (FFmpeg `-c:v copy`) since no encoder was selected.

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
    "total_size_bytes": 1_380_000_000_000
  }
]
```

`total_size_bytes` is computed via `SUM(media_files.size_bytes)` in the `list_libraries` / `get_library` SQL — `0` for libraries with no files.

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

- **Stream-copy** when source is `h264` (mpegts segments) or `hevc` (fmp4 segments) — FFmpeg just remuxes, dropping CPU usage by ~95% versus a full transcode. Audio still re-encoded to AAC 128 kb/s for HLS-client compatibility.
- **Full transcode** for everything else — applies the operator's configured `transcoding_encoder` / `preset` / `crf` from `user_settings`.

The decision is invisible to the client — the response shape is identical for both paths. The server log records which pipeline ran (`mode=stream-copy(h264/mpegts)` / `stream-copy(hevc/fmp4)` / `transcode(libx264)`).

**Query params:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `tonemap` | `bool` | `false` | When `true` and the source has an HDR format (HDR10 / HLG / DolbyVision per `media_files.hdr_format`), the server forces transcode mode and applies a zscale + Hable tonemap filter chain to convert BT.2020 PQ → BT.709 SDR.  No-op for SDR sources — the flag is accepted but `tonemapped` in the response will be `false`.  Tonemap forces CPU-side decode (drops the GPU input pipeline) because the `zscale` and `tonemap` filters cannot consume CUDA frames. |

**Auth:** Bearer token required.  
**Status:** ✅ Implemented

**Response:** `201 Created`
```json
{
  "session_id": "uuid",
  "file_id": "uuid",
  "playlist_url": "http://192.168.1.10:8000/api/v1/hls/uuid/playlist.m3u8",
  "resume_sec": 0.0,
  "hdr_format": "HDR10",
  "tonemapped": false
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

**Errors:** `404` file not found · `429` concurrency limit reached · `503` FFmpeg failed (the response body now carries the first FFmpeg stderr line so the operator notification can surface the real reason — e.g. `"No NVENC capable devices found"`, not a generic "FFmpeg failed")

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

**Response:** `204 No Content`  

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

### `GET /api/v1/hls/{session_id}/playlist.m3u8`
**Description:** Serve the HLS playlist generated by FFmpeg.  
**Auth:** Bearer token required.  
**Status:** ✅ Implemented  
Content-Type: `application/vnd.apple.mpegurl`

---

### `GET /api/v1/hls/{session_id}/{segment}.ts`
**Description:** Serve an individual HLS video segment.  
**Auth:** Bearer token required.  
**Status:** ✅ Implemented  
Content-Type: `video/MP2T`

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
  "license_status": "missing",
  "license_tier": "free",
  "transcoding_encoder": "libx264",
  "transcoding_preset": "veryfast",
  "transcoding_crf": 23,
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
  "language": "en",
  "auto_start_on_boot": false,
  "auto_restart_on_crash": true,
  "minimize_to_system_tray": true,
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
| `ai_segment_duration_seconds` | Positive integer |

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
    }
  }
]
```

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
  }
}
```

`restrictions` is optional — omit it or pass `null` to create a group with no restrictions. All restriction fields default to `null` (no restriction of that kind).

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
  }
}
```

**Response:** Updated `GroupResponse`.  
**Errors:** `404` group not found · `403` not from localhost

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

**Response:**
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
**Description:** Mark a single notification as read. Sets `read_at` to the current UTC timestamp. Idempotent — calling twice does not update the timestamp again.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** `200 OK` — the updated `NotificationResponse`.  
**Errors:** `404` notification not found

---

### `POST /api/v1/notifications/read-all`
**Description:** Mark all unread notifications as read in a single call.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{ "updated": 12 }
```

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
| `library.scan` | `system` | `library` | Library scan adds 1+ files (no-op scans are not recorded) |

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
| `width` | int? | 320–3840 (Pydantic-validated; 422 outside) | Source frame width. Server-side `clamp_resolution` snaps the (`width`, `height`) pair to the nearest documented tier (720p / 1080p / 4K) so the benchmark history doesn't accumulate one-off resolutions. Defaults to 1280. |
| `height` | int? | 240–2160 (Pydantic-validated; 422 outside) | Source frame height. Paired with `width`; same snap behaviour. Defaults to 720. |

**Response:**
```json
{
  "started_at": "2026-05-07T15:30:12.123456+00:00",
  "finished_at": "2026-05-07T15:30:35.987654+00:00",
  "duration_sec": 8,
  "fps": 30,
  "results": [
    {
      "encoder": "h264_nvenc",
      "vendor": "nvidia",
      "codec": "h264",
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
  "current_index": 3
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
  "current_index": null
}
```

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
      "encoder_count": 6
    }
  ]
}
```

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

### `PATCH /api/v1/settings` — `transcoding_chain` field
The settings PATCH body gained a `transcoding_chain: list[str] | null` field for Slice C. Each entry must be a known encoder in the registry. The list is JSON-encoded into `user_settings.transcoding_chain` (migration 020). Validation rules:

- Empty list `[]` → stored as NULL → server uses the default chain (`[transcoding_encoder, "libx264"]`).
- Unknown encoder name → 422 with detail naming the offending entry.
- Chain where every entry is the same encoder → 422 (`"transcoding_chain must contain distinct encoders or be empty"`).

The response's `transcoding_chain` field decodes back to a list (or null). The desktop's `EncoderPriorityList` widget renders + reorders.

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
