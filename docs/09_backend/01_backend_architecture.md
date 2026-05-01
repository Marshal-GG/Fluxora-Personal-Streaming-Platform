# Backend Architecture

> **Category:** Backend  
> **Status:** Active - Updated 2026-05-01 (Phase 5: orders router, transcoding settings DB-driven, hardware encoding, logs endpoint, live system stats + storage breakdown, info actions, conditional Sentry init, `/healthz` + `remote_url` on `/info`, CF Tunnel real-IP / HLS-block / admin-hardening middlewares for public routing; legacy 4-part license keys removed; Groups CRUD + stream-gate; Profile endpoints; 174 tests)

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
│       ├── 008_polar_orders.sql # paid Polar order idempotency + generated keys
│       ├── 009_order_customer_email.sql # adds customer_email to polar_orders
│       ├── 010_transcoding_settings.sql # adds transcoding_encoder/preset/crf to user_settings
│       ├── 011_groups.sql              # groups, group_members, group_restrictions tables + idx_group_members_client
│       └── 012_profile_fields.sql      # adds display_name, email, avatar_path, profile_created_at, last_login_at to user_settings
│
├── routers/
│   ├── info.py             # GET /api/v1/info, /info/logs, /info/stats; POST /info/restart, /info/stop ✅
│   ├── auth.py             # /auth/* ✅ (request-pair, status, approve, reject, revoke)
│   ├── deps.py             # validate_token, validate_token_or_local, require_local_caller FastAPI dependencies ✅
│   ├── files.py            # GET/POST(upload)/DELETE /api/v1/files; validate_token_or_local ✅
│   ├── library.py          # GET/POST /api/v1/library, GET/DELETE /{id}, POST /{id}/scan, GET /storage-breakdown; validate_token_or_local ✅
│   ├── stream.py           # GET /sessions, POST /start/{id}, PATCH /{id}/progress, GET/{id}, DELETE/{id} + hls_router; stream-gate hook calls group_service ✅
│   ├── ws.py               # WS /status (token auth + ping/pong + progress), WS /stats (live system stats) ✅
│   ├── signal.py           # WS /signal: SDP offer/answer + ICE relay ✅
│   ├── settings.py         # GET/PATCH /api/v1/settings; require_local_caller ✅
│   ├── orders.py           # GET /api/v1/orders; require_local_caller; owner license key retrieval ✅
│   ├── groups.py           # GET/POST /api/v1/groups, GET/PATCH/DELETE /{id}, GET/POST /{id}/members, DELETE /{id}/members/{cid}; mixed auth ✅
│   ├── profile.py          # GET/PATCH /api/v1/profile; require_local_caller ✅
│   └── webhook.py          # POST /api/v1/webhook/polar; Standard Webhooks signature ✅
│
│   ├── services/
│   │   ├── ffmpeg_service.py   # FFmpeg subprocess management, HLS output ✅
│   │   ├── library_service.py  # Library + file CRUD + scan_library ✅
│   │   ├── discovery_service.py # mDNS/Zeroconf broadcasting ✅
│   │   ├── auth_service.py     # HMAC-SHA256 tokens, pairing state machine ✅
│   │   ├── webrtc_service.py   # aiortc RTCPeerConnection registry; SDP/ICE handling; graceful teardown ✅
│   │   ├── settings_service.py # GET/PATCH user_settings; tier→max_streams mapping; _enrich_license() ✅
│   │   ├── license_service.py  # HMAC-SHA256 key gen/validation; FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG> format; CLI generator ✅
│   │   ├── webhook_service.py  # Polar signature validation + paid-order license issuance ✅
│   │   ├── tmdb_service.py     # TMDB REST API search; enriches media_files after scan ✅
│   │   ├── group_service.py    # Group CRUD, member management, stream-gate (get_effective_restrictions + reason_to_deny) ✅
│   │   ├── profile_service.py  # get_profile(db) + update_profile(db, ...); avatar_letter computation ✅
│   │   └── system_stats_service.py # CPU/RAM/network/uptime/IP/internet probe; backs /info/stats + /ws/stats ✅
│
│   ├── models/
│   │   ├── media_file.py       # MediaFileResponse Pydantic schema ✅
│   │   ├── library.py          # LibraryResponse, CreateLibraryBody ✅
│   │   ├── client.py           # Client Pydantic schemas ✅
│   │   ├── stream_session.py   # StreamStartResponse, StreamSessionResponse ✅
│   │   ├── settings.py         # UserSettingsResponse (incl. license_status, license_tier, transcoding fields), UpdateSettingsBody ✅
│   │   ├── order.py            # PolarOrderItem, PolarOrderListResponse ✅
│   │   ├── profile.py          # ProfileResponse (avatar_letter computed), ProfileUpdate ✅
│   │   └── group.py            # TimeWindow, GroupRestrictions, GroupResponse, GroupCreate, GroupUpdate, GroupMemberAdd; GroupStatus ✅
│
│   └── tests/
│       ├── conftest.py          # test_db + client fixtures; reset_rate_limits autouse
│       ├── test_auth.py         # 13 tests — info + pairing flow + localhost restriction + client listing ✅
│       ├── test_library.py      # 8 tests — library CRUD ✅
│       ├── test_files.py        # 6 tests — file listing + filtering (validate_token_or_local) ✅
│       ├── test_stream.py       # 10 tests — stream start/stop/HLS (mocked FFmpeg) ✅
│       ├── test_ws.py           # 4 tests — WebSocket auth + pong ✅
│       ├── test_signal.py       # 8 tests — WS signaling auth + SDP/ICE protocol ✅
│       ├── test_settings.py     # 9 tests — GET/PATCH settings + tier concurrency + 429 enforcement + license_status ✅
│       ├── test_license_service.py # 22 tests — key validation (happy/expired/bad-sig/advisory/malformed/4-part-rejected) + generation ✅
│       ├── test_orders.py       # 4 tests — GET /orders localhost restriction + response schema ✅
│       ├── test_tmdb_service.py # 5 tests — TMDB search (movie/TV/person/network-error/missing-poster) ✅
│       ├── test_webhook.py      # 19 tests — Polar signature, paid orders, router responses ✅
│       ├── test_info_stats.py   # 5 tests — REST /info/stats shape + active streams + WS /stats localhost & non-localhost auth ✅
│       ├── test_storage_breakdown.py # 3 tests — empty / aggregation by type / missing-root capacity exclusion ✅
│       ├── test_info_actions.py # 4 tests — /info/restart + /info/stop localhost (202) and non-localhost (403) ✅
│       ├── test_groups.py       # 16 tests — CRUD, member management, auth split, stream-gate enforcement ✅
│       └── test_profile.py      # 9 tests — GET/PATCH profile localhost restriction + response schema + avatar_letter computation ✅

