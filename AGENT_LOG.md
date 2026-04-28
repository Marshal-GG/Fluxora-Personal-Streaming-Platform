# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_02.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 01)
**Archived:** 2026-04-27
**Contents:** Phase 0 & Phase 1 setup.
* Scaffolded the monorepo architecture and authored comprehensive design/architecture docs.
* Setup Python backend (FastAPI, aiosqlite, pydantic-settings) and database scripts.
* Created the `fluxora_core` Flutter package with core entities (`freezed`) and network layer (`ApiClient` with Dio).
* Fixed various linter and structural issues.
* Documented known risks related to `git pull`, `pytest`, and commit message backticks in `CLAUDE.md`.

**Next Immediate Steps:**
1. Implement `packages/fluxora_core` storage wrapper.
2. Move to server components (`config.py`, `database/db.py`, etc.).

---

## Entry Template

```
---
## [YYYY-MM-DD] — Session Title
**Agent:** <model name / tool name>
**Phase:** <Planning | Phase 1 | Phase 2 | …>
**Status:** <Complete | Partial | Blocked>

### What Was Done
- Bullet list of completed tasks

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `relative/path/to/file` |
| Modified | `relative/path/to/file` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/04_api/01_api_contracts.md` | Added `GET /files` response schema |
| `docs/10_planning/01_roadmap.md` | Marked Phase 1 milestone 1 complete |

> If no docs were changed this session, write: **None — no doc-impacting changes made.**

### Decisions Made
- Any architectural or design decisions locked in this session

### Blockers / Open Issues
- Anything that couldn't be finished and why

### Next Agent Should
1. Ordered list of what to do next

### Hard Rules Checklist
- [ ] Did NOT run any `git commit` / `git push` or any git write command
- [ ] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---
```

---

## [2026-04-27] — Landing Page, Firebase Scaffold & pyproject.toml Consolidation
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Setup
**Status:** Complete

### What Was Done
- Consolidated Python server to `pyproject.toml` as single source of truth; added `[tool.ruff]`, `[tool.black]`, `[tool.pytest.ini_options]` configs; deleted redundant `requirements.txt`/`requirements-dev.txt`
- Updated `server_ci.yml` `actions/checkout@v4` → `@v5`
- Scaffolded `apps/web_landing/` — Next.js 16 static export landing page for `fluxora.marshalx.dev`; confirmed `npm run build` succeeds with zero errors
- Scaffolded `firebase.json` + `.firebaserc` + `functions/` Cloud Functions (Node 22, Phase 3 stubs)
- Created `.github/workflows/web_landing_ci.yml` — Cloudflare Pages deploy via `cloudflare/wrangler-action@v3`
- Updated `.gitignore` with Next.js / Firebase build artifact entries
- Updated `CLAUDE.md`: repo layout, tech stack, Phase 3 roadmap

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `CLAUDE.md` |
| Modified | `apps/server/pyproject.toml` |
| Modified | `.github/workflows/server_ci.yml` |
| Modified | `.gitignore` |
| Created | `apps/web_landing/package.json` |
| Created | `apps/web_landing/next.config.ts` |
| Created | `apps/web_landing/tsconfig.json` |
| Created | `apps/web_landing/src/app/layout.tsx` |
| Created | `apps/web_landing/src/app/globals.css` |
| Created | `apps/web_landing/src/app/page.tsx` |
| Created | `apps/web_landing/src/components/Navbar.tsx` |
| Created | `apps/web_landing/src/components/Hero.tsx` |
| Created | `apps/web_landing/src/components/Features.tsx` |
| Created | `apps/web_landing/src/components/HowItWorks.tsx` |
| Created | `apps/web_landing/src/components/Platforms.tsx` |
| Created | `apps/web_landing/src/components/Footer.tsx` |
| Created | `.github/workflows/web_landing_ci.yml` |
| Created | `firebase.json` |
| Created | `.firebaserc` |
| Created | `functions/package.json` |
| Created | `functions/tsconfig.json` |
| Created | `functions/src/index.ts` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `CLAUDE.md` | Repo layout, tech stack (Next.js + Flutter Web), Phase 3 roadmap |

### Decisions Made
- Landing page on Cloudflare Pages — user's domain `marshalx.dev` is already on Cloudflare; subdomain `fluxora.marshalx.dev`
- Next.js static export — no server needed, ideal for Cloudflare Pages CDN
- Flutter Web dashboard (`apps/web_app`) deferred to Phase 3 — needs internet relay to be useful

### Blockers / Open Issues
- **Manual steps before CI deploy works:**
  1. Create Firebase project → update `.firebaserc` with real project ID
  2. Create Cloudflare Pages project named `fluxora-landing`
  3. Add GitHub Secrets: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`
  4. Add custom domain `fluxora.marshalx.dev` in Cloudflare Pages settings
  5. Update GitHub repo URL in `Navbar.tsx` and `Footer.tsx` (placeholder `https://github.com/marshalx/fluxora`)

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Implement `packages/fluxora_core` entities with `freezed` + `json_serializable`; run codegen
3. Implement `packages/fluxora_core` network layer — `ApiException`, `endpoints.dart`, `ApiClient`
4. Implement `packages/fluxora_core` storage — `SecureStorage` wrapper
5. Implement `apps/server/config.py` → `database/db.py` → `main.py` → `GET /api/v1/info`
6. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-27] — fluxora_core Full Implementation
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Core Infrastructure
**Status:** Complete

