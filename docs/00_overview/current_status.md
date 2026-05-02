# Current Status

> Snapshot of what's done / in-progress / not-started across the codebase. Update on every significant milestone landing. The roadmap (`docs/10_planning/01_roadmap.md`) tracks future planning; this doc tracks shipped state.

**As of 2026-05-02.** Phases 1–4 complete; Phase 5 in progress (hardware encoding + advanced desktop modules + desktop redesign).

---

## Repo state

- Monorepo scaffold complete: `apps/server/`, `apps/mobile/`, `apps/desktop/`, `apps/web_landing/`, `packages/fluxora_core/`
- All documentation in sync with code

---

## `apps/server` — Phases 1–5 partially complete (247 passing tests; ruff + black clean)

- Full FastAPI lifespan, mDNS (`AsyncZeroconf`), structured JSON logging (`python-json-logger`), rotating log file
- **Routers:** info (+ healthz), auth, files (upload/delete), library, stream (sessions/progress), ws, signal, settings (transcoding + 18 extended fields), orders (paginated + portal-url), groups, notifications, activity, profile, webhook, transcoding (status), logs (REST + WS)
- **Services:** auth, library, discovery, ffmpeg (HWA), webrtc, settings, tmdb, license, webhook, system_stats, group_service, notification_service, activity_service, profile_service, transcoding_service, log_service
- **Migrations:** 001–015 applied on startup
- **Hardware encoding:** `ffmpeg_service.py` reads `transcoding_encoder/preset/crf` from DB; supports libx264, h264_nvenc, h264_qsv, h264_vaapi
- **Public routing v1:** Cloudflare Tunnel live (`fluxora-api.marshalx.dev`); `RealIPMiddleware`, `HLSBlockOverTunnelMiddleware`, `/healthz`, `remote_url` on `/info`, admin endpoints reject tunneled requests. Phase 6 hardening (Cloudflare Access, WAF, tunnel-health alerts, TURN) tracked as operator manual tasks.

---

## `packages/fluxora_core` — Phase 3 dual-base routing complete (8 passing tests)

- **Entities:** PolarOrder, MediaFile (resume), ServerInfo (with `remoteUrl`), Library, Client, StreamSession, SystemStats, `ActivityEvent` (M3), `LibraryStorageBreakdown` / `StorageByType` (M3), `Group` / `GroupRestrictions` / `TimeWindow` / `GroupStatus` (M5), `TranscodingStatus` / `EncoderLoad` / `ActiveTranscodeSession` (M5)
- **Network:** dual-base `ApiClient` (per-request `LanCheck` resolves between `localBaseUrl` and `remoteBaseUrl`, throws `NoRemoteConfiguredException` off-LAN with no remote), `NetworkPathDetector`, `Endpoints` (with `healthz`, `logs`)
- **Storage:** `SecureStorage` with `saveRemoteUrl/getRemoteUrl/savePairing`
- **Design tokens (v2):** `app_colors.dart` (v2 section), `app_typography.dart` (v2 section), `app_gradients.dart`, `app_spacing.dart`, `app_radii.dart`, `app_shadows.dart`
- **Brand widgets:** `FluxoraMark`, `FluxoraWordmark`, `FluxoraLogo`, `HeroWaves`, `BrandLoader`, `PulseRing`, `EmptyState`
- **Assets:** hi-fi logo PNGs in `assets/brand/`; 4 animated SMIL SVGs in `assets/illustrations/`

---

## `apps/mobile` — Phases 1–4 UI complete (27 passing tests)

| Feature | Status |
|---------|--------|
| `features/connect` (mDNS + manual IP + MulticastLock) | ✅ |
| `features/auth` (full pairing flow + post-pair `/info` fetch persists `remote_url`) | ✅ |
| `features/library` (library grid + TMDB poster thumbnails) | ✅ |
| `features/player` (`media_kit` HLS + WebRTC smart-path + transport badge + resume + tier-limit UI + settings sheet) | ✅ |
| `features/upgrade` (tier comparison + activation guide) | ✅ |
| `features/settings` | 🔲 deferred — desktop is v1 settings surface |

---

## `apps/desktop` — Phases 1–5 in progress (38 passing tests; Dart SDK `>=3.9.0`)

