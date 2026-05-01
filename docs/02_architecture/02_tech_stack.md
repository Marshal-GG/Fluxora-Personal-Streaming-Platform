# Tech Stack

> **Category:** Architecture  
> **Status:** Active - Updated 2026-04-29 (Polar webhooks added)

---

## Stack Summary

| Layer | Technology | Version / Notes |
|-------|-----------|----------------|
| Backend Language | Python | 3.11+ |
| Backend Framework | FastAPI | Async, high-performance |
| ASGI Server | Uvicorn | Production server for FastAPI |
| Streaming Engine | FFmpeg | HLS transcoding (libx264 / NVENC / QSV / VAAPI) |
| Database | SQLite | Local metadata + library index, WAL mode |
| Rate Limiting | `slowapi` | Per-IP rate limiting on hot endpoints |
| System Stats | `psutil` | CPU / RAM / network / uptime probes for `/api/v1/info/stats` |
| Local Discovery | Zeroconf (mDNS) | Auto-pairing on LAN |
| Internet Transport | WebRTC | STUN/TURN for NAT traversal |
| Public Routing | Cloudflare Tunnel | `fluxora-api.marshalx.dev` — Phases 1–4 complete (tunnel `fluxora-home` live; CF middlewares, `/healthz`, `remote_url` on `/info`, dual-base `ApiClient`, mobile pairing persists `remote_url`). Phase 5 desktop UI pending. See [`docs/05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md) |
| Frontend Framework | Flutter 3.32 (Dart 3.8) | Cross-platform; pinned in CI |
| State Management | `flutter_bloc` (BLoC/Cubit) | Confirmed at Phase 1 mobile implementation |
| Metadata API | TMDB API | Movie/TV show metadata |
| Payment Webhooks | Polar Standard Webhooks | Paid-order license issuance |
| PC Control Panel | Flutter Desktop | Electron alternative |

---

## Backend

### FastAPI + Uvicorn
- Async REST API endpoints for file browsing, streaming, library management
- WebSocket support for real-time status updates (active streams, clients)
- Middleware: CORS, auth token validation

### FFmpeg Pipeline
- Transcodes media files to **HLS (HTTP Live Streaming)** format
- Creates `.m3u8` playlist + `.ts` segments
- Adaptive quality based on client bandwidth detection
- Hardware acceleration support (Phase 5 — NVENC/VAAPI)

### SQLite
- Local-first, no external DB server needed
- Stores: library index, file metadata, user sessions, settings
- Migrations managed manually (lightweight)

---

## Frontend (Flutter)

### Architecture: Clean Architecture
```
lib/
├── domain/           # Entities, use cases, repository interfaces
├── data/             # Repository implementations, data sources, models
└── presentation/     # UI screens, widgets, state management (BLoC/Riverpod)
```

### Key Packages — `fluxora_core` (implemented)
| Package | Purpose |
|---------|---------|
| `dio ^5.4.0` | HTTP client (`ApiClient`) |
| `flutter_secure_storage ^9.0.0` | Encrypted token/URL storage |
| `freezed_annotation ^2.4.1` | Immutable data class codegen |
| `json_annotation ^4.9.0` | JSON serialization annotations |
| `logger ^2.7.0` | Structured logging |
| `connectivity_plus ^7.1.1` | Network state monitoring |

### Key Packages — `apps/mobile` (implemented — Phase 1)
| Package | Purpose |
|---------|---------|
| `flutter_bloc ^9.1.1` | BLoC / Cubit state management |
| `get_it ^7.6.7` | Dependency injection |
| `go_router ^13.0.0` | Declarative routing with async auth guard |
| `multicast_dns ^0.3.2` | LAN discovery — PTR→SRV→A resolution |
| `flutter_secure_storage ^9.0.0` | Secure token + server URL storage |
| `logger ^2.7.0` | Structured logging |

### Key Packages — deferred (Phase 2+)
| Package | Phase | Purpose |
|---------|-------|---------|
| `media_kit` | Phase 2 | HLS video playback (replaces `better_player` — incompatible with AGP 8+) |
| `flutter_webrtc` (v1.x+) | Phase 3 | WebRTC internet streaming (v0.10.x uses removed v1 Flutter plugin API) |

---

## Networking

### LAN Path (Zeroconf/mDNS)
- Server broadcasts mDNS service on local network
- Client auto-discovers server IP — zero configuration required
- High-speed, low-latency direct HTTP connection

### Internet Path (WebRTC)
- STUN server: resolves public IP/port (e.g., Google STUN `stun.l.google.com:19302`)
- TURN server: relay fallback when direct P2P is blocked by firewall
- Signaling server: lightweight service to exchange WebRTC offer/answer

---

## External Services

| Service | Usage | Tier |
|---------|-------|------|
| TMDB API | Movie/TV metadata, posters, descriptions | Free |
| STUN Server | WebRTC NAT traversal | Free (Google public) |
| TURN Server | WebRTC relay | Paid / self-hosted |
| Polar | Payment webhook events for license issuance | Paid provider / sandbox available |

---

## Technology Risks

| Technology | Risk | Mitigation |
|-----------|------|------------|
| WebRTC | Complex NAT traversal, mobile battery drain | TURN fallback; optimize connection lifecycle |
| FFmpeg transcoding | CPU-intensive, may lag on weak hardware | Hardware encoding (NVENC); queue management |
| SQLite | Not suited for multi-user concurrency | WAL mode; consider migration path to PostgreSQL for Pro |
| mDNS on mobile | iOS/Android may restrict multicast | Use fallback IP scan; manual server entry option |
