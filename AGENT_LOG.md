# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_07.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 06)
**Archived:** 2026-05-04
**Contents:** Mobile redesign M8–M9 (Downloads + Profile + Notifications real-data, then breaking V2 theme cutover) · Documentation sync round (M8/M9 across 8 docs) · Mobile real-data backfill plan + Phase A scope freeze · Phase A delivered in three commits (server slice + mobile data wiring + pairing UX rebuild) · Desktop polish round in parallel (real glass on Library popups + dialogs, theme tweaks).

* **Mobile M8 — Downloads + Profile + Notifications real-data wiring + log rotation (2026-05-03):** New `features/notifications/` repo + cubit + state mirroring desktop's REST-polling pattern (singleton `NotificationsCubit`); Downloads + Profile screens rebuilt with mock fixtures (`MockDownload`, hardcoded profile fields); previous AGENT_LOG rotated to archive 05. `// TODO(WS):` markers left for future HMAC-bearer WS migration.
* **Mobile M9 — Theme cutover (2026-05-03, breaking PR):** 7 mobile call-sites + 1 desktop straggler migrated off V1 tokens; deleted 17 V1 colors + 11 V1 typography styles from `fluxora_core/constants/`; `apps/mobile/lib/shared/theme/app_theme.dart` body rewritten onto V2 tokens. M9.5 follow-up patched 4 polish issues (`InputDecorationTheme.fillColor` opacity, `surfaceRaised` contrast, Pro/Ultimate tier collapse, Grep matrix verification).
* **Doc sync round (2026-05-03):** Eight architecture / frontend / data / security / planning / gotchas docs rolled forward to reflect M8/M9. Set the precedent for the new "comprehensive Grep matrix before declaring a cutover complete" gotcha.
* **Real-data backfill plan + Phase A scope freeze (2026-05-04):** New `docs/10_planning/08_real_data_backfill_plan.md` — 10 sections covering goal / inventory / phases A-G / decisions / cutover ritual / NOT-doing list / pre-flight findings / frozen Phase A scope. Eight owner decisions locked. Pre-flight caught two server bugs (re-pair from same `client_id` returning 409; pending tokens in-memory only).
* **Phase A — Server slice (commit `ac5051f`, 2026-05-04):** Migration 016 adds FFprobe video metadata + TV episode aggregation + per-client `email`/`paired_at` to `media_files` and `clients`. New `probe_video()` in `ffmpeg_service.py` runs at scan time. `auth_service.create_pair_request` rewritten to reset same-`client_id` rows back to `pending` regardless of prior status (§8.5 bug 1 fix); in-memory pending-token store moved into the service so re-pair can invalidate it. New endpoints: `GET /files/recent?limit=N` (1..50, mobile Home rail) + `GET /auth/clients/me` (bearer-required per-client profile). `MediaFileResponse` extended with the seven new optional fields. Server suite 253 → 262 passing (+9 cases).
* **Phase A — Mobile data wiring (commit `bb9a94f`, 2026-05-04):** Three new cubits — `RecentCubit` (Home rail), `DetailCubit` (per-screen), `ProfileCubit`. New `ClientProfile` entity (freezed); `MediaFile` extended with the 7 Phase A fields plus a `qualityBadge` extension. Library tab consumes `LibraryBloc` (containers + 5-chip `LibraryType` filter). Detail screen consumes `DetailCubit` over `getFile(id)`. Profile header reads `display_name + email + tier` from `/auth/clients/me`; stats row em-dashed until Phase B. Episodes screen converted to a Phase D placeholder. `MockGradients` lifted to `apps/mobile/lib/shared/widgets/gradients.dart` as `AppGradientPlaceholders` with a `forKey(String)` deterministic helper. `mock_data.dart` shrunk ~360 lines (`MockGradients`, `recentlyAdded`, `findById`, `_details`, `MockCastMember/Season/Episode` all deleted). Mobile tests still 27 passing.
* **Phase A — Pairing UX rebuild (commit `556fe48`, 2026-05-04):** `PairCubit` rewritten with two-step entry (`prepare(server)` → `submitEmail({server, email})`) plus a `reconnect()` entry that uses saved `client_id` + `server_url`. New `PairCollectEmail(server)` state for the optional-email pre-request UI. Pairing screen rebuilt V2-styled per state. New `/reconnect` route + `ReconnectScreen` for lost-token recovery. `ApiClient.unauthorizedStream` (broadcast) emits on 401-with-bearer; `setupRouterUnauthorizedBridge()` in `main.dart` redirects to `/reconnect` (unless already on a pairing surface). Auth-guard updated: `/reconnect` is public; the "authenticated → /home" reflection is scoped to `/connect` and `/pairing` only. Profile gains a "Reconnect to server" sub-row. `pair_cubit_test` rewritten — 5 → 9 cases. Mobile 27 → 31 passing; core 8 still passing.
* **Desktop polish — real glass on Library popups + dialogs (parallel 2026-05-04):** New `FluxGlassDialog` + `FluxGlassMenu` widgets using `BackdropFilter` for proper translucent surfaces over the gradient backdrop. Library Sort menu / Filters dialog / Delete confirm migrated. Several theme tweaks (Card default fill `Color(0xFF0F0C24)` for opaque mid-tier, etc.).

