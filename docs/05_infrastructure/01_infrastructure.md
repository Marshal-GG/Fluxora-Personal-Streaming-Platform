# Infrastructure, Deployment & CI/CD

> **Category:** Infrastructure  
> **Status:** Active  
> **Last Updated:** 2026-05-01 (Flutter version pin + subosito setup-flutter alignment; ruff bumped 0.4 → 0.15.12)

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
| SQLite Database | Platform data dir (see below) | Embedded, WAL mode |
| HLS Temp Segments | `{data_dir}/hls/` | Cleaned after stream ends |
| Secrets / Config | `{data_dir}/.env` | `BaseSettings` reads on startup |
| Flutter Mobile Client | Android / iOS device | Downloaded from app store |
| Flutter Desktop Control Panel | User's PC | Installed alongside server |

**Platform data directory:**

| Platform | Path |
|----------|------|
| Windows | `%APPDATA%\Fluxora\` (e.g. `C:\Users\<user>\AppData\Roaming\Fluxora\`) |
| macOS | `~/Library/Application Support/Fluxora/` |
| Linux | `~/.fluxora/` |

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
- All pip dependencies (`pyproject.toml`)
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
1.  Validate secrets       — fail fast if TOKEN_HMAC_KEY is empty
2.  Secure data directory  — create {data_dir}/ with owner-only permissions
3.  Ensure HLS tmp dir     — {data_dir}/hls/ created if missing
4.  Clean HLS orphans      — delete session dirs from previous crash
5.  Open DB + migrate      — aiosqlite, WAL mode, apply pending .sql migrations
6.  Secure DB file         — chmod 600 on .db / -wal / -shm (non-Windows)
7.  Close orphan sessions  — mark ended_at on sessions with no ended_at
8.  Check FFmpeg           — warn (not fail) if FFmpeg not on PATH
9.  Start mDNS broadcast   — AsyncZeroconf _fluxora._tcp.local on FLUXORA_PORT
10. Start HTTP server      — uvicorn begins accepting connections
```

---

## Environment Variables / Config

All settings are read from `{data_dir}/.env` (platform path above) via **Pydantic `BaseSettings`** (`apps/server/config.py`).
Settings can also be overridden via environment variables (same names, uppercase).

| Setting | Default | Description |
|---------|---------|-------------|
| `TOKEN_HMAC_KEY` | *(required)* | HMAC-SHA256 key for token hashing — generate once with `secrets.token_hex(32)` |
| `FLUXORA_PORT` | `8000` | HTTP server port — set to `8080` to match uvicorn `--port 8080` |
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
| `FLUXORA_LICENSE_SECRET` | `""` | HMAC secret for signing Fluxora license keys |
| `POLAR_WEBHOOK_SECRET` | `""` | Polar Standard Webhooks secret for `/api/v1/webhook/polar` |

See [`02_polar_webhook_deployment.md`](./02_polar_webhook_deployment.md) for Polar product metadata, event subscription, local testing, and production caveats.

---

## Web Landing Page — Firebase Hosting

The public landing page (`apps/web_landing/`) is a Next.js static export hosted on **Firebase Hosting**
under the `fluxora-streaming-platform` Firebase project.

### Firebase Project

| Detail | Value |
|--------|-------|
| Project ID | `fluxora-streaming-platform` |
| Hosting site | `fluxora-streaming-platform` |
| Firebase console | https://console.firebase.google.com/project/fluxora-streaming-platform |

### Hosting Channels

Firebase Hosting uses **channels** to serve different versions of the site at different URLs.

| Channel | URL | Behaviour |
|---------|-----|-----------|
| `live` | `fluxora.marshalx.dev` (custom) + `fluxora-streaming-platform.web.app` | Permanent — production |
| `uat` | `uat.fluxora.marshalx.dev` (custom) + `fluxora-streaming-platform--uat-*.web.app` | 30-day TTL, auto-renewed on every deploy |
| PR preview | Auto-generated `fluxora-streaming-platform--pr-NNN-hash.web.app` | Temporary, created per PR, deleted when PR closes |

> **UAT expiry note:** Firebase only makes the `live` channel permanent. All other channels expire after
> a maximum of 30 days. In practice this does not matter — every push to the `uat` branch resets the
> expiry automatically. If the channel does lapse, the next deploy recreates it instantly.

### Custom Domains

| Domain | Channel | DNS (Cloudflare) |
|--------|---------|-----------------|
| `fluxora.marshalx.dev` | `live` | `A` records from Firebase console — proxy **OFF** (DNS only) |
| `uat.fluxora.marshalx.dev` | `uat` | `A` records from Firebase console — proxy **OFF** (DNS only) |

**Why proxy must be OFF:** Firebase Hosting provisions its own TLS certificate via Let's Encrypt by
performing a TLS handshake directly with your domain. Cloudflare's orange-cloud proxy intercepts this
handshake and breaks certificate provisioning. Set both records to grey cloud (DNS only).

