# Fluxora — Project Structure

## Top-Level Layout

```
Fluxora/
├── apps/           # All runnable applications
│   ├── server/     # Python FastAPI backend
│   ├── mobile/     # Flutter iOS + Android
│   ├── desktop/    # Flutter Windows/macOS/Linux control panel
│   └── web_landing/# Next.js marketing site (static export → CF Pages)
│
├── packages/       # Shared Dart code (imported by mobile + desktop)
│   └── fluxora_core/
│
├── assets/         # Brand & marketing asset masters (canonical)
│   ├── brand/      # Logo, wordmark, identity-sheet masters
│   ├── banners/    # README hero, dividers, GitHub social
│   ├── icons/      # Animated section icons used in README.md
│   └── screenshots/# Marketing screenshots (post-Desktop M3)
│
├── docs/           # Architecture, planning, design docs
├── scripts/        # Build, release, CI scripts
│
├── CLAUDE.md
├── DESIGN.md
├── README.md
└── .github/        # GitHub Actions CI/CD
```

> `assets/` is the canonical source of truth for brand. Runtime copies live at `packages/fluxora_core/assets/brand/` (Flutter), `apps/web_landing/public/brand/` (Next.js), and `apps/desktop/windows/runner/resources/app_icon.ico` (Windows runner) — all sized + alpha-processed derivatives, kept in sync manually. See [`assets/README.md`](../../assets/README.md) for the sync flow.

---

## `apps/server/` — Python FastAPI Backend

```
apps/server/
├── main.py
├── config.py
├── pyproject.toml
├── fluxora_server.spec         # PyInstaller
├── Dockerfile
├── README.md
├── database/
│   ├── db.py
│   └── migrations/
│       ├── 001_initial.sql     # media_files, libraries, clients, tmdb_id
│       ├── 002_sessions.sql    # stream_sessions
│       ├── 003_usage.sql       # usage_events
│       ├── 004_tmdb_metadata.sql  # title, overview, poster_url
│       ├── 005_progress.sql    # last_progress_sec
│       ├── 011_groups.sql      # groups, group_members, group_restrictions
│       ├── 012_profile_fields.sql  # display_name, email, avatar_path, profile_created_at, last_login_at on user_settings
│       ├── 013_notifications.sql   # notifications table + idx_notifications_unread
│       ├── 014_activity_events.sql # activity_events table + 2 indexes
│       └── 015_extended_settings.sql # 18 new columns on user_settings (general/network/streaming/security/advanced)
├── routers/
│   ├── auth.py
│   ├── activity.py             # GET /api/v1/activity; validate_token_or_local
│   ├── files.py
│   ├── groups.py
│   ├── library.py
│   ├── logs.py                 # GET /api/v1/logs; WS /api/v1/ws/logs; validate_token_or_local
│   ├── notifications.py        # GET, POST /{id}/read, POST /read-all, DELETE /{id}; WS /ws/notifications
│   ├── profile.py
│   ├── stream.py
│   ├── transcoding.py          # GET /api/v1/transcoding/status; require_local_caller
│   └── ws.py
├── services/
│   ├── activity_service.py     # record() + list_events(limit, since, type_prefix)
│   ├── ffmpeg_service.py
│   ├── group_service.py
│   ├── library_service.py
│   ├── discovery_service.py
│   ├── auth_service.py
│   ├── log_service.py          # parse JSON-line log; filter/paginate; pubsub for WS /ws/logs
│   ├── notification_service.py # CRUD + asyncio pub/sub fan-out
│   ├── profile_service.py
│   ├── tmdb_service.py
│   ├── transcoding_service.py  # encoder discovery + GPU probe; backs GET /transcoding/status
│   └── webrtc_service.py
├── models/
│   ├── activity.py             # ActivityEventResponse
│   ├── media_file.py           # MediaFileResponse (resume_sec alias)
│   ├── group.py
│   ├── library.py
│   ├── client.py
│   ├── log_record.py           # LogRecord, LogListResponse
│   ├── notification.py         # NotificationResponse, NotificationCreate, type/category enums
│   ├── profile.py              # ProfileResponse (avatar_letter computed), ProfileUpdate
│   ├── transcoding.py          # TranscodingStatusResponse, EncoderLoad, ActiveTranscodeSession
│   ├── stream_session.py
│   └── settings.py
├── utils/
│   ├── file_utils.py
│   └── tmdb_client.py
└── tests/
    ├── conftest.py
    ├── test_auth.py
    ├── test_files.py
    ├── test_groups.py
    ├── test_library.py
    ├── test_activity.py        # 12 tests — service CRUD, payload roundtrip, since/type filters, REST endpoints, emitter integration, off-loopback 401
    ├── test_notifications.py   # 12 tests — REST CRUD + WS fan-out + unread filter + dismiss
    ├── test_profile.py         # 9 tests — GET/PATCH profile + avatar_letter computation
    ├── test_stream.py
    ├── test_tmdb.py
    ├── test_transcoding.py     # 6 tests — encoder discovery, GPU probe, status shape, localhost restriction
    ├── test_logs.py            # 15 tests — JSON-line parse, filters, pagination, WS fan-out, auth
    └── test_settings_extended.py # 16 tests — PATCH + GET for 18 new settings fields, constraint enforcement
```

