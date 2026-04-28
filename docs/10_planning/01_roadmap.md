# Project Roadmap & Milestones

> **Category:** Planning  
> **Status:** Active — Updated 2026-04-28 (Phase 3 complete)

---

## Development Phases

### Phase 1 — Core Infrastructure
> **Goal:** Server boots, client connects on LAN, can stream a file

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| FastAPI server scaffolding | Must | ✅ Done | `main.py`, all routers, db setup |
| SQLite schema + migrations | Must | ✅ Done | Migrations 001–003; WAL mode |
| Client pairing + auth tokens | Must | ✅ Done | HMAC-SHA256, full pairing state machine |
| mDNS/Zeroconf LAN broadcast | Must | ✅ Done | `_fluxora._tcp.local.` |
| Library CRUD + scan API | Must | ✅ Done | `GET/POST/DELETE /library`, scan endpoint |
| `GET /api/v1/files` endpoint | Must | ✅ Done | List + filter by library |
| Basic FFmpeg HLS streaming | Must | ✅ Done | `POST /stream/start`, HLS segment serving |
| WebSocket status channel | Must | ✅ Done | Token auth, ping/pong, progress updates |
| Flutter client project setup | Must | ✅ Done | Clean Architecture structure, DI, router |
| mDNS discovery in Flutter | Must | ✅ Done | `multicast_dns` + manual IP entry |
| File browser UI in Flutter | Must | ✅ Done | Library grid + file list |
| HLS playback in Flutter | Must | ✅ Done | `media_kit` v1.2.6 — full player screen with auth headers, stream start/stop |

**Target:** Working LAN stream, file browser, basic connection

---

### Phase 2 — Auth, Library & Polish
> **Goal:** Secure pairing, media libraries with metadata, polished UI

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| Client pairing + auth tokens | Must | ✅ Done | `POST /auth/request-pair` flow |
| PC Control Panel (Flutter Desktop) | Must | ✅ Done | Dashboard + Clients + Library + Settings screens |
| Library manager + scan API | Should | ✅ Done | Directory indexing, file count |
| TMDB metadata integration | Should | ✅ Done | Migration 004/005; title, overview, poster_url, 46 tests ✅ |
| Library UI in Flutter client | Should | ✅ Done | Grid with TMDB poster thumbnails |
| Playback resume (progress tracking) | Should | ✅ Done | `resume_sec` via WS + `last_progress_sec` DB field |
| UI design system + dark theme | Should | ✅ Done | `AppColors`, `AppTypography`, `AppSizes` in `fluxora_core` |
| Desktop Settings screen | Should | ✅ Done | Configurable server URL persisted via `flutter_secure_storage` |

**Target:** Production-quality LAN experience with auth + library

---

### Phase 3 — Internet Streaming (WebRTC)
> **Goal:** Stream works when away from home  
> **Note:** Originally Phase 3 in the plan; TMDB + Resume was completed as part of Phase 2 polish.

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| WebRTC signaling server | Must | ✅ Done | `WS /api/v1/ws/signal` — auth, SDP relay, ICE forwarding, 8 tests ✅ |
| Flutter WebRTC integration | Must | ✅ Done | `flutter_webrtc 1.4.1`; `WebRtcSignalingService` + `PlayerCubit` smart-path (WebRTC→HLS fallback, 8 s timeout) |
| STUN/TURN configuration | Must | ✅ Done | Google STUN default; TURN via env vars (server-side ready) |
| Smart path selection (LAN vs WebRTC) | Must | ✅ Done | `NetworkPathDetector` /24 subnet check; LAN → HLS direct, WAN → WebRTC |
| Connection quality monitoring | Should | ✅ Done | `_handleSignalingDegradation` in `PlayerCubit`; ICE failure → badge switches HLS + signaling closed; `_readyOnce` guard prevents resume banner re-fire |
| Player transport badge | Should | ✅ Done | `_TransportBadge` chip — HLS/WebRTC, auto-hides after 5 s |

**Target:** Full remote streaming over internet

---

