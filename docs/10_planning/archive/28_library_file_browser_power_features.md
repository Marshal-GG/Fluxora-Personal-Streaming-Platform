# Library File-Browser Power Features — Plan 28 (archived)

> **Category:** Planning · **Archived 2026-05-16**
> **Status:** ✅ All four phases (A + B + C + D) shipped 2026-05-16 — see [`docs/00_overview/current_status.md`](../../00_overview/current_status.md) for the rolled-up entry.
> **Commits:** `65a3555` server A + `f0971ae` client A + `6fdfde4` client B + `e74940b` server C + `9f6abf4` client C + `161461e` server+client D.
> **Test counts at close:** server 916 → 943 (+27 across A/C/D); desktop 121 → 143 (+22 across C/D); core 20 / mobile 97 unchanged.
> **Scope:** Reshape the v1 Explorer-style folder browser (shipped same day under plan 27 post-ship) into a power-user surface.  Adds proper desktop semantics (single-click selects / double-click opens), a right-side detail panel, sortable columns, list ↔ grid view toggle with thumbnails, in-place search, type-filter chips, keyboard navigation, right-click context menu, editable path bar, back/forward history, multi-select + density toggle, and per-file actions ("Index this file" / "Generate thumbnail").  Adds six smaller improvements surfaced during the planning pass.  Tier 3 features (recursive search via FTS5, bookmarks, drag-and-drop to Convert, filesystem watching) split into their own plans.
> **Triggered by:** owner review 2026-05-16 after the MVP browser shipped — referenced the Convert/Candidates table as the target design language; asked "what more can we add and improve?" + "do all 19 features".

---

## 1 · Executive Summary

The v1 folder browser (commits `43159e5` / `f340537`) ships these capabilities:
- Walk the actual filesystem under a library's `root_paths`
- Sorted listing with kind-coloured icons + size + modified columns
- Hidden-file toggle (dotfile + Windows attribute)
- Breadcrumb navigation + copy-path
- Click directory → navigate; click file → open in OS default app
- `is_indexed` + `file_id` JOIN with `media_files`

Plan 28 takes it to where operators expect a file browser to be on a modern Linux/Windows desktop.  19 ranked features + 6 additional improvements surfaced during planning.  Delivered in **4 phases (A–D)** spanning ~12 hours of focused work, each phase a clean commit chunk:

