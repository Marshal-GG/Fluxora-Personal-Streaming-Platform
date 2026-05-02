# Frontend Architecture

> **Category:** Frontend  
> **Status:** Active - Updated 2026-05-02 (M3 Dashboard shipped: new entities `ActivityEvent` + `LibraryStorageBreakdown`, new features `storage/` + `recent_activity/`, `DashboardScreen` rewritten to pixel-match prototype; SDK floor `>=3.9.0` (Flutter 3.41); 38 desktop tests)

---

## Framework & Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart 3+) |
| Architecture | Clean Architecture (Domain / Data / Presentation) |
| State Management | BLoC (`flutter_bloc`) — Cubit for simple state, Bloc for event-driven |
| HTTP Client | `ApiClient` (Dio) from `fluxora_core` |
| Video Playback | `media_kit` — Phase 2 (player screen not yet built) |
| LAN Discovery | `multicast_dns` (Dart) — PTR→SRV→A resolution |
| WebRTC | `flutter_webrtc ^1.4.1` — Phase 3 ✅ (`WebRtcSignalingService`, LAN skip, transport badge, ICE degradation → HLS fallback) |
| Storage (secrets) | `flutter_secure_storage` (tokens, server URL, client ID) |
| Routing | `go_router` v13 with async auth redirect guard |
| DI | `get_it` — lazy singletons for repos, factories for BLoCs |

---

## Two Client Targets

| Target | Purpose | Status |
|--------|---------|--------|
| **Flutter Mobile** (Android/iOS) | End-user streaming client | ✅ Phases 1–4 complete |
| **Flutter Desktop** (Windows/macOS/Linux) | PC control panel / server management | ✅ Phases 1–5 (Dashboard + Clients + Library + Orders + Activity + Logs + Transcoding + Settings) |

---

## Design System

Two parallel design systems coexist during the redesign migration:

**Mobile / legacy desktop** (Phase 1–5 surface):
- Color palette: dark-mode — `#0F172A` background, `#6366F1` primary, `#22D3EE` accent
- Typography: `Inter` (Google Fonts)
- Theming: Material 3 `ThemeData` with `ColorScheme.dark()`, `CardThemeData`, `AppBarTheme`
- Tokens: `packages/fluxora_core/lib/constants/app_colors.dart` (top half), `app_typography.dart` (top half), `app_sizes.dart`
- Full spec: `DESIGN.md`

**Desktop redesign** (Phase 5 — new tokens, new primitives, no Material defaults):
- Color palette: `#08061A` root, `#A855F7` violet primary, glassmorphic surfaces (`rgba(20,18,38,0.7)`), 7-color pill semantics, status-dot semantics
- Typography: `Inter` 400/500/600/700/800 + `JetBrains Mono` 400/500/600 — bundled, no runtime `google_fonts` fetch
- Theming: not driven by `ThemeData` — every redesign primitive owns its own `BoxDecoration` / `TextStyle` so Material's defaults can't bleed in
- Tokens (new): `packages/fluxora_core/lib/constants/app_colors.dart` v2 section, `app_typography.dart` v2 section, `app_gradients.dart`, `app_spacing.dart`, `app_radii.dart`, `app_shadows.dart`
- Full spec: [`docs/11_design/desktop_redesign_plan.md`](../11_design/desktop_redesign_plan.md)

---

## Desktop Redesign — M1 Foundation (✅ Done 2026-05-02) · M2 Shell (✅ Done) · M3 Dashboard (✅ Done 2026-05-02)

The redesigned Fluxora Desktop app is being built screen-by-screen following [`desktop_redesign_plan.md`](../11_design/desktop_redesign_plan.md). M1 (foundation) ships the design tokens, primitives, and brand visuals — every later milestone builds on these.

### Token files — `packages/fluxora_core/lib/constants/`

| File | Owns |
|------|------|
| `app_colors.dart` | v2 palette: `bgRoot`, `surfaceGlass`, `borderSubtle`, `borderHover`, `textBright`/`textBody`/`textMutedV2`/`textDim`/`textFaint`, `violet`/`violetDeep`/`violetTint`/`violetSoft`, semantic colours, 7 pill bg/fg pairs, 8 status-dot colours |
| `app_gradients.dart` *(new)* | `brand` (135°), `progress` (90°), `upgradeCallout`, `bgRadialViolet`, `bgRadialCyan` |
| `app_spacing.dart` *(new)* | Locked spacing scale `s2 … s32` — anything outside the set is a typo |
| `app_radii.dart` *(new)* | `xs=6, sm=8, md=10, lg=12, pill=9999` |
| `app_shadows.dart` *(new)* | `cardGlow`, `buttonGlow`, `dotGlow(color)` |
| `app_typography.dart` | v2 styles `displayV2`, `h1`, `h2`, `body`, `bodySmall`, `captionV2`, `micro`, `eyebrow`, plus `monoBody`/`monoCaption`/`monoMicro` |

