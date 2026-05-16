# Desktop Control Panel — Information Architecture Redesign

> **Category:** Planning
> **Status:** ✅ Shipped 2026-05-15 (M1–M5) · refined 2026-05-16 (tab reshape + IndexedStack + singleton cubits + WS push refresh).  Plan kept open until v1.1 back-compat redirect cleanup.
> **Scope:** Collapse the desktop Control Panel's nav rail from 10 top-level items to 7 by folding two overlap pairs into tabbed pages.  `Transcode` (sidecar conversion queue) merges into `Library` as the `Convert` tab; `Logs` merges into `Activity` as a sibling tab.  **`Transcoding` (live stream-session list) moved to `Library` (not `Activity` as originally drafted) — operator decision 2026-05-16 since the live encoder dashboard belongs next to the user-driven Convert workflow.**  `Scan history` tab dropped in the same pass (no real content).  No section dividers — the rail stays flat.  No data-model or server-endpoint changes; this is a pure shell + routing refactor.
> **Triggered by:** owner review 2026-05-15 — rail is bloated and two pages with near-identical names ("Transcode" vs "Transcoding") confuse first-time operators.  `Activity`, `Transcoding`, and `Logs` all answer "what's happening on my server?" at different fidelities and should live behind one nav item.

---

## 0 · 2026-05-16 Refinement Log (post-M5)

Three structural refinements landed the day after the initial M1–M5 ship; treat the §3 / §4 / §6 sections below as the **original plan**, this section as **the actual shipped state**.

### 0.1 Tab reshape

- **Library shell tabs** were `Folders · Convert · Scan history` → **`Libraries · Convert · Transcoding`**.
  - "Folders" tab label renamed to **"Libraries"** (route path stayed `/library/folders` to avoid colliding with the dashboard nav key).
  - **Scan history** tab dropped — placeholder card had no real content, kept ballooning IA without value.
  - **Transcoding** (live HLS session list) moved in from `Activity` because it conceptually pairs with Convert (both are encoder-load surfaces).  Now sits at `/library/transcoding`.
- **Activity shell tabs** were `Sessions · Transcoding · Logs` → **`Sessions · Logs`** (Transcoding moved out).
- Back-compat redirects updated: `/transcoding` now redirects to **`/library/transcoding`** (was `/activity/transcoding`).

### 0.2 `IndexedStack` tab host + lazy-mount via `_visited` Set

The original plan used per-tab `go_router` sub-routes (`/library/folders`, `/library/convert`, ...) backed by separate routes that each rebuilt the entire shell.  The operator caught this immediately on real-device test: every tab click rebuilt the shell, tore down the cubits, and re-fetched data — "the whole page changes, like pop in and out, i don't want that, it's slow."

**Shipped solution:** rewrote `LibraryShell` + `ActivityShell` as `StatefulWidget`s with:

```dart
final Set<LibraryShellTabPath> _visited = {};   // lazy-mount tracker
late LibraryShellTabPath _activeTab;             // current pill

void _switchTab(LibraryShellTabPath next) {
  if (_activeTab == next) return;
  setState(() {
    _activeTab = next;
    _visited.add(next);
  });
  _rememberedLibraryTab = next;
}

// inside build():
IndexedStack(
  index: _activeTab.index,
  children: [
    _bodyFor(LibraryShellTabPath.folders, const LibraryScreen(embedded: true)),
    _bodyFor(LibraryShellTabPath.convert, const TranscodeScreen(embedded: true)),
    _bodyFor(LibraryShellTabPath.transcoding, const TranscodingScreen(embedded: true)),
  ],
)

Widget _bodyFor(LibraryShellTabPath tab, Widget real) =>
    _visited.contains(tab) ? real : const SizedBox.shrink();
```

- Tab switching is now a pure `setState` + index swap — no shell tear-down, no cubit dispose, no re-poll.
- `_visited` Set ensures unvisited tabs render `SizedBox.shrink()` instead of mounting eagerly.  A session that never visits Convert never constructs a `TranscodeCubit`.
- Routes (`/library/folders`, `/library/convert`, `/library/transcoding`) still exist as deep-link targets but they all mount the same `LibraryShell` with an `initialTab` arg.