Total: 174 tests passing ✅ (as of 2026-05-01)
```

---

## Service Map

| Service | Responsibility | Key Functions |
|---------|---------------|---------------|
| `ffmpeg_service` ✅ | Spawn FFmpeg, manage HLS output, cleanup segments; reads transcoding encoder/preset/CRF from DB; supports software (libx264) and hardware (NVENC/QSV/VAAPI) | `start_stream()`, `stop_stream()`, `cleanup_session_dir()`, `is_running()` |
| `library_service` ✅ | Library + media file CRUD; TMDB enrichment (Phase 2); storage breakdown (Dashboard donut) | `list_libraries()`, `get_library()`, `create_library()`, `delete_library()`, `list_files()`, `get_file()`, `get_storage_breakdown()` |
| `discovery_service` ✅ | Broadcast `_fluxora._tcp.local.` via mDNS on LAN — uses `AsyncZeroconf` to avoid blocking FastAPI's event loop | `start_discovery()` (async), `stop_discovery()` (async) |
| `auth_service` ✅ | Token generation (HMAC-SHA256), pairing state machine, token validation | `create_pair_request()`, `approve_client()`, `reject_client()`, `revoke_client()`, `get_trusted_client_by_token()` |
| `webrtc_service` ✅ | Manage `RTCPeerConnection` registry, ICE/STUN/TURN, graceful teardown | `create_peer_connection()`, `handle_offer()`, `close_connection()` |
| `license_service` ✅ | HMAC-SHA256 signed key gen/validation; format `FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>`; advisory mode when secret absent | `validate_key()`, `generate_key()`, `LicenseResult` |
| `webhook_service` ✅ | Verify Polar Standard Webhooks signatures; issue idempotent license keys for paid orders without logging PII | `verify_polar_signature()`, `handle_order_paid()`, `handle_order_created()` |
| `orders router` ✅ | Owner-only view of all processed Polar orders + generated license keys for manual customer delivery | `GET /api/v1/orders` (localhost) |
| `system_stats_service` ✅ | psutil-backed live stats — CPU%, RAM, per-interface network rate (loopback excluded), uptime via `Process.create_time()`, LAN IP via UDP-socket trick, cached internet probe to `1.1.1.1:80`. Per-instance state so REST and WS subscribers don't collide. | `SystemStatsService.collect(db)` returns `StatsPayload` |
| `group_service` ✅ | Client-group CRUD, member management, and stream-gate enforcement. `get_effective_restrictions()` collects all active groups a client belongs to and intersects their restrictions (library allow-list, bandwidth min, time-window AND-combination). `reason_to_deny()` returns a denial string or `None`; called by `routers/stream.py` before the tier-concurrency check. | `list_groups()`, `get_group()`, `create_group()`, `update_group()`, `delete_group()`, `add_member()`, `remove_member()`, `list_members()`, `get_effective_restrictions()`, `reason_to_deny()` |
| `profile_service` ✅ | Reads and writes operator profile metadata from the `user_settings` singleton. Computes `avatar_letter` on every read (not stored). Pass `""` to clear a field; pass `None` to leave it unchanged. | `get_profile(db)` → `ProfileResponse`, `update_profile(db, *, display_name?, email?)` → `ProfileResponse` |

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