### Brand assets — `packages/fluxora_core/assets/`

| Path | Purpose |
|------|---------|
| `brand/logo-icon.png` | Standalone F lettermark — owner's original from `docs/11_design/ref images/brand/logo_icon_dark.png`, auto-processed (Pillow alpha-from-brightness) to remove the dark backdrop, gradient anti-aliasing preserved. Available for any slot that needs just the icon (favicon source, app icon, brand-card slot) |
| `brand/logo-wordmark.png` | Legacy stacked wordmark (F on top of FLUXORA text). Kept for brand-card slots that want the stacked layout; **not** used in primary nav surfaces |
| `brand/logo-wordmark-h.png` | **Primary brand asset** — integrated horizontal wordmark (F + FLUXORA in one image, refined 3D-style F). Sourced from `docs/11_design/ref images/brand/logo_wordmark_horizontal_v2_dark.png`, same Pillow processing. Used by `FluxoraWordmark` widget (Flutter), web Navbar / Footer (Next.js). Replaces the icon + separate-text composition in those surfaces — combining both would double the F |
| `illustrations/hero_waves.svg` | Decorative animated wave-line backdrop (5 paths, dash-offset + gradient-translate animations) |
| `illustrations/pulse_ring.svg` | Concentric expanding rings for live-status indicators (offset half-cycle) |
| `illustrations/empty_libraries.svg` | "No libraries yet" empty-state illustration |
| `illustrations/empty_clients.svg` | "No clients connected" empty-state illustration with animated signal arcs |

### Primitives — `apps/desktop/lib/shared/widgets/`

Pixel-matched to `docs/11_design/desktop_prototype/app/components/primitives.jsx`. Every primitive replaces a Material default; no `ElevatedButton`, `Switch`, `Card`, `LinearProgressIndicator`, etc.

| File | Widget | Notes |
|------|--------|-------|
| `flux_card.dart` | `FluxCard({padding, hoverable, glow, onTap})` | `MouseRegion` hover → `borderHover` + violet tint; optional `cardGlow` |
| `section_label.dart` | `SectionLabel(text)` | 11 / 600 / 0.14em uppercase |
| `status_dot.dart` | `StatusDot({status, size})` + `DotStatus` enum | 8-status palette; halo on online/active/streaming |
| `pill.dart` | `Pill(text, {color, icon})` + `PillColor` enum | 7 variants, optional leading icon |
| `flux_progress.dart` | `FluxProgress({value, height, color, trackColor})` | 400 ms `TweenAnimationBuilder` width animation; gradient fill |
| `flux_button.dart` | `FluxButton({variant, size, icon, iconRight, onPressed, fullWidth, child})` | 6 variants × 3 sizes; no Material ripple; hover via `MouseRegion` + `setState` |
| `stat_tile.dart` | `StatTile({icon, label, value, sub, color, iconBg, accent})` | Wraps `FluxCard`; 44 × 44 icon badge + label/value/sub stack |
| `sparkline.dart` | `Sparkline({data, color, height, strokeWidth})` | `CustomPainter` with single open path |
| `storage_donut.dart` | `StorageDonut({segments, centerText, unitText, size, strokeWidth})` + `StorageDonutSegment` | `CustomPainter` `drawArc` per segment, -90° start |
| `page_header.dart` | `PageHeader({title, subtitle, actions})` | Standard screen header — owns vertical padding only |

### Brand visuals — `packages/fluxora_core/lib/widgets/`

`brand_visuals.dart` exports:
- `HeroWaves({fit, alignment, opacity})` — renders `hero_waves.svg`
- `BrandLoader({size})` — composites the **untouched** `FluxoraMark` PNG inside a Flutter-painted rotating sweep-gradient ring + 6 % scale-pulse on the mark. The brand mark itself is never re-drawn; only the surrounding ring is Flutter-driven.
- `PulseRing({size, color})` — renders `pulse_ring.svg` with `colorFilter: srcIn` so the rings inherit the caller's chosen colour
- `EmptyState({illustration, title, message, illustrationHeight})` + `EmptyStateIllustration.libraries / .clients`