To add/verify custom domains:
1. Firebase console → Hosting → **Add custom domain**
2. Enter the domain, select the target channel
3. Copy the `A` records Firebase provides
4. Add them in Cloudflare → DNS, proxy OFF
5. Click **Verify** in Firebase console — provisioning takes a few minutes

### Required GitHub Secret

| Secret name | What it contains | Where it lives |
|-------------|-----------------|----------------|
| `FIREBASE_SERVICE_ACCOUNT_FLUXORA_STREAMING_PLATFORM` | Service account JSON key with Hosting admin permissions | GitHub → repo Settings → Secrets → Actions |

This secret was created by running `firebase init hosting:github` and is used by all three deploy jobs
in the `web_landing_ci.yml` workflow. Manage it at:
`https://github.com/Marshal-GG/Fluxora-Private/settings/secrets/actions`

---

## CI/CD Pipeline — Web Landing

**Workflow file:** `.github/workflows/web_landing_ci.yml`

### How it works

The workflow has **4 jobs** with a strict dependency chain:

```
push / pull_request
        │
        ▼
   [1] build          ← runs on every trigger
        │  (uploads artifact: landing-out)
        ├──▶ [2] deploy-preview   ← PRs only
        ├──▶ [3] deploy-uat       ← uat branch only
        └──▶ [4] deploy-production ← main branch only (approval gate: pending team plan upgrade)
```

All three deploy jobs download the same build artifact — the site is built exactly once
and the same output is what gets deployed to every environment.

### Job details

| Job | Trigger condition | Firebase channel | Approval gate |
|-----|------------------|-----------------|---------------|
| `build` | Always | — | None |
| `deploy-preview` | `github.event_name == 'pull_request'` | Auto-created PR channel | None |
| `deploy-uat` | `github.ref == 'refs/heads/uat'` | `uat` (expires: 30d, reset on every deploy) | None |
| `deploy-production` | `github.ref == 'refs/heads/main'` | `live` | See note below |

### Required GitHub token permissions

The `FirebaseExtended/action-hosting-deploy` action posts a GitHub Check Run to show deploy status
inline on commits and PRs. This requires the following permissions on each deploy job:

| Job | Required permissions |
|-----|---------------------|
| `deploy-preview` | `contents: read`, `pull-requests: write`, `checks: write` |
| `deploy-uat` | `contents: read`, `checks: write` |
| `deploy-production` | `contents: read`, `checks: write` |

> If `checks: write` is missing, the job crashes with:
> `RequestError: Resource not accessible by integration (403)` on the check-runs API call.

### PR Preview channel

The `deploy-preview` job creates a **temporary Firebase Hosting channel** for every pull request. It is deleted automatically when the PR closes.

**How to use it:**

1. Create a branch and make your changes:
   ```bash
   git checkout -b feature/my-change
   # edit files
   git push origin feature/my-change
   ```
2. Open a pull request on GitHub (base: `uat` or `main`, compare: `feature/my-change`)
3. GitHub Actions runs `build` then `deploy-preview`
4. When `deploy-preview` finishes (~1 min), two things happen:
   - The Firebase action posts a comment on the PR with the preview URL
   - The URL also appears in the Actions tab → `deploy-preview` job → last step output
5. The preview URL looks like: `https://fluxora-streaming-platform--pr-1-xxxxxxxx.web.app`
6. When you close or merge the PR, Firebase deletes the preview channel automatically

**When it's useful:**
- Sharing a WIP change with someone for feedback before it hits UAT
- Visually reviewing a change without polluting the UAT channel
- Code review — reviewer can click the URL directly from the PR

For solo work, this is optional — pushing directly to `uat` is the normal flow.

### Viewing all active channels

```bash
firebase hosting:channel:list
```

This lists every active channel with its URL and expiry. Example output:
```
│ uat  │ 2026-04-27 16:30:27 │ https://fluxora-streaming-platform--uat-6opvp06r.web.app │ 2026-05-27 │
│ live │ 2026-04-27 13:56:39 │ https://fluxora-streaming-platform.web.app               │ never      │
```

> **UAT expiry note:** Firebase resets the channel expiry on every CI deploy. The `deploy-uat` job
> sets `expires: 30d` so each push to `uat` gives you another 30 days. The channel will only lapse
> if the `uat` branch goes untouched for 30+ days straight — in practice this never happens.