**Phase A is shipped end-to-end (server + mobile + pairing).** Mobile Library / Detail / Home-Recent rail / Profile are all real-data-backed; pairing UX is state-machine-driven with the optional email field; lost-token recovery flows through `/reconnect` with auto-redirect on 401.

**Next Immediate Steps:**
1. **Phase B — Continue-watching + Search + Profile stats.** Three new server endpoints (`/clients/me/continue-watching`, `/files/search`, `/clients/me/stats`) plus three mobile cubit / screen rewires. Each is the smallest fully-real surface left in the mobile app. Plan §3 row 1–3 in `docs/10_planning/08_real_data_backfill_plan.md`.
2. **Hide Downloads tab in v1** (decision §5 row 4). Standalone tiny commit: remove from `FluxBottomTabs` registry + `Routes.downloads` + the `StatefulShellBranch`. Could land before or after Phase B.
3. **Visual QA pass on Phase A.** Walk a paired Android / iOS device through the new pairing UX (server tile → email step → pending → approval → /home) and the reconnect flow (revoke token from desktop → 401 fires → redirect → re-approval → /home). All flutter analyze + tests are green; the actual UI hasn't been exercised.
4. **Mobile redesign M10** — X-Ray panel + Group Watch shell + Offline state, UI shells only per plan §1 row 4. Lower priority than Phase B since these surfaces are largely cosmetic.

---

---
## [2026-05-04] — Desktop polish: System Status panel, tier-gated upgrade dialog, notifications audit
**Phase:** Phase 5 (desktop redesign — post-M10 polish round)
**Status:** Complete

