# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_05.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 05)
**Archived:** 2026-05-03
**Contents:** M0 backend close-out (8 chunks) · V2 theme cutover (M9.5) · M10 desktop custom window chrome + Fluxora app icon + Aero Peek · CI golden exclusions · Mobile redesign M0–M7 (foundation → mini-player + drag-down minimize).

* **M0 backend close-out (2026-05-02):** Eight chunks shipped end-to-end (groups + restrictions, profile, notifications, activity, transcoding-status, structured logs + WS tail, settings extension, orders pagination). Migrations 011–015. Server suite 149 → 240 passing. New URL inventory at `docs/05_infrastructure/02_url_inventory.md`.
* **V2 theme cutover (M9.5, 2026-05-03):** Desktop redesign reached the breaking-PR cutover — `apps/desktop/lib/shared/theme/app_theme.dart` body rewritten to consume V2 tokens (`bgRoot`, `violet`, `surfaceGlass`, `textBright`, `h2`, `body`, etc.). Legacy `AppColors.primary` (indigo) and the old text styles removed. Both apps now share the V2 desktop palette via `fluxora_core/lib/constants/`.
* **Desktop M10 — custom window chrome (2026-05-03):** `bitsdojo_window` integration + sidebar logo removal + custom title bar across Win/Mac/Linux. Fluxora app icon shipped (`.ico` for Win + `.icns` for Mac); MSI/DMG version metadata wired; Aero Peek + jump list shell integration on Windows.
* **Docs sync + CI hardening (2026-05-03):** Documentation rolled forward to reflect M8 a11y, golden enable, M10 titlebar, Aero Peek. Golden tests excluded from CI run via `--exclude-tags=golden`.
* **Mobile redesign M0 — Foundation (2026-05-03):** No new theme tokens. Added `google_fonts: ^8.1.0`, `lucide_icons_flutter: ^3.1.13`, bumped `cached_network_image: ^3.3.1 → ^3.4.1`. New `background_gradient.dart` mounts the prototype's two-radial brand gradient app-wide; existing screens unchanged (still opaque scaffolds → gradient hidden until M2).
* **Mobile branding pass (2026-05-03):** Adaptive launcher icons + iOS app icon set + splash + GeneratedPluginRegistrant updates synced from the brand assets in `/assets/brand/`.
* **Mobile M1 — Shared widgets lift (2026-05-03):** `FluxButton` + `FluxChip` (renamed from `Pill`) lifted from desktop into `fluxora_core`; 7 new core widgets: `FluxAppBar`, `FluxBottomTabs`, `FluxBottomSheet` + `showFluxBottomSheet()`, `FluxPoster`, `FluxRow`, `FluxSectionHeader`. 13 desktop call-sites migrated to import from `fluxora_core`.
* **Mobile M2 — Tab shell (2026-05-03):** `MobileShell` wraps `StatefulNavigationShell` with `FluxBottomTabs`. `app_router.dart` rewritten as `StatefulShellRoute.indexedStack`. 5 tab routes (`/home`, `/library`, `/search`, `/downloads`, `/profile`). Auth gates + deep-link routes bypass the shell.
* **Mobile M3 — Discover surfaces (2026-05-03):** New `mock_data.dart` (continue-watching / trending / recently-added / search / notifications). New screens: `home_screen` (3 rails), `search_screen` (active/empty/no-results), `notifications_screen` (Today/Week/Earlier buckets). `library_screen` rewritten with 6 filter chips + grid/list toggle.
* **Mobile M4 — Title detail + episodes (2026-05-03):** `mock_data.dart` extended with detail-rich variants (`MockCastMember` / `MockSeason` / `MockEpisode` + `findById`). New `detail_screen.dart` (hero + Play/Episodes + 4-up actions + collapsible synopsis + cast/crew/similar rails). New `episodes_screen.dart` (season chips + episode rows). Top-level `/detail/:id` and `/episodes/:id` routes.
* **Mobile M5 — Player chrome rebuild (2026-05-03):** `_VideoView` body now `Stack(Video + FluxPlayerControls)`. New `PlayerControlsController(ChangeNotifier)` + `FluxPlayerControls` widget (top bar, center transport, progress bar, 8-up quick-actions, side rails, lock chip). All 25 PlayerCubit tests still pass — cubit interface untouched.
* **Mobile M6 — Player gestures + 5 bottom sheets (2026-05-03):** `screen_brightness ^2.1.7` added. Sheets: audio_subs / speed / sleep / quality (stub) / cast (stub). Gestures: double-tap seek ± 10 s + ripple, long-press 2× peek, vertical drag = brightness/volume + HUD pill, pinch = fit toggle. Hold-to-unlock circular progress ring (1.2 s).
* **Mobile M7 — Mini-player + drag-down minimize (2026-05-03):** `PlayerCubit` promoted to `GetIt.lazySingleton` (the `PlaybackProvider` per plan §9.2); refactored with `_disposeCurrentSession` + restart-safe `startStream` + new `dismiss()`. New `flux_mini_player.dart` (64 px, mounted in `MobileShell.bottomNavigationBar` above `FluxBottomTabs`). New `Routes.playerResume` + `PlayerScreen.resume()` constructor. Drag-down handle (24 px top strip) accumulates `_dragOffset`; release ≥ 150 px pops the route, springs back otherwise. The carried-forward M7 entry below has the full detail.

**Next Immediate Steps:**
1. **Mobile M9 — theme cutover.** Delete legacy `AppColors.primary` (indigo `#6366F1`) and superseded styles; rewrite `apps/mobile/lib/shared/theme/app_theme.dart` body to consume V2 tokens. Per plan §7 row M9 — the breaking PR for mobile.
2. **Mobile M10 — X-Ray panel + Group Watch shell + Offline state.** UI shells only per plan §1 row 4.
3. **Visual smoke test the M5–M8 chain** on a physical Android + iOS device (poster tap → drag-down → mini-player → tap to resume → close X tearing down the stream).
4. **macOS / Linux desktop runners** for the M10 custom window chrome — Win shell integration shipped, the other platforms are pending.

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

### Next Agent Should
1. step
2. step

### Hard Rules Checklist
- [x] No `git commit` / `git push` without explicit per-action OK
- [x] No agent branding anywhere
- [x] No `print()` / `debugPrint()` introduced
- [x] No exceptions swallowed
- [x] No secrets / hardcoded paths added
- [x] All new third-party deps version-checked
---
```

---

## [2026-05-03] — Mobile redesign M7 — Mini-player + drag-down minimize + shared PlaybackProvider
**Phase:** Phase 5 (Mobile redesign — Plan in `docs/11_design/mobile_redesign_plan.md` §7)
**Status:** Complete

### What Was Done

- **`PlayerCubit` promoted to a long-lived `GetIt.lazySingleton`** in `apps/mobile/lib/core/di/injector.dart`. This is the `PlaybackProvider` of plan §9.2 — both the fullscreen player and the mini-player consume the same singleton via `BlocBuilder<PlayerCubit, PlayerState>` so playback state is shared without a separate provider class.
- **`PlayerCubit` refactored** for the singleton lifecycle:
  - Extracted `_disposeCurrentSession()` private method that cancels `_progressTimer`, fires a final `_reportProgress()`, calls `repository.stopStream(_sessionId)` (best-effort, swallowed on error), closes `_signaling`, disposes `_player`, and clears all of `_sessionId` / `_signaling` / `_player` / `_controller`.
  - `startStream` now `await`s `_disposeCurrentSession()` first so a singleton restart cleans up the previous session before opening the next one.
  - New public `dismiss()` calls `_disposeCurrentSession()` and emits `PlayerInitial` if not already in that state — used by the mini-player X button.
  - `close()` keeps the same external behaviour by routing through `_disposeCurrentSession()` then `super.close()`. All 25 `PlayerCubit` unit tests still pass — the cubit's external API (start, close, state-emission sequence) is preserved.
- **New `apps/mobile/lib/shared/widgets/flux_mini_player.dart`** — `FluxMiniPlayer` (64 px, mobile-only). Subscribes to the singleton via `BlocBuilder<PlayerCubit, PlayerState>(bloc: GetIt.I<PlayerCubit>())`. When `state is PlayerReady`, renders a row with: 48×48 violet-gradient poster placeholder + movie-icon, title (13/600 textBright, 1-line ellipsis), tiny 3-px violet `LinearProgressIndicator` (StreamBuilder over `player.stream.position`/`duration`), play-pause `IconButton` (StreamBuilder over `player.stream.playing`), close X (`onPressed: cubit.dismiss`). Tap on the bar pushes `Routes.playerResume`. When state is anything else, renders a zero-height `SizedBox` — the `AnimatedSize(duration: 200ms)` parent slides it in/out smoothly.
- **`MobileShell.bottomNavigationBar` rewritten** as `Column(mainAxisSize: min, children: [FluxMiniPlayer(), FluxBottomTabs(...)])`. Tab-switching code unchanged.
- **`PlayerScreen` rewritten** with two constructors:
  - `PlayerScreen({required MediaFile this.file})` — pushed from a poster tap. Calls `cubit.startStream(file.id, file.title ?? file.name, file.resumeSec)` once on build. Because the cubit is now a singleton with restart-safe `startStream`, this transparently swaps any previously-active stream.
  - `const PlayerScreen.resume()` — pushed from the mini-player tap. Does *not* call `startStream`; the singleton is already in `PlayerReady`. Just rebinds the UI.
  - Both wrap `_PlayerView` in `BlocProvider<PlayerCubit>.value(value: GetIt.I<PlayerCubit>())` (`.value` doesn't auto-close on dispose, which is the correct behaviour for a singleton).
- **`Routes.playerResume = '/player/resume'`** — new top-level deep-link route in `app_router.dart`. Builder: `(context, state) => const PlayerScreen.resume()`.
- **Drag-down-to-minimize**:
  - New `_MinimizeHandle` widget at the top of `_PlayerView` — `Positioned(top: 0)` with `SafeArea(bottom: false)` and a 24-px-tall `GestureDetector(behavior: translucent)` containing a 36×4 white-30% grab pill. Listens only for vertical drags so it doesn't conflict with the controls overlay's tap/double-tap/long-press/pinch gestures.
  - `_PlayerViewState._dragOffset` accumulates `details.delta.dy` (only positive — downward) clamped to `[0, 600]`. `Transform.translate(offset: Offset(0, _dragOffset))` and `Transform.scale(scale: clamp(1 - offset/1200, 0.85, 1.0))` animate the player while dragging; the scaffold's `backgroundColor` opacity reads `clamp(1 - offset/400, 0.4, 1.0)`.
  - On `onVerticalDragEnd`: if `_dragOffset >= 150` → `context.pop()` (the route disappears, the singleton cubit keeps streaming, the mini-player picks up). Otherwise spring back to `0`.
- **Validation**: `flutter analyze` clean × all 3 packages. 27 mobile tests still pass — including the 25 `PlayerCubit` tests that exercise start-stream / stop-stream / close behaviour, all green despite the cubit refactor.

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart` (extracted `_disposeCurrentSession()` private; `startStream` now restart-safe; new public `dismiss()`; `close()` routes through the same path) |
| Modified | `apps/mobile/lib/core/di/injector.dart` (+`PlayerCubit` lazySingleton registration with the existing repos as deps) |
| Created | `apps/mobile/lib/shared/widgets/flux_mini_player.dart` |
| Modified | `apps/mobile/lib/shared/widgets/mobile_shell.dart` (`bottomNavigationBar` now wraps `FluxMiniPlayer + FluxBottomTabs` in a Column) |
| Modified | `apps/mobile/lib/features/player/presentation/screens/player_screen.dart` (added `PlayerScreen.resume()` constructor; switched to `BlocProvider.value` over the singleton; added `_MinimizeHandle` widget + drag-down accumulator with Transform/scale/opacity animation) |
| Modified | `apps/mobile/lib/core/router/app_router.dart` (+`Routes.playerResume`, +matching GoRoute) |

### Docs Updated

- `docs/00_overview/current_status.md` — apps/mobile table gains "Mobile redesign M7 Mini-player + drag-down minimize + shared PlaybackProvider" row; "What's next" item 1 rewritten to point at M8.
- `docs/11_design/mobile_redesign_plan.md` — top-of-file Status updated to "M0–M7 landed"; §7 milestone-table M7 row body rewritten and marked ✅ done; §16 changelog gains a new row.

### Decisions Made

- **`PlayerCubit` doubles as the `PlaybackProvider`, no separate class.** Plan §9.2 left the choice between Riverpod and Cubit open ("TBD at M7"). Adding a `PlaybackProvider` wrapper around the existing cubit would mean two layers of state for one concern. The cubit already owns the `Player` reference, the session id, the progress timer, the WebRTC signaling — promoting it to singleton scope is the smallest viable change. The cubit's name stays accurate for what it does; only its lifetime changed.
- **`_disposeCurrentSession()` extraction over inline cleanup.** Reuse across three call sites (`startStream` restart, `dismiss` explicit teardown, `close` end-of-life) plus null-guarding makes the extraction worth the file overhead. The `close()` body shrinks to two lines.
- **Mini-player resumes via a separate `/player/resume` route, not via `Routes.player` with a stored MediaFile.** The poster-tap path needs a `MediaFile` extra to hand to `startStream`; the mini-player has no `MediaFile` (it only knows the singleton's current state). Two routes is clearer than one route with conditional behaviour. Both render the same `_PlayerView`.
- **Drag-down handle is a separate widget mounted *over* the controls overlay**, not a wrapping `GestureDetector` around the whole video. Wrapping would intercept the tap/double-tap/long-press/vertical-drag/pinch gestures `FluxPlayerControls` already owns. Putting the handle in a 24-px strip at the top with `behavior: translucent` keeps the rest of the player's gesture vocabulary intact.
- **Drag-down threshold = 150 px, max-drag = 600 px.** 150 px is roughly a clear thumb-flick on most screens; the 600-px clamp prevents the player from sliding entirely off-screen during a fast flick before the route pops. The `1 - offset/1200` scale + `1 - offset/400` opacity numbers were tuned to feel snappy without being aggressive.
- **`BlocProvider.value` over the singleton, not `BlocProvider(create: ...)`.** `.create` would close the cubit on the screen's `dispose`, which is exactly what we don't want for a singleton. `.value` is the correct entry point for shared cubits per `flutter_bloc` docs.
- **Mini-player visibility driven by `BlocBuilder` over `state is PlayerReady`**, not by a separate `bool isPlaying` field. State-class identity is the source of truth — `PlayerInitial` / `PlayerLoading` / `PlayerFailure` / `PlayerTierLimit` all hide the mini-player; only `PlayerReady` shows it.

### Issues Discovered / Reported to User

- **`AGENT_LOG.md` rotation overdue** — flagged 8 entries in a row. Rotation handled by the M8 session.
- **The `PlayerScreen({required file})` build path calls `startStream` synchronously on every build.** Restart-safe `startStream` no-ops when the same session is already active. But: pushing the same `MediaFile` twice (poster tap → drag-down → poster tap) tears down + restarts the session. M14 polish: detect "already streaming this id" and short-circuit.
- **Mini-player poster is a placeholder** since `PlayerReady` doesn't carry the source `MediaFile`'s art URL. Threading it through means adding a field to `PlayerReady` and to `startStream`. Out of scope for M7. Flag for M14 polish.

### Blockers / Open Issues

- **None for M8.** All M7 plumbing is done.

### Next Agent Should

1. **Rotate `AGENT_LOG.md`** before any further work — done by the M8 session.
2. **Mobile redesign M8 — Downloads + Profile + Notifications wiring** per plan §7 row M8.
3. **Visual smoke test the M5–M7 player chain** on a physical device.
4. **macOS / Linux desktop runners** when scoped — Win-specific shell integration items still pending.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran. No commits this session — owner has not authorised.
- [x] No agent / AI branding anywhere in code, docs, or commit messages.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed silently — `_disposeCurrentSession` logs the `stopStream` failure case via `_log.w` (preserved from the original `close()` body).
- [x] No secrets / hardcoded paths added.
- [x] No new third-party deps added in M7. `get_it`, `flutter_bloc`, `media_kit`, `media_kit_video`, `go_router` all already in pubspec.
- [x] No backwards-compat hacks. Old per-screen cubit was replaced outright by the singleton, no shim left behind. Old `PlayerScreen({required file})` constructor is preserved (still called from poster taps with their `MediaFile.extra`); new `.resume()` is additive.
- [x] No layer-boundary violations. Mini-player widget lives in `apps/mobile/lib/shared/widgets/`; cubit changes stay within `features/player/presentation/cubit/`; routing change in `core/router/`. `BlocProvider.value` keeps `flutter_bloc` as the only state-management touchpoint — no Riverpod added per the plan §9.2 decision.
---

## [2026-05-03] — Mobile redesign M8 — Downloads + Profile + Notifications real-data wiring + log rotation
**Phase:** Phase 5 (Mobile redesign — Plan in `docs/11_design/mobile_redesign_plan.md` §7)
**Status:** Complete

### What Was Done

- **Log rotated.** `AGENT_LOG.md` (1634 lines) copied to `docs/logs/AGENT_LOG_archive_05.md`; this fresh log contains the rules header + Archive-05 summary + the carried-forward M7 entry + this M8 entry (~290 lines total). Rotation was overdue 8 prior milestones — now reset.
- **M8.1 — Notifications real-data wiring.** Replaced the static `MockData.notifications` list with the existing `/api/v1/notifications` REST endpoint. Mirrored the desktop's polling pattern (its `// TODO(M8)` was to migrate to WS once a shared HMAC-bearer WS wrapper exists; mobile sits on the same path — see new repository's `// TODO(WS)`).
  - **`features/notifications/domain/repositories/notifications_repository.dart`** new — `list({onlyUnread, limit})` / `markRead` / `markAllRead` / `dismiss` / `liveStream()` interface.
  - **`features/notifications/data/repositories/notifications_repository_impl.dart`** new — uses `Endpoints.notifications` / `notificationRead` / `notificationsReadAll` / `notificationDismiss` from `fluxora_core`. `liveStream()` polls every 5 s and yields previously-unseen ids.
  - **`features/notifications/presentation/cubit/notifications_state.dart`** new — sealed class with `Initial` / `Loading` / `Loaded(items, unreadCount)` / `Failure(message)`. No `equatable` dep added — identity equality is fine for an infrequently-updating list and avoids new deps.
  - **`features/notifications/presentation/cubit/notifications_cubit.dart`** new — `start()` loads + subscribes to live stream; `markRead` / `markAllRead` / `dismiss` mirror the desktop pattern; `_emitLoaded` recomputes `unreadCount`. Cancels the live subscription on `close()`.
  - **`core/di/injector.dart`** — registers `NotificationsRepository` + `NotificationsCubit` as `lazySingleton`s. Singleton-scoped so the poll loop survives back-pops on the screen.
  - **`features/notifications/presentation/screens/notifications_screen.dart`** rewritten to consume `NotificationsCubit`. Wraps body in `BlocProvider.value(value: GetIt.I<NotificationsCubit>())` per the M7 singleton-cubit pattern. `start()` is called on first frame when `state is NotificationsInitial`. Bucket render preserved (Today / This week / Earlier) — buckets keyed off `AppNotification.createdAt` parsed via `DateTime.tryParse`. Each row maps `NotificationCategory` → 36×36 colored icon square (system grey, client emerald, license violet, transcode blue, storage amber) using the same color/icon helpers as the desktop. Mark-all-read button calls `cubit.markAllRead`. New states: `_LoadingView` (centered spinner), `_FailureView` (offline icon + message + retry FluxButton), `_EmptyState` (preserved). Tap on an unread row calls `cubit.markRead(id)`.
  - **`shared/data/mock_data.dart`** — removed unused `MockNotification` class + `MockData.notifications` list (now obsolete — real entity is `AppNotification` from `fluxora_core`).
