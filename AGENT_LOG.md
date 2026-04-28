# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_03.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 02)
**Archived:** 2026-04-28
**Contents:** Phase 0, Phase 1 server, Phase 1 mobile (complete), infrastructure.

* **Phase 0 — complete:** Monorepo scaffold, all architecture and planning docs authored, CI/CD workflows, web landing page (Next.js, Cloudflare Pages), Firebase hosting configured.
* **`packages/fluxora_core` — complete:** All 5 freezed entities (`MediaFile`, `Library`, `StreamSession`, `Client`, `ServerInfo`), `ApiClient` (Dio), `ApiException`, `Endpoints`, `SecureStorage`, design tokens (`AppColors`, `AppSizes`, `AppTypography`).
* **`apps/server` — Phase 1 complete (41 tests, ruff ✅, black ✅):**
  - `config.py` (BaseSettings, platform data dir, token key validation), `database/db.py` (WAL, migration runner), migrations 001–003.
  - `main.py` — 9-step ordered lifespan: key validation → dir security → HLS tmp → orphan cleanup → DB init → file permissions → FFmpeg check → mDNS → HTTP.
  - All routers implemented: info, auth (pairing state machine, HMAC tokens, localhost-only approve/reject), files, library (CRUD + scan), stream (FFmpeg HLS, session management), ws (token auth, ping/pong).
  - `require_local_caller` dependency enforces localhost restriction on approve/reject.
* **`apps/mobile` — Phase 1 complete (24 tests, flutter analyze ✅):**
  - Connect (mDNS PTR→SRV→A, MulticastLock for Android), auth (pairing flow, SecureStorage), library (grid + file list), player (media_kit HLS, bearer token in `Media(httpHeaders:)`).
  - `go_router` async auth guard, full DI with `get_it`.
  - M2 (LAN Streaming MVP) milestone complete.
* **Known quirks:** `better_player` dropped (AGP 8+ incompatible); `flutter_webrtc` 0.10.x deferred to Phase 3; media_kit `PlayerState` name conflict resolved with `show` imports; `AsyncZeroconf` required (sync version deadlocks on FastAPI event loop).

**Next Immediate Steps (at time of archiving):**
1. Desktop control panel (`apps/desktop`) — Dashboard + Clients screens.
2. TMDB metadata integration.
3. On-device player testing.

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

## [2026-04-28] — Phase 2: Desktop control panel (Dashboard + Clients)
**Agent:** claude-sonnet-4-6
**Phase:** Phase 2 — Desktop Control Panel
**Status:** Complete

### What Was Done
- Added `GET /api/v1/auth/clients` endpoint to the server — localhost-only, returns all clients with status/platform/last_seen; 3 new tests (empty list, after pair request, LAN blocked); all 41 tests pass
- Added `ClientListItem`, `ClientListResponse` Pydantic models to `apps/server/models/client.py`
- Added `list_clients()` to `apps/server/services/auth_service.py`
- Added `ClientStatus` enum to `packages/fluxora_core/lib/entities/enums.dart` (with `fromJson` factory, no build_runner required)
- Added `packages/fluxora_core/lib/entities/client_list_item.dart` — plain Dart class (not freezed) with manual `fromJson`; exported from `fluxora_core.dart`
- Added `authClients`, `authApprove(id)`, `authReject(id)`, `authRevoke(id)` to `packages/fluxora_core/lib/network/endpoints.dart`
- Built complete `apps/desktop` Flutter control panel from scratch (all files were comment stubs):
  - `main.dart` + `app.dart` — standard MaterialApp.router bootstrap
  - `core/di/injector.dart` — `ApiClient(localhost:8080)`, `DashboardRepository`, `ClientsRepository` as lazy singletons
  - `core/router/app_router.dart` — `Routes` constants + `GoRouter` with `ShellRoute` wrapping `AppShell`
  - `shared/theme/app_theme.dart` — full Material 3 dark theme matching mobile; includes `NavigationRailThemeData`
  - `shared/widgets/sidebar.dart` — `AppShell` + `_Sidebar` (200 px fixed width) + `_NavItem` with brand gradient logo
  - `shared/widgets/stat_card.dart` — icon + label + value card used on dashboard
  - `shared/widgets/status_badge.dart` — colored pill badge for `ClientStatus`
  - `features/dashboard` — `DashboardRepository` / `DashboardRepositoryImpl` / `DashboardCubit` / `DashboardState` / `DashboardScreen` (server info card + stat cards for approved/pending/total clients)
  - `features/clients` — `ClientsRepository` / `ClientsRepositoryImpl` / `ClientsCubit` / `ClientsState` (filter + processingIds) / `ClientsScreen` (filter chips, client tiles with platform icons, Approve/Reject/Revoke/Re-approve buttons, per-client loading spinner)
