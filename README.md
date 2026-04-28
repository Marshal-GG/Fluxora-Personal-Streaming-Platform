# Fluxora

> **"Plex meets Syncthing"** — A hybrid file streaming and syncing system  
> **Status:** Phases 1–3 complete ≤ Phase 4 (Monetization) in progress | Last Updated: 2026-04-28

---

## What is Fluxora?

Fluxora is a self-hosted, cross-platform media streaming system where your **PC is the server** and your **phone/tablet is the client**. It intelligently switches between **LAN (direct, high-speed)** and **Internet (WebRTC)** connections — automatically, with no port forwarding required.

| Layer | Technology |
|-------|-----------|
| Backend | Python + FastAPI + FFmpeg (HLS streaming) |
| Database | SQLite (local, embedded, WAL mode) |
| LAN Discovery | Zeroconf / mDNS (`_fluxora._tcp.local`) |
| Internet Transport | WebRTC (STUN/TURN) — Phase 3 |
| Mobile Client | Flutter — Android + iOS |
| Desktop Control Panel | Flutter — Windows, macOS, Linux |
| Shared Dart Logic | `packages/fluxora_core` (local package) |

---

## Current Status

**M2 — LAN Streaming MVP is complete.** You can run the server, discover it on your phone, pair, browse your media library, and stream a file — all on LAN with no internet required.

| Component | Status | Notes |
|-----------|--------|-------|
| FastAPI server | ✅ Done | All routers incl. settings, mDNS, FFmpeg HLS, WebSocket, WebRTC signaling; 60 tests |
| `fluxora_core` package | ✅ Done | Entities, ApiClient, SecureStorage, design tokens |
| Flutter mobile — connect | ✅ Done | mDNS auto-discovery + manual IP; Android MulticastLock |
| Flutter mobile — auth | ✅ Done | Full pairing flow; token in SecureStorage |
| Flutter mobile — library | ✅ Done | Library grid + file browser + TMDB poster thumbnails |
| Flutter mobile — player | ✅ Done | `media_kit` HLS player; WebRTC smart-path; transport badge; resume; tier limit UI |
| Flutter desktop | ✅ Done | Dashboard + Clients + Settings screens; 23 tests |
| Internet streaming | ✅ Done | WebRTC P2P + HLS fallback; LAN bypass; ICE degradation monitoring |
| Monetization (tier enforcement) | 🔵 In Progress | Tiers + concurrency limits live; license key stored; payment provider TBD |

---

## Repository Structure

```
Fluxora/
├── apps/
│   ├── server/              # Python FastAPI backend + FFmpeg HLS engine
│   ├── mobile/              # Flutter mobile client (Android + iOS)
│   ├── desktop/             # Flutter desktop control panel (Win/macOS/Linux)
│   ├── web_landing/         # Next.js static landing page → fluxora.marshalx.dev
│   └── web_app/             # Flutter Web dashboard (Phase 3 — not started)
├── packages/
│   └── fluxora_core/        # Shared Dart entities, network client, design tokens
├── docs/                    # All project documentation (11 categories)
│   ├── 00_overview/         # Index, overview, folder structure
│   ├── 01_product/          # Vision, requirements, user stories
│   ├── 02_architecture/     # System design, tech stack, component diagrams
│   ├── 03_data/             # Data models, schema, data flows
│   ├── 04_api/              # REST + WebSocket API contracts
│   ├── 05_infrastructure/   # Deployment, distribution, CI/CD
│   ├── 06_security/         # Auth, threat model, security policies
│   ├── 07_ai_ml/            # AI features (Phase 5)
│   ├── 08_frontend/         # Flutter architecture and screen map
│   ├── 09_backend/          # FastAPI structure and service map
│   ├── 10_planning/         # Roadmap, ADRs, open questions
│   └── 11_design/           # Brand system, color palette, UI concepts
├── functions/               # Firebase Cloud Functions (Phase 3 stubs)
├── scripts/                 # Build and release automation
├── .github/
│   └── workflows/           # Path-scoped CI (server / mobile / desktop / web)
├── firebase.json            # Firebase Hosting + Functions config
├── .firebaserc              # Firebase project alias
├── AGENT_LOG.md             # Append-only log of all agent work sessions
├── CLAUDE.md                # AI agent onboarding and mandatory rules
├── DESIGN.md                # Design system (Google Stitch spec)
└── README.md
```

---

## Development Phases

| Phase | Goal | Status |
|-------|------|--------|
| 0 | Architecture, docs, monorepo scaffold | ✅ Complete |
| 1 | FastAPI server, mDNS, HLS streaming, Flutter mobile client, HLS player | ✅ Complete |
| 2 | Desktop control panel, TMDB metadata, playback resume | ✅ Complete |
| 3 | WebRTC internet streaming, smart-path LAN bypass, transport badge | ✅ Complete |
| 4 | Tier enforcement, license key, upgrade UI | 🔵 In Progress |
| 5 | Hardware transcoding, advanced client management | 🔲 Planned |
| 6 | AI recommendations, public release | 🔲 Planned |

---

## Quick Start (Development)

### Server
```bash
cd apps/server
pip install -e .[dev]
uvicorn main:app --reload --host 0.0.0.0 --port 8080
```
Requires `TOKEN_HMAC_KEY` in `%APPDATA%\Fluxora\.env` (Windows) or `~/.fluxora/.env` (macOS/Linux).

### Mobile
```bash
cd apps/mobile
flutter pub get
flutter run          # connects to a physical device or emulator
```

---

## Quick Links

- [Vision & Differentiators](docs/01_product/01_vision.md)
- [System Architecture](docs/02_architecture/01_system_overview.md)
- [Tech Stack](docs/02_architecture/02_tech_stack.md)
- [API Contracts](docs/04_api/01_api_contracts.md)
- [Roadmap](docs/10_planning/01_roadmap.md)
- [Design System](DESIGN.md)
- [Agent Work Log](AGENT_LOG.md)

---

## For AI Agents

Read [`CLAUDE.md`](CLAUDE.md) before touching any code.  
Read [`AGENT_LOG.md`](AGENT_LOG.md) to understand what has been done and what comes next.
