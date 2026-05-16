# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the canonical format spec at [`docs/12_guidelines/04_agent_log_format.md`](docs/12_guidelines/04_agent_log_format.md).
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_NN.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 13)
**Archived:** 2026-05-16
**Contents:** Plan 24 M9-partial follow-ons (HDR codec tonemap, FitMode three-way cycle, pinch zoom via raw Listener, chrome relayout, overflow-menu scroll fix, LAN cleartext config) + plan 26 desktop CP IA redesign (Library + Activity tabbed shells, plan doc + M1-M5 shell construction + deep-link polish).

* **Plan 24 — Real-device follow-ons (2026-05-15).** `network_security_config.xml` for LAN cleartext (global allow + `fluxora-api.marshalx.dev` HTTPS-only carve-out).  Client-side HDR→SDR tonemap via custom `TonemappingRenderersFactory` (Media3 `DefaultRenderersFactory` subclass; `KEY_COLOR_TRANSFER_REQUEST = COLOR_TRANSFER_SDR_VIDEO` on API 33+).  `PlayerEngine.videoSize` + `videoSizeStream` (emitted from `onTracksChanged` + `onVideoSizeChanged`; PAR baked in for anamorphic sources).  Three-way `FitMode {fit, fill, stretch}` cycling button (default `fit`).  Pinch zoom via raw `Listener` (gesture arena loses 2-finger scale at slop crossover; `_activePointers >= 2` gating).  Drag-HUD `zoom` + `fitMode` cases.  Player UI relayout (transport below scrubber, `_MinimizeHandle` removed, gradient chrome backdrops).  Overflow-menu scroll fix (`SingleChildScrollView` + `isScrollControlled: true`).  Mobile 97 → 97 (no new tests; existing fakes stubbed).

* **Plan 26 — Desktop CP IA redesign (2026-05-15 → 2026-05-16).** Owner review collapsed the 10-item rail to 7 by folding two overlap pairs into tabbed shells.  M1-M5 shipped 2026-05-15: `LibraryShell` (`/library/{folders,convert,scan-history}`) + `ActivityShell` (`/activity/{sessions,transcoding,logs}`); inner screens grew `embedded` flag to skip duplicate page headers; legacy `/transcode` / `/transcoding` / `/logs` redirect to new tab paths; Dashboard "Recent Activity" rows deep-link to `/activity/sessions?event=<id>`.  Highlight-the-event polish landed same day (timestamp-based double-tap detection, `ActivityEventRow` flash animation 1.5s easeOutCubic, 4-case widget test).  Desktop 114 → 118.

**Test counts at archive time (2026-05-16):**
- Server: **814 passing** (no new migrations since archive 12)
- Mobile: **97 passing** (player cubit + 5 player widgets + 10 goldens)
- Desktop: **118 passing** (+5 transcoding feature tests, +4 activity_event_row golden, +1 placeholder)
- Core: **20 passing**

`flutter analyze` clean × all 3 packages.

**Open items (not blocking v1, not in code):**
- Plan 24 M5 (multi-audio device smoke) + M6 (HDR + tonemap) — operator real-device verification still pending; archive once green
- iOS PIP — needs iOS test device
- End-of-episode resolver — next-episode lookup + auto-advance hook; estimate ~half a day
- Streaming pipeline regressions — HDR→SDR toggle timeout, seek-ahead 404s, zombie FFmpeg accumulation; see `docs/10_planning/11_streaming_pipeline_issues.md`

---

## [2026-05-16] [desktop] [feat] [refactor] [ws] — Library / Activity shell polish · IndexedStack tab host · singleton cubits · WS push refresh

**Phase:** Plan 26 follow-on iterations — design polish across Library page + page-architecture rewrite for snappy tab switching + real-time auto-refresh via WebSocket push
**Status:** Complete
**Commits:** uncommitted

### What Was Done