`fluxora_logo.dart` exports:
- `FluxoraMark({size, glow})` — standalone F lettermark, square. Use only when a non-F-bearing wordmark won't fit (favicon, app icon, tight brand-card slot).
- `FluxoraWordmark({height})` — **integrated horizontal wordmark** (F + FLUXORA in one image, `logo-wordmark-h.png`). Default height 28 px. The primary brand element for any nav / sidebar / hero use.
- `FluxoraLogo({size, withWordmark, withTagline})` — composite. With `withWordmark: true` (default), renders only the integrated wordmark + optional tagline below. With `withWordmark: false`, falls back to standalone `FluxoraMark` only. Never renders both side-by-side (would double the F).

### Showcase route

[`apps/desktop/lib/shared/showcase/primitives_showcase_screen.dart`](../../apps/desktop/lib/shared/showcase/primitives_showcase_screen.dart) renders every redesign primitive in every variant on the `bgRoot` background. Routed at `/showcase` outside the `ShellRoute` so it sits on a clean canvas for visual diff against the prototype. Removed at the M9 cutover.

---

## Screen / Route Map — Flutter Mobile (Implemented)

| Route | Screen | State class | Status |
|-------|--------|-------------|--------|
| `/` | ConnectScreen | `ConnectCubit` | ✅ Done |
| `/pairing` | PairingScreen | `PairCubit` | ✅ Done |
| `/library` | LibraryScreen | `LibraryBloc` | ✅ Done |
| `/library/:id/files` | FilesScreen | `FilesCubit` | ✅ Done |
| `/player` | PlayerScreen | `PlayerCubit` | ✅ Done |
| `/upgrade` (push) | UpgradeScreen | — (stateless) | ✅ Done |

Auth guard: `go_router` `redirect` callback reads `SecureStorage` — unauthenticated users
are redirected to `/`, authenticated users skip `/` and `/pairing` directly to `/library`.

---

## Flutter Mobile Project Structure (Implemented)

```
apps/mobile/lib/
├── main.dart                    # setupInjector() → runApp()
├── app.dart                     # MaterialApp.router — AppTheme.dark + appRouter
│
├── core/
│   ├── di/
│   │   └── injector.dart        # get_it registrations; restores credentials on restart
│   └── router/
│       └── app_router.dart      # GoRouter + Routes constants + _guardRedirect
│
├── shared/
│   └── theme/
│       └── app_theme.dart       # AppTheme.dark — Material 3 ThemeData from design tokens
│
└── features/
    ├── connect/
    │   ├── domain/entities/
    │   │   └── discovered_server.dart    # name, ip, port, url getter
    │   ├── data/repositories/
    │   │   └── server_discovery_repository_impl.dart  # multicast_dns PTR→SRV→A
    │   └── presentation/
    │       ├── cubit/connect_cubit.dart  # startDiscovery() acquires MulticastLock then streams
    │       └── screens/connect_screen.dart  # auto-discovery list + manual IP entry; configures ApiClient on server select
    │
    ├── auth/
    │   ├── domain/repositories/
    │   │   └── auth_repository.dart      # interface + PairRejectedException
    │   ├── data/repositories/
    │   │   └── auth_repository_impl.dart # ApiClient calls, SecureStorage writes
    │   └── presentation/
    │       ├── cubit/pair_cubit.dart     # Timer.periodic polling, UUID v4 generation
    │       ├── cubit/pair_state.dart     # PairInitial/Requesting/Pending/Approved/Rejected/Error
    │       └── screens/pairing_screen.dart
    │
    ├── library/
    │   ├── domain/repositories/
    │   │   └── library_repository.dart   # listLibraries(), listFiles()
    │   ├── data/repositories/
    │   │   └── library_repository_impl.dart
    │   └── presentation/
    │       ├── bloc/library_bloc.dart    # LibraryStarted, LibraryRefreshed events
    │       ├── bloc/library_state.dart   # LibraryInitial/Loading/Success/Failure
    │       ├── screens/library_screen.dart   # 2-column GridView of library cards
    │       └── screens/files_screen.dart     # ListView of media files; taps push /player
    │
    └── player/
        ├── domain/entities/
        │   └── stream_start_response.dart    # sessionId, fileId, playlistUrl
        ├── domain/repositories/
        │   └── player_repository.dart        # startStream(fileId), stopStream(sessionId)
        ├── data/repositories/
        │   └── player_repository_impl.dart   # POST /stream/start, DELETE /stream/:id
        ├── data/services/
        │   ├── webrtc_signaling_service.dart  # WebSocket SDP/ICE handshake + RTCPeerConnection lifecycle
        │   └── network_path_detector.dart    # isLan() — RFC-1918 /24 subnet check; LAN→HLS, WAN→WebRTC
        └── presentation/
            ├── cubit/player_cubit.dart   # startStream → LAN check → WebRTC (8 s timeout) → HLS fallback; _handleSignalingDegradation for ICE drop
            ├── cubit/player_state.dart   # PlayerInitial/Loading/Ready(streamPath)/Failure; StreamPath enum; PlayerReady.copyWith
            └── screens/player_screen.dart    # Full-screen Video + MaterialVideoControls + _TransportBadge chip; _readyOnce guard; _SettingsSheet (speed, audio track, subtitle track)
```

