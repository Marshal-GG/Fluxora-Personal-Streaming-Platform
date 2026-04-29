# Backend Architecture

> **Category:** Backend  
> **Status:** Active - Updated 2026-04-29 (Phase 4: license verification + Polar webhook implemented)

---

## Framework & Stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.11+ |
| Framework | FastAPI |
| ASGI Server | Uvicorn |
| Streaming | FFmpeg (subprocess) → HLS |
| Database | SQLite (via `aiosqlite` for async) |
| LAN Discovery | `zeroconf` Python library — `AsyncZeroconf` (async-safe) |
| WebRTC Signaling | `aiortc 1.9.0` — RTCPeerConnection, ICE, DataChannel |
| Metadata | TMDB REST API |
| Payments | Polar Standard Webhooks |
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
│       ├── 003_client_status.sql  # clients.status column
│       ├── 004_tmdb_metadata.sql  # title, overview, poster_url on media_files
│       ├── 005_resume_progress.sql # last_progress_sec on media_files
│       ├── 006_settings_license.sql # license_key on user_settings
│       ├── 007_align_tier_limits.sql # corrects max_concurrent_streams per tier
│       └── 008_polar_orders.sql # paid Polar order idempotency + generated keys
│
├── routers/
│   ├── info.py             # GET /api/v1/info ✅
│   ├── auth.py             # /auth/* ✅ (request-pair, status, approve, reject, revoke)
│   ├── deps.py             # validate_token + require_local_caller FastAPI dependencies ✅
│   ├── files.py            # GET /api/v1/files, GET /api/v1/files/{id} ✅
│   ├── library.py          # GET/POST /api/v1/library, GET/DELETE /{id}, POST /{id}/scan ✅
│   ├── stream.py           # POST /start/{id}, GET/{id}, DELETE/{id} + hls_router ✅
│   ├── ws.py               # WS /status: token auth + ping/pong + progress ✅
│   ├── signal.py           # WS /signal: SDP offer/answer + ICE relay ✅
│   ├── settings.py         # GET/PATCH /api/v1/settings; require_local_caller ✅
│   └── webhook.py          # POST /api/v1/webhook/polar; Standard Webhooks signature ✅
│
│   ├── services/
│   │   ├── ffmpeg_service.py   # FFmpeg subprocess management, HLS output ✅
│   │   ├── library_service.py  # Library + file CRUD + scan_library ✅
│   │   ├── discovery_service.py # mDNS/Zeroconf broadcasting ✅
│   │   ├── auth_service.py     # HMAC-SHA256 tokens, pairing state machine ✅
│   │   ├── webrtc_service.py   # aiortc RTCPeerConnection registry; SDP/ICE handling; graceful teardown ✅
│   │   ├── settings_service.py # GET/PATCH user_settings; tier→max_streams mapping; _enrich_license() ✅
│   │   ├── license_service.py  # HMAC-SHA256 key gen/validation; FLUXORA-<TIER>-<EXPIRY>-<SIG> format; CLI generator ✅
│   │   ├── webhook_service.py  # Polar signature validation + paid-order license issuance ✅
│   │   └── tmdb_service.py     # TMDB REST API search; enriches media_files after scan ✅
│
│   ├── models/
│   │   ├── media_file.py       # MediaFileResponse Pydantic schema ✅
│   │   ├── library.py          # LibraryResponse, CreateLibraryBody ✅
│   │   ├── client.py           # Client Pydantic schemas ✅
│   │   ├── stream_session.py   # StreamStartResponse, StreamSessionResponse ✅
│   │   └── settings.py         # UserSettingsResponse (incl. license_status, license_tier), UpdateSettingsBody ✅
│
│   └── tests/
│       ├── conftest.py          # test_db + client fixtures; reset_rate_limits autouse
│       ├── test_auth.py         # 13 tests — info + pairing flow + localhost restriction + client listing ✅
│       ├── test_library.py      # 8 tests — library CRUD ✅
│       ├── test_files.py        # 6 tests — file listing + filtering ✅
│       ├── test_stream.py       # 10 tests — stream start/stop/HLS (mocked FFmpeg) ✅
│       ├── test_ws.py           # 4 tests — WebSocket auth + pong ✅
│       ├── test_signal.py       # 8 tests — WS signaling auth + SDP/ICE protocol ✅
│       ├── test_settings.py     # 9 tests — GET/PATCH settings + tier concurrency + 429 enforcement + license_status ✅
│       ├── test_license_service.py # 20 tests — key validation (happy/expired/bad-sig/advisory/malformed) + generation ✅
│       ├── test_tmdb_service.py # 5 tests — TMDB search (movie/TV/person/network-error/missing-poster) ✅
│       └── test_webhook.py      # 19 tests — Polar signature, paid orders, router responses ✅
```

---

## Service Map

| Service | Responsibility | Key Functions |
|---------|---------------|---------------|
| `ffmpeg_service` ✅ | Spawn FFmpeg, manage HLS output, cleanup segments | `start_stream()`, `stop_stream()`, `cleanup_session_dir()`, `is_running()` |
| `library_service` ✅ | Library + media file CRUD; TMDB enrichment (Phase 2) | `list_libraries()`, `get_library()`, `create_library()`, `delete_library()`, `list_files()`, `get_file()` |
| `discovery_service` ✅ | Broadcast `_fluxora._tcp.local.` via mDNS on LAN — uses `AsyncZeroconf` to avoid blocking FastAPI's event loop | `start_discovery()` (async), `stop_discovery()` (async) |
| `auth_service` ✅ | Token generation (HMAC-SHA256), pairing state machine, token validation | `create_pair_request()`, `approve_client()`, `reject_client()`, `revoke_client()`, `get_trusted_client_by_token()` |
| `webrtc_service` ✅ | Manage `RTCPeerConnection` registry, ICE/STUN/TURN, graceful teardown | `create_peer_connection()`, `handle_offer()`, `close_connection()` |
| `license_service` ✅ | HMAC-SHA256 signed key gen/validation; format `FLUXORA-<TIER>-<EXPIRY>-<SIG>`; advisory mode when secret absent | `validate_key()`, `generate_key()`, `LicenseResult` |
| `webhook_service` ✅ | Verify Polar Standard Webhooks signatures; issue idempotent license keys for paid orders without logging PII | `verify_polar_signature()`, `handle_order_paid()`, `handle_order_created()` |

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
| Polar | Payment webhooks for license key issuance | Standard Webhooks HMAC secret |

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
| Polar webhook invalid signature | Return 403 before parsing JSON |
| Polar webhook secret missing | Return 501 so production misconfiguration is visible |

---

## Logging Strategy

- **Library:** Python `logging` module → structured JSON logs
- **Level:** INFO in prod, DEBUG in dev
- **Outputs:** Console (stdout) + rotating file (`~/.fluxora/logs/server.log`)
- **Key events to log:** Stream start/end, library scans, auth events, FFmpeg errors
