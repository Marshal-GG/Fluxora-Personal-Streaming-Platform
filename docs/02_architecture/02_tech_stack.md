# Tech Stack

> **Category:** Architecture  
> **Status:** Active — Sourced from Planning Session (2026-04-27)

---

## Stack Summary

| Layer | Technology | Version / Notes |
|-------|-----------|----------------|
| Backend Language | Python | 3.11+ |
| Backend Framework | FastAPI | Async, high-performance |
| ASGI Server | Uvicorn | Production server for FastAPI |
| Streaming Engine | FFmpeg | HLS transcoding, adaptive bitrate |
| Database | SQLite | Local metadata + library index |
| Local Discovery | Zeroconf (mDNS) | Auto-pairing on LAN |
| Internet Transport | WebRTC | STUN/TURN for NAT traversal |
| Frontend Framework | Flutter | Dart, cross-platform |
| Metadata API | TMDB API | Movie/TV show metadata |
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

### Key Packages — apps (planned)
| Package | Purpose |
|---------|---------|
| `flutter_bloc ^9.1.1` | State management |
| `get_it` | Dependency injection |
| `go_router` | Navigation |
| `better_player` / `media_kit` | HLS video playback |
| `multicast_dns` | LAN discovery (client-side) |
| `flutter_webrtc` | WebRTC for internet streaming |

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

---

## Technology Risks

| Technology | Risk | Mitigation |
|-----------|------|------------|
| WebRTC | Complex NAT traversal, mobile battery drain | TURN fallback; optimize connection lifecycle |
| FFmpeg transcoding | CPU-intensive, may lag on weak hardware | Hardware encoding (NVENC); queue management |
| SQLite | Not suited for multi-user concurrency | WAL mode; consider migration path to PostgreSQL for Pro |
| mDNS on mobile | iOS/Android may restrict multicast | Use fallback IP scan; manual server entry option |