---

## State Management Pattern

```
UI Event ──▶ BLoC/Cubit ──▶ Repository (interface) ──▶ ApiClient (fluxora_core)
                │                                              │
                └──────────── State emitted ◀──────────────────┘
```

- Use **Cubit** when there are no multi-event chains (connect discovery, pairing, file list)
- Use **Bloc** when events drive different state transitions (library — started vs refreshed)
- Never mix BLoC and Riverpod within a feature

---

## DI Registration Pattern

```dart
// Singletons — created once
getIt.registerSingleton<FlutterSecureStorage>(...)
getIt.registerSingleton<SecureStorage>(...)
getIt.registerSingleton<ApiClient>(ApiClient())  // dual-base; URLs set after restore

// Lazy singletons — created on first use
getIt.registerLazySingleton<LibraryRepository>(() => LibraryRepositoryImpl(...))

// Factories — fresh instance per BlocProvider
// BLoCs are NOT registered in get_it; created inline via BlocProvider
```

On app restart: `setupInjector()` reads `SecureStorage` (both `serverUrl` and `remoteUrl`) and calls `ApiClient.configure(localBaseUrl: …, remoteBaseUrl: …, bearerToken: …)` to restore credentials and routing before any repository is used.

---

## Routing Rules

- All routes defined in `app_router.dart` — never `Navigator.push()` directly
- Route paths: lowercase kebab-case (`/library/:id/files`)
- Route names: `const` string constants in `Routes` class
- Navigate with `context.go()` (replace stack) or `context.push()` (add to stack)
- Extra objects passed via `state.extra` (e.g. `DiscoveredServer`, library name string)

---

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| mDNS package | `multicast_dns` | Dart-native, no external process; PTR→SRV→A chain resolves full address |
| Android MulticastLock | `MethodChannel('dev.marshalx.fluxora/multicast')` | Android silently drops multicast without `WifiManager.MulticastLock`; acquired in `ConnectCubit.startDiscovery()`, released on close; non-fatal if unavailable (iOS/desktop) |
| ApiClient configure | Called in `ConnectScreen` on server select | Server URL must be set on `ApiClient` before any pairing request; done at navigation time, not at app start |
| UUID generation | Custom via `dart:math` + `Random.secure()` | Avoids adding `uuid` package for one use |
| Video player | `media_kit v1.2.6` | `better_player` incompatible with AGP 8+ |
| WebRTC | `flutter_webrtc ^1.4.1` — Phase 3 ✅ | `WebRtcSignalingService` + `NetworkPathDetector`; LAN detection skips negotiation; 8 s ICE timeout with HLS fallback |
| Smart path | `NetworkPathDetector.isLan()` (in `fluxora_core`) | Pure in-process /24 subnet check; no DNS, no ICMP; fails-safe to WAN. Used by `ApiClient` for dual-base routing and by `PlayerCubit` for the WebRTC vs HLS decision |
| Dual-base ApiClient | `ApiClient(localBaseUrl, remoteBaseUrl, lanCheck)` in `fluxora_core` | Per-request resolution: LAN → localBaseUrl, WAN → remoteBaseUrl; throws `NoRemoteConfiguredException` if off-LAN with no remote configured. Phase 3 of public-routing plan |
| Transport badge | `_TransportBadge` chip | Auto-hides after 5 s; HLS (dark chip) vs WebRTC (deep-purple chip + `cell_tower` icon); re-appears on ICE degradation |
| ICE degradation | `_handleSignalingDegradation()` in `PlayerCubit` | `SignalingState.failed` post-connection → `copyWith(streamPath: hls)` emitted; signaling closed; player uninterrupted (HLS was always underlying transport) |
| Resume banner guard | `_readyOnce` in `_PlayerViewState` | Prevents resume banner from re-firing when `PlayerReady` is re-emitted for transport switch |
| Poll interval | Configurable `Duration` on `PairCubit` | Default 3s in production; 30ms in tests — avoids slow test suite |
| Upgrade screen | `UpgradeScreen` (push, not go_router route) | Mobile cannot call `PATCH /settings` (localhost-only); screen shows tier plans + instructs user to activate key in Desktop Control Panel |
| Tier limit view | `_TierLimitView` in `player_screen.dart` | Replaces generic error on 429; gradient icon + `FilledButton` → `UpgradeScreen`, `OutlinedButton` → Go Back |
| `validate_token_or_local` | Files and library endpoints accept bearer token OR localhost | Desktop control panel is always on localhost; avoids needing a client pairing flow for the admin UI. Mobile clients still send a bearer token. |
| Dart 3.8+ null-aware map syntax | `{'key': ?nullableValue}` in `SettingsCubit.saveSettings` | Only includes a key in the PATCH body if the value is non-null. Available since Dart 3.8; project floor is `>=3.9.0`. |
| `_SettingsSheet` in player | Speed controls (0.5–2.0×), audio track picker, subtitle track picker | Exposed via bottom sheet from a settings button in the player controls overlay |