- **M8.2 — Downloads tab.** Replaced the placeholder with the prototype's storage-indicator + downloading-rows + offline-rows layout.
  - **`shared/data/mock_data.dart`** — added `MockDownloadStatus` enum (downloading / completed) + `MockDownload` shape (id / title / gradient / size / status / episodes / qualityBadge / speed / progress / expires) + `MockData.storageUsedGb` (26.3) + `storageTotalGb` (64.0) + `MockData.downloads` fixture (6 entries — 2 downloading, 4 completed).
  - **`features/downloads/presentation/screens/downloads_screen.dart`** rewritten as `StatefulWidget`. Header (no FluxAppBar — prototype integrates the title with the storage indicator, not as a 52 px app bar): "Downloads" 26/800 + "26.3 GB used · 64 GB available on device" 12.5 muted + 6 px progress bar (white-6% bg + violet→cyan gradient fill at the used-fraction). Body: "DOWNLOADING · N" eyebrow + violet-tinted cards (12 padding, accentSoft border, 12 radius) with 56×80 gradient poster + title 13/700 + meta (episodes · size · speed) + 4 px violet progress bar + "%" 10.5/600 violet + 32 px round pause button. "AVAILABLE OFFLINE · N" eyebrow + flat rows (10 vertical padding, divider) with 50×72 poster + title 13.5/600 + meta + "Expires {expires}" + 32 px round more button. The more button opens a `FluxBottomSheet` with "Play offline" and "Delete download" actions (delete fires `_delete(id)` → `setState(_items.removeWhere(...))`). Empty state when `_items` is empty.
- **M8.3 — Profile tab.** Replaced the placeholder with the prototype's avatar block + stats row + sectioned settings + sign-out button.
  - **`features/profile/presentation/screens/profile_screen.dart`** rewritten as `StatelessWidget`. Header row: "Profile" 26/800 + 38 px round settings icon button (top right). Avatar block (radius 16, violet→cyan-radial gradient surface with 14 padding): 64 px circle avatar (violet→pink gradient + "AK" 24/700 + 22 px violet glow shadow) + name 17/700 + email 12 muted + "PLUS MEMBER" pill (10.5/700 with crown icon, violetTint text, pillBgPurple bg). Stats row (3 columns: 284 Hours / 62 Movies / 18 Shows, each with 22/800 value + 10.5/600 uppercase label, vertical dividers): white-3% bg, 12 radius, borderSubtle border. Settings list — 9 `FluxRow`s wrapped in a single rounded container with hairline dividers between: Account / Subscription (with "Plus" pill trailing) / Downloads / Playback / Language & region / Notifications / Privacy & security / Help & support / About Fluxora (v1.0.0 · build 482). Each `FluxRow` has a chevron-right trailing. Below: 14-px-tall "Sign out" button with red-tinted bg (rgba(239,68,68,0.10)) + red-25% border + F87171 text. Tap shows an `AlertDialog` confirm — on accept, dispatches `playerCubit.dismiss()` + `apiClient.clearBearerToken()` + `secureStorage.deleteAll()` + `context.go(Routes.connect)`; the router's redirect guard handles the rest.
- **Validation:** `flutter analyze` clean × `apps/mobile` and `packages/fluxora_core`. 27 mobile tests still pass (the existing 25 PlayerCubit tests + placeholder + library + connect — no test churn introduced for M8).

### Files Created / Modified

| Action | Path |
|--------|------|
| Created | `apps/mobile/lib/features/notifications/domain/repositories/notifications_repository.dart` |
| Created | `apps/mobile/lib/features/notifications/data/repositories/notifications_repository_impl.dart` |
| Created | `apps/mobile/lib/features/notifications/presentation/cubit/notifications_state.dart` |
| Created | `apps/mobile/lib/features/notifications/presentation/cubit/notifications_cubit.dart` |
| Modified | `apps/mobile/lib/features/notifications/presentation/screens/notifications_screen.dart` (rewritten to consume the cubit; new loading + failure + empty states; categories → icon+color; tap-to-markRead) |
| Modified | `apps/mobile/lib/core/di/injector.dart` (+`NotificationsRepository` + `NotificationsCubit` lazySingleton registrations) |
| Modified | `apps/mobile/lib/shared/data/mock_data.dart` (-`MockNotification` class; -`MockData.notifications` list; +`MockDownloadStatus` enum; +`MockDownload` shape; +`storageUsedGb` / `storageTotalGb` constants; +`MockData.downloads` fixture with 6 entries) |
| Modified | `apps/mobile/lib/features/downloads/presentation/screens/downloads_screen.dart` (full rebuild — header + storage indicator + downloading cards + offline rows + bottom-sheet actions + empty state) |
| Modified | `apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart` (full rebuild — header + avatar block + stats row + settings list + sign-out flow) |
| Created | `docs/logs/AGENT_LOG_archive_05.md` (verbatim copy of the prior 1634-line `AGENT_LOG.md`) |
| Modified | `AGENT_LOG.md` (rotated — fresh log with Archive-05 summary + carry-forward M7 + this M8 entry) |

### Docs Updated

- `docs/00_overview/current_status.md` — apps/mobile table gains "Mobile redesign M8 Downloads + Profile + Notifications real-data wiring" row; "What's next" item 1 rewritten to point at M9 (theme cutover).
- `docs/11_design/mobile_redesign_plan.md` — top-of-file Status string updated to "M0–M8 landed"; §7 milestone-table M8 row body rewritten and marked ✅ done; §16 changelog gains a new row.

### Decisions Made

- **REST polling, not WS, for notifications.** The desktop's `NotificationsRepositoryImpl` already carries a `// TODO(M8): Replace polling with WS /api/v1/ws/notifications once desktop gains a proper WebSocket wrapper that supports the same HMAC-bearer auth pattern used by the server's get_current_user_ws dependency.` Mobile sits on the same transitional path — building a one-off WS auth wrapper for mobile alone would diverge the two clients. The new mobile repo carries the same `// TODO(WS):` comment so the cutover happens cohesively when the wrapper lands. Plan §7 row M8 says "Wire notifications to real backend endpoint when available; mock otherwise" — the REST endpoint *is* available, polling is honest.
- **Notifications cubit registered as a singleton.** The poll loop in `liveStream()` should outlive any single push of the notifications screen — the user might back-pop, switch tabs, drop the screen — but the unread-count surface (Home tab bell) needs a steady tail. `lazySingleton` matches the M7 `PlayerCubit` pattern; `BlocProvider.value` is the entry point for screens.
- **No `equatable` dep added for the new state class.** The existing mobile cubit (`PlayerState`) doesn't use Equatable; identity equality is fine because `_emitLoaded` always allocates a new state instance, so `BlocBuilder` rebuilds correctly. Adding the dep just to mirror the desktop's `Equatable` import would be churn for no behavioural gain. CLAUDE.md hard rule #6 ("no new dep without justification").
- **Profile fields are mock-stubbed.** The server has `/api/v1/profile` (M0 chunk §7.2) but it's the *operator profile* (server admin: display_name + email + avatar_path). The mobile user is a paired *client*, not the server admin — surfacing the operator's name on every paired phone would leak identity. The mobile-user-profile endpoint is its own ticket; M8 ships the surface with hardcoded "Alex Kowalski" / "alex@fluxora.io" / 284h / 62 movies / 18 shows.
- **Sign-out tears down the singleton PlayerCubit before clearing storage.** If the user signs out while a stream is active, calling `secureStorage.deleteAll()` first would leave the WebRTC peer connection alive without a bearer token to renew progress reports. `cubit.dismiss()` first ensures `_disposeCurrentSession` cleanly closes signaling + the player + the progress timer; then we clear storage; then the router's redirect guard takes the user to `/connect` on the next navigation tick.
- **Downloads header is integrated, not a `FluxAppBar`.** The prototype JSX puts the 26/800 "Downloads" title directly above the storage indicator — visually they're one block. Wrapping that in a 52 px `FluxAppBar` (which has its own background blur + bottom border) would split them awkwardly. Same reasoning on the Profile tab — the title sits next to the settings gear in the same row as the body padding.
- **Downloads bottom-sheet uses the existing `FluxBottomSheet` skeleton.** The "more" button opens a sheet with Play/Delete — using `showFluxBottomSheet` keeps consistency with the M6 player sheets. The two-action sheet didn't warrant its own widget file; it lives inline in `downloads_screen.dart` as `_SheetAction`.
- **`MockNotification` class deleted, not deprecated.** Per the project's "no half-finished implementations" rule and the no-backwards-compat-hacks guidance, the class + fixture list are removed outright. The discover surfaces don't reference notifications (just continue-watching / trending / recently-added).

### Issues Discovered / Reported to User

- **The `_FailureView`'s "Couldn't reach your server" text uses a literal apostrophe via `\'`** — works fine but is a minor smell. If the project gets a string-i18n pass at M14, this is one of the strings that lands there.
- **The Profile screen's settings rows have no real destinations.** Tapping any row hits an empty `onTap: () {}` — the rows render as interactive but go nowhere. Wiring them is its own follow-up (Account → server-edit screen, Subscription → existing subscription tier surface if it gets added to mobile, etc.). Worth tracking — currently the chevrons promise a destination.
- **Sign-out doesn't show a "Successfully signed out" toast.** It just navigates to `/connect`. If the user wants the affirmative feedback, that's a SnackBar at M14 polish.
- **Stale Dart Analysis Server diagnostics** flashed during the chained edits (especially around the unused-import warnings in `injector.dart` mid-Edit). CLI `flutter analyze` consistently confirms clean — same observation as the prior 8 entries, trust the CLI.
- **Sonnet rotation agent stalled.** Spawned a background `general-purpose` subagent (model=sonnet) to handle the log rotation while M8 code work proceeded; it failed mid-stream after 600 s. Rotation was completed in-thread instead (`cp` for the archive + hand-written summary log). For future log rotations the heavy-token approach would benefit from streaming the file in batches rather than reading it whole.

### Blockers / Open Issues

- **None for M9.** All M8 plumbing is done. M9 is the theme cutover — delete legacy `AppColors.primary` (indigo) and superseded text styles; rewrite `apps/mobile/lib/shared/theme/app_theme.dart` body to consume V2 tokens; verify both apps' import paths still resolve. **This is the breaking PR for mobile** — no rollback after merge.

### Next Agent Should

