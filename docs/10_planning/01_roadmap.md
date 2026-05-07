# Project Roadmap & Milestones

> **Category:** Planning  
> **Status:** Active - Updated 2026-05-04 (Phase 5 in progress; **server at 351 tests** [Phase A + Phase B backfill; GPU UX Slice A: encoder-advisor pure-function + `/transcoding/advisor`, `EncoderTestResult` dataclass, `test_encoder` tuple return, `_input_decoder_args` cuvid hint, cuvid auto-fallback retry, long-GOP stream-copy fix, migration 019 license-key sanitiser; **GPU UX Slice B**: `services/hardware_probe.py` per-OS CPU + GPU enumeration + `/transcoding/devices` with lifetime cache; **GPU UX Slice C**: `services/session_router.py` priority-chain walker with `concurrent_session_cap`-aware fallback (NVENC = 3) + `/transcoding/fallback-history` + 50-entry FIFO ring buffer + migrations 020 (`transcoding_chain`) + 021 (`stream_sessions.encoder_used`); **Phase 6 follow-ups**: cuvid fallback widened (`use_gpu_input` rename, drops both `-c:v *_cuvid` AND `-hwaccel cuda` on retry — covers Turing GPUs without AV1 NVDEC); fmp4 init-segment quirk fix (`-hls_fmp4_init_filename` + `_ensure_fmp4_init_segment` helper + `video/mp4` MIME on `.m4s`/`.mp4`); HDR → SDR tonemap path (`?tonemap=true` query param + zscale + Hable filter chain + `StreamStartResponse.hdr_format`/`tonemapped`); static VOD playlist (`_write_static_vod_playlist` + FFmpeg's incremental playlist moved to `_ff_playlist.m3u8` + 5s segment-wait in HLS router for seek-ahead-of-encode)]; **mobile at 41 tests** [Phase A + B real-data wiring; pairing UX rebuild with state-machine + email field + `/reconnect` + auto-redirect on 401; QR-pairing scanner via `mobile_scanner ^7.1.2`; player polish round — Android PIP + `audio_service ^0.18.18` lockscreen / notification / Bluetooth-headset transport + first-time bg-playback prompt + Profile inline toggle; Downloads tab hidden in v1; mDNS reusePort fix]; **desktop at 84 tests** [GPU UX Slice A: encoder-status widgets + `TranscodingCubit` advisor poll + `ApiException` detail parsing + `ActivityCubit` polling; **Slice B**: `DetectedHardwareCard` widget reading from `HardwareCubit`; **Slice C**: `EncoderPriorityList` drag-and-drop chain editor + `FallbackHistoryPanel` + per-session encoder pill on the Transcoding screen; pair-device dialog with QR via `qr_flutter ^4.1.0`; visible Approve / Reject / Revoke client actions; notifications-audit polish round]; desktop redesign M1–M10 shipped — including M10 custom window chrome / FluxTitlebar / Aero Peek shell-integration; **mobile redesign M0–M9 landed** — Discover surfaces / Detail / Episodes / Player chrome + gestures + sheets / Mini-player + drag-down minimize / Downloads + Profile + Notifications real-data wiring / V2 theme cutover. Next mobile milestone: M10 X-Ray + Group Watch + Offline state shells; iOS PIP + iOS lockscreen pending an iOS test device.)

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
| Library CRUD + scan API | Must | ✅ Done | `GET/POST/PATCH/DELETE /library`, scan endpoint, `total_size_bytes` aggregate (added 2026-05-03 — ADR-016/017) |
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
| Client Groups (M0 §7.1) | Must | ✅ Done | `groups`/`group_members`/`group_restrictions` tables (migration 011); `routers/groups.py` + `services/group_service.py`; stream-gate hook in `stream.py` enforces library allowlist + time window; 8 endpoints shipped 2026-05-01. **All 5 remediation milestones shipped 2026-05-07**: M1 restriction editing (time-window + library allowlist + status toggle + advisory fields), M2 real client picker (replaces raw-UUID paste), M3 Clients-screen cross-link (group chips on detail panel + bidirectional add/remove), M4 filter chip on Groups table, M5 mobile soft-block UX on 403 (PlayerGated state + `_GatedView` instead of generic "stream failed"). See [`12_groups_remediation_plan.md`](./12_groups_remediation_plan.md). |
| Operator Profile (M0 §7.2) | Must | ✅ Done | `display_name`, `email`, `avatar_path`, `profile_created_at`, `last_login_at` added to `user_settings` (migration 012); `routers/profile.py` + `services/profile_service.py` + `models/profile.py`; `GET/PATCH /api/v1/profile` (localhost-only); `avatar_letter` computed server-side; 9 tests; server suite 165 → 174 |
| In-app Notifications (M0 §7.3) | Must | ✅ Done 2026-05-02 | `notifications` table (migration 013) + `idx_notifications_unread`; `models/notification.py` (`NotificationResponse`, `NotificationCreate`, type/category enums); `services/notification_service.py` (CRUD + in-process asyncio pub/sub); `routers/notifications.py` (4 REST endpoints, `validate_token_or_local`); `WS /api/v1/ws/notifications` (loopback-or-token auth); 4 emitter integrations (pair request, license expiry, transcode failure, storage >90%); 12 tests; server suite 174 → 186 |
| Activity Event Log (M0 §7.4) | Must | ✅ Done 2026-05-02 | `activity_events` table (migration 014) + 2 indexes; `models/activity.py` (`ActivityEventResponse`); `services/activity_service.py` (`record()` + `list_events(limit, since, type_prefix)`); `routers/activity.py` (`GET /api/v1/activity`, `validate_token_or_local`, limit 1–200); 6 producer integrations (stream.start/end, client.pair/approve/reject, library.scan); 12 tests; server suite 186 → 198 |
| Transcoding Status API (M0 §7.8) | Must | ✅ Done 2026-05-02 | `GET /api/v1/transcoding/status` (localhost-only); `services/transcoding_service.py` (encoder discovery via `ffmpeg -encoders` cached; GPU probe via `nvidia-smi` best-effort); `models/transcoding.py` (`TranscodingStatusResponse`, `EncoderLoad`, `ActiveTranscodeSession`); 6 tests; suite 198 → 204 |
| Structured Logs API (M0 §7.9) | Must | ✅ Done 2026-05-02 | JSON file formatter via `python-json-logger`; `GET /api/v1/logs?level=&source=&since=&until=&q=&limit=&cursor=` (`validate_token_or_local`); `WS /api/v1/ws/logs` (BroadcastHandler fan-out); `services/log_service.py` (parse, filter, paginate, pubsub); `models/log_record.py` (`LogRecord`, `LogListResponse`); `GET /api/v1/info/logs` removed (no backwards-compat shim); 15 tests; suite 204 → 219 |
| Settings Extension (M0 §7.10) | Must | ✅ Done 2026-05-02 | `015_extended_settings.sql` adds 18 columns to `user_settings` (General: `language`, `auto_start_on_boot`, `auto_restart_on_crash`, `minimize_to_system_tray`, `theme_accent`, `default_library_view`, `scan_libraries_on_startup`, `generate_thumbnails`; Network: `preferred_mode`, `enable_mdns`, `enable_webrtc`, `relay_server_url`; Streaming: `default_quality`, `ai_segment_duration_seconds`; Security: `enable_pairing_required`, `session_timeout_minutes`; Advanced: `enable_log_export`, `custom_server_url`); `UpdateSettingsBody` extended with Pydantic `Literal` guards; dynamic SET-list in `update_settings`; 16 tests; suite 219 → 235 |
| Orders Pagination + Portal URL (M0 §7.11) | Must | ✅ Done 2026-05-02 | `GET /api/v1/orders` extended with `limit`/`cursor` pagination + `total_all`/`next_cursor` in response; `GET /api/v1/orders/portal-url` (localhost-only; returns `FLUXORA_POLAR_PORTAL_URL` or 404); `PortalUrlResponse` model; `polar_portal_url` in `config.py`; 5 tests; suite 235 → 240 |
| Hardware encoding (NVENC/VAAPI) | Nice-to-have | ✅ Done 2026-05-04 | Encoder registry covers 10 encoders (NVENC/QSV/VAAPI/VideoToolbox/software); startup self-test + settings-change retest; GPU monitoring probes. **All three GPU UX slices shipped 2026-05-04** — A: encoder advisor + `/transcoding/advisor` + desktop `ActiveEncoderStrip`/`EncoderRecommendationBanner`/`EncoderStatusPanel`; cuvid input-decoder hint + auto-fallback retry; long-GOP stream-copy fix. B: `services/hardware_probe.py` + `/transcoding/devices` + `DetectedHardwareCard`. C: `services/session_router.py` priority-chain walker + `concurrent_session_cap` (NVENC = 3) + `/transcoding/fallback-history` + `EncoderPriorityList` drag-and-drop UI + `FallbackHistoryPanel` + per-session `encoder_used` pill + migrations 020/021. |
| Desktop Library Management | Must | ✅ Done 2026-05-03 | `LibraryScreen` — create/edit/scan/delete (DB only)/upload + filter + sort + grid/list toggle + per-library files browser; client-side poster mosaic; per-library `total_size_bytes`. P0+P1 close-out details in `docs/10_planning/07_library_screen_plan.md` |
| Desktop Licenses view | Must | ✅ Done | Polar orders + license keys live on the **Subscription → Billing** tab (`SubscriptionScreen`, M7 redesign 2026-05-02). The standalone `/licenses` route + `LicensesScreen` were retired at M9 cleanup 2026-05-03 — `OrdersCubit` is now consumed by the Billing tab. |
| Desktop Activity monitor | Should | ✅ Done | `ActivityScreen` — real-time active stream sessions from `GET /api/v1/stream/sessions` |
| Desktop Server Logs | Should | ✅ Done | `LogsScreen` — live log viewer from `GET /api/v1/logs` |
| Desktop Transcoding Settings | Should | 🔵 Partial | `TranscodingScreen` scaffold; encoder/preset/CRF configurable via `SettingsScreen` |
| Progress via REST | Should | ✅ Done | `PATCH /api/v1/stream/{id}/progress` — REST alternative to WebSocket progress updates |
| Live system stats | Should | ✅ Done | `GET /api/v1/info/stats` + `WS /api/v1/ws/stats`; psutil-backed `system_stats_service` (CPU/RAM/network/uptime/active streams) — backs the redesigned dashboard |
| Storage breakdown | Should | ✅ Done | `GET /api/v1/library/storage-breakdown` — per-type totals + capacity dedup'd by mount point; backs the dashboard donut chart |
| Server admin actions | Should | ✅ Done | `POST /api/v1/info/restart`, `POST /api/v1/info/stop` — localhost-only graceful shutdown |
| Desktop redesign — M1 Foundation | Should | ✅ Done 2026-05-02 | Tokens (`app_colors` v2 / `app_gradients` / `app_spacing` / `app_radii` / `app_shadows` / `app_typography` v2) + 11 primitives in `apps/desktop/lib/shared/widgets/` (`FluxCard`, `SectionLabel`, `StatusDot`, `Pill`, `FluxProgress`, `FluxButton`, `StatTile`, `Sparkline`, `StorageDonut`, `PageHeader`, plus brand visuals `FluxoraMark`/`FluxoraWordmark`/`HeroWaves`/`BrandLoader`/`PulseRing`/`EmptyState`) + `flutter_svg` 2.2.4 dep + 4 animated SMIL SVGs + `/showcase` route. See [`docs/11_design/desktop_redesign_plan.md`](../11_design/desktop_redesign_plan.md) §3 + §9. |
| Public routing (`fluxora-api.marshalx.dev`) | Should | ✅ Done | v1 single-tenant Phases 1–5 complete 2026-05-01 (tunnel live; server CF middlewares + admin hardening + `/healthz` + `remote_url` on `/info`; `fluxora_core` dual-base `ApiClient` with `NetworkPathDetector`; mobile pairing flow persists `remote_url` post-pair; desktop Dashboard Remote-access pill + Settings Remote Access section with on-demand `/healthz` probe). Phase 6 (TURN, WAF rules, Access on admin paths, tunnel health alerts) tracked as operator-driven manual tasks. v2 multi-tenant plan locked. See [`05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md); ADR-013 |
| Mobile redesign — M0–M9 landed | Should | ✅ Done 2026-05-03 | Plan in [`docs/11_design/mobile_redesign_plan.md`](../11_design/mobile_redesign_plan.md). M0 foundation (gradient + deps) → M1 shared widgets lift → M2 tab shell + go_router → M3 Discover (Home/Library/Search/Notifications) → M4 Detail + Episodes → M5 Player chrome → M6 Player gestures + 5 bottom sheets → M7 Mini-player + drag-down minimize + shared `PlaybackProvider` (`PlayerCubit` lazySingleton) → M8 Downloads + Profile + Notifications real-data wiring (REST polling /api/v1/notifications, mirroring desktop; new `NotificationsRepository` + Cubit; `MockNotification` removed; sign-out flow with `dismiss + clearBearerToken + secureStorage.deleteAll`) → M9 theme cutover (V1 palette + V1 typography deleted from `fluxora_core`; `apps/mobile/lib/shared/theme/app_theme.dart` body rewritten in-place onto V2 tokens; `upgrade_screen` tier-color reshuffle Pro=violetDeep / Ultimate=violet to preserve hierarchy after `primary`/`accentPurple` collapse; M9 follow-up: `InputDecorationTheme.fillColor` opaque `Color(0xFF0F0C24)` + `media_card` progress track white-8%). 27 mobile tests still pass; `flutter analyze` clean × all 3 packages. **Next:** M10 X-Ray panel + Group Watch shell + Offline state (UI shells only — no live ML / sync engine). |
| Web landing page redesign (`fluxora.marshalx.dev`) | Should | ✅ Done 2026-05-02 | Full redesign in one PR — indigo→violet token migration, two-column hero with desktop mockup + animated `HeroWaves` SVG backdrop + 4.9★ social-proof stack, 4-card feature row, `PopularMovies` carousel (8 real popular titles with TMDB CDN posters: Dune Part Two, Oppenheimer, Deadpool & Wolverine, The Batman, Spider-Verse, Top Gun: Maverick, Interstellar, Inception), `LibraryTiles` (5 coloured category tiles), 3-step `HowItWorks`, restyled `Pricing` with `Core`→`Free` rename + new `TierComparison` matrix, restyled `Platforms` with platform-icon SVGs, new `Faq` accordion (6 Q&As, native `<details>`), `AboutStrip` with 4-stat grid, `FinalCta` band, 4-column `Footer`. Full SEO push: `metadataBase` + keywords + OG/Twitter cards + JSON-LD (`Organization`+`WebSite`+`SoftwareApplication`+`FAQPage`) + `robots.ts` + `sitemap.ts` + `manifest.json` + TMDB preconnect. `next build` green — 7 routes prerendered static. See [`docs/11_design/web_landing_redesign_plan.md`](../11_design/web_landing_redesign_plan.md). |
| AI file organization | Nice-to-have | 🔲 Planned | Auto-tag, rename, categorize |
| End-to-end encryption | Should | 🔲 Planned | E2E for internet streams |
| Multi-user / family sharing | Nice-to-have | 🔲 Planned | Shared library access |
| TV/casting support (Chromecast) | Nice-to-have | 🔲 Planned | Future platform |
| iOS/Android background streaming | Should | 🔲 Planned | Foreground service |
| Streaming pipeline polish (seek-restart, tonemap timeout, zombie cleanup) | Must | 🔲 Planned | Four-commit plan in [`11_streaming_pipeline_issues.md`](./11_streaming_pipeline_issues.md). Unblocks HDR→SDR toggle, fixes seek-ahead beyond encoded boundary, kills zombie FFmpeg accumulation. ~1.5 days work. |

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