---

## Testing Approach

- **Unit tests** for all BLoCs and Cubits using `bloc_test` + `mocktail`
- Sealed state types tested with `isA<>()` matchers (not concrete equality)
- Data assertions in `verify:` callbacks after state check
- `PairCubit` timer tests use `pollInterval: Duration(milliseconds: 30)` + `wait:`
- No real network calls in any test — all repositories are mocked

```
Mobile test/ (27 tests)
├── features/
│   ├── connect/connect_cubit_test.dart           # 5 tests
│   ├── auth/pair_cubit_test.dart                 # 5 tests
│   ├── auth/auth_repository_impl_test.dart       # 3 tests (post-pair /info fetch + remote_url persistence)
│   ├── library/library_bloc_test.dart            # 6 tests
│   └── player/player_cubit_test.dart             # 8 tests
└── placeholder_test.dart

Desktop test/ (38 tests)
└── features/
    ├── dashboard/dashboard_cubit_test.dart  # 3 tests ✅
    ├── clients/clients_cubit_test.dart      # 7 tests ✅
    └── settings/settings_cubit_test.dart    # 17 tests ✅ (loadSettings + saveSettings + license_key PATCH + Remote Access — `loadSettings` populates `remoteUrl` from `/info`; `checkRemoteAccess` early-return paths)
    └── (library/orders/activity/logs/transcoding cubits tested via manual integration)
```

---

## Flutter Desktop Project Structure (Phases 1–5 — implemented)