Long iterative session against the Library + Convert + Transcoding surfaces.  Owner drove every change live; each item was reviewed before the next was started.  Five conceptual chunks:

#### 1. Convert tab redesign — flat sortable table + right-side action panel

Replaced the folder-grouped `FolderTreeView` candidates list with a flat 7-column table: checkbox · name (sortable) · size (sortable, right-aligned) · codec chip · output size (sortable, right-aligned) · per-row Convert button.  Tristate "select all" header checkbox.  Pagination footer below the table — count on left, page-number nav (ellipsis-collapsed for >7 pages) centered, rows-per-page popup right (10/25/50/100; default 10).  Sort or page-size change resets to page 1.

Right side of the Convert tab gained a fixed 300 px `_TranscodeRightPanel` containing five vertically-stacked sections matched to the per-library detail panel's visual language:
- **Selection Details** — count + size arrow + signed delta line (amber for AV1/VP9 → H.264 expansion, emerald for the unlikely shrink case)
- **Details** — Source size / Output size (est.) / Runtime (est.) rows
- **Storage** — Transcoded / Cache (bordered clickable `_PathCard` with folder icon + open-in-file-manager) / Free on disk / Sources by codec chips
- **Actions** — `_ActionCard` stack: Start Transcode · Add to Queue · Transcoding Settings · Clear Selection (destructive variant, red border + icon + title)
- **Quick Actions section title** dropped in favour of bold body-weight `Actions` matching the Folders detail panel

Server cubit gained `startSingleTranscode(fileId)` to back the per-row Convert button (queues exactly one file with current preset, no dialog).  `_BulkConvertSection` retired; bulk-convert summary now lives in the right panel.  `StorageStrip` retired in-tab (helpers `openPathInFileManager` / `copyPathToClipboard` still exported for other transcode tabs).  Status column removed from candidates table (every row was "Ready" — dead column).

#### 2. Library page UX iterations

- **Pre-selection bug** — auto-select used `state.libraries.first.id` (server-creation order) instead of the alphabetically-first card shown in the grid.  Fix: sort by name and pick `sorted.first.id` in both the auto-select listener and the "selected library disappeared" fallback.
- **Card text legibility** — replaced the 2-stop top→bottom dark gradient with a 3-stop sandwich (67% top, 13% middle, 87% bottom) so badges + name + path all sit on dark scrim.  Empty cards (no TMDB posters) gained a 72 px faded centred type-icon as a visual anchor.
- **Multi-root path display** — "+N more" suffix when `rootPaths.length > 1`.
- **Selection visual toned down** — dropped the 1 px spread-shadow ring; soft drop shadow at 18 % alpha / 12 px blur / 4 px offset.
- **Top-left badge shrunk** — 32×32 → 22×22 since the new 72 px centre icon already conveys the type.
- **Stat tiles compacted** — replaced full `StatTile` cards with a local `_SmallStatTile` (60 % size: 32 px badge, 16 px icon, `h2` value, `captionV2` label).  Row layout iterated through several spacing modes before settling on `Row(children: [stat, SizedBox(s32), stat, …])` (tight pack at left, controlled inter-stat gaps).
- **Type filter chips** — inner FluxTabBar (All / Movies / TV / Music / Documents) replaced with new `_TypeFilterChips` widget: smaller fully-rounded pills, 12 px text, distinct from the outer FluxPillTabs.  No more "tabs under tabs" visual confusion.
- **+ Add library tile retired** — the bottom inline placeholder in the grid duplicated the top-right `+ Add Library` button.
- **Auto-populate library name** — Add Library dialog auto-fills the Name field from the picked folder's basename when empty (operator can override for a custom name).
- **Last Scan format compacted** — `"10h ago"` → `"10h"` so the stat tile doesn't truncate to `"10h a…"`.
- **Selection click feels instant** — `GestureDetector(onTap:, onDoubleTap:)` was waiting ~300 ms for the double-tap arena to resolve.  Iterated through `onTapDown` (press), custom `_InstantTapGestureRecognizer` (arena-bypass via rejectGesture→acceptGesture), and finally settled on plain `onTap` with timestamp-based manual double-tap detection (`_lastTapAt` field, 300 ms window).  Plus `AnimatedContainer` duration 150 ms → 80 ms for snappier border/shadow change.