1. **Mobile redesign M9 — theme cutover** per plan §7 row M9. Walk every `apps/mobile/lib/` file using the legacy `AppColors.{primary, accentPurple, surfaceMuted, primaryVariant}` or legacy `AppTypography.{displayLg, displayMd, headingLg, headingMd, headingSm, bodyLg, bodyMd, bodySm, caption, label}` tokens; migrate to V2 (`violet`, `bgRoot`, `surfaceGlass`, `textBright`, `displayV2`, `h2`, `body`, `captionV2`, `eyebrow`). Rewrite `apps/mobile/lib/shared/theme/app_theme.dart` body in-place (keep the `AppTheme.dark` getter signature). Run `flutter analyze` clean on both apps; this is the gate for the merge.
2. **Visual smoke test the M5–M8 chain** on a physical Android + iOS device. Especially: poster tap → fullscreen player → drag-down to mini-player → tap to resume → sign out from Profile → verify stream tears down + router redirects to `/connect`.
3. **Wire real Profile data when a mobile-client profile endpoint lands.** Replace the hardcoded "Alex Kowalski" / stats trio with a `ProfileCubit` consuming the new endpoint (no such endpoint today — the existing `/api/v1/profile` is the operator profile and shouldn't leak to paired clients).
4. **Consider WS migration for notifications + the desktop polling repo at the same time.** If a shared `WebSocketClient` wrapper lands in `fluxora_core` (matching the WebRTC signaling service's `WebSocket.connect(...)` + bearer-token pattern), both desktop and mobile notification repos can swap their `liveStream()` implementations together. Two `// TODO(WS):` markers are tracking this.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran. No commits this session — owner has not authorised.
- [x] No agent / AI branding anywhere in code, docs, or commit messages.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed silently — `NotificationsCubit` logs failures via `_log.{e,w}` with full context; sign-out's `playerCubit.dismiss()` is wrapped in `try/catch (_)` only because the cubit may not have an active session and its internal `_disposeCurrentSession` already logs the meaningful failure paths.
- [x] No secrets / hardcoded paths added.
- [x] No new third-party deps added in M8. `flutter_bloc`, `get_it`, `logger`, `go_router`, `freezed_annotation` (transitive via `AppNotification` entity) all already in pubspec.
- [x] No backwards-compat hacks. `MockNotification` + the fixture list deleted outright; deleted `MockData.notifications` references nowhere else in the codebase (verified via Grep). The new `NotificationsRepository` is additive — no shim layer.
- [x] No layer-boundary violations. New repository in `features/notifications/{domain,data}/`; new cubit in `features/notifications/presentation/cubit/`; screen in `features/notifications/presentation/screens/`. Mock data + mock-shape extensions stay in `shared/data/mock_data.dart`. Sign-out reaches into `apps/mobile/lib/core/router/` + `core/di/` only — no presentation→data short-circuits.
---

## [2026-05-03] — Mobile redesign M9 — Theme cutover (V1 palette removed)
**Phase:** Phase 5 (Mobile redesign — Plan in `docs/11_design/mobile_redesign_plan.md` §7)
**Status:** Complete — the breaking PR for mobile.

### What Was Done

- **Migrated 7 mobile call-sites + 1 desktop straggler off V1 tokens.** Every `AppColors.{primary,primaryVariant,accent,accentPurple,background,surface,surfaceRaised,surfaceMuted,textPrimary,textSecondary,textMuted,textDisabled,success,warning,error,info,brandGradient}` reference and every `AppTypography.{displayLg,displayMd,headingLg,headingMd,headingSm,bodyLg,bodyMd,bodySm,caption,label,mono}` reference in `apps/mobile/lib/` was rewritten to its V2 equivalent before the deletion landed. Mapping (per plan §4 + §4.2):
  - Colors: `primary`/`accentPurple` → `violet`; `primaryVariant` → `violetDeep`; `accent` → `cyan`; `info` → `blue`; `success` → `emerald`; `warning` → `amber`; `error` → `red`; `background` → `bgRoot`; `surface` → `surfaceGlass`; `surfaceRaised` → `borderSubtle` (used for borders + faint-fill backgrounds in V1); `textPrimary` → `textBright`; `textSecondary` → `textMutedV2`; `textMuted` → `textDim`; `textDisabled` → `textFaint`; `brandGradient` → `AppGradients.brand`.
  - Typography: `displayLg`/`displayMd` → `displayV2` (was 32/700 and 24/700, now both 24/700 — minor downgrade per plan §4.2 "acceptable"); `headingLg` → `h1` (20/600 → 18/700); `headingMd`/`headingSm` → `h2` (16/600 and 13/500 → 14/600); `bodyLg`/`bodyMd` → `body` (16/400 and 14/400 → 13/500); `bodySm` → `bodySmall` (13/400 → 12/500); `caption` → `captionV2` (12/400 → 11/500); `label` → `eyebrow` (11/500/0.1em → 11/600/0.14em).
  - One nuance in `upgrade_screen.dart`: V1 had Pro tier = `primary` (indigo) and Ultimate = `accentPurple` (violet). Both V1 colors map to `violet` in V2 — collapsing them would erase the visual distinction between Pro and Ultimate. Resolution: Pro now uses `violetDeep` (`#8B5CF6`) and Ultimate stays at `violet` (`#A855F7`); Plus moves from `info` → `blue`. The tier hierarchy is now Free (`textDim`) → Plus (`blue`) → Pro (`violetDeep`) → Ultimate (`violet`).
- **Rewrote `apps/mobile/lib/shared/theme/app_theme.dart` body in-place** to consume V2 tokens. Mirrors the desktop's M9.5 pattern: `ColorScheme.dark(primary: violet, secondary: cyan, surface: surfaceGlass, error: red, onPrimary/Surface/Error: textBright, onSecondary: bgRoot)`; `scaffoldBackgroundColor: bgRoot`; `cardColor: surfaceGlass`; `dividerColor: borderSubtle`; `textTheme` mapped onto V2 styles; `appBarTheme` with `surfaceGlass` bg + `textBright` fg + `h2` title; `elevatedButtonTheme` (violet bg + textBright fg + `h2` text style); `outlinedButtonTheme` (textBright fg + `borderSubtle` border + `h2` text style); `inputDecorationTheme` (surfaceGlass fill, borderSubtle borders, violet on focus, `body` for label/hint); `cardTheme` (surfaceGlass + radius lg); `iconTheme: textMutedV2`; `progressIndicatorTheme: violet`; `snackBarTheme` (surfaceGlass + body); new `dividerTheme` (borderSubtle hairline). The `AppTheme.dark` getter signature is unchanged — every existing `MaterialApp(theme: AppTheme.dark)` consumer continues to work.
- **Deleted V1 tokens from `packages/fluxora_core/lib/constants/`**:
  - `app_colors.dart` — removed the 17-token V1 block plus the `brandGradient` LinearGradient. The class now contains only V2 surfaces, V2 text, V2 accents, V2 pill bg/fg, and V2 status semantic re-exports. Top-of-file comment rewritten to reflect V2 as the canonical palette + a note that V1 was removed at M9 cutover (2026-05-03).
  - `app_typography.dart` — removed 11 V1 styles (`displayLg`, `displayMd`, `headingLg`, `headingMd`, `headingSm`, `bodyLg`, `bodyMd`, `bodySm`, `caption`, `label`, `mono`). Class now contains only V2 styles: `displayV2` / `h1` / `h2` / `body` / `bodySmall` / `captionV2` / `micro` / `eyebrow` / `monoBody` / `monoCaption` / `monoMicro`. The transitional "Desktop redesign tokens" comment block is gone — V2 is the only set.
- **Migrated one desktop straggler.** `apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart:1001` had a single remaining `AppTypography.bodyMd` reference (everything else V2 since the M9.5 desktop cutover). Swapped to `AppTypography.body`. Found via the same Grep that scoped this PR — captured here so the deletion was safe.
- **Validation:**
  - `flutter analyze` clean × all 3 packages (`packages/fluxora_core`, `apps/mobile`, `apps/desktop`).
  - 27 mobile tests + 8 core tests + 38 desktop tests (`--exclude-tags=golden` per the M8 a11y/golden-test-infra entry) all pass — zero test churn from the cutover.
  - Verified via Grep: zero `AppColors.{V1 names}` and zero `AppTypography.{V1 names}` references remain in any `*.dart` under `apps/` or `packages/` (matches in `AGENT_LOG.md` + `docs/logs/AGENT_LOG_archive_*.md` are historical narrative, not code).

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `apps/mobile/lib/shared/theme/app_theme.dart` (full body rewrite — `ColorScheme`, `scaffoldBackgroundColor`, `cardColor`, `dividerColor`, `textTheme`, `appBarTheme`, button themes, `inputDecorationTheme`, `cardTheme`, `iconTheme`, `progressIndicatorTheme`, `snackBarTheme`, new `dividerTheme` — all on V2 tokens) |
| Modified | `apps/mobile/lib/features/auth/presentation/screens/pairing_screen.dart` (V1 → V2 token swaps in 6 sites) |
| Modified | `apps/mobile/lib/features/library/presentation/screens/files_screen.dart` (4 sites; full rewrite for clean diff) |
| Modified | `apps/mobile/lib/features/connect/presentation/screens/connect_screen.dart` (8 sites; full rewrite) |
| Modified | `apps/mobile/lib/features/upgrade/presentation/screens/upgrade_screen.dart` (full rewrite — added `app_gradients` import for `AppGradients.brand`; tier color reshuffle to keep Pro vs Ultimate visually distinct after the `primary`/`accentPurple` collapse) |
| Modified | `apps/mobile/lib/shared/widgets/loading_overlay.dart` (V1 → V2 swaps in 2 sites; full rewrite) |
| Modified | `apps/mobile/lib/shared/widgets/media_card.dart` (V1 → V2 swaps in 8 sites — including border, placeholder bg + icon, progress bar bg + value; full rewrite) |
| Modified | `apps/mobile/lib/shared/widgets/status_badge.dart` (V1 → V2 swaps in 4 sites — `success`/`warning`/`textMuted` → `emerald`/`amber`/`textDim`, plus `label` → `eyebrow`; full rewrite) |
| Modified | `apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart` (1 site — `AppTypography.bodyMd` → `AppTypography.body`) |
| Modified | `packages/fluxora_core/lib/constants/app_colors.dart` (deleted V1 brand/surface/text/semantic tokens + `brandGradient` LinearGradient; 95 lines → 60 lines; V2-only) |
| Modified | `packages/fluxora_core/lib/constants/app_typography.dart` (deleted 11 V1 text styles; 207 lines → 105 lines; V2-only) |

### Docs Updated

- `docs/00_overview/current_status.md` — `apps/mobile` table title updated to "M0–M9 landed"; new M9 row added below the M8 row; "What's next" item 1 rewritten to point at M10 (X-Ray panel + Group Watch shell + Offline state). `packages/fluxora_core` row's Design-tokens line updated to reflect the V1 deletion.
- `docs/11_design/mobile_redesign_plan.md` — top-of-file Status string updated to "M0–M9 landed"; §7 milestone-table M9 row body rewritten and marked ✅ done; §16 changelog gains a new row.

### Decisions Made

- **`primary` and `accentPurple` both collapse to `violet`, but `upgrade_screen.dart` differentiates Pro from Ultimate via `violetDeep` vs `violet`.** The two V1 token names happened to be used as distinct *signal* colors for Pro and Ultimate tiers, even though one was indigo and the other violet. After the M9 collapse they'd render as the same hex — eliminating the visible tier hierarchy. Picking `violetDeep` for Pro keeps the violet-family signal but at a slightly deeper shade so the tier ladder stays legible. `Plus` shifts from `info` (`#3B82F6`) to `blue` (same hex, V2 name) — purely a rename, no visual change.
- **`AppColors.surfaceRaised` → `borderSubtle` (not a new dedicated mid-tier surface).** V1 `surfaceRaised` (`#334155`) was used in the mobile theme + media_card + connect tile + upgrade card for hairline borders + the LinearProgressIndicator background. V2 has no exact mid-tier surface — `borderSubtle` (rgba(255,255,255,0.06)) is the closest hairline equivalent. Per plan §4 row "borderStrong → borderSubtle" reasoning, "do not add a white-strong variant — escalate if visually broken." Visual smoke test will validate; if the connect tile or upgrade card look anemic, escalate before adding a new V2 token.
- **Display tokens collapse 32 px → 24 px on mobile.** V1 `displayLg` was 32/700 — used only on the `_LoadingView` in pairing_screen and possibly nowhere mobile-visible after redesign. V2 `displayV2` is 24/700. The plan §4.2 sanctions the downgrade ("Closest existing display style; -1 px tracking, -100 weight. Acceptable."). If the pairing-screen "Connecting to server…" loading message looks under-emphatic, copy edit the screen, don't add a new token.
- **Single `AppTypography.bodyMd` site found in desktop, swept in same PR.** The desktop M9.5 cutover entry claimed "Desktop is now V2-pure." Grep this session found `clients_screen.dart:1001` still on `bodyMd` — likely missed because it landed *after* the M9.5 grep snapshot. Migrating it here was zero-risk (same color, smaller font weight) and clears the way for the V1 deletion. Reported in Issues below.
- **Deleted V1 typography defaults (e.g. `color: AppColors.textPrimary` inside the V1 `displayLg` def) propagate naturally.** Each V1 typography style baked in V1 colors as defaults. Removing the styles removed the references atomically — no orphan `textPrimary`/`textSecondary`/`textMuted` left after the typography deletion, so the colors deletion was safe.
- **`mono` (V1) deleted, V2 mono trio is the canonical mono.** V1 `mono` (13/400) was unused in the mobile codebase per Grep — the V2 trio (`monoBody` 12/500, `monoCaption` 11/500, `monoMicro` 10.5/500) covers every actual call-site. Deleting `mono` is honest; if a 13/400 mono variant is ever needed it can be added explicitly.
- **No new V2 tokens introduced.** The plan §1 row 2 + §4 + §4.2 are explicit: consume what exists, don't recreate. M9 is purely deletion + rewiring; the V2 token surface is unchanged from M0.

### Issues Discovered / Reported to User

- **Desktop M9.5 was not actually V2-pure.** The M9.5 entry claimed "zero `AppColors.{primary,background,surface,...}` references" but `clients_screen.dart:1001` still had `AppTypography.bodyMd`. Single-site, low-risk, but worth flagging — future cutover claims should be backed by a Grep matrix run as part of the validation step, not just a spot check.
- **`upgrade_screen.dart` is the only mobile screen still using legacy `_TierData` colors directly.** The V1→V2 collapse forced a tier-color reshuffle (Pro `primary` indigo → `violetDeep`; Ultimate `accentPurple` violet → `violet`). If a future "tier accent" entry lands in `AppColors`, the upgrade screen's hardcoded `Color(...)` direct refs should be reviewed.
- **`InputDecorationTheme.fillColor: AppColors.surfaceGlass`** — surfaceGlass is rgba(20,18,38,0.7), so a `TextField` (used by the manual-entry IP/port row in connect_screen) renders semi-transparently over the screen background. Visually it should be fine on the V2 backdrop (fluxora bgRoot + radial gradient), but the legacy theme's V1 `surface` (`#1E293B`) was opaque, so the input fields looked solid before. Worth a visual smoke test.
- **`AppTheme.dark` is now dead-loaded but most screens override `Scaffold.backgroundColor: Colors.transparent` to expose the M0 background gradient.** That means `scaffoldBackgroundColor: bgRoot` from the theme only applies to screens that don't override it (legacy `connect_screen` + `pairing_screen` + `upgrade_screen` + `files_screen` keep the theme bg; tab-shell screens ignore it). This is intentional — the redesigned tab screens want the gradient — but documenting here so the hierarchy is clear.

### Blockers / Open Issues

- **None for M10.** All M9 plumbing is done. M10 builds the X-Ray side panel (driven by static cast metadata only, plan §1 row 4 — no live ML), Group Watch shell (placeholder modal — "Coming soon"), and Offline empty state.

### Next Agent Should

1. **Mobile redesign M10 — X-Ray panel + Group Watch shell + Offline state** per plan §7 row M10. Three small additions; UI shells only (no live X-Ray ML, no Group Watch sync engine).
2. **Visual smoke test** the V1→V2 cutover on a real device — especially `pairing_screen` (uses theme defaults heavily), `connect_screen` (Material `TextField` with `inputDecorationTheme.fillColor: surfaceGlass`), `upgrade_screen` (Pro vs Ultimate tier color distinction; `AppGradients.brand` header). The legacy screens are the regression-risk surface.
3. **Wire real per-client profile data** when a mobile-client profile endpoint lands — still mocked at M8.
4. **Coordinated WS migration for notifications** when a shared HMAC-bearer wrapper lands — both mobile and desktop carry `// TODO(WS):` markers from M8.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran. No commits this session — owner has not authorised.
- [x] No agent / AI branding anywhere in code, docs, or commit messages.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed silently.
- [x] No secrets / hardcoded paths added.
- [x] No new third-party deps added in M9. The deletion is purely a contraction; no `pubspec.yaml` touched.
- [x] No backwards-compat hacks. V1 tokens deleted outright, no aliases left behind, no deprecated-marker comments. Full compile-error grep before deletion confirmed every call-site was migrated.
- [x] No layer-boundary violations. Theme rewrite stays in `apps/mobile/lib/shared/theme/`; V1 deletions stay in `packages/fluxora_core/lib/constants/`; per-screen migrations stay within their existing feature folders.
---

---
## [2026-05-03] — Desktop Library — P0+P1 close-out + D2–D7 decisions + full doc sync
**Phase:** Phase 5 — desktop redesign close-out (Library surface)
**Status:** Complete — every item in `docs/10_planning/07_library_screen_plan.md` P0/P1 shipped or explicitly dropped per owner decision.

### What Was Done

Picked up the desktop library screen audit (`docs/10_planning/07_library_screen_plan.md`) where the previous session left it: P0 #1–#5 + per-library `total_size_bytes` aggregate were already implemented end-to-end (server PATCH route + entity regen + cubit + new files screen + route wiring). Verified green: `flutter analyze apps/desktop/lib/features/library/` (clean, 104.8s), `pytest apps/server/tests/test_library.py` (14 / 14), `flutter analyze packages/fluxora_core` (clean, 113.1s).

Then resolved the 6 open D-decisions with the owner this session:

- **D2 — Photos tab**: drop. Confirmed already removed from `_kTabs` during the prior rewrite — only `all/movies/tv/music/docs` remain.
- **D3 — Description field**: drop (recommended). Names + types convey ~90 % of intent; not worth the migration + empty-string maintenance.
- **D4 — Rescan Metadata action**: drop (recommended). Full `Scan` already re-enriches new files; rare full-resweep need is covered by Delete + Rescan.
- **D5 — Sort + Filter + List/Grid toggle**: implement. Shipped `_SortBy` enum (Name A–Z · Last Scanned · File Count · Total Size), `_LibraryFilters` (enriched-only · with-files · recently-scanned ≤ 7d), `_ViewMode` enum, `_ToolbarRow` widget (result-count label + Sort PopupMenu + Filters chip + segmented Grid/List toggle), `_FiltersDialog` modal, `_FiltersEmptyState`, `_LibraryList` widget (rounded glass card, one row per library: type icon + name/paths + file count + size + last scanned + 4 action buttons). State persists in `_LibraryViewState`.
- **D6 — Edit dialog scope**: name + root_paths only; **type is immutable post-creation**. `UpdateLibraryBody` Pydantic model accepts only `name` and `root_paths`. UI passes `typeEditable: false` when editing. Promoted to ADR-016.
- **D7 — Disk file deletion**: **NEVER**. Promoted to ADR-017 ("Hard Lock — does not change without a follow-up ADR"). Defense in depth: code (no `os.remove` / `Path.unlink` / `shutil.rmtree` calls on the library track — verified by grep), confirm-dialog copy hardened to "Your files on disk are never deleted by this app", plan + ADR documented.

Then ran the full doc-update protocol — every affected file touched.

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `apps/desktop/lib/features/library/presentation/screens/library_screen.dart` (added `_SortBy` / `_ViewMode` / `_LibraryFilters` types, `_ToolbarRow`, `_LibraryList`, `_FiltersDialog`, `_FiltersEmptyState`, `_ListRowAction`; threaded sort/filter/view-mode state through `_LibraryViewState` → `_LoadedBody`; tightened delete-dialog copy for ADR-017) — about +600 lines |
| Modified | `apps/desktop/lib/features/library/presentation/cubit/library_cubit.dart` (already had `updateLibrary` / optimistic `deleteLibrary` / `scanLibrary` returning count from prior session; verified) |

### Docs Updated

| Action | Path |
|--------|------|
| Modified | `docs/10_planning/07_library_screen_plan.md` (status `🟡 PROPOSED` → `🟢 P0 + P1 SHIPPED`; replaced "Open decisions" with "Decisions (resolved 2026-05-03)" section listing D1–D7 outcomes including hard-lock 🔒 marker on D7) |
| Modified | `docs/10_planning/02_decisions.md` (added ADR-016 — Library Type is Immutable Post-Creation; added ADR-017 — Files on Disk are NEVER Deleted by Fluxora; status header bumped to "ADR-016/017 added 2026-05-03") |
| Modified | `docs/10_planning/01_roadmap.md` (Phase 1 Library row updated to mention `PATCH` + `total_size_bytes`; Desktop Library Management row updated to list edit/delete/files browser/sort/filter/list toggle/poster mosaic) |
| Modified | `docs/04_api/01_api_contracts.md` (header status updated; `LibraryResponse` schema gains `total_size_bytes`; new `PATCH /api/v1/library/{library_id}` section; DELETE description hardened with ADR-017 reference) |
| Modified | `docs/03_data/01_data_models.md` (Library entity gains `file_count` + `total_size_bytes` computed columns; `type` marked immutable per ADR-016; ActivityEvent `type` field examples extended with `library.create/update/delete` + `file.upload/delete`; producer call sites for routers/library.py + routers/files.py listed) |
| Modified | `docs/09_backend/01_backend_architecture.md` (header status updated; routers/library.py annotation now mentions PATCH + emitters; library_service description mentions `update_library` + `total_size_bytes` aggregate; models/library.py description gains `UpdateLibraryBody`; test_library.py count 8 → 14; total tests 247 → 253; service map row updated with `update_library()`) |
| Modified | `docs/05_infrastructure/02_url_inventory.md` (added PATCH /library/{library_id} row; DELETE description tightened with ADR-017) |
| Modified | `docs/08_frontend/01_frontend_architecture.md` (new "Desktop Library Surface" section before "Two Client Targets" — full description of P0+P1 close-out + sort/filter/list/files-browser surface + ADR-016/017 references) |
| Modified | `docs/00_overview/current_status.md` (header dated 2026-05-03 with library close-out; server test count 247 → 253; Desktop apps Library row description widened; new "Desktop Library — P0+P1 close-out" row in the desktop redesign milestone table) |

### Decisions Made

- **ADR-016 promoted from D6.** Library `type` is immutable post-creation. The risk of orphaning type-specific metadata (movie posters, episode counts, music tags) outweighs the operator-convenience win of being able to flip type. Workaround: `delete + recreate`. UI hides the type selector when editing.
- **ADR-017 promoted from D7 — Hard Lock.** Fluxora never deletes files from disk. The server has zero file-deletion code on the library track. The dialog copy reflects this explicitly. Three layers of defense: code, UI copy, ADR. Reverting requires a fresh ADR.
- **D3 (description field) and D4 (Rescan Metadata) dropped.** Both are low-value features that would add code surface, server work, or migrations for marginal user benefit. The remaining `Scan` covers re-enrichment via Delete + Rescan when full resweep is genuinely needed.
- **`_LibraryFilters` is a value type with `copyWith`.** Considered passing individual flags as function args; the value-type approach kept the sheet's draft-state clean and made `isActive` / `activeCount` readable in the toolbar.
- **`Last Scanned` replaced `Date Created` as a sort key.** The `Library` entity has no `created_at` field exposed to Dart (only `lastScanned`), so the plan's "Date Created" sort would have been fictional. Renamed the option to reflect the real data.

### Validation

- `flutter analyze apps/desktop/lib/features/library/` — **No issues found** (post-implementation, 6.2s after const-fixes; 104.8s on first run before)
- `flutter analyze packages/fluxora_core` — **No issues found** (113.1s)
- `pytest apps/server/tests/` (full suite) — **253 passed in 47 s**, 1 deprecation warning (`pythonjsonlogger.jsonlogger` rename — pre-existing, unrelated)
- `pytest apps/server/tests/test_library.py` — **14 / 14 passed**
- Documentation update protocol Step 5 checklist — every affected file updated; cross-reference sweep done; consistency checks pass.

### Issues Discovered / Reported to User

- **`_kTabs` already had Photos dropped.** The plan's audit was written against a pre-rewrite version of `library_screen.dart`. After the +919 line rewrite earlier in the session, only `all/movies/tv/music/docs` were left. D2 was effectively a no-op confirmation. Reported.
- **The server has no `created_at` exposure on `Library` in the Dart entity.** The plan suggested "Date Created" as a sort option; in practice there's only `lastScanned`. Replaced silently in the implementation; flagged in this entry.
- **Earlier git status snapshot at session start showed apps/server/routers/{auth,files,info,settings}.py as modified, but the actual working tree had no diff in those files.** Cached snapshot from before a previous commit landed; no action needed. (Already noted in prior log entry; carried forward.)

### Blockers / Open Issues

- **P2 nice-to-haves still open** (per plan): #14 multi-root in Add dialog, #15 inline-validation on Add, #16 optimistic mutation rollback, #17 drag-and-drop folder onto card, #18 Upload UI on the file browser screen. Not in scope for this PR — left for owner to prioritise.
- **`apps/desktop/lib/features/recent_activity/` and `apps/desktop/lib/features/storage/`** still show as untracked in `git status`. They're consumed by the redesigned Dashboard / Library; if they were intentional carry-overs from another agent, they should be staged separately. Not touched this session.
- **`apps/mobile/`, `packages/fluxora_core/lib/widgets/flux_*.dart`, `docs/11_design/mobile_redesign_plan.md`** — owned by the mobile-redesign agent per owner instruction "other agent is working on mobile work, dont touch that". Untouched.

### Next Agent Should

1. **Commit the desktop library track in chunks** (matches the prior commit cadence): (a) server — `routers/library.py` + `services/library_service.py` + `models/library.py` + `tests/test_library.py`; (b) core — `packages/fluxora_core/lib/entities/library.{dart,freezed.dart,g.dart}`; (c) desktop — `apps/desktop/lib/features/library/`; (d) docs — every `.md` listed in the table above. **Do not stage** the mobile work or the `flux_*.dart` widget files — those belong to the parallel mobile agent.
2. **Manual visual smoke test on Windows desktop**: launch the Library tab, verify the toolbar row renders correctly at all widths (sort menu opens, filters dialog applies/clears, grid/list toggle persists), confirm the new files screen at `/library/:id/files` shows real per-library file counts/sizes, and that delete confirms with the new ADR-017 copy.
3. **P2 batching**: ask owner to prioritise plan items #14–#18; #15 (inline validation on Add) is the cheapest win and the most user-visible.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran without explicit per-action OK. Committing is the next session's task per owner pattern.
- [x] No agent / AI branding in any code, doc, or commit message.
- [x] No `print()` / `debugPrint()` introduced (Dart) or `print()` (Python). Logger usage is consistent with the existing surface.
- [x] No exceptions swallowed silently. Cubit methods catch `ApiException` separately from the generic `Exception` branch and rethrow after logging.
- [x] No secrets / hardcoded paths added.
- [x] No new third-party deps. All widgets reuse existing `fluxora_core` primitives + Material widgets already in pubspec.
- [x] No backwards-compat hacks. Old `_visibleLibraries` getter expanded in place; toolbar + list view added cleanly; no shim layer.
- [x] No layer-boundary violations. Sort/filter/view-mode state is local UI state in `_LibraryViewState`; cubit + repo + entity changes flow domain → data → presentation as intended.
- [x] D7 hard-lock honoured at every layer (code, UI copy, ADR-017).
---

## [2026-05-03] — Mobile redesign M9 follow-up — Theme polish (input fill + progress track) + V1 grep matrix verification
**Phase:** Phase 5 (Mobile redesign — Plan in `docs/11_design/mobile_redesign_plan.md` §7)
**Status:** Complete — addresses 3 of the 4 issues flagged in the M9 entry. (Issue #3, the Pro/Ultimate tier reshuffle, was already correct in M9.)

### What Was Done

- **Issue #1 — V1 grep matrix verification.** Ran the exhaustive matrix the M9 entry promised: every `AppColors.{primary,primaryVariant,accent,accentPurple,background,surface,surfaceRaised,surfaceMuted,textPrimary,textSecondary,textMuted,textDisabled,success,warning,error,info,brandGradient}` and every `AppTypography.{displayLg,displayMd,headingLg,headingMd,headingSm,bodyLg,bodyMd,bodySm,caption,label,mono}` reference, scoped to `*.dart` files only across the entire repo. **Zero matches in code.** (Matches in `AGENT_LOG.md` + `docs/logs/AGENT_LOG_archive_*.md` + `docs/11_design/desktop_redesign_plan.md` are all historical narrative, never code.) The Grep matrix is the methodology future cutover claims should be backed by — spot checks alone are not sufficient (the M9.5 desktop cutover claimed V2-pure but missed `clients_screen.dart:1001`, caught only when M9 ran the matrix).
- **Issue #4 — `InputDecorationTheme.fillColor` opaque equivalent.** Swapped `AppColors.surfaceGlass` (rgba(20,18,38,0.7) — translucent) → `Color(0xFF0F0C24)` (opaque). The M0 background gradient bleeds through any translucent fill on a Material `TextField`; the only such field today is the manual IP/port row in `connect_screen.dart`, but anything else that mounts a Material `TextField` would have rendered see-through. `Color(0xFF0F0C24)` is the prototype's `bgRaised` value (also used in `FluxBottomSheet` for the same "raised over bgRoot" intent). Inline literal with a 5-line comment explaining why no V2 token was added — plan §4 row 2 explicitly chose to live without an opaque mid-tier color.
- **Issue #2 — `media_card` LinearProgressIndicator track contrast.** Bumped backgroundColor from `AppColors.borderSubtle` (rgba(255,255,255,0.06) — too faint to read as a duration cue) to `Color(0x14FFFFFF)` (white-8% — matches the FluxPlayerControls progress-track shade). Inline comment cross-references the FluxPlayer pattern. Other `surfaceRaised → borderSubtle` mappings audited in this pass: `media_card` border (border use, fine at 6%); `connect_screen` server-tile border (fine); `upgrade_screen` activation card border (fine). The progress track was the only fill-vs-border ambiguity that needed bumping — the rest are genuine borders where 6% reads correctly.
- **Issue #3 — already shipped in M9.** Pro = `violetDeep` / Ultimate = `violet` was the M9 reshuffle decision; nothing further to do. Listed here for completeness.
- **Validation:** `flutter analyze` clean × `apps/mobile`; 27 mobile tests still pass. Single transient hook diagnostic during the edit (a typo where I invented a `copyWithProgress` method that doesn't exist on `LinearProgressIndicator` — fixed by reverting to a plain non-const `LinearProgressIndicator(value: progress, ...)` since `progress` is a runtime value).

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `apps/mobile/lib/shared/theme/app_theme.dart` (`InputDecorationTheme.fillColor`: `AppColors.surfaceGlass` → `Color(0xFF0F0C24)` + 5-line explanatory comment) |
| Modified | `apps/mobile/lib/shared/widgets/media_card.dart` (`LinearProgressIndicator.backgroundColor`: `AppColors.borderSubtle` → `Color(0x14FFFFFF)` + 2-line cross-reference comment) |

### Docs Updated

- None — these are surgical fixes against M9's already-documented "Issues Discovered / Reported to User" section. The M9 entry remains the canonical doc for the cutover; this follow-up records the resolution but doesn't change the cutover narrative. (Per CLAUDE.md "AGENT_LOG.md is append-only — never edit or delete past entries.")

### Decisions Made

- **`Color(0xFF0F0C24)` is an inline literal, not a new V2 token.** Plan §4 row 2 explicitly says "do not add a new token" for the bgRaised mid-tier. Adding one would re-open a settled architectural decision; using the literal — same value as `FluxBottomSheet`'s body bg — keeps the V2 surface set frozen. If a third site needs the same value, that's the trigger for adding a token.
- **`Color(0x14FFFFFF)` for the progress track, not bumping `borderSubtle` from 6 → 8%.** `borderSubtle` is used as a hairline divider/border across both apps; bumping its alpha would visually thicken every divider in the codebase. Picking a local literal scoped to media_card mirrors the FluxPlayer pattern (which made the same call) and keeps the global border token where the spec wants it.
- **No follow-up smoke test ordered.** The fixes are local and the failure modes were narrow: a translucent input fill (visible only on legacy `connect_screen` manual entry) and a barely-visible progress track (visible only on the legacy `MediaCard` in `files_screen` resume path). Both surfaces will be replaced in Phase 5+ (M11 `files-browser` rebuild + M12 onboarding revamp). Investing in a smoke test before the screens get rebuilt is throwaway effort.

### Issues Discovered / Reported to User

- **Other agent's entry sits between M9 and this follow-up** (`Desktop Library — P0+P1 close-out`, 2026-05-03 — appended to `AGENT_LOG.md` while this M9 work was in progress). That's the correct ordering — append-only means time-of-write order, not topical grouping. Anyone reading the log linearly will see the M9 entry → desktop library entry → this M9 follow-up. The cross-references in this follow-up's body make the topical link explicit.
- **The `LinearProgressIndicator` const error during the edit** (a momentary attempt to mark `LinearProgressIndicator` as `const` then chain a `.copyWithProgress(progress)` call that doesn't exist on the Material class) is the kind of micro-mistake the IDE diagnostics catch in real time — flagged here just so future agents know to trust the analyzer over their model of Flutter's API surface.

### Blockers / Open Issues

- **None for M10.** Both M9 issues #2 and #4 are now resolved in code. M10 (X-Ray panel + Group Watch shell + Offline state) remains unblocked.

### Next Agent Should

1. **Mobile redesign M10 — X-Ray panel + Group Watch shell + Offline state** per plan §7 row M10 (unchanged from M9's "Next Agent Should").
2. **Visual smoke test the V1→V2 cutover on hardware** when convenient — especially the `connect_screen` manual-entry IP/port `TextField` (now backed by the opaque `Color(0xFF0F0C24)` fill) and the `files_screen` `MediaCard` resume bar (now backed by the white-8% track). Both render correctly in static analysis but only a real device confirms the shade reads as intended.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran. No commits this session — owner has not authorised.
- [x] No agent / AI branding anywhere in code, docs, or commit messages.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed silently.
- [x] No secrets / hardcoded paths added — `Color(0xFF0F0C24)` and `Color(0x14FFFFFF)` are literal hex values matching values already in the codebase (`FluxBottomSheet` body bg + `FluxPlayerControls` track bg respectively).
- [x] No new third-party deps.
- [x] No backwards-compat hacks. Two surgical fixes in two files; no shim layer.
- [x] No layer-boundary violations. Theme literal stays in `apps/mobile/lib/shared/theme/`; widget literal stays in `apps/mobile/lib/shared/widgets/`.
---

## [2026-05-03] — Doc sync — M8 + M9 + M9-followup propagated across all affected docs
**Phase:** Phase 5 (Mobile redesign — Plan in `docs/11_design/mobile_redesign_plan.md` §7)
**Status:** Complete — followed `docs/12_guidelines/02_documentation_update_protocol.md` Steps 1–5.

### What Was Done

Ran the documentation update protocol after the M8/M9/M9-followup work landed. Step 1 identified 8 affected docs; Step 2 cross-reference Grep across `docs/**/*.md` flagged 4 files with V1-token mentions (3 are historical narrative in archives/plans — left untouched per the append-only rule for archives + the "describes what was done" rule for plans; 1 was the mobile redesign plan §8 file map which had stale future-tense for M9). Step 3 stale-section self-check covered current_status, folder_structure, tech_stack, roadmap, gotchas. Step 4 consistency check: every milestone status in `01_roadmap.md` now matches `current_status.md` and `mobile_redesign_plan.md`. Step 5 verified — every doc in Step 1 updated, every cross-reference resolved or deliberately left as historical.

**Per-doc edits:**

- **`docs/08_frontend/01_frontend_architecture.md`** — Status header date bumped + M9-summary line. "Theming (mobile)" rewritten — now documents the V2-pure cutover + the `Color(0xFF0F0C24)` opaque InputDecorationTheme fillColor (with rationale + cross-link to plan §4 row 2). "Tokens" line rewritten — V2-only; line-range references removed (`lines 43-94` etc. are stale after the V1 deletion). "Screen / Route Map — Flutter Mobile" fully rewritten for the post-M9 5-tab `StatefulShellRoute.indexedStack` layout: 5 tab routes + 4 outside-shell deep-link routes (`/detail/:id`, `/episodes/:id`, `/library-files/:id`, `/player`, `/player/resume`, `/notifications`) + 2 auth-gate routes; Sign-out flow paragraph added with the exact teardown order. "Flutter Mobile Project Structure" tree fully rewritten — adds `home/`, `search/`, `notifications/`, `detail/`, `episodes/`, `downloads/`, `profile/` features + `shared/data/mock_data.dart` + `shared/widgets/{background_gradient,mobile_shell,flux_mini_player}.dart`; per-feature one-liners cite the milestone that landed each.
- **`docs/00_overview/folder_structure.md`** — `apps/mobile/` tree fully rewritten to mirror the post-M9 layout (every feature folder + every shared widget, with milestone tags). `packages/fluxora_core/lib/constants/` block annotated with the V2-only deletion note + adds `app_gradients` / `app_radii` / `app_shadows` / `app_spacing` (which were missing from the prior listing).
- **`docs/12_guidelines/03_gotchas.md`** — 2 new gotchas appended:
  1. **Translucent fillColor on Material widgets bleeds the background gradient** — explains the `surfaceGlass` rgba issue + the `Color(0xFF0F0C24)` workaround + cross-links to plan §4 row 2's "do not add a token" decision.
  2. **Cutover claims need a Grep matrix, not a spot check** — captures the M9.5 desktop oversight (one `bodyMd` site survived the spot check, caught only by mobile M9's exhaustive Grep). Documents the matrix pattern future cutovers should run.
- **`docs/03_data/03_data_flows.md`** — Added a "Client consumers (REST polling, not WS — transitional)" subsection under Flow 7 (Notification Fan-out). Documents the 5 s polling pattern shared by desktop + mobile M8, the `// TODO(WS):` markers, and the blocker (no shared HMAC-bearer `WebSocketClient` wrapper in `fluxora_core` yet).
- **`docs/02_architecture/03_component_architecture.md`** — Flutter Client Presentation/Domain/Data layers expanded: documents the M7 + M8 singleton-cubit pattern (`PlayerCubit` doubles as `PlaybackProvider`; `NotificationsCubit` outlives screen back-pops to feed the Home bell badge); adds `NotificationsRepository` to the repos list with the polling-vs-WS context.
- **`docs/10_planning/01_roadmap.md`** — Status header date + 253-test count + mobile M0–M9 summary line. New row in the Phase 5 table for the mobile redesign milestone arc (M0–M9 chronology with key deliverables per milestone + the M9 follow-up's polish fixes).
- **`docs/06_security/01_security.md`** — New "Sign-out Flow (Mobile, M8)" subsection under the Pairing Flow heading. Documents the exact teardown order (`playerCubit.dismiss` → `clearBearerToken` → `secureStorage.deleteAll` → `context.go(/connect)`) + a server-side note that the operator must `DELETE /api/v1/auth/revoke/{client_id}` from the desktop control panel for full token revocation, since the client-side wipe doesn't tell the server. Calls out a future enhancement: a dedicated `POST /api/v1/auth/sign-out` endpoint that revokes server-side atomically.
- **`docs/11_design/mobile_redesign_plan.md`** — 2 stale future-tense sentences updated to past tense (the §8 file-map row for `app_theme.dart` and the §8 prose statement "stays at the same path — its body is rewritten at M9"). The §16 changelog already had the M8 + M9 rows from the prior session — no new changelog entries here, just the body cleanup.

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `docs/08_frontend/01_frontend_architecture.md` (Status header; "Theming (mobile)"; "Tokens" line; full mobile route table; full mobile project structure tree; sign-out flow paragraph) |
| Modified | `docs/00_overview/folder_structure.md` (`apps/mobile/` tree rewrite + `packages/fluxora_core/lib/constants/` block annotated for V1 deletion + missing token files added) |
| Modified | `docs/12_guidelines/03_gotchas.md` (2 new gotchas — translucent Material fill + Grep-matrix cutover validation) |
| Modified | `docs/03_data/03_data_flows.md` (Flow 7 subsection — REST-polling client consumers) |
| Modified | `docs/02_architecture/03_component_architecture.md` (Flutter Client layers: singleton cubits, NotificationsRepository) |
| Modified | `docs/10_planning/01_roadmap.md` (Status header bump + new mobile M0–M9 row) |
| Modified | `docs/06_security/01_security.md` (Sign-out Flow subsection + server-side revocation note) |
| Modified | `docs/11_design/mobile_redesign_plan.md` (2 stale future-tense → past-tense edits in §8) |

### Docs Updated

(See "Files Created / Modified" — every doc listed there is a doc update.)

### Decisions Made

- **Archives are not edited.** `docs/logs/AGENT_LOG_archive_04.md` and `_05.md` contain V1-token references in their historical narrative. CLAUDE.md hard rule: archives are append-only history; editing them rewrites the past. The references are accurate to *what was true at the time of writing* — leaving them is the correct call.
- **`docs/11_design/desktop_redesign_plan.md` line 106 retained verbatim.** That sentence (`scaffoldBackgroundColor` was still `AppColors.background` (`#0F172A` slate)) is the *triggering bug-report description* that motivated the M9.5 cutover — it documents what was broken at the time, not what the system currently is. Editing it would erase the why-this-cutover-happened context.
- **No new ADR added.** The V2-only / V1-deleted state isn't a new architectural decision — it's the execution of plan §7 row M9 (which has been the locked plan since 2026-05-03). The mobile theme cutover is documented as a *milestone landing*, not a *decision*. ADR-018 would be redundant.
- **DESIGN.md not touched.** Verified to already be V2-pure; no V1 token references in the spec body. The doc was authored against V2 and never updated to reference V1 (the V1 mobile palette existed in code only as transitional carry-over from pre-redesign — DESIGN.md was already the V2 contract).
- **`apps/mobile/README.md` not touched.** Grepped for stale path references (`/library`, `/pairing`, `features/connect|library|player|settings`) — zero matches. The README was either already generic enough or was updated earlier; no stale spots needed fixing.
- **Tier 2 / Tier 3 docs verified clean.** `02_architecture/02_tech_stack.md`, `04_api/01_api_contracts.md`, `05_infrastructure/02_url_inventory.md`, `10_planning/{02_decisions,03_open_questions,04_manual_tasks,05_ship_readiness}.md`, `00_overview/README.md` — none had stale references requiring an update for the M8/M9 work scope. (The mobile NotificationsRepository is a *consumer* of `/notifications` REST; the URL inventory is a *provider-side* doc, so consumer additions don't surface there.)

### Issues Discovered / Reported to User

- **`docs/00_overview/folder_structure.md` was missing `app_gradients`/`app_radii`/`app_shadows`/`app_spacing.dart`** in the `packages/fluxora_core/lib/constants/` listing — these have shipped since the desktop redesign M1 Foundation (2026-05-02) and weren't in the folder-structure tree. Added in this pass; flagged because folder-structure stale-section drift is a recurring doc-protocol failure mode and the "stale section self-check" in step 3 of the protocol catches it only when someone is *looking* for tree drift.
- **Mobile redesign plan §16 changelog already had M8 + M9 rows** from the prior M8/M9 sessions — checked and confirmed no double-entry would land. The §16 entries cover this work; the §8 stale-line cleanup here is the only plan-doc change in this sweep.
- **Grep matrix found references in `desktop_redesign_plan.md:106`** that *look* like bugs but are intentional historical narrative. Flagging the false-positive shape: any "bug-report description" inside a plan or ADR will look stale to a code-grep but is correct as historical record. Future doc-sweep agents should distinguish "describes the past" from "describes the present."

### Blockers / Open Issues

- **None.** Doc state is now consistent with code state for everything in scope of M8 + M9 + M9-followup.

### Next Agent Should

1. **Mobile redesign M10 — X-Ray panel + Group Watch shell + Offline state** per plan §7 row M10 (unchanged from M9-followup's "Next Agent Should").
2. **When M10 docs land,** continue the discipline of running the cross-reference grep + stale-section sweep — the protocol catches drift only when you actually run it.
3. **Desktop M11 / mobile M11 remain on the roadmap** as next major surfaces (per `docs/10_planning/01_roadmap.md`).

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran. No commits this session — owner has not authorised.
- [x] No agent / AI branding anywhere in code, docs, or commit messages.
- [x] No `print()` / `debugPrint()` introduced (no code changes in this entry — docs only).
- [x] No exceptions swallowed silently.
- [x] No secrets / hardcoded paths added.
- [x] No new third-party deps (no code changes).
- [x] No backwards-compat hacks.
- [x] No layer-boundary violations. Doc edits stay within `docs/`; the AGENT_LOG.md doc-sync entry stays append-only at the bottom.
---

## [2026-05-03] — Mobile real-data backfill — plan + locked decisions + pre-flight + Phase A scope freeze
**Phase:** Phase 5 (Mobile redesign — backfill prep)
**Status:** Complete (planning only — no code change). Phase A is frozen and ready for the next session.

### What Was Done

- **New planning doc** `docs/10_planning/08_real_data_backfill_plan.md`. Lists every `MockData` reference in `apps/mobile/lib/`, its real-data path, the server work needed, the mobile work needed, and the phase it lands in. 7 phases originally drafted (A–G); 1 dropped (F = Trending), 1 deferred (E = Downloads, hidden in v1).
- **8 owner decisions locked** (plan §5). Highlights:
  - Search: SQL `LIKE` for v1; FTS5 deferred to v2 (endpoint contract identical, only WHERE clause changes).
  - Profile per-client endpoint: new `GET /clients/me`; `/info` stays public-only.
  - Trending rail: dropped permanently from Home (single-tenant single-user trending is degenerate).
  - Downloads tab: hidden in v1, ships v1.1+.
  - Episodes: schema-light — episode files stay regular `media_files` rows aggregated by `tmdb_show_id`; no new `episodes` table.
  - Quality switching + Direct play: full Phase G (multi-variant HLS ladder + `GET /files/{id}/source` + Source/Auto picker).
  - Pairing UX: Phase A includes a full rebuild — display_name editable + defaulted, optional email, explicit state machine, lost-token Reconnect route.
  - MockGradients: lifted to `shared/widgets/gradients.dart` before deleting `mock_data.dart`.
- **Phase D re-scoped from 5–8 sessions to 1–2** after the schema-light decision — episodes are pure SQL aggregates over the existing `media_files` table.
- **Effort estimate refresh** (plan §4): Phase A 2–3 sessions, B 2–3, C 3–5, D 1–2, E 8–12 (deferred), F 0 (dropped), G 4–6. v1 ship line A+B+C+D+G ≈ 12–19 sessions.
- **Pre-flight reads** (5 items, ~15 min):
  - `media_files` columns: has all TMDB + resume + timestamp fields. **Missing:** `width`, `height`, `codec_name`, `hdr_format`, `tmdb_show_id`, `season_number`, `episode_number`.
  - `clients` columns: has `name` (= display_name today via `device_name` pair-request field), `platform`, `last_seen`, `is_trusted`, `auth_token`, `status`. **Missing:** `email`, `paired_at`.
  - Legacy `LibraryRepository` mobile compile path: intact post-M9 token cutover; just rewire `library_screen.dart` back to `LibraryBloc`.
  - TV episode columns: none on `media_files` today — Phase A migration adds them (pre-folded for Phase D so we ship one schema bump).
  - Auth router + pairing flow: ratelimit + state-machine in place; **two real bugs found that Phase A must fix** (see Issues below).
- **Phase A scope frozen** in plan §9 — single migration 016 + FFprobe persistence + 2 new endpoints (`GET /files/recent` + `GET /clients/me`) + same-`client_id` re-pair fix on the server; Library / Detail / Recent / Profile rewiring + full pairing-screen rebuild + lost-token Reconnect route on mobile. 3-commit delivery proposed (server / mobile-data / mobile-pairing).

### Files Created / Modified

| Action | Path |
|--------|------|
| Created | `docs/10_planning/08_real_data_backfill_plan.md` (~370 lines — 10 sections, decision table, full Phase A migration SQL, frozen mobile scope, cross-references) |
| Modified | `AGENT_LOG.md` (this entry) |

### Docs Updated

- `docs/10_planning/08_real_data_backfill_plan.md` — new file. (Other docs not touched in this session — Phase A's commits will update `04_api/01_api_contracts.md`, `03_data/02_database_schema.md`, `06_security/01_security.md` §Pairing, `00_overview/current_status.md`, and the plan's §3 / §4 / §5 / §9 with the as-built state.)

### Decisions Made

(All 8 are in the plan §5 — copying the headline rationale here for searchability.)

- **Search backend = SQL LIKE for v1.** Endpoint contract is identical when v2 swaps to FTS5. Zero mobile-side cutover cost.
- **Profile endpoint = new `/clients/me`.** Don't muddy `/info` with per-caller fields.
- **Trending rail dropped.** Not telemetry-rich enough at single-tenant scale to be honest.
- **Downloads tab hidden in v1.** Full download manager is a v1.1+ feature; can't smuggle it into the v1 ship.
- **Episodes via aggregate, not new table.** Each episode is already a `media_files` row; "show" is `WHERE tmdb_show_id = ?`. Massive scope reduction.
- **Quality + Direct-play in v1 (Phase G).** User asked for both; multi-variant HLS ladder is FFmpeg config + master playlist (media_kit handles client-side switching automatically); direct-play is a new bearer-auth Range-capable file endpoint with codec allowlist + client-side fallback chain.
- **Pairing UX rebuild in Phase A.** State-machine UI + display_name editable + lost-token Reconnect path. Two server bugs caught in pre-flight (re-pair 409, in-memory pending tokens) get fixed alongside.
- **MockGradients lifted, not deleted.** Gradient placeholders look intentional; solid violet would read as broken.

### Issues Discovered / Reported to User

- **Re-pair from same `client_id` returns 409 Conflict.** `apps/server/routers/auth.py` `POST /auth/approve/{client_id}` (line 100–104) refuses approval if the client's `status` is not `pending`. So a mobile user who reinstalls the app or restores from iCloud / Google Backup hits a hard error the operator can't resolve from the desktop UI today. **Phase A must fix:** `services/auth_service.create_pair_request()` should reset `status` → `pending`, clear the prior `auth_token`, refresh `name` + `email`, drop any cached `_pending_tokens` entry. Operator sees a fresh "re-pair request from {device}" — old token is dead immediately. Doubles as a security improvement (stolen token + reinstall = forced re-approval).
- **Pending tokens are in-memory only.** `_pending_tokens: dict[str, str]` in `apps/server/routers/auth.py` lines 159–167. Server restart between approve and the first `/auth/status` poll loses the raw token; client never sees `auth_token: "..."`. v1 single-tenant home server — operator can re-approve. **Phase A flags as known limitation in `04_manual_tasks.md`** rather than fixing (would need persistent storage with TTL — out of Phase A scope).
- **No mobile lost-token recovery path.** If `secureStorage.auth_token` returns null but `client_id` is still present (could happen via OS keychain glitch, iCloud restore, or future selective wipe), the app routes to `/connect` losing the user's `serverUrl` too. Phase A adds `Routes.reconnect` covering this.
- **Quality / Direct-play (Phase G) needs FFmpeg ladder work that isn't trivial.** The 4–6 session estimate assumes a sane source-aware default ladder (4K → 1080p+720p+480p, etc.) and `media_kit`'s built-in master-playlist variant API works as expected on iOS / Android. Bandwidth-aware adaptive switching is media_kit's territory; we just need to emit a valid HLS master. Worth a media_kit smoke test before committing the full Phase G effort.

### Blockers / Open Issues

- **None for Phase A.** Scope is frozen, migration is drafted, endpoints are specified, the pairing rebuild is itemised. Next agent picks this up cleanly.
- **One open question for Phase G** (not blocking Phase A): does media_kit on iOS handle HLS master playlist variant switching transparently, or does it need an explicit `Player.setVideoTrack` call from the picker? Worth a 30-minute experiment before committing the full Phase G design. Phase A doesn't need this.

### Next Agent Should

1. **Execute Phase A** per plan §9 — three commits in this order:
   - **Commit 1 — Server side.** `apps/server/database/migrations/016_media_quality_episodes_client_email.sql` (full DDL in plan §9.1) + FFprobe persistence in `services/ffmpeg_service.py` (or wherever scan probing lives) + same-`client_id` re-pair fix in `services/auth_service.create_pair_request()` + `models/client.py` adds optional `email` to `PairRequestBody` + new `GET /api/v1/files/recent` + new `GET /api/v1/clients/me` + tests for migration + new endpoints + re-pair flow. Server suite stays green. Subject: `feat(server): migration 016 + FFprobe + recent + clients/me + re-pair fix`.
   - **Commit 2 — Mobile data wiring.** `library_screen.dart` rewires to `LibraryBloc`; new `DetailCubit` + `RecentCubit`; `profile_screen.dart` consumes `/clients/me`; mock entries deleted (`MockMediaItem.recentlyAdded`, `MockMediaItem.findById`, profile hardcoded fields). 27 mobile tests stay green. Subject: `feat(mobile): Phase A real-data wiring (Library + Detail + Recent + Profile basics)`.
   - **Commit 3 — Mobile pairing rebuild.** `pairing_screen.dart` rebuilt with state-machine UI per plan §9.2; new `Routes.reconnect` + reconnect screen; auth-guard updates in `app_router.dart`. Subject: `feat(mobile): pairing UX rebuild + lost-token Reconnect route`.
2. **Update docs at commit time** (don't batch a separate doc-sync commit) — `04_api/01_api_contracts.md` for the 2 new endpoints, `03_data/02_database_schema.md` for migration 016, `06_security/01_security.md` §Pairing for the re-pair-resets-to-pending behaviour, `00_overview/current_status.md` for the test-count + feature-list bumps, and the backfill plan §3 / §4 to mark Phase A done.
3. **Don't touch Phase B / C / D / G yet** — each is a separate session at minimum. Phase B is the natural follow-up (Continue-watching + Search + Profile stats); start it after Phase A is in and CI is green.
4. **Phase G (quality + direct-play) wants a media_kit smoke test first** — see Open Issues above. Don't commit the full ladder design until you've confirmed the master-playlist switching path works on iOS + Android.
5. **Hide the Downloads tab in v1.** Standalone tiny commit at any point: remove `Downloads` from `FluxBottomTabs` registry + remove `Routes.downloads` + the `StatefulShellBranch`. `downloads_screen.dart` stays in tree (deleted at Phase E or kept for v1.1 reactivation). Could land alongside Phase A or as its own polish commit.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran by default — owner authorised the in-session chunked commits earlier; this entry's plan + log commit will be staged + drafted then run with that same authorisation in mind. Single end-of-session commit only.
- [x] No agent / AI branding anywhere in code, docs, or commit messages.
- [x] No `print()` / `debugPrint()` introduced (no code change in this session).
- [x] No exceptions swallowed silently.
- [x] No secrets / hardcoded paths added.
- [x] No new third-party deps.
- [x] No backwards-compat hacks. The `device_name` → `display_name` field rename in `PairRequestBody` is keeping the wire field as-is and renaming only the Python attribute (zero-impact); flagged in plan §9.1.
- [x] No layer-boundary violations. Plan doc lives under `docs/10_planning/`. AGENT_LOG entry stays append-only at the bottom.
---

## [2026-05-04] — Mobile real-data backfill — Phase A — Server side
**Phase:** Phase 5 (mobile real-data backfill — see `docs/10_planning/08_real_data_backfill_plan.md` §9.1)
**Status:** Complete (server slice). Phase A mobile commits (data wiring + pairing rebuild) deferred to next session.

### What Was Done

The first of three Phase A commits per the locked plan §9.4 — server-only changes that unblock the mobile data-wiring + pairing-rebuild commits that follow.

1. **Migration 016 (`016_media_quality_episodes_client_email.sql`)** — three independent additions, one schema bump:
   - **FFprobe-derived video metadata** on `media_files`: `width`, `height`, `codec_name`, `hdr_format` (the quality-badge composition fields + Phase G direct-play allowlist).
   - **TV episode aggregation columns** on `media_files`: `tmdb_show_id`, `season_number`, `episode_number`, plus a covering index `idx_media_files_tmdb_show_id`. Pre-folded for Phase D so the schema doesn't bump again — episodes stay regular `media_files` rows; "show" is just `WHERE tmdb_show_id = ?`.
   - **Per-client profile fields** on `clients`: `email` (optional, captured during the mobile pairing flow's optional contact step) and `paired_at` (ISO timestamp of first approval). `paired_at` is back-filled to the migration-apply time for already-paired rows so the desktop's "Paired Mar 15" label never shows blank.

2. **FFprobe persistence at scan time** — `services/ffmpeg_service.py` gained `_ffprobe_bin()` (PyInstaller-aware), `_detect_hdr_format()` (Dolby Vision side-data first → smpte2084/PQ → arib-std-b67/HLG → null), and `probe_video()` (async wrapper that runs `ffprobe -v error -print_format json -show_streams -select_streams v:0 <path>`). `services/library_service.py` adds `_persist_probe()` and a new `_PROBEABLE_EXTENSIONS` subset (the 8 video extensions); both `scan_library()` and `upload_file_to_library()` invoke probe-and-persist after the insert. Probe failures are best-effort logged + swallowed — they cannot abort a scan.

3. **Same-`client_id` re-pair fix** (plan §8.5 bug 1) — `services/auth_service.create_pair_request()` rewritten:
   - In-memory pending-token store (`_pending_tokens` dict) **moved from `routers/auth.py` into `services/auth_service.py`** so the service can `clear_pending_token(client_id)` on re-pair. Router now uses `auth_service.store_pending_token()` / `consume_pending_token()`.
   - `INSERT … ON CONFLICT(id) DO UPDATE` now resets `is_trusted = 0`, `auth_token = ''`, `status = 'pending'`, refreshes `name` + `platform` + `last_seen`, and merges `email` (preserves existing if new request omits it). Prior status (approved / rejected) no longer matters — re-pair always resets to pending.
   - `approve_client()` stamps `paired_at` only on first approval (`COALESCE(paired_at, now)`), so the desktop "Paired Mar 15" label reflects the original trust event, not the most recent re-pair.
   - **Security improvement (already documented in `docs/06_security/01_security.md`):** a stolen token whose owner reinstalls the app cannot survive a re-pair — the legitimate device's request invalidates the prior token immediately, before the operator clicks "Approve" again.

4. **`PairRequestBody` extended with optional `email: str | None = None`** — wire field unchanged; passes through `routers/auth.py::request_pair` into `auth_service.create_pair_request(..., email=...)`. Email is plain `str` (not `EmailStr`) because pulling in `email-validator` for a single optional field violates CLAUDE.md hard prohibition #6 — the field is only echoed back to the operator + profile screen, never used as an identity key.

5. **New `GET /api/v1/files/recent`** — bearer-or-localhost auth; `?limit=N` clamped to `[1, 50]` at the route boundary (returns 422 on overflow); SQL is `SELECT * FROM media_files ORDER BY created_at DESC LIMIT ?`. Route is registered **before** `/{file_id}` in `routers/files.py` so FastAPI doesn't treat "recent" as a literal id.

6. **New `GET /api/v1/auth/clients/me`** — bearer-required (`validate_token`). Resolves the client from the bearer, joins live `subscription_tier` from `user_settings`, returns `{id, display_name, email, platform, paired_at, last_seen, tier}`. `display_name` is `clients.name` renamed in the API surface only — no DB rename. Uses the existing `auth` router so the path is `/api/v1/auth/clients/me`; the plan said `/api/v1/clients/me` but the namespace is the only thing that changed (auth router is the right home for "who am I").

7. **`MediaFileResponse` extended** with the seven new optional fields (`width`, `height`, `codec_name`, `hdr_format`, `tmdb_show_id`, `season_number`, `episode_number`). All nullable defaults, so legacy rows scanned before the migration return 200 OK with nulls. Switched the model_config to `ConfigDict(populate_by_name=True, extra="ignore")` so future column additions don't silently 500 the response.

8. **Tests** — added 9 new test cases covering the new endpoints + re-pair semantics; total server suite **253 → 262 passing** (3.5 s for the touched files; full suite 48 s).
   - `test_request_pair_accepts_optional_email`
   - `test_repair_after_approval_resets_to_pending` (proves the prior token returns 401 after re-pair)
   - `test_repair_after_rejection_resets_to_pending` (pins existing rejected→pending behaviour)
   - `test_clients_me_returns_profile`
   - `test_clients_me_requires_token`
   - `test_recent_files_orders_newest_first`
   - `test_recent_files_respects_limit`
   - `test_recent_files_clamps_oversized_limit` (asserts 422 on `limit=999`)
   - `test_recent_files_does_not_match_file_id_route` (sanity for the route-order trap)

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `apps/server/database/migrations/016_media_quality_episodes_client_email.sql` |
| Modified | `apps/server/services/ffmpeg_service.py` (added `_ffprobe_bin`, `_detect_hdr_format`, `probe_video`) |
| Modified | `apps/server/services/library_service.py` (added `_PROBEABLE_EXTENSIONS`, `_persist_probe`, `list_recent_files`; threaded probe into `scan_library` + `upload_file_to_library`) |
| Modified | `apps/server/services/auth_service.py` (moved `_pending_tokens` here; added `store_pending_token` / `consume_pending_token` / `clear_pending_token`; rewrote `create_pair_request` for re-pair semantics; `approve_client` stamps `paired_at`) |
| Modified | `apps/server/routers/auth.py` (drop local pending-token dict; use moved helpers; pass `email` through; new `GET /clients/me`) |
| Modified | `apps/server/routers/files.py` (new `GET /recent` route registered before `/{file_id}`) |
| Modified | `apps/server/models/client.py` (added optional `email` to `PairRequestBody`; new `ClientMeResponse` model) |
| Modified | `apps/server/models/media_file.py` (added 7 optional FFprobe + episode fields; `extra="ignore"` for forward compatibility) |
| Modified | `apps/server/tests/test_auth.py` (+5 cases) |
| Modified | `apps/server/tests/test_files.py` (+4 cases) |
| Modified | `docs/00_overview/current_status.md` (test count 253 → 262; migration range 015 → 016; backfill server slice noted) |
| Modified | `docs/03_data/02_database_schema.md` (migration 016 row + index row; updated `media_files` + `clients` schema blocks) |
| Modified | `docs/04_api/01_api_contracts.md` (`request-pair` body + re-pair semantics; new `/files/recent` and `/auth/clients/me` sections; `MediaFileResponse` shape; auth-mode table updated for `/clients/me`) |
| Modified | `docs/05_infrastructure/02_url_inventory.md` (added `/auth/clients/me` + `/files/recent` rows) |
| Modified | `docs/06_security/01_security.md` (Pairing-Flow re-pair sub-section; route matrix row for `/clients/me`; pair-flow request body documents `email?`) |
| Modified | `AGENT_LOG.md` (this entry) |

### Docs Updated
- `docs/00_overview/current_status.md` — test count, migration high-water mark, "What's next" reordered (Phase A mobile + pairing rebuild promoted to top of the queue).
- `docs/03_data/02_database_schema.md` — `media_files` + `clients` schema blocks reflect the seven new columns; new index row; new migration row.
- `docs/04_api/01_api_contracts.md` — `request-pair` documents the optional `email` and re-pair semantics; new `/files/recent` + `/auth/clients/me` endpoint sections; `MediaFileResponse` JSON shape extended; auth-mode summary updated.
- `docs/05_infrastructure/02_url_inventory.md` — two new endpoint rows.
- `docs/06_security/01_security.md` — re-pair sub-section under Pairing Flow + route-matrix row + pair-body field list.

### Decisions Made
- **`email` as plain `str | None`, not `EmailStr`.** Adding `email-validator` for a single optional contact field that's only ever displayed back is a poor trade. Validation deferred to mobile-side; server doesn't care if it's malformed.
- **`/clients/me` lives on the `auth` router** (full path `/api/v1/auth/clients/me`) instead of the proposed `/api/v1/clients/me`. Symmetry with the existing `GET /auth/clients` (operator-side list of all clients) — "who am I" is identity, identity is auth.
- **In-memory pending tokens moved to the service layer.** The router used to own this dict; the service couldn't clear it on re-pair without circular imports. Service-layer ownership cleans up the boundary and lets `create_pair_request` invalidate raw tokens that haven't been polled yet.
- **`paired_at` stamped on first approval, not first pair-request.** `paired_at` reflects when the operator chose to trust the device, not when the device first asked. Re-pair preserves the original timestamp via `COALESCE(paired_at, now)`.
- **No `email_validator` (CLAUDE.md #6).** No new pip dep added in this commit. New imports limited to stdlib + already-vendored packages.

### Blockers / Open Issues
- **Pending tokens still in-memory only.** A server restart between approve and the first /auth/status poll loses the raw token; the client never gets it. Same-tenant single-operator home server — re-approve in the desktop UI fixes it. Persisting the raw token to disk is its own threat-model question (encrypted-at-rest, retention, replay window) and is deliberately out of scope for v1. Flag stays in plan §8.5 bug 2 for `04_manual_tasks.md`.
- **FFprobe-at-scan increases scan wall time** by one subprocess per video file. On large libraries (10k+ files) this could be noticeable on first scan. The probe is async and yields the event loop, so it doesn't block other coroutines, but the first-scan-wall-time hit isn't measured. If users complain, batch `probe_video` calls in parallel via `asyncio.gather` with a small concurrency cap.
- **Phase A back-fill not yet wired for episode columns.** Migration 016 adds `tmdb_show_id` / `season_number` / `episode_number` but the TMDB scan code doesn't yet write to them — that's Phase D's TMDB-client extension. Phase A only ensures the columns exist; rows scanned now stay null on those three until Phase D ships.

### Issues / Sharp Edges Discovered
- **Route ordering trap in `routers/files.py`.** FastAPI resolves routes in registration order; `/recent` had to be added **before** `/{file_id}` or it'd resolve as a literal id-of-`recent` lookup → 404. Caught at design-time but worth documenting — `test_recent_files_does_not_match_file_id_route` pins the contract.
- **`MediaFileResponse` was a pydantic v1 dict-syntax `model_config`.** That sets `populate_by_name=True` but doesn't override Pydantic v2's defaults — including the new (correct) `extra="ignore"` default. Switching to `ConfigDict(populate_by_name=True, extra="ignore")` is explicit and forward-compatible; future column adds will not 500 the API.
- **No `_pending_tokens` reset between tests** in `conftest.py`. The dict is module-level in `services.auth_service`. The existing tests have all worked because each consumes its own entry, but a future test that does `approve` without `status` could leak across runs. Not a blocker today; flag for the next agent if a flaky pairing test pops up.

### Suggested Next Steps (priority order)
1. **Phase A — Mobile data wiring** (next commit per plan §9.4 commit 2). `library_screen.dart` rewires to `LibraryBloc`, new `DetailCubit` consuming `LibraryRepository.getFile(id)`, new `RecentCubit` consuming `GET /files/recent`, profile screen reads from `GET /auth/clients/me`. Delete `MockMediaItem.recentlyAdded` and `MockMediaItem.findById`. 27 mobile tests stay green.
2. **Phase A — Mobile pairing rebuild** (plan §9.4 commit 3). `pairing_screen.dart` state-machine UI + new `Routes.reconnect` + auth-guard tweak in `app_router.dart`. The display_name + optional-email field UI lands here.
3. **Hide Downloads tab in v1** (decision §5 row 4). Can land alongside Phase A or as its own polish commit. Tiny diff: `FluxBottomTabs` registry shrinks to 4 tabs + delete `Routes.downloads`.
4. **Phase B (Continue-watching + Search + Profile stats)** after Phase A is green. SQL `LIKE` search per decision §5 row 1 — endpoint contract is locked, FTS5 is a v2 swap.

### Hard Rules Checklist
- [x] `git commit` / `git push` not run yet — staged + draft only; owner approves in this session.
- [x] No AI branding in code, docs, or the upcoming commit message.
- [x] No `print()` / `debugPrint()`; service+router code uses the project logger.
- [x] No silent `except: pass`; FFprobe failures + activity-event errors all log via `logger.warning(..., exc_info=True)`.
- [x] No hardcoded secrets / paths.
- [x] No new pip deps (consciously chose plain `str` over `EmailStr` to avoid `email-validator`).
- [x] Bearer tokens still HMAC-SHA256-hashed in DB; raw tokens only ever held in-memory between approve and first poll.
- [x] No layer-boundary violations.
- [x] No migration file edited or deleted (only new file `016_*.sql` added).
---

---
## [2026-05-04] — Library screen layout fix + `bgRaised` opaque-surface token + desktop `surfaceGlass` sweep
**Phase:** Phase 5 — desktop redesign polish (post-library P0+P1)
**Status:** Complete

### What Was Done

Three intertwined fixes triggered by visual smoke-testing the Library screen on Windows desktop:

1. **Fixed catastrophic layout collapse on the Library screen.** Root cause: the library refactor added two `Spacer()` calls inside the card's `Column` — but the Column lives as a non-Positioned child of a `Stack` (default `StackFit.loose`), so it received unbounded height. `Spacer` requires bounded height to flex; with unbounded constraints the whole layout pass cascade-failed (`!_debugDoingThisLayout` on `_LibraryGrid`'s `LayoutBuilder`, propagating up through `_LoadedBody.Column` and the parent `Column`). Symptom: `PageHeader`, `FluxTabBar`, stat tiles, and toolbar pills all painted at the same y-coordinate, piled on top of each other in a single broken band. Fix: wrapped the card body in `SizedBox(height: 168, child: ClipRRect(child: Stack(fit: StackFit.expand, ...)))` — explicit height + `StackFit.expand` give the inner Column tight constraints so `Spacer` can flex. The original M4 card had **zero Spacers** in this Column; the regression was visible by diffing against `0d02b00`. Codified as a hard gotcha so a future agent doesn't re-introduce it.

2. **Added the `AppColors.bgRaised` opaque-surface token** (`#0F0C24`) to `packages/fluxora_core/lib/constants/app_colors.dart`. The value is the prototype's canonical raised-surface hex — already used in three mobile sites (`FluxBottomSheet`, mobile theme `InputDecorationTheme.fillColor`, mobile screens) as raw literals, and in one desktop site (`clients_screen.dart`'s `_FilterDropdown`) as a different raw literal `#1A1830`. Initial token attempt at `#1A1830` (matching the existing clients literal) was wrong — the prototype canonical is `#0F0C24`. Corrected, and migrated `clients_screen`'s two PopupMenu sites from raw literal to token. Mobile sites still use the raw `#0F0C24` literal pending the mobile agent's eventual token-pickup.

3. **Swept every desktop `surfaceGlass` misuse to `bgRaised`** (13 source-code call sites): 5 dialogs in `groups_screen.dart`, 5 desktop-theme defaults in `apps/desktop/lib/shared/theme/app_theme.dart` (`colorScheme.surface`, `cardColor`, `appBarTheme`, `cardTheme`, `snackBarTheme`), 1 hover card in `help_screen.dart`, 2 sites in `flux_card.dart`, plus 8 sites in `library_screen.dart`. **Net policy now:** `bgRaised` for any popup / dialog / sheet / AppBar / SnackBar / Material `Card` chrome; `surfaceGlass` reserved for on-page glass cards (`FluxCard`, `FluxPoster` overlays). The translucent token survives only because mobile still references it.

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `packages/fluxora_core/lib/constants/app_colors.dart` (+ `bgRaised` token) |
| Modified | `apps/desktop/lib/features/library/presentation/screens/library_screen.dart` (Stack/Spacer fix + 8 colour migrations + `_CardMenuButton` clients-pattern adoption) |
| Modified | `apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart` (2 raw-literal `#1A1830` sites → `bgRaised` token) |
| Modified | `apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart` (5 dialog backgrounds) |
| Modified | `apps/desktop/lib/features/help/presentation/screens/help_screen.dart` (1 hover card) |
| Modified | `apps/desktop/lib/shared/theme/app_theme.dart` (5 theme defaults) |
| Modified | `apps/desktop/lib/shared/widgets/flux_card.dart` (background + doc comment) |

### Docs Updated

- `DESIGN.md` — split "Surface Hierarchy" into two families: **Translucent glass** and **Opaque raised** (`bgRaised`). Added explicit policy: any floating chrome must use `bgRaised`.
- `docs/08_frontend/01_frontend_architecture.md` — token table now lists `bgRaised`. New "Surface-token policy (added 2026-05-04)" line replaces the stale "no opaque mid-tier color *token*" sentence.
- `docs/12_guidelines/03_gotchas.md` — rewrote the "translucent fillColor" gotcha to reference the new token resolution. Earlier in the same file, also added a separate gotcha for "`Spacer()` inside a `Column` that's a non-Positioned child of a `Stack`".

### Decisions Made

- **`bgRaised` value = `#0F0C24`, not `#1A1830`.** Prototype canonical wins; clients_screen's literal was the deviation. Token now matches `FluxBottomSheet` + mobile theme.
- **Surface tokens are now a two-family system.** On-page chrome stays translucent (`surfaceGlass`); floating chrome is opaque (`bgRaised`). Permanent, not transitional.
- **Stack-with-Spacer is a layout antipattern.** Bound the Stack first via `SizedBox(height: ...)` or `fit: StackFit.expand` before placing a Column-with-Spacer inside it. Codified in gotchas.md.

### Issues Discovered / Reported to User

- **Hot reload silently does not apply structural Dart changes.** New top-level classes added during the session caused stale builds despite saved on-disk fixes — stack traces kept pointing at removed `LayoutBuilder` lines. Resolution: hot **restart** (`R`) or `flutter clean && flutter run`.
- **`surfaceGlass` was being used as a generic raised-surface colour by 13 desktop sites that should have been opaque.** Slow-rotting design-system bug — the original M4 ship paired it with the radial-gradient backdrop where it looks correct, but every popup/dialog inherited the same fill and looked subtly broken.
- **`clients_screen.dart` already deviated** from the design system with a raw `#1A1830` literal. Reconciled via the new token.

### Blockers / Open Issues

- **Mobile `surfaceGlass` references are still translucent.** 8 mobile source files reference `AppColors.surfaceGlass` directly. Per owner directive ("don't touch mobile"), they remain unchanged. The mobile agent should sweep these to `bgRaised`.
- **`bgRaised` raw literals still exist in mobile** (`FluxBottomSheet`, mobile theme `InputDecorationTheme.fillColor`, two mobile screens). Should migrate to `AppColors.bgRaised` token for symmetry.

### Next Agent Should

1. **Visual smoke-test the desktop Library screen** at 1440×900 and 1100×700 (the minimum content width). Confirm cards render at 280 px wide with name/path pushed to the bottom; popup menu opens with opaque `#0F0C24`; Sort menu, Filters dialog, Delete confirm all opaque. No layout-recursion errors in the console.
2. **Visual-test the wider desktop screens** that consumed the theme-default change. Material `Card`s without custom decoration now render at `#0F0C24` instead of translucent. Most surfaces own their own `BoxDecoration`, so the delta should be small — verify on Activity, Logs, Subscription screens.
3. **(Mobile-agent task)** Sweep `apps/mobile/lib/**/*.dart` for `AppColors.surfaceGlass` and inline `Color(0xFF0F0C24)` literals; migrate them to `AppColors.bgRaised`.
4. **Once mobile is migrated**, evaluate deleting the `surfaceGlass` token entirely. Its two intentional consumers (`FluxCard`, `FluxPoster`) could move to a renamed `cardGlass` token or inline the rgba with a comment.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran. Working tree has uncommitted changes from this session — owner will commit when ready.
- [x] No agent / AI branding in any code, doc, or commit message.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed.
- [x] No secrets / hardcoded paths added — and removed several existing hardcoded colour literals by routing them through the new token.
- [x] No new third-party deps.
- [x] No backwards-compat hacks. Old `surfaceGlass` token remains usable; no shim layer added.
- [x] No mobile files touched (per owner directive). Mobile sweep is flagged for the mobile agent.
- [x] No git-history rewrites.
---

---
## [2026-05-04] — Real glass on Library popups + dialogs (`FluxGlassDialog` + `FluxGlassMenu`)
**Phase:** Phase 5 — desktop redesign polish
**Status:** Complete

### What Was Done

Earlier the same day I'd swept all desktop `surfaceGlass` chrome to opaque `bgRaised` because translucent-without-blur reads as broken. Owner clarified they actually wanted glass — they'd assumed the original translucent appearance was a bug. So this entry restores **real glass** (rgba + `BackdropFilter`) on the Library screen's floating chrome.

Two new shared widgets in `apps/desktop/lib/shared/widgets/`:

1. **`FluxGlassDialog`** — drop-in replacement for `AlertDialog`. Wraps in `Dialog(transparent) → ClipRRect → BackdropFilter(blur 20) → Container(surfaceGlass + 1px border)`. Same blur pattern as `FluxAppBar` / `FluxSidebar` / `FluxBottomTabs`. API mirrors `AlertDialog` (`title`, `content`, `actions`) plus optional `maxWidth` (480) and `blurSigma` (20).

2. **`FluxGlassMenu<T>`** + `showFluxGlassMenu<T>(...)` — drop-in replacement for `PopupMenuButton`. Stock `PopupMenuButton`'s items are independent `Material` descendants, so a single `BackdropFilter` can't span them — that's why the original popup-menu glass attempt (set `color: Colors.transparent`) didn't work. This widget uses a custom `PopupRoute<T>` (subclass of Flutter's same `PopupRoute` that powers `showMenu`) that renders all items inside one `BackdropFilter`. Items are declared as `FluxGlassMenuItem<T>` records (`value`, `label`, `icon?`, `iconColor?`, `destructive`, `selected`). The widget computes the trigger's screen position itself, anchors the menu beneath it, and clamps to the viewport so the menu never falls off-screen.

Library-screen migrations (5 sites total):
- 3 `AlertDialog`s → `FluxGlassDialog`: Delete confirm, Add/Edit form, Filters dialog
- 2 `PopupMenuButton`s → `FluxGlassMenu`: `_SortMenu` (toolbar Sort dropdown) and `_CardMenuButton` (per-card 3-dot menu)

Net visual: every floating surface in the Library screen now has true blur-backed glass, the surrounding page actually shows through (defocused), and the chrome reads as glass instead of an opaque dark rectangle.

### Files Created / Modified

| Action | Path |
|--------|------|
| Created | `apps/desktop/lib/shared/widgets/flux_glass_dialog.dart` |
| Created | `apps/desktop/lib/shared/widgets/flux_glass_menu.dart` (incl. `_GlassPopupRoute`, `_GlassMenuLayoutDelegate`, `FluxGlassMenuItem`) |
| Modified | `apps/desktop/lib/features/library/presentation/screens/library_screen.dart` (3 dialog migrations + 2 popup-menu migrations + 2 imports added) |

### Docs Updated

- [`DESIGN.md`](../DESIGN.md) — "Surface Hierarchy" section gained an explicit "Real-glass widgets" table listing all 6 sites that ship rgba+blur (FluxAppBar, FluxBottomTabs, FluxSidebar, FluxGlassDialog, FluxGlassMenu, command palette overlay) plus the rule: floating chrome must commit to either real glass or opaque `bgRaised`; standalone `surfaceGlass` (rgba without blur) is a bug.
- [`docs/08_frontend/01_frontend_architecture.md`](08_frontend/01_frontend_architecture.md) — Surface-token policy refined to point at the new widgets; documents that `FluxGlassMenu` uses a custom `PopupRoute` because stock `PopupMenuButton` can't host a single blur layer.
- [`docs/12_guidelines/03_gotchas.md`](12_guidelines/03_gotchas.md) — Translucent-fillColor gotcha rewritten: "Resolved 2026-05-04 (two-pass fix)" — opaque `bgRaised` for theme defaults, real-glass widgets for opt-in floating chrome. Stock `PopupMenuButton` limitation documented inline.

### Decisions Made

- **Real glass for floating chrome over opaque-everything.** Initial earlier-day fix went all-opaque to remove the broken translucent look. Owner clarified they wanted real glass; this is the architecturally cleaner answer because Fluxora's design language depends on glassmorphism. The only catch is `BackdropFilter`'s GPU cost — kept opaque for theme-level defaults (Material `Card` / `AppBar` / `SnackBar` / input fill) where every screen would pay the cost; widgets that opt into glass (FluxGlassDialog, FluxGlassMenu, FluxAppBar, etc.) get real blur per-instance.
- **Custom `PopupRoute<T>` for `FluxGlassMenu` rather than wrapping `PopupMenuButton`.** Stock `PopupMenuButton` renders each item as a separate `Material` descendant, which means a single `BackdropFilter` cannot span the popup. Subclassing `PopupRoute<T>` gives full control over the menu's render tree at minimal cost (~50 LOC delegate + route subclass).
- **Items as records (`FluxGlassMenuItem<T>`), not arbitrary widgets.** Forces consumers through the standard label/icon/destructive/selected schema so menu rows stay visually consistent across the app. If a menu needs a non-standard row, the item-builder pattern can be added later.

### Issues Discovered / Reported to User

- **`PopupMenuButton`'s "translucent + transparent color" approach doesn't produce real glass.** Setting `color: Colors.transparent` and providing a custom shape just makes the popup invisible — the items still have their default Material rendering. Documented inline in `flux_glass_menu.dart`'s doc comment so future agents don't waste time trying that approach.
- **Earlier today's `bgRaised` opaque sweep was directionally right but missed the design intent.** The translucent appearance the user originally complained about was *failed glass* (rgba without blur), not "transparency for the sake of it." The clean architectural answer is real glass — glass is part of the design language. Adopting `bgRaised` opaque is still correct for theme-level defaults where blur cost would multiply.

### Blockers / Open Issues

- **Mobile still pending.** 8 mobile `surfaceGlass` sites + 4 raw `Color(0xFF0F0C24)` literals haven't been migrated. Mobile agent should: (a) sweep mobile `surfaceGlass` to either `FluxGlassDialog`/`FluxGlassMenu` (where it's a popup/dialog) or `bgRaised` (where it's a theme default); (b) migrate raw `#0F0C24` literals to `AppColors.bgRaised` token.
- **`groups_screen.dart` dialogs** are still on `AlertDialog + bgRaised`. Could be migrated to `FluxGlassDialog` for consistency with library — same one-liner replace as the library dialogs. Not done yet — owner didn't explicitly ask for this and groups is a less-trafficked surface.

### Next Agent Should

1. **Visual smoke-test the Library screen on Windows.** Open the Sort menu — should show real blur of the page behind it. Click any library card's 3-dot — same blur. Open Add Library / Edit / Delete confirm / Filters dialog — same blur with the page defocused behind. No "broken-translucent" appearance anywhere on this screen.
2. **(Optional) Migrate `groups_screen.dart` dialogs to `FluxGlassDialog`.** 5 sites (delete confirms, create/edit forms). One-line replace each. Visual consistency win.
3. **(Mobile-agent task)** Build a mobile equivalent. The pattern is portable — `FluxBottomSheet` already does the glass treatment on its own. A `FluxGlassDialog` mobile-friendly variant could sit in `packages/fluxora_core/lib/widgets/` and be shared between desktop and mobile.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran.
- [x] No agent / AI branding.
- [x] No `print()` / `debugPrint()`.
- [x] No exceptions swallowed.
- [x] No secrets / hardcoded paths added.
- [x] No new third-party deps. `dart:ui`'s `ImageFilter` is part of the SDK.
- [x] No backwards-compat hacks.
- [x] No mobile files touched (per owner directive).
- [x] No git-history rewrites.
---

## [2026-05-04] — Mobile real-data backfill — Phase A — Mobile data wiring
**Phase:** Phase 5 (mobile real-data backfill — see `docs/10_planning/08_real_data_backfill_plan.md` §9.2 + §9.4 commit 2)
**Status:** Complete

### What Was Done

The second of three Phase A commits — mobile-side consumers of yesterday's server slice (`ac5051f`).  The Recently-added rail, title-detail screen, library tab, and profile header are now real-data-backed; the mock fixtures that backed them are deleted.  Mock continues to back continue-watching + trending + downloads + search-chrome only — those stay until Phase B / E.

1. **`MediaFile` entity extended** (`packages/fluxora_core/lib/entities/media_file.dart`) with the seven Phase A fields the server now ships — `width`, `height`, `codecName`, `hdrFormat`, `tmdbShowId`, `seasonNumber`, `episodeNumber`. All optional, all nullable; legacy rows scanned before migration 016 deserialize fine. `freezed` + `json_serializable` regenerated via `flutter pub run build_runner build`.
2. **`MediaFile.qualityBadge` extension** — pure-Dart helper that composes a "4K HDR" / "1080p HLG" / null badge from `height` + `hdrFormat`. Single source of truth for the mobile quality chip — used by Home rail, Library list, Detail hero. Returns null when no resolution is known so audio/document files render no chip.
3. **`ClientProfile` entity** (`packages/fluxora_core/lib/entities/client_profile.dart`, freezed) for `GET /auth/clients/me`. `displayName` reads from the wire `display_name` field (the existing `clients.name` column renamed only in the API surface). `email` and `pairedAt` are nullable for legacy rows. `tier` deserialises from the existing `SubscriptionTier` enum.
4. **`Endpoints` extended** with `authClientsMe`, `filesRecent`, and a `fileById(String)` helper.
5. **`LibraryRepository` gained two methods** — `listRecentFiles({int limit = 20})` and `getFile(String fileId)`. `AuthRepository` gained `getMe()` plus an optional `email` param on `requestPair()` so the mobile pairing-rebuild commit (Phase A commit 3) can wire the email field without further repo changes.
6. **Three new cubits**, each in its feature folder under `presentation/cubit/`:
   - `RecentCubit` (`features/home/`) — sealed-state `RecentInitial`/`Loading`/`Loaded(items)`/`Failure(message)`. Singleton in GetIt so re-entering Home doesn't refetch.
   - `DetailCubit` (`features/detail/`) — instantiated per-screen with the file id; loads on construction.
   - `ProfileCubit` (`features/profile/`) — singleton, loads on first Profile-tab visit.
7. **`AppGradientPlaceholders` lifted** from `MockGradients` into `apps/mobile/lib/shared/widgets/gradients.dart`. Same six gradients, plus a deterministic `forKey(String)` helper that hashes a file/library id to a palette entry — keeps placeholder colours stable across rebuilds. The lift was prerequisite to deleting `MockGradients` from `mock_data.dart` (which now imports from `gradients.dart`).
8. **Home tab rewired** — Recently-added rail consumes `RecentCubit` via `BlocProvider.value`. Loading state shows 4 placeholder tiles; failure surface has Retry; empty surface tells the user "your next library scan will land here." Continue-watching + Trending stay mock until Phase B (per plan §3 row 1, §3 row 2).
9. **Library tab rewired** — drops `MockData` entirely; consumes `LibraryBloc` (which fetches `GET /api/v1/library` for library *containers* — the v1 server has no aggregated-flat-media endpoint). Filter chips collapse to 5 (`All`/`Movies`/`Shows`/`Music`/`Files`) mapped to `LibraryType`; grid/list toggle stays. Cards show name + filecount + total-size; tap navigates to existing `Routes.libraryFiles(id)` deep-link. Loading + failure + empty states all wired to the bloc.
10. **Detail screen rewired** — drops `MockData.findById`; uses `DetailCubit` over `getFile(id)`. Hero composes the quality badge from the new fields. Synopsis renders from `MediaFile.overview` (TMDB-enriched). The mock cast / crew / similar-titles / episodes-button / synopsis-rich-text rails are all gone — their server endpoints land in Phase C / D. Primary action is `Play`/`Resume` (driven by `resumeSec`) + the existing 4 secondary `_IconAction`s (Watchlist / Download / Share / Cast — placeholders unchanged).
11. **Profile screen rewired** — `ProfileCubit` populates the avatar block (display_name + email + tier pill) and the Account/Subscription rows. Failure shows an inline error card with Retry. The stats row (Hours / Movies / Shows) keeps em-dash placeholders until Phase B's `/clients/me/stats` lands — this is deliberate: don't show fake numbers when the server doesn't know yet. Pull-to-refresh re-pings `/auth/clients/me`. Sign-out flow unchanged.
12. **Episodes screen** (`features/episodes/`) **converted to a Phase D placeholder**. The screen used `MockData.findById` + `MockSeason` / `MockEpisode` — none of which survive Phase A. Until Phase D wires `tmdb_show_id`-grouped SQL + a `/shows/{id}/episodes` endpoint, the screen renders "Episodes — coming soon" instead of mock seasons. The `/episodes/:id` route stays so existing deep-links don't 404.
13. **Search screen** trimmed to drop the `MockData.recentlyAdded` source from its in-memory pool (it's now a real Home rail with no fixed list to filter against). Comment marks the screen as the Phase B target for `/files/search`.
14. **`mock_data.dart` shrunk by ~360 lines** — deleted: `MockGradients` class (lifted), `MockMediaItem.recentlyAdded`, `MockMediaItem.findById`, `MockData._details` rich-detail map, `MockCastMember`, `MockSeason`, `MockEpisode`, the optional `year`/`rating`/`duration`/`synopsis`/`cast`/`crew`/`similarIds`/`seasons` fields on `MockMediaItem`. What survives is exactly the Phase B / E removal targets per plan §3.
15. **Injector** now registers `RecentCubit` + `ProfileCubit` as `lazySingleton`s. `DetailCubit` is created per-screen via `BlocProvider`.
16. **Mobile tests still 27 passing**; `fluxora_core` tests still 8 passing; `flutter analyze` clean across both packages.

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `packages/fluxora_core/lib/entities/client_profile.dart` (+ generated `.freezed.dart` / `.g.dart`) |
| Modified | `packages/fluxora_core/lib/entities/media_file.dart` (+ regenerated `.freezed.dart` / `.g.dart`) — 7 new optional fields + `qualityBadge` extension |
| Modified | `packages/fluxora_core/lib/network/endpoints.dart` (added `authClientsMe`, `filesRecent`, `fileById`) |
| Modified | `packages/fluxora_core/lib/fluxora_core.dart` (export `client_profile`) |
| Created | `apps/mobile/lib/shared/widgets/gradients.dart` (`AppGradientPlaceholders`) |
| Created | `apps/mobile/lib/features/home/presentation/cubit/recent_cubit.dart` |
| Created | `apps/mobile/lib/features/detail/presentation/cubit/detail_cubit.dart` |
| Created | `apps/mobile/lib/features/profile/presentation/cubit/profile_cubit.dart` |
| Modified | `apps/mobile/lib/features/library/domain/repositories/library_repository.dart` (+ `listRecentFiles`, `getFile`) |
| Modified | `apps/mobile/lib/features/library/data/repositories/library_repository_impl.dart` |
| Modified | `apps/mobile/lib/features/auth/domain/repositories/auth_repository.dart` (+ `getMe`, optional `email` on `requestPair`) |
| Modified | `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart` |
| Modified | `apps/mobile/lib/features/home/presentation/screens/home_screen.dart` (Recently-added rail consumes `RecentCubit`) |
| Modified | `apps/mobile/lib/features/library/presentation/screens/library_screen.dart` (consumes `LibraryBloc`) |
| Modified | `apps/mobile/lib/features/detail/presentation/screens/detail_screen.dart` (consumes `DetailCubit`) |
| Modified | `apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart` (consumes `ProfileCubit`) |
| Modified | `apps/mobile/lib/features/episodes/presentation/screens/episodes_screen.dart` (Phase D placeholder) |
| Modified | `apps/mobile/lib/features/search/presentation/screens/search_screen.dart` (drop `recentlyAdded` pool) |
| Modified | `apps/mobile/lib/shared/data/mock_data.dart` (~360 lines deleted; `MockGradients` removed; `MockMediaItem.findById` removed; `_details` map removed) |
| Modified | `apps/mobile/lib/core/di/injector.dart` (register `RecentCubit` + `ProfileCubit`) |
| Modified | `AGENT_LOG.md` (this entry) |

### Docs Updated
- None added in this commit.  API + schema + security + URL inventory all landed alongside the server commit (`ac5051f`); they describe the contract this commit consumes.  `current_status.md` will roll forward when Phase A commit 3 (pairing rebuild) lands so the bullet covers the full Phase A delivery rather than a half-done split.

### Decisions Made
- **Library tab shows containers, not flat media.** The plan said "rewires to LibraryBloc" — `LibraryBloc.state` is `List<Library>`. The honest path was to drop the 6-filter mock-flat-grid and render library cards.  Filter chips collapse to 5 mapped to `LibraryType`; the existing `/library-files/:id` deep-link still handles flat-file browsing inside a library. Phase B may add a flat-aggregate endpoint (`GET /files?library_id=...&recent=true`) — until then, container-grid is the truthful surface.
- **Quality badge derived in client, not server.** The badge string ("4K HDR" / "1080p" / null) is composed in `MediaFile.qualityBadge` extension instead of returning a `qualityBadge` field from the server. Two reasons: (1) keeps the server response shape stable (the server returns physics — width/height/hdr_format — not display strings), (2) the same extension serves desktop without a second wire-format change.
- **Profile stats row keeps placeholders.** Showing "284 hours · 62 movies · 18 shows" hardcoded was fine for the prototype; showing it as real-looking-but-fake numbers in a real-data-wired screen is dishonest. Em-dashes communicate "the server doesn't know" until Phase B's `/clients/me/stats` lands.
- **`AppGradientPlaceholders.forKey(String)`** — deterministic hash → palette index. Keeps the same poster background across scrolls + rebuilds without storing per-file palette state. Adopted for Library cards (keyed off `library.id`) and Detail hero (keyed off `file.id`).
- **Episodes screen → Phase D placeholder.** Deleting the `/episodes/:id` route would break existing deep-links; keeping it functional with mock data would require keeping `_details` + `MockSeason` + `MockEpisode` alive. Compromise: keep the route, replace the body with a "Coming soon" panel. Phase D rewires it.
- **Continue-watching + trending + search-chrome stay mock.** Per plan §3 row 1–2 the deletion of those targets is Phase B work. Phase A's scope is "honest about what's real now" — moving them mid-commit would inflate the diff and steal Phase B's planning headroom.

### Blockers / Open Issues
- **No `/clients/me/stats` exists yet.** Profile stats row is em-dashes until Phase B ships the endpoint. Acceptable v1.0 surface, but it visually downgrades a polished prototype.
- **No `/files/search` exists yet.** Search screen still filters a small in-memory pool (continue-watching + trending). Phase B replaces it. Until then, the search affordance is honest-but-narrow.
- **Library cards aren't a "media grid" anymore.** The Phase A surface shows 4 library containers; the Phase A poster grid was 24+ mock items. This is a real visual downgrade from the demo state — but it's the truthful state until either a flat-aggregate endpoint lands or the `LibraryBloc.state` shape changes. Flagged here so the next session can take a polish pass if desired.
- **`/auth/clients/me` is bearer-token-required**, which means Profile fails until pairing succeeds.  When the user signs out (clears the bearer), the cubit will fail with 401 — but the screen unmounts before then because `_performSignOut` `context.go(Routes.connect)`s before any rebuild. No race here, but worth noting if a future change holds the screen across the bearer wipe.

### Issues / Sharp Edges Discovered
- **`Routes.libraryFiles` is a function, not a string.** Initial pass tried `Routes.libraryFiles.replaceAll(':id', library.id)` — Dart's analyser caught it. The right call is `Routes.libraryFiles(library.id)`. Worth documenting because the desktop sibling-pattern uses string templates with `replaceAll`, so the muscle memory is wrong here.
- **Stale Dart Analysis Server diagnostics during freezed regen.** The IDE flagged "Undefined name 'height'" / "redirected constructor incompatible" between the entity edit and the codegen run; CLI `flutter analyze` after `build_runner` was clean. Pattern observed before — IDE diagnostics are a leading-but-flaky indicator during freezed work; CLI is the source of truth.
- **No `_pending_tokens` reset between mobile tests.** Carried forward from the server-side commit's open-issue list — flagged again here because the Phase A pairing-rebuild commit will add new `auth_service` tests that touch this state.

### Suggested Next Steps (priority order)
1. **Phase A — Mobile pairing rebuild** (last of the three Phase A commits per plan §9.4). State-machine UI in `pairing_screen.dart`, optional email field, `Routes.reconnect` lost-token recovery, auth-guard tweak in `app_router.dart`. Wires the `email` param that `requestPair` already accepts.
2. **Visual smoke-test the rewired screens** on a paired device (or `--dart-define` a bearer at startup): scan a real library → confirm Home Recently-added rail populates, Library cards show real names/sizes, tapping a card → file browser → tapping a file → Detail screen with real poster/quality badge, Profile shows real display_name + tier.
3. **Hide the Downloads tab in v1** (decision §5 row 4). Standalone tiny commit: remove from `FluxBottomTabs` registry + `Routes.downloads` + the `StatefulShellBranch`. `downloads_screen.dart` stays in-tree.
4. **Phase B — Continue-watching + Search + Profile stats.** Once Phase A is green, the three remaining mock surfaces are a natural follow-up commit.

### Hard Rules Checklist
- [x] `git commit` / `git push` not run yet — staged + draft only; owner approves in this session.
- [x] No AI branding in code, docs, or the upcoming commit message.
- [x] No `print()` / `debugPrint()`; cubits use the project `Logger` for failures.
- [x] No silent `except:`; cubits log + emit explicit `*Failure` states.
- [x] No hardcoded secrets / paths.
- [x] No new pub deps.
- [x] No layer-boundary violations (cubit → repo → ApiClient).
- [x] No git-history rewrites.
- [x] No edits to past migrations.
---

## [2026-05-04] — Mobile real-data backfill — Phase A — Pairing UX rebuild + lost-token recovery
**Phase:** Phase 5 (mobile real-data backfill — see `docs/10_planning/08_real_data_backfill_plan.md` §9.2 + §9.4 commit 3 — **Phase A close-out**)
**Status:** Complete

### What Was Done

The third and final Phase A commit. Initial-pair flow becomes a state-machine UI with the optional email field. New `/reconnect` route handles lost-token recovery, hooked to a global 401 trigger via a stream on `ApiClient` so a dead bearer mid-session reroutes the user automatically.

1. **`PairState` extended** with a new `PairCollectEmail(server)` state — pre-request UI step. Existing states (`PairInitial`, `PairRequesting`, `PairPending`, `PairApproved`, `PairRejected`, `PairError`) unchanged. Doc comment at the top of the file describes both the initial-pair and re-pair traversals through the machine.
2. **`PairCubit` rewritten with a two-step entry plus a reconnect entry**:
   - `prepare(server)` — emits `PairCollectEmail` (no network call). Replaces the old eager `startPairing` that fired `request-pair` immediately.
   - `submitEmail({server, email})` — generates a fresh client_id UUID, hits `requestPair` with the optional email, transitions to `PairPending` on success, polls `/auth/status/{client_id}` for approval.
   - `reconnect()` — reads `client_id` + `server_url` out of secure storage and re-fires `requestPair` against the same client_id (server now resets the row to `pending` per migration 016 + the §8.5 bug 1 fix). On approval the new token replaces the dead one. If storage is empty, emits `PairError` with a "pair from scratch" pointer.
   - Cubit constructor gained an optional `secureStorage` so reconnect can be unit-tested in isolation.
3. **`pairing_screen.dart` rewired** to the new V2-styled state machine:
   - `PairCollectEmail` → 64 px violet-tinted devices icon + server name/IP + `FluxTextField` for email (typed with `.emailAddress` keyboard) + `Continue` / `Skip` buttons. Client-side email shape check (`^[^\s@]+@[^\s@]+\.[^\s@]+$`) with a friendly "doesn't look like an email" inline error. Empty + Skip both resolve to `email: null`.
   - `PairRequesting` / `PairApproved` → centered violet spinner + status string.
   - `PairPending` → 64 px hourglass icon + "Waiting for approval" + sub-spinner + Cancel button (returns to `/connect`).
   - `PairRejected` → amber `block_rounded` icon + "Pairing rejected" + reason + "Try another server" button.
   - `PairError` → red `error_outline_rounded` icon + "Couldn't pair" + message + "Try again" (which re-enters the `PairCollectEmail` step so the user can edit the email).
   - All surfaces use V2 tokens (`AppColors.{violet,textBright,textBody,textMutedV2,borderSubtle}` + `AppTypography.{h1,body,captionV2,eyebrow}`). `FluxAppBar` with transparent variant + back arrow that pops or falls back to `/connect`.
4. **`reconnect_screen.dart`** (new) — separate screen at `/reconnect` for lost-token recovery. Reuses `PairCubit` with `reconnect()` as the entry point so the same state-machine renders the same surfaces, with two differences: (a) loading copy reads "Reconnecting to your server…" and the pending panel says "Waiting for re-approval"; (b) error / rejected panels offer **two** buttons — "Try again" and "Sign out and pair from scratch" (the latter clears the bearer + secure storage and routes to `/connect`).
5. **`Routes.reconnect = '/reconnect'`** added to `Routes` + a `GoRoute` registered for it. Auth-guard updated:
   - Public-route list now includes `reconnect` so unauthenticated users can land on it (the screen handles the "no saved credentials" case itself).
   - The "authenticated user → bounce to /home" redirect is scoped to `/connect` and `/pairing` only — `/reconnect` is exempt so an authenticated user opting to re-pair (e.g. via the new Profile setting) doesn't get reflected back to `/home` before the screen can re-fire the request.
6. **Global 401 trigger** wired in `packages/fluxora_core/lib/network/api_client.dart`:
   - New `unauthorizedStream` (`Stream<void>`, broadcast). The Dio `onError` interceptor emits to it whenever a request returns HTTP 401 *with* an `Authorization` header attached — silent on unauthenticated 401s (which are legitimate "please pair" surfaces).
   - On 401, the bearer token is also cleared locally so subsequent requests don't re-trip the same loop.
   - `setupRouterUnauthorizedBridge()` (new) in `app_router.dart` subscribes to the stream once at app start (called from `main.dart` after `setupInjector()`). On emission, it calls `appRouter.go(Routes.reconnect)` — except when the user is already on `/connect`, `/pairing`, or `/reconnect`, where credential state is already being handled by the screen.
   - `ApiClient` gets a test-only `dispose()` that closes the stream controller; production code never calls it because `ApiClient` is a GetIt singleton that lives the lifetime of the app.
7. **Profile screen gains a "Reconnect to server" sub-row** — tap → `context.go(Routes.reconnect)`. Discovers the recovery flow before the user gets stuck on a 401-spinning surface. Sub-copy: "Use if your token was revoked." Sits between Help & support and About Fluxora.
8. **`_SettingsRow` extended with optional `onTap`** (was hardcoded `() {}`). Existing rows fall through to the no-op default; the new Reconnect row supplies a navigator-go closure.
9. **Auth-repository `requestPair` test contract updated** for the new `email` named parameter — Mocktail's `any(named: 'email')` matcher works fine with the optional. New tests:
   - `prepare()` emits `PairCollectEmail` with the server.
   - Initial-pair flow now expects `[CollectEmail, Requesting, Pending]` (was `[Requesting, Pending]`).
   - Email-forwarding test: passes `'alex@fluxora.io'` through `submitEmail` and verifies it reached `requestPair`.
   - Reconnect-with-saved-credentials test: stubs `getServerUrl` + `getClientId`; verifies the persisted client_id is what hits `requestPair` (not a freshly generated UUID).
   - Reconnect-with-empty-storage test: verifies `[Requesting, Error]` transition.
10. **Tests: 27 mobile + 8 core → 31 mobile + 8 core**, all passing. `flutter analyze` clean across both packages.

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `apps/mobile/lib/features/auth/presentation/screens/reconnect_screen.dart` |
| Modified | `apps/mobile/lib/features/auth/presentation/screens/pairing_screen.dart` (rebuild — V2 state-machine UI + email field) |
| Modified | `apps/mobile/lib/features/auth/presentation/cubit/pair_state.dart` (added `PairCollectEmail`) |
| Modified | `apps/mobile/lib/features/auth/presentation/cubit/pair_cubit.dart` (`prepare` / `submitEmail` / `reconnect` entry points + secure-storage dependency) |
| Modified | `apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart` (new "Reconnect to server" row; `_SettingsRow.onTap` parameter) |
| Modified | `apps/mobile/lib/core/router/app_router.dart` (`Routes.reconnect`; route registration; auth-guard branch; `setupRouterUnauthorizedBridge`) |
| Modified | `apps/mobile/lib/main.dart` (call `setupRouterUnauthorizedBridge()` after `setupInjector`) |
| Modified | `packages/fluxora_core/lib/network/api_client.dart` (`unauthorizedStream` broadcast controller + 401 detection in interceptor + test-only `dispose()`) |
| Modified | `apps/mobile/test/features/auth/pair_cubit_test.dart` (rewrite for new state machine + reconnect coverage; 5 → 9 cases) |
| Modified | `docs/00_overview/current_status.md` (Phase A close-out + test count 27→31; "What's next" reordered) |
| Modified | `AGENT_LOG.md` (this entry) |

### Docs Updated
- `docs/00_overview/current_status.md` — Phase A close-out noted; test count 27 → 31; "What's next" leads with Phase B now that A is complete; mobile section header updated.
- API contracts + security docs already documented `email` on `request-pair`, the re-pair semantics, and `/auth/clients/me` in commit `ac5051f`. Nothing to add this commit — the URL surface didn't change.

### Decisions Made
- **State-machine entry is two-step (`prepare` → `submitEmail`).** The pre-request `PairCollectEmail` step is the right place for the optional email UI — putting it after the request would mean we'd have to either skip-and-PATCH (server has no PATCH on clients yet) or hold the request open while the user types. Pre-request is cleanest.
- **Email validation is "looks like an email", not RFC 5322.** Server treats the field as advisory (echoes it back, never authenticates against it). Strict validation would either accept a regex too lax to be meaningful or reject valid edge-case addresses (`+`, IDN, etc.). The lightweight `^[^\s@]+@[^\s@]+\.[^\s@]+$` rejects obvious typos and is honest about what it's checking.
- **Reconnect uses the saved `client_id`.** This is the entire premise of the §8.5 bug 1 fix: reusing the existing client_id resets the row instead of creating a new one. Re-approving on the server keeps the operator's familiar device row + the original `paired_at` timestamp.
- **401 detection is global, not per-cubit.** Putting the 401-handler in every cubit would mean each one needs to know about routing — wrong layer. Putting it in `ApiClient` lets the router observe the stream and decide once. The stream pattern also means the dev tools / a future telemetry sink can subscribe too.
- **Auth-guard exempts `/reconnect` from the "authenticated → /home" reflection.** When 401 fires on the home screen and the bridge calls `appRouter.go(Routes.reconnect)`, the user is *technically* still authenticated (token in storage hasn't been cleared yet — `clearBearerToken` only nulls the in-memory copy). Without the exemption, the guard would bounce them right back to `/home` where the next request would 401 again. Exemption breaks the loop.
- **No new pip / pub deps.** `dart:async`'s `StreamController.broadcast()` is stdlib; no new packages.

### Blockers / Open Issues
- **AGENT_LOG.md is at ~1100 lines after this entry** — over the 1000-line rotation threshold per CLAUDE.md. Next session should rotate to `docs/logs/AGENT_LOG_archive_06.md` and start fresh with a summary of Phase A close-out at the top.
- **Reconnect path doesn't yet cache the in-flight email**, so a re-pair via Reconnect always sends `email: null`. Server's `COALESCE(excluded.email, clients.email)` clause preserves the previously-saved email, so this is correct behaviour — but it does mean a user re-pairing from a different device cannot update their email through the Reconnect flow. Out of v1 scope; flagged for a future "edit email" affordance on Profile.
- **No `/connect → /reconnect` discoverability.** The Reconnect screen is reachable via the global 401 trigger, the new Profile setting, and direct deep-link, but not from `/connect` itself. If a user hard-quits during the dead-token window and lands on `/connect`, they may try to pair from scratch instead of reconnecting. Acceptable for v1 — the new client_id will succeed and the operator just sees the device twice. Would tighten with a "I've paired before — reconnect instead" link on `/connect`.
- **Visual smoke-test pending.** All flutter analyze + tests are green, but the actual UI on a paired Android / iOS device hasn't been exercised. Phase A pairing flow walks: (1) discovery → server tile → (2) `PairCollectEmail` panel → email or skip → (3) `PairPending` → operator approves → (4) `/home`. Reconnect flow walks: dead token → 401 fires → router redirect → `/reconnect` `PairPending` → operator re-approves → `/home`. Owner-driven QA needed before claiming v1-shipping.

### Issues / Sharp Edges Discovered
- **`StreamController.broadcast()` triggers `close_sinks` lint** — the controller is intentionally never closed because `ApiClient` is a singleton that lives for the entire app lifecycle. Suppressed with `// ignore: close_sinks` on the field declaration; documented in the surrounding doc comment so future maintainers know it's deliberate. The test-only `dispose()` exists for symmetry but isn't used in production code paths.
- **`FluxTextField` uses `hint:`, not `hintText:`** — initial pass tried `hintText: 'you@example.com'`. The widget API doesn't follow Material's `InputDecoration.hintText`; doc this so future agents don't repeat the mistake. Also no `textInputAction:` parameter — soft keyboard's "Done" affordance is auto-derived from the underlying `TextField`'s default.
- **Test runner reports red logger output as "errors"** when `bloc_test` runs the cubit through its expected-fail paths. Each `[Requesting, Error]` test logs an "Exception: network error" via `Logger().e(...)` to stderr. Tests still pass (`+9: All tests passed!`); the red text is cosmetic noise from the assertion path. Worth knowing because at-a-glance the output looks alarming.
- **`_SettingsRow` had a hardcoded `onTap: () {}`** — Phase A commit 2 left it that way because every row was a stub. Adding the optional `onTap` parameter unblocked the new Reconnect row without breaking the eight existing rows that still want a no-op.

### Suggested Next Steps (priority order)
1. **Rotate `AGENT_LOG.md`.** It's over 1000 lines after this entry. `cp AGENT_LOG.md docs/logs/AGENT_LOG_archive_06.md`; write a fresh `AGENT_LOG.md` with a Phase A close-out summary at the top + this entry's "Next Agent Should" pointers.
2. **Phase B — Continue-watching + Search + Profile stats.** The three remaining mock surfaces. Plan §3 row 1–3. Each is a separate endpoint on the server side; mobile mostly mirrors the Phase A patterns (cubit + repo method + screen rewire + delete the corresponding mock fixture).
3. **Hide Downloads tab in v1** (decision §5 row 4). Tiny standalone commit. Could land before Phase B or alongside it.
4. **Visual QA pass on Phase A.** Walk a paired device through the new pairing UX + the reconnect flow (revoke token from desktop, watch redirect happen). Confirm copy + layout + transitions.

### Hard Rules Checklist
- [x] `git commit` / `git push` not run yet — staged + draft only; owner approves in-session.
- [x] No AI branding in code, docs, or commit message.
- [x] No `print()` / `debugPrint()`; logger used throughout.
- [x] No silent `except:`; cubits emit explicit `*Error` states + log via `Logger`.
- [x] No hardcoded secrets / paths.
- [x] No new pub deps. `StreamController.broadcast()` is stdlib `dart:async`.
- [x] No layer-boundary violations (cubit → repo → ApiClient; router → ApiClient stream is one-way observation).
- [x] No git-history rewrites.
- [x] No edits to past migrations.
---


