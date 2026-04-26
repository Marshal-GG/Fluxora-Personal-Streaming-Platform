# Fluxora — Project Structure

## Top-Level Layout

```
Fluxora/
├── apps/           # All runnable applications
│   ├── server/     # Python FastAPI backend
│   ├── mobile/     # Flutter iOS + Android
│   └── desktop/    # Flutter Windows/macOS/Linux control panel
│
├── packages/       # Shared Dart code (imported by mobile + desktop)
│   └── fluxora_core/
│
├── docs/           # Architecture, planning, design docs
├── scripts/        # Build, release, CI scripts
│
├── CLAUDE.md
├── DESIGN.md
├── README.md
└── .github/        # GitHub Actions CI/CD
```

---

## `apps/server/` — Python FastAPI Backend

```
apps/server/
├── main.py
├── config.py
├── requirements.txt
├── requirements-dev.txt        # black, ruff, pytest
├── fluxora_server.spec         # PyInstaller
├── Dockerfile
├── README.md
├── database/
│   ├── db.py
│   └── migrations/
│       ├── 001_initial.sql
│       └── 002_sessions.sql
├── routers/
│   ├── auth.py
│   ├── files.py
│   ├── library.py
│   ├── stream.py
│   └── ws.py
├── services/
│   ├── ffmpeg_service.py
│   ├── library_service.py
│   ├── discovery_service.py
│   ├── auth_service.py
│   └── webrtc_service.py
├── models/
│   ├── media_file.py
│   ├── library.py
│   ├── client.py
│   ├── stream_session.py
│   └── settings.py
├── utils/
│   ├── file_utils.py
│   └── tmdb_client.py
└── tests/
    ├── conftest.py
    ├── test_auth.py
    ├── test_files.py
    ├── test_library.py
    └── test_stream.py
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
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── windows/
├── macos/
├── linux/
├── test/
└── lib/
    ├── main.dart
    ├── app.dart
    ├── core/
    │   ├── di/
    │   └── router/
    ├── features/
    │   ├── dashboard/
    │   │   └── presentation/
    │   ├── library/
    │   │   ├── data/
    │   │   ├── domain/
    │   │   └── presentation/
    │   ├── clients/
    │   │   ├── data/
    │   │   ├── domain/
    │   │   └── presentation/
    │   ├── activity/
    │   │   └── presentation/
    │   ├── transcoding/
    │   │   └── presentation/
    │   ├── logs/
    │   │   └── presentation/
    │   └── settings/
    │       └── presentation/
    └── shared/
        ├── widgets/
        │   ├── sidebar.dart
        │   ├── stat_card.dart
        │   ├── data_table.dart
        │   └── status_badge.dart
        └── theme/
            └── app_theme.dart
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
    │   ├── media_file.dart
    │   ├── library.dart
    │   ├── client.dart
    │   ├── stream_session.dart
    │   └── server_info.dart
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
| Each app has independent `pubspec.yaml` / `requirements.txt` | Dependency upgrades are isolated |
| CI workflows are path-filtered | A `server/` change never triggers Flutter CI |
| `shared/` inside each app = that app's local reusables | Not promoted to `fluxora_core/` unless needed by both apps |
