# Frontend Architecture

> **Category:** Frontend  
> **Status:** Active — Updated 2026-04-28 (Phase 1 mobile implemented)

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
| WebRTC | `flutter_webrtc` — Phase 3 only (not currently a dependency) |
| Storage (secrets) | `flutter_secure_storage` (tokens, server URL, client ID) |
| Routing | `go_router` v13 with async auth redirect guard |
| DI | `get_it` — lazy singletons for repos, factories for BLoCs |

---

## Two Client Targets

| Target | Purpose | Status |
|--------|---------|--------|
| **Flutter Mobile** (Android/iOS) | End-user streaming client | 🔵 Phase 1 complete (no player yet) |
| **Flutter Desktop** (Windows/macOS/Linux) | PC control panel / server management | 🔲 Phase 2 |

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
| `/settings` | SettingsScreen | — | 🔲 Phase 2 |

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
        └── presentation/
            ├── cubit/player_cubit.dart   # startStream → Player+VideoController; stopStream on close
            ├── cubit/player_state.dart   # PlayerInitial/Loading/Ready/Failure
            └── screens/player_screen.dart    # Full-screen Video widget + MaterialVideoControls
```

---

## State Management Pattern

```
UI Event ──▶ BLoC/Cubit ──▶ Repository (interface) ──▶ ApiClient (fluxora_core)
                │                                              │
                └──────────── State emitted ◀─────────────────┘
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
getIt.registerSingleton<ApiClient>(ApiClient(baseUrl: ''))

// Lazy singletons — created on first use
getIt.registerLazySingleton<LibraryRepository>(() => LibraryRepositoryImpl(...))

// Factories — fresh instance per BlocProvider
// BLoCs are NOT registered in get_it; created inline via BlocProvider
```

On app restart: `setupInjector()` reads `SecureStorage` and calls `ApiClient.configure()` to
restore credentials before any repository is used.

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
| Video player | Deferred to Phase 2 | `better_player` incompatible with AGP 8+; will use `media_kit` |
| WebRTC | Deferred to Phase 3 | `flutter_webrtc 0.10.x` uses removed v1 plugin API; evaluate v1.x when building |
| Poll interval | Configurable `Duration` on `PairCubit` | Default 3s in production; 30ms in tests — avoids slow test suite |

---

## Testing Approach

- **Unit tests** for all BLoCs and Cubits using `bloc_test` + `mocktail`
- Sealed state types tested with `isA<>()` matchers (not concrete equality)
- Data assertions in `verify:` callbacks after state check
- `PairCubit` timer tests use `pollInterval: Duration(milliseconds: 30)` + `wait:`
- No real network calls in any test — all repositories are mocked

```
test/
├── features/
│   ├── connect/connect_cubit_test.dart   # 4 tests
│   ├── auth/pair_cubit_test.dart         # 5 tests
│   └── library/library_bloc_test.dart    # 5 tests
└── placeholder_test.dart
```
