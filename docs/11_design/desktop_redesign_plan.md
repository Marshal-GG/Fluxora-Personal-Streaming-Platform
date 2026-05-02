# Desktop App Redesign — Implementation Plan

> **Status:** Implementing — M0 backend prerequisites partially shipped, M1 foundation complete (2026-05-02), M2 shell complete, M3 Dashboard complete (2026-05-02), M4 Library + Clients complete (2026-05-02), M5 Groups + Activity + Transcoding complete (2026-05-02), M6 Logs + Settings complete (2026-05-02), **M7 Subscription + Profile + Notifications + Help complete (2026-05-02)**
> **Created:** 2026-05-01
> **Owner:** Marshal
> **Source design:** [`docs/11_design/desktop_prototype/`](./desktop_prototype/) — React/JSX prototype exported from claude.ai/design
> **Target:** [`apps/desktop/`](../../apps/desktop/) — Flutter desktop control panel

This plan translates the Fluxora Desktop prototype into the existing Flutter desktop app. It is the single source of truth for the redesign — every screen PR should reference a section here.

---

## Progress

### M0 — Backend prerequisites *(in progress)*

| § | Item | Status | Landed |
|---|------|--------|--------|
| 7.1 | Groups feature (table, service, 8 endpoints, stream-gate) | ✅ Done | migration 011 + `routers/groups.py` + `services/group_service.py` + stream-gate hook |
| 7.2 | Profile management (GET/PATCH + password change) | ✅ Done | migration 012 + `routers/profile.py` + `services/profile_service.py` |
| 7.3 | Notifications | 🔲 Pending | — |
| 7.4 | Activity feed (event log) | 🔲 Pending | — (existing endpoint lists active stream sessions only) |
| 7.5 | Storage breakdown | ✅ Done | `GET /api/v1/library/storage-breakdown` + `library_service.get_storage_breakdown()` |
| 7.6 | System stats stream | ✅ Done | `GET /api/v1/info/stats` + `WS /api/v1/ws/stats` + `services/system_stats_service.py` (psutil) |
| 7.7 | Restart / stop endpoints | ✅ Done | `POST /api/v1/info/restart`, `POST /api/v1/info/stop` (localhost-only) |
| 7.8 | Transcoding status (per-encoder load) | 🔲 Pending | — |
| 7.9 | Logs structured filtering | 🔲 Pending | — |
| 7.10 | Settings extension (19 columns) | 🔲 Pending | — |
| 7.11 | Orders pagination + Polar portal URL | 🔲 Pending | — |

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

### M4 — Library + Clients *(🔵 In Progress)*

- **Library screen** *(✅ Done)* — full grid, stat tiles, FluxTabBar, detail panel, `StorageCubit` integration.
- **Clients screen** *(✅ Done 2026-05-02)* — `clients_screen.dart` fully rewritten. No Material `Scaffold`/`AppBar`/`Card`/`DataTable`. Implements: `PageHeader`, 4 `StatTile`s (total/online/active streams placeholder/total connections), client-side search + status/device/sort `PopupMenuButton` filters, 7-column table in `FluxCard(padding: 0)` with hover + selected row states, visual-only pagination footer, 300 px detail panel with avatar block + 7 info rows + 4 action tiles (Disconnect Client wired to `cubit.reject()`; 3 others disabled with TODO comments). `FluxTabBar` primitive shipped as part of Library. Active Streams tile shows `—` pending `SystemStatsCubit` accessibility (TODO comment in code). IP address and per-client session columns show `—` pending backend fields.

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

### M8–M9 *(not started)*

Pending M7 visual review against prototype.

---

## 1. Decisions locked in

These are the answered questions that shape the rest of the plan. Do not relitigate without updating this section.

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Direct replacement.** No `/v2/*` routes, no feature flag, no kept-alongside legacy code. Each screen PR replaces the existing screen file. | Owner wants no legacy code carry-over. |
| 2 | **Real backend data only.** No mock-data layer in Flutter. Where the screen needs data the backend doesn't yet expose, the **backend endpoint ships before the screen** (see §7). | Owner wants only real user data. |
| 3 | **Cmd+K palette = navigation only** (v1). No global media search in v1. | Scoped down for ship-ability. |
| 4 | **Tweaks panel removed.** No accent-color customization. Brand violet (`#A855F7`) is fixed. | The prototype's tweaks were a design-tool affordance; not a product feature. |
| 5 | **Native window chrome.** Use the OS title bar on every platform. No `bitsdojo_window`, no custom traffic-light buttons. The prototype's titlebar is **not** translated. | Owner asked to remove. Reduces platform-specific code paths. |

The bottom **status bar** (CPU/RAM/network/uptime strip) **is** kept — it is a content widget rendered inside the Flutter window, not OS chrome.

---

## 2. Source-of-truth files