### 0.3 Singleton cubits + `BlocProvider.value` injection

The original plan didn't address what happens when the operator navigates away from `/library` and back — under the per-tab routing model + factory cubits, every navigation hop refetched `/library` + `/storage` (skeleton flash, 200 ms delay).  Operator caught it: "whenever I nav to other pages, like Client say, and come back to Library, it loads back all the data which takes time, when nothing got updated."

**Shipped solution:** `LibraryCubit` + `StorageCubit` promoted to **GetIt lazy singletons** in `injector.dart`:

```dart
getIt.registerLazySingleton<LibraryCubit>(
  () => LibraryCubit(
    repository: getIt<LibraryRepository>(),
    events: getIt<LibraryEventsService>(),
  )..load(),
);
getIt.registerLazySingleton<StorageCubit>(
  () => StorageCubit(
    repository: getIt<StorageRepository>(),
    events: getIt<LibraryEventsService>(),
  )..load(),
);
```

Shell injects via `BlocProvider.value(GetIt.I<…>())` (not `BlocProvider(create:)`) so navigating away + back rebinds the same cubit instance and reuses its cached state.  First Library visit pays the load cost once; subsequent visits are O(1).

Cubits gained a public `refresh()` method that emits straight into `*Loaded` (skipping `Loading`) for stale-while-revalidate semantics.  Every shell-aware screen calls `cubit.refresh()` from `didChangeDependencies` if the cubit is already in `*Loaded` — silent background re-fetch, no skeleton flash on a navigation hop.

The previous `BlocConsumer.listener`-driven auto-select-first-library path had a bug under cached-singleton state: the listener only fires on *new* emissions, not on the pre-existing state at mount time.  Fix: rerun auto-select against `cubit.state` directly inside `didChangeDependencies`, sorted alphabetically.

### 0.4 WebSocket push refresh (`LibraryEventsService`)

The original plan implicitly assumed manual `Refresh` button + 15 s polling timers would handle the freshness gap.  Operator: "wont my app can auto detect changes? ... but websocket will be less expensive and if in future if user just wants to run server for light weight they have option for it."

**Shipped solution:** new [`apps/desktop/lib/features/library/data/services/library_events_service.dart`](../../apps/desktop/lib/features/library/data/services/library_events_service.dart) — `dart:io.WebSocket` subscriber against the existing `/api/v1/ws/notifications` endpoint that demultiplexes ephemeral event frames into broadcast streams:

```dart
class LibraryEventsService {
  final _libraryChanged = StreamController<void>.broadcast();
  final _storageChanged = StreamController<void>.broadcast();

  Stream<void> get libraryChanged => _libraryChanged.stream;
  Stream<void> get storageChanged => _storageChanged.stream;

  Future<void> start() async { /* connect, subscribe, fan out frames */ }
}
```

- Eager singleton in DI (`..start()` at construction).  One TCP socket per app launch; ~zero idle overhead.
- Auto-reconnect with **exponential backoff**: 1 s → 2 s → 4 s → 30 s cap.
- Bearer header injection on the WS upgrade request when an `ApiClient` token is present.
- Frame format: `{"type": "event", "kind": "library_changed" | "storage_changed"}` — separate from the persistent `{"type": "notification", "data": ...}` frames the notifications cubit handles.
- Cubits subscribe in their constructor: `events?.libraryChanged.listen((_) => refresh())`.  `events: null` is accepted (degrades to Refresh-button-only — used by test harnesses).

**Server side:** new helper in [`apps/server/services/notification_service.py`](../../apps/server/services/notification_service.py):

```python
def broadcast_event(kind: str, data: dict[str, Any] | None = None) -> None:
    payload: dict[str, Any] = {"type": "event", "kind": kind}
    if data is not None:
        payload["data"] = data
    _broadcast(payload)
    logger.debug("Event broadcast: kind=%s", kind)
```

Distinct from `_broadcast()` for persistent notifications — `broadcast_event()` emits ephemeral frames that don't get written to the DB (no notification row created; just the WS push).

`apps/server/routers/library.py` fires events after every mutation:
- `POST /library` (create) → `library_changed`
- `PATCH /library/{id}` (update) → `library_changed`
- `DELETE /library/{id}` (delete) → `library_changed` + `storage_changed`
- `POST /library/{id}/scan` (scan) → `library_changed` + `storage_changed`
- `POST /library/{id}/enrich-tmdb` → `library_changed`

