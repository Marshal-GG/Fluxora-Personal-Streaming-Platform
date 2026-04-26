# Infrastructure, Deployment & CI/CD

> **Category:** Infrastructure  
> **Status:** ✅ Complete  
> **Last Updated:** 2026-04-27

---

## Overview

Fluxora is **self-hosted on the user's PC** — not a cloud service. There is no central server,
no user accounts in the cloud, and no mandatory internet connectivity. The server is a standalone
binary that runs on the user's machine and is managed via the Flutter desktop control panel.

---

## Hosting Model

| Component | Location | Notes |
|-----------|----------|-------|
| FastAPI Server | User's PC | Windows / macOS / Linux |
| SQLite Database | `~/.fluxora/fluxora.db` | Embedded, WAL mode |
| HLS Temp Segments | `~/.fluxora/hls/` | Cleaned after stream ends |
| Config File | `~/.fluxora/config.json` | Editable from Control Panel |
| Flutter Mobile Client | Android / iOS device | Downloaded from app store |
| Flutter Desktop Control Panel | User's PC | Installed alongside server |

---

## Server Distribution

The FastAPI server is packaged as a **standalone executable** via PyInstaller:

| Target | Output | Notes |
|--------|--------|-------|
| Windows | `fluxora_server.exe` | Single-file bundle |
| macOS | `fluxora_server` (binary) | Code-signed for Gatekeeper |
| Linux | `fluxora_server` (binary) | AppImage planned |

**Bundle includes:**
- Python runtime
- FastAPI + Uvicorn
- All pip dependencies (`requirements.txt`)
- FFmpeg binary (bundled, not system FFmpeg)
- SQLite (bundled via Python stdlib)

**Build command:**
```bash
# Windows
pyinstaller apps/server/fluxora_server.spec

# Linux / macOS
bash scripts/build_server.sh
```

**Spec file:** `apps/server/fluxora_server.spec`

---

## Flutter Client Distribution

| Platform | Channel | Notes |
|----------|---------|-------|
| Android | Google Play Store | Signed release APK/AAB |
| iOS | Apple App Store | Signed IPA, TestFlight for beta |
| Windows (Control Panel) | GitHub Releases | Bundled `.exe` installer |
| macOS (Control Panel) | GitHub Releases | `.dmg` disk image |
| Linux (Control Panel) | GitHub Releases | AppImage |

---

## Server Startup Sequence

```
1. User launches Fluxora Server (via Control Panel or CLI)
2. Server reads config from ~/.fluxora/config.json
3. DB migration check → apply any pending migrations
4. Start mDNS broadcast  (_fluxora._tcp.local, port 8000)
5. Start Uvicorn on 0.0.0.0:{FLUXORA_PORT}  (default: 8000)
6. Control Panel connects via localhost
7. Server is ready — mDNS visible on LAN, HTTP API active
```

---

## Environment Variables / Config

All settings can be overridden via environment variable or `~/.fluxora/config.json`.
Server reads config using **Pydantic `BaseSettings`** (`apps/server/config.py`).

| Setting | Default | Description |
|---------|---------|-------------|
| `FLUXORA_PORT` | `8000` | HTTP server port |
| `FLUXORA_HOST` | `0.0.0.0` | Bind address |
| `FLUXORA_DB_PATH` | `~/.fluxora/fluxora.db` | SQLite database path |
| `FLUXORA_HLS_TMP` | `~/.fluxora/hls/` | HLS segment temp directory |
| `FLUXORA_LOG_LEVEL` | `INFO` | Logging verbosity |
| `FLUXORA_LIBRARY_ROOTS` | `[]` | Allowed media directories |
| `FLUXORA_MAX_STREAMS` | `3` | Max concurrent transcodes |
| `FLUXORA_TMDB_KEY` | `""` | Optional TMDB API key |
| `FLUXORA_TURN_URL` | `""` | TURN server URL (Phase 3) |
| `FLUXORA_TURN_USER` | `""` | TURN username (Phase 3) |
| `FLUXORA_TURN_PASS` | `""` | TURN password (Phase 3) |

---

## CI/CD Pipeline

GitHub Actions is used for all automated builds. Workflows are **path-scoped** to avoid
unnecessary builds (e.g., a Python change does not trigger a Flutter build).

### Workflow Files

| File | Trigger | What it does |
|------|---------|-------------|
| `.github/workflows/server_ci.yml` | Push to `apps/server/**` | Python tests → server CI checks |
| `.github/workflows/mobile_ci.yml` | Push to `apps/mobile/**` or `packages/**` | Flutter tests → APK checks |
| `.github/workflows/desktop_ci.yml` | Push to `apps/desktop/**` or `packages/**` | Flutter tests → desktop checks |
| `.github/workflows/mirror-public.yml` | Push to `main` | Safely mirrors private repository to a public mirror, stripping internal files |

*Note: All GitHub Actions are configured to use modern Node 24 native versions (e.g. `actions/checkout@v5` and `flutter-actions/setup-flutter@v4`).*

### Pipeline Flow (Release)

```
[git tag v1.0.0  →  push]
        │
        └──▶ GitHub Actions: release.yml
                ├── Python tests (pytest)
                ├── Flutter tests (mobile + desktop)
                ├── PyInstaller → server binary (win/mac/linux)
                ├── Flutter build → APK + AAB (Android)
                ├── Flutter build → desktop (Win/Mac/Linux)
                └── GitHub Release
                        ├── fluxora_server_win.exe
                        ├── fluxora_server_mac
                        ├── fluxora_server_linux
                        ├── fluxora_desktop_win.exe
                        └── fluxora_desktop_mac.dmg
```

### Development Environment

| Task | Command |
|------|---------|
| Run server (dev) | `uvicorn main:app --reload --app-dir apps/server` |
| Run mobile (dev) | `flutter run` (from `apps/mobile/`) |
| Run desktop (dev) | `flutter run -d windows` (from `apps/desktop/`) |
| Run Python tests | `pytest apps/server/tests/` |
| Run Flutter tests | `flutter test` (from each app dir) |

---

## Scaling Strategy

| Phase | Approach |
|-------|---------|
| Phase 1–4 | Single-server, single-owner; SQLite WAL mode for concurrent reads |
| Phase 5 | Evaluate PostgreSQL if multi-library / family sharing added |

Concurrency is controlled by `FLUXORA_MAX_STREAMS` — the server rejects additional
transcode requests above the limit (returns `429 Too Many Requests`).

---

## Monitoring & Observability

| Tool | Scope | Notes |
|------|-------|-------|
| Python `logging` (structured) | Server | Log to stdout + optional file |
| Flutter `dart:developer` | Mobile/Desktop clients | Debug mode only |
| Control Panel dashboard | Real-time | Active sessions, CPU, disk |
| Phase 5: Sentry | Client crash reports | Optional, user opt-in |
| Phase 5: Crashlytics | iOS/Android crashes | Optional, user opt-in |

---

## Backup & Recovery

- Database: `~/.fluxora/fluxora.db` — user is responsible for backup
- Config: `~/.fluxora/config.json` — exported/imported via Control Panel
- Media files: source files stay in user's own directories; Fluxora does not move them
- HLS temp segments: ephemeral, deleted after stream session ends