#### 3. Library shell + Activity shell — IndexedStack tab host

Owner reported "page pops in and out" on tab switches.  Cause: each pill was its own `go_router` route, so switching tabs fully unmounted the shell + every cubit + every body, then mounted a new one.  Solution: in-place tab switching via `IndexedStack` + `setState`.

`LibraryShell` converted from `StatelessWidget(activeTab: …)` to `StatefulWidget(initialTab: …)` with internal `_activeTab` state.  Pill `onChange` now calls `setState(() => _activeTab = next)` instead of `context.go(routePath)`.  Body uses `IndexedStack(index: _activeTab.index, children: [folders, convert, transcoding])`.  All three tab bodies stay mounted; only the active one is painted.

Lazy-mount layer: `Set<LibraryShellTabPath> _visited` tracks first-visit per tab.  Unvisited tabs render `SizedBox.shrink()` (no widget tree, no cubits constructed).  First-time click on Convert mounts `TranscodeScreen` + creates `TranscodeCubit`; further clicks just flip the IndexedStack index.

Same treatment for `ActivityShell` (Sessions + Logs after the Transcoding-tab move below).  Router cleanup: drop per-tab routes (`/library/folders`, `/library/convert`, `/library/transcoding`, `/activity/sessions`, `/activity/logs`); keep only `/library` and `/activity` as live routes; deprecated per-tab URLs and `/transcode` / `/transcoding` / `/logs` redirect back to their shell root.

**IA shift on Transcoding** — owner asked to move live HLS transcoding sessions (encoder load + active sessions + fallback panel) out of Activity and into Library.  `Library` shell tabs became `Libraries / Convert / Transcoding`; `Activity` shrunk to `Sessions / Logs`.  `Scan history` placeholder retired (was always a wireframe).  Folders tab label renamed to `Libraries` to match what it actually shows.

**Page-header tightening** — `PageHeader` gained a `verticalPadding` parameter (default `s24`).  Library + Activity shells pass `s12` so tabbed pages don't waste ~32 px of vertical space above the card.

**Pill button + card body** — new `FluxPillTabs` shared widget.  Body wrapped in `FluxCard(padding: 0)` for the right-detail-panel visual treatment.  Right detail panel `crossAxisAlignment: stretch` on the Row so the dark panel bg fills the full row height (the gap below "Remove Library" disappears).

#### 4. Singleton cubits + stale-while-revalidate

Navigating away from Library and back was re-fetching everything from scratch because `BlocProvider(create:)` was disposing the cubit on unmount.  Fixed by registering `LibraryCubit` + `StorageCubit` as GetIt lazy singletons; shell uses `BlocProvider.value(GetIt.I<…>())`.  First Library page visit constructs the cubit (and fires `load()`); subsequent visits reuse the instance with its cached state — zero re-fetch, zero spinner.

`LibraryCubit._refresh` promoted to public `refresh()` — silent re-fetch that emits `LibraryLoaded` directly without flipping through `LibraryLoading`.  `StorageCubit` gained the same.  `didChangeDependencies` on `_LibraryViewState` runs both refreshes when state is already Loaded (stale-while-revalidate: cached UI shows instantly, fresh data fills in seamlessly if anything changed).  Also runs auto-select against the cached state — handles the case where the singleton cubit is already Loaded but the `BlocConsumer.listener` doesn't fire for pre-existing emissions.

