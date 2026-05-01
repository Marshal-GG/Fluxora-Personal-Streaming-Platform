# API Contracts

> **Category:** API  
> **Status:** Active - Updated 2026-05-02 (new endpoints for the desktop redesign: `/info/stats` + `/ws/stats`, `/info/restart`, `/info/stop`, `/library/storage-breakdown`; previous round added orders, upload, delete file, stream sessions, progress; auth model updated for files/library; transcoding settings fields validated as enums + CRF bounded 0-51; license keys are 5-part only; Groups CRUD + member management + stream-gate; Profile endpoints; Notifications REST + WS added; Activity event log added)

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
| Bearer token required | `validate_token` | Stream, HLS, WebSocket endpoints |
| Bearer token OR localhost | `validate_token_or_local` | `/files`, `/library`, `GET /groups`, `GET /groups/{id}`, `GET /groups/{id}/members`, `GET /notifications`, `POST /notifications/{id}/read`, `POST /notifications/read-all`, `DELETE /notifications/{id}`, `GET /activity` — desktop control panel needs no token |
| Localhost only | `require_local_caller` | `/auth/approve`, `/auth/clients`, `/settings`, `/orders`, `/stream/sessions`, `POST /groups`, `PATCH /groups/{id}`, `DELETE /groups/{id}`, `POST /groups/{id}/members`, `DELETE /groups/{id}/members/{cid}`, `GET /profile`, `PATCH /profile` |
| No auth | — | `/info`, `/info/logs`, `/auth/request-pair`, `/auth/status`, `/webhook/polar` |

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

`remote_url` is `null` when `FLUXORA_PUBLIC_URL` is unset on the server (no public routing configured). Clients persist it after the first successful pair and use it from off-LAN networks (decision D1 in [`docs/05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md#decisions-locked)).

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

### `GET /api/v1/info/logs`
**Description:** Return the last 1000 lines of the server log file (`~/.fluxora/logs/server.log`).  
**Auth:** None required.  
**Status:** ✅ Implemented

**Response:**
```json
{ "logs": "<last 1000 log lines as a single string>" }
```

> Returns `{"logs": ""}` if the log file does not exist yet.

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

### `GET /api/v1/info/stats`
**Description:** Live system stats — CPU, RAM, network throughput, uptime, LAN IP, internet connectivity, active stream count. Backs the redesigned sidebar System Status block, the bottom status bar, and the Dashboard sparklines.  
**Auth:** None required.  
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
**Description:** Client initiates pairing. Creates a pending client record on the server.  
**Auth:** None required.  
**Status:** ✅ Implemented

**Request:**
```json
{
  "client_id": "uuid-generated-by-client",
  "device_name": "Pixel 8 Pro",
  "platform": "android",
  "app_version": "0.1.0"
}
```

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

**Errors:** `403` not from localhost · `404` client not found · `409` client already approved/rejected

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
**Description:** Revoke an approved client's access. Takes effect immediately.  
**Auth:** Bearer token required.  
**Status:** ✅ Implemented

**Response:** `204 No Content`

---

### `GET /api/v1/auth/clients`
**Description:** List all paired clients (all statuses). Used by the desktop control panel.  
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
      "last_seen": "2026-04-28T12:00:00",
      "is_trusted": true
    }
  ],
  "total": 1
}
```

**Errors:** `403` not from localhost

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
    "created_at": "2026-04-27T10:00:00+00:00",
    "updated_at": "2026-04-27T10:00:00+00:00"
  }
]
```

> **Note:** `title`, `overview`, `poster_url` are `null` until the library has been enriched via TMDB.  
> `resume_sec` defaults to `0.0` until the client reports playback progress via WebSocket.

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
    "file_count": 142
  }
]
```

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

### `DELETE /api/v1/library/{library_id}`
**Description:** Delete a library (does not delete files from disk).  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:** `204 No Content`  
**Errors:** `404` library not found

---

### `POST /api/v1/library/{library_id}/scan`
**Description:** Walk the library's `root_paths`, index all discovered media files by extension, enrich metadata via TMDB, and update `last_scanned`.  
**Auth:** Bearer token **or** localhost (`validate_token_or_local`).  
**Status:** ✅ Implemented

**Response:**
```json
{ "library_id": "uuid", "files_added": 42 }
```

**Errors:** `404` library not found · `500` scan failed (I/O error)

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
**Description:** Spawn an FFmpeg transcode process for a file and return the HLS playlist URL.  
**Auth:** Bearer token required.  
**Status:** ✅ Implemented

**Response:** `201 Created`
```json
{
  "session_id": "uuid",
  "file_id": "uuid",
  "playlist_url": "http://192.168.1.10:8000/api/v1/hls/uuid/playlist.m3u8"
}
```

**Errors:** `404` file not found · `429` concurrency limit reached · `503` FFmpeg unavailable

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
  "transcoding_crf": 23
}
```

---

### `PATCH /api/v1/settings`
**Description:** Update one or more server settings. Changing `tier` automatically adjusts `max_concurrent_streams` to match the tier limit.  
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
  "transcoding_crf": 20
}
```

**Field constraints (Pydantic-enforced — invalid values return 422):**

| Field | Allowed values |
|-------|----------------|
| `license_key` | `FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>` — exactly 5 dash-separated segments |
| `transcoding_encoder` | `libx264` · `h264_nvenc` · `h264_qsv` · `h264_vaapi` |
| `transcoding_preset` | `ultrafast` · `superfast` · `veryfast` · `faster` · `fast` · `medium` · `slow` · `slower` · `veryslow` |
| `transcoding_crf` | Integer in `[0, 51]` (0 = lossless, 23 = default, 51 = worst quality) |

**Tier values and stream limits:**

| Tier | Concurrent streams |
|------|-------------------|
| `free` | 1 |
| `plus` | 3 |
| `pro` | 10 |
| `ultimate` | 9999 (unlimited) |

**Response:** Same schema as `GET /api/v1/settings`.  
**Errors:** `422` invalid tier or blank server_name · `403` not from localhost

---

### `GET /api/v1/orders`
**Description:** List all processed Polar orders with their generated license keys. Intended for the Desktop Control Panel owner screen to forward keys to customers manually.  
**Auth:** Localhost only — `require_local_caller`.  
**Status:** ✅ Implemented

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
  "total": 1
}
```

**Errors:** `403` not from localhost

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
