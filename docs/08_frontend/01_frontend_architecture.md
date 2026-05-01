# Frontend Architecture

> **Category:** Frontend  
> **Status:** Active - Updated 2026-05-01 (Phase 5: desktop library/orders/activity/logs/transcoding screens; mobile player settings sheet; Dart 3.8 SDK; 34 desktop tests)

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

- **Color Palette:** Dark-mode — `#0F172A` background, `#6366F1` primary, `#22D3EE` accent
- **Typography:** `Inter` (Google Fonts)
- **Theming:** Material 3 `ThemeData` with `ColorScheme.dark()`, `CardThemeData`, `AppBarTheme`
- Full spec: `DESIGN.md`

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
| Dart 3.8 null-aware map syntax | `{'key': ?nullableValue}` in `SettingsCubit.saveSettings` | Only includes a key in the PATCH body if the value is non-null; requires `sdk: '>=3.8.0'` in pubspec.yaml |
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

Desktop test/ (34 tests)
└── features/
    ├── dashboard/dashboard_cubit_test.dart  # 3 tests ✅
    ├── clients/clients_cubit_test.dart      # 7 tests ✅
    └── settings/settings_cubit_test.dart    # 13 tests ✅ (loadSettings + saveSettings; license_key PATCH)
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
    ├── dashboard/               # ✅ Implemented
    │   ├── domain/repositories/dashboard_repository.dart
    │   ├── data/repositories/dashboard_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/dashboard_cubit.dart  # load() fetches info + clients
    │       ├── cubit/dashboard_state.dart
    │       └── screens/dashboard_screen.dart
    │
    ├── clients/                 # ✅ Implemented
    │   ├── domain/repositories/clients_repository.dart
    │   ├── data/repositories/clients_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/clients_cubit.dart
    │       ├── cubit/clients_state.dart
    │       └── screens/clients_screen.dart  # Filter chips + ClientTile with approve/reject
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
    ├── activity/                # ✅ Implemented (Phase 5)
    │   ├── domain/repositories/activity_repository.dart
    │   ├── data/repositories/activity_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/activity_cubit.dart   # freezed state
    │       └── screens/activity_screen.dart  # Active stream sessions monitor
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
| `/` | DashboardScreen | `DashboardCubit` | ✅ Done |
| `/clients` | ClientsScreen | `ClientsCubit` | ✅ Done |
| `/library` | LibraryScreen | `LibraryCubit` | ✅ Done |
| `/licenses` | LicensesScreen | `OrdersCubit` | ✅ Done |
| `/activity` | ActivityScreen | `ActivityCubit` | ✅ Done |
| `/settings` | SettingsScreen | `SettingsCubit` | ✅ Done |

Desktop uses `ShellRoute` with a fixed 200 px `_Sidebar` on the left and the page content in an `Expanded` right panel. No authentication required — all API calls are localhost-only (`require_local_caller`) or `validate_token_or_local`.
