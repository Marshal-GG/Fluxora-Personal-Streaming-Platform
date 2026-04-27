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