---

## `apps/mobile/` — Flutter iOS + Android

```
apps/mobile/
├── pubspec.yaml               # depends on packages/fluxora_core
├── analysis_options.yaml
├── README.md
├── android/
├── ios/
├── test/
└── lib/
    ├── main.dart
    ├── app.dart
    ├── core/
    │   ├── di/
    │   │   └── injector.dart
    │   └── router/
    │       └── app_router.dart
    ├── features/
    │   ├── connect/
    │   │   ├── data/
    │   │   ├── domain/
    │   │   └── presentation/
    │   ├── library/
    │   │   ├── data/
    │   │   ├── domain/
    │   │   └── presentation/
    │   ├── player/
    │   │   ├── data/
    │   │   ├── domain/
    │   │   └── presentation/
    │   └── settings/
    │       └── presentation/
    └── shared/
        ├── widgets/
        │   ├── media_card.dart
        │   ├── status_badge.dart
        │   └── loading_overlay.dart
        └── theme/
            └── app_theme.dart
```

---

## `apps/desktop/` — Flutter Control Panel (Windows/macOS/Linux)

```
apps/desktop/
├── pubspec.yaml          # window_manager 0.5.1, flutter_bloc, go_router 17, get_it 9, intl, file_picker, dio
├── analysis_options.yaml
├── README.md
├── windows/runner/       # C++ runner — frameless via TitleBarStyle.hidden + WNDCLASSEX (hIcon + hIconSm) + AppUserModelID
│   ├── main.cpp          # SetCurrentProcessExplicitAppUserModelID(L"Fluxora.Desktop") for Aero Peek
│   ├── win32_window.cpp  # WM_GETMINMAXINFO floor 1332×720; UpdateTheme; WNDCLASSEX with both icon variants
│   ├── Runner.rc         # ProductName/CompanyName/FileDescription = Fluxora; pulls version from pubspec
│   ├── CMakeLists.txt    # links dwmapi.lib + shell32.lib (AUMID)
│   └── resources/app_icon.ico  # ← runtime copy of assets/brand/app_icon.ico
├── macos/                # Not yet generated
├── linux/                # Not yet generated
├── test/
│   ├── features/         # Unit + bloc tests (38 passing)
│   └── goldens/          # M3 Dashboard golden — opt-in via --tags=golden, GetIt-mock recipe in _README.md
└── lib/
    ├── main.dart         # windowManager.ensureInitialized() + WindowOptions(titleBarStyle: hidden)
    ├── app.dart          # MaterialApp.router; title 'Fluxora'
    ├── core/
    │   ├── di/injector.dart  # GetIt registrations for every repo + cubit
    │   └── router/app_router.dart  # ShellRoute(builder: FluxShell) wraps every redesigned screen
    ├── features/         # 17 features: dashboard, library, clients, groups, activity, transcoding,
    │                     #   logs, settings, subscription, profile, notifications, help, storage,
    │                     #   recent_activity, system_stats, command_palette, orders
    └── shared/
        ├── widgets/      # V2 widgets only (legacy stat_card / status_badge / data_table deleted in M9)
        │   ├── flux_shell.dart      # Root layout — FluxTitlebar + sidebar + content + status bar
        │   ├── flux_titlebar.dart   # M10 — 36 px custom titlebar (drag region, help/bell, native Win 11 caption buttons)
        │   ├── flux_sidebar.dart    # 232 px nav rail (no logo header — moved to titlebar in M10)
        │   ├── flux_status_bar.dart # 28 px metric strip (CPU/RAM/NET/UP)
        │   ├── flux_button.dart     # M1 primitive — primary/secondary/ghost/danger × sm/md/lg
        │   ├── flux_card.dart       # M1 — glassmorphic surface
        │   ├── flux_progress.dart   # M1 — linear progress bar
        │   ├── flux_tab_bar.dart    # M4 — tab bar primitive
        │   ├── flux_text_field.dart # M6 form primitive
        │   ├── flux_select.dart     # M6 form primitive
        │   ├── flux_switch.dart     # M6 form primitive
        │   ├── flux_slider.dart     # M6 form primitive
        │   ├── page_header.dart     # M1 — title + subtitle + actions
        │   ├── pill.dart            # M1 — 7-color pill semantics
        │   ├── section_label.dart   # M1 — eyebrow caption
        │   ├── sparkline.dart       # M1 — micro line chart
        │   ├── stat_tile.dart       # M1 — icon + label + value tile
        │   ├── status_dot.dart      # M1 — colored status indicator
        │   └── storage_donut.dart   # M1 — donut breakdown chart
        ├── showcase/                # /showcase route — every primitive rendered (dev/QA tool)
        └── theme/app_theme.dart     # V2-pure (post-M9.5 cutover)
```

