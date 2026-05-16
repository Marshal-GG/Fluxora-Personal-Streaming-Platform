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
