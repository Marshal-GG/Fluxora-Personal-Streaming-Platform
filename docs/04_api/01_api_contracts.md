# API Contracts

> **Category:** API  
> **Status:** Active — Sourced from Planning Session (2026-04-27)

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

All endpoints (except `/info` and `/auth/*`) require:
```
Authorization: Bearer {auth_token}
```

Token is issued after successful client pairing.

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
**Auth:** Bearer token required.  
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
    "created_at": "2026-04-27T10:00:00+00:00",
    "updated_at": "2026-04-27T10:00:00+00:00"
  }
]
```

---

### `GET /api/v1/files/{file_id}`
**Description:** Get a single indexed media file by ID.  
**Auth:** Bearer token required.  
**Status:** ✅ Implemented

**Response:** Same schema as list item above.  
**Errors:** `404` file not found

---

### `GET /api/v1/library`
**Description:** List all libraries.  
**Auth:** Bearer token required.  
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
**Auth:** Bearer token required.  
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
**Auth:** Bearer token required.  
**Status:** ✅ Implemented

**Response:** Same schema as list item.  
**Errors:** `404` library not found

---

### `DELETE /api/v1/library/{library_id}`
**Description:** Delete a library (does not delete files from disk).  
**Auth:** Bearer token required.  
**Status:** ✅ Implemented

**Response:** `204 No Content`  
**Errors:** `404` library not found

---

### `POST /api/v1/library/{library_id}/scan`
**Description:** Walk the library's `root_paths`, index all discovered media files by extension, and update `last_scanned`.  
**Auth:** Bearer token required.  
**Status:** ✅ Implemented

**Response:**
```json
{ "library_id": "uuid", "files_added": 42 }
```

**Errors:** `404` library not found · `500` scan failed (I/O error)

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

### `DELETE /api/v1/stream/{session_id}`
**Description:** Stop a stream session, kill the FFmpeg process, and delete HLS segments.  
**Auth:** Bearer token required (must own the session).  
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
**Description:** WebRTC signaling channel for internet connections.  
**Status:** 🔲 Planned (Phase 3)

**Messages:**
```json
// Client → Server (offer)
{ "type": "offer", "sdp": "...", "client_id": "uuid" }

// Server → Client (answer)
{ "type": "answer", "sdp": "..." }

// ICE candidates (both directions)
{ "type": "ice-candidate", "candidate": "..." }
```

---

## Error Codes

| Code | Meaning |
|------|---------|
| 400 | Bad Request — missing or invalid params |
| 401 | Unauthorized — missing or invalid token |
| 403 | Forbidden — client not trusted / tier limit |
| 404 | Not Found — file or library not found |
| 429 | Too Many Requests — stream concurrency limit |
| 500 | Internal Server Error |
| 503 | FFmpeg unavailable |

---

## Versioning Strategy

- Current: `/api/v1/` prefix — public contract, additive changes only
- Breaking changes (removed fields, changed types, removed endpoints) require `/api/v2/`
- Never remove or rename a field in an existing v1 response schema
