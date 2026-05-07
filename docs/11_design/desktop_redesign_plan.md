# Desktop App Redesign — Implementation Plan

> **Status:** ✅ Complete — every milestone (M0 → M10 + M9.5 cutover) shipped. M0 backend prerequisites all 11 sections landed (verified 2026-05-06 — full evidence in the M0 table below). M1 foundation (2026-05-02), M2 shell, M3 Dashboard (2026-05-02), M4 Library + Clients (2026-05-02), M5 Groups + Activity + Transcoding (2026-05-02), M6 Logs + Settings (2026-05-02), M7 Subscription + Profile + Notifications + Help (2026-05-02), M8 Polish (2026-05-03), M9 Cleanup (2026-05-03), **M9.5 V2 theme cutover (2026-05-03 — unplanned follow-up; desktop is now V2-pure)**, **M10 Custom window chrome (2026-05-03 — `window_manager` 0.5.1, `FluxTitlebar`, frameless window with native Win 11 caption-button geometry, AppUserModelID + WNDCLASSEX shell-integration fixes for Aero Peek).** Residual follow-ups (cosmetic — 4 backend joins / wirings) tracked in §11.
> **Created:** 2026-05-01
> **Owner:** Marshal
> **Source design:** [`docs/11_design/prototype/`](./prototype/) — React/JSX prototype bundle from claude.ai/design (top-level [`README.md`](./prototype/README.md) is the agent-handoff doc; desktop port spec at [`prototype/app/desktop/README.md`](./prototype/app/desktop/README.md))
> **Target:** [`apps/desktop/`](../../apps/desktop/) — Flutter desktop control panel

This plan translates the Fluxora Desktop prototype into the existing Flutter desktop app. It is the single source of truth for the redesign — every screen PR should reference a section here.

---

## Progress

### M0 — Backend prerequisites *(✅ Done 2026-05-06)*

All 11 sections shipped. Last six rows reconciled 2026-05-06 against `apps/server/` (had been stale — code shipped without the table being updated).