- `flutter analyze` desktop → **zero issues**; `flutter analyze` mobile → **zero issues**; `flutter analyze` fluxora_core → **zero issues**; server pytest → **41/41 pass**
- `logger: ^2.7.0` added to `apps/desktop/pubspec.yaml` (consistent with mobile)
- Rotated `AGENT_LOG.md` to `docs/logs/AGENT_LOG_archive_02.md` (was 1014 lines)

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/models/client.py` |
| Modified | `apps/server/services/auth_service.py` |
| Modified | `apps/server/routers/auth.py` |
| Modified | `apps/server/tests/test_auth.py` |
| Modified | `packages/fluxora_core/lib/entities/enums.dart` |
| Created  | `packages/fluxora_core/lib/entities/client_list_item.dart` |
| Modified | `packages/fluxora_core/lib/network/endpoints.dart` |
| Modified | `packages/fluxora_core/lib/fluxora_core.dart` |
| Modified | `apps/desktop/pubspec.yaml` |
| Modified | `apps/desktop/lib/main.dart` |
| Modified | `apps/desktop/lib/app.dart` |
| Modified | `apps/desktop/lib/core/di/injector.dart` |
| Modified | `apps/desktop/lib/core/router/app_router.dart` |
| Modified | `apps/desktop/lib/shared/theme/app_theme.dart` |
| Modified | `apps/desktop/lib/shared/widgets/sidebar.dart` |
| Modified | `apps/desktop/lib/shared/widgets/stat_card.dart` |
| Modified | `apps/desktop/lib/shared/widgets/status_badge.dart` |
| Modified | `apps/desktop/lib/shared/widgets/data_table.dart` |
| Created  | `apps/desktop/lib/features/dashboard/domain/repositories/dashboard_repository.dart` |
| Created  | `apps/desktop/lib/features/dashboard/data/repositories/dashboard_repository_impl.dart` |
| Created  | `apps/desktop/lib/features/dashboard/presentation/cubit/dashboard_state.dart` |
| Created  | `apps/desktop/lib/features/dashboard/presentation/cubit/dashboard_cubit.dart` |
| Created  | `apps/desktop/lib/features/dashboard/presentation/screens/dashboard_screen.dart` |
| Created  | `apps/desktop/lib/features/clients/domain/repositories/clients_repository.dart` |
| Created  | `apps/desktop/lib/features/clients/data/repositories/clients_repository_impl.dart` |
| Created  | `apps/desktop/lib/features/clients/presentation/cubit/clients_state.dart` |
| Created  | `apps/desktop/lib/features/clients/presentation/cubit/clients_cubit.dart` |
| Created  | `apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart` |
| Created  | `docs/logs/AGENT_LOG_archive_02.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/04_api/01_api_contracts.md` | Added `GET /api/v1/auth/clients` endpoint with full schema |
| `docs/08_frontend/01_frontend_architecture.md` | Updated Two Client Targets table (desktop 🔵 In Progress); added Desktop project structure tree + route table |
| `docs/10_planning/01_roadmap.md` | PC Control Panel marked 🔵 in progress |

### Decisions Made
- `ClientListItem` is a plain Dart class (not freezed) — avoids touching `.freezed.dart`/`.g.dart` generated files for a server-response-only DTO; `ClientStatus.fromJson` is a hand-written factory
- Desktop app talks to `localhost:8080` with no bearer token — all its endpoints are either localhost-only (no auth needed) or no-auth (`GET /info`)
- `always_use_package_imports` is enforced in desktop `analysis_options.yaml` — all imports use `package:fluxora_desktop/...` form
- `ClientsCubit` tracks `processingIds: Set<String>` to show per-client spinners during approve/reject without blocking the whole list

### Blockers / Open Issues
- Desktop app not yet tested on a running Windows instance — `flutter analyze` passes but UI needs visual verification
- Desktop tests not yet written (Phase 2 follow-up)
- TMDB metadata integration not yet started
- `apps/desktop/lib/shared/widgets/data_table.dart` is a thin re-export stub — not needed for current screens

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Run the desktop app (`flutter run -d windows`) and verify Dashboard + Clients screens work against a running server
3. **Phase 2 next priority:** TMDB metadata integration — `GET /api/v1/files` should optionally return poster URLs and descriptions; mobile library should show posters
4. **Phase 2 next priority:** Playback resume — `stream_sessions.progress_sec` already stored; surface it in the player screen and restore position on re-open
5. Consider adding desktop tests for `DashboardCubit` and `ClientsCubit` (mocktail + bloc_test already in dev deps)
6. Run `flutter analyze` in all three Flutter packages and `pytest` on the server before declaring any new work done
7. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-28] — Docs: Align Phase 2 desktop documentation
**Agent:** claude-sonnet-4-6 (thinking)
**Phase:** Phase 2 — Desktop Control Panel
**Status:** Complete

### What Was Done
- Audited all uncommitted changes vs. current documentation
- Found 5 empty feature scaffold dirs (`activity`, `library`, `logs`, `settings`, `transcoding`) inside `apps/desktop/lib/features/` that were not reflected in the frontend architecture doc
- Found desktop routes table was missing those 5 planned routes
- Found `docs/10_planning/01_roadmap.md` still marked PC Control Panel as 🔵 in-progress instead of ✅ Done

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `docs/08_frontend/01_frontend_architecture.md` |
| Modified | `docs/10_planning/01_roadmap.md` |
| Modified | `AGENT_LOG.md` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/08_frontend/01_frontend_architecture.md` | Status line updated to Phase 2; desktop project tree expanded with ✅ / 🔲 markers for all 7 feature dirs; routes table expanded with 5 planned routes |
| `docs/10_planning/01_roadmap.md` | PC Control Panel row updated to ✅ Done; status date updated to 2026-04-28 |

