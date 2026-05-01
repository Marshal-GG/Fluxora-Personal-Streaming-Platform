# Project Roadmap & Milestones

> **Category:** Planning  
> **Status:** Active - Updated 2026-05-01 (Phase 5 in progress; hardware encoding, desktop monitoring screens, orders view, live system stats, storage breakdown, info admin actions, public routing plan locked)

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
| License key validation | Must | ✅ Done | `license_service.py` — HMAC-SHA256 signed keys (`FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>`); `_enrich_license()` in `settings_service`; format validator on `UpdateSettingsBody`; `license_status` + `license_tier` in API response; 22 tests ✅ |
| Payment provider integration | Should | ✅ Done | Polar webhook endpoint implemented for `order.paid` + signed key issuance; Polar dashboard setup complete |
| Upgrade prompt UI | Must | ✅ Done | Mobile: `PlayerTierLimit` state + `_TierLimitView` → `UpgradeScreen` (tier cards + activation guide); Desktop: tier selector + stream limit badge in Settings |
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

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| Client Groups (M0 §7.1) | Must | ✅ Done | `groups`/`group_members`/`group_restrictions` tables (migration 011); `routers/groups.py` + `services/group_service.py`; stream-gate hook in `stream.py` enforces library allowlist + time window; 8 endpoints shipped 2026-05-01 |
| Operator Profile (M0 §7.2) | Must | ✅ Done | `display_name`, `email`, `avatar_path`, `profile_created_at`, `last_login_at` added to `user_settings` (migration 012); `routers/profile.py` + `services/profile_service.py` + `models/profile.py`; `GET/PATCH /api/v1/profile` (localhost-only); `avatar_letter` computed server-side; 9 tests; server suite 165 → 174 |
| In-app Notifications (M0 §7.3) | Must | ✅ Done 2026-05-02 | `notifications` table (migration 013) + `idx_notifications_unread`; `models/notification.py` (`NotificationResponse`, `NotificationCreate`, type/category enums); `services/notification_service.py` (CRUD + in-process asyncio pub/sub); `routers/notifications.py` (4 REST endpoints, `validate_token_or_local`); `WS /api/v1/ws/notifications` (loopback-or-token auth); 4 emitter integrations (pair request, license expiry, transcode failure, storage >90%); 12 tests; server suite 174 → 186 |
| Activity Event Log (M0 §7.4) | Must | ✅ Done 2026-05-02 | `activity_events` table (migration 014) + 2 indexes; `models/activity.py` (`ActivityEventResponse`); `services/activity_service.py` (`record()` + `list_events(limit, since, type_prefix)`); `routers/activity.py` (`GET /api/v1/activity`, `validate_token_or_local`, limit 1–200); 6 producer integrations (stream.start/end, client.pair/approve/reject, library.scan); 12 tests; server suite 186 → 198 |
| Hardware encoding (NVENC/VAAPI) | Nice-to-have | 🔵 In Progress | `ffmpeg_service.py` reads `transcoding_encoder/preset/crf` from DB; supports libx264, h264_nvenc, h264_qsv, h264_vaapi |
| Desktop Library Management | Must | ✅ Done | `LibraryScreen` — create/scan/upload/filter; `POST /files/upload` endpoint |
| Desktop Licenses view | Must | ✅ Done | `LicensesScreen` — lists all Polar orders + license keys from `GET /api/v1/orders` |
| Desktop Activity monitor | Should | ✅ Done | `ActivityScreen` — real-time active stream sessions from `GET /api/v1/stream/sessions` |
| Desktop Server Logs | Should | ✅ Done | `LogsScreen` — live log viewer from `GET /api/v1/info/logs` |
| Desktop Transcoding Settings | Should | 🔵 Partial | `TranscodingScreen` scaffold; encoder/preset/CRF configurable via `SettingsScreen` |
| Progress via REST | Should | ✅ Done | `PATCH /api/v1/stream/{id}/progress` — REST alternative to WebSocket progress updates |
| Live system stats | Should | ✅ Done | `GET /api/v1/info/stats` + `WS /api/v1/ws/stats`; psutil-backed `system_stats_service` (CPU/RAM/network/uptime/active streams) — backs the redesigned dashboard |
| Storage breakdown | Should | ✅ Done | `GET /api/v1/library/storage-breakdown` — per-type totals + capacity dedup'd by mount point; backs the dashboard donut chart |
| Server admin actions | Should | ✅ Done | `POST /api/v1/info/restart`, `POST /api/v1/info/stop` — localhost-only graceful shutdown |
| Desktop redesign — M1 Foundation | Should | ✅ Done 2026-05-02 | Tokens (`app_colors` v2 / `app_gradients` / `app_spacing` / `app_radii` / `app_shadows` / `app_typography` v2) + 11 primitives in `apps/desktop/lib/shared/widgets/` (`FluxCard`, `SectionLabel`, `StatusDot`, `Pill`, `FluxProgress`, `FluxButton`, `StatTile`, `Sparkline`, `StorageDonut`, `PageHeader`, plus brand visuals `FluxoraMark`/`FluxoraWordmark`/`HeroWaves`/`BrandLoader`/`PulseRing`/`EmptyState`) + `flutter_svg` 2.2.4 dep + 4 animated SMIL SVGs + `/showcase` route. See [`docs/11_design/desktop_redesign_plan.md`](../11_design/desktop_redesign_plan.md) §3 + §9. |
| Public routing (`fluxora-api.marshalx.dev`) | Should | ✅ Done | v1 single-tenant Phases 1–5 complete 2026-05-01 (tunnel live; server CF middlewares + admin hardening + `/healthz` + `remote_url` on `/info`; `fluxora_core` dual-base `ApiClient` with `NetworkPathDetector`; mobile pairing flow persists `remote_url` post-pair; desktop Dashboard Remote-access pill + Settings Remote Access section with on-demand `/healthz` probe). Phase 6 (TURN, WAF rules, Access on admin paths, tunnel health alerts) tracked as operator-driven manual tasks. v2 multi-tenant plan locked. See [`05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md); ADR-013 |
| AI file organization | Nice-to-have | 🔲 Planned | Auto-tag, rename, categorize |
| End-to-end encryption | Should | 🔲 Planned | E2E for internet streams |
| Multi-user / family sharing | Nice-to-have | 🔲 Planned | Shared library access |
| TV/casting support (Chromecast) | Nice-to-have | 🔲 Planned | Future platform |
| iOS/Android background streaming | Should | 🔲 Planned | Foreground service |

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
| M5 — Monetization Live | 4 | ✅ Done |
| M5.5 — Advanced Desktop + Hardware Encoding | 5 | 🔵 In Progress |
| M6 — AI Recommendations & Public Release | 5-6 | ⬜ Future |

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
