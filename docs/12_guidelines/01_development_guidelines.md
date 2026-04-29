# Fluxora Development Guidelines

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
| Cloud (Phase 3+) | Firebase Cloud Functions (Node.js) + Polar webhooks | Firebase for relay/push features; Polar `order.paid` webhooks hit the self-hosted server for license issuance |

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

## Git Commit Convention

All commits **must** follow this structure. Future agents must use this format when writing commit messages.

### Format

```
<type>(<scope>): <short summary, imperative, ≤72 chars>

## <Area 1> — <what changed>
- <bullet: specific change, file/class names, no fluff>
- <bullet>

## <Area 2> — <what changed>
- <bullet>

## Docs
- <what docs were updated and why>
```

### Types

| Type | When to use |
|------|-------------|
| `feat` | New feature or capability added |
| `fix` | Bug fix |
| `refactor` | Code restructure without behavior change |
| `docs` | Documentation-only changes |
| `test` | Adding or updating tests only |
| `chore` | Tooling, dependencies, config |
| `perf` | Performance improvement |

### Scopes (use the most specific one)

| Scope | Covers |
|-------|--------|
| `phase<N>` | A multi-area milestone commit (e.g. `phase4`) |
| `server` | `apps/server/` |
| `mobile` | `apps/mobile/` |
| `desktop` | `apps/desktop/` |
| `core` | `packages/fluxora_core/` |
| `docs` | `docs/` only |
| `db` | Migrations or schema changes |
| `ci` | CI/CD pipeline |

### Rules

- **Subject line:** imperative mood, no period, ≤ 72 chars (`feat(server): add settings router`)
- **Body sections:** Use `## Area — description` headers to group related changes
- **Bullet format:** Each bullet names the exact file, class, or function changed
- **Docs bullet:** Always end with a `## Docs` section if any `.md` files were updated
- **No vague bullets:** ❌ "various fixes" ✅ "settings_service.py: map tier → max_concurrent_streams"
- **Test counts:** When tests are added, state the count (`9 settings tests, 5 TMDB tests added`)

### Real Example (from this repo)

```
feat(phase4): tier enforcement, license key, TMDB metadata & full doc sync

## Server — Tier Enforcement & Settings Service
- Add settings_service.py: GET/PATCH /api/v1/settings with tier → max_concurrent_streams
  mapping (free=1, plus=3, pro=10, ultimate=9999); writes limit to DB on every tier change
- Add routers/settings.py wired into main.py at /api/v1 prefix
- Add models/settings.py: UserSettings Pydantic schema with tier + license_key fields
- Add migrations/004–007: TMDB columns, last_progress_sec, license_key, max_concurrent_streams
- routers/stream.py: enforce max_concurrent_streams from DB row; return 429 on excess
- 60 total passing tests (9 settings tests, 5 TMDB tests added)

## Mobile — TMDB, Resume & Tier Limit UI
- player_state.dart: add StreamPath enum + lastProgressSec to PlayerReady
- player_cubit.dart: POST resume position on pause/dispose; restore on start
- player_screen.dart: add PlayerTierLimit → _TierLimitView on 429 response

## Desktop — Settings Screen
- settings_cubit.dart: loadSettings() / saveSettings() via PATCH /settings
- settings_state.dart: sealed states Initial/Loading/Loaded/Saved/Error
- settings_screen.dart: tier selector, license key, max-streams badge
- 23 desktop tests passing (dashboard: 3, clients: 7, settings: 13)

## Docs
- database_schema.md: migrations 004–007 documented
- data_models.md: TMDB fields, last_progress_sec, license_key added
- backend_architecture.md: settings router/service, test counts updated
- frontend_architecture.md: desktop settings ✅, routes table, test counts
- decisions.md: ADR-008 → Accepted; ADR-011 (DB-driven tier limits) added
- open_questions.md: Q-007 resolved; Q-005/Q-006 partial
- CLAUDE.md + README.md + docs/00_overview/README.md: phase roadmap updated
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