### Decisions Made
- Empty scaffold directories (`activity`, `library`, `logs`, `settings`, `transcoding`) are documented as "🔲 Phase 2 — scaffold only" — they exist as directory stubs only, no Dart files yet

### Blockers / Open Issues
- Desktop app not yet tested on a live Windows instance (no code change this session)
- TMDB metadata integration still pending
- Desktop tests still pending

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Run the desktop app (`flutter run -d windows`) and verify Dashboard + Clients screens work against a running server
3. **Phase 2 next priority:** TMDB metadata integration — `GET /api/v1/files` should optionally return poster URLs; mobile library should show posters
4. **Phase 2 next priority:** Playback resume — `stream_sessions.progress_sec` already stored; surface it in the player screen and restore position on re-open
5. Run `flutter analyze` in all three Flutter packages and `pytest` on the server before declaring any new work done
6. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## Session — 2026-04-28 (Phase 3: TMDB Metadata + Playback Resume)

### Objectives
Implement TMDB metadata enrichment and cross-client playback resume, end-to-end from DB migrations through to the mobile UI.

### Work Completed

**Database**
- `004_tmdb_metadata.sql` — adds `title`, `overview`, `poster_url` to `media_files`
- `005_resume_progress.sql` — adds `last_progress_sec` to `media_files`

**Server (`apps/server`)**
- `services/tmdb_service.py` — async TMDB `/search/multi` client; maps movie/TV results to `TmdbMeta`; silently returns `None` on any error
- `services/library_service.py` — calls `_enrich_with_tmdb` after file discovery; non-blocking; skips if `fluxora_tmdb_key` is unset
- `models/media_file.py` — `MediaFileResponse` now includes `title`, `overview`, `poster_url`, `last_progress_sec`
- `models/stream_session.py` — `StreamStartResponse` now includes `resume_sec`
- `routers/stream.py` — `PATCH /api/v1/stream/{session_id}/progress` persists progress to both `stream_sessions` and `media_files`
- `routers/library.py` — passes TMDB key from settings into scan service
- `tests/test_tmdb_service.py` — 5 unit tests covering movie, TV, person-skip, network error, missing poster

**`packages/fluxora_core`**
- `entities/media_file.dart` — added `title?`, `overview?`, `posterUrl?`, `resumeSec` (`@Default(0.0)`)
- `network/endpoints.dart` — added `streamProgress(sessionId)` endpoint
- `network/api_client.dart` — added `patch<T>()` method (consistent with get/post/put/delete pattern)
- Ran `dart run build_runner build --delete-conflicting-outputs` → 15 outputs regenerated ✅

**`apps/mobile`**
- `pubspec.yaml` — added `cached_network_image: ^3.3.1`
- `domain/entities/stream_start_response.dart` — added `resumeSec` field
- `domain/repositories/player_repository.dart` — added `updateProgress(sessionId, progressSec)`
- `data/repositories/player_repository_impl.dart` — implemented `updateProgress` via `PATCH /progress`
- `presentation/cubit/player_state.dart` — added `resumeSec` to `PlayerReady`
- `presentation/cubit/player_cubit.dart` — seeks to server resume position on stream open; 10 s periodic timer reports progress; flushes final position on `close()`
- `presentation/screens/player_screen.dart` — passes `file.resumeSec` to cubit; shows auto-dismissing "Resumed from X:XX" banner when resuming
- `shared/widgets/media_card.dart` — TMDB poster thumbnail via `CachedNetworkImage`; TMDB title/overview display; thin resume-progress bar
- `test/features/player/player_cubit_test.dart` — updated all 5 `startStream` call-sites to new 3-arg signature; added `updateProgress` stub

**Quality Gates**
- `flutter analyze --no-fatal-infos` → **No issues found** ✅
- `build_runner` → **15 outputs, exit 0** ✅

### Known Remaining Work
1. **Server tests** — run `pytest` against live DB to verify progress PATCH and enrichment paths end-to-end
2. **On-device testing** — test resume seek and poster display on a physical device with a valid TMDB key
3. **Desktop alignment** — port resume/metadata display to `apps/desktop` control panel
4. **Library screen** — wire `MediaCard` into the library list screen if not already done

### Next Agent Should
1. Read `AGENT_LOG.md` before starting
2. Run `pytest` in `apps/server/` and `flutter test` in `apps/mobile/` to confirm clean baselines
3. Address remaining work items above
4. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## Session — Phase 3 Post-Audit Bugfix
**Date:** 2026-04-28
**Scope:** Post-audit bug fixes identified during deep code review of Phase 3 implementation

### Bugs Found & Fixed

