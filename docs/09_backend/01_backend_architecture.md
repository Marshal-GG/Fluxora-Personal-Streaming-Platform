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
├── main.py                 # FastAPI app entry point + lifespan (DB, mDNS, HLS cleanup)
├── config.py               # Settings (BaseSettings), platform data dir, DB permissions
├── database/
│   ├── db.py               # aiosqlite connection pool, WAL mode, migration runner
│   └── migrations/
│       ├── 001_initial.sql  # libraries, media_files, clients, user_settings
│       ├── 002_sessions.sql # stream_sessions
│       └── 003_client_status.sql  # clients.status column
│
├── routers/
│   ├── info.py             # GET /api/v1/info ✅
│   ├── auth.py             # /auth/* ✅ (request-pair, status, approve, reject, revoke)
│   ├── deps.py             # validate_token + require_local_caller FastAPI dependencies ✅
│   ├── files.py            # GET /api/v1/files, GET /api/v1/files/{id} ✅
│   ├── library.py          # GET/POST /api/v1/library, GET/DELETE /{id}, POST /{id}/scan ✅
│   ├── stream.py           # POST /start/{id}, GET/{id}, DELETE/{id} + hls_router ✅
│   └── ws.py               # WS /status: token auth + ping/pong + progress ✅
│
├── services/
│   ├── ffmpeg_service.py   # FFmpeg subprocess management, HLS output ✅
│   ├── library_service.py  # Library + file CRUD + scan_library ✅
│   ├── discovery_service.py # mDNS/Zeroconf broadcasting ✅
│   ├── auth_service.py     # HMAC-SHA256 tokens, pairing state machine ✅
│   └── webrtc_service.py   # STUN/TURN/signaling (stub)
│
├── models/
│   ├── media_file.py       # MediaFileResponse Pydantic schema ✅
│   ├── library.py          # LibraryResponse, CreateLibraryBody ✅
│   ├── client.py           # Client Pydantic schemas ✅
│   ├── stream_session.py   # StreamStartResponse, StreamSessionResponse ✅
│   └── settings.py         # ServerInfo schema ✅
│
└── tests/
    ├── conftest.py          # test_db + client fixtures; reset_rate_limits autouse
    ├── test_auth.py         # 10 tests — info + pairing flow + localhost restriction ✅
    ├── test_library.py      # 8 tests — library CRUD ✅
    ├── test_files.py        # 6 tests — file listing + filtering ✅
    ├── test_stream.py       # 10 tests — stream start/stop/HLS (mocked FFmpeg) ✅
    └── test_ws.py           # 4 tests — WebSocket auth + pong ✅
```

---

## Service Map

| Service | Responsibility | Key Functions |
|---------|---------------|---------------|
| `ffmpeg_service` ✅ | Spawn FFmpeg, manage HLS output, cleanup segments | `start_stream()`, `stop_stream()`, `cleanup_session_dir()`, `is_running()` |
| `library_service` ✅ | Library + media file CRUD; TMDB enrichment (Phase 2) | `list_libraries()`, `get_library()`, `create_library()`, `delete_library()`, `list_files()`, `get_file()` |
| `discovery_service` ✅ | Broadcast `_fluxora._tcp.local.` via mDNS on LAN | `start_discovery()`, `stop_discovery()` |
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