**Cost vs polling:** desktop with 4 tabs open used to issue ~16 HTTP requests per minute against a quiescent server (15 s polling × 4 cubits).  WS path is one idle TCP socket — server only writes when something actually changes.  Reflects mutations within ~50 ms of the server commit instead of within the polling interval.

### 0.5 `FluxPillTabs` + other supporting widgets

- **`FluxPillTabs`** (new) at `apps/desktop/lib/shared/widgets/flux_pill_tabs.dart` — pill-button tab row (filled violet pill on active, dim text+icon on inactive).  Distinct from the underline-style `FluxTabBar` reused inside `TranscodeScreen` etc.
- **`PageHeader.verticalPadding`** parameter (default `AppSpacing.s24`; tabbed shells use `AppSpacing.s12`) — tightens the header above the pill tabs.
- **`LibraryScreen` polish bundle:** alphabetical pre-selection, sandwich gradient on cards (top-dark / middle-clear / bottom-dark) for text legibility over poster art, faded type-icon fallback for libraries without TMDB results, `_SmallStatTile` (~60 % StatTile), `_TypeFilterChips`, 80 ms `AnimatedContainer` selection (down from 150 ms), manual double-tap via `_lastTapAt` timestamp (Flutter `GestureDetector.onDoubleTap` introduced a 300 ms single-tap latency).  Add Library dialog auto-populates name from picked folder basename.  Skeleton-loading body replaces the spinner during cold load.
- **`TranscodeScreen` rework:** right panel got the per-library detail-panel design language (`_SectionTitle` body-bold + bordered info cards + `_ActionCard` widgets with icon + title + subtitle + chevron, with destructive variant in red).  Candidates tab rewritten as sortable flat table (☐ Name / Size (right-aligned) / Codec / Output size (right-aligned) / Convert button); tristate select-all; rows-per-page popup; paginated footer with ellipsis-collapsed page nav; sortable column headers with arrow indicator; Status column removed; "Estimated Save" column renamed to "Output size" (negative values were misleading — AV1→H.264 expands, doesn't save).
- **`TranscodeCubit.startSingleTranscode(String fileId)`** for per-row Convert button.

---

## 1 · Executive Summary

Today's rail surfaces **10 top-level items** for a single-tenant home server.  Two structural problems:

1. **Word collision** — `Transcode` (user-driven AV1/VP9 → H.264 sidecar conversion, plan 18) and `Transcoding` (live HLS session monitor) sit one row apart in the rail.  Operators can't tell which is which without clicking.
2. **Triple-redundant observability** — `Activity`, `Transcoding`, and `Logs` all answer "what's happening?" with different fidelities.  Three top-level items for one mental model.

**Decision:** flatten the rail to **7 items**, merging the overlaps as tabs of the page they conceptually belong to.

```
Dashboard
Library          (Folders · Convert · Scan history)
Clients
Groups
Activity         (Sessions · Transcoding · Logs)
Settings
Subscription
```

**Headline outcomes:**
- 10 → 7 nav items.  No section labels or dividers — flat list.
- `Transcode` page survives intact as `Library → Convert` tab.  Same widgets, same cubit, same routes underneath.
- `Transcoding` and `Logs` pages survive intact as `Activity → Transcoding` and `Activity → Logs` tabs.
- Per-page remembered last-tab so the operator's flow isn't reset every visit.
- Dashboard's "Recent Activity" rows deep-link into `Activity → Sessions` (event-feed view), filtered to the clicked event.

**What's NOT changing:**
- No server endpoints touched.  No DB migration.  No cubit shape changes — each surviving screen widget mounts unchanged inside its new tab host.
- No naming changes (`Groups` stays `Groups`, `Library` stays `Library`).  Operator vocabulary unchanged.
- No removal of functionality — every screen visible today is still reachable, just one click deeper for the three that merge.

**Sequencing:** five milestones, ~1 day end-to-end.  M1 lands the `Library` tab host; M2 lands the `Activity` tab host; M3 wires Dashboard deep-links; M4 sweeps nav rail visuals + remembered-tab persistence; M5 polish + golden tests + cross-doc updates.  Detail in [§6](#6--milestones).

---

## 2 · Why This Redesign

| Pain point (current rail) | Symptom | Fix |
|---|---|---|
| `Transcode` vs `Transcoding` word collision | Operator confusion on first session — "which one starts a conversion?" | Rename in place: `Transcode` → `Library → Convert` tab.  No more two-rail-items-one-word away |
| Three observability surfaces (`Activity`, `Transcoding`, `Logs`) | Same question answered at three depths; operator hunts across three pages | One `Activity` rail item with three tabs |
| 10 rail items on a single-tenant home server | Visual bloat; rail looks like enterprise software | Flat 7-item rail |
| `Transcoding` page only has content when a stream is active | Top-level rail item for what's frequently empty state | Demote to a tab — still 1 click from rail, but doesn't dominate the home view |
| `Logs` is an advanced surface but lives at same depth as primary pages | Cognitive weight inversion | Tab under `Activity` — discoverable but not first-class |
| Operator has no "what's the latest state?" landing | Has to pick between three rail items | `Activity` becomes that landing; tabs let them deepen as needed |

---

## 3 · Final Rail Structure

### 3.1 Rail items

```
Dashboard
Library
Clients
Groups
Activity
Settings
Subscription
```

Flat list.  No section headers, no dividers.  Same icon vocabulary as today — only `Transcode`, `Transcoding`, and `Logs` icons retire.

### 3.2 Tabbed pages

| Page | Tabs | Tab contents |
|---|---|---|
| **Library** | Folders · Convert · Scan history | • **Folders** = today's `Library` page (root paths, scan triggers, library list)<br>• **Convert** = today's `Transcode` page (sidecar queue + history + scan-time toast)<br>• **Scan history** = lifted from `Folders` if it's already there, otherwise new in M5 |
| **Activity** | Sessions · Transcoding · Logs | • **Sessions** = today's `Activity` page (real-time event feed + history)<br>• **Transcoding** = today's `Transcoding` page (live HLS session list + per-session progress)<br>• **Logs** = today's `Logs` page (server logs viewer) |

All other rail items (`Dashboard`, `Clients`, `Groups`, `Settings`, `Subscription`) are single-page; no tab bar.

### 3.3 Tab behavior

- **`FluxTabBar`** reused from `groups/edit` page (plan 14).  Same chrome, same selected-tab styling.
- **Remembered last tab** — per-page persistence via `SharedPreferences` keyed on `last_tab.library` and `last_tab.activity`.  Visiting `Library` reopens the tab the operator was on last; same for `Activity`.  Fresh install / cleared prefs falls back to first tab.
- **Tab routing** — each tab is its own `go_router` sub-route so deep-links work and browser back navigation behaves:
  - `/library` → resolves to remembered tab or `/library/folders`
  - `/library/folders`, `/library/convert`, `/library/scan-history`
  - `/activity` → resolves to remembered tab or `/activity/sessions`
  - `/activity/sessions`, `/activity/transcoding`, `/activity/logs`

---

## 4 · Migration Map

Every screen today lands somewhere identical in the new IA.

| Today's route | Tomorrow's route | Notes |
|---|---|---|
| `/dashboard` | `/dashboard` | Unchanged |
| `/library` | `/library/folders` | First tab of new tabbed Library |
| `/library/:id/files` | `/library/folders/:id/files` | Deep-link unchanged in semantic; path prefix shifts |
| `/transcode` | `/library/convert` | Folded; rail icon retired |
| `/clients` | `/clients` | Unchanged |
| `/groups` | `/groups` | Unchanged (kept separate per owner direction) |
| `/groups/:id/edit` | `/groups/:id/edit` | Unchanged |
| `/activity` | `/activity/sessions` | First tab of new tabbed Activity |
| `/transcoding` | `/activity/transcoding` | Folded; rail icon retired |
| `/logs` | `/activity/logs` | Folded; rail icon retired |
| `/settings/*` | `/settings/*` | Unchanged (settings has its own internal tabbed structure) |
| `/subscription` | `/subscription` | Unchanged |

**Back-compat redirects** — old top-level routes (`/transcode`, `/transcoding`, `/logs`) redirect to their new home for one release.  Drop in v1.1.

---

## 5 · Dashboard Deep-Links

The Dashboard's "Recent Activity" card (visible on home) lists session events.  Today the rows are clickable and "View All" jumps to `/activity`.

**New behavior:** every row deep-links to `Activity → Sessions` (the event feed) with the clicked event pre-selected / scrolled-to.  This holds for both `stream.start` and `stream.end` rows; the operator stays in the event-feed mental model and can switch tabs if they want the live-session list.

`Activity → Transcoding` is reached only via:
- Direct rail click → `/activity` → resolves to `Activity → Transcoding` if that was the remembered tab
- Explicit tab click within `Activity`
- (Future) "Open in Transcoding view" affordance on a Sessions row — out of scope for this plan

This keeps the Dashboard's deep-link contract simple: one click, one destination, predictable.

---

## 6 · Milestones

Five milestones, ~1 day end-to-end.  Order is deliberate: tab hosts before deep-link rewiring before nav-rail visual cleanup.

### M1 — Library tab host (~2 h) — ✅ Shipped 2026-05-15 · refined 2026-05-16

- Add `LibraryShell` widget that renders `FluxTabBar` + tab content.
- Sub-routes: `/library/folders`, `/library/convert`, `/library/scan-history`.
- Mount existing `LibraryScreen` widget (renamed `LibraryFoldersTab`), existing `TranscodeScreen` widget (renamed `LibraryConvertTab`), and a new `ScanHistoryTab` stub.
- `/library` root resolves to remembered tab via `SharedPreferences`; falls back to Folders.
- Existing `/transcode` route registered as redirect → `/library/convert`.
- Update `app_router.dart`.

**Shipped diverges from plan:**
- `FluxTabBar` swapped for **`FluxPillTabs`** (new shared widget — pill-button row).  `FluxTabBar` underline style stays inside `TranscodeScreen` inner Candidates/Queue/History tabs.
- `LibraryScreen` + `TranscodeScreen` kept their existing widget names + paths; passed `embedded: true` instead of being renamed.
- **`ScanHistoryTab` dropped at 2026-05-16 refinement** — replaced by `TranscodingScreen(embedded: true)` (Transcoding moved out of Activity).  Library tabs are now `folders / convert / transcoding`.
- Rewritten as `StatefulWidget` + `IndexedStack` (not per-tab routing) to fix operator-caught "pop in/out" tab-switch tear-down.  See §0.2.

### M2 — Activity tab host (~2 h) — ✅ Shipped 2026-05-15 · refined 2026-05-16

- Add `ActivityShell` widget — same shape as `LibraryShell`.
- Sub-routes: `/activity/sessions`, `/activity/transcoding`, `/activity/logs`.
- Mount existing `ActivityScreen`, `TranscodingScreen`, `LogsScreen` widgets as tabs.
- `/activity` root resolves to remembered tab; falls back to Sessions.
- Existing `/transcoding` and `/logs` routes registered as redirects → respective tab.

**Shipped diverges from plan:**
- **Transcoding tab moved out** at 2026-05-16 refinement (now `/library/transcoding`).  Activity tabs are now `sessions / logs` only.
- `/transcoding` redirect target updated to **`/library/transcoding`** (was `/activity/transcoding`).
- Same `IndexedStack` + lazy-mount + module-level remembered-tab pattern as M1.

### M3 — Dashboard deep-links (~1 h) — ✅ Shipped 2026-05-15

- Update `DashboardScreen` "Recent Activity" card row tap handler to `context.go('/activity/sessions?event=<id>')`.
- `ActivityScreen` reads the `event` query param and scrolls / highlights that row.
- "View All" link → `/activity/sessions`.

**Shipped diverges from plan:**
- Row taps + "View All" + Quick-Access "View Activity" button all target `/activity/sessions` and append `?event=<id>` — but the **highlight-on-scroll consumer in `ActivityScreen` is deferred** (query param accepted by the route but not yet read).  Mark as v1.1 polish.

### M4 — Nav rail cleanup (~1 h) — ✅ Shipped 2026-05-15

- Remove `Transcode`, `Transcoding`, `Logs` from the nav-rail config.
- Retire their icons from the icon registry (or mark deprecated if still used elsewhere — likely not).
- Verify keyboard nav order: `Dashboard → Library → Clients → Groups → Activity → Settings → Subscription`.
- Verify rail width unchanged (no items got narrower; spacing didn't shift).

### M5 — Polish + tests + docs (~2 h) — ✅ Shipped 2026-05-15 · doc sweep 2026-05-16

- Golden test updates: `desktop_nav_rail_golden_test.dart`, any per-screen goldens that captured the old breadcrumb / title.
- Update widget tests that navigated via `/transcode`, `/transcoding`, `/logs` to use new paths.
- `docs/08_frontend/01_frontend_architecture.md` — update the Desktop Control Panel screen-tree section.
- `docs/04_api/01_api_contracts.md` — no changes (server contracts unchanged), but verify the URL inventory.
- `docs/05_infrastructure/02_url_inventory.md` — update client-facing routes.
- Mark `current_status.md` IA section.

### M6 (added 2026-05-16) — IndexedStack + singleton cubits + WS push refresh

Captured retroactively after operator caught the per-tab-route tear-down + cross-page refetch + polling cost on real-device test.  Not a planned milestone — landed in the same session as the M1–M5 shipping pass.

- **IndexedStack tab host** (`LibraryShell` + `ActivityShell` as `StatefulWidget` + `_visited` Set lazy-mount).
- **Singleton cubits** (`LibraryCubit` + `StorageCubit` lazy singletons in GetIt + `BlocProvider.value` injection + `refresh()` stale-while-revalidate).
- **`LibraryEventsService`** WS subscriber + server-side `broadcast_event()` helper + `library.py` mutation fires.
- **Polling timers ripped out** (`startPolling()` / `stopPolling()` / `Timer.periodic` deleted, not deprecated).

See §0 above for the full shipped notes.

---

## 7 · Out of Scope

- **No naming changes** — `Groups` stays `Groups` (owner explicitly chose to keep the name in IA review).  No "Sharing" / "Access" rename.
- **No section dividers / labels** — owner explicitly chose flat rail.
- **No data-model changes** — no DB migration, no API change.
- **No Activity ↔ Transcoding row cross-links** — a Sessions row doesn't deep-link to its live transcoding view in this pass.  Future enhancement.
- **No mobile changes** — this plan is desktop Control Panel only.  Mobile nav is unchanged.
- **No Subscription / Settings restructure** — already coherent, left alone.
- **No removal of back-compat redirects** — `/transcode`, `/transcoding`, `/logs` redirect for one release.  Cleanup is a separate v1.1 chore.

---

## 8 · Open Questions

None at draft sign-off.  Three earlier questions are resolved:

1. ~~Section dividers?~~ → No, flat rail.
2. ~~Default tab behavior?~~ → Remembered last tab per page.
3. ~~Dashboard deep-link target?~~ → `Activity → Sessions`.

If new questions surface during M1 implementation (e.g. should Convert tab badge a count when sidecars are queued?), they get added here before the next milestone.

---

## 9 · Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Existing widget tests assume `/transcode` and `/transcoding` routes exist as top-level | High | M5 sweeps tests; back-compat redirects keep prod traffic working |
| Operator muscle memory for "click Transcoding to see live sessions" | Medium | Back-compat redirect plus `Activity → Transcoding` is one tab click away; release notes call out the change |
| Polling cubits don't survive being mounted inside a tab host | Low | Cubits are page-scoped already; tab host is just a parent widget — no cubit lifecycle change |
| Remembered-tab persistence corrupts on schema change | Low | `SharedPreferences` key uses string literal; invalid value falls back to first tab |
| Golden tests fail en masse from layout shift | Medium | Run goldens locally in M5 and update intentional shifts; flag any unintentional ones |

---

## 10 · References

- `docs/08_frontend/01_frontend_architecture.md` — desktop screen tree (will be updated in M5)
- `docs/10_planning/14_groups_management_page.md` — sibling tabbed-page precedent (`FluxTabBar` pattern)
- `docs/10_planning/18_library_transcode_plan.md` — original Transcode page spec (folded into `Library → Convert` here)
- `docs/05_infrastructure/02_url_inventory.md` — routes manifest (will be updated in M5)