| Phase | Effort | Status | Headline |
|---|---|---|---|
| **A — Foundation** | ~4 h | ✅ Shipped 2026-05-16 (`65a3555` + `f0971ae`) | Single/double-click semantics + right detail panel + sortable columns + list ↔ grid view + search box + server-side indexed-metadata extension + thumbnail preview in detail panel + currently-streaming badge + indexed-only toggle (header form; chip form in Phase B) + stale-thumbnail auto-re-queue + empty-state copy variations + stream-test button on detail panel + HDR badge on rows.  Long-hover quick-preview deferred to Phase B (small, low-priority). |
| **B — Filters & power** | ~3 h | ✅ Shipped 2026-05-16 (`6fdfde4`) | Type-filter chips (`LibraryBrowseFilterChips`) + item-count footer (`LibraryBrowseCountFooter`) + keyboard nav (arrows/Enter/Backspace/Esc/Home/End/PageUp/Down/`/`) + indexed-only chip variant + polish (failed-thumb warning icon, indexed-at tooltip via `_IndexedTag`).  Long-hover quick-preview deliberately skipped — the always-visible right detail panel already shows the same info on click, parallel popover surface is marginal value for real Overlay+z-index cost. |
| **C — Interactions** | ~4 h | ✅ Shipped 2026-05-16 (`e74940b` server + `9f6abf4` client) | Right-click context menu (`library_browse_context_menu.dart` — Open / Reveal / Copy path / Copy name / Index this file / Regenerate thumbnail / Scan this folder, dispatched on entry kind + indexed status) + editable path textbox (`_BreadcrumbBar` now Stateful with click-to-edit; Enter commits via `navigateToAbsolute`, Esc cancels via inner `Focus` interceptor) + density toggle (`_DensityCycleButton` cycles compact/cosy/comfortable; row vertical padding 4/6/8 px, grid tiles 140/160/180 cross × 160/180/200 main) + multi-select (Ctrl-click toggle, Shift-click range from anchor, Ctrl+A select-all-visible; `_MultiSelectBody` on the detail panel replaces single-entry view with summary + Copy paths + Clear).  **Server endpoints (`e74940b`):** `POST /api/v1/library/{id}/index-file?path=<rel>` (`library_service.index_single_file` + idempotent UNIQUE-conflict handling), `POST /api/v1/files/{file_id}/regenerate-thumbnail` (`thumbnail_worker.regenerate_file` priority=10 reset), `POST /api/v1/library/{id}/scan-subtree?path=<rel>` (`scan_library` gained `subtree_abs` kwarg routed via `_scan_library_locked`).  Shared `browse_service.resolve_file_for_index` / `resolve_subtree_for_scan` / `_load_library_roots` resolvers.  Test counts: server **925 → 938 (+13)**; desktop **121 → 137 (+16)**. |
| **D — History + lazy compute** | ~1 h | ✅ Shipped 2026-05-16 (`161461e`) | Back/forward history (cubit `_back` + `_forward` stacks driven by `navigateTo`; `goBack` / `goForward` + `canGoBack` / `canGoForward` getters; toolbar `arrow_back_ios_new_rounded` / `arrow_forward_ios_rounded` icons in `_BreadcrumbBar`; Alt+← / Alt+→ keyboard shortcuts).  Lazy folder-size: new `GET /api/v1/library/{id}/folder-size?path=<rel>` endpoint walking `os.walk(followlinks=False)` summing file sizes (hidden files included; "how much disk does this folder use" doesn't depend on visibility filters); `cubit.computeFolderSize` caches under `_folderSizes: Map<String, FolderSize>` so re-selection skips the round-trip; `_FolderSizeBlock` on the detail panel for directory entries renders a `FluxButton('Compute size')` → spinner → "X MB · N files" readout.  Server **938 → 943 (+5)**; desktop **137 → 143 (+6)**. |

**Tier 3 — separate plans (not in 28):**
- Recursive search via SQLite FTS5 (new search service + endpoint + pagination)
- Bookmarks / favorites (new DB table + endpoints + sidebar UI)
- Drag-and-drop to Convert tab (cross-feature contract + per-OS Flutter desktop drag/drop)
- Live filesystem watching (`watchdog` dep + WS event broadcast + per-OS event semantics)

**What's NOT in scope (even though it came up while thinking):**
- Delete file from disk (one mis-click = data loss; OS file manager handles deletes)
- Rename file (same data-loss risk; breaks `media_files.path` invariant)
- Group-by-month media gallery view (separate "Photos library" feature)
- Watched-count / play-count surfacing (conflates file browser with playback analytics)

---

## 2 · Why This Plan, Why Now

| Pain point (v1 MVP browser) | Symptom | Phase that fixes it |
|---|---|---|
| Single-click on a file immediately opens it | Operator who wants to inspect a file's metadata is forced into the OS app first | A — single-click selects + detail panel |
| No way to see file metadata without clicking through | Have to leave the panel to verify codec / dimensions / indexed status | A — right detail panel |
| Default sort is dirs-first-alphabetical only | "Largest file" / "most recent" / "smallest" needs scanning every row | A — sortable columns |
| List view only | Lots of media in one folder is hard to scan visually | A — grid view with thumbnails |
| No search inside the current directory | Have to scroll through hundreds of files for one match | A — search box |
| No filtering by file kind | A music folder mixed with text files makes finding videos slow | B — type chips |
| No keyboard nav | Power users want arrows + Enter; today every action is mouse | B — keyboard nav |
| Right-click does nothing | Every modern file browser has right-click; muscle memory is broken | C — context menu |
| Deep paths require N clicks to reach | "Open D:/Movies/2024/Sci-Fi/Director/foo" via click-click-click is tedious | C — path textbox |
| Un-indexed files can't be played | Operator sees a streamable file in the browser but can't trigger ingest | C — per-file Index action |
| Failed thumbnails stay invisible | Operator doesn't know which files the worker gave up on | C — per-file Generate-thumb + Phase B failed-thumb indicator |
| No back navigation | "I just came from there" isn't undoable | D — back/forward history |
| Folder sizes unknown without inspection | "How big is this folder?" requires shelling out to OS | D — lazy folder-size compute |

---

## 3 · Architecture Overview

```
┌────────────────────────────────────────────────────────────────────┐
│  library_files_screen.dart                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  PageHeader (back + title + show-hidden + indexed-only       │  │
│  │              + view-toggle + search + density + Open in Exp.)│  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │  _PathBar (editable textbox toggle + breadcrumb + history)   │  │
│  ├─────────────────────────────────────────┬────────────────────┤  │
│  │                                          │                    │  │
│  │  _BrowseListBody / _BrowseGridBody      │  _DetailPanel      │  │
│  │  (selection + sort + filter + multi-    │  (selected entry's │  │
│  │   select + ctxmenu + keyboard nav)       │   metadata +       │  │
│  │                                          │   thumbnail +      │  │
│  │                                          │   actions)         │  │
│  │                                          │                    │  │
│  ├──────────────────────────────────────────┴────────────────────┤  │
│  │  _CountFooter (folders · files · indexed · visible size)     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  LibraryBrowseCubit                                                 │
│    state: { response, selectedNames, sortBy, sortAsc, filter,       │
│             search, viewMode, showHidden, indexedOnly, density,     │
│             history (back/forward stacks), folderSize: Map<...> }   │
│    actions: navigate / select / multiSelect / setSort / setFilter / │
│             setSearch / setView / goBack / goForward / requestSize  │
└────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  Server: GET /api/v1/library/{id}/browse                            │
│  - Existing path + show_hidden query                                │
│  - NEW Phase A: indexed entries include width/height/codec/         │
│    duration_sec/hdr_format + thumbnail_status (joined with          │
│    media_files + media_thumbnails)                                  │
│  - NEW Phase D: optional ?include_size=true triggers recursive      │
│    size accumulation for entries flagged dirs in the response       │
│  Server: POST /api/v1/library/{id}/index-file (Phase C)             │
│  Server: POST /api/v1/library/{id}/regenerate-thumbnail-for         │
│          (Phase C — single-file variant of plan 27 M3 regen)        │
│  Server: POST /api/v1/library/{id}/scan-subtree (Phase C addition)  │
│  Server: GET /api/v1/library/{id}/folder-size?path= (Phase D)       │
└────────────────────────────────────────────────────────────────────┘
```

---

## 4 · Phase A — Foundation (✅ Shipped 2026-05-16)

The single biggest UX shift.  Splits click into select-vs-open + adds the detail panel that motivates the split + makes the listing genuinely usable.

**Shipped commits:**
- Server (`65a3555` — `feat(server): plan 28 phase A M1 — browse endpoint indexed-entry media payload`): `BrowseEntry` carries new `mtime_unix` + nullable `IndexedMedia` block (width / height / duration_sec / codec_name / hdr_format / audio_codec / thumbnail_status / thumbnail_generated_at_unix / indexed_at_iso / is_streaming).  `_attach_index_status` rewritten as a single LEFT-JOIN against `media_files` + `media_thumbnails` + `EXISTS` subquery on `stream_sessions`.  Stale-thumbnail auto-re-queue (source mtime > thumbnail generated_at flips the worker row back to pending with priority=5 + reports `thumbnail_status='stale'` to the client).  9 new tests; server suite 916 → 925.
- Client (`f0971ae` — `feat(desktop): plan 28 phase A — folder browser foundation`): `IndexedMedia` + extended `BrowseEntry` shapes; cubit gains UI-pref state (selection / sort / view-mode / search / indexed-only) + `applyBrowseFilters` pure function; three new widget files (`LibraryBrowseDetailPanel`, `LibraryBrowseSearchBar`, `LibraryBrowseViewToggle`); `library_files_screen.dart` rewritten with Row(list/grid body | 320 px detail panel), sortable column headers, single-click-selects / double-click-opens via `_lastTapAt` 300 ms pattern, `_BrowseGridTile` with real thumbnail loading, distinct empty-state copy per scenario.  Desktop suite 121 (unchanged — Phase A is mostly composition; widget tests for sort/click/grid land with Phase B).

### 4.1 Click semantics rewrite (#2)

- **Single-click on row** → toggles `selectedNames` set membership.  In single-select mode (default; Phase C adds multi-select) this replaces any prior selection.  Selected row gets a violet outline + ~10 % violet tint + becomes the source for the detail panel.
- **Double-click on row** → action:
  - Directory → `cubit.navigateTo('${currentPath}/${entry.name}')`
  - File → `launchUrl(Uri.file(absolute))` to open in OS default app
- **`onTap` / `onDoubleTap` competition:** Flutter's gesture-arena adds ~300 ms latency to single-tap when `onDoubleTap` is registered.  Use the same `_lastTapAt` timestamp pattern that `_LibraryCard` in `library_screen.dart` uses — only `onTap` registered, manual double-tap detection via 300 ms window.

### 4.2 Right detail panel (#3 + thumbnail preview)

Fixed 320 px wide column on the right side of the body (between the list and the screen's right padding).  Sections, top-to-bottom:

- **Kind header** — large icon (40 px) + entry name (h2) + small kind label ("Video file" / "Folder" / etc).
- **Path** — bordered `_PathCard` (matches the design language of the per-library detail panel's library-path card from earlier this week) with copy-to-clipboard icon.
- **Quick stats grid** (3 rows × 2 cols when applicable):
  - Size · Modified
  - Kind · Hidden (Yes/No)
  - For files: Extension · Indexed (Yes/No)
- **Media metadata** (only for indexed video/audio/image — requires server change below):
  - Video: Dimensions (`1920 × 1080`), Codec (`H.264`), Duration (`1h 47m`), HDR Format (badge: HDR10 / HLG / DolbyVision / SDR)
  - Audio: Codec (`FLAC`), Bitrate (`1411 kbps`)
  - Image: Dimensions (when known)
- **Thumbnail preview** (only when `is_indexed` and a `media_thumbnails.status='ready'` row exists):
  - 280 × 158 (16:9) at the top of the panel — or 280 × 280 for image kind.
  - Loads from `/api/v1/files/{file_id}/thumbnail?v=<unix>` via `Image.network` with `_apiClient.localBaseUrl` prefix (reuses `LibraryRepositoryImpl._resolveCoverUrls` pattern).
  - If not indexed but kind=image: load the image itself via the existing `/content` endpoint (small preview).
  - Folder preview: a 4-tile collage of the first 4 indexed thumbnails under it (cheap; reuses the same gradient mosaic fallback when empty).
- **Actions row** at the bottom (single buttons until Phase C extends with Index/Generate-thumb):
  - `Open` (file: launchUrl; folder: navigate into)
  - `Reveal in folder` (the existing reveal action)
  - `Copy path` (clipboard write)
- **Empty state** when no selection: muted "Select a file or folder to view details" + faded icon.

### 4.3 Sortable columns (#1)

Server-side already sorts dirs-first then files-alphabetical.  Phase A adds **client-side sort on top of the server response** — the response is small (one directory at a time, bounded by typical filesystem fan-out) so re-sorting in Dart is free.  Server stays as-is.

- Click a column header → toggle sort direction; first click sets ascending, second click descending, third click clears (returns to server default).
- Sortable columns: **Name**, **Size** (right-aligned), **Modified**.  Phase B adds **Kind** + **Indexed**.
- Header shows arrow indicator (↑ asc / ↓ desc / blank).
- Sort state lives in the cubit (`sortBy: enum`, `sortAsc: bool`) so it persists across navigation but resets on screen mount.

### 4.4 List ↔ Grid view (#4)

View-mode toggle in the header (segmented control: List | Grid).  Local screen state (not cubit) — defaults to List on first visit but persists across the screen's lifetime via the BLoC's `viewMode` field for symmetry with the other prefs.

- **List view** = today's body, plus selection + sort + multi-select work.
- **Grid view** = wrap of fixed-size tiles (160 × 200 px each):
  - Top 60 % of tile: kind icon **OR** thumbnail when `is_indexed` and ready.  Thumbnails use the same `/api/v1/files/{file_id}/thumbnail?v=<unix>` endpoint.
  - Bottom 40 %: name (max 2 lines, ellipsised) + small kind icon + size.
  - Same selection / context-menu / double-click semantics.
- Folder tiles in grid view: violet folder icon big in the centre + name below.
- Hidden + Indexed tags appear as small corner badges in grid view (top-right corner).

### 4.5 In-place search box (#5)

- New `FluxTextField` in the header (between view toggle and density toggle).  ~240 px wide.
- Typed text filters the visible entries by case-insensitive substring on `name`.  Pure client-side — operates on the loaded `response.entries`.  No server roundtrip.
- Search state lives in the cubit so navigation preserves it; cleared on `navigateTo`.
- Empty-state copy: "No entries in this folder match `<query>`."

### 4.6 Server endpoint extension — indexed-entry metadata

Today `_attach_index_status` returns `is_indexed` + `file_id` only.  Phase A extends the join to surface the metadata the right detail panel needs without a second HTTP request.  Field name additions on the wire:

```json
{
  "name": "John Wick 4.mkv",
  "kind": "video",
  ...
  "is_indexed": true,
  "file_id": "uuid",
  "media": {                                  // NEW — null when not indexed
    "width": 1920,
    "height": 1080,
    "duration_sec": 6420.5,
    "codec_name": "h264",
    "hdr_format": null,
    "audio_codec": "ac3",                     // primary track's codec from audio_tracks JSON
    "thumbnail_status": "ready",              // pending / generating / ready / failed / skipped
    "thumbnail_generated_at_unix": 1726493812 // for the ?v= cache-buster
  }
}
```

Implementation: single LEFT JOIN expansion in `_attach_index_status` plus a JOIN to `media_thumbnails` for thumbnail status.  Bounded by the per-directory query size; no N+1.

### 4.7 Additional improvements (folded into Phase A)

Each is small, high-leverage, and naturally co-located with the foundation work.

1. **mtime vs `thumbnail_generated_at` mismatch detection.**  In `_library_aggregates` (cover_urls) AND in the new `media.thumbnail_status` field: if `media_files.updated_at > media_thumbnails.generated_at`, report `thumbnail_status='stale'` and auto-re-queue via `thumbnail_worker.enqueue` with priority=5.  Two-line server change.  Quality-of-life for operators who replace files in-place.

2. **Currently-playing badge per row.**  JOIN browse response with `stream_sessions WHERE ended_at IS NULL AND file_id = mf.id` — set `is_streaming: bool` on indexed entries.  Client renders a small "▶ live" pill on the row.  Tiny SQL cost; very useful operator info.

3. **Stream-test button on detail panel (indexed videos only).**  Calls a new endpoint `POST /api/v1/stream/test-start/{file_id}` that runs `POST /stream/start` + immediately reports back the result (200 success + session_id, 422 with the FFmpeg stderr tail on failure).  Auto-cleans the session within 5 s.  Diagnostic gold: "does this file actually stream without going to mobile?"  Endpoint just wraps the existing stream-start logic with auto-cleanup.

4. **Long-hover quick-preview popover.**  800 ms hover on a row pops a small `Material(elevation: 8)` card next to the cursor with the kind icon / thumbnail / key metadata.  Cheaper than clicking to see what something is.  Tooltip pattern.  Uses existing thumbnail endpoint.

### 4.8 Phase A milestones + tests

- **M1** (~2 h): server endpoint extension + 3 tests covering the new `media` field shape (indexed video w/ thumbnail / indexed without thumbnail / non-indexed).
- **M2** (~1 h): client cubit selection + sort state + view-mode toggle.  Pure state work; 4 cubit tests.
- **M3** (~1 h): right detail panel + sort headers + grid view + search box + the 4 additional improvements.  Mostly composition; smoke-tested via manual operator pass.

**Acceptance:** open Library Files → select a video → right panel shows codec / dimensions / thumbnail.  Sort by size → biggest first.  Toggle Grid → tiles with thumbnails.  Type in search → list filters live.  Long-hover a row → preview popover.  A currently-streaming file shows the ▶ pill.  An indexed video has a Stream-Test button in the detail panel.

---

## 5 · Phase B — Filters & Power (~3 h)

The features that turn "find a file" from scrolling into a one-second operation.

### 5.1 Type-filter chips (#6)

- Row of `FluxChip`s below the search bar: **All** · **Folders** · **Videos** · **Images** · **Audio** · **PDFs** · **Other** · **Indexed only** (the Phase B incarnation of #9).
- Filter state in cubit; combinator is AND with the search filter.
- Indexed-only chip filters to `is_indexed=true` (folders implicitly excluded since folders never carry `is_indexed`).
- "All" is the default; chip group has single-selection semantics except for "Indexed only" which can stack on top of any kind filter.

### 5.2 Item-count footer (#7)

- Thin status strip at the bottom of the body, full-width minus the detail panel.
- Renders: `12 folders · 47 files · 3 indexed · 1.2 GB visible`.  Live-updated with filters / search.
- "Visible size" sums `size_bytes` of the currently-displayed file entries (excludes folders since their size needs the lazy compute from Phase D).
- "X indexed" only renders when > 0 to avoid noise.

### 5.3 Keyboard navigation (#8)

- `Focus` on the body so arrow keys / Enter / Backspace / Esc route to the cubit.
- **↑ / ↓** — move selection up/down in the visible list (post-sort post-filter).
- **Enter** — open (= double-click action).
- **Backspace** — `goUp()` (same as the toolbar Up button).
- **Esc** — clear selection.
- **Home / End** — jump to first/last visible entry.
- **PageUp / PageDown** — jump 10 entries.
- **/** — focus the search box.
- **Ctrl+L** — focus the path textbox (Phase C).
- **Ctrl+A** — select all visible (multi-select, Phase C).

### 5.4 Indexed-only toggle (#9)

Lives inside the Phase 5.1 chip group as a side toggle — see §5.1.

### 5.5 Polish bundle (the §10 small items)

1. **HDR badge per row** — when `is_indexed && media.hdr_format != null`, render a violet `HDR10` / `HLG` / `DV` pill on the row (between the file name and the Indexed tag).  Reuses the chip widget that the player chrome uses (lift to `fluxora_core/widgets/` if needed).
2. **Failed-thumbnail indicator** — when `is_indexed && media.thumbnail_status == 'failed'`, render a small warning icon in the row.  Tooltip: "Thumbnail generation failed.  Click to retry."  Click triggers the Phase C single-file regenerate action.
3. **`indexed_at` tooltip** — long-hover the `Indexed` tag → popover showing `Indexed YYYY-MM-DD HH:MM` + `Last scanned YYYY-MM-DD`.  Server-side: include `media_files.created_at` and `media_files.updated_at` in the indexed-entry payload.
4. **Empty-state copy variations** — three distinct messages:
   - At root, no entries: "This library is empty.  Add files under one of its root paths."
   - In subdirectory, no entries: "This folder is empty."
   - With filters/search active: "No entries match the current filters."
   Each variation gets its own icon (folder_off / folder_open_outlined / search_off).

### 5.6 Phase B milestones + tests

- **M1** (~1 h): chip group + count footer + state plumbing.
- **M2** (~1 h): keyboard nav with `Focus` + `RawKeyboardListener`.  Manual smoke; 2 widget tests for arrow up/down + Enter.
- **M3** (~1 h): polish (HDR badge / failed-thumb icon / indexed-at tooltip / empty-state variations).

**Acceptance:** click `Videos` chip → only videos visible + count footer updates.  Type in search + chip stack → AND filter.  Press ↑ → previous entry selected; Enter → opens.  An HDR file shows the HDR10 pill.  A file the worker gave up on shows the warning icon.

---

## 6 · Phase C — Interactions (~4 h)

The deepest power-user features.  Mostly additive but introduces two new server endpoints.

### 6.1 Right-click context menu (#10)

- `Listener` for `onSecondaryTapDown` on each row.  Builds a position-anchored `FluxGlassMenu` (the existing primitive) with items based on entry kind + indexed status:
  - **Open** (Enter equivalent) — directory navigates, file opens
  - **Reveal in folder** (existing)
  - **Copy path**
  - **Copy as text** (the entry name only, no path)
  - **View details** (= focus right panel; on small screens / collapsed panel, expands it)
  - For files: separator
  - **Index this file** (only when `!is_indexed`) — Phase 6.3 endpoint
  - **Generate thumbnail** (only when `is_indexed && thumbnail_status in {pending,failed,skipped,stale}`) — Phase 6.4 endpoint
  - **Stream test** (only when `is_indexed && kind=video` — same as Phase A's button but accessible from the menu)
  - For folders: separator
  - **Scan this folder** (Phase 6.5 endpoint) — only when folder has any non-indexed video/image/audio/pdf files under it (cheap recursive count from `media_files.path` LIKE)

### 6.2 Editable path textbox (#11)

- Path bar gains a click-to-edit affordance.  Click any empty space in the breadcrumb area → switches to a single-line `FluxTextField` showing the current absolute path.
- Enter → validates: if path resolves under a library root and exists, navigate.  Otherwise show inline error ("Path is outside this library" / "Path doesn't exist") and keep editing mode.
- Esc → cancel + restore breadcrumb.
- `Ctrl+L` (from Phase B) focuses the textbox directly.
- Server reuses the existing `/browse` endpoint; path validation happens server-side (404 / 403 already returned).

### 6.3 Per-file "Index this file" action (#12)

New endpoint: `POST /api/v1/library/{library_id}/index-file?path=<relative>`.

- Server-side flow:
  1. Resolve `<root>/<relative>` via `browse_service._resolve_under_root` (reuses path security).
  2. Verify file exists, is a regular file, kind is non-`other` (no point indexing arbitrary docs into the catalog).
  3. INSERT a `media_files` row with absolute path; on UNIQUE conflict return the existing id.
  4. Run `_persist_probe` (ffprobe metadata) inline — single file is cheap.
  5. `thumbnail_worker.enqueue` with `priority=10` (jumps the queue).
  6. Best-effort TMDB enrichment if `FLUXORA_TMDB_KEY` set + filename parses to a likely title.
  7. Return `{file_id, queued_thumbnail: bool, enriched: bool}`.
- Client: cubit method `indexFile(libraryId, relativePath)` + UI update — once `file_id` is returned, the row's `is_indexed` flips to true + the action menu reshuffles.  Server broadcasts the existing `library_changed` event so other clients see the update.

### 6.4 Per-file "Generate thumbnail" action (#12 sibling)

New endpoint: `POST /api/v1/files/{file_id}/regenerate-thumbnail`.

- Wraps `thumbnail_worker.regenerate_library` shape but for a single file.
- Resets the `media_thumbnails` row to `pending` + `attempts=0` + deletes the on-disk JPEG + bumps priority to 10.
- Returns `{file_id, status: 'pending'}`.  Worker picks it up on the next tick.
- Client: row's failed-thumb indicator hides; thumbnail-progress events surface the regeneration.

### 6.5 Per-folder "Scan this subtree" action (additional improvement)

New endpoint: `POST /api/v1/library/{library_id}/scan-subtree?path=<relative>`.

- Triggers `library_service.scan_library` but constrained to a subtree.
- Implementation: add a `subtree: str | None = None` param to `scan_library`; when set, walk only that subdir.  Existing per-library lock still applies (concurrent calls serialise).
- Existing event broadcasts (`library_changed` + `storage_changed`) fire as usual.

### 6.6 Density toggle (#14)

- Header gains a small "Density" segmented control: **Compact** (28 px row height) / **Comfortable** (44 px row height; current default) / **Cosy** (38 px).
- State lives in the cubit; persisted across screen mount within the session.
- Pure CSS-style change — row internals adjust padding + icon size to match.

### 6.7 Multi-select with Ctrl+click / Shift+click (#15)

- **Ctrl+click** (Cmd on macOS) — toggle the clicked row's membership in `selectedNames` without clearing the rest.
- **Shift+click** — range select from the last single-clicked row to the shift-clicked row.
- **Ctrl+A** (Phase B keyboard) — select all visible.
- Detail panel reacts to multi-select by showing "$N items selected" instead of single-entry metadata.  Multi-select actions row:
  - Copy paths (newline-joined)
  - Reveal in folder (opens each parent? — opens just the first row's parent + warns "12 files selected; opening only the first parent" — multi-window opens are obnoxious)
  - For 2+ selected files: "Index N files" / "Generate thumbnails for N files" (multi-shot of the §6.3 / §6.4 endpoints; concurrency cap 4 to avoid hammering)

### 6.8 Phase C milestones + tests

- **M1** (~1 h): right-click context menu + position-anchored `FluxGlassMenu`.
- **M2** (~1.5 h): per-file Index + Generate-thumbnail + Scan-subtree endpoints + 9 server tests (happy / bad-path / unknown-file / already-indexed / kind-other rejected / etc).
- **M3** (~1 h): editable path textbox + validation flow.
- **M4** (~0.5 h): density toggle + multi-select state + multi-select detail panel.

**Acceptance:** right-click an un-indexed video → "Index this file" → 3 s later it shows as indexed + thumbnail appears in detail panel.  Click breadcrumb empty space → type `D:/Movies/2024` → Enter navigates.  Ctrl+click 5 files → detail panel shows "5 items selected" + bulk-action buttons.

---

## 7 · Phase D — History + lazy compute (~1 h)

The last small set.

### 7.1 Back/forward history (#13)

- Cubit gains two stacks: `_back: List<String>` (paths visited; topmost == current) and `_forward: List<String>` (cleared on every fresh navigate).
- `navigateTo` pushes current path onto `_back` before changing; clears `_forward`.
- `goBack()` pops from `_back`, pushes the popped onto `_forward`, navigates.
- `goForward()` mirrors.
- Two new toolbar icons in the header (between back button and breadcrumb): `arrow_back_ios_rounded` + `arrow_forward_ios_rounded`.  Disabled when stacks are empty.
- Keyboard: `Alt+←` / `Alt+→` (Phase B keyboard nav additions).
- History is per-screen-mount; not persisted.

### 7.2 Lazy folder-size compute

- New endpoint: `GET /api/v1/library/{library_id}/folder-size?path=<relative>`.
- Server walks the subtree, sums file sizes, returns `{size_bytes, file_count}`.  Bounded by the actual subtree size; can be slow on huge folders.
- Detail panel for a folder entry adds a "Compute size" button.  Click → shows a small spinner while the request runs → renders the totals + a small note "computed at HH:MM".  Result lives in cubit's `folderSize: Map<String, FolderSize>` so re-selecting the same folder doesn't refetch.
- "Compute size" is opt-in to avoid surprise CPU + disk-IO on huge libraries.

### 7.3 Phase D milestones + tests

- **M1** (~0.5 h): back/forward stacks + 3 cubit tests (push/pop, clear-forward-on-navigate, edges-disabled).
- **M2** (~0.5 h): folder-size endpoint + lazy compute UI + 2 server tests (small dir / nonexistent path).

---

## 8 · Edge Cases

| # | Case | Behaviour |
|---|---|---|
| 1 | Server `/browse` endpoint extension breaks existing client | Phase A is server-additive (new `media` field; clients ignore unknown keys via Dart's tolerant `fromJson`).  v1 desktop browser still works against the extended server response. |
| 2 | Sort + filter + search apply in what order? | Always: server response → filter (chip + search + show_hidden + indexed_only) → sort.  Sort happens last so a filtered subset is sorted, not the full set. |
| 3 | Multi-select + navigation | Selection clears on `navigateTo` to a different directory.  Selection persists across sort/filter changes within the same directory. |
| 4 | Right-click context menu position | Menu is anchored at the cursor's screen position via `Overlay.of(context)` + `Positioned` math.  Clamped to stay on-screen (if cursor is near the bottom edge, menu opens above).  Uses `FluxGlassMenu`'s existing position-prop. |
| 5 | Editable path textbox: paste an absolute path | Path validation: must resolve under one of the library's `root_paths` (server-enforced via the existing `_resolve_under_root`).  An absolute path outside the library shows the "outside this library" inline error. |
| 6 | Index-this-file on a path that's already indexed | Server checks for an existing `media_files.path` row; returns the existing id without re-INSERT.  Client treats this as success (already there). |
| 7 | Generate-thumbnail on a file currently being generated | The `media_thumbnails.status='generating'` row gets reset to `pending` (matches `regenerate_library` behaviour).  The in-flight worker slot finishes, writes `ready`, then the row goes back to `pending` on the reset.  Net: one wasted extraction.  Acceptable. |
| 8 | Stream-test on a file the encoder can't handle | Endpoint returns 422 + FFmpeg stderr tail.  Client renders the failure inline in the detail panel for 8 s before auto-clearing. |
| 9 | Long-hover preview on a fast-moving cursor | Tooltip's existing 800 ms `waitDuration` handles this; preview never pops if cursor leaves before the timer. |
| 10 | Folder-size compute on a folder mid-scan | Concurrent scan + folder-size: scan adds files; folder-size walks the live filesystem so the count grows.  Operator gets a snapshot.  Acceptable. |
| 11 | Currently-streaming badge race | When a session ends, the badge needs to disappear.  Solution: include `is_streaming` in `thumbnails_progress` and `library_changed` event payloads' affected file list — or accept refresh-on-next-browse-call.  v1.2 lazy refresh; not worth a new event kind today. |
| 12 | mtime > generated_at auto-re-queue races with manual regenerate | Both flip status to `pending`; `INSERT OR IGNORE` semantics mean no duplicate row.  Worker picks up either way.  Idempotent. |
| 13 | Path textbox + symlink escape | `_resolve_under_root` follows symlinks once + verifies the resolved target is under a root.  Paths pointing OUT via symlink return 403 — same v1 protection. |
| 14 | Browse cubit state restoration on hot reload | Sealed state is `freezed`-friendly; preserved across hot reload.  History stacks persist within the cubit's lifetime. |
| 15 | Multi-select all-visible when filter is active | `Ctrl+A` selects only currently-visible (post-filter, post-search) entries.  Operator who wants every entry in the directory clears filters first. |

---

## 9 · Data Model Changes

**Server-side: zero new tables or columns for Phases A–D.**  Phase A's endpoint extension reuses existing `media_files` + `media_thumbnails` columns via the JOIN.  Phase C's new endpoints are stateless (or write to existing tables).

**Tier-3 plans will need new tables** — flagged here for completeness:
- Bookmarks plan: new `library_bookmarks(id, library_id, relative_path, label, created_at)`.
- Recursive search plan: SQLite FTS5 virtual table over `media_files.path` + `media_files.title` + `media_files.name`.

---

## 10 · Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Phase A endpoint extension breaks v1 client | Low | Additive only; v1 clients ignore unknown JSON keys via Dart's `Map<String, dynamic>` decode |
| `is_streaming` JOIN adds cost on every browse request | Low | Index on `stream_sessions.file_id` + WHERE `ended_at IS NULL`; typical session count is small (≤10) |
| Long-hover preview popover causes z-index issues with right detail panel | Low | Use `Overlay.of(context)` with explicit `aboveDetailPanel` insert — same pattern as `FluxGlassMenu` |
| Index-this-file inline ffprobe blocks the request | Low | Probe is a single subprocess; bounded by `_persist_probe`'s existing timeout |
| Right-click context menu fights with Flutter's default text-selection menu | Low | `Listener.onSecondaryTapDown` is upstream of any text-selection arena; verified against the existing `FluxGlassMenu` callsites |
| Path textbox + manual edits + complex symlink hierarchies | Medium | All path resolution goes through `_resolve_under_root`; the inline error renders for any non-resolvable path |
| Density toggle's row-height changes break Phase A's sort header layout | Low | Header is fixed-height; only row content scales |
| Multi-select range (Shift+click) across a sort change | Medium | Shift-click computes range by visual index; resetting after sort means the range is whatever the operator saw at click time — acceptable behaviour matching Explorer |
| Folder-size compute on a TB-scale folder times out | Medium | Server enforces a 30 s walk cap with early-return; client shows "still computing" / "partial" if cap hit.  Future enhancement: stream incremental counts via WS |
| mtime auto-re-queue thrashes when an external process keeps touching files | Low | Worker's `max_attempts=3` already bounds retry storms.  Stale-detection only triggers when `updated_at` changes — `touch` without write doesn't move it |

---

## 11 · Out of Scope (deliberately deferred)

These came up in the planning pass but are not Phase 28 work:

- **Delete file from disk** — too dangerous from a control panel; OS file manager handles deletes.
- **Rename file** — same risk; breaks the `media_files.path` invariant.
- **Group-by-month media gallery view** — separate feature, conflates browser with photo-library shape.
- **Watched-count surfacing per row** — conflates file browser with playback analytics; deserves its own plan.
- **Per-folder thumbnail preview using actual file contents** (vs the gradient mosaic fallback) — covered by Phase A's "Folder preview: 4-tile collage of indexed thumbnails" but limited to indexed.  Recursive scan for un-indexed thumbs is too expensive.
- **Quick-look popover with playable video preview** — would need a Flutter video player on desktop, which today doesn't exist (control panel has no player).  Punted.
- **Drag-to-reorder columns / customisable column visibility** — pleasant for power users but every column is currently load-bearing; defer until user genuinely wants to hide one.
- **Saved views** (named filter+sort+columns combos) — flag for a future power-user plan.

---

## 12 · Tier 3 — Separate Plans

Each of these is large enough to warrant its own plan doc.  Tracked here for visibility; not implemented in 28.

### 12.1 Recursive search across the library

- New SQLite FTS5 virtual table indexed at scan time.
- Endpoint `GET /api/v1/library/{id}/search?q=<query>&kind=<filter>&limit=&offset=`.
- Snippet highlighting in results.
- Pagination + ranking.
- ~6 h effort.

### 12.2 Bookmarks / favorites

- New `library_bookmarks` table (id, library_id, relative_path, label, created_at).
- Endpoints: list / add / remove.
- Sidebar UI in the browser screen (collapsible left rail).
- Per-bookmark icon picker.
- ~4 h effort.

### 12.3 Drag-and-drop to Convert tab

- Cross-feature contract: browser produces a `DragPayload(libraryId, fileIds)`; Convert tab consumes it via Flutter's `DragTarget`.
- Per-OS quirks: Windows works via `desktop_drop`; macOS needs `NSDraggingInfo` bridge; Linux needs custom plumbing.
- Global drag controller via Riverpod or a singleton service.
- ~6 h effort (most of it the OS shims).

### 12.4 Live filesystem watching

- New pip dep `watchdog`.
- Server-side `FileSystemWatcher` per library root; events broadcast over the existing WS as a new `library_files_changed` kind.
- Per-OS event semantics:
  - Windows: `ReadDirectoryChangesW` — doesn't see USB plug/unplug; works for in-volume changes.
  - macOS: `FSEvents` — coalesces fast bursts; need a 250 ms debounce.
  - Linux: `inotify` — has system-wide watch-count limits (~8192 default); operator may need to `sysctl fs.inotify.max_user_watches=524288`.
- Client subscribes + refreshes the current browse path on relevant events.
- ~8 h effort + cross-platform QA.

---

## 13 · References

- `apps/server/services/browse_service.py` — current MVP service
- `apps/server/routers/library.py` — current MVP endpoint
- `apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart` — current MVP screen
- `apps/desktop/lib/features/library/presentation/cubit/library_browse_cubit.dart` — current MVP cubit
- `apps/desktop/lib/features/transcode/presentation/widgets/candidates_tab.dart` — design-language reference for the sortable table
- `apps/desktop/lib/features/library/presentation/screens/library_screen.dart` — design-language reference for `_LibraryDetailPanel` (right-side detail card the new detail panel matches)
- Plan 27: `docs/10_planning/27_thumbnail_generation_plan.md` — thumbnail subsystem reused for Phase A's preview + Phase C's per-file regenerate
- Plan 26: `docs/10_planning/26_desktop_cp_ia_redesign.md` — IndexedStack tab host + WS event push (the `LibraryEventsService` Phase A reuses)
- `docs/03_data/02_database_schema.md` — `media_files` + `media_thumbnails` + `stream_sessions` column inventory
- `docs/04_api/01_api_contracts.md` — existing `/browse` endpoint + WS frame format docs