**Skeleton-loading body** — `_LoadingBody` (centred spinner) replaced with `_SkeletonBody` that renders the same outer structure as `_LoadedBody`: 4 `_SmallStatTile`s with `'—'` placeholder values, the real `_ToolbarRow` (with `resultCount: 0`), and 4 ghost cards (`_SkeletonLibraryCard` — 168 px bordered `bgRaised` rectangles).  Operator sees page chrome + skeleton from frame 1; real data hot-swaps in.

#### 5. WebSocket push refresh — real-time external-change sync

Replaced the periodic-poll auto-refresh from chunk 4 with WS-driven push.  Polling timers added briefly then removed in favour of this.

**Server** — `notification_service.broadcast_event(kind, data=None)` fans out ephemeral `{type: "event", kind: "..."}` frames to all `/api/v1/ws/notifications` subscribers without persisting to the `notifications` table.  `routers/library.py` calls it after every successful mutation: `library_changed` on create/update/delete/scan/enrich-tmdb; additionally `storage_changed` on delete + scan (since file count + disk usage shifts).

**Client** — new `LibraryEventsService` at `apps/desktop/lib/features/library/data/services/library_events_service.dart` using `dart:io` `WebSocket` (no new dep).  Connects to `/api/v1/ws/notifications` derived from the configured server URL (http→ws, https→wss).  Auto-reconnect with exponential backoff (1 s → 2 s → 4 s → … capped at 30 s).  Filters incoming frames for `type: "event"`; exposes `libraryChanged` + `storageChanged` broadcast streams.

Registered as eager singleton in `injector.dart` (started at app boot — one held TCP connection, ~zero idle overhead).  `LibraryCubit` + `StorageCubit` constructors now take optional `events: LibraryEventsService?`; each cubit subscribes to its matching stream and calls `refresh()` on every event.  StreamSubscription cancelled in `close()`.

Polling code (`_pollTimer`, `startPolling`, `stopPolling`) removed from both cubits.  `LibraryShell.initState` no longer starts polling; `dispose` removed entirely.