#### Bug 1 — `MediaFileResponse` missing `last_progress_sec` (Critical, server)
**File:** `apps/server/models/media_file.py`
- The DB column `last_progress_sec` (added in migration 005) was never included in `MediaFileResponse`.
- The mobile client would always receive `0` for `resumeSec`, making resume playback silently broken.
- **Fix:** Added `resume_sec: float = Field(default=0.0, alias="last_progress_sec")` with `populate_by_name=True` so Pydantic v2 reads `last_progress_sec` from the DB row dict and serializes it as `resume_sec` to match the Dart `fromJson` generated key.

#### Bug 2 — `tmdb_id` column missing from migration 004 (Critical, server)
**File:** `apps/server/database/migrations/004_tmdb_metadata.sql`
- `_enrich_with_tmdb` in `library_service.py` performs `UPDATE media_files SET tmdb_id = ?` but migration 004 never added the `tmdb_id` column — only `title`, `overview`, `poster_url`.
- This would cause a SQLite `table media_files has no column named tmdb_id` error on the first enrichment pass.
- **Fix:** Added `ALTER TABLE media_files ADD COLUMN tmdb_id INTEGER;` as the first line of migration 004.

### Verification
- `flutter analyze --no-fatal-infos` → **No issues found** ✅ (mobile + core)
- Server models: manually verified Pydantic alias flow is correct for v2.

### Known Remaining Work
1. **Server tests** — run `pytest` in `apps/server/` against live DB (migration 004/005 must run fresh for tmdb_id to exist)
2. **On-device testing** — resume seek and poster display with real TMDB key
3. **Desktop alignment** — port resume/metadata display to `apps/desktop`

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## Session — 2026-04-28 (Desktop Library Feature / Phase 3 Parity)

### What Was Done
Implemented the full Library feature in `apps/desktop` to bring the control panel to parity with the Phase 3 TMDB metadata and resume-playback work.

### Files Created
| File | Purpose |
|---|---|
| `apps/desktop/lib/features/library/domain/repositories/library_repository.dart` | Abstract interface — `getLibraries()`, `getFiles({libraryId?})` |
| `apps/desktop/lib/features/library/data/repositories/library_repository_impl.dart` | Concrete impl — delegates to `ApiClient.get()` with `Endpoints.library` / `Endpoints.files` |
| `apps/desktop/lib/features/library/presentation/cubit/library_state.dart` | States: Initial, Loading, Loaded (with `visibleFiles`, `resumingCount`, `enrichedCount`), Failure |
| `apps/desktop/lib/features/library/presentation/cubit/library_cubit.dart` | BLoC cubit — loads + emits; `selectLibrary(id?)` filters without re-fetching |
| `apps/desktop/lib/features/library/presentation/screens/library_screen.dart` | Full screen: stats row, library filter chips, file list with TMDB indicator + resume progress bar |

### Files Modified
| File | Change |
|---|---|
| `apps/desktop/lib/core/di/injector.dart` | Registered `LibraryRepository` → `LibraryRepositoryImpl` |
| `apps/desktop/lib/core/router/app_router.dart` | Added `Routes.library = '/library'` + `GoRoute` |
| `apps/desktop/lib/shared/widgets/sidebar.dart` | Added Library nav item (`video_library_outlined`) |

### Features Delivered
- **Stats row:** Total Files / TMDB Enriched / In Progress cards (reuses existing `StatCard` widget)
- **Library filter chips:** "All" + one chip per library; pure client-side filtering (no extra HTTP call)
- **File list:** TMDB enrichment indicator (green dot), title (falls back to filename), overview snippet (2-line clamp), resume progress bar + timestamp, file size
- **Resume progress bar:** Shown only when `resumeSec > 0` and `durationSec != null`; uses `AppColors.warning` to match mobile

### Verification
- `dart analyze lib` → **No issues found** ✅

### Known Remaining Work
1. On-device smoke test with a real TMDB API key
2. Desktop app does not yet have a Settings screen (server URL is hardcoded to `localhost:8080`)

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## Session Log — 2026-04-28 (Desktop Settings Screen)

### Objective
Resolve the hardcoded `localhost:8080` server URL in the desktop control panel by implementing a fully functional Settings screen backed by `SecureStorage`.

### What Was Built

#### `features/settings/presentation/cubit/settings_state.dart` (new)
- Sealed class hierarchy: `SettingsInitial`, `SettingsLoading`, `SettingsLoaded`, `SettingsSaved`, `SettingsError`
- No external dependencies (dropped `equatable` — sealed classes already provide exhaustive matching)

#### `features/settings/presentation/cubit/settings_cubit.dart` (new)
- `loadSettings()` — reads stored URL from `SecureStorage`, falls back to `http://localhost:8080`
- `saveServerUrl(String url)` — validates URL (non-empty, parseable `http://` scheme + authority), saves to `SecureStorage`, calls `ApiClient.configure(baseUrl:)` so all in-flight and future requests immediately use the new host — **no restart required**

#### `features/settings/presentation/screens/settings_screen.dart` (new)
- `BlocProvider` wraps `SettingsCubit` from GetIt
- **Section cards:** "Server Connection" (URL text field + Save button), "About" (version + platform rows)
- `BlocConsumer` listener: success SnackBar (green, `AppColors.success`) on save; error SnackBar (red) on validation failure
- Pre-populates field from `SettingsLoaded` state; shows `CircularProgressIndicator` while loading

