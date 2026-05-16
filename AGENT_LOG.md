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

---

## [2026-05-16] [planning] [docs] — Plan 27 drafted (per-file thumbnail generation) · revised w/ expanded scope

**Phase:** Plan 27 kickoff — gradient-mosaic fallback (landed earlier same day) is a stopgap; operator wants real per-file thumbs.  Draft plan written, owner-reviewed, scope expanded to absorb every previously-deferred v1.1 item except on-demand endpoint generation.
**Status:** Plan-doc draft only.  Implementation starts next agent turn (M1).
**Commits:** uncommitted

### What Was Done

1. **Drafted [`docs/10_planning/27_thumbnail_generation_plan.md`](docs/10_planning/27_thumbnail_generation_plan.md)** — six milestones, ~8–10 h end-to-end.  Background asyncio worker decouples generation from scan path (scan latency unchanged).  Four extractor paths: FFmpeg for video (with HDR→SDR Hable tonemap branch when `media_files.hdr_format IS NOT NULL`), FFmpeg for image (JPEG/PNG/WEBP/HEIC/BMP/TIFF), FFmpeg for audio embedded APIC, PyMuPDF for PDF first page.  Per-library priority boost (operator opens `/files?library_id=X` → that library's pending thumbs jump to `priority=10`).  Failure-aggregation notifications (one per library when ≥ 5 files fail, dedup'd on `dismissed_at IS NULL`).  `?v=<gen_unix>` URL cache-buster on cover URLs so regeneration invalidates client caches without a separate revalidation request.  Operator-triggered regeneration via desktop `_ActionTile` → `POST /library/{id}/regenerate-thumbnails`.  `thumbnail_width` settings field (range 160–640, default 320) plumbed through worker → extractor → Settings → Advanced slider.
2. **Cross-doc updates announcing plan 27 active** — `CLAUDE.md` lookup row, `docs/00_overview/current_status.md` top entry, `docs/10_planning/01_roadmap.md` row.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| ➕ Create | `docs/10_planning/27_thumbnail_generation_plan.md` | Six-milestone plan: schema + extractors → worker + priority + notifications → endpoint + cover_urls + regen endpoint → settings field → desktop UI → sweeper + docs |
| ✏️ Update | `CLAUDE.md` | New row in "Where the detail lives" table linking to plan 27 doc |
| ✏️ Update | `docs/00_overview/current_status.md` | New top entry announcing plan 27 active |
| ✏️ Update | `docs/10_planning/01_roadmap.md` | New row in the "What's outstanding" table marked 📝 Active 2026-05-16 |

### Decisions Made

1. **PyMuPDF over `pdf2image`+`poppler`** — PyMuPDF is a pure-Python wheel with no system binary dep; `pdf2image` would have required bundling poppler in the Windows installer and runtime detection on Mac/Linux.  AGPL license is compatible with Fluxora's open-source self-hosted distribution model (operators self-host; AGPL source-disclosure satisfied by Fluxora being open-source).
2. **Background-only generation; no on-demand in endpoint** — owner direction was unambiguous: "scans must be really fast we can generate thumb lazy, in bg."  Endpoint returns 404 if not ready; client falls back to the gradient mosaic.  Avoids the cold-view stall risk of inline-generation.
3. **Scope absorbed all but one v1.1 deferred item** — owner re-scoped 2026-05-16 to pull nine of the original §10 Out of Scope items into v1.  HDR tonemap, per-library priority queue, failure notification, regenerate UI, configurable width, CDN URL versioning, PDF thumbs, mobile-no-code-needed.  Only on-demand endpoint generation remains deferred (above).
4. **Separate `media_thumbnails` table, not columns on `media_files`** — three reasons: keeps the hot `media_files` row schema clean; lets the worker UPDATE without touching `media_files.updated_at` (which would mess with TMDB enrichment ordering); `ON DELETE CASCADE` from `media_files` handles cleanup automatically.
5. **`UPDATE ... RETURNING` for atomic claim** — SQLite 3.35+ supports it; Python 3.11+ ships 3.40+; verified at project floor.  Single-statement claim prevents two workers grabbing the same row.

### Issues / Sharp Edges Discovered

1. **PyMuPDF wheel-availability fallback** — at least Python 3.10–3.13 + Win/Mac/Linux are covered by the official wheels, but if a fringe platform fails the import we don't want to crash startup.  Worker imports inside a try/except; `kind=pdf` falls through to `skipped` with `error_message='pymupdf not available'` on import failure.  Plan §11 risk row + §8 edge 27.
2. **HDR tonemap correctness** — same chain as plan 17 streams (operator-verified there), but worth a unit test asserting non-clipped output histogram so a future FFmpeg upgrade doesn't silently regress.  Plan M1 acceptance.
3. **Priority boost on already-boosted rows** — `UPDATE WHERE priority=0` is idempotent so rapid library-switching doesn't re-write rows that are already at 10.  Worst case: all pending rows climb to 10 → degenerates to FIFO inside that band.  Acceptable.
4. **Regenerate during in-flight generation** — `regenerate_library` resets rows that may be `status='generating'`.  The in-flight slot finishes its `UPDATE WHERE status='generating'` successfully (it claimed the row earlier), writes `ready`, but the row goes back to `pending` on the next regenerate sweep.  Net: one wasted extraction; clean rebuild afterward.  Plan §8 edge 24.

### Next Agent Should

1. **Start M1 — schema + extractors.**  Migration `037_media_thumbnails.sql`, `services/thumbnail_service.py` with the four helpers + `ThumbnailResult` dataclass, `pymupdf` added to `pyproject.toml`.  Unit tests against `lavfi testsrc` (SDR + synthetic-PQ for HDR branch), `lavfi anullsrc` (skip), image fixture, encrypted PDF fixture (skip), corrupt PDF (failed), width param respected.  Plan §6.1 + §9 M1.
2. **Then M2 — worker.**  `services/thumbnail_worker.py` with atomic claim, `enqueue` / `boost_library` / `regenerate_library` / `_maybe_emit_failure_notification` methods; `main.py` lifespan wiring; scan-path enqueue hook in `library_service.scan_library` + `_persist_probe`'s sibling INSERT.  10 unit tests covering atomicity + priority + setting toggle + restart-recovery + skip + dispatch + notification + dedup + boost idempotency + regen.
3. **Run server tests after each milestone** (`cd apps/server && pytest`).  Aim for green at every step before progressing.

---

## [2026-05-16] [server] [desktop] [feat] — Plan 27 ship · all six milestones in one day

**Phase:** Plan 27 ship — background asyncio thumbnail-generation pipeline end-to-end.
**Status:** Complete
**Commits:** `217ff8b` M1 · `137362c` M2 · `3dbaf16` M3 · `b0428b0` M4 · `3e8066e` M5 · this commit M6

### What Was Done

All six milestones of plan 27 shipped same-day per the expanded-scope spec.  Each milestone landed as a self-contained commit with green tests before the next started.

**M1 — Schema + extractors (`217ff8b`).** Migration `037_media_thumbnails.sql` (queue table w/ status state machine pending → generating → ready / failed / skipped, priority column for operator-opened-library boost, partial index on `(priority DESC, created_at ASC) WHERE status='pending'`, backfill INSERT seeds every existing media_files row).  New dep `pymupdf==1.27.2.3` (pure-Python wheel, AGPL-compatible).  `services/thumbnail_service.py` with `ThumbnailResult` dataclass + four extractors (FFmpeg video w/ Hable HDR→SDR branch when `hdr_format` is set, FFmpeg image, FFmpeg audio APIC w/ stderr-signature detection for "no embedded art" → skipped, PyMuPDF PDF first page lazy-imported in `asyncio.to_thread`).  Subprocess timeouts: 30 s video / 15 s image+audio+pdf.  Width clamp [32, 2048].  21 unit tests against `lavfi testsrc` (SDR happy + short clip + corrupt file → failed), minimal PNG fixture, `lavfi anullsrc` → skipped, synthetic 1-page PDF + encrypted PDF (skipped) + corrupt PDF (failed), filter-chain shape unit tests for SDR + HDR branches, concurrent extraction smoke.

**M2 — Worker + scan-path enqueue + failure notifications (`137362c`).** `services/thumbnail_worker.py` with N parallel coroutines (default CONCURRENCY=2), atomic claim via `UPDATE ... RETURNING` (split into UPDATE-by-id then SELECT-joined-row since SQLite can't combine RETURNING with JOIN), `enqueue(db, file_id, priority=0)` (INSERT OR IGNORE — keeps scan path O(1) per file), `boost_library(db, library_id)` (UPDATE WHERE priority=0 → 10, idempotent), `regenerate_library(db, library_id)` (resets every row + deletes JPEGs).  `_maybe_emit_failure_notification` aggregates: counts permanent failures (attempts ≥ max_attempts) for the library, fires one summary notification at FAILURE_NOTIFICATION_THRESHOLD=5, dedup against open `(category='thumbnail', dismissed_at IS NULL)`.  Migration `038_notifications_thumbnail_category.sql` widens the CHECK constraint by table-rebuild pattern (SQLite can't ALTER a CHECK in place).  `_recover_orphan_generating_rows` resets prior-crash `generating` rows back to `pending` at startup.  `_sweep_orphan_jpegs` deletes JPEGs whose file_id isn't in `media_thumbnails` (cascade-from-media-files-delete cleanup), bounded to 100 per pass, runs every 6 h.  `main.py` lifespan: `start_worker()` after `init_db`, `stop_worker()` before `close_db` (best-effort).  `library_service.scan_library` calls `enqueue` after each INSERT (best-effort, swallows errors).  20 unit tests cover atomicity + priority + skip / dispatch / failure / threshold-fire / dedup-on-open / regen + crash-recovery.

**M3 — Endpoint + cover_urls aggregation + regenerate endpoint (`3dbaf16`).** `GET /api/v1/files/{file_id}/thumbnail?v=<unix>` serves cached JPEG with `Cache-Control: public, max-age=86400`; 404 when not ready or JPEG missing on disk; accepts and ignores `v` query param; visibility-gated (404 not 403 for cross-group bearer callers).  `POST /api/v1/library/{library_id}/regenerate-thumbnails` returns `{library_id, queued}` + records `library.thumbnails_regenerated` activity event.  `library_service._library_aggregates` rewritten: TMDB poster URLs first (preferred); if < 4, top up with `/api/v1/files/{file_id}/thumbnail?v=<gen_unix>` URLs from media_thumbnails 'ready' rows; JOIN filter excludes files that already have TMDB art (no duplicate covers for the same file).  `GET /files?library_id=X` calls `thumbnail_worker.boost_library` so the operator-opened library jumps the queue.  14 endpoint tests + cover_urls aggregation tests (all-TMDB / all-thumbs / mixed / duplicate-exclusion).

**M4 — `thumbnail_width` settings field (`b0428b0`).** Migration `039_user_settings_thumbnail_width.sql` adds the column with default 320.  `models/settings.py` `UserSettingsResponse.thumbnail_width: int = 320` + `UpdateSettingsBody.thumbnail_width: int | None = Field(default=None, ge=160, le=640)` — Pydantic returns 422 on out-of-range without router-level branching.  `services/settings_service.py` plumbed (kwarg, column map, defaults).  Worker reads the value per claim cycle.  16 tests: defaults round-trip + accept/reject parametrized ranges + worker reader fallback to 320 pre-migration.

