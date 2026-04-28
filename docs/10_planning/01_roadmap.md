# Project Roadmap & Milestones

> **Category:** Planning  
> **Status:** Active — Updated 2026-04-28

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

| Feature | Priority | Notes |
|---------|----------|-------|
| Client pairing + auth tokens | Must | `POST /auth/request-pair` flow |
| PC Control Panel (Flutter Desktop) | Must | ✅ Done — Dashboard + Clients screens (approve/reject/revoke) |
| Library manager + scan API | Should | Directory indexing |
| TMDB metadata integration | Should | Movies + TV |
| Library UI in Flutter client | Should | Grid with posters |
| Playback resume (progress tracking) | Should | `stream_sessions` |
| UI design system + dark theme | Should | Final visual polish |

**Target:** Production-quality LAN experience with auth + library

---

### Phase 3 — Internet Streaming (WebRTC)
> **Goal:** Stream works when away from home

| Feature | Priority | Notes |
|---------|----------|-------|
| WebRTC signaling server | Must | WS `/ws/signal` |
| Flutter WebRTC integration | Must | `flutter_webrtc` |
| STUN/TURN configuration | Must | Google STUN + TURN server |
| Smart path selection (LAN vs WebRTC) | Must | Auto-switching logic |
| Connection quality monitoring | Should | Detect degradation, switch paths |

**Target:** Full remote streaming over internet

---

### Phase 4 — Monetization
> **Goal:** Tier system live, upgrade flows working

| Feature | Priority | Notes |
|---------|----------|-------|
| Subscription tier enforcement | Must | DB + API middleware |
| License key / payment validation | Must | Integration TBD |
| Upgrade prompt UI | Should | In-app upsell |
| Free/Plus/Pro/Ultimate tier limits | Must | Stream concurrency, features |

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
| M3 — Auth + Library | 2 | ⬜ Planned |
| M4 — Internet Streaming | 3 | ⬜ Planned |
| M5 — Monetization Live | 4 | ⬜ Planned |
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