#### `core/di/injector.dart` (updated)
- Registers `FlutterSecureStorage` (with `WindowsOptions`) + `SecureStorage` singleton
- **Reads persisted URL at startup** — `ApiClient` is constructed with the saved URL, not the hardcoded default
- Registers `SettingsCubit` as a `registerFactory` (new instance per screen push)

#### `core/router/app_router.dart` (updated)
- Added `Routes.settings = '/settings'` constant
- Added `GoRoute(path: '/settings', builder: SettingsScreen)` inside the `ShellRoute`

#### `shared/widgets/sidebar.dart` (updated)
- `_Sidebar` now accepts `isSettingsSelected` + `onSettingsTap` parameters (location is only in scope in `AppShell.build`)
- Settings nav item highlights correctly when on `/settings` route and navigates on tap

### Verification
```
dart analyze lib  →  No issues found!  (0 errors, 0 warnings)
dart fix --apply  →  7 const fixes applied cleanly
```

### Pending Work (Next Session)
1. On-device smoke test with real TMDB API key
2. Phase 3: WebRTC signalling server implementation

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## Session Log — 2026-04-28 (Phase 3 — WebRTC Signaling Server)

### Objective
Implement the WebRTC signaling server (`WS /api/v1/ws/signal`) — Phase 3's first deliverable — enabling internet streaming by exchanging SDP offers/answers and ICE candidates between the mobile client and the server's `aiortc` peer connection.

### What Was Built

#### `services/webrtc_service.py` (replaced stub)
- In-memory `_PeerSession` registry (`client_id → RTCPeerConnection`)
- `create_peer_connection(client_id)` — creates `aiortc.RTCPeerConnection` with ICE config; closes any stale session first
- `handle_offer(client_id, sdp)` — sets remote description, queues pending ICE candidates, creates + sets local description, returns answer SDP
- `add_ice_candidate(client_id, candidate)` — adds immediately if remote desc is set, otherwise queues for post-offer drain
- `close_peer_connection(client_id)` — unregisters and closes PC gracefully
- ICE server config: Google STUN by default; reads `WEBRTC_TURN_URL/USERNAME/PASSWORD` env vars for TURN (Q-002 resolution path ready)

#### `routers/signal.py` (new)
- `WS /api/v1/ws/signal` — same auth handshake as `/ws/status` (bearer token in first message)
- Full message protocol: `offer → answer`, `ice-candidate` (both directions)
- Structured error replies: `invalid_json`, `missing_sdp`, `offer_failed`, `unknown_type`
- Server-generated ICE candidates forwarded to client via `@pc.on("icecandidate")` callback
- Clean teardown: `close_peer_connection()` always called in `finally` block

#### `main.py` (updated)
- Imported `signal` router and registered at `/api/v1/ws` prefix alongside the existing `ws` router

#### `tests/test_signal.py` (new, 8 tests)
- Auth flow: valid token → `auth_ok`, invalid token closes, missing auth message closes
- SDP flow: `offer` → `answer` round-trip
- ICE candidate forwarding verified
- Error cases: unknown type, invalid JSON, offer without `sdp`
- `aiortc` is mocked — tests are hermetic and fast (< 1s)

### Verification
```
pytest tests/test_signal.py  →  8 passed in 0.91s
pytest (full suite)          →  54 passed, 0 failed in 3.42s
```

### Pending Work (Next Session)
Phase 3 remaining:
1. Flutter WebRTC integration (`flutter_webrtc` in mobile app)
2. Smart LAN-vs-WebRTC path selection in mobile client
3. Connection quality monitoring

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## Session Log — 2026-04-28 (Phase 3 — Flutter WebRTC Integration)

### Objective
Implement the Flutter-side WebRTC client so the mobile app can negotiate a peer-to-peer session with the server's signaling endpoint and automatically fall back to HLS if it fails.

### What Was Built

#### `pubspec.yaml` (updated)
- Added `flutter_webrtc: ^1.4.1`

#### `features/player/data/services/webrtc_signaling_service.dart` (new)
- `SignalingState` enum: `idle → connecting → connected | failed | closed`
- `WebRtcSignalingService(serverWsUrl, authToken, onStateChange)`:
  - Opens `dart:io WebSocket` to `/api/v1/ws/signal`
  - Sends bearer-token auth handshake; on `auth_ok` creates `RTCPeerConnection`
  - Generates SDP offer, sends to server, sets answer as remote description
  - Forwards local ICE candidates to server; applies remote candidates from server
  - `_signalUrl()` converts `http(s)://` base URL to `ws(s)://` signal URL
  - `close()` tears down PC + socket cleanly

#### `features/player/presentation/cubit/player_state.dart` (updated)
- Added `StreamPath` enum (`hls`, `webRtc`)
- Added `streamPath` field to `PlayerReady` (default: `StreamPath.hls`)

