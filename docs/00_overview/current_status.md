# Current Status

> Snapshot of what's done / in-progress / not-started across the codebase. Update on every significant milestone landing. The roadmap (`docs/10_planning/01_roadmap.md`) tracks future planning; this doc tracks shipped state.

**As of 2026-05-03.** Phases 1–4 complete; Phase 5 in progress (hardware encoding + advanced desktop modules + desktop redesign — M10 custom window chrome shipped 2026-05-03).

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
| **Desktop redesign M8 Cmd+K + a11y pass + golden-test infra** (`Tooltip` + `Semantics` annotations across all 15 surfaces — M3–M7 screens + Logs / Settings / Encoder Settings / Profile / Help / Notifications panel / sidebar / status bar; `golden_toolkit` 0.15.0 + `mocktail` added; M3 Dashboard golden enabled via the GetIt-mock recipe in `setUp` — drop wrapping `MultiBlocProvider`, register mock repos in GetIt, then the screen's own `MultiBlocProvider.create` consumes them. Baseline PNG committed; `dart_test.yaml` skip removed; goldens are opt-in via `--tags=golden` and excluded in CI via `--exclude-tags=golden`. Recipe documented in `test/goldens/_README.md`.) | ✅ done 2026-05-03 |
| **Desktop redesign M9 cleanup** (deleted 4 legacy widgets/screens superseded by M1–M7: `stat_card.dart`, `status_badge.dart`, `data_table.dart`, `licenses_screen.dart` — all unused after the redesign cutover; `flutter analyze` confirmed no remaining references) | ✅ done 2026-05-03 |
| **Desktop V2 theme cutover** (rewrote `apps/desktop/lib/shared/theme/app_theme.dart` body to consume V2 tokens — `bgRoot`, `violet`, `surfaceGlass`, `textBright`, V2 typography, `pillBgPurple` indicator. Fixes the slate-blue scaffold flash on tab switches. Plus 5 V1 stragglers in `encoder_settings_screen.dart`/`clients_screen.dart`/`library_screen.dart`. Desktop is now V2-pure — zero `AppColors.{primary,background,surface,...}` references in `apps/desktop/lib/`. `flutter analyze` clean.) | ✅ done 2026-05-03 |
| **Desktop redesign M10 Custom window chrome** (`window_manager ^0.5.1` added; OS title bar hidden via `TitleBarStyle.hidden` in `main.dart` with `WindowOptions(size: 1440×900, minimumSize: 1332×720)`; new `lib/shared/widgets/flux_titlebar.dart` widget — 36 px tall, `DragToMoveArea` wraps wordmark + tagline, help + bell mid-right, native Win 11 caption-button strip flush right at 46×36 px; `flux_shell.dart` restructured to mount titlebar above the existing Stack so notifications / Cmd+K overlays don't cover it; sidebar `_LogoHeader` deleted to match the updated prototype. Window-control glyphs use Segoe Fluent Icons codepoints `U+E921 / U+E922 / U+E923 / U+E8BB` with Segoe MDL2 Assets fallback. **Branding pass:** `app_icon.ico` regenerated from `assets/brand/logo-icon.png` with tight-crop + 8 % margin (was 59 % glyph fill → now 84 %), runtime copy synced to `windows/runner/resources/`; `Runner.rc` `com.example` placeholders → `Fluxora`; `main.cpp` window title `L"fluxora_desktop"` → `L"Fluxora"`. **Aero Peek shell-integration fix:** `win32_window.cpp` switched `WNDCLASS` → `WNDCLASSEX` so both `hIcon` and `hIconSm` are registered; `main.cpp` calls `SetCurrentProcessExplicitAppUserModelID(L"Fluxora.Desktop")`; `shell32.lib` linked in `windows/runner/CMakeLists.txt`.) | ✅ done 2026-05-03 |

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


1. **Mobile app redesign** — execution gate is now lifted (desktop M0–M10 + theme cutover landed). Plan in `docs/11_design/mobile_redesign_plan.md` — 14 milestones (M0 foundation → M14 polish), V2 palette migration across the entire mobile app.
2. **macOS / Linux desktop runners** — Windows-only today. When generating other-platform runners, port the M10 shell-integration: `WindowOptions.titleBarStyle: hidden` already works cross-platform via `window_manager`; native equivalents needed for `WM_GETMINMAXINFO` (window-size floor), `SetCurrentProcessExplicitAppUserModelID`, and `WNDCLASSEX hIconSm`. Caption-button glyphs need a `Platform.isWindows` swap to `CustomPainter` paths or a vendored TTF since Segoe Fluent Icons / Segoe MDL2 Assets are Windows-only.
3. **Phase 6 routing hardening** — operator-driven Cloudflare config (Access policies, WAF rules, tunnel-health alerts, TURN evaluation).
4. **Dependabot triage** — Dart 3.9 floor bump may have unstuck PRs blocked on `json_annotation 4.11+`, `go_router 17.x`, `json_serializable 6.13+`.