> ⚠️ **Production protection — TODO when adding team members**
>
> The workflow uses `environment: production` which supports a required-reviewer approval gate,
> but **GitHub Free plan does not expose this feature for private repos**. Currently the gate is
> not enforced — any push to `main` deploys directly to live.
>
> **When to fix this:** as soon as a second developer gets push access to the repo.
>
> **Option A — Upgrade to GitHub Team ($4/user/month)**
> → Environments → `production` → Deployment protection rules → Required reviewers → add reviewer → Save.
> The Actions job will pause and email the reviewer before deploying.
>
> **Option B — Branch protection (free)**
> → Settings → Branches → Add rule for `main` → Require a pull request before merging → Required approvals: 1 → Save.
> Forces every change to go through a PR. Reviewer approves the PR, not the deploy itself,
> but the effect is the same: nothing reaches `main` without a second person signing off.
>
> **Current workaround (solo project):** use `uat` as the personal quality gate.
> Test on UAT, push to `main` only when satisfied. The `uat → main` flow is the gate.

---

## Deploying to UAT

Push any commit to the `uat` branch:

```bash
git checkout uat
git merge feature/my-landing-change
git push origin uat
```

GitHub Actions will:
1. Build the Next.js static export
2. Deploy to the `uat` Firebase channel
3. Site is live at `uat.fluxora.marshalx.dev` within ~2 minutes

No approval needed. Anyone with push access to the `uat` branch can deploy.

---

## Deploying to Production (Live)

Push to `main` **after getting reviewer approval**:

```bash
git checkout main
git merge uat          # or merge your branch
git push origin main
```

GitHub Actions starts the `deploy-production` job but **pauses** it immediately,
waiting for a required reviewer to approve in the Actions UI.

### How approval works

1. A push to `main` triggers the workflow
2. The `deploy-production` job reaches the `environment: production` gate
3. GitHub emails all required reviewers and shows a pending approval in the Actions tab
4. A reviewer goes to **Actions → the workflow run → Review deployments** and clicks **Approve**
5. The job resumes and deploys to the `live` channel

If nobody approves within 30 days, the pending job expires and must be re-triggered by pushing again.

### Setting up required reviewers (one-time setup)

1. Go to **GitHub → repo → Settings → Environments**
2. Click **New environment**, name it `production`
3. Under **Deployment protection rules**, tick **Required reviewers**
4. Add the GitHub usernames of people who can approve production deploys
5. Save — the gate is now active on every push to `main`
6. Repeat for the `uat` environment (no reviewers needed — leave protection rules empty)

> **Important:** The `production` and `uat` environments must exist in GitHub Settings for the
> workflow's `environment:` block to function. If they don't exist, the approval gate is silently
> skipped and deploys go straight through.

---

## CI/CD Pipeline — Server, Mobile, Desktop

GitHub Actions is used for all automated builds. Workflows are **path-scoped** to avoid
unnecessary builds (e.g., a Python change does not trigger a Flutter build).

### Workflow Files

| File | Trigger | What it does |
|------|---------|-------------|
| `.github/workflows/web_landing_ci.yml` | Push to `apps/web_landing/**` on `main`/`uat`, or any PR | Build → deploy to Firebase Hosting (preview / uat / live) |
| `.github/workflows/server_ci.yml` | Push/PR to `apps/server/**` | ruff lint → black format check → pytest (ruff pinned to `0.15.12`) |
| `.github/workflows/mobile_ci.yml` | Push/PR to `apps/mobile/**` or `packages/**` | `flutter pub get` (core + app) → `flutter analyze` → `flutter test` |
| `.github/workflows/desktop_ci.yml` | Push/PR to `apps/desktop/**` or `packages/**` | `flutter pub get` (core + app) → `flutter analyze` → `flutter test` |
| `.github/workflows/mirror-public.yml` | Push to `main` | Safely mirrors private repository to a public mirror, stripping internal files |

*All workflows use `actions/checkout@v5`. The Flutter workflows use `subosito/flutter-action@v2` with `flutter-version: 3.32.0` (Dart 3.8.x — required for the null-aware map literal syntax used in `apps/desktop`).*

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
| Run server | `cd apps/server && uvicorn main:app --host 0.0.0.0 --port 8080` |
| Run server (reload) | `cd apps/server && uvicorn main:app --host 0.0.0.0 --port 8080 --reload` |
| Run mobile (dev) | `cd apps/mobile && flutter run` |
| Run desktop (dev) | `cd apps/desktop && flutter run -d windows` |
| Run Python tests | `cd apps/server && pytest tests/ -v` |
| Run Flutter tests | `flutter test` (from each app dir) |

**VSCode launch configurations** (`.vscode/launch.json`):

| Config | Description |
|--------|-------------|
| `Server` | Uvicorn with debugger attached — breakpoints work |
| `Server (reload)` | Same + `--reload` for auto-restart on file save |
| `Mobile` | Flutter debug on connected device |
| `Desktop` | Flutter debug on Windows |
| `Server + Mobile` (compound) | Launches both simultaneously; `stopAll: true` |
| `Server + Desktop` (compound) | Launches both simultaneously |

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