```
apps/desktop/lib/
├── main.dart                    # setupInjector() → runApp()
├── app.dart                     # MaterialApp.router — AppTheme.dark + appRouter
│
├── core/
│   ├── di/
│   │   └── injector.dart        # get_it: ApiClient (localhost:8080), all repositories, OrdersCubit factory, SettingsCubit factory
│   └── router/
│       └── app_router.dart      # GoRouter + Routes + ShellRoute wrapping AppShell (Dart 3.8 wildcard params)
│
├── shared/
│   ├── theme/
│   │   └── app_theme.dart       # AppTheme.dark — Material 3 ThemeData + NavigationRailTheme
│   └── widgets/
│       ├── sidebar.dart         # AppShell + _Sidebar + _NavItem (Dashboard/Library/Clients/Licenses/Activity/Settings)
│       ├── stat_card.dart       # Dashboard stat card with icon + value + label
│       └── status_badge.dart    # ClientStatus badge (Approved/Pending/Rejected)
│
└── features/
    ├── dashboard/               # ✅ Implemented + M3 redesign (pixel-matched prototype)
    │   ├── domain/repositories/dashboard_repository.dart  # + restartServer() / stopServer()
    │   ├── data/repositories/dashboard_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/dashboard_cubit.dart  # load() fetches serverInfo + clients
    │       ├── cubit/dashboard_state.dart
    │       └── screens/dashboard_screen.dart  # MultiBlocProvider: Dashboard+Storage+RecentActivity+SystemStats
    │
    ├── clients/                 # ✅ Implemented
    │   ├── domain/repositories/clients_repository.dart
    │   ├── data/repositories/clients_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/clients_cubit.dart
    │       ├── cubit/clients_state.dart
    │       └── screens/clients_screen.dart  # M4 redesign: PageHeader + 4 StatTiles + search/filter row + 7-column table + 300px detail panel (approve/reject/revoke wired)
    │
    ├── library/                 # ✅ Implemented (Phase 5)
    │   ├── domain/repositories/library_repository.dart
    │   ├── data/repositories/library_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/library_cubit.dart
    │       ├── cubit/library_state.dart
    │       └── screens/library_screen.dart  # Create/scan/upload/filter libraries
    │
    ├── orders/                  # ✅ Implemented (Phase 5)
    │   ├── domain/repositories/orders_repository.dart
    │   ├── data/repositories/orders_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/orders_cubit.dart
    │       └── screens/licenses_screen.dart  # Polar orders with copyable license keys + tier color chips
    │
    ├── activity/                # ✅ Implemented (Phase 5 — active sessions, legacy name, DO NOT rename)
    │   ├── domain/repositories/activity_repository.dart
    │   ├── data/repositories/activity_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/activity_cubit.dart   # freezed state
    │       └── screens/activity_screen.dart  # Active stream sessions monitor
    │
    ├── storage/                 # ✅ M3 — storage breakdown for Dashboard donut
    │   ├── domain/repositories/storage_repository.dart
    │   ├── data/repositories/storage_repository_impl.dart   # GET /api/v1/library/storage-breakdown
    │   └── presentation/cubit/
    │       ├── storage_cubit.dart      # load() → StorageLoaded(breakdown)
    │       └── storage_state.dart      # StorageInitial|Loading|Loaded|Failure
    │
    ├── recent_activity/         # ✅ M3 — activity event log for Dashboard card
    │   ├── domain/repositories/recent_activity_repository.dart
    │   ├── data/repositories/recent_activity_repository_impl.dart   # GET /api/v1/activity?limit=4
    │   └── presentation/cubit/
    │       ├── recent_activity_cubit.dart   # load()/refresh() → RecentActivityLoaded([events])
    │       └── recent_activity_state.dart   # RecentActivityInitial|Loading|Loaded|Failure
    │
    ├── logs/                    # ✅ Implemented (Phase 5)
    │   ├── domain/repositories/logs_repository.dart
    │   ├── data/repositories/logs_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/logs_cubit.dart
    │       ├── cubit/logs_state.dart
    │       └── screens/logs_screen.dart  # Live server log viewer
    │
    ├── transcoding/             # 🔵 Partial (Phase 5 — screen scaffold only; settings via SettingsScreen)
    │   └── presentation/screens/transcoding_screen.dart
    │
    └── settings/                # ✅ Implemented (Phases 2 + 5)
        ├── domain/repositories/settings_repository.dart
        ├── data/repositories/settings_repository_impl.dart
        └── presentation/
            ├── cubit/settings_cubit.dart   # loadSettings(), saveSettings(); transcoding fields; Dart 3.8 null-aware map syntax
            ├── cubit/settings_state.dart   # SettingsLoaded includes transcodingEncoder/Preset/Crf
            └── screens/settings_screen.dart  # URL + server name + tier + license key + transcoding encoder/preset/CRF + "View Licenses" button
```

### Desktop routes

| Route | Screen | State class | Status |
|-------|--------|-------------|--------|
| `/` | DashboardScreen | `DashboardCubit` + `StorageCubit` + `RecentActivityCubit` + `SystemStatsCubit` | ✅ Done (M3 redesign) |
| `/clients` | ClientsScreen | `ClientsCubit` | ✅ Done (M4 redesign) |
| `/library` | LibraryScreen | `LibraryCubit` | ✅ Done |
| `/licenses` | LicensesScreen | `OrdersCubit` | ✅ Done |
| `/activity` | ActivityScreen | `ActivityCubit` | ✅ Done |
| `/settings` | SettingsScreen | `SettingsCubit` | ✅ Done |
| `/showcase` | PrimitivesShowcaseScreen | — (stateless; M1 redesign primitives) | ✅ Done — renders outside `ShellRoute`; deep-link only |

Desktop uses `ShellRoute` with a fixed 200 px `_Sidebar` on the left and the page content in an `Expanded` right panel. No authentication required — all API calls are localhost-only (`require_local_caller`) or `validate_token_or_local`.