### What Was Done
- Implemented all 5 freezed entities with `json_serializable` codegen: `MediaFile`, `Library`, `StreamSession`, `Client`, `ServerInfo`
- Created shared `converters.dart` (UTC DateTime helpers) and `enums.dart` (`LibraryType`, `ConnectionType`, `ClientPlatform`, `SubscriptionTier`)
- Implemented `ApiClient` — Dio singleton with auth interceptor and typed `get`/`post`/`put`/`delete` methods throwing `ApiException`
- Implemented `ApiException` — typed error class with `fromDioException` factory and convenience getters
- Implemented `Endpoints` — all `/api/v1` URL constants with path-parameter helpers
- Implemented `SecureStorage` — `flutter_secure_storage` wrapper for `auth_token`, `server_url`, `client_id`
- Implemented `AppColors`, `AppSizes`, `AppTypography` design token constants from `DESIGN.md`
- Added `json_annotation: ^4.9.0` to `pubspec.yaml`; created `build.yaml` with global `field_rename: snake` + `explicit_to_json`
- Added `invalid_annotation_target: ignore` to `analysis_options.yaml` (known freezed v2 pattern)
- Ran `dart run build_runner build --delete-conflicting-outputs` — all 10 generated files committed
- `flutter analyze` → **zero issues**

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `packages/fluxora_core/pubspec.yaml` |
| Modified | `packages/fluxora_core/pubspec.lock` |
| Modified | `packages/fluxora_core/analysis_options.yaml` |
| Created | `packages/fluxora_core/build.yaml` |
| Created | `packages/fluxora_core/lib/entities/converters.dart` |
| Created | `packages/fluxora_core/lib/entities/enums.dart` |
| Modified | `packages/fluxora_core/lib/entities/media_file.dart` |
| Created | `packages/fluxora_core/lib/entities/media_file.freezed.dart` |
| Created | `packages/fluxora_core/lib/entities/media_file.g.dart` |
| Modified | `packages/fluxora_core/lib/entities/library.dart` |
| Created | `packages/fluxora_core/lib/entities/library.freezed.dart` |
| Created | `packages/fluxora_core/lib/entities/library.g.dart` |
| Modified | `packages/fluxora_core/lib/entities/stream_session.dart` |
| Created | `packages/fluxora_core/lib/entities/stream_session.freezed.dart` |
| Created | `packages/fluxora_core/lib/entities/stream_session.g.dart` |
| Modified | `packages/fluxora_core/lib/entities/client.dart` |
| Created | `packages/fluxora_core/lib/entities/client.freezed.dart` |
| Created | `packages/fluxora_core/lib/entities/client.g.dart` |
| Modified | `packages/fluxora_core/lib/entities/server_info.dart` |
| Created | `packages/fluxora_core/lib/entities/server_info.freezed.dart` |
| Created | `packages/fluxora_core/lib/entities/server_info.g.dart` |
| Modified | `packages/fluxora_core/lib/network/api_exception.dart` |
| Modified | `packages/fluxora_core/lib/network/endpoints.dart` |
| Modified | `packages/fluxora_core/lib/network/api_client.dart` |
| Modified | `packages/fluxora_core/lib/storage/secure_storage.dart` |
| Modified | `packages/fluxora_core/lib/constants/app_colors.dart` |
| Modified | `packages/fluxora_core/lib/constants/app_sizes.dart` |
| Modified | `packages/fluxora_core/lib/constants/app_typography.dart` |
| Modified | `packages/fluxora_core/lib/fluxora_core.dart` |
| Modified | `CLAUDE.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `CLAUDE.md` | Updated Current Status: fluxora_core now implemented |
| `docs/02_architecture/02_tech_stack.md` | Split Key Packages table into implemented (fluxora_core) vs planned (apps) |

### Decisions Made
- `json_annotation` kept as explicit dep at `^4.9.0` (not `^4.11.0`) — constrained by `freezed ^2.5.2` + `json_serializable ^6.7.1` version triangle
- `@JsonKey` on freezed factory params is valid for codegen; `invalid_annotation_target: ignore` is the standard freezed v2 workaround
- `build.yaml` global `field_rename: snake` avoids per-class `@JsonSerializable(fieldRename: ...)` boilerplate
- `converters.dart` top-level functions (not a `JsonConverter` class) — avoids needing `json_annotation` for the `JsonConverter` interface

### Blockers / Open Issues
- None — package is complete and passes analysis

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Implement `apps/server/config.py` — `BaseSettings` reading `~/.fluxora/.env`
3. Implement `apps/server/database/db.py` — aiosqlite connection pool, WAL mode, migration runner
4. Write `apps/server/database/migrations/001_initial_schema.sql` — all 5 core tables
5. Implement `apps/server/main.py` — FastAPI app with startup/shutdown lifecycle
6. Implement `GET /api/v1/info` router + `ServerInfo` Pydantic response model
7. Run `pytest` and `ruff check` + `black --check` to verify server passes CI
8. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-27] — Firebase Hosting & CI/CD Pipeline Setup
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Infrastructure
**Status:** Complete

### What Was Done
- Created Firebase Hosting `uat` channel (30-day TTL, auto-renewed on each deploy)
- Ran `firebase init hosting:github` → created GCP service account, uploaded `FIREBASE_SERVICE_ACCOUNT_FLUXORA_STREAMING_PLATFORM` secret to `Marshal-GG/fluxora-private`
- Ran `firebase init` (Hosting only) → restored `firebase.json` after init overwrote custom config (site, trailingSlash, cache headers)
- Deleted Firebase-generated `firebase-hosting-pull-request.yml` — replaced by our `web_landing_ci.yml`
- Updated `web_landing_ci.yml` UAT environment URL to `uat.fluxora.marshalx.dev`
- Fixed `functions/tsconfig.json` — added `rootDir: "src"` to resolve TypeScript error
- Registered Firebase web app in console
- Added custom domain `fluxora.marshalx.dev` → `live` channel (DNS verification pending)
- Fully documented Firebase Hosting setup, CI/CD pipeline, and production protection options

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `.github/workflows/web_landing_ci.yml` |
| Modified | `firebase.json` |
| Modified | `functions/tsconfig.json` |
| Modified | `docs/05_infrastructure/01_infrastructure.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/05_infrastructure/01_infrastructure.md` | Added full Firebase Hosting section: channels, custom domains, GitHub secret, CI/CD pipeline diagram, UAT/production deploy guides, production protection options and TODO |

### Decisions Made
- UAT channel uses 30-day TTL (Firebase limitation); auto-renews on every deploy
- GitHub Free plan does not support required reviewers on Environments for private repos; `uat → main` discipline is the current production gate
- Firebase-generated workflow files deleted — `web_landing_ci.yml` handles all deploy cases

### Blockers / Open Issues
- DNS verification for `fluxora.marshalx.dev` pending propagation
- `uat.fluxora.marshalx.dev` custom domain not yet added to Firebase Hosting console
- GitHub Environments have no protection rules (Free plan limitation — documented in infra doc)

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Implement `apps/server/config.py` — `BaseSettings` reading `~/.fluxora/.env`
3. Implement `apps/server/database/db.py` — aiosqlite connection pool, WAL mode, migration runner
4. Write `apps/server/database/migrations/001_initial_schema.sql` — all 5 core tables
5. Implement `apps/server/main.py` — FastAPI app with startup/shutdown lifecycle
6. Implement `GET /api/v1/info` router + `ServerInfo` Pydantic response model
7. Run `pytest` and `ruff check` + `black --check` to verify server passes CI
8. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-27] — CI/CD Fixes, PR Preview Docs & Landing Page Polish
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Infrastructure
**Status:** Complete

### What Was Done
- Fixed `deploy-uat` job missing `expires: 30d` — Firebase was resetting UAT channel to 7-day TTL on every CI deploy
- Added `checks: write` permission to all three deploy jobs — Firebase action crashed with 403 trying to post GitHub Check Runs
- Fixed GitHub repo URLs in Navbar, Hero, and Footer — placeholder `marshalx/fluxora` replaced with real public mirror `Marshal-GG/Fluxora-Personal-Streaming-Platform`
- Updated git remote URL after GitHub renamed repo from `fluxora-private` → `Fluxora-Private`
- Documented PR preview channel workflow in infrastructure doc (how to trigger, view URL, when useful)
- Documented required GitHub token permissions per deploy job
- Documented `firebase hosting:channel:list` usage with example output

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `.github/workflows/web_landing_ci.yml` |
| Modified | `apps/web_landing/src/components/Navbar.tsx` |
| Modified | `apps/web_landing/src/components/Hero.tsx` |
| Modified | `apps/web_landing/src/components/Footer.tsx` |
| Modified | `docs/05_infrastructure/01_infrastructure.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/05_infrastructure/01_infrastructure.md` | Added PR preview channel section, required permissions table, channel list usage, updated secret URL to renamed repo |

### Decisions Made
- `expires: 30d` set on `deploy-uat` job — Firebase resets TTL on every deploy; must be explicit or defaults to 7 days
- `checks: write` required on all deploy jobs — `FirebaseExtended/action-hosting-deploy@v0` always tries to post a Check Run
- Public mirror URL used in landing page — private repo link would 404 for all visitors

### Blockers / Open Issues
- DNS verification for `fluxora.marshalx.dev` still pending
- `uat.fluxora.marshalx.dev` custom domain not yet added to Firebase Hosting console

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Implement `apps/server/config.py` — `BaseSettings` reading `~/.fluxora/.env`
3. Implement `apps/server/database/db.py` — aiosqlite connection pool, WAL mode, migration runner
4. Write `apps/server/database/migrations/001_initial_schema.sql` — all 5 core tables
5. Implement `apps/server/main.py` — FastAPI app with startup/shutdown lifecycle
6. Implement `GET /api/v1/info` router + `ServerInfo` Pydantic response model
7. Run `pytest` and `ruff check` + `black --check` to verify server passes CI
8. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-27] — Server Phase 1: config, database, migrations, GET /api/v1/info
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Server Core
**Status:** Complete

### What Was Done
- Implemented `config.py` — `Settings` via `pydantic-settings`; reads `~/.fluxora/.env`; platform-correct data dir (`%APPDATA%\Fluxora` / `~/.fluxora`); `700`/`600` permission helpers; `icacls` for Windows
- Implemented `database/db.py` — aiosqlite connection, WAL mode, `PRAGMA foreign_keys=ON`, `_migrations` tracking table, migration runner applying `.sql` files in order
- Implemented `database/migrations/001_initial.sql` — `libraries`, `media_files` (+ 2 indexes), `clients`, `user_settings` (with seed `INSERT OR IGNORE`)
- Implemented `database/migrations/002_sessions.sql` — `stream_sessions` (+ 3 indexes)
- Implemented `models/settings.py` — `ServerInfoResponse` Pydantic model
- Implemented `routers/info.py` — `GET /api/v1/info` reads `user_settings`, returns name/version/tier
- Stubbed all other routers (`auth`, `files`, `library`, `stream`, `ws`) as empty `APIRouter` so they import cleanly
- Implemented `main.py` — FastAPI lifespan: dir security → HLS orphan cleanup → `init_db` → `secure_db_file` → router registration; structured JSON logging in prod, plain in dev
- Implemented `tests/conftest.py` — `test_db` fixture (isolated tmp DB) + `client` fixture (ASGI test client)
- Implemented `tests/test_auth.py` — 2 integration tests for `GET /api/v1/info` (defaults + settings row update)
- Fixed `server_ci.yml` — added ruff lint and black format check steps; added PR trigger; set `working-directory`

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/config.py` |
| Modified | `apps/server/database/db.py` |
| Modified | `apps/server/database/migrations/001_initial.sql` |
| Modified | `apps/server/database/migrations/002_sessions.sql` |
| Modified | `apps/server/models/settings.py` |
| Created  | `apps/server/routers/info.py` |
| Modified | `apps/server/routers/auth.py` |
| Modified | `apps/server/routers/files.py` |
| Modified | `apps/server/routers/library.py` |
| Modified | `apps/server/routers/stream.py` |
| Modified | `apps/server/routers/ws.py` |
| Modified | `apps/server/main.py` |
| Modified | `apps/server/tests/conftest.py` |
| Modified | `apps/server/tests/test_auth.py` |
| Modified | `.github/workflows/server_ci.yml` |
| Modified | `docs/05_infrastructure/01_infrastructure.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/05_infrastructure/01_infrastructure.md` | Updated server_ci.yml description to reflect ruff + black + pytest steps |