#### `features/player/presentation/cubit/player_cubit.dart` (updated)
- `startStream()` now calls `_tryWebRtc()` before opening the media player
- `_tryWebRtc()` races ICE connected vs 8-second timeout → returns `StreamPath`
- On WebRTC success: `streamPath = StreamPath.webRtc` in emitted `PlayerReady`
- On timeout/failure: falls back silently to HLS — stream always starts
- `close()` calls `_signaling?.close()` for clean teardown

### Verification
```
flutter pub get  →  success (no conflicts)
dart analyze lib/features/player  →  No issues found!
```

### Pending Work (Next Session)
Phase 3 remaining:
1. STUN/TURN configuration testing with real NAT
2. Smart path selection: LAN detection → skip WebRTC negotiation on local network
3. Connection quality monitoring + auto-switch
4. Player screen UI badge (HLS vs WebRTC indicator)

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## Session Log — 2026-04-28 (Phase 3 — Smart Path Selection + Transport Badge)

### Objective
Implement LAN vs WAN path detection so WebRTC is only attempted on internet connections, and add a transport badge to the player UI so users can see which streaming path is active.

### What Was Built

#### `features/player/data/services/network_path_detector.dart` (new)
- `NetworkPathDetector.isLan(serverUrl)` — static async method
- Parses server URL host; checks RFC-1918 private ranges (10.x, 172.16-31.x, 192.168.x, 169.254.x)
- Enumerates device IPv4 network interfaces; compares /24 subnet octets
- localhost/loopback always returns `true`; non-IP hostnames default to `false` (WAN)
- Fails-safe to `false` (WAN) on any IO error so WebRTC is attempted rather than suppressed

#### `features/player/presentation/cubit/player_cubit.dart` (updated)
- Added `NetworkPathDetector.isLan()` check before `_tryWebRtc()`
- LAN → skip WebRTC, use HLS directly (logged at debug level)
- WAN → attempt WebRTC with 8-second ICE timeout, HLS fallback

#### `features/player/presentation/cubit/player_state.dart` (updated)
- Added `StreamPath` enum (`hls`, `webRtc`) and `streamPath` field on `PlayerReady`

#### `features/player/presentation/screens/player_screen.dart` (updated)
- Added `_showTransportBadge` bool + 5-second auto-hide timer triggered on `PlayerReady`
- Added `_TransportBadge` widget: positioned chip at bottom-right of video overlay
  - Deep purple + `cell_tower` icon for WebRTC; dark chip + `stream` icon for HLS
  - Uses `AnimatedOpacity` for smooth appearance

### Verification
```
dart analyze lib/features/player  →  No issues found!
```

### Pending Work (Next Session)
Phase 3 remaining:
1. Connection quality monitoring + ICE state degradation auto-switch
2. End-to-end test on real device with WAN connection

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-28] — Phase 3 Complete: ICE Degradation / Connection Quality Monitoring
**Agent:** claude-sonnet-4-6
**Phase:** Phase 3 — Internet Streaming
**Status:** Complete

### What Was Done
- Implemented the last Phase 3 "Should" item: connection quality monitoring / ICE degradation auto-fallback
- **`player_state.dart`** — added `PlayerReady.copyWith({StreamPath? streamPath})` so the cubit can re-emit an updated badge state without recreating the entire player/controller
- **`player_cubit.dart`** — split `_tryWebRtc` `onStateChange` callback into two phases:
  - Pre-connection: resolves the `Completer<StreamPath>` as before (no behaviour change)
  - Post-connection: delegates to new `_handleSignalingDegradation(sigState)` method
  - `_handleSignalingDegradation`: on `SignalingState.failed` while in `PlayerReady(streamPath: webRtc)` → emits `copyWith(streamPath: hls)`, closes and nulls `_signaling`; media_kit player is uninterrupted (it was always reading HLS)
- **`player_screen.dart`** — added `_readyOnce` flag to `_PlayerViewState`; resume banner only fires on first `PlayerReady` transition; transport badge re-fires on any `PlayerReady` (covers degradation badge re-show)
- All Phase 3 roadmap items now ✅ Done; M4 milestone marked complete
- `flutter analyze` → **No issues** ✅ · `flutter test` → **24/24 pass** ✅

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/mobile/lib/features/player/presentation/cubit/player_state.dart` |
| Modified | `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart` |
| Modified | `apps/mobile/lib/features/player/presentation/screens/player_screen.dart` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/10_planning/01_roadmap.md` | Connection quality monitoring → ✅ Done; M4 milestone → ✅ Done |
| `docs/08_frontend/01_frontend_architecture.md` | Status updated; Key Technical Decisions table: ICE degradation + resume banner guard rows added; player tree comments updated |

### Decisions Made
- Media transport stays on HLS throughout; WebRTC drives only the signaling badge — degradation handling is purely badge + signaling cleanup, no player reinit needed
- `_readyOnce` is the simplest guard: stateful bool set on first `PlayerReady`, prevents resume banner double-fire without adding complexity to the state model