---

## `packages/fluxora_core/` — Shared Dart Code

> Imported by both `mobile/` and `desktop/` via local path dependency.  
> Contains ONLY code that is 100% shared — no platform-specific Flutter widgets.

```
packages/fluxora_core/
├── pubspec.yaml
├── README.md
└── lib/
    ├── fluxora_core.dart       # Barrel export
    ├── entities/
    │   ├── activity_event.dart         # M3: ActivityEvent (id, type, summary, createdAt …)
    │   ├── client.dart
    │   ├── client_list_item.dart
    │   ├── enums.dart
    │   ├── library.dart
    │   ├── library_storage_breakdown.dart  # M3: LibraryStorageBreakdown + StorageByType
    │   ├── media_file.dart
    │   ├── server_info.dart
    │   ├── stream_session.dart
    │   └── system_stats.dart
    ├── network/
    │   ├── api_client.dart     # Dio singleton + interceptors
    │   ├── endpoints.dart      # All API URL constants
    │   └── api_exception.dart
    ├── storage/
    │   └── secure_storage.dart # flutter_secure_storage wrapper
    └── constants/
        ├── app_colors.dart     # Design tokens from DESIGN.md
        ├── app_typography.dart
        └── app_sizes.dart
```

---

## `scripts/` — Build & Release

```
scripts/
├── build_server.ps1            # Windows: PyInstaller .exe
├── build_server.sh             # Linux/macOS: PyInstaller binary
├── build_mobile.sh             # Flutter: APK + IPA
├── build_desktop.sh            # Flutter: Win/macOS/Linux
└── release.sh                  # Tag version + GitHub Release
```

---

## `.github/` — CI/CD (Path-Scoped)

```
.github/
└── workflows/
    ├── server_ci.yml           # Triggers on: apps/server/** changes only
    ├── mobile_ci.yml           # Triggers on: apps/mobile/** changes only
    └── desktop_ci.yml          # Triggers on: apps/desktop/** changes only
```

---

## Scalability Rules

| Rule | Why |
|------|-----|
| Features are **feature-first** inside each app | Adding a screen never touches other features |
| All shared Dart code in `packages/fluxora_core/` | Single source of truth for entities, API client, tokens |
| `apps/server/` is pure Python | Can move to its own repo later with zero refactoring |
| Each app has independent `pubspec.yaml` / `pyproject.toml` | Dependency upgrades are isolated |
| CI workflows are path-filtered | A `server/` change never triggers Flutter CI |
| `shared/` inside each app = that app's local reusables | Not promoted to `fluxora_core/` unless needed by both apps |