| Concern | File |
|---------|------|
| Visual reference (open in browser) | [`docs/11_design/desktop_prototype/Fluxora Desktop.html`](./desktop_prototype/Fluxora%20Desktop.html) |
| Primitive widget definitions | [`docs/11_design/desktop_prototype/app/components/primitives.jsx`](./desktop_prototype/app/components/primitives.jsx) |
| Sidebar layout | [`docs/11_design/desktop_prototype/app/components/sidebar.jsx`](./desktop_prototype/app/components/sidebar.jsx) |
| Per-screen layout | `docs/11_design/desktop_prototype/app/screens/<name>.jsx` |
| Per-tab/sub-page layout | `docs/11_design/desktop_prototype/app/pages/<name>.jsx` |
| Sample data shapes (study only — do not copy) | `docs/11_design/desktop_prototype/app/data/fluxora-data*.jsx` |
| Brand assets (PNGs) | `docs/11_design/desktop_prototype/app/assets/logo-icon.png`, `logo-wordmark.png` |
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
- Top: `FluxoraWordmark(28)` + tagline (the wordmark is the integrated F + FLUXORA image — `logo-wordmark-h.png` — so no separate `FluxoraMark` is rendered next to it; that would double the F).
- 9 nav items: Dashboard, Library, Clients, Groups, Activity, Transcoding, Logs, Settings, Subscription. (Current sidebar has 6; this **adds** Groups, Activity, Subscription, **renames** Licenses → Subscription, **drops** the Settings-as-bottom-item pattern.)
- Hover + active states: violet tint (`rgba(168,85,247,0.14)` bg, `rgba(168,85,247,0.3)` border, `#E9D5FF` text on active).
- System Status block: server-running / LAN mode + IP / Internet Access — fed by `SystemStatusCubit` (new, see §6.3).
- Upgrade card: visible only when `tier != ultimate`. Reads tier from existing `OrdersCubit` / `SettingsCubit`.
- User footer: routes to `/profile`. Avatar uses `FluxAvatar` with `linear-gradient(135deg, #A855F7, #6366F1)` fallback.

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
| 1 | **Dashboard** | `DashboardCubit` (extend) | `StorageCubit` *(new)*, `RecentActivityCubit` *(new)* | §7.5, §7.6, §7.7 | ✅ Done |
| 2 | **Library** | `LibraryCubit` (kept) | – | – | 🔲 Pending |
| 3 | **Clients** | `ClientsCubit` (kept) | – | – | 🔲 Pending |
| 4 | **Groups** | – | `GroupsCubit` *(new)* | §7.1 | 🔲 Pending |
| 5 | **Activity** | `ActivityCubit` (kept) | – | – | 🔲 Pending |
| 6 | **Transcoding** + Encoder Settings | `SettingsCubit` (extend) | `TranscodingCubit` *(new)* | §7.8 | 🔲 Pending |
| 7 | **Logs** + tabs | `LogsCubit` (extend) | – | §7.9 | 🔲 Pending |
| 8 | **Settings** + 6 tabs | `SettingsCubit` (extend) | – | §7.10 | 🔲 Pending |
| 9 | **Subscription** + Billing + Manage | `OrdersCubit` (extend) | – | §7.11 | 🔲 Pending |
| 10 | **Profile** | – | `ProfileCubit` *(new)* | §7.2 | 🔲 Pending |
| 11 | **Notifications** | – | `NotificationsCubit` *(new)* | §7.3 | 🔲 Pending |
| 12 | **Help** | – | – (static) | – | 🔲 Pending |

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
| **M0 — Backend prerequisites** | §7.1 Groups · §7.2 Profile · §7.3 Notifications (schema + endpoints + WS events) · §7.5 Storage breakdown · §7.6 System stats · §7.7 Restart/Stop · §7.8 Transcoding status · §7.9 Logs filter · §7.10 Settings extension · §7.11 Orders list + portal | 4–5 days |
| **M1 — Foundation** | All design tokens, all primitives + widgetbook stories, FluxoraMark/Wordmark widgets, font + asset registration | 2 days |
| **M2 — Shell** | Sidebar + status bar + new routes (replacing existing), `SystemStatsCubit`, Cmd+K palette | 1.5 days |
| **M3 — Dashboard** | Pixel-verified Dashboard, live-tick wiring, Sparkline, Donut | 1.5 days |
| **M4 — Library + Clients** | Both screens incl. detail panels | 2 days |
| **M5 — Groups + Activity + Transcoding** | All three + Encoder Settings sub-page | 2 days ✅ Done 2026-05-02 |
| **M6 — Logs + Settings** | Logs filtering UI + all 6 Settings tabs | 2 days |
| **M7 — Subscription + Profile + Notifications + Help** | Subscription + Billing + Manage + Profile + Notifications overlay + Help | 2 days |
| **M8 — Polish + visual QA** | Cmd+K polish, accessibility pass, golden tests, pixel review against prototype | 1.5 days |
| **M9 — Cleanup + docs** | Delete legacy screen files, update all docs per §10, update `AGENT_LOG.md` | 0.5 day |

**Total: ~19 working days.** Backend (M0) can run in parallel with M1 once primitives are scoped.

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