Round-trip: mobile/another desktop client mutates a library → server commits + calls `broadcast_event("library_changed")` → fan-out to WS subscribers → desktop's `LibraryEventsService` receives → `libraryChanged` stream fires → cubit's listener calls `refresh()` → UI updates within ~50 ms.  Idle bandwidth: zero bytes / second (one held TCP socket).

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Created | apps/desktop/lib/shared/widgets/flux_pill_tabs.dart | Pill-style outer tab row primitive (distinct from FluxTabBar's underline) |
| Created | apps/desktop/lib/features/library/presentation/screens/library_shell.dart | Stateful IndexedStack tab host for /library; provides LibraryCubit + StorageCubit singletons |
| Created | apps/desktop/lib/features/activity/presentation/screens/activity_shell.dart | Stateful IndexedStack tab host for /activity (Sessions + Logs after Transcoding move) |
| Created | apps/desktop/lib/features/library/data/services/library_events_service.dart | WS subscriber for library_changed / storage_changed events; auto-reconnect with backoff |
| Created | apps/desktop/test/features/activity/activity_event_row_test.dart | 4-case widget test for the Activity deep-link flash animation |
| Created | docs/10_planning/26_desktop_cp_ia_redesign.md | Plan doc (drafted earlier this session arc; final-status pass landed today) |
| Created | docs/logs/AGENT_LOG_archive_13.md | Verbatim copy of pre-rotation AGENT_LOG.md |
| Modified | apps/desktop/lib/core/di/injector.dart | Register LibraryCubit + StorageCubit + LibraryEventsService singletons |
| Modified | apps/desktop/lib/core/router/app_router.dart | Drop per-tab routes; keep /library and /activity; deprecated paths redirect to shell roots |
| Modified | apps/desktop/lib/features/library/presentation/cubit/library_cubit.dart | Promote `_refresh` → public `refresh`; take optional `events: LibraryEventsService?`; subscribe to libraryChanged |
| Modified | apps/desktop/lib/features/storage/presentation/cubit/storage_cubit.dart | Add `refresh()` (silent); take optional `events`; subscribe to storageChanged |
| Modified | apps/desktop/lib/features/library/presentation/screens/library_screen.dart | Pre-selection alphabetical fix; sandwich gradient + fallback centre icon on cards; multi-root "+N more"; toned-down selection glow; smaller top-left badge; `_TypeFilterChips`; `_SmallStatTile`; instant-tap with timestamp double-tap; 80 ms AnimatedContainer; `_SkeletonBody`; auto-populate name in Add Library dialog; `didChangeDependencies` stale-while-revalidate + cached auto-select |
| Modified | apps/desktop/lib/features/transcode/presentation/screens/transcode_screen.dart | Row > Expanded(scroll) + 300 px right panel; `_TranscodeRightPanel` with Selection Details / Details / Storage / Actions sections; `_ActionCard` + `_PathCard` widgets |
| Modified | apps/desktop/lib/features/transcode/presentation/widgets/candidates_tab.dart | Flat sortable table (replaces `FolderTreeView`); per-row Convert; tristate select-all; pagination footer; status column removed; output size column |
| Modified | apps/desktop/lib/features/transcode/presentation/cubit/transcode_cubit.dart | New `startSingleTranscode(fileId)` for per-row Convert |
| Modified | apps/desktop/lib/features/transcode/presentation/widgets/storage_strip.dart | Added Transcoding Settings button (later retired in-tab when right panel landed; helpers stay) |
| Modified | apps/desktop/lib/features/activity/presentation/screens/activity_screen.dart | `embedded` flag for shell hosting; `?event=` deep-link reader; `ActivityEventRow` made public + stateful with flash animation |
| Modified | apps/desktop/lib/features/dashboard/presentation/screens/dashboard_screen.dart | Recent Activity row tap → `/activity/sessions?event=<id>` with URL-encoded id |
| Modified | apps/desktop/lib/features/logs/presentation/screens/logs_screen.dart | `embedded` flag |
| Modified | apps/desktop/lib/features/transcoding/presentation/screens/transcoding_screen.dart | `embedded` flag |
| Modified | apps/desktop/lib/shared/widgets/flux_sidebar.dart | Rail trimmed 10 → 7 items (drop Transcode / Transcoding / Logs) |
| Modified | apps/desktop/lib/shared/widgets/page_header.dart | New `verticalPadding` param (default s24); shells pass s12 for tighter tabbed-page chrome |
| Modified | apps/server/routers/library.py | Emit `library_changed` (+ `storage_changed` on delete/scan) after each successful mutation |
| Modified | apps/server/services/notification_service.py | New `broadcast_event(kind, data)` for ephemeral sync events (no DB persistence) |
| Modified | CLAUDE.md | Plan 26 row in "Where the detail lives" table |
| Modified | docs/08_frontend/01_frontend_architecture.md | Desktop CP IA section + plan 26 + iterations sweep |
| Modified | AGENT_LOG.md | Rotation + this entry |

### Docs Updated

- [`AGENT_LOG.md`](AGENT_LOG.md) — rotated (1065 lines → archive 13) + this entry
- [`docs/logs/AGENT_LOG_archive_13.md`](docs/logs/AGENT_LOG_archive_13.md) — created (verbatim archive of prior log)
- [`docs/10_planning/26_desktop_cp_ia_redesign.md`](docs/10_planning/26_desktop_cp_ia_redesign.md) — plan status updated to Complete with iteration addendum
- [`docs/08_frontend/01_frontend_architecture.md`](docs/08_frontend/01_frontend_architecture.md) — Desktop IA section updated with final tab structure + iteration details
- [`docs/04_api/01_api_contracts.md`](docs/04_api/01_api_contracts.md) — new WS event frame format documented under `/ws/notifications`
- [`docs/05_infrastructure/02_url_inventory.md`](docs/05_infrastructure/02_url_inventory.md) — WS event types added
- [`docs/02_architecture/01_system_overview.md`](docs/02_architecture/01_system_overview.md) — WS event push channel mentioned
- [`docs/00_overview/current_status.md`](docs/00_overview/current_status.md) — desktop 114 → 118 test count + plan 26 status
- [`CLAUDE.md`](CLAUDE.md) — plan 26 row verified accurate

### Decisions Made

- **WS push over polling.**  Briefly shipped a 15 s / 30 s polling pair on `LibraryCubit` + `StorageCubit`, then replaced with `LibraryEventsService` WebSocket on owner's note that WS is materially cheaper for lightweight-server deployments.  Idle cost goes from N×poll-rate to zero bytes / second per client; server load goes from N×poll-rate to one event per mutation regardless of subscriber count.
- **Drop per-tab URLs in favour of internal tab state.**  Each pill being its own `go_router` route was the root cause of the tab-switch unmount → cubit re-creation → re-fetch sequence.  Single `/library` route with internal state preserves cubits across tab switches.  Operators rarely deep-link to specific tabs on a desktop app — acceptable trade-off.
- **Singleton cubits over per-page providers.**  Library + Storage cubits register in GetIt as lazy singletons; shell uses `BlocProvider.value`.  Navigating between pages keeps cubit state cached; refresh button still works.  Memory cost is the library list + storage breakdown — negligible.
- **`onTap` + manual double-tap over custom GestureRecognizer.**  Iterated through `onTapDown`, custom `_InstantTapGestureRecognizer` (arena-bypass via rejectGesture→acceptGesture override), then settled on plain `onTap` (no `onDoubleTap` in the GestureDetector, so the arena has no competition and Tap fires instantly on release) + timestamp-based double-tap inside the handler.  Cleanest code; same UX.
- **Skeleton body over centred spinner.**  Renders the page shell (stat strip with `'—'` placeholders, real toolbar, ghost cards) so the operator sees structure from frame 1 instead of a blank loading state.  Hot-swap to real data when cubit Loaded.
- **Server emits two event kinds (`library_changed` + `storage_changed`) instead of one.**  Some mutations only change library metadata (rename, TMDB enrichment) without touching storage; only scan + delete affect storage totals.  Separate events let each cubit refresh only what's needed instead of everyone re-fetching everything.

### Issues / Sharp Edges Discovered

1. **Flutter's gesture arena adds ~300 ms to single-tap when `onDoubleTap` is also registered.**  Standard pattern; not a Fluxora-specific bug.  Worked around by avoiding `onDoubleTap` and doing manual double-tap detection.
2. **`AllowMultipleGestureRecognizer.rejectGesture → acceptGesture` override only helps the double-tap path, not the single-tap path.**  The arena calls `rejectGesture` when DoubleTap *wins*; for single taps Tap eventually wins via timeout (the 300 ms delay).  The override pattern from Stack Overflow is misleading — it doesn't fix the single-tap latency it claims to.
3. **IndexedStack with all children always-mounted starts every cubit at shell-open time.**  Mitigated by `_visited` set + `SizedBox.shrink()` for unvisited tabs (lazy mount).
4. **`BlocConsumer.listener` doesn't fire for the cubit's initial state on re-mount.**  Singleton cubits hold their Loaded state across page navigations, but the listener only sees fresh emissions.  Fix: replicate the auto-select logic in `didChangeDependencies`.
5. **`StatTile` doesn't have a compact variant.**  Built local `_SmallStatTile` (~60 % size) instead of modifying the shared widget — keeps Dashboard's full-size tiles unaffected.
6. **`close_sinks` lint flags WebSockets stored in fields.**  False positive — the socket is closed in `stop()`, just not in `_connect()` where it's opened.  Suppressed with `// ignore: close_sinks` + an explaining comment.

### Test Counts (re-baselined)

- **Desktop: 118 passing** (+4 `activity_event_row_test`; +1 from migration test cleanup elsewhere; previous baseline 114).  No new tests today for the IndexedStack / singleton-cubit / WS work — manual verification only.  Stale follow-ups in [Next Agent Should](#next-agent-should).
- Server, Mobile, Core: untouched.

`flutter analyze --no-pub` clean × desktop in 5–10 s.

### Working-Tree Status

Uncommitted.  Suggested commit chunking — eight logical groups so each PR (or commit) is reviewable in isolation:

1. **Plan 26 plan doc + AGENT_LOG rotation** — `docs/10_planning/26_*.md` + `docs/logs/AGENT_LOG_archive_13.md` + `AGENT_LOG.md` + `CLAUDE.md` row.  Standalone.
2. **Shared widget primitives** — `flux_pill_tabs.dart` (new); `page_header.dart` `verticalPadding` param.  No behavioural impact on existing callers (default preserved).
3. **Library + Activity shells (IA refactor)** — `library_shell.dart` + `activity_shell.dart` + `app_router.dart` route changes + sidebar nav-rail trim.  Depends on #2.
4. **Inner-screen `embedded` flag + Dashboard deep-links** — `library_screen.dart` (embedded path, gradient sandwich, fallback icon, multi-root "+N more", small stat tile, type filter chips, instant tap, skeleton body, dialog auto-populate name, didChangeDependencies refresh + auto-select), `transcode_screen.dart` (right panel), `transcoding_screen.dart`, `logs_screen.dart`, `activity_screen.dart` (incl. `ActivityEventRow` flash), `dashboard_screen.dart` (deep-link wiring).  Depends on #3.
5. **Convert tab table + cubit** — `candidates_tab.dart` (flat sortable table + pagination), `transcode_cubit.dart` (`startSingleTranscode`), `storage_strip.dart` trim.  Depends on #2.
6. **Singleton cubits** — `injector.dart` + `library_cubit.dart` + `storage_cubit.dart` `refresh()` promotion.  Depends on #4.
7. **Server WS event emission** — `notification_service.py` + `routers/library.py`.  Standalone, ships independently of client.
8. **Client WS subscriber** — `library_events_service.dart` (new) + `injector.dart` registration + cubit constructor changes.  Depends on #6 and #7.
9. **Docs sweep** — `docs/08_frontend/*`, `docs/04_api/*`, `docs/05_infrastructure/*`, `docs/02_architecture/*`, `docs/00_overview/current_status.md`.

### Next Agent Should

1. **Operator real-device sanity-check on the new IA + WS pipeline.**  Open Library → click between pill tabs → verify zero pop-in (IndexedStack works).  Mutate a library from a second client (mobile or curl) → verify desktop UI updates within ~1 s (WS push works).  Restart server → verify desktop reconnects without manual intervention.
2. **Widget tests for `LibraryShell` + `ActivityShell` IndexedStack switching.**  Pump shell with each `*ShellTabPath`, verify the right body is visible.  Verify visited-tab caching (second click on a previously-visited tab is instant).
3. **Widget test for `_TranscodeRightPanel` action cards.**  Verify Start Transcode opens preset dialog; Add to Queue skips dialog; Clear Selection wipes; Transcoding Settings navigates.
4. **WS auth handshake for non-localhost deployments.**  `LibraryEventsService` currently skips auth (localhost-only).  Cloudflared-tunnelled deployments will need first-message `{"type":"auth","token":"…"}` per the pattern in `ws.py::_authenticate`.  Half-hour job.
5. **Plan 26 archival.**  Once operator sign-off lands on item 1, move `docs/10_planning/26_desktop_cp_ia_redesign.md` to `docs/10_planning/archive/`.  Update `CLAUDE.md` row to mark complete.
6. **Operator sign-off on plan 24 M5 + M6** (multi-audio device smoke + HDR tonemap on real Android device).  Then delete `_kForceMediaKitOnAndroid` and archive plan 24.