| Surface | Status |
|---------|--------|
| Dashboard (server info + client stats + Remote-access pill) | ✅ |
| Clients (approve/reject/filter) | ✅ |
| Library (create/scan/upload/filter) | ✅ |
| Licenses (Polar orders + copyable license keys) | ✅ |
| Activity (active stream sessions monitor) | ✅ |
| Logs (live log viewer; consumes `/api/v1/logs`) | ✅ |
| Settings (URL, server name, tier, license key, transcoding + Remote Access section) | ✅ |
| Transcoding screen | 🔵 scaffold only; settings managed via Settings screen |
| **Desktop redesign M1 Foundation** (tokens + 11 primitives + brand widgets + `/showcase`) | ✅ done 2026-05-02 |
| Desktop redesign M2 Shell (sidebar + status bar + new routes + `SystemStatsCubit`) | ✅ done 2026-05-02 |
| **Desktop redesign M3 Dashboard** (4 stat tiles + Server Info + Quick Access + Recent Activity + Storage donut — pixel-matched prototype; `StorageCubit` + `RecentActivityCubit` + `ActivityEvent` + `LibraryStorageBreakdown` entities) | ✅ done 2026-05-02 |
| **Desktop redesign M4 Library** (grid + stat tiles + FluxTabBar + detail panel + `StorageCubit`) | ✅ done 2026-05-02 |
| **Desktop redesign M4 Clients** (7-col table + search/filter + detail panel — `PageHeader`, `StatTile`, `Pill`, `StatusDot`, `FluxCard`; approve/reject/revoke wired) | ✅ done 2026-05-02 |
| **Desktop redesign M5 Groups** (table + detail panel + create/edit/delete + member management; `GroupsCubit`, `Group` entity) | ✅ done 2026-05-02 |
| **Desktop redesign M5 Activity** (replaced legacy screen; `PageHeader` + search + 4 stat tiles + Live Activity card + Filter sidebar; `RecentActivityCubit` extended with `loadAll`/`pause`/`resume`) | ✅ done 2026-05-02 |
| **Desktop redesign M5 Transcoding** (4 stat tiles + Active Sessions card; `TranscodingCubit` polls 2 s; joins legacy `ActivityCubit` for stream sessions) | ✅ done 2026-05-02 |
| **Desktop redesign M5 Encoder Settings** (sub-page at `/transcoding/encoder`; hardware encoder selector + preset chips + CRF slider + live stats sidebar; reuses `SettingsCubit`) | ✅ done 2026-05-02 |
| **Desktop redesign M6 Logs + Settings** (Logs: structured rows + level/source/since filters + 4 tabs + auto-scroll + pause/resume; Settings: 6-tab side-rail layout — General / Network / Streaming / Security / Advanced / About — wires all 18 §7.10 extended fields; 4 new form primitives: `FluxTextField`, `FluxSelect`, `FluxSwitch`, `FluxSlider`; `LogRecord` domain entity) | ✅ done 2026-05-02 |
| **Desktop redesign M7 Subscription + Profile + Notifications + Help** (Subscription with 3 sub-tabs Overview/Billing/Manage; Profile reuses `/api/v1/profile`; Notifications slide-over overlay subscribed to `WS /ws/notifications`; static Help screen; new entities `Profile` + `AppNotification`; new features `notifications/` + `help/`) | ✅ done 2026-05-02 |
| **Desktop redesign M8 Cmd+K palette** (palette overlay + 13 commands: 12 routes + 2 server actions + 1 notifications toggle; `Cmd+K` on macOS, `Ctrl+K` elsewhere; arrow keys + Enter + Escape; mounted in `flux_shell.dart` via `Shortcuts`/`Actions`/`CommandPaletteScope`) | ✅ done 2026-05-02 |
| Desktop redesign M8 a11y pass + golden-test infra | 🔲 deferred — Sonnet sub-agent only completed the Cmd+K piece; tooltips/Semantics across M3–M7 + golden_toolkit setup pending |
| Desktop redesign M9 (cleanup + final docs) | 🔲 not started |

---

## `apps/web_landing` — Redesigned to v2 violet palette (✅ done 2026-05-02; gap-fix round + background polish + brand asset consolidation also landed 2026-05-02)

- Token migration in `globals.css` (indigo `#6366F1` → violet `#A855F7`, ambient bg radial wash, 3 floating gradient orbs, dot-grid texture, scroll-driven entry animations)
- 7 new components: `PopularMovies`, `LibraryTiles`, `Screenshots` (6-tab gallery), `TierComparison`, `Faq` (zero-JS `<details>`), `AboutStrip`, `FinalCta`
- 7 modified components: `Navbar`, `Hero`, `Features`, `HowItWorks`, `Pricing`, `Platforms`, `Footer`
- Privacy + Terms full-content pages at `/privacy` and `/terms`
- Auto-generated OG card via `app/opengraph-image.tsx`
- Skip-to-content keyboard a11y link + scoped `prefers-reduced-motion`
- `next/font/google` self-hosted Inter
- Brand asset consolidation: shared `logo-wordmark-h.png` (integrated F + FLUXORA) across web + Flutter
- Full SEO: JSON-LD (Organization + WebSite + SoftwareApplication + FAQPage), OG/Twitter, robots.ts, sitemap.ts, manifest.json
- `next build` clean — 10 routes prerendered as static
- **Carry-over manual tasks:** real Polar checkout URLs, real desktop Dashboard screenshot post-M3, footer placeholder links — all tracked in `docs/10_planning/04_manual_tasks.md`

---

## What's next

See `AGENT_LOG.md` "Next Agent Should" section for the prioritised list. As of 2026-05-02:

1. **Desktop redesign M5** — next screens: Groups / Activity / Transcoding / Logs (check prototype JSX for each before starting)
2. **Phase 6 routing hardening** — operator-driven Cloudflare config (Access policies, WAF rules, tunnel-health alerts, TURN evaluation)
3. **Dependabot triage** — Dart 3.9 floor bump may have unstuck PRs blocked on `json_annotation 4.11+`, `go_router 17.x`, `json_serializable 6.13+`