### What Was Done
- **Sidebar / System Status visual fix.** `_SystemStatusBlock` was visually identical to the nav rail above it. Wrapped its content in a recessed `Container` with `Color(0x33000000)` fill + `borderSubtle` + `AppRadii.md` so it reads as a distinct panel against `sidebarGlass`.
- **Sidebar Help duplicate removed.** The titlebar already exposes a Help icon, and the nav-rail entry was redundant. Dropped the `_NavEntry` for Help — the route at `/help` and the screen still exist; only the duplicate sidebar item is gone (sidebar is back to 9 nav items, matching `desktop_redesign_plan.md`).
- **Tier-gated startup upgrade dialog.** New [`UpgradeDialog`](apps/desktop/lib/features/subscription/presentation/widgets/upgrade_dialog.dart) backed by `FluxGlassDialog`. `FluxShell` now provides a shell-scoped `SettingsCubit` (alongside `SystemStatsCubit` + `NotificationsCubit`) and wraps its body in a `BlocListener<SettingsCubit, SettingsState>` with `listenWhen: (prev, curr) => curr is SettingsLoaded && prev is! SettingsLoaded` — fires `showUpgradeDialog` once per launch, only when `tier != 'ultimate'`. Dismissable via outside-tap, Esc, "Maybe Later", or "View Plans" → `/subscription`. `_upgradeDialogShown` guard prevents re-fire on rebuild.
- **Sidebar `_UpgradeCard` self-gates on the same cubit.** Dropped the `currentTier` constructor param on `FluxSidebar` (no caller was passing it). `_UpgradeCard.build` now reads `context.watch<SettingsCubit>().state` and returns `SizedBox.shrink()` when tier is `'ultimate'`. Stays visible while settings load (optimistic-free default).
- **Notifications audit + fixes (desktop):**
  - Titlebar bell dot now reads `BlocSelector<NotificationsCubit, NotificationsState, int>` keyed off `unreadCount` — the violet dot only renders when `count > 0`. Was always-on regardless of state.
  - Repository query-param mismatch fixed — `?unread_only=true` (client) vs `?unread=true` (server FastAPI signature). Dormant since no caller exercised the flag, but a footgun. Renamed.
  - Panel auto-closes via `NotificationsPanelScope.of(context).close()` before `context.go(route)` on row tap so the overlay doesn't linger over the destination screen.
  - `NotificationsCubit.{markRead, markAllRead, dismiss}` now rethrow on transport failure. Header / footer "Mark all as read" and per-row dismiss callbacks catch and surface a SnackBar (`_markAllReadWithFeedback` / `_dismissWithFeedback` helpers).
  - `markRead` short-circuits with no API call when the target's `readAt != null` — avoids the server's "already read" 404 on stale taps.
  - `liveStream` `seen` set capped at 500 entries (FIFO eviction) so long sessions don't accumulate IDs without bound. Poll limit is 20, so the cap is generous enough to never evict an ID we'd see again on the next tick.
  - `_PanelBody` is now stateful with a 220 ms `easeOutCubic` `SlideTransition` from `Offset(1, 0)` → `Offset.zero`. Animation runs once on mount; rebuilds during filter taps don't restart it (tween + controller are owned by `State`, not the build method).
  - Footer "Notification Settings" link removed — `/settings` has no notifications-prefs section yet, the link was dead. "Mark all as read" right-aligned alone.
  - Repository `TODO(M8)` comment rewritten to reflect the v1 polling decision (matches `SystemStatsCubit`'s rationale). The `WS /api/v1/ws/notifications` endpoint exists; switch is post-v1 once a shared HMAC-bearer WebSocket wrapper exists.
- **Tests.** New `apps/desktop/test/features/notifications/notifications_cubit_test.dart` — 13 cases covering `start` (success / `ApiException` / generic exception), `markRead` (happy / already-read no-op / rethrow), `markAllRead` (happy / rethrow), `dismiss` (happy / rethrow), and live-stream behaviour (new id appended + unread bump / duplicate id ignored). Suite **38 → 51 passing.** `flutter analyze` clean across all 3 packages.

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `apps/desktop/lib/features/subscription/presentation/widgets/upgrade_dialog.dart` |
| Created | `apps/desktop/test/features/notifications/notifications_cubit_test.dart` |
| Modified | `apps/desktop/lib/shared/widgets/flux_shell.dart` (BlocProvider + BlocListener for SettingsCubit; tier-gated dialog trigger) |
| Modified | `apps/desktop/lib/shared/widgets/flux_sidebar.dart` (recessed System Status panel; dropped `currentTier` param + Help nav entry; `_UpgradeCard` self-gates on SettingsCubit) |
| Modified | `apps/desktop/lib/shared/widgets/flux_titlebar.dart` (bell dot reads `unreadCount` via BlocSelector) |
| Modified | `apps/desktop/lib/features/notifications/presentation/cubit/notifications_cubit.dart` (rethrow on mutation failure; `markRead` short-circuit on already-read) |
| Modified | `apps/desktop/lib/features/notifications/data/repositories/notifications_repository_impl.dart` (`unread_only` → `unread`; cap `seen` at 500; polling-comment alignment) |
| Modified | `apps/desktop/lib/features/notifications/presentation/widgets/notifications_panel.dart` (panel auto-close on row tap; SnackBar feedback helpers; `_PanelBody` slide-in animation; dead Settings link removed) |

### Docs Updated
- `docs/00_overview/current_status.md` — desktop test count `38 → 51`; new "Desktop polish" milestone row; M7 row corrected (notifications poll, not WS); top-of-file dated summary extended.
- `docs/08_frontend/01_frontend_architecture.md` — surface-token policy paragraph extended with notifications audit details (bell-dot wiring, panel slide-in, `seen` cap, query-param fix, mutation rethrow + SnackBar pattern); `UpgradeDialog` cross-link tightened.
- `docs/12_guidelines/03_gotchas.md` — added "Silent query-string contract drift between client and server" gotcha covering the `unread_only` vs `unread` find.
- `AGENT_LOG.md` — this entry.

### Decisions Made
- **No tier gating on the `UpgradeDialog` API itself** — gating is performed at the trigger site in `FluxShell`. Same pattern as `_UpgradeCard`. Lets the dialog be reused from anywhere (e.g. a future "tier-required" CTA) without entangling tier logic into the widget.
- **Shell-scoped `SettingsCubit` is read-only chrome.** Settings / Subscription / Encoder screens still build their own instances for save flows. Splits "live tier for chrome" from "form-state for editing" without forcing a singleton refactor. The trade-off: a save in the Subscription screen does NOT update the shell's cubit until next app launch — acceptable for v1; if we ever want live updates, convert `SettingsCubit` to a `lazySingleton` and replace per-screen `BlocProvider(create:)` with `BlocProvider.value`.
- **Panel exit animation deliberately deferred.** Slide-in only. Adding exit animation requires routing every close path (backdrop tap, X button, row tap, bell-toggle close, NotificationsPanelScope.close) through a single widget-owned animation step — bigger refactor than the polish warrants.
- **Footer "Notification Settings" link removed rather than routed-somewhere.** `/settings` has no prefs surface; routing the link to a non-existent anchor would be worse than no link. Re-introduce when prefs ship.

### Blockers / Open Issues
- None for the polish round. Pre-existing post-v1 items remain: WebSocket migration for notifications, notifications-prefs surface, alpha-only mock data fields, etc.

### Issues / Sharp Edges Discovered
- **Server query-param contract drift was undetected for a full milestone.** `unread_only` (client) vs `unread` (server) shipped because no caller passed the flag — FastAPI silently dropped the unknown param. Captured as a new gotcha. Recommendation in the gotcha: pin param names as constants somewhere reviewable, prefer integration tests that assert the filter actually filtered (not just "no exception thrown").
- **Mobile carries the same `unread_only` typo at [`apps/mobile/lib/features/notifications/data/repositories/notifications_repository_impl.dart:29`](apps/mobile/lib/features/notifications/data/repositories/notifications_repository_impl.dart#L29).** Identical dormant bug. Left in place for the mobile agent — not my track. Single-line rename is all that's needed.
- **Documentation drift audit (2026-05-04).** Read-only sweep across `docs/` surfaced 16 issues + 7 suggestions — stale test counts in 02_tech_stack.md / folder_structure.md / 01_roadmap.md, a TBD-stub product roadmap at `docs/01_product/04_roadmap.md`, missing Phase A row in the planning roadmap, and structural duplication of test counts and repo-trees across multiple files. Captured in [`docs/10_planning/09_doc_audit_2026_05_04.md`](docs/10_planning/09_doc_audit_2026_05_04.md) for a future targeted-fix commit. None of it actioned in this session.
- **Always-on bell badges hide unread state.** A persistent indicator that doesn't change is just decoration. Easy to miss in a code review because the widget itself looks innocuous; the bug is the *absence* of a state read. Added unit-test for the `unreadCount` projection so future changes can't silently regress.
- **`_BellDot` and `_UpgradeCard` both demonstrate "self-gating widgets > parent-passed props" for shell chrome.** Consumers don't have to remember to wire props — the widget consults the cubit directly. Worth keeping in mind for future shell additions (status pill, license-expiry banner, etc.).

### Suggested Next Steps
1. **Phase B real-data backfill** — continue-watching, search, profile stats (per `docs/10_planning/08_real_data_backfill_plan.md` §3 rows 1–3). Three new server endpoints + three mobile cubit rewires. Highest priority for the mobile stream of work.
2. **Hide Downloads tab in v1** — tiny standalone commit per backfill-plan §5 row 4. Could land before or after Phase B.
3. **Surface mutation errors on the row-tap path too.** Currently the row-tap fires `cubit.markRead` fire-and-forget so the user can navigate immediately; failures are silent. If we ever want a retry surface, route the mark-read through `_markReadWithFeedback` and tolerate the brief navigation delay.
4. **Walk-the-app QA on this polish round.** I exercised the cubit in unit tests and `flutter analyze` is clean, but the actual UI hasn't been touched on Windows. Verify: bell-dot only lights when there ARE unread notifications, panel slides in cleanly (not a single-frame jump), upgrade dialog appears once per launch and dismisses cleanly, sidebar Help is gone but titlebar Help still works, `Subscription` route still navigates from the dialog's "View Plans" button.
5. **Promote "self-gating widget" pattern to DESIGN.md / frontend architecture** as the default for shell chrome that depends on cubit state. Lower priority — a single sentence somewhere.

### Hard Rules Checklist
- [x] No `git commit` / `git push` / amend operations performed
- [x] No agent branding added anywhere (code, comments, docs)
- [x] No `print` / `debugPrint` / Python `print()` introduced — all logging via project logger
- [x] No silent exception swallowing — mutations rethrow, panel surfaces SnackBars, repository logger keeps full context on poll failures
- [x] No hardcoded secrets, ports, or paths
- [x] No new pub / pip dependencies added
- [x] Clean Architecture layer boundaries respected (cubit consumes repository, repository owns API client, presentation never touches `Endpoints` directly)
- [x] No tokens, passwords, or PII logged
- [x] No DB migrations edited or deleted
- [x] No string-concatenated SQL
- [x] No secrets committed (`.env` / `google-services.json` / etc. unchanged)
- [x] No package versions bumped — all changes operate within current pinned deps
- [x] Bearer-token storage untouched (HMAC-SHA256 invariant preserved)

---

## Entry Template

```
---
## [YYYY-MM-DD] — Brief title
**Phase:** Phase N (description)
**Status:** Complete | Partial | Blocked

### What Was Done
- bullet list

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | path |
| Modified | path |

### Docs Updated
- list

### Decisions Made
- list

### Blockers / Open Issues
- list

### Issues / Sharp Edges Discovered
- list

### Suggested Next Steps
- list

### Hard Rules Checklist
- [ ] item
```

---

## [2026-05-04] — Mobile real-data backfill — Phase B (Continue-watching + Search + Profile stats)
**Phase:** Phase 5 (mobile real-data backfill — see `docs/10_planning/08_real_data_backfill_plan.md` §3 row 1–3)
**Status:** Complete

### What Was Done

Phase B in two slices (server + mobile), both delivered together since the surfaces are small and the two halves are tightly coupled.  Also includes the standalone "hide Downloads tab in v1" commit (`46ac462`) and the AGENT_LOG rotation commit (`cf16a40`) that opened this archive cycle.

**Server slice — three new endpoints, twelve new tests (server suite 262 → 274):**

1. **`GET /api/v1/files/search?q=&limit=N`** (`routers/files.py`, registered before `/{file_id}` per the same gotcha as `/recent`).  `q` is required (1–200 chars), `limit` clamped `[1, 50]` — both via `fastapi.Query(...)`.  Service implementation in `library_service.search_files` does case-insensitive `LIKE` against `name` + TMDB `title`, `ESCAPE \` clause to neutralise `_` and `%` in user input so `season_1` matches the literal underscore, sorts by `created_at DESC` for tie-breaking.  Tests cover filename match, TMDB-title fallback, case-insensitivity, the wildcard escape, empty-query 422, oversize-limit 422, and the route-order trap.
2. **`GET /api/v1/auth/clients/me/continue-watching?limit=N`** (`routers/auth.py`, bearer-required).  Service in `library_service.list_continue_watching`: `WHERE last_progress_sec > 0 AND (duration_sec IS NULL OR last_progress_sec < duration_sec * 0.95) ORDER BY updated_at DESC LIMIT ?`.  Path lives under `/auth/clients/me/...` so it shares the `validate_token` dep + namespace symmetry with the other `me` endpoints.  Tests cover the 95%-cutoff exclusion (zero-progress + completed both filtered out) and the bearer-required gate.
3. **`GET /api/v1/auth/clients/me/stats`** (`routers/auth.py`, bearer-required).  Returns `{hours, movies, shows}`.  Service in `library_service.get_client_stats` runs three SQL queries scoped by `client_id`: `SUM(progress_sec)/3600` from `stream_sessions`, distinct `file_id`s joined to `libraries.type='movies'`, distinct `tmdb_show_id` values across the user's sessions.  All three values are non-negative ints; a fresh client returns `{0, 0, 0}` rather than 404.  `shows` stays at 0 until Phase D back-fills `tmdb_show_id` — that's intentional honesty.  Tests cover the zero-state, the aggregation correctness with mixed-library mixed-show data, and the bearer gate.
4. **`ClientMeStatsResponse` model** added to `models/client.py`.

**Mobile slice — three new cubits + screen rewires (mobile tests still 31, fluxora_core still 8):**

5. **`MediaFile`-only changes**: none.  `ClientStats` is the new entity (freezed, `client_stats.dart`), exported from `fluxora_core.dart`.  `Endpoints` gained `filesSearch`, `authClientsMeStats`, `authClientsMeContinueWatching`.
6. **`LibraryRepository`** gained two methods — `searchFiles({query, limit})` and `listContinueWatching({limit})`.  Empty-query short-circuit (`return const []`) avoids a server round-trip on every Backspace-to-empty.  **`AuthRepository`** gained `getMyStats()`.  Both repos updated and existing tests still pass.
7. **`ContinueWatchingCubit`** (`features/home/presentation/cubit/`) — singleton-scoped in GetIt, sealed-state `*Initial / Loading / Loaded(items) / Failure(message)`.  Loaded once on first Home-tab visit; pull-to-refresh fires `refresh()`.
8. **`SearchCubit`** (`features/search/presentation/cubit/`) — sealed `Idle / Loading / Loaded(query, results) / Failure(message)`.  300 ms debounce on `queryChanged()` so each keystroke doesn't slam the server.  Sequence-counter (`_requestSeq`) so a slower in-flight response can't clobber a newer query's results.  Empty input transitions back to `Idle` and rebuilds the recent / trending search-history chrome.
9. **`ProfileStatsCubit`** (`features/profile/presentation/cubit/`) — singleton, sealed `*Initial / Loading / Loaded(stats) / Failure(message)`.  Separate from `ProfileCubit` so a stats failure can't blank the avatar header (and vice versa); both load in parallel and pull-to-refresh awaits `Future.wait([_profile.refresh(), _stats.refresh()])`.
10. **`home_screen.dart`** — Continue-watching rail rewired to `ContinueWatchingCubit` (hero-size posters with composed quality badges and computed "N min left" subtitles via `(durationSec - resumeSec)`); Recently-added rail unchanged (Phase A); Trending now consumes `MockData.trending` directly inside `_MockRail` so its widget is `const`-constructible.  Pull-to-refresh dispatches both Phase A and Phase B cubits in parallel.
11. **`search_screen.dart`** — full rewrite.  Drops the in-memory `MockData` filter; consumes `SearchCubit` via `BlocProvider`.  `ValueListenableBuilder` over the `TextEditingController` keeps the X-clear button correct without forcing a `setState` chain.  Active-results layout matches the Phase A prototype (top-3 horizontal rail + sectioned vertical list) with `MediaFile` posters, `AppGradientPlaceholders.forKey(id)` placeholders, `MediaFile.qualityBadge` chips.
12. **`profile_screen.dart`** — `_StatRow` rewritten to consume `ProfileStatsCubit`.  Loaded state shows real `{hours, movies, shows}`; loading / failure / initial states fall through to em-dash placeholders so the row holds its layout slot without lying about the numbers.  Pull-to-refresh awaits both profile + stats cubits in parallel.
13. **`mock_data.dart`** — deleted `MockData.continueWatching` (the four `cw-1`..`cw-4` fixtures).  `MockMediaItem` class survives because `MockData.trending` still uses it for the Phase C target rail.  `MockData.recentSearches` + `trendingSearches` survive (they back the search history chrome — the search-history persistence feature isn't anchored to a specific phase yet).
14. **Injector** registers `ContinueWatchingCubit` and `ProfileStatsCubit` as `lazySingleton`.  `SearchCubit` is created per-screen via `BlocProvider` so its debounce timer resets when the user leaves the tab.

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `packages/fluxora_core/lib/entities/client_stats.dart` (+ generated `.freezed.dart` / `.g.dart`) |
| Created | `apps/mobile/lib/features/home/presentation/cubit/continue_watching_cubit.dart` |
| Created | `apps/mobile/lib/features/search/presentation/cubit/search_cubit.dart` |
| Created | `apps/mobile/lib/features/profile/presentation/cubit/profile_stats_cubit.dart` |
| Modified | `apps/server/services/library_service.py` (added `search_files`, `list_continue_watching`, `get_client_stats`) |
| Modified | `apps/server/routers/files.py` (`GET /search` registered before `/{file_id}`) |
| Modified | `apps/server/routers/auth.py` (`GET /clients/me/continue-watching`, `GET /clients/me/stats`) |
| Modified | `apps/server/models/client.py` (added `ClientMeStatsResponse`) |
| Modified | `apps/server/tests/test_files.py` (+7 search cases) |
| Modified | `apps/server/tests/test_auth.py` (+5 stats / continue-watching cases) |
| Modified | `packages/fluxora_core/lib/network/endpoints.dart` (`filesSearch`, `authClientsMeStats`, `authClientsMeContinueWatching`) |
| Modified | `packages/fluxora_core/lib/fluxora_core.dart` (export `client_stats`) |
| Modified | `apps/mobile/lib/features/library/domain/repositories/library_repository.dart` (`searchFiles`, `listContinueWatching`) |
| Modified | `apps/mobile/lib/features/library/data/repositories/library_repository_impl.dart` |
| Modified | `apps/mobile/lib/features/auth/domain/repositories/auth_repository.dart` (`getMyStats`) |
| Modified | `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart` |
| Modified | `apps/mobile/lib/features/home/presentation/screens/home_screen.dart` (Continue-watching rail consumes cubit) |
| Modified | `apps/mobile/lib/features/search/presentation/screens/search_screen.dart` (consumes `SearchCubit`) |
| Modified | `apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart` (stats row consumes `ProfileStatsCubit`) |
| Modified | `apps/mobile/lib/shared/data/mock_data.dart` (deleted `MockData.continueWatching`) |
| Modified | `apps/mobile/lib/core/di/injector.dart` (register `ContinueWatchingCubit` + `ProfileStatsCubit`) |
| Modified | `docs/00_overview/current_status.md` (Phase B noted; server test count 262 → 274) |
| Modified | `docs/04_api/01_api_contracts.md` (three new endpoint sections + status banner update) |
| Modified | `docs/05_infrastructure/02_url_inventory.md` (three new endpoint rows) |
| Modified | `AGENT_LOG.md` (this entry) |

### Docs Updated
- `docs/00_overview/current_status.md` — Phase B noted in the status banner; server test count 262 → 274; routers list updated to reflect `/me/stats`, `/me/continue-watching`, `/files/search`.
- `docs/04_api/01_api_contracts.md` — three new endpoint sections (one per Phase B endpoint) + status banner update.  All three sections describe `Auth`, `Status`, query params (where applicable), response shape, error codes.
- `docs/05_infrastructure/02_url_inventory.md` — three new rows in the auth + files router tables.

### Decisions Made
- **Search uses SQL `LIKE`, not FTS5.** Decision §5 row 1 — FTS5 is the documented v2 swap-in.  Trade-off: substring match is good enough for v1 libraries (typical < 10k files); ranking + prefix-match ergonomics + diacritic-insensitive search all wait for FTS5.
- **`_` and `%` are escaped before `LIKE`.**  Without the escape clause a search for `season_1` would silently match `season-1`, `season1`, etc.  The escape adds 3 chars to the SQL and pins the gotcha in a test.
- **Continue-watching uses the global `last_progress_sec` column, not per-client `stream_sessions`.**  Single-tenant home server — `last_progress_sec` lives on `media_files` and is touched by every progress write.  Joining `stream_sessions` would give per-client history at the cost of a more complex query and effectively no benefit on a single-tenant box.  Phase F (multi-tenant) revisits.
- **95% cutoff for "effectively complete".**  An exact `progress >= duration` check would never fire because the client's progress reporter rounds + the server's float comparison can be off by milliseconds.  95% is the same threshold most streaming apps use to consider a title "watched".  Lives in the SQL where the rule is enforced.
- **Stats live behind bearer auth even though continue-watching arguably could be `validate_token_or_local`.**  Both are scoped by `me`, and `me` is the bearer.  Localhost callers (the desktop control panel) wouldn't typically need either of these endpoints anyway — they have richer per-client analytics paths.  Keeping them both bearer-required also means the path namespace `/auth/clients/me/...` is consistent.
- **Stats `shows` = 0 is correct for v1.**  `tmdb_show_id` is null on all rows until Phase D back-fills it.  Showing 0 is the truth; padding with a fake count would be a worse failure mode than the user noticing "0 shows" and asking why.
- **`SearchCubit` debounces 300 ms, not the typical 200 ms.**  Mobile keyboards are slow; 200 ms double-fires when a fast typist hits two keys consecutively.  300 ms still feels instant + cuts the request count by ~3×.
- **Sequence-counter dropping stale responses.**  Without it, a slow server reply for `q="vel"` could land after the response for `q="velvet"` and clobber the more-specific result.  Single int counter, monotonically incremented, dropped if it doesn't match on completion.

### Blockers / Open Issues
- **`SearchCubit` has no tests yet.**  The cubit is small enough that the integration-via-screen path catches the meaningful failures, but a unit test that pins the debounce + sequence-counter contracts is worth doing in a follow-up.  Same for `ContinueWatchingCubit` and `ProfileStatsCubit`.  Mobile suite is 31, hasn't grown — Phase B's confidence comes from the server tests + flutter analyze.
- **Trending rail still mock.**  Decision §5 row 3 calls for either a deletion or a rewire against a popularity / TMDB-trending endpoint, deferred to Phase C.  Until Phase C, the rail surfaces `MockData.trending` directly — that's the only `MockMediaItem`-typed surface left in the live UI.
- **Search history is not persisted.**  `MockData.recentSearches` is a hardcoded list; tapping the chip does navigate the search but the user's actual recent searches don't accumulate.  No phase anchor yet — the search-history persistence feature is a follow-up.
- **`MediaFile.qualityBadge` extension's "1440p" fallback** is composed for any height in `[1400, 2000)`, but few titles ever ship at that resolution.  Cosmetic.

### Issues / Sharp Edges Discovered
- **`/clients/me/continue-watching` route registration order.**  FastAPI doesn't yet collide it with another route, but adding any future `/clients/{client_id}/...` route would shadow it.  The path prefix `me` is treated as a literal because the router never registers a wildcard at that depth.  If a future commit wants per-client-by-id endpoints (e.g. `/clients/{id}/sessions`), the `me` routes have to register first.
- **`ValueListenableBuilder` for the X-clear button**.  The `TextEditingController` is a `ChangeNotifier` that emits on every keystroke; using it as the listenable lets the X button appear/disappear without the screen calling `setState` on every keystroke.  Pattern documented inline.
- **`extension.replaceFirst('.', '').toUpperCase()`** in the search subtitle helper — `MediaFile.extension` includes the leading dot (`.mp4` not `mp4`).  The helper handles both forms but the explicit `.replaceFirst` makes the contract obvious.
- **Server tests already used `_get_token` with a pair-then-approve helper**.  Phase B's new `_approve_and_token` is the same shape but uses `PAIR_BODY` (the module-level fixture) directly instead of an inline body — minor duplication that's worth tolerating since the two tests' client_ids (`client-uuid-001` vs `files-test-client`) need to differ for parallel test isolation.

### Suggested Next Steps (priority order)
1. **Visual QA pass on Phase A + Phase B.**  Walk a paired Android / iOS device through: scan a real library → confirm Home Continue-watching + Recently-added rails populate; type into Search → confirm the debounce feels good and results land; open Profile → confirm stats land (or em-dash if zero state).
2. **Phase C — Title detail rich content.**  Cast / crew / similar-titles rails on the detail screen.  Server-side needs a TMDB-credits writer (a new column or a new table) plus a `/files/{id}/credits` and `/files/{id}/similar` endpoint.  Plan §3 row 4 / 5.
3. **Phase D — TV episode aggregation.**  Back-fill `tmdb_show_id` / `season_number` / `episode_number` during library scan + new `/shows/{tmdb_show_id}` and `/shows/{tmdb_show_id}/episodes` endpoints.  Mobile: rewire the `episodes_screen.dart` Phase D placeholder.  This is also when `stats.shows` starts returning real numbers.
4. **`SearchCubit` / `ContinueWatchingCubit` / `ProfileStatsCubit` unit tests.**  Each is small; ~5 cases each.  Pins the debounce + sequence-counter + parallel-load behaviour.
5. **Mobile redesign M10** — X-Ray panel + Group Watch shell + Offline state, UI shells only.  Lower priority than Phases C / D since real data > cosmetic shells.

### Hard Rules Checklist
- [x] `git commit` / `git push` not run yet — staged + draft only; owner approves in this session.
- [x] No AI branding in code, docs, or commit message.
- [x] No `print()` / `debugPrint()`.
- [x] No silent `except:`; cubits emit `*Failure` states + log via project `Logger`.
- [x] No hardcoded secrets / paths.
- [x] No new pip / pub deps.
- [x] No layer-boundary violations (cubit → repo → ApiClient).
- [x] No git-history rewrites.
- [x] No edits to past migrations.
---
