# Backend Architecture

> **Category:** Backend  
> **Status:** Active — Sourced from Planning Session (2026-04-27)

---

## Framework & Stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.11+ |
| Framework | FastAPI |
| ASGI Server | Uvicorn |
| Streaming | FFmpeg (subprocess) → HLS |
| Database | SQLite (via `aiosqlite` for async) |
| LAN Discovery | `zeroconf` Python library |
| WebRTC Signaling | `aiortc` or custom WebSocket handshake |
| Metadata | TMDB REST API |
| Process Management | `asyncio` subprocess for FFmpeg |

---

## Server Project Structure

```
server/
├── main.py                 # FastAPI app entry point
├── config.py               # Settings, env vars, paths
├── database/
│   ├── db.py               # SQLite connection + migrations runner
│   └── migrations/
│       ├── 001_initial.sql
│       └── 002_sessions.sql
│
├── routers/
│   ├── info.py             # GET /api/v1/info ✅
│   ├── auth.py             # /auth endpoints ✅ (request-pair, status, approve, reject, revoke)
│   ├── deps.py             # FastAPI dependencies (validate_token) ✅
│   ├── files.py            # /files endpoints
│   ├── library.py          # /library endpoints
│   ├── stream.py           # /stream + /hls endpoints
│   └── ws.py               # WebSocket endpoints
│
├── services/
│   ├── ffmpeg_service.py   # FFmpeg subprocess management
│   ├── library_service.py  # Library scanning + TMDB integration
│   ├── discovery_service.py # mDNS/Zeroconf broadcasting
│   ├── auth_service.py     # Token validation, pairing logic
│   └── webrtc_service.py   # STUN/TURN/signaling management
│
├── models/
│   ├── media_file.py       # SQLite model
│   ├── library.py
│   ├── client.py
│   ├── stream_session.py
│   └── settings.py
│
└── utils/
    ├── file_utils.py       # Path helpers, MIME detection
    └── tmdb_client.py      # TMDB API wrapper
```

---

## Service Map

| Service | Responsibility | Key Functions |
|---------|---------------|---------------|
| `ffmpeg_service` | Spawn FFmpeg, manage HLS output, cleanup segments | `start_stream()`, `stop_stream()`, `get_stream_url()` |
| `library_service` | Scan directories, enrich with TMDB metadata | `scan_library()`, `index_file()`, `fetch_tmdb_metadata()` |
| `discovery_service` | Broadcast mDNS on LAN | `start_broadcasting()`, `stop_broadcasting()` |
| `auth_service` ✅ | Token generation (HMAC-SHA256), pairing state machine, token validation | `create_pair_request()`, `approve_client()`, `reject_client()`, `revoke_client()`, `get_trusted_client_by_token()` |
| `webrtc_service` | Manage ICE/STUN/TURN for internet connections | `handle_offer()`, `generate_answer()` |

---

## Background Jobs

| Job | Trigger | Frequency |
|-----|---------|-----------|
| Library re-scan | Manual (API or Control Panel) | On demand |
| HLS segment cleanup | Stream ends | On stream close |
| TMDB metadata enrichment | After file indexed | Background queue |
| mDNS broadcast | Server startup | Continuous |
| Session heartbeat timeout | No heartbeat in 30s | Periodic check (30s) |

---

## FFmpeg Pipeline Detail

```
Input: /media/movies/Inception.mkv
    │
    └──▶ ffmpeg -i <input>
              -codec:v libx264       # Video: H.264 (wide compatibility)
              -codec:a aac           # Audio: AAC
              -f hls                 # Output format: HLS
              -hls_time 6            # 6-second segments
              -hls_list_size 0       # Keep all segments
              -hls_segment_type mpegts
              -hls_flags delete_segments  # Auto-cleanup
              /tmp/fluxora/{session_id}/playlist.m3u8

Output: .m3u8 playlist + numbered .ts segment files
```

---

## External Integrations

| Integration | Purpose | Auth Method |
|------------|---------|------------|
| TMDB API | Movie/TV metadata, posters | API Key (user-provided or default) |
| STUN Server | WebRTC NAT traversal | None (public servers) |
| TURN Server | WebRTC relay fallback | Username + Credential |

---

## Error Handling Strategy

| Error Type | Handling |
|-----------|---------|
| FFmpeg not found | Startup check; graceful error with install instructions |
| FFmpeg transcode failure | Return 503; log stderr; cleanup temp files |
| SQLite locked | Retry with exponential backoff (WAL mode reduces this) |
| TMDB API down | Cache last known metadata; log + skip enrichment |
| Client token expired | Return 401; client must re-pair |
| Stream concurrency exceeded | Return 429 with `Retry-After` header |

---

## Logging Strategy

- **Library:** Python `logging` module → structured JSON logs
- **Level:** INFO in prod, DEBUG in dev
- **Outputs:** Console (stdout) + rotating file (`~/.fluxora/logs/server.log`)
- **Key events to log:** Stream start/end, library scans, auth events, FFmpeg errors
