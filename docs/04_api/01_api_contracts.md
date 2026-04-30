# API Contracts

> **Category:** API  
> **Status:** Active - Updated 2026-05-01 (new endpoints: orders, upload, delete file, stream sessions, progress; auth model updated for files/library; transcoding settings fields validated as enums + CRF bounded 0-51; license keys are 5-part only)

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
| Bearer token OR localhost | `validate_token_or_local` | `/files`, `/library` — desktop control panel needs no token |
| Localhost only | `require_local_caller` | `/auth/approve`, `/auth/clients`, `/settings`, `/orders`, `/stream/sessions` |
| No auth | — | `/info`, `/info/logs`, `/auth/request-pair`, `/auth/status`, `/webhook/polar` |

---

## Endpoints

### `GET /api/v1/info`
**Description:** Returns server identity — used during discovery.  
**Auth:** None required.  
**Status:** ✅ Implemented

**Response:**
```json
{
  "server_name": "My Fluxora Server",
  "version": "1.0.0",
  "tier": "plus"
}
```

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