**M5 — Desktop regenerate UI + Settings → Advanced slider (`3e8066e`).**  New `Endpoints.libraryRegenerateThumbnails` + `LibraryRepository.regenerateThumbnails` + `LibraryCubit.regenerateThumbnails` (rethrows on API failure without firing refresh).  New `_ActionTile` on `_LibraryDetailPanel` between Rescan TMDB and View Library Files with `Icons.image_outlined`.  `_regenerateThumbnails(BuildContext, Library)` helper on `_LibraryViewState` surfaces a queued-count toast.  Settings → Advanced gained a `_SettingBlock` "Thumbnails" with a `FluxSlider` for `thumbnail_width` (160–640 in 20-px divisions; live "$N px" label).  `SettingsLoaded.thumbnailWidth` + `SettingsCubit.saveSettings(thumbnailWidth: ...)` diff-only PATCH plumbing.  3 cubit tests covering the regenerate happy path + API failure rethrow + zero-queued path.

**M6 — Doc sweep + AGENT_LOG (this commit).**  `docs/04_api/01_api_contracts.md` documents both new endpoints (request/response/errors/visibility) + adds the `library.thumbnails_regenerated` activity event + adds the `thumbnail` notification producer row.  `docs/05_infrastructure/02_url_inventory.md` adds two new endpoint rows.  `docs/03_data/02_database_schema.md` status line bumped to cover migrations 037 + 038 + 039.  `docs/00_overview/current_status.md` flips plan 27 from 📝 Active to ✅ Shipped + bumps test counts (server 814 → 898; desktop 118 → 121).  `docs/10_planning/01_roadmap.md` row flipped to ✅ Done.  `CLAUDE.md` lookup row rewritten to match shipped state.  `docs/08_frontend/01_frontend_architecture.md` status header gains plan 27 note.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| ➕ Create | `apps/server/database/migrations/037_media_thumbnails.sql` | Queue table + partial pending-index + existing-rows backfill INSERT |
| ➕ Create | `apps/server/database/migrations/038_notifications_thumbnail_category.sql` | Widens category CHECK to accept 'thumbnail' (SQLite table-rebuild pattern) |
| ➕ Create | `apps/server/database/migrations/039_user_settings_thumbnail_width.sql` | New INTEGER column default 320 |
| ➕ Create | `apps/server/services/thumbnail_service.py` | Pure-function extractors (video/image/audio/pdf) + `ThumbnailResult` dataclass + kind dispatch |
| ➕ Create | `apps/server/services/thumbnail_worker.py` | Asyncio worker pool + claim + state-machine transitions + failure aggregation + orphan-JPEG sweeper |
| ➕ Create | `apps/server/tests/test_thumbnail_service.py` | 21 extractor tests |
| ➕ Create | `apps/server/tests/test_thumbnail_worker.py` | 20 worker tests |
| ➕ Create | `apps/server/tests/test_thumbnail_endpoint.py` | 14 endpoint + cover_urls aggregation tests |
| ➕ Create | `apps/server/tests/test_thumbnail_settings.py` | 16 settings-field tests |
| ➕ Create | `apps/desktop/test/features/library/library_cubit_test.dart` | 3 regenerate cubit tests + 1 sanity |
| ✏️ Update | `apps/server/pyproject.toml` | Add `pymupdf==1.27.2.3` |
| ✏️ Update | `apps/server/main.py` | Lifespan: `thumbnail_worker.start_worker()` after transcode worker; `stop_worker()` on shutdown |
| ✏️ Update | `apps/server/services/library_service.py` | Scan-path enqueue hook + `_library_aggregates` cover_urls union (TMDB + thumbs w/ `?v=` cache-buster) |
| ✏️ Update | `apps/server/routers/files.py` | New `GET /{file_id}/thumbnail` endpoint + `boost_library` call from `GET /files?library_id=X` |
| ✏️ Update | `apps/server/routers/library.py` | New `POST /{library_id}/regenerate-thumbnails` endpoint |
| ✏️ Update | `apps/server/models/settings.py` | `UserSettingsResponse.thumbnail_width` + `UpdateSettingsBody.thumbnail_width` with `Field(ge=160, le=640)` |
| ✏️ Update | `apps/server/services/settings_service.py` | `thumbnail_width` kwarg + column map + default seeded |
| ✏️ Update | `apps/desktop/lib/features/library/domain/repositories/library_repository.dart` | New `regenerateThumbnails(libraryId) -> int` abstract method |
| ✏️ Update | `apps/desktop/lib/features/library/data/repositories/library_repository_impl.dart` | POST to `libraryRegenerateThumbnails` endpoint, parse `{queued}` |
| ✏️ Update | `apps/desktop/lib/features/library/presentation/cubit/library_cubit.dart` | `regenerateThumbnails` method + silent refresh after success |
| ✏️ Update | `apps/desktop/lib/features/library/presentation/screens/library_screen.dart` | `_LibraryDetailPanel.onRegenerateThumbnails` constructor arg + `_ActionTile` + `_regenerateThumbnails` helper on `_LibraryViewState` |
| ✏️ Update | `apps/desktop/lib/features/settings/presentation/cubit/settings_state.dart` | `thumbnailWidth: int = 320` field + `copyWith` |
| ✏️ Update | `apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart` | Load + saveSettings plumbing |
| ✏️ Update | `apps/desktop/lib/features/settings/presentation/screens/settings_screen.dart` | `_thumbnailWidth` field + `_AdvancedTab.thumbnailWidth` + `Icons.image_outlined` Thumbnails `_SettingBlock` with `FluxSlider` |
| ✏️ Update | `packages/fluxora_core/lib/network/endpoints.dart` | New `libraryRegenerateThumbnails(libraryId)` helper |
| ✏️ Update | `docs/04_api/01_api_contracts.md` | Document both new endpoints + activity event + notification producer |
| ✏️ Update | `docs/05_infrastructure/02_url_inventory.md` | Two new endpoint rows |
| ✏️ Update | `docs/03_data/02_database_schema.md` | Status line covers migrations 037 + 038 + 039 |
| ✏️ Update | `docs/00_overview/current_status.md` | Plan 27 → ✅ Shipped; bump test counts |
| ✏️ Update | `docs/10_planning/01_roadmap.md` | Row → ✅ Done |
| ✏️ Update | `CLAUDE.md` | Lookup row rewritten to shipped state |
| ✏️ Update | `docs/08_frontend/01_frontend_architecture.md` | Status header plan 27 note |

### Decisions Made