### Decisions Made
- `_migrations` table tracks applied migrations by filename — lightweight, no Alembic dependency
- `executescript()` used for migrations — handles multi-statement SQL files; auto-commits
- HLS orphan cleanup runs at startup before accepting requests — prevents leftover segments from crashed runs
- Router stubs use empty `APIRouter()` — avoids import errors while Phase 1 endpoints are not yet implemented

### Blockers / Open Issues
- `token_hmac_key` in `config.py` defaults to `""` — server will accept empty key until auth is implemented in Phase 1 auth work; must be enforced before pairing endpoint is wired up
- Keyring integration (`get_or_create_db_key`) not yet implemented — deferred to auth phase

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Implement `apps/server/routers/auth.py` — `POST /auth/request-pair`, `GET /auth/status/{client_id}`, `POST /auth/approve/{client_id}`, `DELETE /auth/revoke/{client_id}`
3. Implement `apps/server/services/auth_service.py` — token generation (HMAC-SHA256), pairing state machine
4. Implement `apps/server/models/client.py` — `PairRequestBody`, `PairResponse`, `AuthStatusResponse` Pydantic models
5. Add `validate_token` dependency for protected routes
6. Write integration tests for all auth endpoints
7. Run `ruff check`, `black --check`, `pytest` — all must pass
8. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-27] — Server Auth: pairing flow, HMAC tokens, validate_token
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Server Auth
**Status:** Complete

### What Was Done
- Implemented `models/client.py` — `PairRequestBody`, `PairResponse`, `AuthStatusResponse` Pydantic models
- Implemented `services/auth_service.py` — `generate_token()`, `hash_token()`, `verify_token()` (HMAC-SHA256 + constant-time compare); full pairing state machine: `create_pair_request`, `approve_client`, `reject_client`, `revoke_client`, `get_trusted_client_by_token`
- Implemented `routers/auth.py` — 5 endpoints: `POST /request-pair`, `GET /status/{id}`, `POST /approve/{id}`, `POST /reject/{id}`, `DELETE /revoke/{id}`; raw token returned once on first approved poll then discarded from memory (server only stores hash)
- Implemented `routers/deps.py` — `validate_token` FastAPI dependency using `HTTPBearer`
- Added `database/migrations/003_client_status.sql` — `ALTER TABLE clients ADD COLUMN status`
- Fixed `apps/server/env.example` — corrected env var names to match `config.py` (`FLUXORA_PORT`, `FLUXORA_ENV`, etc.)
- Updated all tests to cover 8 scenarios including full approval flow, rejection, and protected route enforcement
- All tests pass (8/8); ruff ✅; black ✅

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/models/client.py` |
| Modified | `apps/server/services/auth_service.py` |
| Modified | `apps/server/routers/auth.py` |
| Created  | `apps/server/routers/deps.py` |
| Created  | `apps/server/database/migrations/003_client_status.sql` |
| Modified | `apps/server/env.example` |
| Modified | `apps/server/tests/test_auth.py` |
| Modified | `docs/04_api/01_api_contracts.md` |
| Modified | `docs/03_data/02_database_schema.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |
| Modified | `CLAUDE.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/04_api/01_api_contracts.md` | Updated all auth endpoint paths to `/api/v1/auth/...`; added approve, reject, revoke endpoints; added status markers |
| `docs/03_data/02_database_schema.md` | Added `status` column to clients table; updated migration strategy with applied migrations table |
| `docs/09_backend/01_backend_architecture.md` | Added `deps.py` to routers structure; marked `auth_service` as implemented |
| `CLAUDE.md` | Updated Current Status with full auth implementation detail |

### Decisions Made
- Raw token returned only once on first `GET /status` poll after approval — stored in `_pending_tokens` dict; server discards it immediately after; server only ever holds HMAC hash
- `status` column added via migration 003 rather than recreating the table — safe for existing DBs
- `validate_token` lives in `routers/deps.py` not `services/` — it raises `HTTPException` which belongs in the router layer per architecture rules
- Rejected clients can re-submit a pair request — `ON CONFLICT` resets status to `pending` if previously rejected