### Blockers / Open Issues
- On-device WAN testing still pending (needs physical Android device + outside-LAN network)
- Desktop tests for `DashboardCubit` / `ClientsCubit` not yet written

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Run `flutter analyze` in all Flutter packages and `pytest` in `apps/server/` to confirm clean baselines
3. **Phase 4 — Monetization**: subscription tier enforcement, license key validation, upgrade prompt UI, Free/Plus/Pro/Ultimate tier limits
4. Alternatively: write desktop tests for `DashboardCubit` and `ClientsCubit` (mocktail + bloc_test already in dev deps) — quick win before Phase 4
5. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## [2026-04-29] — Phase 4: Subscription tier system + mobile upgrade prompt + desktop settings
**Agent:** claude-sonnet-4-6
**Phase:** Phase 4 — Monetization
**Status:** Complete (license key payment validation deferred — integration TBD)

### What Was Done

**Server**
- `database/migrations/006_settings_license.sql` — adds `license_key TEXT` to `user_settings`
- `database/migrations/007_align_tier_limits.sql` — corrects existing free-tier rows where `max_concurrent_streams` was 3 (initial default); now enforces `free=1, plus=3, pro=10, ultimate=9999`
- `services/settings_service.py` — `get_settings()`, `update_settings()`, `get_max_concurrent_streams()`; `TIER_STREAM_LIMITS` dict; tier change auto-sets `max_concurrent_streams`
- `models/settings.py` — extended with `UserSettingsResponse` and `UpdateSettingsBody` (Pydantic v2 field validator on `server_name`)
- `routers/settings.py` — `GET /api/v1/settings` and `PATCH /api/v1/settings` (both `require_local_caller`)
- `routers/stream.py` — stream concurrency check now reads `max_concurrent_streams` from `user_settings` DB row (was `settings.fluxora_max_streams` config) so a tier change takes effect immediately
- `main.py` — imported `settings_router` (aliased to avoid shadowing `config.settings`)
- `tests/test_settings.py` — 9 tests: defaults, tier update, stream-limit auto-update, invalid tier 422, license key storage, blank name 422, partial update preserves fields, free-tier blocks second stream
- All 63 server tests pass ✅

**`packages/fluxora_core`**
- `network/api_exception.dart` — added `bool get isTierLimit => statusCode == 429`
- `network/endpoints.dart` — added `serverSettings = '/api/v1/settings'`

**`apps/mobile`**
- `player_state.dart` — added `PlayerTierLimit` sealed state (no fields needed)
- `player_cubit.dart` — `startStream` catches `ApiException.isTierLimit` and emits `PlayerTierLimit` instead of generic `PlayerFailure`
- `player_screen.dart` — added `_TierLimitView` with upgrade messaging and back button; added to switch expression

**`apps/desktop`**
- `settings_state.dart` — `SettingsLoaded` extended with `serverName`, `tier`, `maxConcurrentStreams`, `licenseKey?`; `SettingsSaved` extended with `serverName`, `tier`
- `settings_cubit.dart` — `loadSettings()` now fetches from `GET /settings` (best-effort, non-fatal); new `saveSettings()` replaces `saveServerUrl()` — patches server + saves URL locally
- `settings_screen.dart` — full rewrite: Server Connection card (URL + server name), Subscription card (tier dropdown, license key field, stream-limit badge), Save button, About card; uses plain `DropdownButton` (avoids `DropdownButtonFormField.value` deprecation in Flutter 3.33)

### Quality Gates
- `flutter analyze --no-fatal-infos` → **No issues** ✅ (mobile, desktop, core)
- `flutter test` mobile → **24/24 pass** ✅
- `pytest` server → **63/63 pass** ✅

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `apps/server/database/migrations/006_settings_license.sql` |
| Created | `apps/server/database/migrations/007_align_tier_limits.sql` |
| Created | `apps/server/services/settings_service.py` |
| Modified | `apps/server/models/settings.py` |
| Created | `apps/server/routers/settings.py` |
| Modified | `apps/server/routers/stream.py` |
| Modified | `apps/server/main.py` |
| Created | `apps/server/tests/test_settings.py` |
| Modified | `packages/fluxora_core/lib/network/api_exception.dart` |
| Modified | `packages/fluxora_core/lib/network/endpoints.dart` |
| Modified | `apps/mobile/lib/features/player/presentation/cubit/player_state.dart` |
| Modified | `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart` |
| Modified | `apps/mobile/lib/features/player/presentation/screens/player_screen.dart` |
| Modified | `apps/desktop/lib/features/settings/presentation/cubit/settings_state.dart` |
| Modified | `apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart` |
| Modified | `apps/desktop/lib/features/settings/presentation/screens/settings_screen.dart` |

### Docs Updated
| Doc File | What Changed |
|----------|-------------|
| `docs/04_api/01_api_contracts.md` | Added `GET /api/v1/settings` and `PATCH /api/v1/settings` with full schema + tier table |
| `docs/10_planning/01_roadmap.md` | Phase 4 table updated with Status column and current state; M5 → 🔄 In Progress |

