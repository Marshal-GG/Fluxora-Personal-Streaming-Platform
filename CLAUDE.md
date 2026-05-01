# Fluxora — CLAUDE.md

> This file provides essential context for AI coding agents (Claude, Gemini, Copilot, etc.) working
> on the Fluxora codebase. Read this file fully before making any code changes.

---

## Table of Contents

1. [Mandatory Agent Rules](#mandatory-agent-rules)
2. [Hard Prohibitions](#hard-prohibitions)
3. [Documentation Update Protocol](#documentation-update-protocol)
4. [What is Fluxora?](#what-is-fluxora)
5. [Repository Layout](#repository-layout)
6. [Tech Stack](#tech-stack)
7. [Architecture: Core Concepts](#architecture-core-concepts)
8. [Architecture Rules — Never Break These](#architecture-rules)
9. [Database](#database)
10. [Database Migration Rules](#database-migration-rules)
11. [API Overview](#api-overview)
12. [Development Commands](#development-commands)
13. [Code Conventions](#code-conventions)
14. [Testing Discipline](#testing-discipline)
15. [Security Rules](#security-rules)
16. [Resource Cleanup Rules](#resource-cleanup-rules)
17. [Before You Are Done — Checklist](#before-you-are-done)
18. [Dependency Version Policy](#dependency-version-policy)
19. [API Key & Secrets Management](#api-key--secrets-management)
20. [Server Startup Initialization Order](#server-startup-initialization-order)
21. [Code Generation Policy](#code-generation-policy)
22. [WebSocket Rules](#websocket-rules)
23. [Firebase Integration Rules](#firebase-integration-rules)
24. [Rate Limiting](#rate-limiting)
25. [Offline Detection & Connectivity](#offline-detection--connectivity)
26. [PR / Code Review Checklist](#pr--code-review-checklist)
27. [Key Files to Read Before Specific Tasks](#key-files-to-read)
28. [Design System Reference](#design-system-reference)
29. [Phase Roadmap](#phase-roadmap)
30. [Known Risks & Gotchas](#known-risks--gotchas)
31. [Out of Scope (v1)](#out-of-scope-v1)
32. [Current Status](#current-status)

---

## Mandatory Agent Rules

> **Before writing a single line of code:**
> 1. Read `AGENT_LOG.md` — understand what has been done and what comes next.
> 2. Read the relevant `docs/` files for the area you are working in.
>
> **While writing code:**
> - If you change an API contract → update `docs/04_api/01_api_contracts.md`
> - If you change data models or the DB schema → update `docs/03_data/`
> - If you change the backend structure → update `docs/09_backend/01_backend_architecture.md`
> - If you change Flutter screens or navigation → update `docs/08_frontend/01_frontend_architecture.md`
> - If you change the tech stack or system design → update `docs/02_architecture/`
> - If you add/complete a roadmap milestone → update `docs/10_planning/01_roadmap.md`
> - If you add or change a UI component or design token → update `DESIGN.md`
> - If you add, remove, or modify any `.github/workflows/` file → update `docs/05_infrastructure/01_infrastructure.md`
>
> **Rule: code and docs must always be in sync. Never leave docs stale.**
>
> **Before ending your session:**
> 1. Append a new entry to `AGENT_LOG.md` using the template at the top of that file.
> 2. List every file you created or modified (code **and** docs) in the entry's table.
> 3. List every `docs/` file you updated in the "Docs Updated" section of the log entry.
> 4. Write a clear "Next Agent Should" section so the next agent can resume without reading chat history.
> 5. **Report Issues:** If you discover any issues, security errors, or areas for proper fixes/improvements during your work or audits, you MUST explicitly report them to the user. Do not keep them to yourself.
> 6. **Proactive Suggestions:** Always proactively offer 2-3 suggestions to the user on what to work on next based on the `AGENT_LOG.md` status, project roadmap, and your findings before ending your turn. Do not wait to be prompted.
>
> **AGENT_LOG.md is append-only. Never edit or delete past entries.**
> **Log Rotation Policy:** If `AGENT_LOG.md` exceeds ~1000 lines, you MUST rotate it: move it to `docs/logs/AGENT_LOG_archive_XX.md`, read the archived log to summarize its progress and next steps, and start a fresh `AGENT_LOG.md` with the summary at the top and the entry template.


---

## Documentation Update Protocol

> **When the user asks you to update docs — or when any code change requires a doc update — follow this protocol in full. Never stop after updating just the obvious file.**

### Step 1 — Identify every file that could be affected

Before writing a single word, run a mental (or literal `grep`) sweep against this checklist:

| File | Update when... |
|------|---------------|
| `docs/04_api/01_api_contracts.md` | Any endpoint added, removed, renamed, or response schema changed |
| `docs/03_data/01_data_models.md` | Any entity field added, removed, or renamed |
| `docs/03_data/02_database_schema.md` | Any table or column added, removed, or altered |
| `docs/03_data/03_data_flows.md` | Any data flow between layers changed |
| `docs/02_architecture/01_system_overview.md` | Any system-level design decision changed |
| `docs/02_architecture/02_tech_stack.md` | Any technology added, removed, or swapped |
| `docs/02_architecture/03_component_architecture.md` | Any component boundary or responsibility changed |
| `docs/09_backend/01_backend_architecture.md` | Any backend structure, service, or pattern changed |
| `docs/08_frontend/01_frontend_architecture.md` | Any Flutter screen, navigation, or pattern changed |
| `docs/05_infrastructure/01_infrastructure.md` | Any CI workflow, build process, or distribution method changed |
| `docs/06_security/01_security.md` | Any auth flow, threat model, or security control changed |
| `docs/10_planning/01_roadmap.md` | Any milestone started, completed, or descoped |
| `docs/10_planning/02_decisions.md` | Any architectural decision locked in |
| `docs/10_planning/03_open_questions.md` | Any open question answered or added |
| `docs/01_product/06_polar_product_setup.md` | Configuration steps for Polar.sh products changed |
| `docs/00_overview/README.md` | Status column of any doc changes; new doc added |
| `DESIGN.md` | Any color, spacing, typography, or component spec changed |
| `README.md` | Project-level summary, structure, or setup steps changed |
| `CLAUDE.md` | Tech stack, repo layout, phase status, or any rule changes |
| `AGENT_LOG.md` | Every session — always append an entry |

### Step 2 — Cross-reference sweep

After identifying the files, **grep across all `.md` files** for the thing you changed:
- Renamed a field? Search for the old name — it may appear in 4 different docs.
- Changed an endpoint path? Search for the old path string everywhere.
- Changed a folder name? Search for the old path in every doc.
- Changed a tech decision? Search for the old technology name.

Never assume a term only appears in one place.

### Step 3 — CLAUDE.md self-check

CLAUDE.md has sections that silently go stale. After any doc update, verify these sections are still accurate:

| CLAUDE.md section | Goes stale when... |
|-------------------|--------------------|
| Repository Layout | Folders added, renamed, or removed |
| Tech Stack tables | Any dependency added, swapped, or removed |
| Architecture Rules | Layer responsibilities change |
| Development Commands | Paths, commands, or scripts change |
| Phase Roadmap | Any phase or milestone status changes |
| Current Status | Any significant progress is made |
| Known Risks & Gotchas | A risk is mitigated or a new one discovered |

### Step 4 — Consistency checks

- All code examples in docs must use the **real current paths and API shapes** — not hypothetical ones.
- All cross-links between docs must resolve (no broken `[see X](../Y/Z.md)` links).
- All table columns must be complete — no empty cells unless the column is optional by design.
- All milestone statuses in `docs/10_planning/01_roadmap.md` must match the "Phase Roadmap" table in `CLAUDE.md`.
- All doc statuses in `docs/00_overview/README.md` must match the actual content state of each file.

### Step 5 — Completion declaration

Only declare the doc update complete when:
- [ ] Every file in Step 1 that is affected has been updated
- [ ] The cross-reference sweep in Step 2 found no stale references
- [ ] The CLAUDE.md self-check in Step 3 passed
- [ ] The consistency checks in Step 4 passed
- [ ] The AGENT_LOG.md entry lists every doc file touched
---

## Hard Prohibitions

| # | Rule |
|---|------|
| 1 | **Never run `git commit`, `git push`, or any git write command.** All version control is the owner's responsibility. You may read git state (`git status`, `git log`, `git diff`) but must never write to it. |
| 2 | **Never add agent branding anywhere.** No comments, docstrings, README badges, footer text, or any other content that names, credits, or promotes an AI model (e.g. "Generated by Claude", "Built with Gemini", "AI-assisted"). Code must read as if a human wrote it. |
| 3 | **Never use `print()` in Python or `print()`/`debugPrint()` in Dart.** Use the project logger in every file. Silent output is invisible in production and unrecoverable once deployed. |
| 4 | **Never swallow exceptions silently.** No bare `except: pass` in Python, no empty `catch (_) {}` in Dart. Always log the error with full context and either rethrow or handle explicitly. |
| 5 | **Never hardcode secrets, credentials, ports, or file paths.** All config lives in `config.py` via `BaseSettings` (Python) or is injected via the DI layer (Dart). No magic strings or numbers outside of config/constants files. |
| 6 | **Never add a new pub/pip dependency without justification.** Check if an existing dependency already covers the need. Every new dep is a maintenance burden and a supply chain risk. |
| 7 | **Never break Clean Architecture layer boundaries.** A layer violation that compiles is still a bug. See the Architecture Rules section. |
| 8 | **Never log tokens, passwords, or any PII.** Scrub sensitive fields before logging. If a log line could expose a bearer token or user path, it must not be written. |
| 9 | **Never edit or delete a past database migration file.** Migrations are append-only. See Database Migration Rules. |
| 10 | **Never use string concatenation to build SQL queries.** Always use parameterized queries to prevent SQL injection. |
| 11 | **Never commit API keys, Firebase config files, or any secret to the repo.** `google-services.json`, `GoogleService-Info.plist`, `.env`, and `config.json` (dart-define) are gitignored and provided at build time only. See API Key & Secrets Management section. |
| 12 | **Never use a package version without first checking if a newer version exists.** Before adding or updating any pip/pub/npm/GitHub Action dependency, look up the current latest release. Do not pin to a version you found in training data — it is likely outdated. |
| 13 | **Never store bearer tokens as plaintext or reversibly encrypted in the database.** Bearer tokens must be stored as HMAC-SHA256 hashes — they are high-entropy random strings, so hashing is sufficient and irreversible if the DB leaks. Other secrets (API keys) use Fernet encryption. See Database Security section. |

---

## What is Fluxora?

Fluxora is a **self-hosted hybrid media streaming system** — think "Plex meets Syncthing."
It lets users stream their personal media library (movies, TV, music, documents) to any device,
automatically switching between LAN (fast, direct) and Internet (WebRTC/STUN/TURN) connections
without user intervention.

The system consists of:
1. **Server** — A Python/FastAPI backend that runs on the user's home machine, transcodes media via FFmpeg, and broadcasts itself on the LAN via mDNS.
2. **Mobile Client** — A Flutter app (iOS + Android) that discovers the server, pairs with it, and streams media.
3. **Desktop Control Panel** — A Flutter desktop app (Windows/macOS/Linux) for managing libraries, clients, and server settings.
4. **Shared Core** — A Flutter package (`packages/fluxora_core`) containing shared entities, network client, design tokens, and secure storage used by both Flutter apps.

**Key constraint:** Core streaming must work with zero cloud dependency — LAN streaming never touches Firebase. Firebase is used only for Phase 3+ features (WebRTC signaling, push notifications, subscriptions) and degrades gracefully when absent. The server is distributed as a standalone executable (PyInstaller). No Docker, no external DB, no mandatory account for Phase 1-2.

---

## Repository Layout

```
Fluxora/
├── CLAUDE.md                  <- You are here
├── DESIGN.md                  <- Full visual design system (read before any UI work)
├── AGENT_LOG.md               <- Append-only session log (read before starting work)
├── README.md                  <- Project overview and doc index
│
├── apps/
│   ├── server/                <- Python FastAPI backend
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── pyproject.toml     <- single source of truth for Python deps + tool config
│   │   ├── env.example        <- documents expected ~/.fluxora/.env keys
│   │   ├── fluxora_server.spec
│   │   ├── routers/           <- auth, files, library, stream, ws
│   │   ├── services/          <- ffmpeg, library, discovery, auth, webrtc
│   │   ├── models/            <- Pydantic schemas
│   │   ├── database/          <- db.py + migrations/
│   │   ├── utils/
│   │   └── tests/
│   │
│   ├── mobile/                <- Flutter mobile client (Android + iOS)
│   │   ├── lib/
│   │   │   ├── core/          <- DI, router
│   │   │   ├── features/      <- connect, library, player, settings
│   │   │   └── shared/        <- widgets, theme
│   │   ├── analysis_options.yaml
│   │   └── pubspec.yaml
│   │
│   ├── desktop/               <- Flutter desktop control panel (Windows/macOS/Linux)
│   │   ├── lib/
│   │   │   ├── core/          <- DI, router
│   │   │   ├── features/      <- dashboard, library, clients, activity, transcoding, logs, settings
│   │   │   └── shared/        <- widgets, theme
│   │   ├── analysis_options.yaml
│   │   └── pubspec.yaml
│   │
│   ├── web_landing/           <- Next.js public landing page (fluxora.marshalx.dev)
│   │   ├── src/app/           <- Next.js App Router pages + globals.css
│   │   ├── src/components/    <- Navbar, Hero, Features, HowItWorks, Platforms, Footer
│   │   ├── next.config.ts     <- static export for Cloudflare Pages
│   │   └── package.json
│   │
│   └── web_app/               <- Flutter Web dashboard (Phase 3 — not started)
│       └── (mirrors desktop feature set, accessible via browser)
│
├── packages/
│   └── fluxora_core/          <- Shared Flutter package (entities, ApiClient, tokens, storage)
│       ├── lib/
│       │   ├── entities/
│       │   ├── network/
│       │   ├── storage/
│       │   └── constants/
│       ├── analysis_options.yaml
│       └── pubspec.yaml
│
├── docs/                      <- All planning and architecture documentation
│   ├── 00_overview/           <- Project summary, folder structure
│   ├── 01_product/            <- Vision, requirements, user stories, Polar setup
│   ├── 02_architecture/       <- System overview, tech stack, component architecture
│   ├── 03_data/               <- Data models, SQLite schema, data flows
│   ├── 04_api/                <- REST + WebSocket API contracts
│   ├── 05_infrastructure/     <- CI/CD, hosting, distribution
│   ├── 06_security/           <- Auth model, threat model, encryption
│   ├── 07_ai_ml/              <- AI/ML architecture (Phase 5)
│   ├── 08_frontend/           <- Flutter architecture
│   ├── 09_backend/            <- FastAPI architecture
│   ├── 10_planning/           <- Roadmap, decisions, open questions
│   └── 11_design/             <- Design reference HTML + brand README
│
├── firebase.json              <- Firebase project config (Cloud Functions)
├── .firebaserc                <- Firebase project alias (update with real project ID)
├── functions/                 <- Firebase Cloud Functions (Phase 3 stubs)
│   ├── src/index.ts           <- health check + Phase 3 stub exports
│   ├── package.json
│   └── tsconfig.json
│
├── scripts/                   <- Build and release automation
└── .github/workflows/         <- Path-scoped CI (server / mobile / desktop / web / mirror)
```

---

## Detailed Development Guidelines

> **Note:** The detailed guidelines for Tech Stack, Code Conventions, Security, Architecture Rules, Firebase, and more have been moved to prevent this file from becoming too large.
> 
> **👉 You must read the full guidelines here: [Development Guidelines](docs/12_guidelines/01_development_guidelines.md)**

### Guidelines Index
- [Tech Stack](docs/12_guidelines/01_development_guidelines.md#tech-stack)
- [Architecture: Core Concepts](docs/12_guidelines/01_development_guidelines.md#architecture-core-concepts)
- [Architecture Rules](docs/12_guidelines/01_development_guidelines.md#architecture-rules)
- [Database (SQLite, Security, Storage)](docs/12_guidelines/01_development_guidelines.md#database)
- [Database Migration Rules](docs/12_guidelines/01_development_guidelines.md#database-migration-rules)
- [API Overview & Versioning](docs/12_guidelines/01_development_guidelines.md#api-overview)
- [Development Commands](docs/12_guidelines/01_development_guidelines.md#development-commands)
- [Code Conventions](docs/12_guidelines/01_development_guidelines.md#code-conventions)
- [Git Commit Convention](docs/12_guidelines/01_development_guidelines.md#git-commit-convention)
- [Testing Discipline](docs/12_guidelines/01_development_guidelines.md#testing-discipline)
- [Security Rules](docs/12_guidelines/01_development_guidelines.md#security-rules)
- [Resource Cleanup Rules](docs/12_guidelines/01_development_guidelines.md#resource-cleanup-rules)
- [Before You Are Done (Checklists)](docs/12_guidelines/01_development_guidelines.md#before-you-are-done)
- [Dependency Version Policy](docs/12_guidelines/01_development_guidelines.md#dependency-version-policy)
- [API Key & Secrets Management](docs/12_guidelines/01_development_guidelines.md#api-key--secrets-management)

## Key Files to Read Before Specific Tasks

| Task | Read First |
|------|-----------|
| Any UI work | `DESIGN.md` |
| Adding an API endpoint | `docs/04_api/01_api_contracts.md` |
| Changing DB schema | `docs/03_data/02_database_schema.md` |
| Backend service changes | `docs/09_backend/01_backend_architecture.md` |
| Flutter screen/widget | `docs/08_frontend/01_frontend_architecture.md` |
| Networking/streaming | `docs/02_architecture/01_system_overview.md` |
| Security-sensitive feature | `docs/06_security/01_security.md` |
| CI/CD changes | `docs/05_infrastructure/01_infrastructure.md` |

---

## Design System Reference

**Read `DESIGN.md` in full before creating any UI.**

Quick tokens for reference:

```
Background:    #0F172A
Surface:       #1E293B
Border:        #334155
Primary:       #6366F1
Accent:        #22D3EE
Text primary:  #E2E8F0
Text muted:    #94A3B8
Success:       #22C55E
Warning:       #F59E0B
Error:         #EF4444
Font:          Inter (all weights)
Border radius: cards=12px, buttons=8px, badges=9999px
```

---

## Phase Roadmap

| Phase | Scope | Status |
|-------|-------|--------|
| 0 | Architecture, docs, monorepo scaffold | ✅ Complete |
| 1 | FastAPI scaffold, mDNS, basic HLS, Flutter mobile project setup | ✅ Complete |
| 2 | Full library management, TMDB metadata, playback resume, Desktop Control Panel | ✅ Complete |
| 3 | WebRTC internet streaming, smart-path LAN bypass, transport badge, ICE degradation | ✅ Complete |
| 4 | Tier enforcement, license key, upgrade UI, payment provider integration | ✅ Complete (Polar webhook + product config docs + UI alignment done) |
| 5 | Hardware transcoding, advanced desktop modules (Library/Activity/Logs/Licenses), player settings sheet | 🔵 In Progress |
| 6 | AI recommendations, public release | 🔲 Planned |

Full roadmap: `docs/10_planning/01_roadmap.md`

---

## Known Risks & Gotchas

| Area | Gotcha | Mitigation |
|------|--------|-----------|
| FFmpeg | Must be installed separately by the user; PyInstaller cannot bundle it | Startup check with friendly error message and download link |
| mDNS on Android 12+ | Android silently drops multicast packets without `WifiManager.MulticastLock` | Implemented: `MainActivity.kt` exposes `MethodChannel('dev.marshalx.fluxora/multicast')` — `ConnectCubit.startDiscovery()` acquires the lock before scanning, releases on close; manual IP entry remains as fallback |
| `flutter_webrtc` | v0.10.x uses removed v1 Flutter plugin API (`PluginRegistry.Registrar`) — fails to compile on AGP 8+ | v1.4.1 integrated and working (Phase 3 ✅); do not downgrade |
| SQLite concurrency | WAL mode helps but high client counts can still lock | Connection pool limit; queue writes; plan PostgreSQL migration path for Pro |
| HLS temp files | FFmpeg writes to `/tmp` — can fill up on long sessions | Enforce cleanup on stream close AND on server startup (orphan cleanup) |
| PyInstaller + FFmpeg | FFmpeg subprocess path must use the bundled binary path, not `PATH` | Resolve FFmpeg path via `sys._MEIPASS` in frozen builds |
| Token storage (Flutter) | `shared_preferences` is not encrypted | Use `flutter_secure_storage` for the bearer token |
| Path traversal | File-serving routes could expose files outside the library root | Always canonicalize and prefix-check before serving |
| Bash / Git Commits | Backticks inside double-quoted commit messages execute as bash commands, causing pathspec errors | Use single quotes (`'`) instead of double quotes to wrap commit messages containing backticks |
| Dart 3.8 null-aware map syntax | `{'key': ?value}` looks like a Dart syntax error to older analyzers or IDEs | Valid in SDK `>=3.8.0` (desktop `pubspec.yaml` uses `sdk: '>=3.8.0'`); `flutter analyze` confirms no issues |
| Pytest & CI | `pytest` exits with code 5 if no tests are found, breaking CI pipelines | Always include at least one placeholder test (e.g. `def test_placeholder(): pass`) |
| Git Pull / Merge | Running `git pull` with diverged branches creates an unwanted `Merge branch 'main' of...` commit in the history | Always use `git pull --rebase` to pull remote changes without creating an automated merge commit |

---

## Out of Scope (v1)

- Light mode
- Multi-user accounts (single-owner server only)
- Cloud backup / remote library
- Music streaming (media type supported but UI is Phase 2+)
- Torrent integration
- Browser-based web client
- Subtitle / caption rendering (Phase 3+)
- AI-based recommendations (Phase 5)

---

## Current Status

> **As of May 2026 — Phases 1–4 complete, Phase 5 in progress (hardware encoding + advanced desktop modules).**

- Monorepo scaffold complete: `apps/server/`, `apps/mobile/`, `apps/desktop/`, `packages/fluxora_core/`
- All documentation in sync with code
- `apps/server` — **Phases 1–5 partially complete** (113 passing tests; ruff + black clean):
  - Full FastAPI lifespan, mDNS (`AsyncZeroconf`), structured logging, rotating log file
  - Routers: info (+ logs), auth, files (upload/delete), library, stream (sessions/progress), ws, signal, settings (transcoding), orders, webhook ✅
  - Services: auth, library, discovery, ffmpeg (HWA), webrtc, settings, tmdb, license, webhook ✅
  - Migrations 001–010 applied on startup ✅
  - Hardware encoding: `ffmpeg_service.py` reads `transcoding_encoder/preset/crf` from DB; supports libx264, h264_nvenc, h264_qsv, h264_vaapi ✅
  - Orders: `GET /api/v1/orders` (localhost) exposes Polar order + license key for manual customer delivery ✅
  - `validate_token_or_local` dependency — files/library endpoints accessible from localhost without bearer token ✅
- `apps/mobile` — **Phases 1–4 UI complete** (14 passing tests):
  - `features/connect` — mDNS + manual IP + `MulticastLock` ✅
  - `features/auth` — full pairing flow ✅
  - `features/library` — library grid + TMDB poster thumbnails ✅
  - `features/player` — `media_kit` HLS; `NetworkPathDetector`; WebRTC 8 s timeout → HLS fallback; `_TransportBadge`; resume; `PlayerTierLimit` → `_TierLimitView` → `UpgradeScreen`; `_SettingsSheet` (speed/audio/subtitle) ✅
  - `features/upgrade` — `UpgradeScreen` tier comparison cards + activation guide ✅
- `apps/desktop` — **Phases 1–5 in progress** (34 passing tests; Dart SDK `>=3.8.0`):
  - Dashboard screen (server info + client stats) ✅
  - Clients screen (approve/reject/filter) ✅
  - Library screen (create/scan/upload/filter libraries) ✅
  - Licenses screen (Polar orders + copyable license keys) ✅
  - Activity screen (active stream sessions monitor) ✅
  - Logs screen (live server log viewer) ✅
  - Settings screen (URL, server name, tier, license key, transcoding encoder/preset/CRF) ✅
  - Transcoding screen (scaffold only; settings managed via Settings screen) 🔵

**Next:** Complete `TranscodingScreen` cubit, add hardware encoding startup validation, E2E encryption planning.