### Blockers / Open Issues
- `token_hmac_key` defaults to `""` — server will work but tokens are weakly signed; must generate a real key via `secrets.token_hex(32)` and add to `~/.fluxora/.env` before production use
- `approve` and `reject` endpoints have no auth — Control Panel is assumed localhost-only; network restriction enforcement deferred to Phase 2

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Implement `apps/server/services/discovery_service.py` — `zeroconf` mDNS broadcast of `_fluxora._tcp.local`
3. Implement `GET /api/v1/files` — list files with optional `library_id` filter
4. Implement `GET /api/v1/library` — list libraries; `POST /api/v1/library` — create library
5. Write tests for all new endpoints
6. Run `ruff check`, `black --check`, `pytest` — all must pass
7. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-27] — Server Phase 1: Files/Library endpoints + mDNS discovery
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Server Core
**Status:** Complete

### What Was Done
- Implemented `services/discovery_service.py` — `start_discovery()` and `stop_discovery()` using `zeroconf`; broadcasts `_fluxora._tcp.local.` with server name, port, IP, and version properties
- Added `fluxora_server_name: str = "Fluxora Server"` to `config.py Settings`
- Wired `start_discovery` / `stop_discovery` into `main.py` lifespan (step 6 before HTTP; shutdown after HTTP)
- Implemented `models/media_file.py` — `MediaFileResponse` Pydantic schema
- Implemented `models/library.py` — `LibraryResponse`, `CreateLibraryBody` Pydantic schemas
- Implemented `services/library_service.py` — `list_libraries`, `get_library`, `create_library`, `delete_library`, `list_files`, `get_file`; `root_paths` stored as JSON string in SQLite
- Implemented `routers/files.py` — `GET /api/v1/files` (with `library_id` filter), `GET /api/v1/files/{id}`; all routes require `validate_token`
- Implemented `routers/library.py` — `GET /api/v1/library`, `POST /api/v1/library`, `GET /api/v1/library/{id}`, `DELETE /api/v1/library/{id}`; all routes require `validate_token`
- Wrote `tests/test_library.py` — 8 integration tests covering full CRUD
- Wrote `tests/test_files.py` — 6 integration tests covering listing, filtering by library_id, and per-file fetch
- All 22 tests pass; ruff ✅; black ✅

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/config.py` |
| Modified | `apps/server/main.py` |
| Modified | `apps/server/services/discovery_service.py` |
| Modified | `apps/server/services/library_service.py` |
| Modified | `apps/server/models/media_file.py` |
| Modified | `apps/server/models/library.py` |
| Modified | `apps/server/routers/files.py` |
| Modified | `apps/server/routers/library.py` |
| Modified | `apps/server/tests/test_library.py` |
| Modified | `apps/server/tests/test_files.py` |
| Modified | `docs/04_api/01_api_contracts.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/04_api/01_api_contracts.md` | Replaced stub `/files` and `/library` with full `/api/v1/files`, `/api/v1/library` contract including all 6 endpoints, schemas, auth, status markers; updated versioning strategy |
| `docs/09_backend/01_backend_architecture.md` | Updated project structure with all implemented files + test files; updated service map with `library_service` and `discovery_service` actual function signatures |

### Decisions Made
- `root_paths` stored as JSON text in SQLite (no junction table) — library roots are a small ordered list; JSON avoids a join and keeps the migration simple
- `fluxora_server_name` added to `Settings` — mDNS name can be overridden via env var; `user_settings` DB name used only for the `/info` endpoint
- `file_count` computed via `COUNT(*)` sub-query per library — acceptable for Phase 1 with small libraries; optimize with trigger or cached column if performance requires

### Blockers / Open Issues
- `scan_library` (directory scan + file indexing) not yet implemented — `media_files` can only be populated via direct DB insert or future scan endpoint
- `approve`/`reject` endpoints still have no auth — Control Panel localhost restriction deferred to Phase 2

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Implement `POST /api/v1/library/{id}/scan` — walk `root_paths` directories, detect media files by extension, insert into `media_files`
3. Implement `GET /api/v1/stream/start/{file_id}` — spawn FFmpeg, create HLS session, return playlist URL
4. Implement `GET /api/v1/hls/{session_id}/{filename}` — serve `.m3u8` and `.ts` files
5. Implement `DELETE /api/v1/stream/{session_id}` — stop FFmpeg, clean up temp files
6. Run `ruff check`, `black --check`, `pytest` — all must pass
7. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-27] — Server Phase 1: library scan, FFmpeg service, streaming endpoints
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Server Core
**Status:** Complete

### What Was Done
- Implemented `scan_library()` in `library_service.py` — walks `root_paths`, skips non-media extensions, inserts new files, updates `last_scanned`; yields event loop every 50 inserts
- Added `POST /api/v1/library/{id}/scan` to `library.py` router
- Implemented `services/ffmpeg_service.py` — `start_stream()` spawns `asyncio.create_subprocess_exec`; `stop_stream()` kills process; `cleanup_session_dir()` deletes HLS temp dir; `_ffmpeg_bin()` resolves bundled binary in PyInstaller builds
- Implemented `models/stream_session.py` — `StreamStartResponse`, `StreamSessionResponse` Pydantic schemas
- Implemented `routers/stream.py` — `POST /start/{file_id}`, `GET /{session_id}`, `DELETE /{session_id}` (enforces session ownership); `hls_router` with `GET /{session_id}/{filename}` (path traversal guard + `resolve().relative_to()` check)
- Updated `main.py` — imports `hls_router` from stream module; mounts at `/api/v1/hls`
- All 22 tests pass; ruff ✅; black ✅

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/services/library_service.py` |
| Modified | `apps/server/routers/library.py` |
| Modified | `apps/server/services/ffmpeg_service.py` |
| Modified | `apps/server/models/stream_session.py` |
| Modified | `apps/server/routers/stream.py` |
| Modified | `apps/server/main.py` |
| Modified | `docs/04_api/01_api_contracts.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/04_api/01_api_contracts.md` | Added `POST /library/{id}/scan`, `POST /stream/start/{id}`, `GET /stream/{id}`, `DELETE /stream/{id}`, `GET /hls/{id}/playlist.m3u8`, `GET /hls/{id}/{seg}.ts` with full schemas and status markers |
| `docs/09_backend/01_backend_architecture.md` | Updated project structure (stream.py, ffmpeg_service.py, stream_session.py, library.py scan endpoint); updated service map with ffmpeg_service functions |

### Decisions Made
- `hls_router` is a separate `APIRouter` inside `stream.py`, mounted at `/api/v1/hls` in `main.py` — keeps HLS serving decoupled from stream CRUD while staying in the same module
- Path traversal guard uses two checks: early string rejection of `..`/`/`/`\\`, then `resolve().relative_to()` for canonicalized path comparison
- `connection_type` hardcoded to `'lan'` on session create — WebRTC type update deferred to Phase 3