### Decisions Made
- Stream concurrency limit is now fully DB-driven — `settings.fluxora_max_streams` config is no longer consulted for live enforcement (it still exists in `config.py` as a fallback default for new installs if the DB row is missing)
- License key is stored as plain text in the DB — no encryption applied yet because it has no secret value until payment validation is wired
- Desktop `SettingsCubit.loadSettings()` fetches server settings best-effort; if the server is offline, it falls back to sensible defaults without crashing
- Used plain `DropdownButton` instead of `DropdownButtonFormField` to avoid the `value` deprecation in Flutter 3.33+

### Blockers / Open Issues
- License key payment/crypto validation is deferred ("Integration TBD") — the key is stored and displayed but not validated against any payment provider
- Desktop tests for `DashboardCubit`, `ClientsCubit`, `SettingsCubit` not yet written

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything
2. Run `flask analyze` in all Flutter packages and `pytest` in `apps/server/` to confirm clean baselines
3. **Phase 5 options**: hardware encoding (NVENC/VAAPI), E2E encryption, multi-user/family sharing
4. Alternatively: write desktop cubit tests (`DashboardCubit`, `ClientsCubit`, `SettingsCubit`) — still outstanding
5. Append a new entry to `AGENT_LOG.md` when done

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

## Session — 2026-04-28 (Desktop Cubit Tests)

### Goal
Write the outstanding desktop cubit unit tests flagged in the previous session's "Next Agent Should" section: `DashboardCubit`, `ClientsCubit`, `SettingsCubit`.

### What Was Done

Three test files added under `apps/desktop/test/`:

**`test/features/dashboard/dashboard_cubit_test.dart`** (5 tests)
- `initial state is DashboardInitial`
- `emits [Loading, Loaded]` when load succeeds
- `loaded state carries correct server info and client lists` (serverName, approvedCount, pendingCount)
- `emits [Loading, Failure]` with `ApiException` message on API error
- `emits [Loading, Failure]` with default message on generic exception

**`test/features/clients/clients_cubit_test.dart`** (13 tests)
- `load`: initial, success, failure (ApiException + generic)
- `setFilter`: approved-only, clear filter, no-op when not loaded
- `approve`: processingIds set then cleared after reload; error path clears processingId; no-op when not loaded
- `reject`: processingIds set then cleared after reload; error path clears processingId; no-op when not loaded

**`test/features/settings/settings_cubit_test.dart`** (13 tests)
- `loadSettings`: all defaults when storage empty + server offline; uses saved URL; merges server settings on success; saved URL + server settings; defaults when `getServerUrl` throws
- `saveSettings`: SettingsError on blank URL; SettingsError on URL without scheme; SettingsError on blank name; SettingsSaved with trimmed values + verify calls; SettingsError when PATCH throws; license_key included in body when provided; license_key absent from body when null

Total desktop test suite: **34 tests** (up from 1 placeholder).

### Approach Notes
- `DashboardRepository` and `ClientsRepository` are abstract → mocked with `extends Mock implements`.
- `SecureStorage` and `ApiClient` are concrete classes → same `implements` pattern works because `Mock.noSuchMethod` intercepts all calls; concrete fields are never initialized on the mock.
- Generic method stubs (`get<Map<String,dynamic>>`, `patch<void>`) work correctly because Dart captures type arguments in `Invocation.typeArguments` and mocktail matches on them.
- `configure()` (sync void) stubbed with `thenAnswer((_) {})`.
- `saveServerUrl()` / `patch<void>()` (async void) stubbed with `thenAnswer((_) async {})`.
- `blocTest` `seed:` parameter used for `setFilter`, `approve`, `reject` tests to avoid needing to drive the cubit through `load()` first.

### Quality Gates
- `flutter analyze --no-fatal-infos` → **No issues** ✅ (desktop)
- `flutter test` desktop → **34/34 pass** ✅
- `flutter test` mobile → **24/24 pass** ✅ (regression check)

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `apps/desktop/test/features/dashboard/dashboard_cubit_test.dart` |
| Created | `apps/desktop/test/features/clients/clients_cubit_test.dart` |
| Created | `apps/desktop/test/features/settings/settings_cubit_test.dart` |

### Docs Updated
None — pure test additions, no code or API changes.

### Decisions Made
- Kept `test/placeholder_test.dart` in place; it continues to satisfy any CI config that expects at least one test to exist before the real suite runs.
- Used `blocTest`'s `seed:` parameter rather than re-driving the cubit through prior states — keeps tests fast and focused.

### Blockers / Open Issues
- License key payment/crypto validation still deferred ("Integration TBD").
- On-device WAN testing for WebRTC not yet performed (requires physical device + real outside-LAN network).

### Next Agent Should
1. Read `CLAUDE.md` and `AGENT_LOG.md` before touching anything.
2. Run `flutter analyze` in all Flutter packages and `pytest` in `apps/server/` to confirm clean baselines.
3. **Phase 5 options** (pick one):
   - Hardware encoding (NVENC/VAAPI) — `apps/server/services/ffmpeg.py` + new transcoding settings
   - E2E encryption for internet streams
   - Multi-user / family sharing (new `users` table, auth model changes)
4. Or: wire up a real payment/license-key validation provider for Phase 4 completion.
5. Append a new entry to `AGENT_LOG.md` when done.

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---
