# Contributing to Fluxora

This is the "first 30 minutes on a new machine" guide. If you're an AI agent, read [`CLAUDE.md`](./CLAUDE.md) instead — it's the longer rules-and-context doc. This file is for humans.

---

## Required tools

| Tool | Version | Why |
|------|---------|-----|
| Python | 3.11 or 3.12 | Server runtime. 3.13 not yet validated. |
| Flutter | 3.41.3 (stable) | Mobile + desktop apps. Pinned in CI to match the Dart 3.9+ project floor (json_annotation 4.11+, go_router 17+ require it). |
| FFmpeg | latest stable | HLS transcoding. Server checks for it on startup. |
| Git | any recent | obviously |
| (optional) cloudflared | latest | Only if you're testing public routing — see [`docs/05_infrastructure/03_public_routing.md`](./docs/05_infrastructure/03_public_routing.md) |
| (optional) sqlite3 CLI | any | Useful for poking the DB directly during dev |

### Platform notes

- **Windows:** install Python and Flutter via `winget` or the official installers. FFmpeg from `https://www.gyan.dev/ffmpeg/builds/` and add `bin/` to `PATH`. WSL works but isn't primary.
- **macOS:** `brew install python@3.11 ffmpeg flutter`.
- **Linux:** Python 3.11 from your distro; Flutter from the snap or the tarball; FFmpeg from `apt`/`dnf`. The desktop app's `flutter_secure_storage_linux` plugin needs `libsecret-1-dev`.

### Skip the platform setup: use the devcontainer

The repo ships a `.devcontainer/` config with Python 3.11, Flutter 3.41, Node 22, FFmpeg, and cloudflared pre-installed. If you have VS Code with the **Dev Containers** extension (or use **GitHub Codespaces**):

1. Open the repo in VS Code → command palette → **"Dev Containers: Reopen in Container"**
2. Wait for build (~5 minutes first time, cached after)
3. Run server / mobile / desktop / web tests directly in the container

Your host's `~/.fluxora/` (where `.env` lives) is bind-mounted into the container at `/home/vscode/.fluxora/`, so secrets work transparently. The Dockerfile is at [`.devcontainer/Dockerfile`](./.devcontainer/Dockerfile); the post-create install script is at [`.devcontainer/post-create.sh`](./.devcontainer/post-create.sh).

> **Mobile / desktop release builds happen on the host or in CI**, not in the container — Android SDK and platform-specific signing tools aren't bundled. Day-to-day Flutter dev (analyze, test, format) works inside the container fine; just don't try to assemble an APK there.

---

## First-clone setup

```bash
git clone https://github.com/Marshal-GG/Fluxora.git
cd Fluxora

# Server
cd apps/server
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -e ".[dev]"
cd ../..

# Shared core package — referenced by path: from mobile and desktop
cd packages/fluxora_core
flutter pub get
cd ../..

# Mobile
cd apps/mobile
flutter pub get
cd ../..

# Desktop
cd apps/desktop
flutter pub get
cd ../..
```

You should now have a working tree. Don't run anything yet — secrets need to exist first.

---

## Configure secrets

Fluxora reads its config from `~/.fluxora/.env` (Linux/macOS) or `%APPDATA%\Fluxora\.env` (Windows). Create that directory and file:

```bash
# macOS/Linux
mkdir -p ~/.fluxora
cat > ~/.fluxora/.env <<'EOF'
TOKEN_HMAC_KEY=$(python -c "import secrets; print(secrets.token_hex(32))")
FLUXORA_LICENSE_SECRET=$(python -c "import secrets; print(secrets.token_hex(32))")
FLUXORA_PORT=8080
FLUXORA_LOG_LEVEL=DEBUG
EOF
```

```powershell
# Windows PowerShell
New-Item -ItemType Directory -Force "$env:APPDATA\Fluxora"
@"
TOKEN_HMAC_KEY=$([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
FLUXORA_LICENSE_SECRET=$([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
FLUXORA_PORT=8080
FLUXORA_LOG_LEVEL=DEBUG
"@ | Set-Content "$env:APPDATA\Fluxora\.env"
```

For local dev that's all you strictly need. `POLAR_WEBHOOK_SECRET` only matters if you're testing payment webhooks; leave unset and `/api/v1/webhook/polar` returns 501 (intentional — confirms misconfiguration is loud).