### Blockers / Open Issues
- FFmpeg must be installed separately and on `PATH`; startup check (friendly error + download link) deferred
- Stream tests (mocking FFmpeg subprocess) not yet written — FFmpeg not available in CI without additional setup
- `approve`/`reject` endpoints still have no auth — Control Panel localhost restriction deferred to Phase 2

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Write tests for the streaming endpoints — mock `ffmpeg_service.start_stream` and `ffmpeg_service.stop_stream` to avoid needing real FFmpeg in CI
3. Implement the WebSocket router (`routers/ws.py`) — real-time stream status events (ping/pong keepalive)
4. Consider adding a startup FFmpeg availability check in `main.py` with a clear error message
5. Run `ruff check`, `black --check`, `pytest` — all must pass
6. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-27] — Server Phase 1: stream tests + WebSocket status router
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Server Core
**Status:** Complete

### What Was Done
- Wrote `tests/test_stream.py` — 10 integration tests covering all stream endpoints using `unittest.mock.patch` to mock `ffmpeg_service`; includes HLS playlist serving, path traversal rejection, and session ownership enforcement
- Implemented `routers/ws.py` — `/api/v1/ws/status` WebSocket endpoint: token auth via first message, 30 s ping / 10 s pong timeout keepalive, `progress` message handling updates `stream_sessions.progress_sec` in DB; uses `asyncio.create_task` for non-blocking ping loop
- All 32 tests pass; ruff ✅; black ✅

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/tests/test_stream.py` |
| Modified | `apps/server/routers/ws.py` |
| Modified | `docs/04_api/01_api_contracts.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/04_api/01_api_contracts.md` | Replaced `/ws/status` and `/ws/signal` stubs with full implemented `/api/v1/ws/status` contract (handshake, ping/pong, progress) and Phase 3 stub for `/ws/signal` |
| `docs/09_backend/01_backend_architecture.md` | Updated ws.py entry; added test_stream.py to test file list |

### Decisions Made
- WebSocket token auth uses first-message JSON pattern (not query param or HTTP header) — avoids exposing token in server access logs or URL history
- Ping loop runs as a separate `asyncio.create_task` — allows receive loop to stay unblocked between pings; task is cancelled on session end
- `progress` updates use a targeted UPDATE with `client_id` check — prevents one client updating another client's session

### Blockers / Open Issues
- FFmpeg startup check not yet implemented — server starts without verifying FFmpeg is on PATH; add a `WARNING` log on startup (not a hard failure, since FFmpeg might be installed after server starts)
- WebSocket `/ws/signal` for WebRTC deferred to Phase 3
- `approve`/`reject` endpoints still have no auth — Control Panel localhost restriction deferred to Phase 2

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Phase 1 server is now feature-complete — review CLAUDE.md Phase Roadmap and update Phase 1 status to ✅ Complete
3. Begin Phase 2: implement `apps/mobile` Flutter project setup — `pubspec.yaml`, DI, router, connect screen (mDNS discovery + manual IP entry), pairing flow
4. Alternatively: add an FFmpeg startup `WARNING` log to `main.py` if FFmpeg is not found on PATH (non-blocking — just log a warning)
5. Run `ruff check`, `black --check`, `pytest` — all must pass before starting Phase 2
6. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-27] — Server Phase 1: "fix all" improvements, doc sweep, WS test fixes
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Server Core
**Status:** Complete

### What Was Done
- Added `_check_ffmpeg()` startup warning to `main.py` — logs `WARNING` if FFmpeg not on PATH; server still starts, streaming endpoints return 503
- Added `_close_orphaned_sessions()` to `main.py` lifespan — marks any sessions with `ended_at IS NULL` as ended at startup (crash recovery)
- Added `@limiter.limit("5/minute")` + `request: Request` parameter to `POST /auth/request-pair` in `routers/auth.py`
- Added `env.example` entry for `FLUXORA_SERVER_NAME`
- Completed full doc sweep after all Phase 1 server implementation: `api_contracts`, `backend_architecture`, `data_models` (added `status` field), `security` (route auth matrix), `roadmap` (Phase 1 server ✅)
- Updated `CLAUDE.md` Current Status to reflect Phase 1 server complete with 36 tests
- Wrote `tests/test_ws.py` — 4 integration tests for `/api/v1/ws/status` using `TestClient` (sync WebSocket support): `test_ws_auth_ok`, `test_ws_invalid_token_closes`, `test_ws_missing_auth_message_closes`, `test_ws_pong_accepted`
- Fixed `tests/test_ws.py` TestClient–lifespan conflict: `TestClient(app)` triggers full lifespan including `init_db(production_path)` which overwrites the test DB's `_db` pointer; fixed by patching `main.init_db`, `main.close_db`, `main.start_discovery`, `main.stop_discovery` via a `_lifespan_patches()` context manager in each test
- Fixed inter-test rate limit accumulation: `slowapi` in-memory counters persisted across tests causing `5/minute` limit to be hit mid-suite; added `reset_rate_limits` autouse fixture to `conftest.py` that calls `lim._storage.reset()` on `auth_limiter` and `stream_limiter` before and after each test
- **Final state:** 36/36 tests pass; ruff ✅; black ✅

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/main.py` |
| Modified | `apps/server/env.example` |
| Modified | `apps/server/routers/auth.py` |
| Modified | `apps/server/tests/conftest.py` |
| Created  | `apps/server/tests/test_ws.py` |
| Modified | `docs/04_api/01_api_contracts.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |
| Modified | `docs/03_data/01_data_models.md` |
| Modified | `docs/06_security/01_security.md` |
| Modified | `docs/10_planning/01_roadmap.md` |
| Modified | `CLAUDE.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/04_api/01_api_contracts.md` | All new endpoints added with full schemas; status markers updated |
| `docs/09_backend/01_backend_architecture.md` | Project structure updated; service map updated |
| `docs/03_data/01_data_models.md` | Added `status` field to Client entity; fixed `auth_token` description |
| `docs/06_security/01_security.md` | Updated route auth matrix with all ~20 implemented endpoints; WS first-message auth noted |
| `docs/10_planning/01_roadmap.md` | Phase 1 server features marked ✅ Done; Flutter features marked 🔲 Next |
| `CLAUDE.md` | Updated Current Status; Phase 1 row now shows server-complete with 36 tests |

### Decisions Made
- `_lifespan_patches()` context manager pattern — single place to declare all lifespan mocks needed by WS tests; avoids repeating four `patch()` calls in each test
- `reset_rate_limits` autouse fixture — applies globally to all tests; ensures `POST /request-pair` limit never carries over between tests regardless of run order
- `main.init_db` / `main.close_db` patched as `AsyncMock()` not `MagicMock()` — these are `async def` functions; using `MagicMock` would cause a coroutine-not-awaited error in the lifespan

### Blockers / Open Issues
- `approve`/`reject` endpoints still have no auth — Control Panel localhost restriction deferred to Phase 2
- `token_hmac_key` defaults to `""` — must set real key via `secrets.token_hex(32)` before production use

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Phase 1 server is now fully complete (36 tests, ruff ✅, black ✅) — **begin Phase 2: Flutter mobile app setup**
3. `apps/mobile` Flutter project: `pubspec.yaml` dependencies, DI (`get_it`), router (`go_router`), Connect screen (mDNS discovery + manual IP entry)
4. Implement the pairing flow: Connect screen → pair request → approval waiting screen → approved (token stored in `flutter_secure_storage`)
5. Run `flutter analyze` — zero issues required before moving on
6. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-27] — Security hardening: startup key validation + localhost enforcement
**Agent:** Claude Sonnet 4.6
**Phase:** Phase 1 — Server Security
**Status:** Complete

### What Was Done
- Added `TOKEN_HMAC_KEY` startup validation to `main.py` lifespan (step 1): raises `RuntimeError` with actionable message if the key is empty; server refuses to start insecurely
- Added `require_local_caller` dependency to `routers/deps.py`: checks `request.client.host` against `{127.0.0.1, ::1, localhost}`; returns `403` for non-loopback callers
- Applied `require_local_caller` to `POST /auth/approve/{id}` and `POST /auth/reject/{id}` in `routers/auth.py`
- Added 2 new tests to `test_auth.py`: `test_approve_blocked_from_lan` and `test_reject_blocked_from_lan` — use `ASGITransport(client=("192.168.1.100", 50000))` to simulate a LAN caller and assert `403`
- Updated `test_ws.py` `_lifespan_patches()`: added `patch.object(_settings, "token_hmac_key", HMAC_KEY)` so the startup key check passes, and `app.dependency_overrides[require_local_caller] = lambda: None` so `TestClient` approve calls succeed
- Updated lifespan step comments in `main.py` to reflect the correct 9-step order
- **Final state:** 38/38 tests pass; ruff ✅; black ✅

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/main.py` |
| Modified | `apps/server/routers/deps.py` |
| Modified | `apps/server/routers/auth.py` |
| Modified | `apps/server/tests/test_auth.py` |
| Modified | `apps/server/tests/test_ws.py` |
| Modified | `docs/04_api/01_api_contracts.md` |
| Modified | `docs/06_security/01_security.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |
| Modified | `README.md` |
| Modified | `CLAUDE.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/04_api/01_api_contracts.md` | Updated `approve`/`reject` auth notes to document `require_local_caller`; added `403` to error lists |
| `docs/06_security/01_security.md` | Route matrix: `approve`/`reject` changed from "None (Phase 1)" to "🔒 Localhost only"; Security Policies updated; Phase 2 additions note clarified |
| `docs/09_backend/01_backend_architecture.md` | `deps.py` entry updated; test file list updated with correct counts and `test_ws.py` |
| `README.md` | Status line updated; repo structure added `web_landing/`, `web_app/`, `functions/`, `firebase.json`, `.firebaserc`; Development Phases table aligned with CLAUDE.md |
| `CLAUDE.md` | Server Startup Initialization Order rewritten to match actual 9-step implementation; test count updated to 38; Current Status updated |

### Decisions Made
- `require_local_caller` checks `request.client.host` (not IP range) — simple and correct for Phase 1
- Startup key check is a hard `RuntimeError` (not a warning) — an empty key silently produces forgeable tokens
- WS tests use `patch.object` on the shared `_settings` singleton — restores the original value when the context exits, preventing test pollution

### Blockers / Open Issues
- None — Phase 1 server is fully implemented and hardened

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Phase 1 server is fully complete and hardened (38 tests) — **begin Phase 2: Flutter mobile app**
3. `apps/mobile`: configure `pubspec.yaml` deps, DI (`get_it`), router (`go_router`), Connect screen (mDNS discovery + manual IP entry)
4. Implement the pairing flow: Connect → pair request → approval waiting → approved → token in `flutter_secure_storage`
5. Run `flutter analyze` — zero issues before moving on
6. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

---
## [2026-04-28] — Phase 1 Mobile: Connect, Auth, Library
**Agent:** claude-sonnet-4-6
**Phase:** Phase 1
**Status:** Complete

### What Was Done
- Implemented the full Phase 1 Flutter mobile app (`apps/mobile`) from scratch on branch `feature/mobile-phase1`
- Added `flutter_secure_storage: ^9.0.0` and `logger: ^2.7.0` as direct dependencies to `pubspec.yaml`
- **Foundation:** `AppTheme` (dark ThemeData from DESIGN.md tokens), `main.dart`, `FluxoraApp`, DI via `get_it`, `go_router` with async auth-guard redirect
- **Shared widgets:** `LoadingOverlay`, `StatusBadge` (online/idle/offline), `MediaCard`
- **Feature: connect** — `DiscoveredServer` entity, `ServerDiscoveryRepository` interface + mDNS impl (`multicast_dns` — PTR→SRV→A resolution for `_fluxora._tcp.local.`), `ConnectCubit`, `ConnectScreen` (scan animation, server list, manual IP entry)
- **Feature: auth** — `AuthRepository` interface + impl (request-pair, poll-status, save-credentials), `PairCubit` (requesting→pending→approved/rejected via configurable-interval `Timer.periodic`), `PairingScreen`
- **Feature: library** — `LibraryRepository` interface + impl, `LibraryBloc` (Started/Refreshed), `LibraryScreen` (2-column grid), `FilesCubit`, `FilesScreen` (list with `MediaCard`)
- **Router:** `_guardRedirect` reads `SecureStorage` async; redirects to `/library` if credentials exist, or `/` if accessing a protected route without auth
- **DI startup:** restores saved `serverUrl` + `authToken` into `ApiClient` on app restart
- **Tests:** 17 tests across connect/auth/library — all pass; `flutter analyze` zero issues

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/mobile/pubspec.yaml` |
| Modified | `apps/mobile/lib/main.dart` |
| Modified | `apps/mobile/lib/app.dart` |
| Modified | `apps/mobile/lib/shared/theme/app_theme.dart` |
| Modified | `apps/mobile/lib/shared/widgets/loading_overlay.dart` |
| Modified | `apps/mobile/lib/shared/widgets/status_badge.dart` |
| Modified | `apps/mobile/lib/shared/widgets/media_card.dart` |
| Modified | `apps/mobile/lib/core/di/injector.dart` |
| Modified | `apps/mobile/lib/core/router/app_router.dart` |
| Created | `apps/mobile/lib/features/connect/domain/entities/discovered_server.dart` |
| Created | `apps/mobile/lib/features/connect/domain/repositories/server_discovery_repository.dart` |
| Created | `apps/mobile/lib/features/connect/data/repositories/server_discovery_repository_impl.dart` |
| Created | `apps/mobile/lib/features/connect/presentation/cubit/connect_state.dart` |
| Created | `apps/mobile/lib/features/connect/presentation/cubit/connect_cubit.dart` |
| Created | `apps/mobile/lib/features/connect/presentation/screens/connect_screen.dart` |
| Created | `apps/mobile/lib/features/auth/domain/repositories/auth_repository.dart` |
| Created | `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart` |
| Created | `apps/mobile/lib/features/auth/presentation/cubit/pair_state.dart` |
| Created | `apps/mobile/lib/features/auth/presentation/cubit/pair_cubit.dart` |
| Created | `apps/mobile/lib/features/auth/presentation/screens/pairing_screen.dart` |
| Created | `apps/mobile/lib/features/library/domain/repositories/library_repository.dart` |
| Created | `apps/mobile/lib/features/library/data/repositories/library_repository_impl.dart` |
| Created | `apps/mobile/lib/features/library/presentation/bloc/library_event.dart` |
| Created | `apps/mobile/lib/features/library/presentation/bloc/library_state.dart` |
| Created | `apps/mobile/lib/features/library/presentation/bloc/library_bloc.dart` |
| Created | `apps/mobile/lib/features/library/presentation/cubit/files_state.dart` |
| Created | `apps/mobile/lib/features/library/presentation/cubit/files_cubit.dart` |
| Created | `apps/mobile/lib/features/library/presentation/screens/library_screen.dart` |
| Created | `apps/mobile/lib/features/library/presentation/screens/files_screen.dart` |
| Created | `apps/mobile/test/features/connect/connect_cubit_test.dart` |
| Created | `apps/mobile/test/features/auth/pair_cubit_test.dart` |
| Created | `apps/mobile/test/features/library/library_bloc_test.dart` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/10_planning/01_roadmap.md` | Phase 1 mobile milestones updated to ✅ Done |
| `AGENT_LOG.md` | This entry appended |

### Decisions Made
- `PairCubit` accepts `pollInterval` constructor param (default 3s) so tests use 30ms without slow waits
- `go_router` async redirect guards both directions (unauthed → protected, authed → connect/pairing)
- `isA<>()` matchers used in all BLoC tests — sealed state classes intentionally don't implement `==`
- `logger` and `flutter_secure_storage` added as explicit direct deps — used directly in DI layer, not just transitive

### Blockers / Open Issues
- HLS player (Phase 2): `MediaCard.onTap` is a no-op stub pending `better_player` integration
- UI not visually verified on device — correctness confirmed via `flutter analyze` + tests

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Phase 1 mobile is complete (17 tests, zero analyze issues) — branch: `feature/mobile-phase1`
3. Next: **Phase 2 mobile** — HLS player screen (`better_player`), wire `MediaCard.onTap` → `/player/:sessionId`, stream start/stop via `ApiClient`
4. Then: **Desktop control panel** (`apps/desktop`) — Dashboard, Library management, Client approval UI
5. Run `flutter analyze` in all affected packages before declaring done
6. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-28] — On-device testing: build fixes, server fixes, doc update
**Agent:** claude-sonnet-4-6
**Phase:** Phase 1 — Mobile on-device testing
**Status:** Complete

### What Was Done
- Generated Android platform files via `flutter create . --org dev.marshalx --platforms android,ios` — `android/` and `ios/` directories were missing entirely
- Added required Android permissions to `AndroidManifest.xml`: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE` (needed for mDNS multicast)
- Fixed app label: `fluxora_mobile` → `Fluxora`
- Removed `better_player: ^0.0.84` from `pubspec.yaml` — missing `namespace` in its `build.gradle` causes AGP 8+ build failure; will use `media_kit` in Phase 2
- Removed `flutter_webrtc: ^0.10.0` from `pubspec.yaml` — uses removed v1 Flutter plugin API (`PluginRegistry.Registrar`), fails to compile; deferred to Phase 3 with v1.x+
- Removed auto-generated `test/widget_test.dart` (created by `flutter create`) — conflicts with existing test structure
- Fixed `services/discovery_service.py` — replaced synchronous `Zeroconf` with `AsyncZeroconf`; both `start_discovery()` and `stop_discovery()` are now `async def` using `async_register_service` / `async_unregister_service` / `async_close`; prevents `EventLoopBlocked` crash on startup
- Updated `main.py` lifespan — `await start_discovery(...)` and `await stop_discovery()`
- Created `%APPDATA%\Fluxora\.env` with `TOKEN_HMAC_KEY` and `FLUXORA_PORT=8080` — server was failing startup and broadcasting wrong port (8000 vs 8080)
- Configured `.vscode/launch.json` — Server, Server (reload), Mobile, Desktop configs + `Server + Mobile` / `Server + Desktop` compound configs
- Full doc sweep: updated frontend arch, tech stack, backend arch, infrastructure, roadmap, CLAUDE.md

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `apps/mobile/android/` (full platform tree) |
| Modified | `apps/mobile/android/app/src/main/AndroidManifest.xml` |
| Modified | `apps/mobile/pubspec.yaml` |
| Modified | `apps/server/services/discovery_service.py` |
| Modified | `apps/server/main.py` |
| Created | `C:\Users\marsh\AppData\Roaming\Fluxora\.env` |
| Modified | `.vscode/launch.json` |
| Modified | `docs/08_frontend/01_frontend_architecture.md` |
| Modified | `docs/02_architecture/02_tech_stack.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |
| Modified | `docs/05_infrastructure/01_infrastructure.md` |
| Modified | `docs/10_planning/01_roadmap.md` |
| Modified | `CLAUDE.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/08_frontend/01_frontend_architecture.md` | Full rewrite: actual implemented structure, routes, state classes, DI pattern, testing approach, tech decisions |
| `docs/02_architecture/02_tech_stack.md` | Split mobile packages into implemented vs deferred; noted `better_player` dropped, `flutter_webrtc` deferred to Phase 3 |
| `docs/09_backend/01_backend_architecture.md` | `discovery_service` noted as using `AsyncZeroconf`; `start_discovery`/`stop_discovery` marked async |
| `docs/05_infrastructure/01_infrastructure.md` | Platform data dir table added (Windows path is `%APPDATA%\Fluxora`); startup sequence updated to 10 steps; TOKEN_HMAC_KEY documented; VSCode launch configs documented; dev commands updated |
| `docs/10_planning/01_roadmap.md` | HLS player note updated: `better_player` → `media_kit`; M2 status updated |
| `CLAUDE.md` | Phase 1 mobile marked complete; `better_player` → `media_kit`; `flutter_webrtc` noted as Phase 3 only with version caveat; Known Risks updated; Current Status updated |

### Decisions Made
- `AsyncZeroconf` is required when running inside FastAPI lifespan — synchronous `Zeroconf.register_service()` calls `run_coro_with_timeout` which deadlocks on an already-running event loop
- `better_player` is permanently dropped — AGP 8+ requires `namespace` in build.gradle; the package is unmaintained and will not be fixed
- `flutter_webrtc` v0.10.x uses `PluginRegistry.Registrar` which was removed from the Flutter embedding; will use v1.x+ when Phase 3 begins
- `.env` on Windows lives at `%APPDATA%\Fluxora\.env` (not `~/.fluxora/.env` as the Linux-only comment in code implied)

### Blockers / Open Issues
- HLS player (`media_kit`) not yet added — Phase 2
- `flutter_webrtc` not yet added — Phase 3
- On-device pairing not yet verified (server running, mobile building)

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Verify on-device pairing works: run server → run mobile → approve pair request via `curl -X POST http://localhost:8080/api/v1/auth/approve/<client_id>`
3. Begin **Phase 2**: add `media_kit` for HLS player, wire `MediaCard.onTap` → start stream → `/player` screen
4. Begin **Desktop control panel** (`apps/desktop`) — Dashboard + Client approval UI so pairing can be approved without curl
5. Run `flutter analyze` + `flutter test` before declaring any Phase 2 work done
6. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-28] — On-device fixes: ApiClient URL, MulticastLock, port default
**Agent:** claude-sonnet-4-6
**Phase:** Phase 1 — Mobile on-device testing
**Status:** Complete

