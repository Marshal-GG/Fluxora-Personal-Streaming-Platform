# Fluxora

> **"Plex meets Syncthing"** — A hybrid file streaming and syncing system  
> **Status:** Phase 1 server complete — Phase 1 mobile next | Last Updated: 2026-04-27

---

## What is Fluxora?

Fluxora is a self-hosted, cross-platform media streaming system where your **PC is the server** and your **phone/tablet is the client**. It intelligently switches between **LAN (direct, high-speed)** and **Internet (WebRTC)** connections — automatically, with no port forwarding required.

| Layer | Technology |
|-------|-----------|
| Backend | Python + FastAPI + FFmpeg (HLS streaming) |
| Database | SQLite (local, embedded, WAL mode) |
| LAN Discovery | Zeroconf / mDNS (`_fluxora._tcp.local`) |
| Internet Transport | WebRTC (STUN/TURN) |
| Mobile Client | Flutter — Android + iOS |
| Desktop Control Panel | Flutter — Windows, macOS, Linux |
| Shared Dart Logic | `packages/fluxora_core` (local package) |

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
│   ├── scaffold.ps1         # Initial project scaffolding (run once)
│   ├── build_server.ps1/.sh # PyInstaller builds
│   ├── build_mobile.sh      # Flutter APK + IPA builds
│   ├── build_desktop.sh     # Flutter desktop build
│   └── release.sh           # GitHub Release tagging
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
| 1 | FastAPI server, mDNS, HLS streaming, Flutter client setup, landing page | 🔵 In Progress (server ✅ · mobile 🔲) |
| 2 | Full library management, Flutter home + player screens | 🔲 Planned |
| 3 | WebRTC internet streaming, Firebase signaling, Flutter Web dashboard, subscriptions | 🔲 Planned |
| 4 | Hardware transcoding, advanced client management | 🔲 Planned |
| 5 | AI recommendations, public release | 🔲 Planned |

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