### Phase 4 — Monetization
> **Goal:** Tier system live, upgrade flows working

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| Subscription tier enforcement | Must | ✅ Done | `user_settings.subscription_tier` + `GET/PATCH /api/v1/settings`; `require_local_caller`; 9 tests ✅ |
| License key / payment validation | Must | 🔵 Partial | Key stored in DB; format-only validation; payment provider integration TBD |
| Upgrade prompt UI | Should | ✅ Done | Mobile: `PlayerTierLimit` state + `_TierLimitView` on 429; Desktop: tier selector + stream limit badge in Settings |
| Free/Plus/Pro/Ultimate tier limits | Must | ✅ Done | Tier change auto-updates `max_concurrent_streams`; stream router reads from DB (not config); migration 007 aligns existing rows |

**Tier Breakdown:**
| Tier | Price | Stream Limit | Features |
|------|-------|-------------|---------|
| Free | $0 | 1 concurrent | File browser, basic streaming |
| Plus | $4.99/mo | 3 concurrent | Library, metadata, TMDB |
| Pro | $9.99/mo | 10 concurrent | AI org, hardware encode |
| Ultimate | $19.99/mo | Unlimited | All features, priority support |

---

### Phase 5 — Advanced Features
> **Goal:** Power user features for Pro/Ultimate tier

| Feature | Priority | Notes |
|---------|----------|-------|
| Hardware encoding (NVENC/VAAPI) | Nice-to-have | GPU transcoding for Pro |
| AI file organization | Nice-to-have | Auto-tag, rename, categorize |
| End-to-end encryption | Should | E2E for internet streams |
| Multi-user / family sharing | Nice-to-have | Shared library access |
| TV/casting support (Chromecast) | Nice-to-have | Future platform |
| iOS/Android background streaming | Should | Foreground service |

---

## Milestone Overview

| Milestone | Phase | Status |
|-----------|-------|--------|
| M1 — Architecture & Docs Complete | 0 | ✅ Done |
| M1.5 — Monorepo Scaffold Complete | 0 | ✅ Done |
| M2 — LAN Streaming MVP | 1 | ✅ Done |
| M3 — Auth + Library + TMDB + Resume | 2 | ✅ Done |
| M3.5 — Desktop Control Panel Parity (incl. Settings) | 2 | ✅ Done |
| M4 — Internet Streaming | 3 | ✅ Done |
| M5 — Monetization Live | 4 | 🔄 In Progress |
| M6 — Advanced Features | 5 | ⬜ Future |

---

## Project Repository Structure (Live)

```
Fluxora/
├── apps/
│   ├── server/              # Python FastAPI backend + FFmpeg HLS engine
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── pyproject.toml
│   │   ├── Dockerfile
│   │   ├── fluxora_server.spec
│   │   ├── routers/         # auth, files, library, stream, ws
│   │   ├── services/        # ffmpeg, library, discovery, auth, webrtc
│   │   ├── models/          # Pydantic models
│   │   ├── database/        # db.py + migrations/
│   │   ├── utils/
│   │   └── tests/
│   ├── mobile/              # Flutter mobile client (Android + iOS)
│   │   ├── lib/
│   │   │   ├── core/        # DI, router
│   │   │   ├── features/    # connect, library, player, settings
│   │   │   └── shared/      # widgets, theme
│   │   └── pubspec.yaml
│   └── desktop/             # Flutter desktop control panel
│       ├── lib/
│       │   ├── core/        # DI, router
│       │   ├── features/    # dashboard, library, clients, activity,
│       │   │               #   transcoding, logs, settings
│       │   └── shared/      # widgets, theme
│       └── pubspec.yaml
├── packages/
│   └── fluxora_core/        # Shared Dart — entities, network, storage, tokens
├── docs/                    # All project documentation
├── scripts/                 # Build + release automation
├── .github/workflows/       # Path-scoped CI (server / mobile / desktop)
├── AGENT_LOG.md             # Append-only agent session log
├── CLAUDE.md                # AI agent rules and context
├── DESIGN.md                # Design system (Google Stitch spec)
└── README.md
```