### What Was Done
- Fixed pairing failure: `ApiClient` had empty `baseUrl` when the pairing request was made — `configure(baseUrl: server.url)` now called in `ConnectScreen` at the point of server selection (both auto-discovered tile tap and manual entry connect button)
- Fixed manual entry default port: `8000` → `8080` to match server config
- Fixed mDNS auto-discovery on Android: Android silently drops multicast packets without a `WifiManager.MulticastLock`; implemented `MethodChannel('dev.marshalx.fluxora/multicast')` in `MainActivity.kt` exposing `acquire`/`release`; `ConnectCubit.startDiscovery()` acquires lock before scanning, releases in `stopDiscovery()` and `close()`; failure is non-fatal (iOS/desktop platforms silently continue)

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/mobile/lib/features/connect/presentation/screens/connect_screen.dart` |
| Modified | `apps/mobile/lib/features/connect/presentation/cubit/connect_cubit.dart` |
| Modified | `apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/MainActivity.kt` |
| Modified | `docs/08_frontend/01_frontend_architecture.md` |
| Modified | `CLAUDE.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/08_frontend/01_frontend_architecture.md` | Added MulticastLock and ApiClient.configure() to key decisions; updated connect feature description |
| `CLAUDE.md` | Updated Known Risks: mDNS on Android — mitigation now describes the implemented MulticastLock channel |

### Decisions Made
- `ApiClient.configure()` called from `ConnectScreen` (presentation layer) via `GetIt.I<ApiClient>()` — acceptable because this is DI resolution, not a direct HTTP call; it is the correct moment since the user has explicitly selected a server
- MulticastLock failure is caught and logged as warning, not error — iOS and desktop platforms don't have the channel and must continue working

### Blockers / Open Issues
- Router AP isolation may still prevent mDNS if the MulticastLock fix isn't enough — manual entry always works
- Confirmed: pairing flow works end-to-end (pair request → server approval → token stored → library screen)

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Phase 1 is fully working on-device — begin **Phase 2: HLS player**
3. Add `media_kit` to `pubspec.yaml` for HLS `.m3u8` playback
4. Wire `MediaCard.onTap` → `POST /stream/start/{file_id}` → navigate to `/player` with session
5. Build the player screen with play/pause, seek, and stop (DELETE /stream/{session_id})
6. Also consider: **Desktop control panel** (`apps/desktop`) — client approval UI so pairing doesn't require curl
7. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-28] — Phase 1 complete: HLS player with media_kit
**Agent:** claude-sonnet-4-6
**Phase:** Phase 1 — HLS Player (final item)
**Status:** Complete — M2 LAN Streaming MVP is now fully done

### What Was Done
- Added `media_kit` ^1.2.6, `media_kit_video` ^2.0.1, `media_kit_libs_video` ^1.0.7 to `pubspec.yaml`
- Added `MediaKit.ensureInitialized()` to `main.dart` before `runApp()`
- Updated `packages/fluxora_core` `Endpoints`: replaced incorrect `stream(fileId)` with `streamStart(fileId)` (`/api/v1/stream/start/$fileId`) and `streamSession(sessionId)` (`/api/v1/stream/$sessionId`)
- Built `features/player` Clean Architecture stack:
  - `domain/entities/stream_start_response.dart` — plain Dart DTO (sessionId, fileId, playlistUrl)
  - `domain/repositories/player_repository.dart` — interface: `startStream`, `stopStream`
  - `data/repositories/player_repository_impl.dart` — POST `/stream/start`, DELETE `/stream/:id`
  - `presentation/cubit/player_state.dart` — sealed: `PlayerInitial / Loading / Ready / Failure`; uses `show` imports to avoid name conflict with `media_kit`'s own `PlayerState`
  - `presentation/cubit/player_cubit.dart` — calls `startStream`, reads bearer token from `SecureStorage`, injects it as `Media(httpHeaders:)` so HLS segment requests are authenticated; calls `stopStream` on `close()`
  - `presentation/screens/player_screen.dart` — full-screen `Video` widget with `MaterialVideoControls`; landscape + `immersiveSticky` on init, restores portrait on dispose; back button + title overlay
- Registered `PlayerRepository` (`registerLazySingleton`) in `injector.dart`
- Added `/player` route to `app_router.dart`; wired `MediaCard.onTap` in `FilesScreen` to `context.push(Routes.player, extra: files[index])`
- Wrote `test/features/player/player_cubit_test.dart` — 7 tests (initial state, repository called, loading emitted, API error, generic error, stopStream on close, no stopStream if never started)
- Fixed name conflict: `media_kit` exports `PlayerState`; resolved with `import 'package:media_kit/media_kit.dart' show Player, Media'` everywhere
- Fixed `.gitignore`: `.vscode/*` + `!.vscode/launch.json` so `launch.json` is tracked but personal settings are not

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `apps/mobile/lib/features/player/domain/entities/stream_start_response.dart` |
| Created | `apps/mobile/lib/features/player/domain/repositories/player_repository.dart` |
| Created | `apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart` |
| Created | `apps/mobile/lib/features/player/presentation/cubit/player_state.dart` |
| Created | `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart` |
| Created | `apps/mobile/lib/features/player/presentation/screens/player_screen.dart` |
| Created | `apps/mobile/test/features/player/player_cubit_test.dart` |
| Modified | `apps/mobile/pubspec.yaml` |
| Modified | `apps/mobile/lib/main.dart` |
| Modified | `apps/mobile/lib/core/di/injector.dart` |
| Modified | `apps/mobile/lib/core/router/app_router.dart` |
| Modified | `apps/mobile/lib/features/library/presentation/screens/files_screen.dart` |
| Modified | `packages/fluxora_core/lib/network/endpoints.dart` |
| Modified | `.gitignore` |
| Modified | `docs/10_planning/01_roadmap.md` |
| Modified | `docs/08_frontend/01_frontend_architecture.md` |
| Modified | `CLAUDE.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/10_planning/01_roadmap.md` | HLS playback marked ✅ Done; M2 milestone marked ✅ Done |
| `docs/08_frontend/01_frontend_architecture.md` | PlayerScreen marked done in route map; `features/player` added to project structure tree |
| `CLAUDE.md` | Current Status updated: Phase 1 fully complete (24 tests); media_kit versions noted; Next updated to Phase 2 desktop control panel |