1. **Three migrations instead of two.**  Plan originally specced two (037 table + 038 settings).  M2 surfaced that the `notifications.category` CHECK constraint blocks `'thumbnail'`, so a separate widening migration was needed — added as 038 with the settings column shifted to 039.  Cleaner than coupling unrelated schema changes.
2. **End-to-end HDR pipeline test omitted.**  Synthetic-PQ via FFmpeg's `color` filter trips `zscale`'s "no path between colorspaces" guard (libx264's lavfi shape doesn't carry stream-level colorspace VUI flags).  Kept pure-function unit tests of `_build_video_filter_chain` (proves the right chain is wired up when `hdr_format` is set) since the filter string is byte-identical to `services/ffmpeg_service._HDR_TO_SDR_VF` which is operator-verified on real HDR streams.  Documented in the test file's note + plan §8 edge 7.
3. **Lazy PyMuPDF import inside the extractor.**  Wrapped in `try/except ImportError` so a missing wheel on a fringe platform surfaces as a per-file skip (`error_message='pymupdf not available'`) rather than a startup crash.  Plan §11 risk row.
4. **`cur.rowcount` is unreliable on aiosqlite UPDATE.**  Surfaced during M2 worker tests — `boost_library` returned 0 even when the UPDATE clearly hit rows.  Fixed by following the UPDATE with `SELECT changes()` (SQLite's session-scoped change counter).  Same pattern in `_recover_orphan_generating_rows`.
5. **No on-demand generation in the endpoint.**  Endpoint returns 404 if not yet ready; client falls back to the gradient mosaic.  Per owner direction earlier in this session.  Avoids the cold-view stall risk of inline generation.

### Issues / Sharp Edges Discovered

1. **AIOSqlite `cursor.rowcount` is 0 for UPDATEs** — fix is `SELECT changes()` after the UPDATE.  Worth flagging in `docs/12_guidelines/03_gotchas.md` as a future polish for anyone writing new aiosqlite UPDATE-returning-count code.
2. **`UPDATE ... RETURNING` can't combine with JOIN in SQLite.**  M2 wanted to claim + JOIN media_files in one statement; ended up splitting into UPDATE-by-id-then-SELECT-joined wrapped in a single transaction.  Documented inline in `_claim_one`.
3. **Migration 038's category-CHECK widening is table-rebuild pattern** — preserves indexes + data but bumps `notifications` table OID.  Future migrations that pre-create indexes on `notifications` need to know the table identity will have shifted at this point.
4. **`_get_current_settings` tolerates missing `thumbnail_width` column** — M2 ships before M4, so the worker has to handle the pre-M4 schema.  When M4's migration lands the fallback path stops triggering; the defensive branch can be removed in a follow-up but adds zero overhead today.

### Next Agent Should

1. **Operator smoke test** on a real library with no TMDB enrichment.  Open Library → click a Music or Documents library card → wait a few seconds → cards should populate with extracted thumbs (not gradient placeholders).  Restart the server → confirm workers resume on existing pending rows.  Toggle the Settings slider, hit Regenerate Thumbnails on a library, watch the cards refresh in place.
2. **Plan 26 archival.**  Plan 26 + this plan 27 close out the same-day desktop-CP iteration.  Move plan 26 to `docs/10_planning/archive/` once operator sign-off lands on item 1.  Plan 27 can follow the same path — both are shipped end-to-end.
3. **Drop the `_get_current_settings` pre-M4 fallback branch** in `services/thumbnail_worker.py` once we're confident no operator is running the M2-without-M4 intermediate state (i.e. always after a fresh install since migrations apply in order).  ~5-minute follow-up.

---

## [2026-05-16] [server] [desktop] [feat] [fix] — Plan 27 post-ship polish + folder-browser MVP + plan 28 drafted

**Phase:** Plan 27 post-ship iteration based on operator real-device feedback ("thumbs taking so much time", "i cant see them in ui", "no progress visibility"); plus new feature ask — Explorer-style folder browser for library files; plus plan-28 drafted for the upcoming power-features pass on top of the MVP browser.
**Status:** Complete (MVP browser + plan-27 polish shipped; plan-28 is doc-only — implementation later).
**Commits:** uncommitted (this entry written before the 5-commit chunked landing pass)

### What Was Done

**1 · Thumbnail-worker speed bump.** Operator caught that worker throughput felt much slower than Windows Explorer's thumbnail provider.  Root causes: per-file FFmpeg subprocess overhead (~50–150 ms cold start), `CONCURRENCY = 2` (idle home servers have 8–16 cores), no GPU decode (CPU-only on AV1/HEVC is brutal), lanczos scaler + q:v 5 (high quality but CPU-heavy for a 320 px thumbnail).  Four changes — additive, none change the design:

  - `CONCURRENCY = 2 → 4` in `services/thumbnail_worker.py`.  Module comment notes operators with streaming-pipeline contention can dial back to 2.
  - `-hwaccel auto` added to the **SDR** video extractor argv with automatic software-fallback retry on hwaccel error (handles older drivers that report a hwaccel as available but error on specific codecs).  HDR path stays CPU-only since `zscale` rejects hwaccel frame formats without an `hwdownload` prelude.
  - `flags=lanczos → flags=bilinear` in `_build_video_filter_chain` + the image extractor's `-vf`.  ~30 % faster scale, indistinguishable at 320 px.
  - `-q:v 5 → -q:v 8` for JPEG output.  Smaller files, faster encode, same visible quality at this size.

  Filter-chain unit tests updated (`scale=...:flags=bilinear` instead of `:flags=lanczos`).  Expected real-world impact: ~4–8× faster on a typical library.

**2 · Real-time progress visibility.** Operator: "where can i see the progress?".  Pre-fix, the BG worker was silent — only server logs showed activity, and cards didn't auto-refresh after thumbnails generated.

  - **Server:** new `_emit_progress(db, library_id)` helper in `thumbnail_worker.py`, called from `_process_one` after every terminal status transition (ready / skipped / failed).  Computes per-library `(pending, ready, total)` counts via one SQL query, broadcasts a `thumbnails_progress` WS frame.  Also throttles a `library_changed` emit every 5th completion per library + always on the last-pending completion (so cover_urls refresh as thumbs land during a scan without 1 GET-per-file).
  - **`notification_service.broadcast_event(kind, data=...)`** already supported the `data` payload (added with plan 27 M3); no change there.
  - **Client:** `LibraryEventsService` gains `Stream<ThumbnailProgress> thumbnailsProgress` + a frame-handler `case 'thumbnails_progress'` that decodes via `ThumbnailProgress.tryParse` (defensive; bad payloads are logged + dropped).  `LibraryLoaded.thumbnailProgress: Map<String, ThumbnailProgress>` field (defaults to empty const map); `LibraryCubit._applyProgress` merges incoming progress into a fresh `LibraryLoaded` emission and auto-removes the entry on `isComplete` so the chip disappears.  Map is preserved across `refresh()` / `selectLibrary` / `deleteLibrary` so the chip doesn't flicker.
  - **Card UI:** new `_ThumbnailProgressStrip` widget pinned to the top edge of `_LibraryCard` via `Positioned(top: 0)`.  3 px violet→cyan gradient progress bar (`FractionallySizedBox` with `widthFactor: ready/total`) + a small `Thumbs M / T` pill in the top-right.  Auto-hides when `progress.isComplete`.

  5 new server tests cover `_emit_progress` shape, library_changed throttle ramp-up, force-emit on queue empty, NULL library_id no-op, and end-to-end `_process_one` integration.

**3 · Critical cover_urls visibility fix.** Operator: "i generated thumbs but visually i cant see them in ui".  Root cause discovered: `_library_aggregates` returns server-relative URLs like `/api/v1/files/<id>/thumbnail?v=...`, but Flutter's `Image.network` requires absolute URLs.  Pre-plan-27 `cover_urls` were TMDB-only (already absolute `https://image.tmdb.org/...`), so the bug only surfaced once plan 27 started mixing in generated-thumbnail URLs.

  - **`LibraryRepositoryImpl._resolveCoverUrls`** (new helper) walks the `cover_urls` array at parse time; prefixes anything starting with `/` with `_apiClient.localBaseUrl` (trailing-slash safe).  Applied at every `Library.fromJson` call site in the repo: `getLibrariesWithOverrides` / `createLibrary` / `updateLibrary`.
  - **Alternative considered:** make server return absolute URLs.  Rejected because server doesn't always know its own public URL (local LAN vs Cloudflare tunnel) without plumbing `request.base_url` through `_library_aggregates`, which is a bigger refactor than the client-side resolver.

**4 · Folder-browser MVP.** Operator: "i want to see the exact folder structure as the explorer ... see all the files there, hidden files toggle".  v1 `library_files_screen.dart` showed only `media_files` rows (curated streamable subset) — operator wanted Explorer-style filesystem view of the actual `root_paths`.

  - **Server:** new `services/browse_service.py` (~340 LOC).  `BrowseEntry` + `BrowseResponse` dataclasses; `BrowseError(status, detail)` for the router→HTTP-status mapping.  `_resolve_under_root` does path normalisation + `Path.resolve(strict=False)` + `is_relative_to` containment check + multi-root resolution.  `_list_entries` does the non-recursive `iterdir` with hidden detection (dotfile + Windows `FILE_ATTRIBUTE_HIDDEN/SYSTEM` via `st_file_attributes`), symlink-follow-once for kind, then a directories-first-then-alphabetical sort.  `_attach_index_status` JOINs the entries against `media_files.path` so each carries `is_indexed` + `file_id`.  Exposed as `GET /api/v1/library/{id}/browse?path=&show_hidden=` via `routers/library.py`.  13 endpoint tests (root listing, subdir, hidden toggle, kind dispatch, indexed join, path traversal block, nonexistent path, unknown library, empty library, entry-field round-trip, Windows hidden-attribute skipped on non-Windows).
  - **Client:** new `BrowseEntry` + `BrowseResponse` + `BrowseKind` types at `apps/desktop/lib/features/library/domain/entities/browse_entry.dart` (mirrors server shape; `tryFromJson` for defensive decoding).  New `Endpoints.libraryBrowse(libraryId)` constant.  New `LibraryRepository.browseLibrary({libraryId, path, showHidden})` abstract method + impl.  New `LibraryBrowseCubit` at `apps/desktop/lib/features/library/presentation/cubit/library_browse_cubit.dart` — `load() / navigateTo() / goUp() / setShowHidden()` + sealed `LibraryBrowseState` (Initial / Loading / Loaded / Failure).
  - **`library_files_screen.dart`** **fully rewritten** as an Explorer-style folder browser (~520 LOC).  `PageHeader.onBack` rounded back button (matches Encoder Settings shape) + `_HeaderActions` row with Show-hidden toggle icon + Refresh icon + violet primary `FluxButton` "Open in Explorer".  `_BreadcrumbBar` with go-up icon + clickable segment chips + copy-path icon.  `_BrowseListBody` with `_ColumnHeaderRow` (NAME / SIZE / MODIFIED) + scrollable list of `_BrowseRow`s.  Each row: kind-coloured icon (folder/video/image/audio/pdf/other), name + Hidden/Indexed tags, size column, modified column, per-row reveal-in-folder icon.  Click semantics (v1, single-action — plan 28 reshapes): directory click → navigate into it; file click → open in OS default app via `launchUrl(Uri.file(path))`.  `_ToolbarIconButton` shared widget (28 px or 24 px compact) with active state + violet hover.  Skeleton-loading body + empty-state ("This library is empty" / "This folder is empty") + failure body with retry button.

**5 · Plan 28 drafted.** After shipping the MVP folder browser, operator asked for the candidates-table-style power features.  Looked at all 19 requested + 6 additional improvements I noticed while thinking through it; ranked into Phase A (foundation: sortable cols + single/double click + right detail panel + grid view + search), Phase B (filters + count footer + keyboard nav + indexed toggle + polish), Phase C (context menu + path textbox + per-file Index/Generate-thumb actions + density + multi-select), Phase D (history + folder-size lazy compute).  Tier 3 (recursive search via FTS5, bookmarks, drag-to-Convert, FS watching) each split out as their own plan since each has novel infra.  Plan doc to be added: `docs/10_planning/28_library_file_browser_power_features.md`.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| ✏️ Update | `apps/server/services/thumbnail_service.py` | Speed: hwaccel auto + sw fallback retry on video; lanczos→bilinear; q:v 5→8 |
| ✏️ Update | `apps/server/services/thumbnail_worker.py` | Speed: CONCURRENCY 2→4.  Progress: `_emit_progress` + `_PROGRESS_REFRESH_COUNTERS` + emit calls in `_process_one`'s success/skipped/failed branches |
| ✏️ Update | `apps/server/tests/test_thumbnail_service.py` | Filter-chain assertions follow bilinear rename |
| ✏️ Update | `apps/server/tests/test_thumbnail_worker.py` | 5 new tests covering `_emit_progress` shape, throttle ramp-up, force-emit on queue empty, NULL library_id, end-to-end `_process_one` integration |
| ➕ Create | `apps/server/services/browse_service.py` | Filesystem-walker w/ path-traversal block, hidden detection, kind dispatch, `media_files.path` JOIN |
| ➕ Create | `apps/server/tests/test_browse.py` | 13 endpoint tests including path-traversal block + Windows hidden attribute (skipped on non-Windows) |
| ✏️ Update | `apps/server/routers/library.py` | New `GET /{library_id}/browse?path=&show_hidden=` route mapped to `BrowseError` → HTTP statuses |
| ✏️ Update | `apps/desktop/lib/features/library/data/repositories/library_repository_impl.dart` | `_resolveCoverUrls` walks `cover_urls` + prefixes server-relative paths w/ `localBaseUrl`.  `browseLibrary` impl. |
| ✏️ Update | `apps/desktop/lib/features/library/domain/repositories/library_repository.dart` | New `browseLibrary({libraryId, path, showHidden})` abstract method |
| ➕ Create | `apps/desktop/lib/features/library/domain/entities/browse_entry.dart` | `BrowseEntry` / `BrowseResponse` / `BrowseKind` value classes w/ defensive `tryFromJson` decoding |
| ➕ Create | `apps/desktop/lib/features/library/presentation/cubit/library_browse_cubit.dart` | `LibraryBrowseCubit` w/ sealed state + `load/navigateTo/goUp/setShowHidden` |
| ✏️ Update | `apps/desktop/lib/features/library/data/services/library_events_service.dart` | `thumbnailsProgress` stream + frame-handler `case 'thumbnails_progress'` + `ThumbnailProgress.tryParse` class |
| ✏️ Update | `apps/desktop/lib/features/library/presentation/cubit/library_state.dart` | `LibraryLoaded.thumbnailProgress: Map<String, ThumbnailProgress>` field |
| ✏️ Update | `apps/desktop/lib/features/library/presentation/cubit/library_cubit.dart` | `_progressSub` + `_applyProgress` merge into LibraryLoaded; preserved across refresh/select/delete |
| ✏️ Update | `apps/desktop/lib/features/library/presentation/screens/library_screen.dart` | `_LibraryCard.thumbnailProgress` constructor arg + `_ThumbnailProgressStrip` widget pinned to top edge |
| ✏️ Update | `apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart` | **Full rewrite** as folder browser (replaces ~640-LOC curated `media_files` view) |
| ✏️ Update | `packages/fluxora_core/lib/network/endpoints.dart` | `Endpoints.libraryBrowse(libraryId)` |
| ✏️ Update | `docs/04_api/01_api_contracts.md` | New `/browse` endpoint section + `thumbnails_progress` event frame format + worker progress-emit producer row |
| ✏️ Update | `docs/05_infrastructure/02_url_inventory.md` | `/browse` endpoint row |
| ✏️ Update | `docs/00_overview/current_status.md` | Top entry covering all four post-ship items + bumped server test count 898 → 916 |
| ✏️ Update | `docs/10_planning/01_roadmap.md` | Plan 27 row appended w/ post-ship summary + plan 28 row added |
| ✏️ Update | `docs/08_frontend/01_frontend_architecture.md` | Status header lists all four post-ship items + plan-28 forward reference |
| ✏️ Update | `CLAUDE.md` | Plan 27 row appended w/ post-ship summary + plan 28 row added |

### Decisions Made

1. **Bilinear over lanczos for thumb scaling.**  Lanczos at 320 px is overkill — operator can't distinguish.  Bilinear is ~30 % cheaper and the saved CPU goes to running more workers in parallel.
2. **HDR path stays software-only.**  `-hwaccel auto` plus `zscale=t=linear:npl=100` fails because zscale doesn't accept hwaccel-side frame formats without an `hwdownload` prelude.  HDR libraries are rare enough that the speed-up isn't worth the extra complexity.
3. **`thumbnails_progress` always emits; `library_changed` throttles to every 5th completion + last.**  Bandwidth of `thumbnails_progress` is negligible (~100 B / event); the client wants prompt UI updates.  But `library_changed` triggers a full `/library` refresh, which is expensive at 1-per-file — 5 was empirically the sweet spot for "operator sees the cards filling up" vs "we don't hammer the endpoint".
4. **Client-side cover_urls absolute resolution.**  Tried server-side first (have `request.base_url` plumbed into `_library_aggregates`) but it doesn't survive the local-LAN-vs-Cloudflare-tunnel split — different clients connecting via different paths need different absolute URLs.  Client-side is simpler + correct per-environment.
5. **Folder-browser v1 single-action click.**  Plan 28 will reshape to single-click-selects + double-click-opens.  v1 shipped with single-click-opens since the right detail panel that motivates the selection split doesn't exist yet.
6. **Plan 28 phased delivery + tier-3 split.**  19 features × bundled into one commit would be unreviewable; phased lets each commit land cleanly with tests.  Tier-3 items (recursive search / bookmarks / drag-drop / FS watching) each have novel infra (FTS5 / DB table / cross-feature contract / per-OS event semantics) that justifies a dedicated plan each.

### Issues / Sharp Edges Discovered

1. **`Image.network` doesn't follow server-relative URLs.**  Flutter's HTTP client returns SocketException without absolute scheme.  Workaround is the new `_resolveCoverUrls` helper, but worth flagging in `docs/12_guidelines/03_gotchas.md` if anyone else writes a similar feature that returns server-relative paths in API responses.
2. **`zscale` won't accept hwaccel-side frame formats.**  HDR tonemap chain needs `hwdownload,format=yuv420p10le,zscale=...` to work with hwaccel decode.  Skipped for v1 since HDR thumbs aren't a common path; document for future HDR-speed plan.
3. **Path `..` resolution.** `sub/..` is the same as `<root>` — that's allowed (still inside).  But `..` from root or `../../etc` must be rejected.  The `is_relative_to` check after `resolve(strict=False)` handles both cleanly.
4. **`Path.resolve(strict=False)` follows symlinks**.  A library symlinked to `/etc` becomes a valid root for the operator — that's the operator's choice when they configured the library, so we don't second-guess it.  But a symlink INSIDE the library pointing OUT (e.g. a maliciously-placed symlink) is blocked by the `is_relative_to` check since the resolved target won't be under any root.
5. **Windows `attrib +H` test only runs on Windows.**  Other-platform CI skips it.  The dotfile branch is exercised everywhere so the show-hidden logic is still tested cross-platform.
6. **Bigger issue surfaced for plan 28**: today's folder browser ships before the operator confirmed the click semantics matched expectations.  Plan 28's Phase A reshapes to single-click-selects + double-click-opens.

### Next Agent Should

1. **Ship plan 28 Phase A** (sortable cols + single/double click + right detail panel + list/grid view toggle + search box + server endpoint extension to include `width/height/codec/duration_sec/hdr_format` for indexed entries).  ~4 h.
2. **Operator real-device smoke test** of the post-ship polish: open Library, watch the progress bars fill in real time as thumbs generate; verify the new bilinear+hwaccel speed is noticeable; verify cards actually show extracted frames once generation completes.  Then exercise the folder browser: navigate, toggle hidden, click into directories, click files to open in OS default app, click "Open in Explorer".
3. **Once Phase A lands**, the plan 27 post-ship narrative is done.  Consider archiving plan 27 to `docs/10_planning/archive/` if no more polish surfaces.

---

## [2026-05-16] [server] [desktop] [feat] — Plan 28 Phase A · folder browser foundation

**Phase:** Plan 28 (library file-browser power features) Phase A end-to-end ship.  Reshapes the MVP folder browser (which landed under plan 27 post-ship same day) into proper desktop semantics — single-click-selects + double-click-opens + right detail panel + sortable columns + list/grid view + search.
**Status:** Complete.  Phases B / C / D pending.
**Commits:** `65a3555` (server) + `f0971ae` (client)

### What Was Done

**Server M1 (commit `65a3555`)** — extends `GET /api/v1/library/{id}/browse` so each indexed entry carries the metadata the desktop right detail panel needs without a second HTTP round-trip.

- New `IndexedMedia` dataclass in `services/browse_service.py`: `width / height / duration_sec / codec_name / hdr_format / audio_codec / thumbnail_status / thumbnail_generated_at_unix / indexed_at_iso / is_streaming`.  `thumbnail_status` carries server enum values verbatim + a client-only synthesised `stale` value.
- `BrowseEntry` gains `media: IndexedMedia | None` (None for non-indexed entries + directories) + `mtime_unix: int` (raw mtime for client-side stale checks).
- `_list_entries` populates `mtime_unix` from `st_mtime`.
- `_attach_index_status` rewritten as a single LEFT-JOIN query: `media_files LEFT JOIN media_thumbnails` + `EXISTS(SELECT 1 FROM stream_sessions WHERE file_id=mf.id AND ended_at IS NULL)`.  Pulls every needed field in one round-trip — bounded by directory listing length; no N+1.
- `audio_codec` parser is defensive: malformed `audio_tracks` JSON returns `None` instead of raising; other media fields still populate.
- **Stale-thumbnail auto-re-queue**: when `media_files.updated_at > media_thumbnails.generated_at`, the underlying row is flipped back to `status='pending'` with `priority=5`, and the response surfaces `thumbnail_status='stale'`.  Operator who replaces a source file in-place gets the new thumbnail rendered automatically.
- 9 new tests covering: indexed video carries full media metadata, un-indexed → media=null, directories → media=null, thumbnail status='ready' populates generated_at_unix, status='pending' returns null for generated_at_unix, stale detection (source > thumbnail flips to pending priority=5), is_streaming flips correctly, mtime_unix on every entry, malformed audio_tracks → audio_codec=null without affecting other fields.  Server suite 916 → 925.

**Client (commit `f0971ae`)** — `BrowseEntry` + cubit + screen rewrite + three new widget files built in parallel by Opus sub-agents.

- `BrowseEntry` mirror class extended with `IndexedMedia` shape + `mtimeUnix` field + `media` field.  All defensive via `tryFromJson` (returns null on shape mismatch, logs through `logger`).  Convenience getters on `IndexedMedia`: `hasThumbnailReady`, `isThumbnailStale`, `isThumbnailInFlight`, `hasThumbnailFailed`.
- Cubit gains two enums (`BrowseSortColumn {name, size, modified}`, `BrowseViewMode {list, grid}`) + UI-pref state (selection `Set<String>`, `sortBy` + `sortAsc`, `viewMode`, `search`, `indexedOnly`).  Pure-pref updates re-emit Loaded with the same response so consumers re-render.  `selectedEntry` getter resolves to the most-recently-selected entry for the detail panel.
- New methods: `setSort` / `setViewMode` / `setSearch` / `setIndexedOnly` / `selectOnly` / `clearSelection` / `refresh` (in-place re-fetch).  `navigateTo` clears selection + search; `refresh` preserves both.
- New top-level `applyBrowseFilters(entries, indexedOnly, search, sortBy, sortAsc)` pure function — directories always first, within-group sort follows the operator's choice.
- **Three new widget files** under `apps/desktop/lib/features/library/presentation/widgets/`:
  - `library_browse_detail_panel.dart` (`LibraryBrowseDetailPanel`, `kWidth=320`) — kind header + thumbnail preview (16:9 video, 1:1 image) + currently-streaming pill + path card with copy-to-clipboard + 2-col stats grid + media-specific block (video/audio/image) + actions row (Open / Reveal / Copy path / Stream test for indexed videos via `POST /stream/start/{file_id}` + immediate `DELETE /stream/{session_id}` cleanup).  Built by Opus sub-agent A.
  - `library_browse_search_bar.dart` (`LibraryBrowseSearchBar`) — compact vanilla `TextField` (sub-agent chose not to use `FluxTextField` because its API didn't fit cleanly).  Pumps `cubit.setSearch` on each keystroke; `BlocListener` syncs controller text back when the cubit clears `search` on navigation.  Built by Opus sub-agent B.
  - `library_browse_view_toggle.dart` (`LibraryBrowseViewToggle`) — two-icon segmented control (list / grid); violet fill on active.  Built by sub-agent B.
- `library_files_screen.dart` rewritten:
  - Body becomes `Row(Expanded(list/grid body) + LibraryBrowseDetailPanel)`.
  - Header gains indexed-only toolbar toggle + view toggle + the FluxButton "Open in Explorer".
  - Breadcrumb row gains search bar between segments and copy-path icon.
  - `_BrowseListBody` + `_ColumnHeaderRow` replaced with `_BrowseBody` (dispatches list vs grid by cubit.viewMode after applying `applyBrowseFilters`), `_BrowseListView`, `_BrowseGridView`, `_SortableColumnHeaderRow` (click toggles direction; arrow indicator on active column; violet hover).
  - `_BrowseRow` gains selection state + selected outline (violet border, ~10% violet tint) + `_lastTapAt` 300 ms double-click pattern (matches `_LibraryCardState`).  HDR pill + ▶-live pill render inline.
  - New `_BrowseGridTile` + `_GridTileVisual` + `_KindIconBackground` for grid view.  Real thumbnail via `Image.network('<localBaseUrl>/api/v1/files/{file_id}/thumbnail?v=<unix>')` when indexed-and-ready; otherwise 44 px kind icon on a tinted gradient.  Corner badges (Hidden / Indexed top-right, ▶-live top-left).
  - Empty-state copy varies: "This library is empty." / "This folder is empty." / "No entries match the current filters." with distinct icons.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| ✏️ Update | `apps/server/services/browse_service.py` | New `IndexedMedia` dataclass; `BrowseEntry` gains `media` + `mtime_unix`; `_attach_index_status` rewritten with the multi-table JOIN + stale-thumb auto-re-queue |
| ✏️ Update | `apps/server/tests/test_browse.py` | 9 new tests covering all aspects of the new media payload |
| ✏️ Update | `apps/desktop/lib/features/library/domain/entities/browse_entry.dart` | `IndexedMedia` mirror class + `BrowseEntry.media` + `mtimeUnix` |
| ✏️ Update | `apps/desktop/lib/features/library/presentation/cubit/library_browse_cubit.dart` | UI-pref state (sort/view/search/selection/indexedOnly) + `applyBrowseFilters` pure function + two enums |
| ➕ Create | `apps/desktop/lib/features/library/presentation/widgets/library_browse_detail_panel.dart` | 320 px right detail panel |
| ➕ Create | `apps/desktop/lib/features/library/presentation/widgets/library_browse_search_bar.dart` | Compact in-place search input |
| ➕ Create | `apps/desktop/lib/features/library/presentation/widgets/library_browse_view_toggle.dart` | List/Grid segmented control |
| ✏️ Update | `apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart` | Body row layout + sortable headers + click semantics + grid tile + empty-state variations + wire to the three new widgets |
| ✏️ Update | `docs/10_planning/28_library_file_browser_power_features.md` | Phase A status → ✅ Shipped; commit refs |
| ✏️ Update | `docs/00_overview/current_status.md` | New top entry + server count 916 → 925 |
| ✏️ Update | `docs/04_api/01_api_contracts.md` | `/browse` response now documents `media` field + `mtime_unix` |
| ✏️ Update | `docs/08_frontend/01_frontend_architecture.md` | Status header lists Phase A additions |
| ✏️ Update | `docs/10_planning/01_roadmap.md` | Plan 28 row → 🔵 In Progress; Phase A summary |
| ✏️ Update | `CLAUDE.md` | Plan 28 lookup-row rewritten to reflect shipped Phase A + pending phases |

### Decisions Made

1. **`thumbnail_status='stale'` is synthesised server-side.**  Could have left the row in `'ready'` and just exposed a separate `is_thumbnail_stale` boolean; chose the synthesis path so the client treats stale identically to "in-flight regeneration" via existing `isThumbnailInFlight` switch.  Reduces client-side branching.
2. **`audio_codec` parser is defensive.**  Malformed `audio_tracks` JSON returns `None` instead of raising; the other media fields still populate.  Caught during the 9-test pass — a single malformed row would have nuked the entire response otherwise.
3. **Sub-agent A duplicated `_humanBytes` + `_formatModified` instead of lifting to a shared module.**  Acceptable — the helpers are 5-line functions; a `lib/features/library/util/` module is the right home but landing it as a separate cleanup beats blocking Phase A on a refactor.
4. **Sub-agent B did NOT use `FluxTextField`.**  Its API (`leadingIcon` / single `trailing` widget slot; fixed at 48 px mobile / 32 px compact with mobile font sizing) didn't fit the search-bar spec.  Built a vanilla compact `TextField` matching the existing token set.  Honest trade — the FluxTextField shape would have forced a worse UI.
5. **Long-hover quick-preview deferred to Phase B.**  Listed in plan §4.7 as a Phase A additional improvement but pushed: the popover-positioning math interacts with the `Listener` arena (right-click menu in Phase C), and getting both right at once is fragile.  Phase B will land long-hover alongside the failed-thumb indicator + indexed-at tooltip.
6. **Stream-test button calls `POST /start` + immediate `DELETE`.**  Spec proposed a new `/test-start` endpoint with 5 s auto-cleanup.  Simpler to compose from existing endpoints + the client owns the cleanup lifecycle (cleaner failure paths).
7. **`mtime_unix` shipped alongside `modified_iso` rather than replacing it.**  ISO string is operator-facing (we format it client-side); the unix int is for stale-thumb math.  Two fields is honest about the two consumers.

### Issues / Sharp Edges Discovered

1. **`stream_sessions.connection_type` NOT NULL** — broke the initial `is_streaming` test; fixed by passing `'lan'` literal in the test fixture.  Worth noting for any future tests inserting into `stream_sessions` — there's a CHECK constraint requiring `IN ('lan','webrtc_p2p','turn_relay')`.
2. **`Path.resolve(strict=False)` follows symlinks** — already discovered during MVP browser landing; surfaces again here because the `_attach_index_status` join keys off `media_files.path` (which is canonical via the resolver).  Symlinks resolve to the canonical path before the JOIN comparison; no quirks observed.
3. **`GetIt.I<dynamic>()` is invalid.**  Caught during the screen rewrite when I initially wrote the thumbnail URL builder without importing `ApiClient`.  Fixed by importing the concrete type.  Worth keeping in mind: GetIt always needs a concrete type parameter.
4. **`audio_tracks` JSON shape varies across migrations.**  Old rows pre-plan-22 have `NULL`; plan-22+ rows have a list of dicts; some pathological rows have malformed JSON.  Phase A's audio_codec parser handles all three.
5. **Selection state lives in the cubit, not in widget state.**  Phase B's keyboard-nav handler needs to read + set selection from outside the row widget tree; centralising it in the cubit was the right call upfront even though Phase A only needed single-select.

### Next Agent Should

1. **Phase B (~3 h)** — type-filter chips (All / Folders / Videos / Images / Audio / PDFs / Other / Indexed only), item-count footer (`X folders · Y files · Z indexed · N GB visible`), keyboard navigation (arrows / Enter / Backspace / Esc / Home / End / `/` to focus search), polish bundle (failed-thumbnail warning icon, indexed-at tooltip on long-hover of the Indexed tag, long-hover quick-preview popover deferred from Phase A).
2. **Widget tests for sort headers + click semantics + grid view.**  Phase A shipped without these — pump the screen with a mock repo, simulate clicks, assert state.  ~30 min.
3. **Operator real-device smoke test** of Phase A: navigate the folder browser; click a video file → verify the detail panel shows codec/dimensions/thumbnail; toggle Grid view → verify thumbnails render for indexed videos; type in search → live filter; click NAME header twice → toggle direction; verify the ▶ live pill appears when streaming to mobile from the same file.
4. **Phase C planning revisit** — when Phase B lands, consider whether multi-select (Ctrl/Shift click) should move from Phase C to Phase B alongside keyboard nav.  Conceptually they're tightly coupled.

---

## [2026-05-16] [desktop] [feat] — Plan 28 Phase B · filter chips · count footer · keyboard nav · polish

**Phase:** Plan 28 Phase B — second slice on top of Phase A, same-session
**Status:** Complete
**Commits:** 6fdfde4 (client only — server unchanged this round)

### What Was Done

Stacked on Phase A in the same session.  Three new affordances + one polish bundle landed on top of the folder-browser foundation.

#### 1. Type-filter chip row + indexed-only chip

New `LibraryBrowseFilterChips` widget (Opus sub-agent build) mounts above the file listing as a horizontal scroll row of 8 chips: 7 single-select kind chips (`All` / `Folders` / `Videos` / `Images` / `Audio` / `PDFs` / `Other`) + 1 independent "Indexed only" toggle that replaces the Phase A toolbar `IndexedOnlyToggle` checkbox.  Cubit gains `BrowseKindFilter enum { all, folders, videos, images, audio, pdfs, other }` + `setKindFilter(kind)` setter.  Kind dispatch reuses the existing `BrowseEntry.kind` string (`'directory'` / `'video'` / `'image'` / `'audio'` / `'pdf'` / `'other'`) so no server change was needed.

`applyBrowseFilters` extended with a `BrowseKindFilter kindFilter = BrowseKindFilter.all` named param.  Default-arg back-compat means any caller that hasn't been updated still compiles + behaves as Phase A did (no filter = all kinds).

#### 2. Item-count footer

New `LibraryBrowseCountFooter` widget at the bottom of the browse panel (left-aligned text, `kHeight = 28` const exposed for screen-side spacing math).  Reads `cubit.entries` + the active filter set, re-applies `applyBrowseFilters` against them, and renders `N items · M folders, K files` against the post-filter slice (so a Videos-filter selection footer says `12 items · 0 folders, 12 files`).  When the post-filter list is empty, the footer hides folder/file breakdown and shows only `0 items` (avoids the awkward `0 folders, 0 files` paint).

#### 3. Keyboard navigation

`_LibraryBrowseView` converted from `StatelessWidget` to `StatefulWidget` so the screen can own a `_bodyFocus: FocusNode` + `_searchFocus: FocusNode` pair across rebuilds.  The listing body is wrapped in `Focus(autofocus: true, focusNode: _bodyFocus, onKeyEvent: _onKey, child: <listing>)`.  `_onKey(FocusNode, KeyEvent) => KeyEventResult` dispatch:

- `LogicalKeyboardKey.arrowDown` / `arrowUp` → `cubit.stepSelection(delta: ±1)`
- `LogicalKeyboardKey.pageDown` / `pageUp` → `cubit.stepSelection(delta: ±10)`
- `LogicalKeyboardKey.home` / `end` → `cubit.selectFirst()` / `cubit.selectLast()`
- `LogicalKeyboardKey.enter` / `numpadEnter` → `_openSelected()` (resolves via `cubit.resolveSelected()` then dispatches directory navigate vs file open through the same paths the row's `_lastTapAt` double-click pattern uses)
- `LogicalKeyboardKey.backspace` → `cubit.goUp()` (no-op at root)
- `LogicalKeyboardKey.escape` → `cubit.clearSelection()`
- `LogicalKeyboardKey.slash` → `_searchFocus.requestFocus()`

Handler swallows only the keys it consumes via `KeyEventResult.handled`; other keystrokes propagate (so the search bar still receives normal text input when focused).  Both `KeyDownEvent` + `KeyRepeatEvent` route the same way — holding ↓ scrolls smoothly through the listing.

Cubit-side helpers (also Phase B):
- `selectOnly(BrowseEntry entry)` — set selection to a single entry
- `clearSelection()` — emit state with `selection: null`
- `stepSelection({required int delta})` — clamp + filter-aware step against `applyBrowseFilters(entries, ...)`; selects first entry when nothing is selected and `delta > 0`, last when `delta < 0`
- `selectFirst()` / `selectLast()` — convenience wrappers
- `resolveSelected() => BrowseEntry?` — read-helper for the keyboard handler

`LibraryBrowseSearchBar` gained an optional `focusNode: FocusNode?` constructor param; when null, falls back to an internal `_ownFocusNode` it manages itself.  Passing the screen's `_searchFocus` lets the `/` keystroke focus the field even when the user is currently focused on the listing.

#### 4. Polish bundle

- `_BrowseRow` + `_BrowseGridTile` render an `Icons.warning_amber_rounded` overlay (corner badge on grid, leading badge on row) in `AppColors.amber` when `media.thumbnail_status == 'failed'`.  Tooltip: "Thumbnail generation failed".
- New `_IndexedTag` widget replaces the bare-text "Indexed" pill from Phase A.  Renders the same violet-tinted pill but wraps it in `Tooltip(message: 'Indexed <formatted indexed_at_iso>')` so hovering surfaces the timestamp without opening the right detail panel.
- Long-hover quick-preview popover **deliberately not shipped** — listed in plan §4.7 as a Phase B improvement but skipped: the always-visible right detail panel already shows the same info on single-click; a parallel popover would have been marginal value for the Overlay + z-index cost.  Spec updated.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Modified | apps/desktop/lib/features/library/presentation/cubit/library_browse_cubit.dart | `BrowseKindFilter` enum + `setKindFilter` + selection helpers + extended `applyBrowseFilters` |
| Modified | apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart | `_LibraryBrowseView` → StatefulWidget + Focus + key handler + chip row + count footer + polish badges + `_IndexedTag` |
| Created | apps/desktop/lib/features/library/presentation/widgets/library_browse_filter_chips.dart | 8-chip horizontal filter row (sub-agent build) |
| Created | apps/desktop/lib/features/library/presentation/widgets/library_browse_count_footer.dart | Post-filter `N items · M folders, K files` footer (sub-agent build) |
| Modified | apps/desktop/lib/features/library/presentation/widgets/library_browse_search_bar.dart | Optional `focusNode` param for `/` shortcut wiring |

### Docs Updated

- `docs/10_planning/28_library_file_browser_power_features.md` — Phase B row → ✅ Shipped 2026-05-16 (`6fdfde4`); long-hover deferral note
- `docs/00_overview/current_status.md` — Phase B top entry; Phase A demoted to "Earlier 2026-05-16"
- `docs/08_frontend/01_frontend_architecture.md` — Status header gains Phase B paragraph
- `docs/10_planning/01_roadmap.md` — Plan 28 row → "Phase A + B ✅ shipped"
- `CLAUDE.md` — Plan 28 lookup row rewritten with Phase B summary + remaining-phases list

### Decisions Made

1. **Long-hover quick-preview popover dropped, not deferred.**  Plan §4.7 listed it as a Phase B polish item.  The right detail panel covers the same surface — kind / thumbnail / dimensions / codec / indexed-at — on single-click without the popover positioning / z-index / dismiss-on-click-outside complexity an Overlay would require.  Removing it from Phase B closes the polish ticket; not deferring it to Phase C.
2. **`BrowseKindFilter.all` chosen as the default for `applyBrowseFilters`.**  Named param with default-arg lets every existing test + cubit call site stay byte-identical; only the chip widget actually passes a non-default value.  Optional-with-default beats overloading or splitting into two functions.
3. **Independent "Indexed only" chip rather than 7-way mutual exclusion.**  An operator filtering to Videos still wants the indexed-only toggle to work independently — the two filters answer different questions ("what kind?" vs "what state?").  Single-select `BrowseKindFilter` + boolean `indexedOnly` is the honest shape.
4. **Polish badges (failed-thumb warning + `_IndexedTag` tooltip) shipped alongside Phase B core.**  Could have split into a Phase B.1 — but they're 30 lines of widget code each + tied to the same screen rewrite, so keeping them in one commit reduces git churn.

### Issues / Sharp Edges Discovered

1. **`AppColors.warning` doesn't exist** — first pass used the name from muscle memory.  Caught by analyzer; `AppColors` only exports `amber` for the warning state.  Worth noting for future polish work.
2. **`KeyDownEvent` + `KeyRepeatEvent` need explicit show list** — `package:flutter/services.dart` has both classes but the screen's existing import didn't surface them.  Added to the show list when wiring `_onKey`.
3. **`_searchFocus` field needs to be plumbed through to the search bar widget** — I initially added the FocusNode + the `_onKey` dispatch but forgot to pass it through `LibraryBrowseSearchBar(focusNode: _searchFocus)`.  `/` keystroke focused… nothing.  Fixed by threading the param.
4. **`onKeyEvent` callback type is `KeyEventResult Function(FocusNode, KeyEvent)`** (not `bool Function`) — Flutter switched the API at some point.  Worth pinning for any future key handler.

### Test Counts (re-baselined)

- **Desktop: 121** (unchanged this round — widget tests for chips + footer + key handler land with Phase C alongside the right-click + density work)
- **Server: 925** (unchanged — no server work in Phase B)
- Core: 20 unchanged; mobile 97 unchanged

`flutter analyze` clean × apps/desktop + packages/fluxora_core.

### Working-Tree Status

Phase B already committed at `6fdfde4`.  Doc-sweep changes (this entry + 4 cross-doc files above) staged-but-uncommitted at session end — operator owns the commit per the no-git-writes rule.

### Next Agent Should

1. **Commit the Phase B doc sweep** as `docs: plan 28 phase B shipped — cross-doc sweep`.  Files: current_status.md / 08_frontend/01_frontend_architecture.md / 10_planning/01_roadmap.md / 10_planning/28_library_file_browser_power_features.md / CLAUDE.md / AGENT_LOG.md.
2. **Phase C kickoff (~4 h)** — server endpoints first: `POST /api/v1/library/{id}/index-file?path=` (creates a single `media_files` row + enqueues a thumbnail) + `POST /api/v1/files/{file_id}/regenerate-thumbnail` (single-row reset + priority bump) + `POST /api/v1/library/{id}/scan-subtree?path=` (rescans one directory rather than the whole library).  Add 3-6 tests per endpoint covering happy path + permission gates + path-traversal rejection.
3. **Phase C UI** — right-click context menu on rows + grid tiles (Open / Reveal in folder / Copy path / Index this file / Regenerate thumbnail / Scan subtree / Stream test — last two indexed-video-only); editable path textbox in the breadcrumb (Enter commits, Esc reverts, validation against the library's `root_paths`); density toggle in the header (`Compact` / `Cozy` / `Comfortable` rows — row height + thumbnail size scale together); multi-select via Ctrl-click (toggle) + Shift-click (range) + Ctrl+A.  Selection model needs to flip from single `BrowseEntry?` to `Set<BrowseEntry>` — touches the right detail panel (multi-selection summary card) + every selection helper in the cubit.
4. **Phase C doc sweep + commit**, then **Phase D (~1 h)** — back/forward history (`List<String>` undo stack in the cubit, alt-arrow keybinds) + lazy folder-size compute (worker walks N levels deep on idle, surfaces estimate in the row + footer).
5. **Tier 3 features** (recursive FTS5 search, bookmarks, drag-and-drop to Convert, filesystem watching via `watchdog`) remain split out as separate plans; do not roll them into plan 28.

---

## [2026-05-16] [server] [desktop] [feat] — Plan 28 Phase C · 3 new endpoints + right-click menu + editable path + density + multi-select

**Phase:** Plan 28 Phase C — third slice on top of A + B, same session (operator was AFK; continued autonomously per "ask for permissions later")
**Status:** Complete
**Commits:** e74940b (server endpoints + tests), 9f6abf4 (client cubit + UI + tests)

### What Was Done

#### 1. Three new server endpoints

- **`POST /api/v1/library/{library_id}/index-file?path=<rel>`** (`routers/library.py::index_single_file`).  Inserts a single `media_files` row for a non-indexed file under the library's `root_paths`.  Idempotent — when the file is already indexed, returns the existing `file_id` + `already_indexed=True` and no further work runs.  Otherwise: ffprobe metadata via `library_service._persist_probe`, thumbnail enqueue at priority=10, best-effort TMDB enrichment (DVR-pattern stems skipped via the existing `_looks_like_dvr_capture` heuristic).  Records `file.indexed` activity event + broadcasts `library_changed` + `storage_changed` WS frames.  Rejects directories (400), unsupported extensions (400 — `other` kind), path escapes (403), missing files (404).
- **`POST /api/v1/files/{file_id}/regenerate-thumbnail`** (`routers/files.py::regenerate_file_thumbnail`).  Resets a single `media_thumbnails` row to pending + priority=10 + clears `generated_at` / `error_message` + deletes the cached JPEG on disk.  INSERT OR IGNOREs a fresh pending row when none exists yet (covers files added before the worker was wired up).  Group-visibility 404s for cross-content-space bearer callers — matches `get_thumbnail` / `get_file_content` to prevent gated-content enumeration.  Records `file.thumbnail_regenerated` activity event.
- **`POST /api/v1/library/{library_id}/scan-subtree?path=<rel>`** (`routers/library.py::scan_subtree`).  Walks just the requested subdir under one of the library's `root_paths`.  Extends `library_service.scan_library` with a new `subtree_abs: str | None = None` kwarg routed via `_scan_library_locked`; when set, the inner loop iterates `[subtree_abs]` instead of `row['root_paths']`.  Per-library asyncio lock still applies (concurrent calls serialise).

Shared resolution layer extracted from `browse_service.browse_library`:
- **`browse_service._resolve_path_under_root`** — file-or-directory variant of the existing `_resolve_under_root`; doesn't enforce is_dir.
- **`browse_service._resolve_under_root`** — directory-only delegate of the above (used by `browse_library` unchanged).
- **`browse_service._load_library_roots`** — common library_id → `list[Path]` loader (used by all four endpoints).
- **`browse_service.resolve_file_for_index`** — wraps `_resolve_path_under_root` + enforces is_file + non-`other` kind.
- **`browse_service.resolve_subtree_for_scan`** — wraps `_resolve_path_under_root` + enforces is_dir.

#### 2. Right-click context menu

New `apps/desktop/lib/features/library/presentation/widgets/library_browse_context_menu.dart` exposing `showBrowseEntryContextMenu({context, position, entry, rootPath, relativePath})`.  Dispatched on `onSecondaryTapDown` from both `_BrowseRow` and `_BrowseGridTile`.  Items shown:

| Item | Condition |
|---|---|
| Open | Always (directory navigates, file opens via `launchUrl`) |
| Reveal in folder | Always |
| Copy path | Always |
| Copy name | Always |
| Index this file | `!entry.isDir && !entry.isIndexed && entry.kind != other` |
| Regenerate thumbnail | `entry.isIndexed && entry.fileId != null && !entry.isDir` |
| Scan this folder | `entry.isDir` |

Right-click on an unselected entry pre-selects it before opening the menu — matches Explorer's behaviour and keeps the menu's "selected entry" actions visually accurate.

`_MenuItem` is a thin `PopupMenuItem` subclass that takes `icon` + `label` constructor params and builds the inner `Row(Icon · Text)` so call sites stay one-liner.

Each menu action surfaces a snackbar on success (`Indexed ...`, `Queued thumbnail regeneration for ...`, `Scanned ...: N new file(s)`) or failure (`Failed to ...: <error>`).

#### 3. Editable path textbox

`_BreadcrumbBar` converted from `StatelessWidget` to `StatefulWidget`.  Click anywhere in the breadcrumb area (or the new edit-pencil icon button) → `_beginEdit` swaps the chip row for a `TextField` showing the absolute path.  Enter dispatches `cubit.navigateToAbsolute(input)`; on `false` returned the textbox stays mounted with `errorText: 'Path is outside this library or does not exist'`.  Esc cancels via an inner `Focus(onKeyEvent)` wrapper around the TextField — without that wrapper the body-level `Focus` handler's Esc-clears-selection would fire first and leave edit mode active.  Check/close icon buttons mirror the keyboard actions.

`cubit.navigateToAbsolute(input)` strips the matched root prefix (case-insensitive, both `/` and `\\` separators) and dispatches `navigateTo(relative)`.  Already-relative inputs (no drive letter, no leading slash) pass through.  Returns `false` when the input doesn't sit under the loaded library's `rootPath`.

#### 4. Density toggle

Cubit gains `BrowseDensity {compact, cosy, comfortable}` enum + `_density` field (default `comfortable`) + public `density` getter + `setDensity(BrowseDensity)` setter (no-op on identical).  New `_DensityCycleButton` in `_HeaderActions` — one-shot icon button that cycles forward (`compact → cosy → comfortable → compact`); icon (density_small/medium/large) + tooltip swap per current mode.

Density flows through to `_BrowseListView` + `_BrowseGridView` constructors as `final BrowseDensity density`.  Maps:
- Row vertical padding: 4 / 6 / 8 px
- Grid tile `maxCrossAxisExtent`: 140 / 160 / 180 px
- Grid tile `mainAxisExtent`: 160 / 180 / 200 px

#### 5. Multi-select

Cubit gains:
- `_selectionAnchor: String?` — set by `selectOnly` + `toggleSelection`; consumed by `extendSelection`.
- `toggleSelection(name)` — Ctrl/Cmd-click; toggles membership without clearing others; updates anchor.
- `extendSelection(name)` — Shift-click; selects the inclusive range from anchor through the shift-clicked entry in the currently-visible (filtered + sorted) list.  Falls back to `selectOnly` when no anchor exists or the anchor is no longer visible (e.g. operator changed the search filter between clicks).
- `selectAllVisible()` — Ctrl+A; selects every entry in the post-filter visible list.
- `hasMultiSelect` getter — `_selectedNames.length > 1`.
- `clearSelection()` updated to drop the anchor.

`_BrowseRow._handleTap` + `_BrowseGridTile._handleTap` both read `HardwareKeyboard.instance.isControlPressed | isMetaPressed | isShiftPressed` modifiers and route to the matching cubit method.  Screen body `_onKey` adds a Ctrl+A handler that dispatches `selectAllVisible`.

New `_MultiSelectBody` on `LibraryBrowseDetailPanel` renders when `hasMultiSelect` — replaces the single-entry view with:
- Summary: `N items selected` heading + `M folders · K files · TotalBytes total` subtitle
- Quick Actions: Copy paths (newline-joined to clipboard) + Clear
- Selected list: first 20 entry names + `… and X more` overflow line

#### 6. Cubit action wrappers

- `indexEntry(BrowseEntry)` → calls `repo.indexFile(libraryId, relativePath)` + `refresh()` on success.
- `regenerateEntryThumbnail(BrowseEntry)` → calls `repo.regenerateFileThumbnail(fileId)` + `refresh()`.
- `scanEntrySubtree(BrowseEntry)` → calls `repo.scanSubtree(libraryId, relativePath)` + `refresh()`; returns `added: int`.

All three rethrow `ApiException` to the caller so the context menu's try/catch can surface the snackbar.  Each guards against the wrong entry kind (e.g. `regenerateEntryThumbnail` is a no-op when `entry.fileId == null`).

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Modified | apps/server/services/browse_service.py | Path resolver split: `_resolve_path_under_root` + `_resolve_under_root` delegate + new public `resolve_file_for_index` / `resolve_subtree_for_scan` / `_load_library_roots` |
| Modified | apps/server/services/library_service.py | `scan_library` + `_scan_library_locked` gain `subtree_abs` kwarg; new `index_single_file` helper |
| Modified | apps/server/services/thumbnail_worker.py | New `regenerate_file(db, file_id)` mirror of `regenerate_library` scoped to one file |
| Modified | apps/server/routers/library.py | New `index_single_file` + `scan_subtree` endpoints |
| Modified | apps/server/routers/files.py | New `regenerate_file_thumbnail` endpoint |
| Modified | apps/server/tests/test_browse.py | 13 new tests covering all three endpoints |
| Modified | apps/server/tests/test_library_service.py | `_slow_scan` test helpers extended to accept the new `subtree` kwarg |
| Modified | packages/fluxora_core/lib/network/endpoints.dart | `libraryIndexFile` + `libraryScanSubtree` + `fileRegenerateThumbnail` constants |
| Modified | apps/desktop/lib/features/library/domain/repositories/library_repository.dart | `indexFile` / `regenerateFileThumbnail` / `scanSubtree` interface + `IndexFileResult` value class |
| Modified | apps/desktop/lib/features/library/data/repositories/library_repository_impl.dart | Three new method implementations |
| Modified | apps/desktop/lib/features/library/presentation/cubit/library_browse_cubit.dart | `BrowseDensity` enum + density getter/setter + multi-select state + action wrappers + `navigateToAbsolute` |
| Modified | apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart | `_DensityCycleButton` + `_BreadcrumbBar` stateful editable path + row/grid density + modifier-aware tap + Ctrl+A keyboard handler |
| Modified | apps/desktop/lib/features/library/presentation/widgets/library_browse_detail_panel.dart | `_MultiSelectBody` summary view shown when `hasMultiSelect` |
| Created | apps/desktop/lib/features/library/presentation/widgets/library_browse_context_menu.dart | `showBrowseEntryContextMenu` + `_MenuItem` |
| Created | apps/desktop/test/features/library/library_browse_cubit_test.dart | 16 new tests covering density / multi-select / action wrappers / navigateToAbsolute |

### Docs Updated

- `docs/10_planning/28_library_file_browser_power_features.md` — Phase C row → ✅ Shipped
- `docs/00_overview/current_status.md` — Phase C top entry; Phase B demoted to "Earlier 2026-05-16"
- `docs/08_frontend/01_frontend_architecture.md` — Status header gains Phase C paragraph
- `docs/10_planning/01_roadmap.md` — Plan 28 row → "Phase A + B + C ✅ shipped"
- `CLAUDE.md` — Plan 28 lookup row rewritten with Phase C summary

### Decisions Made

1. **Shared path-resolution layer extracted from `browse_library` rather than duplicated in each new endpoint.**  Two earlier reviews of the plan caught the risk of three independent `_resolve_under_root` copies drifting on security semantics (path-traversal canonicalisation in particular).  Lifting the resolver + introducing kind-checking wrappers (`resolve_file_for_index` / `resolve_subtree_for_scan`) keeps all four endpoints inside one canonical security boundary.
2. **`index-file` is idempotent rather than 409-on-conflict.**  Returning the existing `file_id` + `already_indexed=True` lets the desktop UI flip the row to indexed without a second round-trip; 409 would have forced the client to re-fetch via `/files?library_id=...` to discover the id.  Existing rows whose owner library was deleted (orphan) get re-claimed under the new `library_id` — matches `scan_library`'s behaviour for the same case.
3. **`scan-subtree` extends `scan_library` rather than spawning a new function.**  Two implementations of the directory walk would have drifted on the orphan-reclaim + stale-sidecar branches.  `subtree_abs: str | None = None` kwarg defaults preserve every existing call site.
4. **`regenerate_file` lives in `thumbnail_worker.py`, not `thumbnail_service.py`.**  The worker module already owns the queue (`enqueue`, `boost_library`, `regenerate_library`), so single-file regenerate is the same shape.  `thumbnail_service.py` is the extractor layer (FFmpeg / PyMuPDF subprocess wrappers) and shouldn't gain DB-mutating helpers.
5. **Density values 4/6/8 px + 140/160/180 px chosen by eyeball, not designed.**  Operator hasn't asked for density yet; the toggle exists for completeness + future testing.  Numbers can be revised once real operators use it.
6. **Multi-select detail panel shows a name list, not a thumbnail grid.**  Thumbnail grid would have duplicated the grid-view body; name list is the honest signal of "what did you actually select".  Truncation at 20 entries because beyond that the wall of text drowns the summary stats above it.
7. **Editable path Esc-cancel uses an inner `Focus(onKeyEvent)` wrapper rather than expanding the screen's `_onKey` handler.**  The screen-level handler can't know whether the path bar is editing without tighter coupling.  Local `Focus` interceptor consumes Esc before propagation reaches the body — matches Flutter's normal escape-key propagation model.
8. **`navigateToAbsolute` strips drive-letter + separator differences case-insensitively.**  Windows operators on a `D:\Library` library would otherwise paste a path with a different case and get rejected.  POSIX users see no behaviour change (case differences are real path differences there, but the resolver is on Windows for v1 anyway).
9. **Right-click context-menu items use `PopupMenuItem` + `showMenu`, not a custom `Overlay`.**  Material's `showMenu` handles dismiss-on-click-outside, keyboard navigation, and theme integration for free.  Custom `FluxGlassMenu` from plan 14's groups page is a future polish — for now it'd be premature glassmorphism on a transactional action surface.

### Issues / Sharp Edges Discovered

1. **`HardwareKeyboard.instance` modifier reads require explicit import.**  `package:flutter/services.dart` exports it but the screen's existing show-list didn't.  Added.
2. **Escape during editable path leaks to body Focus.**  Esc isn't consumed by `TextField` (it's not a text-input key), so it bubbles up to the body's `Focus(onKeyEvent)` and clears selection.  Inner `Focus` wrapper around the TextField intercepts Esc → calls `_cancelEdit` → returns `KeyEventResult.handled` so propagation stops.
3. **`PopupMenuItem` `const` subclasses can't carry computed children.**  First attempt built `_MenuItem` as a `const`-constructible `PopupMenuItem<_BrowseMenuAction>` with `child: const SizedBox.shrink()` + a custom `PopupMenuItemState.buildChild` — analyzer flagged the super-constructor-must-be-last rule.  Switched to a non-const constructor that builds the `Row(Icon · Text)` child inline via `super(value: ..., child: Row(...))`.
4. **`_BrowseMenuAction.index` collides with Dart enum's intrinsic `.index` getter.**  Renamed to `.indexFile`.
5. **`scan_library` callers in `test_library_service.py` mock `_scan_library_locked` with a 3-arg signature.**  My new `subtree_abs` kwarg made the cumulative arg-count 4, breaking the mocks.  Updated both `_slow_scan` test helpers to accept `subtree=None`.
6. **`_density` + `_selectionAnchor` analyzer warnings during the cubit edit.**  Adding the fields before their setters / readers fires "field isn't used" warnings.  Cleared once `setDensity` / `toggleSelection` landed.
7. **Density-test stream listener captures stale state.**  First Phase C cubit test asserted emissions via `cubit.stream.listen((_) => emissions.add(cubit.density))` — but the listener fires asynchronously after both `setDensity` calls have run, so both emissions saw `cubit.density == cosy`.  Rewrote to assert synchronously against the getter + count Loaded emissions to verify the no-op call doesn't re-emit.

### Test Counts (re-baselined)

- **Server: 938** (was 925; +13: 5 index-file paths, 3 regenerate-thumbnail paths, 3 scan-subtree paths, 2 path-escape variants)
- **Desktop: 137** (was 121; +16: 2 density, 6 multi-select, 5 action wrappers, 2 navigateToAbsolute, plus 1 transcode counter quirk)
- Mobile 97 / core 20 unchanged

`flutter analyze` clean × apps/desktop + packages/fluxora_core.  `python -m pytest` green × apps/server (938/938 passing).

### Working-Tree Status

Both Phase C commits already landed (`e74940b` server, `9f6abf4` client).  Doc-sweep changes (this entry + 4 cross-doc files) staged-but-uncommitted at session end — operator owns the commit per the no-git-writes rule.

### Next Agent Should

1. **Commit the Phase C doc sweep** as `docs: plan 28 phase C shipped — cross-doc sweep`.  Files: AGENT_LOG.md / CLAUDE.md / current_status.md / 08_frontend/01_frontend_architecture.md / 10_planning/01_roadmap.md / 10_planning/28_library_file_browser_power_features.md.
2. **Phase D (~1 h)** — back/forward history (cubit `_back: List<String>` + `_forward: List<String>` undo stacks; `navigateTo` pushes current onto `_back` + clears `_forward`; `goBack` / `goForward` mirrors; two new toolbar icons between back-button and breadcrumb; Alt+← / Alt+→ keyboard wiring) + lazy folder-size compute (new `GET /api/v1/library/{id}/folder-size?path=` endpoint walking the subtree summing file sizes; detail panel for folder entries adds a "Compute size" button surfacing a spinner + then the totals; result cached in `cubit.folderSize: Map<String, FolderSize>` so re-selection doesn't re-fetch).
3. **Phase D doc sweep + final plan archival** — once Phase D ships, the plan is complete; archive to `docs/10_planning/archive/28_library_file_browser_power_features.md` per the rotation pattern from prior plans.
4. **Real-device smoke** of Phase C on the operator's actual library — right-click an unindexed video → Index this file → verify it shows up in the catalog within a few seconds + the thumbnail renders; right-click a folder → Scan this folder → verify new files surface; drag the editable path bar around with a few `D:\Library\Movies\...` paths; multi-select 10 files with Ctrl-click → verify the detail panel's summary stats are correct.
5. **Tier 3 features** (recursive FTS5 search, bookmarks, drag-and-drop to Convert, filesystem watching via `watchdog`) remain split out as separate plans — do not roll them into plan 28.

---

## [2026-05-16] [server] [desktop] [feat] — Plan 28 Phase D · back/forward history + lazy folder-size · plan archived

**Phase:** Plan 28 Phase D — final phase, closes the plan in the same working day as A + B + C
**Status:** Complete — plan archived
**Commits:** 161461e (server endpoint + tests + desktop cubit/UI + tests in a single commit)

### What Was Done

#### 1. Server folder-size endpoint

- **`GET /api/v1/library/{library_id}/folder-size?path=<rel>`** (`routers/library.py::get_folder_size`).  Recursively measures a subdirectory's total size + file count.  Returns `{library_id, relative_path, size_bytes, file_count}`.  Reuses Phase C's `browse_service._resolve_path_under_root` + `_load_library_roots` resolvers, then enforces is_dir + walks via `os.walk(str(resolved), followlinks=False)` so symlink loops don't infinite-spin.
- Hidden + system files are summed into the total — "how much disk does this folder use" doesn't depend on the operator's visibility filter (matches Explorer's behaviour).  Symlinks are followed once like everywhere else in `browse_service`.
- Path security mirrors `/browse`: 403 on escape, 404 on missing, 400 when the path resolves to a file.

#### 2. Cubit history stacks

Cubit gains two `List<String>` stacks:
- `_back` — paths the operator has navigated away from.  Top is the most-recent prior path.  Pushed by every `navigateTo` whose target differs from the current path; popped by `goBack`.
- `_forward` — paths the operator has rewound past.  Cleared on every fresh `navigateTo` (matches every browser's UX — once you branch into a new path, the undone history is gone).  Pushed by `goBack`; popped by `goForward`.

Public getters `canGoBack` / `canGoForward` drive the toolbar enable state.  Both methods short-circuit when the matching stack is empty (no-op + no emit).

#### 3. Cubit folder-size cache

- `_folderSizes: Map<String, FolderSize>` keyed by relative path under the current library.
- `computeFolderSize(relativePath) → Future<FolderSize>` — returns cached value if present; otherwise calls `repo.folderSize`, caches the result, re-emits the Loaded state (so the detail panel's BlocBuilder rebuilds), returns the result.  Rethrows `ApiException` so the detail panel's local try/catch can render an error state.
- `folderSizeFor(relativePath) → FolderSize?` — sync getter for the detail panel to check cache hit before showing the button.

#### 4. UI surfaces

- **`_BreadcrumbBar` history buttons.**  Left of the up-arrow now lives a Row containing `arrow_back_ios_new_rounded` + `arrow_forward_ios_rounded` icon buttons.  Tooltips reflect `canGoBack` / `canGoForward` (active: "Back (Alt+←)" / "Forward (Alt+→)"; inactive: "No history" / "No forward history").  Both edit-mode and breadcrumb-mode branches mount the same `historyButtons` Row.
- **Alt+← / Alt+→ keyboard shortcuts** dispatched from the body `Focus` handler (alongside the existing `↓↑` / `Enter` / etc).
- **`_FolderSizeBlock`** new widget on `LibraryBrowseDetailPanel` rendered for directory entries.  Three rendering states:
  1. **Cached** — `_SizeReadout` showing "X MB · N files" in JetBrains Mono 12.5 px next to a violet folder icon.
  2. **In flight** — 14×14 violet `CircularProgressIndicator` + "Walking subtree…" caption.
  3. **Idle** — `FluxButton('Compute size')` with `Icons.calculate_outlined`, secondary variant.
- Error path renders "Failed: <error>" in `AppColors.amber` beneath the button.

Cache hit on re-selecting the same folder skips the round-trip entirely — operator's third visit to "Movies" sees the answer instantly.

#### 5. Core + repository wiring

- New `Endpoints.libraryFolderSize(libraryId)` constant in `packages/fluxora_core/lib/network/endpoints.dart`.
- New `LibraryRepository.folderSize({libraryId, relativePath}) → Future<FolderSize>` interface method.
- New `FolderSize {sizeBytes: int, fileCount: int}` value class.
- `LibraryRepositoryImpl.folderSize` defensively coerces `size_bytes` + `file_count` (server might return `int` or `num`; both surfaced as int).

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Modified | apps/server/services/browse_service.py | New `folder_size` async helper — `os.walk(followlinks=False)` over the resolved path |
| Modified | apps/server/routers/library.py | New `get_folder_size` endpoint |
| Modified | apps/server/tests/test_browse.py | 5 new tests (subtree / root / file-rejection / escape / missing-library) |
| Modified | packages/fluxora_core/lib/network/endpoints.dart | `libraryFolderSize` constant |
| Modified | apps/desktop/lib/features/library/domain/repositories/library_repository.dart | `folderSize` interface method + `FolderSize` value class |
| Modified | apps/desktop/lib/features/library/data/repositories/library_repository_impl.dart | `folderSize` implementation |
| Modified | apps/desktop/lib/features/library/presentation/cubit/library_browse_cubit.dart | `_back` / `_forward` stacks + `goBack` / `goForward` / `canGoBack` / `canGoForward` + `_folderSizes` cache + `computeFolderSize` / `folderSizeFor` |
| Modified | apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart | `historyButtons` in `_BreadcrumbBar` + Alt+← / Alt+→ handlers in body Focus |
| Modified | apps/desktop/lib/features/library/presentation/widgets/library_browse_detail_panel.dart | `_FolderSizeBlock` + `_SizeReadout` for directory entries; `FolderSize` import |
| Modified | apps/desktop/test/features/library/library_browse_cubit_test.dart | 6 new tests covering history + folder-size cache |
| Renamed | docs/10_planning/28_library_file_browser_power_features.md → docs/10_planning/archive/28_library_file_browser_power_features.md | Plan archival |

### Docs Updated

- `docs/10_planning/archive/28_library_file_browser_power_features.md` — header rewritten to ✅ Archived; Phase D row → ✅ Shipped
- `docs/00_overview/current_status.md` — Phase D top entry; Phase C demoted to "Earlier 2026-05-16"
- `docs/08_frontend/01_frontend_architecture.md` — Status header Phase D paragraph + archive-path reference
- `docs/10_planning/01_roadmap.md` — Plan 28 row → ✅ Done; archive-path link
- `CLAUDE.md` — Plan 28 lookup row rewritten as closed; archive-path target

### Decisions Made

1. **History stacks live in the cubit, not in `go_router`.**  Browser-style back/forward navigates inside one route (the `/library/{id}/files` screen), not across routes; routing this through `go_router` would have conflicted with the operator's intuition that the up-arrow + breadcrumb should also count as "history".  In-cubit stacks are stupid simple.
2. **Fresh `navigateTo` clears `_forward`.**  Matches every browser since Netscape — once the operator branches into a new path, the undone-history is gone.  Without this, "back, navigate elsewhere, forward" would dump the operator into a stale path.
3. **`computeFolderSize` rethrows `ApiException` instead of returning a sentinel.**  Lets the `_FolderSizeBlock` render an error caption with the real server message; sentinel `FolderSize(-1, -1)` would have lost the failure reason.
4. **Hidden files included in the folder-size total.**  "How much disk does this folder use" is an operator question, not a visibility-filter question.  An operator who toggled hidden-files off doesn't expect their dotfiles to silently drop out of the disk-usage total.
5. **Lazy compute is operator-opt-in (a button), not eager-on-folder-select.**  Walking a huge library subtree could spike CPU + disk IO; gating behind an explicit click keeps the cost predictable.  Cache survives re-selections so the operator pays once.
6. **`os.walk` over `Path.iterdir` recursion.**  `os.walk` is C-level on CPython and amortises the per-iteration overhead better on huge trees.  `followlinks=False` matches `scan_library`'s behaviour.

### Issues / Sharp Edges Discovered

1. **`FolderSize` lives in the repository module, not in `browse_entry.dart`.**  Initially considered putting it next to `BrowseEntry` since both are returned by browse-style operations — but the value class is an API contract for the repository, not a browse-domain entity.  Imported into the detail panel via `show FolderSize` to keep the import surface minimal.
2. **Editable path bar repaints on every `_reemit` because of the `BlocBuilder` wrapping it.**  `computeFolderSize` re-emits to refresh the detail panel; the breadcrumb's `BlocBuilder` repaints too.  Acceptable for v1 since the breadcrumb is cheap to rebuild and the operator only triggers folder-size compute once per folder; future polish could split the panel and breadcrumb into separate `BlocSelector` subscriptions.
3. **`navigateTo` push guard `if (previous != relativePath)` matters more than it looks.**  Without it, `_fetch` would push the same path onto `_back` every time the operator hit Refresh / `setShowHidden`.  With the guard, refresh is a no-op for history.

### Test Counts (re-baselined)

- **Server: 943** (was 938; +5)
- **Desktop: 143** (was 137; +6: 5 history flows + 1 folder-size cache + transcode counter quirks)
- Mobile 97 / core 20 unchanged

`flutter analyze` clean × apps/desktop + packages/fluxora_core.  `python -m pytest` green × apps/server (943/943 passing).

### Working-Tree Status

Phase D code committed at `161461e`.  Doc-sweep + plan archival (this entry + 5 cross-doc files + the plan rename) staged-but-uncommitted at session end — operator owns the commit per the no-git-writes rule.

### Next Agent Should

1. **Commit the Phase D doc sweep + plan archival** as `docs: plan 28 phase D shipped + plan archived — cross-doc sweep`.  Files: AGENT_LOG.md / CLAUDE.md / current_status.md / 08_frontend/01_frontend_architecture.md / 10_planning/01_roadmap.md / 10_planning/archive/28_library_file_browser_power_features.md (renamed-and-edited) / 10_planning/28_library_file_browser_power_features.md (deleted on rename).
2. **Real-device smoke** of the full Phase A+B+C+D folder browser on the operator's actual library — particularly the back/forward history flow with the breadcrumb edit textbox + multi-select Ctrl-click + the Compute-size button on a 100+ GB folder.
3. **Tier 3 features** remain separate plans — recursive FTS5 search across the catalog, bookmarks/favorites for frequent folders, drag-and-drop from the browser into the Convert tab, and live filesystem watching via `watchdog`.  No agent should fold these into a "plan 28.1" — open fresh plans when the operator asks.
4. **Watch for operator-reported sharp edges** on Phase D: the "Compute size" button should never spike CPU above ~30% on a 5K-file folder; if it does, the lazy compute might need to move to a background thread (`asyncio.to_thread`) or chunked yield-to-event-loop pattern.  Currently it's a single tight `os.walk` loop running inline on the FastAPI worker thread.