See [`docs/05_infrastructure/01_infrastructure.md` § Environment variables](./docs/05_infrastructure/01_infrastructure.md#environment-variables--config) for the full list.

---

## Run things

### Server

```bash
cd apps/server
uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```

`--reload` watches Python files and restarts on save. Drop it for production-ish runs.

Verify: `curl http://localhost:8080/api/v1/info` → JSON with `server_name` and `version`.

### Mobile

Server must be running first.

```bash
cd apps/mobile
flutter run                  # picks an attached device
flutter run -d "Pixel 6"     # specific device
flutter run -d chrome        # if you really want web
```

The app's first screen is server discovery — your local server should appear via mDNS. If not, manual IP entry works (`http://192.168.x.x:8080`).

### Desktop

```bash
cd apps/desktop
flutter run -d windows       # or -d macos / -d linux
```

The desktop control panel hits `localhost:8080` directly. No pairing flow — it's privileged via `validate_token_or_local`.

### All three at once (VS Code)

`.vscode/launch.json` has compound configs:
- **Server + Mobile** — useful when working on streaming
- **Server + Desktop** — useful when working on admin UI

Hit F5, pick the config.

---

## Tests

| Suite | Where | Count | Run |
|-------|-------|-------|-----|
| Server | `apps/server/tests/` | 149 | `cd apps/server && python -m pytest -v` |
| Mobile | `apps/mobile/test/` | 27 | `cd apps/mobile && flutter test` |
| Desktop | `apps/desktop/test/` | 38 | `cd apps/desktop && flutter test` |
| `fluxora_core` | `packages/fluxora_core/test/` | 9 | `cd packages/fluxora_core && flutter test` |

All four should be green before opening a PR.

### Lint / format

```bash
# Server
cd apps/server
python -m ruff check .
python -m ruff format .          # apply
python -m black --check .        # both must be happy — they currently agree

# Flutter (any of the three)
flutter analyze
dart format --set-exit-if-changed lib/ test/
```

The `server_ci.yml`, `mobile_ci.yml`, `desktop_ci.yml` GitHub Actions run all of these on every push.

---

## Code conventions

The full list lives in [`docs/12_guidelines/01_development_guidelines.md`](./docs/12_guidelines/01_development_guidelines.md). The 5-line summary:

1. **No `print()` / `debugPrint()`** — always use the project logger.
2. **No bare `except: pass`** — log the error or rethrow.
3. **No hardcoded secrets, ports, or paths** — config via `BaseSettings` (Python) or DI (Dart).
4. **Clean Architecture layers** — Domain → Data → Presentation. Don't import upward.
5. **Always parameterize SQL** — never f-string a query.

For the Hard Prohibitions list (don't run `git commit` from automation, don't add AI branding anywhere, etc.) see [`CLAUDE.md`](./CLAUDE.md#hard-prohibitions).

---

## Commit & PR conventions

Commit messages follow conventional-commit-ish style:

```
type(scope): short imperative summary

Optional body explaining the why. Wrap at 72 chars.
```

| Prefix | When |
|--------|------|
| `feat:` | New user-visible behavior |
| `fix:` | Bug fix |
| `chore:` | Build, CI, deps, gitignore, no behavior change |
| `docs:` | Documentation only |
| `refactor:` | Internal cleanup, no behavior change |
| `test:` | Test-only changes |
| `build:` | Dependency bumps, packaging |
| `ci:` | GitHub Actions / workflow changes |

Scope is `(server)`, `(mobile)`, `(desktop)`, `(core)`, `(docs)`, or omit for repo-wide.

PRs: target `uat` for visible work; `main` only for releases. The web-landing CI auto-deploys `uat` to `uat.fluxora.marshalx.dev` and `main` to `fluxora.marshalx.dev`.

---

## Adding a database migration

Brief version: `apps/server/database/migrations/NNN_description.sql`, zero-padded, applied alphabetically on startup. Append-only — never edit a past migration.

Full guide: [`docs/03_data/04_migration_guide.md`](./docs/03_data/04_migration_guide.md).

---

## Where to look when stuck

| Symptom | Doc |
|---------|-----|
| "How do I add an API endpoint?" | [`docs/04_api/01_api_contracts.md`](./docs/04_api/01_api_contracts.md) + look at `apps/server/routers/files.py` for a clean example |
| "How do I structure a new Flutter feature?" | [`docs/08_frontend/01_frontend_architecture.md`](./docs/08_frontend/01_frontend_architecture.md) — feature-first Clean Architecture |
| "Why does mDNS not work on Android 12+?" | [`CLAUDE.md` § Known Risks](./CLAUDE.md#known-risks--gotchas) — `MulticastLock` |
| "How do I rotate the license secret?" | [`docs/06_security/02_license_key_operations.md`](./docs/06_security/02_license_key_operations.md) |
| "How do I back up my dev DB?" | [`docs/05_infrastructure/05_backup_and_recovery.md`](./docs/05_infrastructure/05_backup_and_recovery.md) |
| "What are the design tokens?" | [`DESIGN.md`](./DESIGN.md) |

---

## Asking for help

- Check [`AGENT_LOG.md`](./AGENT_LOG.md) for recent decisions and ongoing work
- Check `docs/10_planning/03_open_questions.md` for known unresolved questions
- Open a draft PR early — it's easier to redirect than to undo