### Decisions Made
- `media_kit` imports must use `show` to avoid conflict with its own exported `PlayerState` class — applies to `player_state.dart`, `player_cubit.dart`, and `player_screen.dart`
- Bearer token is injected into `Media(httpHeaders:)` rather than through a custom HTTP interceptor — media_kit makes its own HTTP requests for HLS segments so the `ApiClient` Dio interceptor doesn't cover them
- `PlayerReady` state holds `Player` and `VideoController` directly — standard pattern for media_kit + BLoC; avoids an extra getter on the cubit
- `PlayerReady` path cannot be unit-tested headlessly (requires native media_kit libs); tests cover repository calls, error states, and cleanup behavior instead

### Blockers / Open Issues
- Player screen untested on physical device — needs live HLS stream from the FastAPI server to verify playback
- `flutter_webrtc` still deferred to Phase 3

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. **M2 is complete** — begin Phase 2
3. Priority 1: **Desktop control panel** (`apps/desktop`) — at minimum: dashboard showing server status + active streams, and a Clients screen to approve/revoke paired devices (so curl is no longer needed for pairing)
4. Priority 2: TMDB metadata integration — posters + descriptions on library/media cards
5. Test the player on a physical device: `flutter run` → browse library → tap a file → video should play
6. Run `flutter analyze && flutter test` before declaring any Phase 2 work done
7. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---