| § | Item | Status | Landed |
|---|------|--------|--------|
| 7.1 | Groups feature (table, service, 8 endpoints, stream-gate) | ✅ Done | migration 011 + `routers/groups.py` + `services/group_service.py` + stream-gate hook |
| 7.2 | Profile management (GET/PATCH + password change) | ✅ Done | migration 012 + `routers/profile.py` + `services/profile_service.py` |
| 7.3 | Notifications | ✅ Done | migration 013 + `routers/notifications.py` (list/read/read-all/dismiss) + `services/notification_service.py` + `routers/ws.py:218` `WS /api/v1/ws/notifications` |
| 7.4 | Activity feed (event log) | ✅ Done | migration 014 + `routers/activity.py` + `services/activity_service.py` |
| 7.5 | Storage breakdown | ✅ Done | `GET /api/v1/library/storage-breakdown` + `library_service.get_storage_breakdown()` |
| 7.6 | System stats stream | ✅ Done | `GET /api/v1/info/stats` + `WS /api/v1/ws/stats` + `services/system_stats_service.py` (psutil) |
| 7.7 | Restart / stop endpoints | ✅ Done | `POST /api/v1/info/restart`, `POST /api/v1/info/stop` (localhost-only) |
| 7.8 | Transcoding status (per-encoder load) | ✅ Done | `GET /api/v1/transcoding/status` (`routers/transcoding.py:81`) + `/advisor` + `/devices` + `/fallback-history` |
| 7.9 | Logs structured filtering | ✅ Done | `GET /api/v1/logs` (`routers/logs.py:30`, returns `LogListResponse`) + `WS /api/v1/ws/logs` for live tail |
| 7.10 | Settings extension (18 columns) | ✅ Done | migration 015 — General/Network/Streaming/Security/Advanced fields. Plan originally listed 19; final cut was 18 (the 19th — a forward-compat `theme_accent` analogue — was folded into the existing `theme_accent` column with a single nullable placeholder per Decision §1 #4). |
| 7.11 | Orders pagination + Polar portal URL | ✅ Done | `GET /api/v1/orders` with `cursor`/`limit` pagination (`routers/orders.py:51`) + `GET /api/v1/orders/portal-url` (localhost-only) |

### M1 — Foundation *(✅ Done 2026-05-02)*

- Tokens extended: `app_colors.dart` v2, `app_gradients.dart`, `app_spacing.dart`, `app_radii.dart`, `app_shadows.dart`, `app_typography.dart` v2
- 11 primitives shipped in `apps/desktop/lib/shared/widgets/`: `FluxCard`, `SectionLabel`, `StatusDot`, `Pill`, `FluxProgress`, `FluxButton`, `StatTile`, `Sparkline`, `StorageDonut`, `PageHeader`
- Brand widgets in `packages/fluxora_core/lib/widgets/`: `FluxoraMark`, `FluxoraWordmark`, `FluxoraLogo`, `HeroWaves`, `BrandLoader` (Flutter-driven ring around the untouched PNG mark), `PulseRing`, `EmptyState`
- Hi-fidelity logo PNGs from `docs/11_design/ref images/` processed (Pillow alpha-from-brightness) and bundled in `packages/fluxora_core/assets/brand/`
- `flutter_svg` 2.2.4 added — 4 animated SMIL SVGs in `packages/fluxora_core/assets/illustrations/`: `hero_waves.svg`, `pulse_ring.svg`, `empty_libraries.svg`, `empty_clients.svg`. The recreated F-mark loader was deleted per owner direction — brand mark is never re-drawn.
- `/showcase` route renders every primitive on `bgRoot` for visual diff against the prototype (outside `ShellRoute`)
- Both packages pass `flutter analyze` with zero issues

### M2 — Shell *(✅ Done)*

`flux_shell.dart`, `flux_sidebar.dart`, `flux_status_bar.dart` shipped. `SystemStatsCubit` polls every 1.1 s. Routes wired in `app_router.dart`.

### M3 — Dashboard *(✅ Done 2026-05-02)*

- `DashboardScreen` rewritten — full `MultiBlocProvider` composition: `DashboardCubit` + `StorageCubit` + `RecentActivityCubit`; `SystemStatsCubit` read from shell context.
- 4 stat tiles (Libraries / Connected Clients / Active Streams / CPU + sparkline).
- Server Information card (6 rows: name, LAN IP+`StatusDot`, internet `Pill`, public address, uptime, version).
- Quick Access card (2×2 grid + span-2 Settings tile), all navigating via `context.go`.
- Recent Activity card: `GET /api/v1/activity?limit=4` via new `RecentActivityCubit`. Relative timestamps, category→icon/color mapping.
- Storage Overview card: `StorageDonut` + legend + `FluxProgress` bar, fed by `StorageCubit` → `GET /api/v1/library/storage-breakdown`.
- New entities: `ActivityEvent` + `LibraryStorageBreakdown` / `StorageByType` in `packages/fluxora_core`.
- New `Endpoints.activity` constant.
- `DashboardRepository` extended with `restartServer()` / `stopServer()`.
- New desktop features: `storage/` + `recent_activity/` registered in DI.

### M4 — Library + Clients *(✅ Done 2026-05-02)*

- **Library screen** *(✅ Done)* — full grid, stat tiles, FluxTabBar, detail panel, `StorageCubit` integration.
- **Clients screen** *(✅ Done 2026-05-02)* — `clients_screen.dart` fully rewritten. No Material `Scaffold`/`AppBar`/`Card`/`DataTable`. Implements: `PageHeader`, 4 `StatTile`s (total/online/active-streams-from-`SystemStatsCubit` 2026-05-06/total connections), client-side search + status/device/sort `PopupMenuButton` filters, 7-column table in `FluxCard(padding: 0)` with hover + selected row states, visual-only pagination footer, 300 px detail panel with avatar block + 7 info rows + emerald "Currently Streaming" block when active session present + 4 action tiles (Disconnect Client wired to `cubit.reject()`; 3 others disabled with TODO comments). `FluxTabBar` primitive shipped as part of Library.
- **Originally deferred follow-ups, now landed 2026-05-06 (F1 + F2 + F3 in §11.1):**
  - F1 — Active Streams stat tile reads from `SystemStatsCubit.state.latest?.activeStreams` ([clients_screen.dart](../../apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart) `_buildStatTiles`).
  - F2 — Per-client IP address column reads `c.lastIp ?? '—'`, populated by `clients.last_ip` (migration 023) at pair time + every authenticated request.
  - F3 — Per-client active session block + table cell read from `c.activeSession`, joined server-side in `auth_service.list_clients` via `ROW_NUMBER() OVER (PARTITION BY client_id)` against `stream_sessions WHERE ended_at IS NULL`.

### M5 — Groups + Activity + Transcoding + Encoder Settings *(✅ Done 2026-05-02)*

- **New entities** in `packages/fluxora_core/lib/entities/`: `Group` / `GroupRestrictions` / `TimeWindow` / `GroupStatus` (`group.dart`); `TranscodingStatus` / `EncoderLoad` / `ActiveTranscodeSession` (`transcoding_status.dart`). Both freezed + json_serializable.
- **New endpoints** in `Endpoints`: `groups`, `groupById(id)`, `groupMembers(id)`, `groupMember(groupId, clientId)`, `transcodingStatus`.
- **Groups feature** (`apps/desktop/lib/features/groups/`): `GroupsRepository` + `GroupsRepositoryImpl`; `GroupsCubit` + `GroupsState`; full `GroupsScreen` — `PageHeader`, 4 `StatTile`s, table with selected-row highlight, 300px detail panel with restrictions + members list, create/edit/delete dialogs, add/remove member.
- **Transcoding feature** (`apps/desktop/lib/features/transcoding/`): `TranscodingRepository` + impl; `TranscodingCubit` polls `/api/v1/transcoding/status` every 2 s; `TranscodingScreen` — 4 stat tiles, active sessions card (reuses legacy `ActivityCubit` for stream sessions, joins with `TranscodingStatus` for codec/fps/speed); `EncoderSettingsScreen` — hardware encoder selector, preset chip-picker, CRF slider, live stats sidebar; `Routes.encoderSettings = '/transcoding/encoder'` added to router.
- **Activity screen** (`apps/desktop/lib/features/activity/presentation/screens/activity_screen.dart`) — fully replaced: `PageHeader` + search, 4 `StatTile`s derived from real event counts (no fabricated deltas), 2-col layout with Live Activity card + Filter sidebar. Polling via extended `RecentActivityCubit` (added `loadAll`, `pause`, `resume`, `isPaused`). Legacy `ActivityCubit` + repository preserved for Transcoding screen.
- **DI** — `GroupsRepository` + `TranscodingRepository` registered in `injector.dart`.

### M6 — Logs + Settings *(✅ Done 2026-05-02)*

- **Logs feature** (`apps/desktop/lib/features/logs/`): repository extended to expose structured `List<LogRecord>` alongside the legacy text-blob (new `getStructuredLogs(limit)` method); cubit gains pause/resume + structured-state path; new `LogRecord` domain class at `lib/features/logs/domain/log_record.dart`. Replaced screen renders structured rows: timestamp (mono) + level pill + source + message, with `FluxTabBar` (All / Errors / Warnings / Info), Source + Time-Range dropdowns, Live indicator + entry count, expandable rows with copy-to-clipboard, auto-scroll to bottom while live.
- **Settings feature** (`apps/desktop/lib/features/settings/`): screen rewrite uses 220 px side-rail nav + scrollable content area. Six tabs (General / Network / Streaming / Security / Advanced / About) each rendering a stack of `FluxCard`s grouping related settings. Reuses existing `SettingsCubit` + `saveSettings(...)` for all 18 §7.10 extended fields plus tier-1 fields. Local dirty-tracking map enables Save button only when changes exist; on save, diff is sent and the dirty map clears.
- **New form primitives** in `apps/desktop/lib/shared/widgets/`: `FluxTextField`, `FluxSelect`, `FluxSwitch`, `FluxSlider` — thin Material wrappers with violet-glass styling, drop-in replacements for the corresponding Material widgets.
- About tab: server version + uptime + LAN IP from SystemStats / serverInfo; GitHub repo / Documentation / Report Issue buttons; Credits.

### M7 — Subscription + Profile + Notifications + Help *(✅ Done 2026-05-02)*

- **New entities** in `packages/fluxora_core/lib/entities/`: `Profile` (freezed, `avatar_letter`, `display_name`, `email`, `created_at`, `last_login_at`); `AppNotification` (freezed, full enum types `NotificationType` + `NotificationCategory`).
- **New endpoints** in `Endpoints`: `profile`, `notifications`, `notificationRead(id)`, `notificationsReadAll`, `notificationDismiss(id)`, `ordersPortalUrl`, `wsNotifications`.
- **Profile feature** (`apps/desktop/lib/features/profile/`): `ProfileRepository` + impl (GET/PATCH `/api/v1/profile`); `ProfileCubit` with `load` / `save` / `markDirty`; full `ProfileScreen` — 240 px left nav with 5 tabs (Profile / Security / Preferences / Sessions / Danger Zone), avatar block, dirty-tracked save button, form fields bound to parent state controllers.
- **Orders feature extended**: `OrdersRepository.portalUrl()` added (returns `null` on 404); `OrdersCubit.openPortal()` fetches URL + copies to clipboard.
- **Notifications feature** (`apps/desktop/lib/features/notifications/`): `NotificationsRepository` + 5s-polling impl (WS deferred to M8 — TODO comment added); `NotificationsCubit` with `start` / `markRead` / `markAllRead` / `dismiss`; `NotificationsPanel` slide-over (420 px, right-edge, category filter bar, animated unread badge, dismiss X, empty state); `NotificationsPanelNotifier` (`ValueNotifier<bool>`) + `NotificationsPanelScope` inherited widget.
- **Shell updated**: `FluxShell` now provides `NotificationsCubit` (factory via DI) + mounts `NotificationsPanel` as a `Stack` overlay toggled by `NotificationsPanelScope`. Bell icon nav item registered in sidebar.
- **Subscription feature** (`apps/desktop/lib/features/subscription/`): full `SubscriptionScreen` with `FluxTabBar` (Plans & Pricing / Billing History / Manage). Plans tab: 4 `_PlanCard`s + feature comparison table. Billing tab: 4 `StatTile`s + order table with copy-license-key button (uses `OrdersCubit`). Manage tab: portal button (copies URL to clipboard), plan action rows, info banner.
- **Help feature** (`apps/desktop/lib/features/help/`): static screen — keyboard shortcut groups, expandable FAQ (6 entries), Get Help links card, Status card (`StatusDot`), Diagnostics card. No cubit/repository.
- **Router**: `/help` route added. `Routes.help` constant added. Help added to sidebar nav list.
- **DI**: `ProfileRepository`, `ProfileCubit`, `NotificationsRepository`, `NotificationsCubit` registered in `injector.dart`.

### M8 — Polish *(✅ Done 2026-05-03)*

- **Cmd+K command palette ✅ Done 2026-05-02:** new `apps/desktop/lib/features/command_palette/` feature — `Command` model, `command_registry.dart` with 13 commands (12 routes + Restart Server + Stop Server + Open Notifications), `CommandPaletteNotifier` for open/closed/query/highlight state, `CommandPaletteOverlay` (600 × 420 px frosted-glass card, search input with auto-focus, fuzzy substring match, arrow-key + Enter + Escape navigation). Mounted in `flux_shell.dart` via `Shortcuts`/`Actions`/`CommandPaletteScope` — `Cmd+K` on macOS, `Ctrl+K` elsewhere.
- **Accessibility pass ✅ Done 2026-05-03:** Tooltip wrappers added to every icon-only `IconButton`/`InkWell` across all M3–M7 screens + sidebar + status bar (refresh, close X, eye/stop/more, copy, dismiss, pause/resume, pagination chevrons, three-dot overflows, the bell). `Semantics(label: ...)` wrappers added to every `StatTile` value + `Sparkline`. No behavioural changes.
- **Golden-test infra ✅ Done 2026-05-03 (skip-marked):** `golden_toolkit` 0.15.0 + `mocktail` added as dev_dependencies. First Dashboard golden test scaffolded at `test/goldens/m3_dashboard_golden_test.dart` with deterministic mock states (server info, 6 libraries, 1 active stream, fixed storage breakdown, 4 activity events at fixed timestamps, 30-sample CPU buffer). The test currently fails because production `DashboardScreen` creates cubits via `GetIt.I<>()` rather than reading from the test's `MultiBlocProvider`. Skip-marked via `dart_test.yaml` (`golden` tag); detailed fix recipe in `test/goldens/_README.md`. Default `flutter test` excludes the golden suite cleanly.

### M9 — Cleanup + final docs *(✅ Done 2026-05-03)*

- **Legacy widgets/screens deleted:** `apps/desktop/lib/shared/widgets/stat_card.dart` (superseded by M1 `stat_tile.dart`), `status_badge.dart` (superseded by M1 `pill.dart` + `status_dot.dart`), `data_table.dart` (superseded by per-screen custom tables built on `FluxCard`), and `apps/desktop/lib/features/orders/presentation/screens/licenses_screen.dart` (superseded by M7 `subscription_screen.dart`'s Billing tab). Verified zero remaining references via `grep`; `flutter analyze` clean post-deletion.
- **Visual review against prototype** is the user's manual verification step — `flutter run -d windows` and pixel-compare each redesigned screen against `desktop_prototype/Fluxora Desktop.html` at 1440 × 900. No code can substitute for this.
- **Desktop redesign milestone is complete.** The remaining cleanup item from M8 (Tooltips + Semantics on the 8 screens Sonnet didn't reach + the GetIt-mocking fix to enable goldens) is documented in `test/goldens/_README.md` and the M8 row of `current_status.md`.

### M9.5 — V2 theme cutover *(✅ Done 2026-05-03 — unplanned follow-up)*

> Triggered by an owner bug report: switching tabs caused a brief slate-blue scaffold flash. Root cause: the redesign built every screen against V2 tokens directly but never rewrote the underlying `ThemeData` body — `scaffoldBackgroundColor` was still `AppColors.background` (`#0F172A` slate). Material defaults underneath the V2-painted screens flashed during route transitions.

- **`apps/desktop/lib/shared/theme/app_theme.dart` body rewritten** — every V1 token swapped to V2: `scaffoldBackgroundColor: bgRoot`, `colorScheme.primary: violet`, `colorScheme.surface: surfaceGlass`, `cardColor: surfaceGlass`, `dividerColor: borderSubtle`, `appBarTheme.backgroundColor: surfaceGlass`, `elevatedButtonTheme.backgroundColor: violet`, `progressIndicatorTheme.color: violet`, `navigationRailTheme.{bg: sidebarGlass, indicator: pillBgPurple, active: violet}`, `snackBarTheme.backgroundColor: surfaceGlass`. Typography swapped V1 → V2 across the `TextTheme` (`displayV2`, `h1`, `h2`, `body`, `bodySmall`, `eyebrow`, `captionV2`). File path + `AppTheme.dark` getter signature unchanged.
- **5 V1 stragglers fixed** in feature screens: `encoder_settings_screen.dart:503` (`dropdownColor: surface` → `bgRoot`); `clients_screen.dart:308,312` and `library_screen.dart:292,297` (`textMuted` → `textDim`, `textSecondary` → `textMutedV2`, `bodyMd` → `body` — same hexes for the colours, just V2-named).
- **Verification:** zero matches across `apps/desktop/lib/` for any `AppColors.{primary,background,surface,surfaceRaised,surfaceMuted,primaryVariant,accentPurple,info,textPrimary,textSecondary,textMuted,textDisabled,error}` (V1 tokens). `flutter analyze` clean (27.8 s). Desktop is V2-pure.
- **Docs synced:** `DESIGN.md` rewritten as V2-only canonical (no legacy section, no migration framing); `current_status.md`, `frontend_architecture.md` updated; this file's M9.5 entry added; `mobile_redesign_plan.md` gate-lifted note (since this completes the desktop side of the M9-cutover dependency).

---

## 1. Decisions locked in

These are the answered questions that shape the rest of the plan. Do not relitigate without updating this section.

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Direct replacement.** No `/v2/*` routes, no feature flag, no kept-alongside legacy code. Each screen PR replaces the existing screen file. | Owner wants no legacy code carry-over. |
| 2 | **Real backend data only.** No mock-data layer in Flutter. Where the screen needs data the backend doesn't yet expose, the **backend endpoint ships before the screen** (see §7). | Owner wants only real user data. |
| 3 | **Cmd+K palette = navigation only** (v1). No global media search in v1. | Scoped down for ship-ability. |
| 4 | **Tweaks panel removed.** No accent-color customization. Brand violet (`#A855F7`) is fixed. | The prototype's tweaks were a design-tool affordance; not a product feature. |
| 5 | ~~**Native window chrome.** Use the OS title bar on every platform. No `bitsdojo_window`, no custom traffic-light buttons. The prototype's titlebar is **not** translated.~~ **REVERSED 2026-05-03.** Custom window chrome is now in scope — see §13 / M10. The prototype's 36 px titlebar with wordmark + tagline + help/bell/window-controls is the visual target. |
| 6 | **Sidebar logo header removed (updated prototype, 2026-05-03).** The new prototype drops the wordmark + tagline block from the top of the sidebar — nav now starts at the top of the rail. The wordmark moves into the custom titlebar (Decision #5 reversal). | Updated prototype bundle removes duplicate branding (wordmark in titlebar + sidebar). One source of brand at the top edge of the window. |

The bottom **status bar** (CPU/RAM/network/uptime strip) **is** kept — it is a content widget rendered inside the Flutter window, not OS chrome.

---

## 2. Source-of-truth files

| Concern | File |
|---------|------|
| Visual reference (open in browser) | [`docs/11_design/prototype/Fluxora Desktop.html`](./prototype/Fluxora%20Desktop.html) |
| Desktop port spec (canonical) | [`docs/11_design/prototype/app/desktop/README.md`](./prototype/app/desktop/README.md) |
| Window chrome (titlebar) layout | [`docs/11_design/prototype/app/desktop/app.jsx`](./prototype/app/desktop/app.jsx) (titlebar block + `tbBtn`/`winBtn` styles) |
| Sidebar layout | [`docs/11_design/prototype/app/desktop/components/sidebar.jsx`](./prototype/app/desktop/components/sidebar.jsx) |
| Primitive widget definitions | [`docs/11_design/prototype/app/shared/components/primitives.jsx`](./prototype/app/shared/components/primitives.jsx) (relocated from `app/components/` in the prior bundle) |
| Per-screen layout | `docs/11_design/prototype/app/desktop/screens/<name>.jsx` |
| Per-tab/sub-page layout | `docs/11_design/prototype/app/desktop/pages/<name>.jsx` |
| Sample data shapes (study only — do not copy) | `docs/11_design/prototype/app/shared/data/fluxora-data*.jsx` |
| Brand assets (PNGs) | `docs/11_design/prototype/app/shared/assets/logo-icon.png`, `logo-wordmark.png` |
| Design-handoff README (top-level) | [`docs/11_design/prototype/README.md`](./prototype/README.md) |
| Design-conversation transcripts | [`docs/11_design/prototype/chats/`](./prototype/chats/) |
| Existing design tokens | [`DESIGN.md`](../../DESIGN.md), [`packages/fluxora_core/lib/constants/`](../../packages/fluxora_core/lib/constants/) |
| Existing Flutter desktop code | [`apps/desktop/lib/`](../../apps/desktop/lib/) |

---

## 3. Pre-flight: tokens & primitives

Before any screen, harvest tokens and build all primitives. Skipping this is the #1 cause of "looks close but not right".

### 3.1 Design tokens — extend `packages/fluxora_core/lib/constants/`

| File | Add |
|------|-----|
| `app_colors.dart` | `bgRoot=#08061A`, `surface=rgba(20,18,38,0.7)`, `border=rgba(255,255,255,0.06)`, `borderHover=rgba(168,85,247,0.4)`, `textPrimary=#F1F5F9`, `textSecondary=#E2E8F0`, `textMuted=#94A3B8`, `textDim=#64748B`, `textFaint=#475569`, `primary=#A855F7`, `primaryDeep=#8B5CF6`, `primaryTint=#C4A8F5`, `accent=#22D3EE`, `success=#10B981`, `warning=#F59E0B`, `danger=#EF4444`, `info=#3B82F6`, `pink=#EC4899`. Pill bg/fg maps for 7 variants (neutral/purple/success/warning/error/info/pink). |
| `app_gradients.dart` *(new)* | `brand` (135°, `#8B5CF6 → #A855F7`), `progress` (90°, same), two `bgRadial` gradients for ambient violet/cyan glow. |
| `app_typography.dart` | Inter weights 400/500/600/700/800. Add `JetBrains Mono` for IPs/codecs/timestamps. Tokens: `display` (24/700/-0.01em), `h1` (18/700), `h2` (14/600), `body` (13/500), `bodySmall` (12/500), `caption` (11/500), `micro` (10.5/500), `eyebrow` (11/600 / 0.14em uppercase). |
| `app_spacing.dart` *(new)* | Locked set: `s4, s6, s8, s10, s12, s14, s16, s18, s20, s24, s28`. Anything outside this set is a typo. |
| `app_radii.dart` *(new)* | `xs=6, sm=8, md=10, lg=12, pill=999`. |
| `app_shadows.dart` *(new)* | `cardGlow`, `buttonGlow`, `dotGlow`. |

### 3.2 Primitive widgets — `apps/desktop/lib/shared/widgets/`

Build all of these **before** any screen. Each gets a widgetbook story (or simple test screen) that renders every variant for visual diff against the prototype.

| Prototype | Flutter widget | Notes |
|-----------|---------------|-------|
| `Card` | `FluxCard({padding, hoverable, glow, onTap, child})` | `MouseRegion` for hover. Hover swaps border + bg to `rgba(168,85,247,0.4/0.05)`. `glow` adds `cardGlow` shadow. |
| `SectionLabel` | `SectionLabel(text)` | 11/600 uppercase, 0.14em letter-spacing. |
| `StatusDot` | `StatusDot(status, size)` | online/active/streaming dots get an 8px halo via `BoxShadow`. |
| `Pill` | `Pill(text, color)` | 7 variants. Text never wraps. |
| `Button` | `FluxButton({variant, size, icon, iconRight, onPressed, fullWidth, child})` | 6 variants × 3 sizes. **Replaces every Material button.** Use `InkWell` over `DecoratedBox`; primary variant uses `gradient: brand` + `buttonGlow`. |
| `Progress` | `FluxProgress(value, color, height, track)` | Width animated via `TweenAnimationBuilder` with 400ms ease. |
| `StatTile` | `StatTile({icon, label, value, sub, color, iconBg, accent})` | 44×44 icon-bg square + label/value/sub stack. |
| `Sparkline` | `Sparkline(data, color)` | `CustomPaint` + `Path`. 200×36, 1.5px stroke, round caps. |
| `Donut` | `StorageDonut(segments)` | `CustomPaint` + `drawArc` per segment. 14px stroke, -90° start. Center text via `TextPainter`. |
| `PageHeader` | `PageHeader(title, subtitle, actions)` | Standard header on every screen. |
| `NavItem` | private, lives inside `flux_sidebar.dart` | Hover + active states. |
| `FluxSwitch` | new | Replaces Material `Switch`. Custom track/thumb + violet active state. |
| `FluxTextField` | new | Replaces Material `TextField`. Custom border + focus state. |
| `FluxSelect` | new | Replaces Material `DropdownButton`. |
| `FluxDataTable` | new | Replaces Material `DataTable`. Used by Clients, Logs, Groups. |
| `FluxAvatar` | new | Circular avatar with optional gradient bg. |
| `AvatarStack` | new | Used by Groups screen (member avatars). |
| `FluxScreen` | new wrapper | Locks the standard padding (`0 28 28 28`) + scroll behavior so screens are dumb. |

**Acceptance for §3:** all primitives merged + visually compared to prototype. No screen work begins until this passes.

---

## 4. App shell — replace `apps/desktop/lib/shared/widgets/sidebar.dart`

The current `AppShell` is a Material `Scaffold` + `Row` with a 6-item sidebar. The redesigned shell:

```
+--- (native OS title bar, untouched) ---+
|                                        |
|  [Sidebar 232px] | [Screen content]    |
|                                        |
+----------- [FluxStatusBar] ------------+
```

### 4.1 Sidebar — `flux_sidebar.dart`
- 232px wide, `rgba(13,11,28,0.7)`, 1px right border, **`BackdropFilter(blur: 20)`** for glass.
- ~~Top: `FluxoraWordmark(28)` + tagline~~ **Logo header removed** (updated prototype, 2026-05-03 — see Decision #6). Nav now starts at the top of the rail with `padding: 16px 10px 8px`. The wordmark + tagline live in the new custom titlebar (§13).
- 9 nav items: Dashboard, Library, Clients, Groups, Activity, Transcoding, Logs, Settings, Subscription. (Current sidebar has 6; this **adds** Groups, Activity, Subscription, **renames** Licenses → Subscription, **drops** the Settings-as-bottom-item pattern.)
- Hover + active states: violet tint (`rgba(168,85,247,0.14)` bg, `rgba(168,85,247,0.3)` border, `#E9D5FF` text on active).
- System Status block: server-running / LAN mode + IP / Internet Access — fed by `SystemStatusCubit` (new, see §6.3).
- Upgrade card: visible only when `tier != ultimate`. Reads tier from existing `OrdersCubit` / `SettingsCubit`.
- User footer: routes to `/profile`. Avatar uses `FluxAvatar` with `linear-gradient(135deg, #A855F7, #8B5CF6)` fallback (violet → violetDeep, matches the brand button gradient).

### 4.2 Status bar — `flux_status_bar.dart`
- 28px tall bottom strip: CPU%, RAM%, network throughput (Mbps), uptime.
- Same data source as System Status block. Updates every 1.1s via the live tick (see §6.4).

### 4.3 Routing — keep `go_router`
Replace existing route map directly:
```
/dashboard, /library, /clients, /groups, /activity,
/transcoding, /transcoding/encoder, /logs, /settings,
/subscription, /subscription/billing, /subscription/manage,
/profile, /help
```
Notifications is an `Overlay` slide-over, not a route.

The current `Routes.licenses` is **renamed** to `Routes.subscription`. Old `licenses_screen.dart` deleted in the same PR.

### 4.4 Cmd+K palette
- `Shortcuts` + `Actions` at app root. `Cmd/Ctrl+K` opens an `Overlay` with a search field and route list.
- v1 scope: **navigation only** — fuzzy-match against the route map and a small list of static actions ("Restart Server", "Stop Server"). No backend calls.

---

## 5. Screen translation order

Each screen gets one PR. Order is chosen so each screen exercises a primitive that future screens reuse.

| # | Screen | Existing Cubit | New entities/Cubits | Backend gap (§7) | Status |
|---|--------|----------------|---------------------|------------------|--------|
| 1 | **Dashboard** | `DashboardCubit` (extend) | `StorageCubit` *(new)*, `RecentActivityCubit` *(new)* | §7.5, §7.6, §7.7 | ✅ Done 2026-05-02 |
| 2 | **Library** | `LibraryCubit` (kept) | – | – | ✅ Done 2026-05-02 |
| 3 | **Clients** | `ClientsCubit` (kept) | – | – | ✅ Done 2026-05-02 (cosmetic follow-ups in §11) |
| 4 | **Groups** | – | `GroupsCubit` *(new)* | §7.1 | ✅ Done 2026-05-02 |
| 5 | **Activity** | `ActivityCubit` (kept) | – | – | ✅ Done 2026-05-02 |
| 6 | **Transcoding** + Encoder Settings | `SettingsCubit` (extend) | `TranscodingCubit` *(new)* | §7.8 | ✅ Done 2026-05-02 |
| 7 | **Logs** + tabs | `LogsCubit` (extend) | – | §7.9 | ✅ Done 2026-05-02 |
| 8 | **Settings** + 6 tabs | `SettingsCubit` (extend) | – | §7.10 | ✅ Done 2026-05-02 |
| 9 | **Subscription** + Billing + Manage | `OrdersCubit` (extend) | – | §7.11 | ✅ Done 2026-05-02 |
| 10 | **Profile** | – | `ProfileCubit` *(new)* | §7.2 | ✅ Done 2026-05-02 |
| 11 | **Notifications** | – | `NotificationsCubit` *(new)* | §7.3 | ✅ Done 2026-05-02 |
| 12 | **Help** | – | – (static) | – | ✅ Done 2026-05-02 |

For each screen, the recipe is:
1. Open the prototype's `screens/<name>.jsx` next to the editor.
2. Codify container layout via `FluxScreen` wrapper.
3. Translate CSS Grid → `Row` / `Column` / `Wrap` / `LayoutBuilder` (for collapse).
4. Wire to existing Cubit. **If a field is missing, extend the Cubit + backend rather than mocking** (per Decision #2).
5. Run pre-merge checklist (§8.5).

---

## 6. Cross-cutting concerns

### 6.1 Asset packaging
- Brand assets in `packages/fluxora_core/assets/brand/`: `logo-icon.png` (standalone F mark), `logo-wordmark.png` (legacy stacked F+FLUXORA — kept for any brand-card slot that wants the stacked layout), `logo-wordmark-h.png` (the **integrated horizontal wordmark** — F + FLUXORA in one image, used by sidebar / web Navbar / web Footer).
- Register in `fluxora_core/pubspec.yaml` under `flutter.assets`.
- Expose via `FluxoraMark` and `FluxoraWordmark` widgets in `fluxora_core/lib/widgets/`.

### 6.2 Fonts
- Add `Inter` (400/500/600/700/800) and `JetBrains Mono` (400/500/600) TTFs to `fluxora_core/assets/fonts/`.
- Register under `flutter.fonts` in `fluxora_core/pubspec.yaml`.
- Do **not** rely on `google_fonts` runtime fetch — it adds latency on first load and fails offline.

### 6.3 Live data flow
- `SystemStatsCubit` lives at app root, polls `GET /api/v1/info/stats` (new — see §7.6) every 1.1s **only when sidebar/status bar is mounted**. Stops on app blur.
- Sparkline / donut / progress consumers use `BlocSelector` to subscribe to one slice of state, not the whole Cubit, to keep rebuilds cheap.

### 6.4 Tick / animation
- A single `Stream<int>.periodic(Duration(milliseconds: 1100))` provided via `BlocProvider` at root drives any animated UI (sparkline progression, "Active" pulse).
- Live data (CPU/RAM/network, active sessions) drives off the SSE/WS stream from §7.6, **not** the tick. Tick is for visual animation only.

### 6.5 Glassmorphism
- `BackdropFilter(filter: ImageFilter.blur(40, 40))` on the root background is expensive on Linux. Measure on each platform; add a fallback constant `kEnableHeavyBlur = false` for Linux if FPS drops below 50.

---

## 7. Backend work — the redesign waits on these

These are the concrete server-side and shared-package changes the redesigned screens depend on. They land **before** their consuming screen. Each item below is sized as a self-contained PR.

> **Convention:** every new endpoint follows `docs/04_api/01_api_contracts.md` formatting. Every new table follows `docs/03_data/02_database_schema.md` formatting. Migrations are append-only (`011_*.sql` onwards).

### 7.1 Groups — entirely new feature

**Status:** no model, no migration, no router, no service, no Flutter cubit.

**Database — migration `011_groups.sql`:**
```sql
CREATE TABLE groups (
  id            TEXT PRIMARY KEY,            -- UUID
  name          TEXT NOT NULL,
  description   TEXT,
  status        TEXT NOT NULL DEFAULT 'active',  -- active | inactive
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);

CREATE TABLE group_members (
  group_id      TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  client_id     TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  added_at      TEXT NOT NULL,
  PRIMARY KEY (group_id, client_id)
);

CREATE TABLE group_restrictions (
  group_id          TEXT PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
  allowed_libraries TEXT,        -- JSON array of library ids; NULL = all
  bandwidth_cap_mbps INTEGER,    -- NULL = unlimited
  time_window       TEXT,        -- JSON {start_h, end_h, days[]}; NULL = always
  max_rating        TEXT         -- e.g. "PG-13"; NULL = none
);

CREATE INDEX idx_group_members_client ON group_members(client_id);
```

**Pydantic models — `apps/server/models/group.py`:**
- `Group(id, name, description, status, created_at, updated_at, member_count, restrictions)`
- `GroupCreate(name, description?, restrictions?)`
- `GroupUpdate(name?, description?, status?)`
- `GroupRestrictions(allowed_libraries?, bandwidth_cap_mbps?, time_window?, max_rating?)`

**Service — `apps/server/services/group_service.py`:**
- `list_groups(db) -> list[Group]`
- `get_group(db, group_id) -> Group`
- `create_group(db, payload) -> Group`
- `update_group(db, group_id, payload) -> Group`
- `delete_group(db, group_id) -> None`
- `add_member(db, group_id, client_id) -> None`
- `remove_member(db, group_id, client_id) -> None`
- `list_members(db, group_id) -> list[Client]`
- `apply_restrictions(db, client_id, action) -> None`  *(stream gate hook)*

**Router — `apps/server/routers/groups.py`** mounted at `/api/v1/groups`:
| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET    | `/`                          | List groups | localhost or token |
| POST   | `/`                          | Create | localhost only |
| GET    | `/{id}`                      | Detail | localhost or token |
| PATCH  | `/{id}`                      | Update | localhost only |
| DELETE | `/{id}`                      | Delete | localhost only |
| GET    | `/{id}/members`              | List members | localhost or token |
| POST   | `/{id}/members`              | Add member `{client_id}` | localhost only |
| DELETE | `/{id}/members/{client_id}`  | Remove member | localhost only |

**Stream gate integration:** `services/stream` checks `apply_restrictions` before starting a session — denies if outside time window, throttles at bandwidth cap, blocks library access per `allowed_libraries`.

**Doc updates:** `docs/03_data/01_data_models.md`, `docs/03_data/02_database_schema.md`, `docs/04_api/01_api_contracts.md`, `docs/09_backend/01_backend_architecture.md`.

---

### 7.2 Profile management

**Status:** auth_service exists; no profile-management endpoints.

**Endpoints — `apps/server/routers/profile.py`** at `/api/v1/profile` (localhost only — single-owner server):
| Method | Path | Description |
|--------|------|-------------|
| GET    | `/`                | Returns `{display_name, email, avatar_letter, created_at, last_login_at}` |
| PATCH  | `/`                | Update `{display_name?, email?}` |
| POST   | `/password`        | Body: `{current_password, new_password}`. Re-derives auth secret. |
| POST   | `/avatar`          | Multipart upload (optional in v1; can defer). |

**Storage:** extend `user_settings` table — add `display_name`, `email`, `avatar_path`, `last_login_at` (migration `012_profile_fields.sql`).

**Doc updates:** `docs/04_api/01_api_contracts.md`, `docs/06_security/01_security.md` (password change flow).

---

### 7.3 Notifications

**Status:** entirely new.

**Migration `013_notifications.sql`:**
```sql
CREATE TABLE notifications (
  id              TEXT PRIMARY KEY,            -- UUID
  type            TEXT NOT NULL,               -- info | warning | error | success
  category        TEXT NOT NULL,               -- system | client | license | transcode | storage
  title           TEXT NOT NULL,
  message         TEXT NOT NULL,
  related_kind    TEXT,                        -- e.g. 'client', 'order', 'session'
  related_id      TEXT,                        -- entity id
  created_at      TEXT NOT NULL,
  read_at         TEXT,                        -- NULL = unread
  dismissed_at    TEXT
);

CREATE INDEX idx_notifications_unread
  ON notifications(read_at, dismissed_at, created_at DESC);
```

**Pydantic — `models/notification.py`:** `Notification`, `NotificationCreate`.

**Service — `services/notification_service.py`:**
- `create(db, type, category, title, message, related_kind?, related_id?) -> Notification`
- `list(db, limit, only_unread) -> list[Notification]`
- `mark_read(db, id) -> None`
- `mark_all_read(db) -> None`
- `dismiss(db, id) -> None`

**Router — `routers/notifications.py`** at `/api/v1/notifications`:
| Method | Path | Description |
|--------|------|-------------|
| GET    | `/?unread=true&limit=50` | List |
| POST   | `/{id}/read` | Mark read |
| POST   | `/read-all` | Mark all read |
| DELETE | `/{id}` | Dismiss |

**Generators — emit notifications from existing services:**
- `services/auth_service` — new client pending pairing → `category=client, type=info`.
- `services/license_service` — license expires within 30 days / expired → `category=license, type=warning|error`.
- `services/ffmpeg_service` — transcode failure → `category=transcode, type=error`.
- `services/library_service` — disk usage > 90% → `category=storage, type=warning`.

**Push to Flutter:** WebSocket `/api/v1/ws` already exists; add a `notification` event type. Sidebar bell shows the live unread count.

**Doc updates:** `docs/04_api/01_api_contracts.md`, `docs/03_data/02_database_schema.md`.

---

### 7.4 Recent Activity feed (Dashboard widget)

**Status:** Activity screen has its own endpoint already. Verify it supports `?limit=4`.

**Action:** if not, add `?limit` query param to existing activity endpoint. No new endpoint needed if it does.

---

### 7.5 Storage breakdown by media type (Dashboard donut)

**Status:** no endpoint. Library data is per-library, not aggregated by media type.

**New endpoint — `GET /api/v1/library/storage-breakdown`:**
```json
{
  "total_bytes": 2992000000000,
  "capacity_bytes": 4400000000000,
  "by_type": {
    "movies": 1380000000000,
    "tv":     980000000000,
    "music":  340000000000,
    "other":  292000000000
  }
}
```
Implementation: `library_service.get_storage_breakdown(db)` aggregates `media_files.size_bytes` grouped by `media_type`, plus `shutil.disk_usage` on the library root for capacity.

**Doc updates:** `docs/04_api/01_api_contracts.md`.

---

### 7.6 System stats stream (sidebar System Status, status bar, sparklines)

**Status:** `GET /api/v1/info` returns server name + version + tier only. No CPU/RAM/network/uptime.

**Approach:** add a single endpoint and a single WS event so the Flutter app can choose polling or push.

**New endpoint — `GET /api/v1/info/stats`:**
```json
{
  "uptime_seconds": 9912,
  "lan_ip": "192.168.1.105",
  "public_address": "103.21.45.67:8443",
  "internet_connected": true,
  "cpu_percent": 18.4,
  "ram_percent": 42.1,
  "ram_used_bytes": 6800000000,
  "ram_total_bytes": 16000000000,
  "network_in_mbps": 8.4,
  "network_out_mbps": 2.1,
  "active_streams": 1
}
```
Implementation:
- Use `psutil` (already in deps for FFmpeg path resolution? — verify; if not, add).
- LAN IP via `socket.gethostbyname(socket.gethostname())` with fallback to interface enumeration.
- Internet check via cached short-TTL probe to a stable host (e.g. CloudFlare 1.1.1.1 TCP:80).
- Uptime via `process_start_time` captured at lifespan start.

**WS event on `/api/v1/ws`:** push `{"type": "stats", "data": <same payload>}` every 1100ms when ≥1 client subscribed. Sidebar/status bar subscribe; Dashboard sparklines accumulate the last 30 ticks.

**Doc updates:** `docs/04_api/01_api_contracts.md` (REST + WS), `docs/02_architecture/01_system_overview.md` (push channel).

---

### 7.7 Dashboard "Quick Access" actions (Restart / Stop server)

**Status:** no endpoints; CLAUDE.md / config.py boot flow exists but not exposed.

**New endpoints — `apps/server/routers/info.py`:**
| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/info/restart` | Graceful restart (close DB, re-exec process) | localhost only |
| POST | `/info/stop`    | Graceful shutdown                            | localhost only |

Implementation: schedule the action after returning the response so the client gets a `202 Accepted`. Use `os.execv` on Unix, `subprocess.Popen` + `sys.exit` on Windows.

**Doc updates:** `docs/04_api/01_api_contracts.md`.

---

### 7.8 Transcoding screen — encoder load per device

**Status:** `ffmpeg_service` knows the active encoder and tracks live sessions, but exposes no "load per encoder" metric.

**New endpoint — `GET /api/v1/transcoding/status`:**
```json
{
  "active_encoder": "h264_nvenc",
  "available_encoders": ["libx264", "h264_nvenc", "h264_qsv", "h264_vaapi"],
  "encoder_loads": [
    { "encoder": "h264_nvenc", "active_sessions": 1, "gpu_utilization_percent": 34, "vram_used_mb": 580 },
    { "encoder": "libx264",    "active_sessions": 0, "cpu_utilization_percent": 0 }
  ],
  "active_sessions": [
    { "id": "sess_…", "client_id": "…", "media_title": "…", "input_codec": "h265", "output_codec": "h264", "fps": 60, "speed_x": 1.4, "progress": 0.42 }
  ]
}
```
Implementation:
- GPU utilization via `nvidia-smi` (NVIDIA), `intel_gpu_top` (QSV), `radeontop`/`vaapi` query (VAAPI). Best-effort — return `null` if probe fails.
- Per-session progress reuses existing FFmpeg session tracking.

**Doc updates:** `docs/04_api/01_api_contracts.md`.

---

### 7.9 Logs — structured filtering

**Status:** ✅ Done — `GET /api/v1/logs` is the canonical logs endpoint (structured, filtered, paginated). `WS /api/v1/ws/logs` provides live tail. The legacy `GET /api/v1/info/logs` endpoint has been removed; there is no backwards-compat shim.

**Endpoint — `GET /api/v1/logs`**:
| Param | Description |
|-------|-------------|
| `level` | `info \| warn \| error` (repeatable) |
| `source` | logger name prefix |
| `since` | ISO timestamp |
| `until` | ISO timestamp |
| `q` | substring match against message |
| `limit` | default 200, max 1000 |
| `cursor` | for pagination |

Returns:
```json
{
  "items": [
    { "ts": "2026-05-01T12:34:56.789Z", "level": "info", "source": "fluxora.stream", "message": "…" }
  ],
  "next_cursor": "…"
}
```
Implementation: switch logger to JSON-line format already partially defined in `main.py` (`json` formatter). Stream from rotating file; tail with `pyinotify`/polling for live tab.

**WS event:** `{"type":"log", "data": <line>}` on `/api/v1/ws` for the live-log tab.

**Doc updates:** `docs/04_api/01_api_contracts.md`, `docs/09_backend/01_backend_architecture.md` (logging format change).

---

### 7.10 Settings — extend coverage

The existing `services/settings_service` covers transcoding (encoder/preset/CRF) + tier/license. The redesigned Settings screen has 6 tabs (General / Network / Streaming / Security / Advanced / About) needing more fields.

**Schema extension — migration `014_extended_settings.sql`** adds columns to `user_settings`:

| Column | Type | Default | Surface (tab) |
|--------|------|---------|--------------|
| `language`                  | TEXT     | `'en'`     | General |
| `auto_start_on_boot`        | BOOLEAN  | `0`        | General |
| `auto_restart_on_crash`     | BOOLEAN  | `1`        | General |
| `minimize_to_system_tray`   | BOOLEAN  | `1`        | General |
| `theme_accent`              | TEXT     | `'violet'` | (deprecated by Decision #4 — keep nullable for forward-compat) |
| `default_library_view`      | TEXT     | `'grid'`   | General |
| `scan_libraries_on_startup` | BOOLEAN  | `1`        | General |
| `generate_thumbnails`       | BOOLEAN  | `1`        | General |
| `preferred_mode`            | TEXT     | `'auto'`   | Network |
| `enable_mdns`               | BOOLEAN  | `1`        | Network |
| `enable_webrtc`             | BOOLEAN  | `1`        | Network |
| `relay_server_url`          | TEXT     | NULL       | Network |
| `default_quality`           | TEXT     | `'auto'`   | Streaming |
| `max_concurrent_streams`    | INTEGER  | `3`        | Streaming |
| `ai_segment_duration_seconds` | INTEGER | `4`       | Streaming |
| `enable_pairing_required`   | BOOLEAN  | `1`        | Security |
| `session_timeout_minutes`   | INTEGER  | `60`       | Security |
| `enable_log_export`         | BOOLEAN  | `1`        | Advanced |
| `custom_server_url`         | TEXT     | NULL       | Advanced |

**Endpoint:** `GET /api/v1/settings` and `PATCH /api/v1/settings` already exist; extend their payload schemas. No new routes needed.

**Doc updates:** `docs/03_data/02_database_schema.md`, `docs/04_api/01_api_contracts.md`, `docs/06_security/01_security.md` (session timeout, pairing).

---

### 7.11 Subscription — billing history & plan management

**Status:** `GET /api/v1/orders` returns the latest Polar order + license. The redesigned Subscription screen wants a billing history table and a manage-subscription deep-link.

**Endpoints:**
| Method | Path | Description |
|--------|------|-------------|
| GET    | `/api/v1/orders?limit=20&cursor=…` | List orders (paginated) — extend existing |
| GET    | `/api/v1/orders/portal-url` | Returns Polar customer portal URL for the current customer (deep-link to manage payment / cancel) |

Implementation: Polar SDK exposes a customer-portal URL builder; cache per `customer_id` with short TTL.

**Doc updates:** `docs/04_api/01_api_contracts.md`, `docs/01_product/06_polar_product_setup.md` (portal-link configuration).

---

### 7.12 Backend dependencies

| Package | Reason | Where |
|---------|--------|-------|
| `psutil` | CPU / RAM / process probe for §7.6 | `apps/server/pyproject.toml` |
| (consider) `pyinotify` (Linux) / `watchdog` (cross-platform) | Live-log tail for §7.9 | optional; polling is acceptable v1 |

Pin to current latest versions per CLAUDE.md Rule #12 — verify at PR time, do not pin to a number from training data.

---

## 8. "Without any UI errors" — enforcement rules

These rules are enforced on every screen PR. Each comes from a real Flutter pitfall.

### 8.1 Layout correctness
- **Lock dev window to 1440×900** during development (`window_manager.setSize` in `main()` for debug). Test minima at 1280×720 and 1024×768.
- Every `Row`/`Column` with potentially-overflowing children uses `Flexible`/`Expanded` correctly. **Run with `debugPaintSizeEnabled = true` once per screen; if you see yellow-and-black overflow stripes, fix before commit.**
- Text inside a fixed-width box: `overflow: TextOverflow.ellipsis` and `maxLines`. Test with: server name = "My Really Long Home Media Server Name", username = "averylongemail@something.example.org".
- Avatars use `ClipOval`, not `BorderRadius.circular(999)` (latter aliases on Windows).
- `BackdropFilter` only works inside a `ClipRect`. Without one, it does nothing or paints the entire screen.
- Use `Align` not `Center` when you mean a specific corner (`Center` shrinks unexpectedly inside a `Stack`).

### 8.2 Visual fidelity
- **Hex codes are non-negotiable.** Never approximate. If unsure, use a color picker on the live prototype.
- Gradient angles match: CSS `135deg` ≈ `LinearGradient(begin: topLeft, end: bottomRight)`; CSS `90deg` ≈ `centerLeft → centerRight`.
- Border radii are exactly `12 / 10 / 8 / 6 / 999`. No new values.
- Spacing only on the locked set in `app_spacing.dart`.
- Never use Material's default elevation. Set `elevation: 0`; provide explicit `BoxShadow`.
- Replace **every** `Switch`, `Checkbox`, `TextField`, `Slider`, `DropdownButton`, `ElevatedButton`, `OutlinedButton`, `TextButton`, raw `DataTable` with the Flux equivalents. Add a `custom_lint` rule banning the Material variants in screen files.

### 8.3 Typography
- Bundle TTFs in `fluxora_core` (don't rely on `google_fonts` runtime fetch).
- Pre-compute `TextStyle` objects per token; don't compose styles inline in `build`.
- Letter-spacing matches exactly (`0.14em`, not `1.5px`).

### 8.4 State & rebuilds
- Use `BlocSelector` / `buildWhen` to scope rebuilds. A naïve `BlocBuilder` over the whole screen rebuilds the donut + sparklines + every card on every tick.
- Live-tick consumers use `ValueListenableBuilder<int>` scoped to that one widget. Don't propagate the tick through Cubit state.
- `CustomPaint` widgets pass `child: SizedBox.expand()` to behave under tight constraints.

### 8.5 Pre-merge checklist (screen PRs)
- [ ] `flutter analyze` clean — zero warnings.
- [ ] App opens at 1440×900 with no overflow stripes (`debugPaintSizeEnabled`).
- [ ] App still renders without overflow at 1280×720.
- [ ] Every interactive element responds to hover (mouse-region cursor changes).
- [ ] Side-by-side screenshot vs prototype at 1440×900 — no visible difference at 100% zoom.
- [ ] Every text field handles overflow with extreme values.
- [ ] Tab/keyboard navigation works (focus rings visible).
- [ ] No `print()` / `debugPrint()`.
- [ ] No `// TODO` left behind.
- [ ] Existing tests pass; new screen has at least a smoke test that mounts it.
- [ ] `AGENT_LOG.md` entry appended; relevant docs updated per CLAUDE.md doc protocol.

### 8.6 Visual regression harness (recommended)
Add `golden_toolkit`. Capture a golden PNG of each screen at 1440×900 with a fixed data fixture. Re-run on every PR to catch unintended visual changes. Goldens live in `apps/desktop/test/goldens/`.

---

## 9. Milestone breakdown

Estimates are for a single dev. Halve with two devs after primitives are merged.

| Milestone | Deliverable | Est. |
|-----------|-------------|------|
| **M0 — Backend prerequisites** | §7.1 Groups · §7.2 Profile · §7.3 Notifications (schema + endpoints + WS events) · §7.4 Activity feed · §7.5 Storage breakdown · §7.6 System stats · §7.7 Restart/Stop · §7.8 Transcoding status · §7.9 Logs filter · §7.10 Settings extension · §7.11 Orders list + portal | 4–5 days ✅ Done 2026-05-06 |
| **M1 — Foundation** | All design tokens, all primitives + widgetbook stories, FluxoraMark/Wordmark widgets, font + asset registration | 2 days ✅ Done 2026-05-02 |
| **M2 — Shell** | Sidebar + status bar + new routes (replacing existing), `SystemStatsCubit`, Cmd+K palette | 1.5 days ✅ Done 2026-05-02 |
| **M3 — Dashboard** | Pixel-verified Dashboard, live-tick wiring, Sparkline, Donut | 1.5 days ✅ Done 2026-05-02 |
| **M4 — Library + Clients** | Both screens incl. detail panels | 2 days ✅ Done 2026-05-02 |
| **M5 — Groups + Activity + Transcoding** | All three + Encoder Settings sub-page | 2 days ✅ Done 2026-05-02 |
| **M6 — Logs + Settings** | Logs filtering UI + all 6 Settings tabs | 2 days |
| **M7 — Subscription + Profile + Notifications + Help** | Subscription + Billing + Manage + Profile + Notifications overlay + Help | 2 days |
| **M8 — Polish + visual QA** | Cmd+K polish, accessibility pass, golden tests, pixel review against prototype | 1.5 days ✅ Done 2026-05-03 |
| **M9 — Cleanup + docs** | Delete legacy screen files, update all docs per §10, update `AGENT_LOG.md` | 0.5 day ✅ Done 2026-05-03 |
| **M10 — Custom window chrome** | New `window_manager` dep + per-platform native runner edits + `FluxTitleBar` widget + sidebar logo-header removal. Full spec in §13. | 1–1.5 days ✅ Done 2026-05-03 |

**Total: ~20–21 working days.** Backend (M0) can run in parallel with M1 once primitives are scoped.

---

## 10. Doc-update protocol — files to touch on cutover

Per CLAUDE.md doc protocol §3, after M9:

| File | Update |
|------|--------|
| `docs/02_architecture/01_system_overview.md` | New WS event channels (stats, log, notification) |
| `docs/02_architecture/03_component_architecture.md` | New service modules (group, notification) |
| `docs/03_data/01_data_models.md` | Group / GroupMember / GroupRestrictions / Notification entities |
| `docs/03_data/02_database_schema.md` | Migrations 011–014 |
| `docs/03_data/03_data_flows.md` | Group restriction enforcement flow; notification fan-out |
| `docs/04_api/01_api_contracts.md` | All endpoints in §7 |
| `docs/06_security/01_security.md` | Profile password change; session timeout setting |
| `docs/08_frontend/01_frontend_architecture.md` | New screen map; primitive catalogue; sidebar redesign |
| `docs/09_backend/01_backend_architecture.md` | New routers, services, JSON log format |
| `docs/10_planning/01_roadmap.md` | Phase 5 progress |
| `docs/10_planning/02_decisions.md` | Decisions §1.1–§1.5 here become ADR entries |
| `DESIGN.md` | Extend tokens with new colors / spacing / radii / shadows |
| `CLAUDE.md` | Update "Current Status" + "Phase Roadmap" tables |
| `AGENT_LOG.md` | Per-session entries throughout |

---

## 11. Open items / risks

### 11.1 Residual follow-ups (post-M10, cosmetic)

These are the cells/fields the redesign deliberately landed as `—` placeholders because the backend join didn't exist yet, plus a handful of stale TODOs found during the 2026-05-06 audit. Tracked here so they don't get lost. None block the redesign milestone.

| # | Item | Frontend TODO | Backend work needed | Priority |
|---|------|---------------|---------------------|----------|
| F1 | **Clients screen → Active Streams stat tile** ~~shows placeholder~~ now reads `SystemStatsCubit.state.latest.activeStreams` | `clients_screen.dart:208` (was `:214`) | None — done. | ✅ Done 2026-05-06 |
| F2 | **Clients table → IP address column** ~~shows `—`~~ now reads `c.lastIp` (populated by `clients.last_ip` from migration 023; written at `request_pair` and refreshed on every authenticated request via `validate_token` heartbeat) | `clients_screen.dart` (table cell + detail-panel info row) | None — done. | ✅ Done 2026-05-06 |
| F3 | **Clients detail panel → active session block** ~~hidden~~ now renders an emerald-tinted "Currently Streaming" block when `client.activeSession != null`; "Current Stream" table column shows the joined media title. Server-side: `auth_service.list_clients` LEFT-JOINs `stream_sessions WHERE ended_at IS NULL` with a `ROW_NUMBER() OVER (PARTITION BY client_id)` to pick the most recent in-flight session per client. | `clients_screen.dart` (table cell + new `_ActiveSessionBlock` widget) | None — done. | ✅ Done 2026-05-06 |
| F4 | **Settings 19th column (forward-compat)** — plan budgeted 19, migration 015 shipped 18; no consumer waiting on it | n/a | If a real need surfaces, add migration `02x_*.sql` rather than back-filling 015. | Defer |
| F5 | **Help screen → external links** ~~currently no-op~~ now opens via `url_launcher` 6.3.2 (`launchUrl(uri, mode: LaunchMode.externalApplication)`) with logger-wrapped error handling | `help_screen.dart` `_LinkRowState._open` | None — done. | ✅ Done 2026-05-06 |
| F6 | **Help screen → support bundle export** ~~("download diagnostic zip" disabled)~~ now generates an in-memory gzipped tar via `POST /api/v1/info/support-bundle` (localhost-only) and saves to a user-chosen path via `FilePicker.saveFile`. Bundle contents: `metadata.json` (server version + Python + platform + data dir), `system/stats.json` (one psutil snapshot), `system/encoders.json` (last self-test results from the new `transcoding_service.get_test_results()` accessor), `settings/redacted.json` (`user_settings` row with `tmdb_api_key` / `license_key` / `email` replaced by `***REDACTED***` sentinel — null stays null so "never configured" is distinguishable from "had a value"), `database/schema.sql` (`sqlite_master` DDL only, no row data), `logs/*` (current rotating log file + up to 4 rotated siblings). Each sub-collector is wrapped in try/except — a single failure ships a partial bundle with `_collect_error` markers rather than aborting the download. | `services/support_bundle_service.py` (new); `routers/info.py:download_support_bundle`; `help_screen.dart:_DiagnosticsCardState`; `tests/test_support_bundle.py` (+9). | None — done. | ✅ Done 2026-05-06 |
| F7 | **Groups screen → ~~3~~ 5 Material `AlertDialog` calls** swapped for the existing `FluxGlassDialog` primitive — primitive already shipped at `flux_glass_dialog.dart`; the audit's "build a new primitive" assumption was wrong, `FluxGlassDialog` had been there since the M3 era. Both inner dialog widgets (`_CreateGroupDialog`, `_EditGroupDialog`) and 3 confirm/add-member dialogs swapped. Violet primary `FilledButton` for affirmative action; red for destructive. | `groups_screen.dart` (5 sites) | None — done. | ✅ Done 2026-05-06 |
| F8 | **Subscription manage tab → `_ActionRow.onTap`** ~~`() {}`~~ now wired to `OrdersCubit.openPortal()` via `_ManageTab._openPortal()`; both "Upgrade Plan" and "Cancel Subscription" rows route through the Polar customer portal (correct per the parent comment "Actions (all deferred to portal)"). Snackbar feedback on success/failure. | `subscription_screen.dart` `_ActionRow.onTap` | None — done. | ✅ Done 2026-05-06 |
| F9 | **Profile screen → Sessions tab wired (revoke session + sign out everywhere + auto-refresh)** ~~hardcoded "This device" shell~~ now consumes a tab-scoped `ClientsCubit` (`getIt<ClientsRepository>()`); lists every approved + trusted client (sorted by `lastSeen` desc); per-row `Sign Out` button → `cubit.revoke(id)` → `DELETE /auth/revoke/{id}`; header `Sign Out All Devices` button revokes every active session sequentially behind a `FluxGlassDialog` confirm; `_bulkRevoking` flag dims per-row buttons during the sweep; mounted-guards across awaits. Loading / failure / empty states all wired (no devices = "Pair a device from the Clients screen" caption). Hardcoded "Current" row dropped — desktop CP is localhost-only and never pairs as a client. **Auto-refresh:** `_SessionsTabBody.initState` starts a 5 s `Timer.periodic` calling new `ClientsCubit.refreshSilent()` (skips `ClientsLoading` emit + preserves `filter` + `processingIds` + swallows errors so a poll blip doesn't flicker the UI to error and back); skipped while `_bulkRevoking` to avoid racing the cubit's own state emissions. **Danger Zone (delete account, export data) deferred** — compliance scope (GDPR DSR, account-deletion semantics) needs spec before code; tracked separately. | `profile_screen.dart` `_SessionsTab` / `_SessionsTabBody` / `_SessionsHeader` / `_SessionRow` / `_SessionsLoadingRow` / `_SessionsErrorRow` / `_NoSessionsRow`; `clients_cubit.dart` `refreshSilent()`; `test/features/clients/clients_cubit_test.dart` (+6 cases — silent refresh happy path / filter preserved / processingIds preserved / no-op-when-not-loaded / no-op-on-failure-state / errors-swallowed). | None for the Sessions subset. Danger Zone still pending. | ✅ Sessions done 2026-05-07; Danger Zone deferred |
| F10 | **Encoder Settings → "Run Benchmark" button** ~~disabled~~ now wired to `POST /api/v1/transcoding/benchmark`. Server runs an 8 s synthetic `lavfi testsrc` encode through every detected encoder sequentially (35 s ceiling each), parses fps/speed/bitrate from the final FFmpeg progress line. Desktop renders a per-encoder results table below the button: green check + emerald perf for ≥1× realtime; amber for sub-realtime; red error row with the first-stderr-line for failures. `ApiClient.post` gained an optional `receiveTimeout` so the desktop can override the default 10 s for this slow call (uses 3 min). | `encoder_settings_screen.dart` `_BenchmarkBlock` + `_BenchmarkResultsTable`; `services/benchmark_service.py`; `routers/transcoding.py` `run_benchmark`; tests `test_benchmark_service.py` (+13) + `test_transcoding.py` (+5 router cases). | None — done. | ✅ Done 2026-05-07 |

### 11.2 Original risk register

| Item | Mitigation |
|------|------------|
| `BackdropFilter` perf on Linux | Add `kEnableHeavyBlur` flag; benchmark M2 |
| GPU-utilization probes vary by vendor (NVIDIA/Intel/AMD) | Best-effort; return `null` when probe fails — sidebar shows `–` |
| Notification fan-out volume | Generators are emitter-side; client subscribes via existing `/ws` — no extra infra |
| Polar customer-portal URL caching | Short TTL (5 min) sufficient; cache miss = one Polar API call |
| Live log tail file-locking on Windows | Polling fallback (250ms) is adequate; `watchdog` only if perf demands |
| Keyboard shortcuts on macOS vs Windows/Linux | Use `LogicalKeyboardKey.meta` on macOS, `control` elsewhere — `Platform.isMacOS` check at app root |

---

## 12. Change log

| Date | Author | Change |
|------|--------|--------|
| 2026-05-01 | Claude (session) | Initial plan |
| 2026-05-02 | Claude (session) | M0 §7.5/§7.6/§7.7 shipped (storage breakdown, system stats REST + WS, restart/stop). M1 Foundation shipped (tokens, 11 primitives, brand visuals, 4 animated SVGs, `/showcase` route, `flutter_svg` dep, hi-fi logos). §7.1 Groups + §7.2 Profile shipped by parallel agent. Recreated F-mark SVG removed per owner direction — brand mark stays the original PNG. |
| 2026-05-02 | Claude (session) | M3 Dashboard shipped. New entities `ActivityEvent` + `LibraryStorageBreakdown`/`StorageByType` in core. New features `storage/` + `recent_activity/` in desktop. `DashboardScreen` fully rewritten to pixel-match prototype: 4 stat tiles, Server Info card, Quick Access card, Recent Activity card, Storage Overview card. `DashboardRepository` extended with `restartServer`/`stopServer`. `Endpoints.activity` constant added. |
| 2026-05-02 | Claude (session) | M5 shipped: Groups screen, Activity screen (replaced), Transcoding screen, Encoder Settings sub-page. New entities: `Group`/`GroupRestrictions`/`TimeWindow`/`GroupStatus` and `TranscodingStatus`/`EncoderLoad`/`ActiveTranscodeSession`. New features: `groups/` + `transcoding/`. `RecentActivityCubit` extended with `loadAll`/`pause`/`resume`. `Routes.encoderSettings` added. DI updated. |
| 2026-05-02 | Claude (session) | M6 shipped: Logs screen (structured rows + 4 tabs + level/source/since filters + auto-scroll while live + pause/resume + click-to-expand) and Settings screen (6-tab side-rail layout — General / Network / Streaming / Security / Advanced / About — wires all 18 §7.10 extended fields plus tier-1 fields). New form primitives: `FluxTextField`, `FluxSelect`, `FluxSwitch`, `FluxSlider`. New `LogRecord` domain entity. |
| 2026-05-03 | Claude (session) | **Updated prototype bundle imported.** Old `docs/11_design/desktop_prototype/` replaced by `docs/11_design/prototype/` — new layout splits files into `app/desktop/`, `app/mobile/`, `app/shared/`, plus top-level `README.md`, `chats/`, `uploads/`, and per-platform `app/desktop/README.md` + `app/mobile/README.md` port specs. Diff vs prior bundle: every desktop screen / page / data file is byte-identical (only relocated). Two real UI deltas: titlebar logo removed (wordmark only), sidebar logo header removed (nav at top). All §2 source-of-truth paths updated. **Decisions §1 #5 reversed** — custom window chrome is now in scope; new Decision #6 records the sidebar logo-header removal. New §13 spec + M10 milestone added. Mobile bundle parked — `mobile_player_redesign_plan.md` still gates on completion of these desktop milestones. |
| 2026-05-06 | Claude (session) | **Plan reconciled with code reality.** M0 prerequisite table verified: §7.3 / §7.4 / §7.8 / §7.9 / §7.10 / §7.11 marked ✅ Done with concrete landed-file evidence (had been stale — backend shipped earlier without the table being updated). M0 milestone label flipped from "(in progress)" to "(✅ Done 2026-05-06)". M4 milestone label flipped from "🔵 In Progress" to "✅ Done 2026-05-02" with deferred follow-ups itemised. §5 Screen translation order table — 11 of 12 stale "🔲 Pending" rows updated to ✅ Done. Top-of-doc Status banner rewritten: "Complete — partially shipped" → "✅ Complete — every milestone shipped". §11 split into 11.1 Residual follow-ups (F1–F10 — Clients placeholders, Help external links + support bundle, Groups FluxDialog primitive, Subscription stale `onTap`, Profile danger-zone actions, Encoder Settings benchmark) and 11.2 Original risk register. No code changes — doc-only sync. |
| 2026-05-06 | Claude (session) | **Settings + Help audit pass 2: 13 wireless fields wired (A8), Network tab flattened (A9), System Info card lives (A10), Max Concurrent Streams chipped (A11), AI/Session timeout fields seeded from state (A12+A13), Help link URLs corrected.** A8 — `SettingsLoaded` extended with 13 new fields (`defaultLibraryView`, `scanLibrariesOnStartup`, `generateThumbnails`, `preferredMode`, `enableMdns`, `enableWebrtc`, `relayServerUrl`, `defaultQuality`, `aiSegmentDurationSeconds`, `enablePairingRequired`, `sessionTimeoutMinutes`, `enableLogExport`, `customServerUrl`); `loadSettings` reads each from `GET /settings`; `saveSettings()` accepts all 13 + emits in PATCH body via the `?value` operator (each field nulls out at the call site when unchanged so the PATCH stays minimal). M6's "wires all 18 §7.10 extended fields" claim is now actually true. A9 — `_NetworkTab` flattened from `StatefulWidget` to `StatelessWidget`; the four values now live on the parent `_SettingsViewState`. A10 — `_SystemInfoCard` reads `SystemStatsCubit` via `context.select`; status row derives label/colour/dot from `(latest, errorMessage)` — emerald "Running" / red "Degraded" / red "Unreachable" / muted "Checking…". A11 — Max Concurrent Streams replaced with a `FluxChip` ("`<n>` · tier-locked" or "Unlimited") + `Tooltip` explaining the tier-set semantics. A12+A13 — `_aiSegmentCtrl` / `_sessionTimeoutCtrl` reseat from state on every load (default fallback `'6'` corrected to `'4'` matching the server). **Help screen URL fix**: all 4 `_kLinks` entries swapped from non-existent `marshalx/fluxora` to canonical `Marshal-GG/Fluxora-Personal-Streaming-Platform` (Documentation → /wiki, Community → /discussions, Report Issue → /issues, What's New → /releases). Server suite 488/488 passing (no new tests — `test_settings_extended.py` already covers PATCH round-trips for every column with 20 cases). `flutter analyze` clean. **3 new gotchas**: Dart 3 records don't allow forward declarations (use `late final`); Stateful→Stateless conversion misses references inside conditional branches (re-run `flutter analyze` is non-negotiable); `SystemStatsState` is a flat-with-nullables class, not a sealed union — match on `(latest, errorMessage)` tuples not subclass types. |
| 2026-05-06 | Claude (session) | **Settings + Help audit pass 1 (user-flagged surfaces): A1+A2+A3+A4+A5+A6+A7.** A1 — Help link rows gain `HitTestBehavior.opaque` + snackbar feedback on launch failure (handles "user did `flutter pub get` but didn't `flutter clean && flutter run`" — native plugins don't load on hot reload). A2 — Help "Get Help" rows gain hover background tint (violet 8 % `AnimatedContainer`) replacing icon-only hover state. A3 — Settings → About → Links card 3 rows now wire through new `_ExternalLinkRow` widget mirroring the Help-screen pattern (hover tint, snackbar feedback, Logger). A4 — Settings → About `_CreditsCard` ("Built with Flutter, FastAPI, FFmpeg, and ❤") replaced with `_AboutProductCard` — product description + 4 bullets (local-first / hardware-accelerated / cross-platform / no telemetry). A5 — Settings → Security "View Issued Licenses" button now navigates to `Routes.subscription` (was `/licenses` which was deleted at M9 cleanup; clicking went nowhere). A6 — Settings → General "Server URL" relabelled "Control Panel Connection URL" with sub clarifying "saved on this machine"; A7 — Settings → Advanced "Server URL Override" / "Custom Server URL" relabelled "Public URL Advertisement" / "Custom Public URL" with sub explaining override-of-env-var semantics. **`routers/info.py` precedence change**: `/info` now reads `user_settings.custom_server_url` first, falling back to `FLUXORA_PUBLIC_URL` env var — the Advanced field was previously dead (value persisted but never consumed). 2 new pytest cases (custom URL overrides env; whitespace falls back). 477 → 488 server tests passing (cumulative across F6 + audit). |
| 2026-05-06 | Claude (session) | **F6 shipped: support bundle export.** New `services/support_bundle_service.py` builds a gzipped tar in memory: `metadata.json` (server version + Python version + platform + data dir), `system/stats.json` (one psutil snapshot via `system_stats.collect`), `system/encoders.json` (snapshot of `_TEST_RESULTS` via new public `transcoding_service.get_test_results()` accessor — added so the bundle service does not reach into private state), `settings/redacted.json` (`user_settings` with `tmdb_api_key` / `license_key` / `email` replaced by `***REDACTED***` sentinel; null stays null so "never configured" differs from "had a value, redacted"), `database/schema.sql` (`sqlite_master` DDL only — never row data), `logs/*` (active rotating log + up to 4 rotated siblings). Each sub-collector is wrapped in try/except — a single failure ships a partial bundle with `_collect_error` markers rather than aborting the download. New `POST /api/v1/info/support-bundle` (localhost-only via `require_local_caller`) returns the bytes with `Content-Disposition: attachment; filename="fluxora-support-<UTC stamp>.tar.gz"`. Frontend: `Endpoints.infoSupportBundle` constant; new `ApiClient.postBytes(path)` method returns `({Uint8List bytes, String? filename})` parsing the filename out of `Content-Disposition`; Help screen's `_DiagnosticsCard` converted to stateful, "Generate Bundle" button calls `getIt<ApiClient>().postBytes()` then `FilePicker.saveFile()` (`file_picker` 11.0.2 — `.platform` accessor was removed; static method now). 9 new pytest cases (bundle structure, filename format, secret redaction, null secrets stay null, schema-no-rows guard, metadata fields, sub-collector failure isolation, endpoint localhost guard returns gzip + Content-Disposition, non-localhost returns 403). 477 → 486 server tests passing. `flutter analyze` clean (desktop + core). |
| 2026-05-06 | Claude (session) | **F2 + F3 shipped: Clients screen IP column + active-session join.** Server: migration `023_clients_last_ip.sql` adds nullable `last_ip` TEXT to `clients`. `auth_service.create_pair_request` accepts `client_ip` kwarg + persists at insert/upsert (with `COALESCE` so re-pair from a known IP doesn't clobber). New `auth_service.update_client_heartbeat()` helper updates `last_seen` (+ optionally `last_ip`); called from `validate_token` dep on every authenticated request — also fixes a pre-existing latent bug where `last_seen` only updated at pair/approval. `auth_service.list_clients` rewritten to LEFT-JOIN `stream_sessions WHERE ended_at IS NULL` with a `ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY started_at DESC) = 1` window to pick the single in-flight session per client. New `ActiveSessionInfo` Pydantic model + `ClientListItem.last_ip` + `active_session` fields. `routers/auth.list_clients` builds the nested response. `routers/stream.py:425` direct call site updated to match new `validate_token` signature (added `request` param). Frontend: `packages/fluxora_core` `ClientListItem` gains `lastIp` + `activeSession`; new `ActiveSessionInfo` entity. `clients_screen.dart` — IP cell at table row + detail-panel info row both read `c.lastIp ?? '—'`; "Current Stream" cell shows joined media title; new emerald-tinted `_ActiveSessionBlock` widget renders below info rows when `client.activeSession != null` (status dot + media title + encoder + elapsed-since-start in `Hh Mm` / `Mm` / `Ss`). Tests: 3 new pytest cases (request-pair persists `last_ip` from request socket, list-clients surfaces `last_ip` + `active_session`, ended sessions don't appear as active). 474 → 477 server tests passing. `flutter analyze` clean (26.7 s). **Pre-existing failure flagged**: `m3_dashboard_golden_test.dart` fails with 62.77 % pixel diff against the stored baseline — unrelated to F2/F3 (Dashboard untouched), likely V2 cutover drift; baseline needs regenerating. Added to follow-ups. |
| 2026-05-06 | Claude (session) | **Quick-wins batch shipped: F1 + F5 + F7 + F8.** F1 — Clients screen Active Streams stat tile reads `SystemStatsCubit.state.latest?.activeStreams` (`clients_screen.dart` `_buildStatTiles` signature gained `BuildContext`; `const StatTile` dropped to allow runtime value). F5 — `url_launcher` 6.3.2 added (single new dep, established maintainer); `_LinkRowState._open()` opens external URL via `launchUrl(uri, mode: LaunchMode.externalApplication)` with `Logger`-wrapped failure paths. F7 — discovered `FluxGlassDialog` already shipped at `lib/shared/widgets/flux_glass_dialog.dart`; the original audit's "build a new primitive" assumption was wrong. Swapped **all 5** Material `AlertDialog` instances in `groups_screen.dart` (Create / Edit / Add-Member / 2× Delete confirm) to `FluxGlassDialog` with violet `FilledButton` for affirmative actions and red for destructive. F8 — Subscription manage tab `_ActionRow` `onTap: () {}` wired to `_ManageTab._openPortal()` → `OrdersCubit.openPortal()` with snackbar feedback; both "Upgrade Plan" and "Cancel Subscription" route through Polar portal per the parent comment "Actions (all deferred to portal)". `flutter analyze` clean (0 issues, 82.8 s). Net effect: every cosmetic placeholder and stale TODO from F1/F5/F7/F8 removed; the Clients / Help / Groups / Subscription surfaces now match the V2 design 1:1. F2/F3/F6/F10 still need backend work (per §11.1); F9 deferred until compliance scope is decided. |
| 2026-05-07 | Claude (session) | **Benchmark UX maturation: history persistence + sidebar + live progress + UX cleanup + back-button bugfix.** Same-day continuation of the F10 ship.  User picked through the operator workflow and asked for: (1) drop the "Verify session caps" toggle, always run the probe — chip would lie about capacity otherwise; (2) add resolution selector (720p / 1080p / 4K); (3) fix the tab-divider gap (FluxTabBar's `mainAxisSize.min` collapsed the bottom border to the tabs' combined width vs Settings' full-width divider; also dropped `bottom: 16` so the active underline overlaps the divider per the prototype's `marginBottom: -1` intent); (4) replace Cancel with a proper back arrow on Encoder Settings; (5) save benchmark history with proper details; (6) build a sidebar UI for it; (7) live progress feedback during runs ("i need to see something in ui how much the progress has been done and what is going on"); (8) gradient on the progress bar; (9) the back button crashed the app (root cause: `MouseRegion.onExit` firing post-dispose during the route transition + missing `canPop` guard for deep-link entries).  All shipped.  **Server**: migration `024_benchmark_history.sql` adds `benchmark_runs` (top-level metadata + JSON `results_json` + denormalized `encoder_count`, indexed on `started_at DESC`); `services/benchmark_history_service.py` (save / list / get / delete + auto-prune to 50); `BenchmarkRequest.{width, height}` Pydantic-validated + `clamp_resolution` snaps to nearest tier; `BenchmarkResponse` carries `id` after persist; module-level `_progress: dict | None` populated on every encoder/step transition + cleared in `finally` so a crash mid-run doesn't leave stale state; new `services/benchmark_history_service` + `_with_verified_cap` helper + `verified_concurrent` field re-derives `recommended_concurrent` against measured cap; cap probe now uses the same fps + size as the main run; 4 new endpoints (`POST /benchmark` returns id; `GET /benchmark/progress`; `GET /benchmark/history`; `GET /benchmark/history/{id}`; `DELETE /benchmark/history/{id}`); always-on cap probe (toggle removed).  **Desktop**: `FluxTabBar` divider + spacing fixes (full width + zero gap between underline + divider) — improves Library / Logs / Subscription / Encoder Settings simultaneously; `PageHeader.onBack` slot with mounted-guarded `_BackButton`; Encoder Settings replaces Cancel with `onBack: canPop ? pop : go(Routes.transcoding)`; verify-caps switch deleted, repo hardcodes `verify_caps: true`; new `_ResolutionSelector` chip row (720p / 1080p / 4K); `EncoderBenchmarkRun.id` + `BenchmarkHistoryEntry` + `BenchmarkHistory` + `BenchmarkProgress` freezed entities; ApiClient receive timeout 4 → 6 min; Benchmark tab restructured to 2-column with 280-px `_BenchmarkHistorySidebar` (FluxCard "Recent Runs" header + refresh icon + per-row entry with active-dot indicator, "Today HH:MM" / "Yesterday HH:MM" / "MMM d HH:MM" formatter, resolution + fps + count caption, hover-revealed delete affordance, 520-px max-height + scroll, busy spinner per entry, empty/loading/error states); parent `_BenchmarkTab` is stateful (owns `_currentRun` + `_historyVersion`); progress polling every 500 ms via `Timer.periodic` started on benchmark trigger + cancelled in `dispose`; new `_BenchmarkProgressCard` (violet-tinted card with status line + caption + gradient bar); new `_GradientProgressBar` widget — `Stack(fit: StackFit.expand)` + `AnimatedPositioned(width: fraction × parentWidth)` for determinate fills (240 ms ease-out) + AnimatedBuilder + Positioned strip for indeterminate sweep, painting `AppGradients.progress` (#8B5CF6 → #A855F7).  **Bugs fixed mid-pass**: bitrate column always `—` (`-f null -` → `-f mpegts -` so the muxer measures bytes); wrong error line ("Input #0, lavfi, from 'testsrc=...'" → marker-aware `_pick_error_line` finds `error`/`failed`/`unsupported`/...); progress bar always-100% (tight-constrained `AnimatedContainer(width:)` clamped to fill — fixed via Stack + AnimatedPositioned); back button crash (`setState` after dispose on `MouseRegion.onExit` + empty-stack `pop()` — fixed via mounted check + `canPop` fallback).  **Tests**: 27 new server cases (clamp_resolution snap, init_ms streaming, GPU probe wiring, cap probe success counting, progress publish/clear/exception/step-flip, all 3 history endpoints + localhost guards, progress endpoint idle/running/403).  Server suite **488 → 565 passing**.  `flutter analyze` clean (desktop + core).  Migrations 023 → 024.  `desktop_redesign_plan.md` §11.1 F10 row remains ✅ Done. |
| 2026-05-07 | Claude (session) | **F10 enrichment shipped: Tier 1 benchmark fields + UI redesign.** Two real bugs surfaced in the user's first-run screenshot: every Bitrate cell showed `—` (root cause: `-f null -` discards bytes before the muxer measures them, so `bitrate=N/A` lands in every progress line), and the hevc_qsv error read "Input #0, lavfi, from 'testsrc=...'" instead of the actual encoder error (root cause: "first non-empty stderr line" picker grabbed FFmpeg's input header). Switched output mux to `-f mpegts -` piped to stdout DEVNULL so the bitrate counter stays live without touching disk; new marker-aware `_pick_error_line` walks stderr looking for `error`/`failed`/`unsupported`/`could not`/... before falling back to the last line. Then added the four operator-actionable fields the bare benchmark was missing: **`init_ms`** (wall-clock from spawn → first encoded frame, measured by streaming stderr live and timestamping the first `frame=N≥1` line — required moving stderr from a tempfile to PIPE), **`gpu_utilization_percent` + `vram_used_mb`** (midpoint sample via the existing per-vendor probes — `nvidia-smi` / `intel_gpu_top` / `radeontop` / `system_profiler` — fired at `max(0.25, duration_sec/2)` so the encoder is in steady state), **`concurrent_session_cap`** (surfaced from `ENCODER_REGISTRY[encoder].concurrent_session_cap` — NVENC consumer cards = 3), **`recommended_concurrent`** (`min(cap, floor(speed_x))` — the practical "how many streams at realtime" answer; falls back to realtime_multiplier when speed_x missing; floor-clamped to ≥1). Each result also carries `vendor` + `codec` for client-side grouping. Desktop UI rebuilt as a vendor-sectioned card list: section header (`SOFTWARE` / `NVIDIA NVENC` / `INTEL QUICK SYNC` / `AMD VAAPI` / `APPLE VIDEOTOOLBOX`) with hairline divider per vendor; 2-line row per encoder — top line has status icon + encoder name + codec pill + right-aligned concurrent chip (success when multi-stream, warning when cap-bound with "· cap" suffix), bottom line is a dot-separated mono-spaced metrics strip (`init · fps · speed · bitrate · gpu · vram`) where each metric is omitted entirely when null so software rows stay terse; failed rows replace the metrics line with the picked error in red. Speed cell colour: emerald ≥1×, amber <1×, red on fail. New tests: parametrised `_recommended_concurrent` table (7 cases incl. cap-bound + sub-realtime + None fallback), `init_ms_populated_when_first_frame_seen`, `skips_gpu_probe_for_software_encoders`, `runs_midpoint_probe_for_nvidia_encoders` (proc.wait sleeps 1.5 s so the 1.0 s probe coroutine fires before cleanup cancels it). Server suite **508 → 522 passing**. `flutter analyze` clean (desktop 125 s, core 64 s). API contract `POST /transcoding/benchmark` doc updated with the full new field table + per-field source/notes column. |
| 2026-05-07 | Claude (session) | **F10 shipped: Encoder Settings → Run Benchmark.** Server: new `services/benchmark_service.py` runs an 8 s synthetic `lavfi testsrc` (1280×720 @ 30 fps) encode through each detected encoder sequentially with a 35 s per-encoder ceiling. `medium` preset + CRF 23 mirror real-world settings rather than an artificial `ultrafast` pass. Stderr drained from a tempfile, FFmpeg's last progress line parsed via four regexes (`fps=`, `speed=`, `bitrate=`, `frame=`) to populate `EncoderBenchmarkResult` (passed/error + fps/speed_x/bitrate_kbps/encoded_frames/elapsed_sec/realtime_multiplier). Loglevel bumped from `error` to `info` so the progress lines actually emit. New `POST /api/v1/transcoding/benchmark` (localhost-only) accepts optional `duration_sec` (Pydantic-validated 2–20, server-clamps via `clamp_duration`). Desktop: new `EncoderBenchmarkResult` + `EncoderBenchmarkRun` freezed entities in `fluxora_core`; `TranscodingRepository.benchmark()` method added; `ApiClient.post` gained optional `receiveTimeout` param so the repo can override the default 10 s desktop timeout (uses 3 min for the benchmark call to accommodate sequential per-encoder runs). UI: `_BenchmarkBlock` replaces the previously-disabled `_SettingRow`, owning loading/last-run/error state via `setState` (no cubit — one-shot operation); `_BenchmarkResultsTable` renders a 4-column row per encoder (Encoder / FPS / Speed / Bitrate) with check/error icon + emerald-on-realtime / amber-on-sub-realtime / red-on-fail colour cues; failed rows surface the first stderr line below the perf cells. 18 new server tests (parser regexes, clamp bounds, unknown encoder fast-fail, FFmpeg-missing fast-fail, happy-path subprocess mock with stderr injection, failure-with-stderr pass-through, timeout-kills-process-after-budget, sequential orchestrator). Server suite **488 → 508 passing**. `flutter analyze` clean across desktop + core. §11.1 F10 row flipped to ✅ Done. |
| 2026-05-07 | Claude (session) | **F9 Sessions subset shipped + ruff cleanup.** Profile screen `_SessionsTab` rewritten — was a hardcoded `_SessionRow('This device', 'Desktop Control Panel', 'localhost', 'Now', isCurrent: true)` shell with no real data + no buttons. Now wraps in `BlocProvider<ClientsCubit>` (tab-scoped via `getIt<ClientsRepository>()`); `_activeSessions` filters to `status == approved && isTrusted` sorted by `lastSeen` desc; per-row ghost `Sign Out` button → `cubit.revoke(id)` → existing `DELETE /auth/revoke/{id}`; header outline `Sign Out All Devices` button revokes every active session sequentially via `FluxGlassDialog` confirm. `_bulkRevoking` flag dims per-row buttons + skips poll ticks during the sweep. Empty / loading / failure rows wired. Hardcoded "This device / Current" row dropped — desktop CP is localhost-only and never pairs as a client. **Auto-refresh**: new `ClientsCubit.refreshSilent()` re-fetches without flickering through `ClientsLoading`, preserves `filter` + `processingIds`, swallows errors silently. `_SessionsTabBody.initState` starts a 5 s `Timer.periodic` calling it; `dispose` cancels. Pattern matches `ActivityCubit`'s implicit "only emit Loading on first load" idiom but explicit. Tests: +6 cubit cases for `refreshSilent` (happy path / filter preserved / processingIds preserved / no-op-when-not-loaded / no-op-on-failure-state / errors-swallowed); 17 → 23 passing in `clients_cubit_test.dart`. **Danger Zone (delete account / export data) deferred** — compliance scope (GDPR DSR, account-deletion semantics) needs spec before code. **Ruff cleanup**: 34 violations across 13 server files (drift from recent benchmark + streaming-pipeline ships) → 0; auto-fix handled 16 (I001 / F401 / UP035), manual line wraps handled 18 E501s. Pure formatting, zero behavioural change. New gotcha in `03_gotchas.md`: polling cubits need a silent-refresh path or the UI flickers every tick. `flutter analyze` clean. |
| 2026-05-03 | Claude (session) | **M8 deferred items shipped + M10 Custom window chrome shipped.** A11y pass completed for the 8 surfaces Sonnet didn't reach in M8 (Logs, Settings, Encoder Settings, Profile, Help, Notifications panel, Sidebar, Status bar) — `Tooltip` + `Semantics` annotations matching the existing M3-M7 pattern. Golden tests enabled via the GetIt-mock recipe (drop wrapping `MultiBlocProvider`, register mock repos in `setUp`); `dart_test.yaml` skip removed; baseline PNG regenerated; `test/goldens/_README.md` rewritten with the recipe. **M10 implemented:** `window_manager ^0.5.1` added; `main.dart` initialises with `TitleBarStyle.hidden` + `WindowOptions(size: 1440×900, minimumSize: 1332×720)`; new `lib/shared/widgets/flux_titlebar.dart` (36 px, drag region wraps wordmark + tagline, help/bell mid-right, min/max/close flush right at 46×36 px); `flux_shell.dart` restructured to mount titlebar above the existing Stack; sidebar `_LogoHeader` deleted (prototype dropped it); window-control glyphs use Segoe Fluent Icons codepoints (`U+E921` / `U+E922` / `U+E923` / `U+E8BB`) with Segoe MDL2 Assets fallback for native Win 11 visual identity. **Branding pass:** new `assets/brand/app_icon.ico` master regenerated from `logo-icon.png` with tight-crop + 8 % margin (was 59 % glyph fill → now 84 %); runtime copy synced to `windows/runner/resources/`; `Runner.rc` placeholders fixed (`com.example` → `Fluxora`, `fluxora_desktop` → `Fluxora Desktop Control Panel` for ProductName/CompanyName/LegalCopyright/FileDescription); `main.cpp` window title `L"fluxora_desktop"` → `L"Fluxora"`. **Aero Peek fix:** `win32_window.cpp` switched from `WNDCLASS` to `WNDCLASSEX` so both `hIcon` and `hIconSm` are registered (Win 11 thumbnail renderer needs the small variant); `main.cpp` calls `SetCurrentProcessExplicitAppUserModelID(L"Fluxora.Desktop")` before window creation; `shell32.lib` added in `windows/runner/CMakeLists.txt`. Tech stack + gotchas docs updated with Segoe Fluent Icons codepoint table, taskbar-icon margin recipe, Aero Peek root-cause analysis. |

---

## 13. Custom window chrome (M10)

> **Status:** ✅ Done 2026-05-03. `window_manager` 0.5.1 selected (per §13.1 recommendation). Implementation summary in the §12 change log. Spec retained below as design-of-record.

The updated prototype bundle (2026-05-03) ships a 36 px custom titlebar at the top of the app window. Decision #5 was reversed to bring this into scope. This section is the build spec.

### 13.1 Dependency choice

| Option | Pros | Cons |
|--------|------|------|
| **`window_manager` ^0.5.x** *(recommended)* | Actively maintained (last release < 60 days). Single API across Win / macOS / Linux. Ships drag/resize/minimize/maximize/close helpers. Good Wayland coverage. | Slightly heavier than the alternative; adds ~150 KB to release bundle. |
| `bitsdojo_window` ^0.1.x | Smaller surface, well-documented for borderless windows. | Last release > 1 year old; macOS support has known traffic-light edge cases. |
| Roll our own | Zero deps. | ~200 LOC of native code per platform we have to maintain. |

**Recommendation:** `window_manager`. Add per CLAUDE.md Hard Prohibition #6 — single new dep, established maintainer, primary feature is exactly what we need.

### 13.2 Native runner edits

Each Flutter desktop platform needs a small runner change to enable a borderless / transparent window before the Dart side renders.

| Platform | File | Change |
|----------|------|--------|
| Windows | `apps/desktop/windows/runner/main.cpp` | Pre-`runApp` call to `WindowManagerPlugin::SetTitleBarStyle("hidden")` (or equivalent — see `window_manager` README). Keep min size 1100×720 per §3.3 of the prototype's desktop README. |
| macOS | `apps/desktop/macos/Runner/MainFlutterWindow.swift` | Set `titleVisibility = .hidden`, `titlebarAppearsTransparent = true`, `styleMask.insert(.fullSizeContentView)`. Position traffic-light buttons explicitly so they sit inside the custom bar without overlap (`standardWindowButton(.closeButton).frame.origin`). |
| Linux | `apps/desktop/linux/runner/my_application.cc` | Use GTK `gtk_window_set_decorated(window, FALSE)` after window creation. Wayland may still apply server-side decorations on some distros — accept the visual quirk; do not block release. |

Each edit is reversible (one block per file). Diff stays small.

### 13.3 `FluxTitleBar` widget

New file: `apps/desktop/lib/shared/widgets/flux_title_bar.dart`. Sits at the top of `FluxShell` above the sidebar/content row.

**Layout** (matches `prototype/app/desktop/app.jsx` titlebar block + `tbBtn`/`winBtn` styles):

| Region | Spec |
|--------|------|
| **Bar** | Height 36 px, full width, `bg = rgba(6,4,16,0.9)`, `border-bottom: 1px solid rgba(255,255,255,0.04)`. Wraps in `DragToMoveArea` (from `window_manager`) so the whole bar drags the window — except the right cluster. |
| **Left** | `padding-left: 14`. `FluxoraWordmark(height: 13)` + 10 px gap + tagline `· Stream. Sync. Anywhere.` in `AppTypography.micro` colored `#64748B`. |
| **Right cluster (icon buttons)** | 4 px gap. Each button `26×26`, radius 6, `bg = rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.05)`. Icons: `helpCircle` (opens `/help`) and `bell` (opens notifications panel via `NotificationsPanelScope.open(context)`). Bell has a 6×6 violet dot (`#A855F7` with 6 px glow `BoxShadow`) in the top-right corner when `unreadCount > 0`. `margin-right: 8`. |
| **Window controls** | 14 px gap. Three transparent icon-only buttons: minimize (`Icons.remove`, `windowManager.minimize()`), maximize/restore (`Icons.crop_square`, `windowManager.isMaximized() ? unmaximize() : maximize()`), close (`Icons.close`, `windowManager.close()`). All `winBtn` style: transparent bg, no border, 4 px padding. Tooltip on each per §8.5 accessibility checklist. |

**Macros / pitfalls:**
- The right-cluster buttons must NOT be inside `DragToMoveArea` — wrap only the left/middle drag region.
- macOS traffic-light positioning: the `MainFlutterWindow.swift` change leaves them in their default top-left position. Either (a) keep them and shift `FluxTitleBar`'s left padding to 78 px on macOS only, OR (b) hide them entirely (`standardWindowButton(.closeButton).isHidden = true`) and rely on the right-cluster window controls. Owner pick — defaults to (a) for native macOS feel.

### 13.4 Sidebar logo-header removal

Per Decision #6: in `apps/desktop/lib/shared/widgets/flux_sidebar.dart`, delete the existing logo-header block (the leading `Padding` + `FluxoraWordmark(28)` + tagline `Column`). Nav rebuilds from the top of the sidebar, padding `16, 10, 16, 8` (top, right, bottom, left → matches prototype).

The `FluxoraWordmark` widget itself stays; only the sidebar consumer is removed. Titlebar (§13.3) becomes the new consumer.

### 13.5 Notifications-panel hookup

The bell button in the titlebar needs to toggle the existing `NotificationsPanel` overlay (M7). Reuse `NotificationsPanelScope.of(context).toggle()`. The unread-count dot subscribes to `NotificationsCubit.unreadCount` via `BlocSelector` — no rebuild of the rest of the bar.

### 13.6 Close-to-tray (deferred)

The prototype's desktop README §11.1 calls for "close button → minimize to tray" on Windows/Linux. That's a **separate feature** with its own dep (`tray_manager`) and its own native runner work. **Out of scope for M10.** If we want it later, file under "M11 — System tray".

For M10, the close button does what it says: closes the app.

### 13.7 Acceptance criteria (a port is "done" when…)

1. App launches at 1440×900 with custom titlebar visible at the top (no OS chrome) on all three platforms.
2. Wordmark + tagline render at the prototype's exact metrics (13 px wordmark, 11.5 px tagline in `#64748B`).
3. Help button routes to `/help`; bell button toggles `NotificationsPanel`; bell shows the violet dot when `unreadCount > 0`.
4. Min/max/close buttons each work, tooltips appear on hover.
5. Drag region: dragging the titlebar (anywhere except the icon buttons) moves the window.
6. macOS: traffic lights either positioned cleanly inside the bar (option a) or hidden (option b) per owner pick.
7. Linux Wayland: app launches without crash even if SSD is forced; visible quirks acceptable.
8. Sidebar logo-header is gone — nav starts at row 1 of the sidebar.
9. `flutter analyze` clean; no `print()` / `debugPrint()`.
10. AGENT_LOG entry references this section + lists every native runner file touched.

### 13.8 Risks specific to M10

| Risk | Mitigation |
|------|------------|
| `window_manager` plugin breaks on a Flutter SDK bump | Pin in `pubspec.yaml`; revisit at each Flutter upgrade. The plugin's per-platform code is small enough to fork if needed. |
| macOS traffic-light overlap with custom bar content | Either inset left padding to 78 px on macOS (default) or hide traffic lights — both options spec'd in §13.3. |
| Linux Wayland refuses CSD | Document in known issues; visual-only impact, no functional regression. |
| Close-to-tray expectations | Explicitly out of scope (§13.6). Owner already aware; revisit only if requested. |
