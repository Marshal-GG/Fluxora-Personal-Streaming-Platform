# Fluxora — CLAUDE.md

> This file provides essential context for AI coding agents (Claude, Gemini, Copilot, etc.) working
> on the Fluxora codebase. Read this file fully before making any code changes.

---

## Table of Contents

1. [Mandatory Agent Rules](#mandatory-agent-rules)
2. [Hard Prohibitions](#hard-prohibitions)
3. [Documentation Update Protocol](#documentation-update-protocol)
4. [What is Fluxora?](#what-is-fluxora)
5. [Repository Layout](#repository-layout)
6. [Tech Stack](#tech-stack)
7. [Architecture: Core Concepts](#architecture-core-concepts)
8. [Architecture Rules — Never Break These](#architecture-rules)
9. [Database](#database)
10. [Database Migration Rules](#database-migration-rules)
11. [API Overview](#api-overview)
12. [Development Commands](#development-commands)
13. [Code Conventions](#code-conventions)
14. [Testing Discipline](#testing-discipline)
15. [Security Rules](#security-rules)
16. [Resource Cleanup Rules](#resource-cleanup-rules)
17. [Before You Are Done — Checklist](#before-you-are-done)
18. [Dependency Version Policy](#dependency-version-policy)
19. [API Key & Secrets Management](#api-key--secrets-management)
20. [Server Startup Initialization Order](#server-startup-initialization-order)
21. [Code Generation Policy](#code-generation-policy)
22. [WebSocket Rules](#websocket-rules)
23. [Firebase Integration Rules](#firebase-integration-rules)
24. [Rate Limiting](#rate-limiting)
25. [Offline Detection & Connectivity](#offline-detection--connectivity)
26. [PR / Code Review Checklist](#pr--code-review-checklist)
27. [Key Files to Read Before Specific Tasks](#key-files-to-read)
28. [Design System Reference](#design-system-reference)
29. [Phase Roadmap](#phase-roadmap)
30. [Known Risks & Gotchas](#known-risks--gotchas)
31. [Out of Scope (v1)](#out-of-scope-v1)
32. [Current Status](#current-status)

---

## Mandatory Agent Rules

> **Before writing a single line of code:**
> 1. Read `AGENT_LOG.md` — understand what has been done and what comes next.
> 2. Read the relevant `docs/` files for the area you are working in.
>
> **While writing code:**
> - If you change an API contract → update `docs/04_api/01_api_contracts.md`
> - If you change data models or the DB schema → update `docs/03_data/`
> - If you change the backend structure → update `docs/09_backend/01_backend_architecture.md`
> - If you change Flutter screens or navigation → update `docs/08_frontend/01_frontend_architecture.md`
> - If you change the tech stack or system design → update `docs/02_architecture/`
> - If you add/complete a roadmap milestone → update `docs/10_planning/01_roadmap.md`
> - If you add or change a UI component or design token → update `DESIGN.md`
> - If you add, remove, or modify any `.github/workflows/` file → update `docs/05_infrastructure/01_infrastructure.md`
>
> **Rule: code and docs must always be in sync. Never leave docs stale.**
>
> **Before ending your session:**
> 1. Append a new entry to `AGENT_LOG.md` using the template at the top of that file.
> 2. List every file you created or modified (code **and** docs) in the entry's table.
> 3. List every `docs/` file you updated in the "Docs Updated" section of the log entry.
> 4. Write a clear "Next Agent Should" section so the next agent can resume without reading chat history.
>
> **AGENT_LOG.md is append-only. Never edit or delete past entries.**
> **Log Rotation Policy:** If `AGENT_LOG.md` exceeds ~1000 lines, you MUST rotate it: move it to `docs/logs/AGENT_LOG_archive_XX.md`, read the archived log to summarize its progress and next steps, and start a fresh `AGENT_LOG.md` with the summary at the top and the entry template.


---

## Documentation Update Protocol

> **When the user asks you to update docs — or when any code change requires a doc update — follow this protocol in full. Never stop after updating just the obvious file.**

### Step 1 — Identify every file that could be affected

Before writing a single word, run a mental (or literal `grep`) sweep against this checklist:

| File | Update when... |
|------|---------------|
| `docs/04_api/01_api_contracts.md` | Any endpoint added, removed, renamed, or response schema changed |
| `docs/03_data/01_data_models.md` | Any entity field added, removed, or renamed |
| `docs/03_data/02_database_schema.md` | Any table or column added, removed, or altered |
| `docs/03_data/03_data_flows.md` | Any data flow between layers changed |
| `docs/02_architecture/01_system_overview.md` | Any system-level design decision changed |
| `docs/02_architecture/02_tech_stack.md` | Any technology added, removed, or swapped |
| `docs/02_architecture/03_component_architecture.md` | Any component boundary or responsibility changed |
| `docs/09_backend/01_backend_architecture.md` | Any backend structure, service, or pattern changed |
| `docs/08_frontend/01_frontend_architecture.md` | Any Flutter screen, navigation, or pattern changed |
| `docs/05_infrastructure/01_infrastructure.md` | Any CI workflow, build process, or distribution method changed |
| `docs/06_security/01_security.md` | Any auth flow, threat model, or security control changed |
| `docs/10_planning/01_roadmap.md` | Any milestone started, completed, or descoped |
| `docs/10_planning/02_decisions.md` | Any architectural decision locked in |
| `docs/10_planning/03_open_questions.md` | Any open question answered or added |
| `docs/00_overview/README.md` | Status column of any doc changes; new doc added |
| `DESIGN.md` | Any color, spacing, typography, or component spec changed |
| `README.md` | Project-level summary, structure, or setup steps changed |
| `CLAUDE.md` | Tech stack, repo layout, phase status, or any rule changes |
| `AGENT_LOG.md` | Every session — always append an entry |

### Step 2 — Cross-reference sweep

After identifying the files, **grep across all `.md` files** for the thing you changed:
- Renamed a field? Search for the old name — it may appear in 4 different docs.
- Changed an endpoint path? Search for the old path string everywhere.
- Changed a folder name? Search for the old path in every doc.
- Changed a tech decision? Search for the old technology name.

Never assume a term only appears in one place.

### Step 3 — CLAUDE.md self-check

CLAUDE.md has sections that silently go stale. After any doc update, verify these sections are still accurate:

| CLAUDE.md section | Goes stale when... |
|-------------------|--------------------|
| Repository Layout | Folders added, renamed, or removed |
| Tech Stack tables | Any dependency added, swapped, or removed |
| Architecture Rules | Layer responsibilities change |
| Development Commands | Paths, commands, or scripts change |
| Phase Roadmap | Any phase or milestone status changes |
| Current Status | Any significant progress is made |
| Known Risks & Gotchas | A risk is mitigated or a new one discovered |

### Step 4 — Consistency checks

- All code examples in docs must use the **real current paths and API shapes** — not hypothetical ones.
- All cross-links between docs must resolve (no broken `[see X](../Y/Z.md)` links).
- All table columns must be complete — no empty cells unless the column is optional by design.
- All milestone statuses in `docs/10_planning/01_roadmap.md` must match the "Phase Roadmap" table in `CLAUDE.md`.
- All doc statuses in `docs/00_overview/README.md` must match the actual content state of each file.

### Step 5 — Completion declaration

Only declare the doc update complete when:
- [ ] Every file in Step 1 that is affected has been updated
- [ ] The cross-reference sweep in Step 2 found no stale references
- [ ] The CLAUDE.md self-check in Step 3 passed
- [ ] The consistency checks in Step 4 passed
- [ ] The AGENT_LOG.md entry lists every doc file touched
---

## Hard Prohibitions

| # | Rule |
|---|------|
| 1 | **Never run `git commit`, `git push`, or any git write command.** All version control is the owner's responsibility. You may read git state (`git status`, `git log`, `git diff`) but must never write to it. |
| 2 | **Never add agent branding anywhere.** No comments, docstrings, README badges, footer text, or any other content that names, credits, or promotes an AI model (e.g. "Generated by Claude", "Built with Gemini", "AI-assisted"). Code must read as if a human wrote it. |
| 3 | **Never use `print()` in Python or `print()`/`debugPrint()` in Dart.** Use the project logger in every file. Silent output is invisible in production and unrecoverable once deployed. |
| 4 | **Never swallow exceptions silently.** No bare `except: pass` in Python, no empty `catch (_) {}` in Dart. Always log the error with full context and either rethrow or handle explicitly. |
| 5 | **Never hardcode secrets, credentials, ports, or file paths.** All config lives in `config.py` via `BaseSettings` (Python) or is injected via the DI layer (Dart). No magic strings or numbers outside of config/constants files. |
| 6 | **Never add a new pub/pip dependency without justification.** Check if an existing dependency already covers the need. Every new dep is a maintenance burden and a supply chain risk. |
| 7 | **Never break Clean Architecture layer boundaries.** A layer violation that compiles is still a bug. See the Architecture Rules section. |
| 8 | **Never log tokens, passwords, or any PII.** Scrub sensitive fields before logging. If a log line could expose a bearer token or user path, it must not be written. |
| 9 | **Never edit or delete a past database migration file.** Migrations are append-only. See Database Migration Rules. |
| 10 | **Never use string concatenation to build SQL queries.** Always use parameterized queries to prevent SQL injection. |
| 11 | **Never commit API keys, Firebase config files, or any secret to the repo.** `google-services.json`, `GoogleService-Info.plist`, `.env`, and `config.json` (dart-define) are gitignored and provided at build time only. See API Key & Secrets Management section. |
| 12 | **Never use a package version without first checking if a newer version exists.** Before adding or updating any pip/pub/npm/GitHub Action dependency, look up the current latest release. Do not pin to a version you found in training data — it is likely outdated. |
| 13 | **Never store bearer tokens as plaintext or reversibly encrypted in the database.** Bearer tokens must be stored as HMAC-SHA256 hashes — they are high-entropy random strings, so hashing is sufficient and irreversible if the DB leaks. Other secrets (API keys) use Fernet encryption. See Database Security section. |

---

## What is Fluxora?

Fluxora is a **self-hosted hybrid media streaming system** — think "Plex meets Syncthing."
It lets users stream their personal media library (movies, TV, music, documents) to any device,
automatically switching between LAN (fast, direct) and Internet (WebRTC/STUN/TURN) connections
without user intervention.

The system consists of:
1. **Server** — A Python/FastAPI backend that runs on the user's home machine, transcodes media via FFmpeg, and broadcasts itself on the LAN via mDNS.
2. **Mobile Client** — A Flutter app (iOS + Android) that discovers the server, pairs with it, and streams media.
3. **Desktop Control Panel** — A Flutter desktop app (Windows/macOS/Linux) for managing libraries, clients, and server settings.
4. **Shared Core** — A Flutter package (`packages/fluxora_core`) containing shared entities, network client, design tokens, and secure storage used by both Flutter apps.

**Key constraint:** Core streaming must work with zero cloud dependency — LAN streaming never touches Firebase. Firebase is used only for Phase 3+ features (WebRTC signaling, push notifications, subscriptions) and degrades gracefully when absent. The server is distributed as a standalone executable (PyInstaller). No Docker, no external DB, no mandatory account for Phase 1-2.

---

## Repository Layout

```
Fluxora/
├── CLAUDE.md                  <- You are here
├── DESIGN.md                  <- Full visual design system (read before any UI work)
├── AGENT_LOG.md               <- Append-only session log (read before starting work)
├── README.md                  <- Project overview and doc index
│
├── apps/
│   ├── server/                <- Python FastAPI backend
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── pyproject.toml     <- single source of truth for Python deps + tool config
│   │   ├── env.example        <- documents expected ~/.fluxora/.env keys
│   │   ├── fluxora_server.spec
│   │   ├── routers/           <- auth, files, library, stream, ws
│   │   ├── services/          <- ffmpeg, library, discovery, auth, webrtc
│   │   ├── models/            <- Pydantic schemas
│   │   ├── database/          <- db.py + migrations/
│   │   ├── utils/
│   │   └── tests/
│   │
│   ├── mobile/                <- Flutter mobile client (Android + iOS)
│   │   ├── lib/
│   │   │   ├── core/          <- DI, router
│   │   │   ├── features/      <- connect, library, player, settings
│   │   │   └── shared/        <- widgets, theme
│   │   ├── analysis_options.yaml
│   │   └── pubspec.yaml
│   │
│   ├── desktop/               <- Flutter desktop control panel (Windows/macOS/Linux)
│   │   ├── lib/
│   │   │   ├── core/          <- DI, router
│   │   │   ├── features/      <- dashboard, library, clients, activity, transcoding, logs, settings
│   │   │   └── shared/        <- widgets, theme
│   │   ├── analysis_options.yaml
│   │   └── pubspec.yaml
│   │
│   ├── web_landing/           <- Next.js public landing page (fluxora.marshalx.dev)
│   │   ├── src/app/           <- Next.js App Router pages + globals.css
│   │   ├── src/components/    <- Navbar, Hero, Features, HowItWorks, Platforms, Footer
│   │   ├── next.config.ts     <- static export for Cloudflare Pages
│   │   └── package.json
│   │
│   └── web_app/               <- Flutter Web dashboard (Phase 3 — not started)
│       └── (mirrors desktop feature set, accessible via browser)
│
├── packages/
│   └── fluxora_core/          <- Shared Flutter package (entities, ApiClient, tokens, storage)
│       ├── lib/
│       │   ├── entities/
│       │   ├── network/
│       │   ├── storage/
│       │   └── constants/
│       ├── analysis_options.yaml
│       └── pubspec.yaml
│
├── docs/                      <- All planning and architecture documentation
│   ├── 00_overview/           <- Project summary, folder structure
│   ├── 01_product/            <- Vision, requirements, user stories
│   ├── 02_architecture/       <- System overview, tech stack, component architecture
│   ├── 03_data/               <- Data models, SQLite schema, data flows
│   ├── 04_api/                <- REST + WebSocket API contracts
│   ├── 05_infrastructure/     <- CI/CD, hosting, distribution
│   ├── 06_security/           <- Auth model, threat model, encryption
│   ├── 07_ai_ml/              <- AI/ML architecture (Phase 5)
│   ├── 08_frontend/           <- Flutter architecture
│   ├── 09_backend/            <- FastAPI architecture
│   ├── 10_planning/           <- Roadmap, decisions, open questions
│   └── 11_design/             <- Design reference HTML + brand README
│
├── firebase.json              <- Firebase project config (Cloud Functions)
├── .firebaserc                <- Firebase project alias (update with real project ID)
├── functions/                 <- Firebase Cloud Functions (Phase 3 stubs)
│   ├── src/index.ts           <- health check + Phase 3 stub exports
│   ├── package.json
│   └── tsconfig.json
│
├── scripts/                   <- Build and release automation
└── .github/workflows/         <- Path-scoped CI (server / mobile / desktop / web / mirror)
```

---

## Tech Stack

### Backend (Server)

| Layer | Technology | Notes |
|-------|-----------|-------|
| Language | Python 3.11+ | Required minimum version |
| Framework | FastAPI | Async; use `async def` for all route handlers |
| ASGI Server | Uvicorn | Dev: `uvicorn main:app --reload` |
| Streaming | FFmpeg → HLS | Spawned as subprocess; never import FFmpeg as a library |
| Database | SQLite + `aiosqlite` | Local-only; WAL mode enabled; async queries only |
| LAN Discovery | `zeroconf` (Python) | Broadcasts `_fluxora._tcp.local` service |
| Internet | `aiortc` or WebSocket signaling | STUN: `stun.l.google.com:19302` |
| Metadata | TMDB REST API | User-provided API key; gracefully degrade if absent |
| Distribution | PyInstaller | Single-file `.exe` / binary; no external Python install required |
| Cloud (Phase 3+) | Firebase Cloud Functions (Node.js) | WebRTC signaling relay, subscription webhooks, push notifications; gracefully absent in Phase 1-2 |

### Frontend (Mobile + Desktop apps)

| Layer | Technology | Notes |
|-------|-----------|-------|
| Language | Dart 3+ | Null-safe; use `late` and `required` properly |
| Framework | Flutter 3.x | Separate `apps/mobile` and `apps/desktop`; shared code in `packages/fluxora_core` |
| Architecture | Clean Architecture | `domain/` → `data/` → `presentation/` strictly enforced in each app |
| State | BLoC or Riverpod | Pick one per feature; do not mix patterns within a feature |
| HTTP | `dio` (via `fluxora_core`) | All HTTP calls through the single `ApiClient` instance |
| LAN Discovery | Dart `multicast_dns` | Scan for `_fluxora._tcp.local` |
| WebRTC | `flutter_webrtc` (v1.x+) | Internet streaming only — Phase 3; v0.10.x uses removed v1 Flutter plugin API; do not add until Phase 3 |
| Storage | `flutter_secure_storage` (via `fluxora_core`) | Bearer token storage; never `shared_preferences` for secrets |
| File paths | `path_provider` | All file/directory paths go through this — never hardcode platform paths |
| Video | `media_kit` ^1.2.6 + `media_kit_video` ^2.0.1 + `media_kit_libs_video` ^1.0.7 | HLS `.m3u8` playback (mobile); `better_player` dropped (AGP 8+ incompatible) |
| Cloud (Phase 3+) | Firebase SDK (`firebase_core`, `firebase_messaging`, `cloud_firestore`) | Push notifications, crash reporting (Crashlytics), remote config; feature-flagged — never block core streaming |
| Web (landing) | Next.js 16 + TypeScript | Static export → Firebase Hosting; hosted at `fluxora.marshalx.dev` |
| Web (dashboard, Phase 3+) | Flutter Web (`apps/web_app`) | Browser-accessible control panel; shares code with `apps/desktop` |

---

## Architecture: Core Concepts

### Hybrid Network Auto-Switch

This is the central innovation of Fluxora. The client MUST:
1. First attempt mDNS discovery on the local network.
2. If mDNS resolves → connect directly via LAN HTTP. **Never** use WebRTC on LAN.
3. If mDNS fails → fall back to WebRTC (STUN → TURN).
4. Continuously monitor connection quality; switch seamlessly if the network changes.

**Never** make the user manually select LAN vs Internet. The switch must be invisible.

### Streaming Pipeline

```
File on disk
  → FFmpeg (subprocess) transcodes to HLS
  → .m3u8 playlist + .ts segments saved to /tmp/fluxora/{session_id}/
  → FastAPI serves segments via GET /hls/{session_id}/{segment}
  → Client's video player reads the .m3u8 and fetches segments
```

- Segments are **deleted after stream ends** — no persistent cache.
- Default: H.264 video + AAC audio. Hardware encoding is Phase 5.
- HLS segment duration: 6 seconds.

### Authentication Model

- **Local-first, manual pairing.** No passwords, no email.
- New client → sends pairing request → user approves on control panel → server issues a bearer token.
- Token stored securely on client device. Validated on every API request.
- Token lifetime: indefinite until manually revoked.
- No user accounts, no OAuth, no cloud auth provider.

---

## Architecture Rules

### Python Backend Layer Rules

Import direction is strictly one-way:

```
routers/ → services/ → database/
                  ↘
               models/   utils/
```

| Layer | Must contain | Must NOT do |
|-------|-------------|-------------|
| `routers/` | Route handlers, request/response validation | Business logic; direct DB queries |
| `services/` | All business logic, orchestration, FFmpeg, mDNS | Import FastAPI; raise `HTTPException` |
| `models/` | Pydantic request/response schemas | DB queries; business logic |
| `database/` | aiosqlite queries, migrations, connection pool | Import from `services/` or `routers/` |
| `utils/` | Stateless pure helper functions | Import from any other layer |

> **Rule:** Services raise plain Python exceptions. Routers catch and convert to `HTTPException`. The word `HTTPException` must never appear in a service file.

### Dart/Flutter Layer Rules

Import direction is strictly one-way:

```
presentation/ → domain/ ← data/
```

| Layer | Must contain | Must NOT do |
|-------|-------------|-------------|
| `domain/` | Entities, repository interfaces, use cases | Import Flutter SDK; import `data/` or `presentation/` |
| `data/` | Repository implementations, `ApiClient` calls, local storage | Import `presentation/`; contain UI or business logic |
| `presentation/` | Widgets, BLoC/Riverpod states/events, navigation | Import `data/` directly; call `dio` or storage directly |
| `packages/fluxora_core` | Shared entities, `ApiClient`, design tokens, `SecureStorage` | Feature-specific business logic |

**Before adding any import, ask:**
- Is `presentation/` importing from `data/`? → Go through a domain use case instead.
- Is `domain/` importing Flutter? → Domain is pure Dart; remove it.
- Is a router doing DB queries? → Move to a service.
- Is a service raising `HTTPException`? → Raise a plain exception; let the router convert it.
- Is a widget calling `ApiClient` directly? → Wrong layer; go through a repository use case.

---

## Database

- **Engine:** SQLite with WAL mode (`PRAGMA journal_mode=WAL`).
- **Driver:** `aiosqlite` for all async access.
- **Location:** `~/.fluxora/fluxora.db` (user home directory).
- **Migrations:** Plain `.sql` files in `apps/server/database/migrations/`, run in order at startup.

### Core Tables

| Table | Purpose |
|-------|---------|
| `media_files` | Indexed media files with metadata |
| `libraries` | Named library → directory path mappings |
| `stream_sessions` | Active and historical streaming sessions |
| `clients` | Paired client devices and their tokens |
| `user_settings` | Key-value store for server configuration |

Full DDL: `docs/03_data/02_database_schema.md`

### Database Security

The local database must be inaccessible to any process other than the Fluxora server. Apply these rules on every platform:

**Directory and file permissions**

```python
import os, stat, platform
from pathlib import Path

def get_db_dir() -> Path:
    """Returns the platform-correct data directory, created with owner-only permissions."""
    system = platform.system()
    if system == "Windows":
        base = Path(os.environ["APPDATA"]) / "Fluxora"
    elif system == "Darwin":
        base = Path.home() / "Library" / "Application Support" / "Fluxora"
    else:
        base = Path.home() / ".fluxora"

    if not base.exists():
        base.mkdir(parents=True)
        if system != "Windows":
            os.chmod(base, stat.S_IRWXU)  # 700 — owner only
    return base

def secure_db_file(db_path: Path) -> None:
    """Restrict read/write on the DB and its WAL/SHM sidecar files to owner only."""
    if platform.system() != "Windows":
        for suffix in ["", "-wal", "-shm"]:
            p = Path(str(db_path) + suffix)
            if p.exists():
                os.chmod(p, stat.S_IRUSR | stat.S_IWUSR)  # 600
```

Call `secure_db_file()` once after the DB connection is opened at startup.

On Windows, use `icacls` to restrict the directory to the current user only (does not require `pywin32`):

```python
import subprocess, os, platform

def restrict_windows_path(path: str) -> None:
    """Remove inherited permissions and grant full control to current user only."""
    if platform.system() == "Windows":
        username = os.environ.get("USERNAME", "")
        subprocess.run(
            ["icacls", path, "/inheritance:r", "/grant:r", f"{username}:(OI)(CI)F"],
            capture_output=True, check=False
        )
```

Call `restrict_windows_path(str(base))` immediately after creating the `~\AppData\Roaming\Fluxora\` directory.

**Token hashing (bearer tokens)**

Bearer tokens are high-entropy random strings. Store a hash — never the raw token, never reversible encryption. If the DB leaks, hashes cannot be reversed.

```python
import hashlib
import hmac
import secrets

def generate_token() -> str:
    """Generate a cryptographically secure bearer token."""
    return secrets.token_urlsafe(32)

def hash_token(token: str, secret_key: str) -> str:
    """HMAC-SHA256 hash of the token. Store this in the DB."""
    return hmac.new(secret_key.encode(), token.encode(), hashlib.sha256).hexdigest()

def verify_token(provided_token: str, stored_hash: str, secret_key: str) -> bool:
    """Constant-time comparison — prevents timing attacks."""
    expected = hash_token(provided_token, secret_key)
    return hmac.compare_digest(expected, stored_hash)
```

`secret_key` comes from `config.py` via `BaseSettings` (env var `TOKEN_HMAC_KEY`). Generate it once with `secrets.token_hex(32)` and store in `~/.fluxora/.env`.

**Fernet encryption for other secrets (API keys)**

For reversible secrets that must be read back (e.g. TMDB key stored in `user_settings`):

```python
from cryptography.fernet import Fernet
import keyring

_KEY_SERVICE = "fluxora"
_KEY_ACCOUNT = "db-encryption-key"

def _get_fernet() -> Fernet:
    key = keyring.get_password(_KEY_SERVICE, _KEY_ACCOUNT)
    if key is None:
        key = Fernet.generate_key().decode()
        keyring.set_password(_KEY_SERVICE, _KEY_ACCOUNT, key)
    return Fernet(key.encode())

def encrypt_field(value: str) -> str:
    return _get_fernet().encrypt(value.encode()).decode()

def decrypt_field(value: str) -> str:
    return _get_fernet().decrypt(value.encode()).decode()
```

**Rules:**
- `clients.token` column stores the **HMAC hash**, never the raw token.
- `user_settings` rows storing API keys use `encrypt_field()` / `decrypt_field()`.
- The Fernet key lives in the OS keychain (`keyring`) — never in a file, env var, or `config.py`.
- Add `keyring`, `cryptography`, and `argon2-cffi` to `pyproject.toml`.
- Never log raw tokens, decrypted values, or the encryption key.
- The WAL file (`fluxora.db-wal`) and SHM file (`fluxora.db-shm`) are part of the database — apply `secure_db_file()` to them too.


### Flutter/Dart Storage Security

Flutter's security model differs per platform — mobile is OS-sandboxed, desktop is not. Rules must cover both.

**Mobile (Android / iOS) — OS sandbox applies**

The app's private directory (`getApplicationSupportDirectory()`) is inaccessible to other apps by default — no extra permissions needed. Rules:

- Always store files via `path_provider` — never hardcode paths or write to shared/external storage.
- `flutter_secure_storage` is the only permitted storage for secrets (bearer token, any API key). Never `shared_preferences`, `Hive` boxes, or plain file writes for secrets.
- Never request external storage permissions (`READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`) unless a feature explicitly requires it — and even then, never write secrets there.

**Desktop (Windows / macOS / Linux) — NOT sandboxed**

Flutter desktop apps run with the same filesystem access as the user. Apply the same directory hardening as the server:

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> getSecureAppDir() async {
  final base = await getApplicationSupportDirectory();
  // base is already platform-correct:
  //   Windows: %APPDATA%\fluxora_desktop\
  //   macOS:   ~/Library/Application Support/fluxora_desktop/
  //   Linux:   ~/.local/share/fluxora_desktop/

  if (!Platform.isWindows) {
    // Restrict to owner read/write/execute only (700)
    await Process.run('chmod', ['700', base.path]);
  }
  return base;
}

Future<void> secureFile(File file) async {
  if (!Platform.isWindows) {
    await Process.run('chmod', ['600', file.path]);
  }
}
```

Call `secureFile()` on any file written by the desktop app that contains sensitive data.

**If a local SQLite database is added to any Flutter app (Phase 2+)**

- Use `sqflite_sqlcipher` (not plain `sqflite`) for encrypted SQLite.
- Generate and store the SQLCipher passphrase in `flutter_secure_storage` — never derive it from a hardcoded string.
- Apply `secureFile()` to the `.db` file on desktop.

```dart
// ✅ Correct — encrypted local DB
final db = await openDatabase(
  dbPath,
  password: await secureStorage.read(key: 'db_passphrase'),
);

// ❌ Wrong — unencrypted, readable by anyone with file access
final db = await openDatabase(dbPath);
```

**Rules summary**

| Storage type | Permitted for secrets? | Notes |
|---|---|---|
| `flutter_secure_storage` | ✅ Yes — required | OS keychain/keystore backed |
| `sqflite_sqlcipher` | ✅ Yes — with encryption | Passphrase from `flutter_secure_storage` |
| Plain `sqflite` | ❌ No | Unencrypted on disk |
| `shared_preferences` | ❌ No | Plaintext plist/XML |
| `Hive` (unencrypted box) | ❌ No | Plaintext on disk |
| External/shared storage | ❌ Never | World-readable |

---

## Database Migration Rules

- **Migrations are append-only.** Never edit or delete an existing `.sql` migration file — it may already be applied in production databases.
- **Naming:** `NNN_description.sql` where `NNN` is a zero-padded integer (e.g. `003_add_poster_url.sql`).
- **Each migration must be idempotent** where possible — use `IF NOT EXISTS` and `IF EXISTS` guards.
- **Never DROP a column in the same migration that ADDs another.** Split into separate migrations so rollback is clean.
- **Never rename a column directly.** Add the new column, migrate data, then drop the old in a later migration.
- **Test every migration** against a copy of the real DB before writing it to the repo.

---

## API Overview

All API endpoints are prefixed with `/api/v1`.

| Group | Prefix | Description |
|-------|--------|-------------|
| Info | `GET /info` | Server identity, version, capabilities |
| Auth | `/auth/...` | Pairing, token management |
| Files | `/files/...` | Browse and search the library |
| Library | `/library/...` | CRUD for libraries, trigger scans |
| Stream | `/stream/...` | Start/stop streams, get HLS URLs |
| HLS | `/hls/...` | Serve `.m3u8` and `.ts` files |
| WebSocket | `/ws/...` | Real-time events (stream status, client activity) |

Full contracts: `docs/04_api/01_api_contracts.md`

### API Versioning Rule

`/api/v1` is a permanent public contract. Once shipped:
- **Additive changes** (new endpoints, new optional fields) are allowed in v1.
- **Breaking changes** (removed fields, changed types, removed endpoints) require `/api/v2`.
- Never remove or rename a field in an existing v1 response schema.

### Common Patterns

```python
# All routes use async/await
@router.get("/files", response_model=List[MediaFileSchema])
async def list_files(
    library_id: int | None = None,
    db: aiosqlite.Connection = Depends(get_db),
    token: str = Depends(validate_token),
):
    ...
```

- All responses: JSON with consistent `{ data, error, meta }` envelope.
- Errors: Standard HTTP status codes + `{ "error": "message", "code": "SNAKE_CASE_CODE" }` body.
- Auth: `Authorization: Bearer <token>` header on all protected routes.
- All timestamps stored and returned as UTC ISO 8601.

---

## Development Commands

### Server

```bash
# Install dependencies
cd apps/server
pip install -e .[dev]

# Run development server
uvicorn main:app --reload --host 0.0.0.0 --port 8080

# Run tests
pytest tests/ -v

# Lint + format
ruff check .
black .

# Build standalone executable
pyinstaller fluxora_server.spec
```

### Desktop App (Flutter)

```bash
cd apps/desktop
flutter pub get
flutter run -d windows          # or macos / linux
flutter test
flutter analyze
# Release builds — always obfuscate; keep debug-info files privately for crash symbolication
flutter build windows --release --obfuscate --split-debug-info=build/debug-info/windows/
flutter build macos --release --obfuscate --split-debug-info=build/debug-info/macos/
```

### Mobile App (Flutter)

```bash
cd apps/mobile
flutter pub get
flutter run                     # connected device or emulator
flutter test
flutter analyze
# Release builds — always obfuscate; keep debug-info files privately for crash symbolication
flutter build apk --release --obfuscate --split-debug-info=build/debug-info/android/
flutter build ipa --release --obfuscate --split-debug-info=build/debug-info/ios/
```

### Shared Core Package

```bash
cd packages/fluxora_core
flutter pub get
flutter analyze
# Run codegen (freezed + json_serializable)
dart run build_runner build --delete-conflicting-outputs
```

---

## Code Conventions

### Python (Backend)

- **Formatting:** Black (line length 88). Run `black .` before committing.
- **Linting:** Ruff. Run `ruff check .` before committing.
- **Type hints:** Required on all function signatures. Use `X | None` syntax (Python 3.11+).
- **Async:** All database calls and I/O must be `async`. Never use `time.sleep()` — use `asyncio.sleep()`.
- **FFmpeg:** Always use `asyncio.create_subprocess_exec()`. Never `subprocess.run()` (blocks the event loop).
- **Config:** All settings live in `config.py` via `pydantic.BaseSettings`. Never hardcode paths, ports, or URLs.
- **Logging:** Use `logging.getLogger(__name__)` per module. Log levels:
  - `DEBUG` — internal state, variable dumps (dev only)
  - `INFO` — lifecycle events: server start, stream open/close, library scan complete
  - `WARNING` — recoverable issues: TMDB key absent, mDNS unavailable, client reconnecting
  - `ERROR` — failures needing attention: DB error, FFmpeg crash, auth failure
  - `CRITICAL` — unrecoverable startup failures
  - Always pass `exc_info=True` to `logger.error()` and `logger.critical()`.
- **Error handling:** Raise `HTTPException` from route handlers only. Services raise plain Python exceptions; routers catch and convert.
- **Concurrency:** Use `asyncio.Lock` to protect any shared mutable state. SQLite writes are serialized through the connection pool — never open a second write connection.
- **SQL:** Always use parameterized queries. Never concatenate user input into a SQL string.
- **N+1 queries:** Never query inside a loop. Collect IDs first, then use `WHERE id IN (...)` or a JOIN in one query.
- **Log format:** In development (`ENV=dev`), use plain `StreamHandler` output. In production (`ENV=prod`), use structured JSON via `python-json-logger` — every log record must include `timestamp`, `level`, `module`, `message`. Configure in `config.py`.

```python
# ✅ Correct
async def start_stream(file_id: int, session_id: str) -> str:
    proc = await asyncio.create_subprocess_exec("ffmpeg", ...)
    return playlist_url

# ❌ Wrong — blocks event loop, no type hints
def start_stream(file_id):
    subprocess.run(["ffmpeg", ...])
```

### Dart/Flutter (Frontend)

- **Formatting:** `dart format .` (enforced). Line length: 80.
- **Analysis:** `flutter analyze` must pass with zero errors before committing.
- **Architecture layers:** Never import from `presentation/` into `domain/`. Never import from `data/` into `presentation/` directly — go through the domain use case.
- **State:** Use BLoC events/states for complex async flows. Use Riverpod providers for simpler shared state. Never mix BLoC and Riverpod in the same feature.
- **Naming:**
  - Files: `snake_case.dart`
  - Classes: `PascalCase`
  - Variables/functions: `camelCase`
  - Constants: `kCamelCase` (Flutter convention)
- **Widgets:** Keep widgets small and focused. Extract any widget > ~80 lines to its own file.
- **API calls:** All HTTP via `ApiClient` (from `fluxora_core`). Never call `dio.get()` directly in a widget or BLoC.
- **Logging:** Use the `logger` package (via `fluxora_core`). Never `print()` or `debugPrint()`. Use:
  - `logger.d(message)` — debug
  - `logger.i(message)` — info
  - `logger.w(message)` — warning
  - `logger.e(message, error: e, stackTrace: st)` — always pass the error and stack trace
- **Types:** Never use `dynamic` unless interfacing with a fully untyped external API. Prefer explicit generics and `Object?`.
- **BLoC error states:** Every BLoC must emit an error state. Never model a feature with only loading + success states.
- **Null safety:** Never use `!` (null assertion) without a preceding null check or an invariant comment explaining why null is impossible here.
- **Dates:** All timestamps from the API are UTC. Parse with `DateTime.parse(...).toUtc()`. Convert to local time only at the display layer.
- **`const` everywhere:** Every widget, constructor, and value that does not depend on runtime data must be `const`. The linter enforces this — treat any `prefer_const_constructors` warning as an error.
- **BLoC naming:**
  - Events: `XEvent` (sealed class) with subclasses `XStarted`, `XRefreshed`, etc.
  - States: `XState` (sealed class) with subclasses `XInitial`, `XLoading`, `XSuccess`, `XFailure`
  - BLoC: `XBloc extends Bloc<XEvent, XState>`
  - Use `Cubit<XState>` instead of `Bloc` when there are no multi-event chains (simple toggle, single async fetch)
- **`go_router` rules:**
  - All routes defined in `app_router.dart` — never use `Navigator.push()` directly
  - Route paths: lowercase kebab-case (`/library/detail/:id`)
  - Route names: `const` string constants in a `Routes` class
  - Auth guard: implement via `redirect` callback — check token before allowing navigation to protected routes
  - Navigate with `context.go()` (replace) or `context.push()` (stack)
- **DI with `get_it`:**
  - All registrations in `core/di/injector.dart`, called before `runApp()`
  - `registerLazySingleton` for services initialized on first use (`ApiClient`, `SecureStorage`)
  - `registerFactory` for BLoCs — each `BlocProvider` gets a fresh instance
  - `registerSingleton` for services that must initialize at startup (`Logger`)
  - Never call `GetIt.instance<X>()` inside a widget — inject via `BlocProvider` or constructor

```dart
// ✅ Correct — domain layer
abstract class StreamRepository {
  Future<StreamSession> startStream(int fileId);
}

// ❌ Wrong — presentation calling data directly
class StreamBloc {
  final dio = Dio();
  Future<void> startStream() async {
    final res = await dio.post('/stream/start');
  }
}
```

---

## Testing Discipline

### Python

- Every **router** must have at least one integration test using `httpx.AsyncClient` and a test DB.
- Every **service** must have unit tests with mocked dependencies (no real DB, no real FFmpeg).
- Test files mirror source structure: `tests/test_auth.py` tests `routers/auth.py`.
- Use `pytest-asyncio` for all async tests.
- Use `pytest` fixtures in `conftest.py` — never repeat setup code across test files.
- Minimum coverage targets: routers 80%, services 90%, utils 100%.

### Dart/Flutter

- Every **use case** must have a unit test with a mocked repository.
- Every **BLoC** must have tests for each event covering: loading, success, and error states.
- Every **repository implementation** must have integration tests against a real (test) `ApiClient`.
- Widget tests for every screen — at minimum test initial render, loading state, and error state.
- Use `mocktail` for mocking; never use real network calls in unit or widget tests.
- Run `flutter test --coverage` and keep coverage above 70% per package.

---

## Security Rules

- **Path traversal:** Every file-serving endpoint must validate the resolved path is inside a registered library root before serving. Use `path.canonicalize()` and check the prefix. See `docs/06_security/01_security.md`.
- **FFmpeg argument sanitization:** Never pass raw user input as FFmpeg arguments. Validate file IDs against the database; resolve to a trusted path internally.
- **Parameterized SQL:** Always use `?` placeholders in aiosqlite queries. Zero tolerance for string-formatted SQL.
- **Token security:** Tokens must be stored only in `flutter_secure_storage` on the client. Never `shared_preferences`, never in-memory only. Never log a token value — log only its first 8 characters for debugging if absolutely necessary.
- **Input validation:** Validate all user-facing input at the API boundary (FastAPI schemas). Never trust input that reaches a service or database layer.
- **CORS:** In production mode, never use `allow_origins=["*"]`. Restrict to the paired client's origin or use token validation as the sole auth mechanism.
- **Error messages:** Never expose internal paths, stack traces, or DB schema details in API error responses. Log the detail internally; return a generic message to the client.
- **Database file access:** The `~/.fluxora/` directory must be `700` and `fluxora.db` must be `600` (owner read/write only). See the Database Security subsection for the exact implementation. Never open the DB file with world-readable permissions.
- **Database contents:** Sensitive columns (`clients.token`, any stored API key) must be encrypted via `encrypt_field()` / `decrypt_field()` before any DB read/write. A raw `SELECT *` on the database file must not expose usable secrets.
- **Keychain key:** The Fernet encryption key lives exclusively in the OS keychain (`keyring`). If the keychain is unavailable (headless server, CI), the server must fail fast with a clear error rather than silently falling back to unencrypted storage.

---

## Resource Cleanup Rules

### Python

- **HLS temp directories:** Every `stream_session` must register its temp dir at creation. On session end (normal or crash), delete `/tmp/fluxora/{session_id}/` immediately. On server startup, delete all orphaned `/tmp/fluxora/*/` dirs from previous runs.
- **FFmpeg processes:** Track every spawned subprocess by `session_id`. On session end, `proc.kill()` and `await proc.wait()`. Never leave a zombie FFmpeg process.
- **DB connections:** Always return connections to the pool. Use `async with get_db() as db:` pattern — never hold a connection longer than one request.

### Dart/Flutter

- **StreamSubscriptions:** Cancel every `StreamSubscription` in the `close()` method of the BLoC or in `dispose()` of the widget. Never leave a subscription dangling.
- **BLoC disposal:** Every BLoC created via `BlocProvider` is disposed automatically. BLoCs created manually must be `close()`d explicitly.
- **Video player:** Call `controller.dispose()` when navigating away from the player screen. Leaving an active HLS session without closing it wastes server resources.
- **Timers:** Cancel all `Timer` instances in `dispose()`. A leaked timer is a memory leak that also fires callbacks on dead state.

---

## Before You Are Done

Run these checks before ending any session. Do not mark a task complete until all pass.

### Server changes
- [ ] `ruff check apps/server` — zero errors
- [ ] `black --check apps/server` — no formatting issues
- [ ] `pytest apps/server/tests/ -v` — all tests pass
- [ ] Manually hit the affected endpoint with a real request if feasible

### Flutter changes (run in the affected package directory)
- [ ] `flutter analyze` — zero errors, zero warnings
- [ ] `flutter test` — all tests pass
- [ ] If UI changed: run the app and visually verify the golden path

### Both
- [ ] Release builds use `--obfuscate --split-debug-info` (Flutter) — never ship an unobfuscated release binary
- [ ] Debug info files (`build/debug-info/`) are saved privately (not committed) for crash symbolication
- [ ] No new `TODO` / `FIXME` left without a linked GitHub issue
- [ ] No secrets, tokens, or `.env` files staged for commit
- [ ] Docs updated to match any changed contracts, schemas, or architecture
- [ ] `AGENT_LOG.md` entry written


---

## Dependency Version Policy

> **Before adding or updating any dependency, you must verify the current latest version. Never use a version from memory or training data — it is likely months or years out of date.**

### How to check latest versions

| Ecosystem | Command | Alternative |
|-----------|---------|-------------|
| Python (pip) | `pip index versions <package>` | https://pypi.org/project/<package>/ |
| Dart/Flutter (pub) | `dart pub outdated` in the package dir | https://pub.dev/packages/<package> |
| Node.js (npm) | `npm show <package> version` | https://www.npmjs.com/package/<package> |
| GitHub Actions | Check releases tab on the action's GitHub repo | e.g. github.com/actions/checkout/releases |

### Rules

- **Pin to the latest stable release** at time of writing. Use `^` for pub deps (allows minor/patch), exact pins for security-sensitive packages.
- **GitHub Actions must always use the latest major version tag** (e.g. `actions/checkout@v5`, not `@v3` or `@v2`). Check the action's GitHub releases page before writing any workflow.
- **Never copy a version number from a doc, README, or AI suggestion without verifying it is current.** The version in an example may be years old.
- **Run `flutter pub outdated` and `pip list --outdated` before any major release** and upgrade where safe.
- **When a package releases a new major version**, evaluate it — do not blindly stay on the old major forever.
- **Firebase SDKs**: Firebase packages update frequently and must stay in sync with each other. Always run `flutter pub upgrade firebase_core firebase_messaging` together and verify the FlutterFire compatibility matrix at https://firebase.flutter.dev/docs/overview before pinning.

---

## API Key & Secrets Management

> Putting secrets in a `.env` file is not a strategy — it is the bare minimum. This section defines the full end-to-end approach for every secret type in Fluxora.

### Secret types and where they live

| Secret | Owner | Storage at rest | Injected at |
|--------|-------|----------------|-------------|
| TMDB API key | Server | `~/.fluxora/.env` (user's machine) | Server startup via `BaseSettings` |
| Fluxora bearer tokens | Client | `flutter_secure_storage` (device keychain/keystore) | Runtime, after pairing |
| Firebase project config | Build system | `google-services.json` / `GoogleService-Info.plist` (gitignored) | Build time, per-platform |
| Firebase service account | CI only | GitHub Secret | CI workflow env var |
| Cloud Functions secrets | Firebase | Firebase Secret Manager | Function runtime via `secretManager.getSecret()` |
| Dart-define keys (any) | Build system | `config.json` (gitignored) or GitHub Secrets | Build time via `--dart-define-from-file` |

### Flutter: compile-time secrets via `--dart-define`

Never read API keys from a file at runtime in Flutter. Pass them at build time:

```bash
# Local dev — create a gitignored file
# config.json  (add to .gitignore)
# { "TMDB_KEY": "abc123", "FIREBASE_PROJECT": "fluxora-prod" }

flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/debug-info/android/ \
  --dart-define-from-file=config.json
```

Access in Dart code:
```dart
const tmdbKey = String.fromEnvironment('TMDB_KEY');
```

In CI (GitHub Actions), inject via secrets:
```yaml
- run: flutter build apk --release --obfuscate --split-debug-info=build/debug-info/android/ --dart-define=TMDB_KEY=${{ secrets.TMDB_KEY }}
```

### Firebase config files

- `google-services.json` (Android) and `GoogleService-Info.plist` (iOS/macOS) are **not secrets** per se — Firebase considers them semi-public identifiers. However, they must still be gitignored in public repos to prevent abuse (quota exhaustion, spam).
- Store them in a private location (password manager, secure file share) and document the setup step in the private onboarding guide.
- In CI, store as base64-encoded GitHub Secrets and decode them during the build step.

```yaml
- name: Decode Firebase config
  run: echo "${{ secrets.GOOGLE_SERVICES_JSON }}" | base64 --decode > apps/mobile/android/app/google-services.json
```

### Firebase Cloud Functions: Secret Manager

Never put secrets in `functions/` source code or `firebase.json`:

```javascript
// ✅ Correct — use Secret Manager
const { defineSecret } = require('firebase-functions/params');
const tmdbKey = defineSecret('TMDB_KEY');

exports.myFunction = onRequest({ secrets: [tmdbKey] }, (req, res) => {
  const key = tmdbKey.value();
});

// ❌ Wrong — hardcoded or in config
const key = functions.config().tmdb.key;
```

### Python server: BaseSettings + .env

```python
# config.py
class Settings(BaseSettings):
    tmdb_api_key: str | None = None  # optional — degrade gracefully if absent
    server_port: int = 8080

    class Config:
        env_file = "~/.fluxora/.env"  # user's home dir, never the repo
```

The `.env` file lives in `~/.fluxora/` — never in the project directory. Document this location in the setup guide. The repo's `.gitignore` must explicitly exclude `*.env`, `.env`, and `config.json`.

### .gitignore requirements

These entries must always be present:
```
# Secrets
*.env
.env
config.json
google-services.json
GoogleService-Info.plist

# Obfuscation debug symbols (keep privately, never commit)
build/debug-info/
```

---

## Server Startup Initialization Order

The server must initialize components in this exact order. Starting to accept HTTP requests before migrations run or before permissions are set is a bug.

```
1. Validate secrets    — fail fast if TOKEN_HMAC_KEY is empty
2. Secure DB directory — get_data_dir() + restrict_windows_path() / chmod 700
3. Ensure HLS tmp dir  — hls_tmp_path.mkdir(parents=True, exist_ok=True)
4. Clean HLS orphans   — delete session dirs left over from a crash
5. Open DB + migrate   — init_db(): connect, WAL mode, apply pending .sql migrations
6. Secure DB file      — secure_db_file(): chmod 600 on .db / -wal / -shm
7. Close orphan sessions — mark ended_at on sessions with no ended_at (crash recovery)
8. Check FFmpeg        — warn (not fail) if FFmpeg not on PATH
9. Start mDNS          — zeroconf broadcast of _fluxora._tcp.local
10. Start HTTP server  — uvicorn begins accepting connections
```

> **Note:** Keychain integration (`get_or_create_db_key`) is planned for Phase 2 when TMDB key encryption is added.

Never swap steps. Never skip a step in any environment including tests (use an in-memory test DB for step 3-6, but the order must be preserved).

---

## Code Generation Policy

Fluxora uses `build_runner` to generate `freezed` data classes and `json_serializable` JSON codecs.

**Rules:**
- Generated files (`.freezed.dart`, `.g.dart`) **must be committed** to the repository. Do not gitignore them. Other developers and CI must not need to run `build_runner` just to compile.
- Regenerate after every change to an entity annotated with `@freezed` or `@JsonSerializable`.
- Always use `--delete-conflicting-outputs` to avoid stale partial generations.
- Never manually edit a `.freezed.dart` or `.g.dart` file — all changes go in the source class.
- In CI, run `dart run build_runner build --delete-conflicting-outputs` and then verify no files were changed (`git diff --exit-code`). If files changed, the developer forgot to regenerate.

```bash
# Regenerate all in fluxora_core
cd packages/fluxora_core
dart run build_runner build --delete-conflicting-outputs

# Verify nothing is stale (run in CI)
git diff --exit-code packages/fluxora_core/lib
```

---

## WebSocket Rules

The `/ws/` endpoints carry real-time server events. Treat the WebSocket connection as unreliable — it will drop.

**Server (Python):**
- Send a `{"type": "ping"}` frame every 30 seconds to each connected client.
- If no `pong` response within 10 seconds, close the connection and clean up the client's session state.
- Never hold application state in-memory per WebSocket connection — always read from the DB.
- On abnormal close, log `WARNING` with client ID; do not log `ERROR` (disconnects are normal).

**Client (Dart/Flutter):**
- Reconnect with exponential backoff on disconnect: 1s → 2s → 4s → 8s → 16s → 30s (cap).
- Respond to server `ping` frames with a `{"type": "pong"}` immediately.
- While disconnected: show a subtle non-blocking indicator in the UI; do not block user interaction.
- On reconnect: re-subscribe to any session-specific events by replaying the last known event ID.
- Dispose the WebSocket in `BLoC.close()` — never leak an open socket.

---

## Firebase Integration Rules

### Crashlytics (error monitoring)

Initialize in `main.dart` before `runApp()`. Catch all unhandled errors:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  runZonedGuarded(
    () => runApp(const FluxoraApp()),
    (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
  );
}
```

**Rules:**
- Never log PII, file paths, tokens, or user content to Crashlytics.
- Use `setCustomKey` only for non-sensitive context: app version, connection type (`lan`/`webrtc`), phase.
- Call `setCrashlyticsCollectionEnabled(false)` in debug builds.
- For caught errors that are worth tracking: `FirebaseCrashlytics.instance.recordError(e, st)`.

### Remote Config (feature flags)

- Every flag must have a default value defined in the Firebase console AND in code.
- Flag naming convention: `feature_<name>_enabled` (e.g. `feature_webrtc_enabled`).
- All Phase 3+ features must be gated behind a Remote Config flag that **defaults to `false`**.
- Fetch interval: 1 hour minimum in production; 0 in debug (use `fetchAndActivate` freely).
- Flag checks belong in the **domain layer** (use case), never in a widget.
- When Firebase is absent (no internet, no config): always fall back to the `false` default — never crash.

```dart
// ✅ Correct — domain layer, safe default
final isWebRtcEnabled = FirebaseRemoteConfig.instance.getBool('feature_webrtc_enabled');

// ❌ Wrong — flag check in widget
if (widget.remoteConfig.getBool('feature_webrtc_enabled')) { ... }
```

---

## Rate Limiting

The FastAPI server must protect against request flooding from misbehaving or malicious clients.

Use `slowapi` (wraps the `limits` library):

```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
```

**Limits per endpoint group:**

| Endpoint group | Limit | Key |
|----------------|-------|-----|
| `POST /auth/request-pair` | 5/minute | IP address |
| `POST /stream/start` | 10/minute | Bearer token |
| `GET /hls/...` | 300/minute | Bearer token |
| All other `/api/v1/...` | 120/minute | Bearer token |

- Return `429 Too Many Requests` with `Retry-After` header.
- Log rate limit violations at `WARNING` level with client IP and endpoint.
- Never rate-limit the health/info endpoint (`GET /api/v1/info`).

---

## Offline Detection & Connectivity

Use `connectivity_plus` to monitor network state in Flutter apps. Add it to `fluxora_core`.

```dart
// In a top-level ConnectivityService (registered as lazySingleton in get_it)
class ConnectivityService {
  final _connectivity = Connectivity();

  Stream<bool> get isOnline => _connectivity.onConnectivityChanged
      .map((result) => result != ConnectivityResult.none);

  Future<bool> get currentlyOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
```

**Rules:**
- A device having network connectivity does NOT mean the Fluxora server is reachable. Always distinguish between "network available" and "server reachable".
- Server reachability: attempt `GET /api/v1/info` with a 3-second timeout. If it fails, consider server unreachable.
- When server is unreachable: show a non-blocking banner at the top of the screen. Never show a full-screen error for a transient disconnect.
- When connectivity is restored: retry server discovery automatically (mDNS first, then last-known IP).
- Never disable core navigation or cached UI because of a connectivity loss — let the user browse what they already loaded.

---

## PR / Code Review Checklist

Before any pull request is merged, verify all of the following. The author checks this; the reviewer verifies.

### Author checklist
- [ ] `flutter analyze` — zero errors, zero warnings in all affected packages
- [ ] `ruff check` + `black --check` — zero issues in server
- [ ] All tests pass locally (`pytest -v`, `flutter test`)
- [ ] New code has tests — no new feature ships without tests
- [ ] Generated files regenerated and committed if entities changed
- [ ] No `print()` / `debugPrint()` / `TODO` / `FIXME` left without a linked issue
- [ ] No secrets, tokens, or credentials anywhere in the diff
- [ ] Docs updated (API contracts, schema, architecture) if the change requires it
- [ ] `AGENT_LOG.md` entry written

### Reviewer checklist
- [ ] Layer boundaries not broken (no `presentation/` importing `data/` directly)
- [ ] All error paths handled and logged
- [ ] No new dependency added without justification in the PR description
- [ ] Sensitive fields hashed or encrypted appropriately
- [ ] Rate limiting applied to any new public-facing endpoint
- [ ] No hardcoded paths, ports, or magic numbers
---

## Key Files to Read Before Specific Tasks

| Task | Read First |
|------|-----------|
| Any UI work | `DESIGN.md` |
| Adding an API endpoint | `docs/04_api/01_api_contracts.md` |
| Changing DB schema | `docs/03_data/02_database_schema.md` |
| Backend service changes | `docs/09_backend/01_backend_architecture.md` |
| Flutter screen/widget | `docs/08_frontend/01_frontend_architecture.md` |
| Networking/streaming | `docs/02_architecture/01_system_overview.md` |
| Security-sensitive feature | `docs/06_security/01_security.md` |
| CI/CD changes | `docs/05_infrastructure/01_infrastructure.md` |

---

## Design System Reference

**Read `DESIGN.md` in full before creating any UI.**

Quick tokens for reference:

```
Background:    #0F172A
Surface:       #1E293B
Border:        #334155
Primary:       #6366F1
Accent:        #22D3EE
Text primary:  #E2E8F0
Text muted:    #94A3B8
Success:       #22C55E
Warning:       #F59E0B
Error:         #EF4444
Font:          Inter (all weights)
Border radius: cards=12px, buttons=8px, badges=9999px
```

---

## Phase Roadmap

| Phase | Scope | Status |
|-------|-------|--------|
| 0 | Architecture, docs, monorepo scaffold | ✅ Complete |
| 1 | FastAPI scaffold, mDNS, basic HLS, Flutter project setup, landing page | 🔵 In Progress (server ✅, mobile ✅ except HLS player — on-device testing) |
| 2 | Full library management, Flutter home/player screens | 🔲 Planned |
| 3 | WebRTC internet streaming, Firebase signaling, Flutter Web dashboard, subscription licensing | 🔲 Planned |
| 4 | Hardware transcoding, advanced client management | 🔲 Planned |
| 5 | AI recommendations, public release | 🔲 Planned |

Full roadmap: `docs/10_planning/01_roadmap.md`

---

## Known Risks & Gotchas

| Area | Gotcha | Mitigation |
|------|--------|-----------|
| FFmpeg | Must be installed separately by the user; PyInstaller cannot bundle it | Startup check with friendly error message and download link |
| mDNS on Android 12+ | Android silently drops multicast packets without `WifiManager.MulticastLock` | Implemented: `MainActivity.kt` exposes `MethodChannel('dev.marshalx.fluxora/multicast')` — `ConnectCubit.startDiscovery()` acquires the lock before scanning, releases on close; manual IP entry remains as fallback |
| `flutter_webrtc` | v0.10.x uses removed v1 Flutter plugin API (`PluginRegistry.Registrar`) — fails to compile on AGP 8+ | Use v1.x+ when adding in Phase 3; do not add earlier |
| SQLite concurrency | WAL mode helps but high client counts can still lock | Connection pool limit; queue writes; plan PostgreSQL migration path for Pro |
| HLS temp files | FFmpeg writes to `/tmp` — can fill up on long sessions | Enforce cleanup on stream close AND on server startup (orphan cleanup) |
| PyInstaller + FFmpeg | FFmpeg subprocess path must use the bundled binary path, not `PATH` | Resolve FFmpeg path via `sys._MEIPASS` in frozen builds |
| Token storage (Flutter) | `shared_preferences` is not encrypted | Use `flutter_secure_storage` for the bearer token |
| Path traversal | File-serving routes could expose files outside the library root | Always canonicalize and prefix-check before serving |
| Bash / Git Commits | Backticks inside double-quoted commit messages execute as bash commands, causing pathspec errors | Use single quotes (`'`) instead of double quotes to wrap commit messages containing backticks |
| Pytest & CI | `pytest` exits with code 5 if no tests are found, breaking CI pipelines | Always include at least one placeholder test (e.g. `def test_placeholder(): pass`) |
| Git Pull / Merge | Running `git pull` with diverged branches creates an unwanted `Merge branch 'main' of...` commit in the history | Always use `git pull --rebase` to pull remote changes without creating an automated merge commit |

---

## Out of Scope (v1)

- Light mode
- Multi-user accounts (single-owner server only)
- Cloud backup / remote library
- Music streaming (media type supported but UI is Phase 2+)
- Torrent integration
- Browser-based web client
- Subtitle / caption rendering (Phase 3+)
- AI-based recommendations (Phase 5)

---

## Current Status

> **As of April 2026 — Phase 0 complete. Phase 1 fully complete (M2 done). Phase 2 next.**

- Monorepo scaffold complete: `apps/server/`, `apps/mobile/`, `apps/desktop/`, `packages/fluxora_core/`
- All documentation written and in sync
- Flutter workspace configured: all packages pass `flutter analyze` with zero issues
- `.vscode/launch.json` configured: Server, Mobile, Desktop configs + `Server + Mobile` compound
- `packages/fluxora_core` **implemented**: all 5 entities with `freezed` + `json_serializable` codegen; `ApiClient` (Dio), `ApiException`, `Endpoints`, `SecureStorage`; design tokens
- `apps/server` — **Phase 1 complete** (38 passing tests; ruff + black clean):
  - Full FastAPI lifespan (10 ordered steps), mDNS (`AsyncZeroconf`), structured logging
  - All routers: info, auth, files, library, stream, ws ✅
  - All services: auth, library, discovery, ffmpeg ✅
  - `TOKEN_HMAC_KEY` required at startup; stored in `%APPDATA%\Fluxora\.env` (Windows)
- `apps/mobile` — **Phase 1 complete** (24 passing tests):
  - `core/di/injector.dart` — get_it DI; credentials restored from SecureStorage on restart
  - `core/router/app_router.dart` — go_router with async auth redirect guard
  - `features/connect` — mDNS auto-discovery + manual IP; Android `WifiManager.MulticastLock` ✅
  - `features/auth` — full pairing flow, `PairCubit` with polling ✅
  - `features/library` — library grid + files list ✅
  - `features/player` — `media_kit` HLS player; `PlayerCubit` starts/stops stream; auth headers injected into `Media(httpHeaders:)`; `MaterialVideoControls`; landscape + immersive mode ✅
  - Android platform files; `better_player` removed (AGP 8+ incompatible); `flutter_webrtc` deferred to Phase 3

**Next:** Phase 2 — Desktop control panel (`apps/desktop`) — dashboard + client approval UI (so pairing no longer requires curl). Then: TMDB metadata, playback resume.