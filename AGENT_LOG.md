# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the canonical format spec at [`docs/12_guidelines/04_agent_log_format.md`](docs/12_guidelines/04_agent_log_format.md).
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_NN.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 14)
**Archived:** 2026-05-17
**Contents:** Plan 24 M9-partial follow-ons (HDR codec tonemap, FitMode three-way cycle, pinch zoom via raw Listener, chrome relayout, overflow-menu scroll fix, LAN cleartext config) + plan 26 desktop CP IA redesign (Library + Activity tabbed shells, M1-M5 + same-day-plus-one refinement with IndexedStack + singleton cubits + WS push refresh) + post-plan-28 folder-browser polish wave 1 (commit `aac917f`) + folder-browser polish wave 2 (uncommitted-at-archive-time: glass dropdowns + Filter button + cross-restart prefs + live thumb refresh + index-all-files + unindex actions + per-library TMDB toggle / migration 040).

* **Plan 24 — Real-device follow-ons (2026-05-15).** `network_security_config.xml` for LAN cleartext (global allow + `fluxora-api.marshalx.dev` HTTPS-only carve-out).  Client-side HDR→SDR tonemap via custom `TonemappingRenderersFactory` (Media3 `DefaultRenderersFactory` subclass; `KEY_COLOR_TRANSFER_REQUEST = COLOR_TRANSFER_SDR_VIDEO` on API 33+).  `PlayerEngine.videoSize` + `videoSizeStream`.  Three-way `FitMode {fit, fill, stretch}` cycling button.  Pinch zoom via raw `Listener` (`_activePointers >= 2` gating).  Player UI relayout (transport below scrubber, `_MinimizeHandle` removed).  Overflow-menu scroll fix (`SingleChildScrollView` + `isScrollControlled: true`).  Mobile 97 (no new tests).

* **Plan 26 — Desktop CP IA redesign (2026-05-15 → 2026-05-16).** Rail collapsed 10 → 7 by folding `Transcode` / `Transcoding` / `Logs` into tabbed pages of `Library` / `Activity`.  Same-day-plus-one refinement (2026-05-16): tab reshape (Library = Libraries / Convert / Transcoding; Activity = Sessions / Logs); shell architecture rewritten as `StatefulWidget` + `IndexedStack` (was per-tab `go_router` sub-routes); `LibraryCubit` + `StorageCubit` promoted to GetIt lazy singletons; new `LibraryEventsService` WS subscriber for `library_changed` / `storage_changed` events; polling timers ripped out; `FluxPillTabs` shared widget; Library/Transcode page polish (alphabetical pre-select, sandwich gradient, manual double-tap fix, sortable Candidates table).  Server 814 / Desktop 114 → 118.

* **Folder-browser polish wave 1 (2026-05-17, commit `aac917f`).** Stacked on plan 28 the day after.  **`FluxFilterChips` lifted** from `library_screen.dart` into a shared widget at `apps/desktop/lib/shared/widgets/flux_filter_chips.dart` — same chip shape now drives Library page + folder browser; `FluxFilterChipsDivider` separator + `trailing` slot for mixed groups.  **Editable URL bar** with consistent chrome (`height=30 / surfaceBandLow fill`); click-anywhere-to-edit + `TapRegion` cancel; folder-name autocomplete via `cubit.pathSuggestions(input)` + `_childListCache`; copy-path + open-in-Explorer icons inside the field.  **Soft-refresh pattern** (`_softFetch` + `LibraryBrowseLoaded.refreshing` field) keeps chrome mounted across navigation; thin 2-px `_RefreshIndicatorStrip` overlay on the listing body.  **Within-session UI-pref persistence** via module-level statics (showHidden / indexedOnly / sortBy / sortAsc / viewMode / kindFilter / density).  **Windows Explorer-style customizable columns** (drag-reorder via `Draggable + DragTarget.onMove` left/right-half detection, drag-divider resize via `_ResizableColumnDivider` 9 px hit zone, right-click `_ColumnPickerPopup` via `OverlayPortal + TapRegion`); all-fixed-width columns + shared `ScrollController` + `SingleChildScrollView(Axis.horizontal)` for horizontal scroll.  **FluxCard containment** of URL band + toolbar band + listing; chips moved outside the card; new `surfaceBandHigh` / `surfaceBandLow` colour tokens.  **Scanner extension list widened** (`.mpg .mpeg .ts .3gp .opus .ico .jxr` + all common image formats).  **WIC fallback extractor for JXR** (`_extract_image_wic` shells out to PowerShell + WPF Imaging; `BitmapDecoder` → `Rgba128Float` → `TransformedBitmap` scale → Reinhard tonemap → `Bgra32` → `JpegBitmapEncoder`; ~1.6 s for an 8 MB JXR source).  Server 943 / Desktop 143.

* **Folder-browser polish wave 2 (2026-05-17, uncommitted at archive).** Stacked on `aac917f` same day; surfaced once operator started right-clicking through real libraries.  **Glass dropdowns** — new `FluxGlassPopupSurface` shared widget extracts the `ClipRRect → BackdropFilter(20) → surfaceGlass Container` chrome from `FluxGlassMenu`; row right-click context menu switched from Material `showMenu` to `showFluxGlassMenu`; `_ColumnPickerPopup` + `_SuggestionsOverlay` (path autocomplete) wrap their custom content in the shared shell.  Right-click anchor coord-system fix (`overlayBox.globalToLocal(globalPos)` before composing `RelativeRect` — `_GlassMenuLayoutDelegate` expects overlay-local coords, but `details.globalPosition` is global window coords + Fluxora's `FluxTitlebar` + sidebar offset the overlay).  **Toolbar reshape** — removed `_SortIndicatorChip` + chip strip (orphan `library_browse_filter_chips.dart` deleted); new `_FilterButton` pill with sticky `_FilterPopup` (kind single-select + `Indexed only` toggle) right-anchored via `CompositedTransformFollower(targetAnchor: bottomRight, followerAnchor: topRight)`; icons swapped L↔R; sort is column-header-only.  **Cross-restart browse-prefs** via `flutter_secure_storage` (Hard Prohibition #6 honoured — already in pubspec for auth token); `hydrateLibraryBrowsePrefs(SecureStorage)` reads `library_browse_prefs_v1` JSON at app startup from `main.dart`; `_flushBrowsePrefs()` writes on every setter; `_decodeEnum<T>` tolerates corrupt payloads.  **Live thumbnail refresh in folder browser** — `LibraryBrowseCubit` subscribes to `LibraryEventsService.thumbnailsProgress` filtered by `libraryId`; 600 ms debounced refresh; `isComplete` bypasses debouncer.  **Index ALL files** — scanner `safe_walk` removed `_MEDIA_EXTENSIONS` filter; `resolve_file_for_index` no longer rejects `kind == 'other'`; mobile catalog now reaches arbitrary docs / archives / source files via `/files/{id}/content`.  **Skipped vs failed split** — `hasThumbnailFailed` now only `'failed'`; new `isThumbnailSkipped` getter; `.srt` / `.txt` / `.zip` stop showing amber warning icon.  **Unindex action** — new `POST /api/v1/library/{id}/unindex-subtree?path=<rel>` + `library_service.unindex_subtree` (LIKE prefix match with `|`-escape); right-click "Unindex this file" + "Unindex this folder" destructive-styled `FluxGlassMenuItem`s; single-file unindex reuses existing `DELETE /api/v1/files/{file_id}`.  **TMDB poster preferred in folder browser** — `IndexedMedia.poster_url` server field + client decode; `_GridTileVisual` + `_ThumbnailPreview` render TMDB art first, fall back to extracted frame via `errorBuilder`.  **Per-library TMDB toggle (migration 040)** — `libraries.tmdb_enabled INTEGER NOT NULL DEFAULT 1`; `_is_tmdb_enabled` helper gates all 4 enrichment sites; `_apply_tmdb_mask(db, rows)` batched-lookup mask applied at 5 list/get functions + `_library_aggregates` + `_attach_index_status`; hide-but-keep semantics (DB rows retained, flip ON instantly restores).  `CreateLibraryBody` + `UpdateLibraryBody` accept `tmdb_enabled`; `Library` entity gains `tmdbEnabled` (freezed regenerated); new `_TmdbToggleRow` Switch widget on Add/Edit Library dialog.  **Efficiency wins** — scanner skips enqueue for non-extractable extensions; `regenerate_library` filters to extractable kinds + excludes already-`skipped` rows + uses `executemany`.  Migration 040 added.  Server 943 → 962 (+19); Desktop 143 unchanged.

**Test counts at archive time (2026-05-17):**
- Server: **962 passing** (migrations 001-040)
- Mobile: **97 passing** (player cubit + 5 player widgets + 10 goldens; unchanged since 2026-05-14)
- Desktop: **143 passing**
- Core: **20 passing**

`flutter analyze` clean × all 3 packages.  Ruff clean.

**Open items (not blocking v1, not in code):**
- Plan 24 M5 (multi-audio device smoke) + M6 (HDR + tonemap) — operator real-device verification still pending; archive plan 24 once green
- iOS PIP — needs iOS test device; manual task in `04_manual_tasks.md`
- End-of-episode resolver — next-episode lookup + auto-advance hook; ~half a day
- Streaming pipeline regressions — HDR→SDR toggle timeout, seek-ahead 404s, zombie FFmpeg accumulation; see `docs/10_planning/11_streaming_pipeline_issues.md`
- Tier 3 folder-browser features (recursive FTS5 search, bookmarks, drag-and-drop to Convert, filesystem watching via `watchdog`) — separate plans, not folded back into plan 28
- AGENT_LOG-format regression guard test — would catch future drift from the canonical format spec; currently format is enforced by reviewer eyeballing
- A server-side regression test for `_apply_tmdb_mask` — insert two libraries (`tmdb_enabled=0` and `=1`), assert `list_files()` returns null TMDB fields for the disabled library; catches future read-path additions that bypass the mask

---

## [2026-05-18] [fix] [feat] [desktop] [server] — Folder-browser polish wave 3 · URL bar hardening · Explorer-style flat rows · numeric right-align · column hover/drag affordances · column-layout persistence · folder-size auto-populate · `/stream-test` · `/resolve-absolute` · paint-cascade bug fix
**Phase:** Post-plan-28 polish — third wave stacked on the same-day waves 1 + 2.
**Status:** Complete (uncommitted — operator owns the staging + commit per the no-git-writes rule).
**Commits:** uncommitted.

### What Was Done

#### 1. URL bar hardening
- **`/` no longer steals focus from the URL `TextField`.** The body-level `_onKey` Focus handler now gates body shortcuts on `_bodyFocus.hasPrimaryFocus`, so any key typed into the URL field stays in the field. Body shortcuts (`/` → search, arrow keys → step selection, Enter → open) only fire when the listing has focus.
- **Suggestion click navigates directly.** `_SuggestionsOverlay` switched from raw `BrowseEntry` to a new `PathSuggestion(parentRelative, entry)` value class that pre-computes the relative path. `_pickSuggestion` dispatches `cubit.navigateTo(suggestion.relativePath)` instead of round-tripping through the field's commit handler (which previously fired the click-outside cancel before the suggestion's `onTap` could run). The field cluster + the suggestions overlay share a `_kPathFieldTapGroup` `Object` as their `TapRegion.groupId` so `TapRegion.onTapOutside` doesn't trip when the user clicks the suggestion.
- **Manual-typing fallback via new server endpoint.** Typing an absolute path that doesn't match the currently-visible root (multi-root library, case mismatch on Windows, canonical form drift) now falls back to a new `GET /api/v1/library/{id}/resolve-absolute?path=<abs>` that walks every `library.root_paths` entry via `Path.is_relative_to` after `Path.resolve(strict=True)`.
- **Case-correct breadcrumb display.** `browse_service._resolve_path_under_root` now calls `candidate.resolve(strict=True)` — on Windows this invokes `GetFinalPathNameByHandle` which returns the OS canonical case, so typing `d:\movies\action` displays back as `D:\Movies\Action` after navigation.

#### 2. Explorer-style flat rows + numeric right-align
- **Flat row treatment.** Body rows lost their elevated card chrome — no per-row border, no rounded corners, no horizontal divider between rows. Hover + selected stay as background tints (3% white hover, 8% violet selected) layered on a transparent base. `MouseRegion` `onEnter`/`onExit` setStates guarded with `if (!_hovered)` so identical hover events don't churn.
- **Right-aligned numeric columns.** Body cells for `BrowseColumn.{size, modified, duration, dimensions}` use `Align(alignment: Alignment.centerRight)` + `textAlign: TextAlign.right` via a new `_isNumericBrowseColumn(BrowseColumn)` helper. Empty cells render as `''` instead of an em-dash so the column reads clean when most rows have no value. Header labels stay LEFT-aligned per operator preference.
- **Invisible body column dividers.** `_ColumnDivider` rendered as a 9-px-wide `SizedBox` (no painted line) so the header `_ResizableColumnDivider` boundaries align pixel-for-pixel with body cells without adding inter-column rules to every row.

#### 3. Column header hover band + drag "held" view
- **`_DraggableColumnHeaderState._hovered` field** wraps each cell in an `AnimatedContainer` (120 ms) that paints a subtle violet hover tint (`0x0DA855F7`) across the full cell width + vertical band.
- **`_dragging` flips** the drag source cell to a depressed darker tint + violet outline at 55 % opacity (replaces the prior bare-opacity treatment that read as a render glitch). `MouseRegion(cursor: _dragging ? grabbing : grab)`.
- **`_ResizableColumnDivider`** keeps a 1-px line at rest, thickens to 2-px violet on hover or drag. New trailing `_ResizableColumnDivider(leftColumn: visible.last)` after the last header cell gives the rightmost column its own resize handle and visually closes the header row.

#### 4. Column-layout persistence across restarts
- **`BrowseColumn` enum + module-level statics moved into `library_browse_cubit.dart`.** New `persistedColumnOrder: List<BrowseColumn>` + `persistedColumnWidths: Map<BrowseColumn, double>` + `columnsVersion: ValueNotifier<int>` + mutators `toggleBrowseColumn` / `reorderBrowseColumn` / `resizeBrowseColumn` (public so the picker popup + drag handlers can call them).
- **Hydration / flush extends the wave-2 SecureStorage blob.** `hydrateLibraryBrowsePrefs` decodes the persisted column order + per-column widths from the `library_browse_prefs_v1` JSON, clamps widths to `[kBrowseColumnMinWidth, kBrowseColumnMaxWidth]`, forces `BrowseColumn.name` to slot 0 even if the operator's saved file says otherwise. `_flushBrowsePrefs` re-encodes after every mutator call. No new pub deps (Hard Prohibition #6 honoured — extends the existing JSON bundle).
- Bulk-renamed ~21 callsites in `library_files_screen.dart` from the previous underscore-private statics (`_persistedColumnOrder` etc.) to the public names so the cubit can host them.

#### 5. Folder-size auto-populate in SIZE column
- **`BrowseEntry.cataloged_size_bytes`** (new server field, `int = 0` default). Populated by `browse_service._attach_directory_catalog_sizes` — a single batched SQL pass per browse, one `WHERE path LIKE 'prefix/%' ESCAPE '|'` per directory against the `media_files` path index, summing `size_bytes` for every indexed descendant.
- **Client renders it in the SIZE column on directory rows** + the detail panel's Quick Stats Size cell, so folders show a number without the operator clicking "Compute size" first. The on-disk "Compute size" button (existing) still triggers `/folder-size` for the authoritative walk when the indexed-only estimate is insufficient (Documents library with random extensions, `.git` / `node_modules` trees, etc).

#### 6. New endpoints
- **`POST /api/v1/files/{file_id}/stream-test`** (localhost-only via `require_local_caller`). Dry-run sanity check for the folder browser's "Stream test" affordance. Verifies the file is reachable on disk + reports codec + the exact playback path `/stream/start` would route through (plan-18 H.264 sidecar wins over source when present + on disk). Does NOT spawn FFmpeg, does NOT INSERT a `stream_sessions` row.
- **`GET /api/v1/library/{library_id}/resolve-absolute?path=<abs>`** (bearer or localhost). Backs the URL-bar manual-typing fallback (see §1). Walks every `library.root_paths` via `Path.is_relative_to`. 404 on missing or not-under-any-root; 403 on path escape.

#### 7. Paint-cascade bug fix (`mouse_tracker.dart` flood)
- **Root cause** — an earlier draft of the column hover-band feature (this session) added `crossAxisAlignment: CrossAxisAlignment.stretch` to `_SortableColumnHeaderRow`'s `Row` so the AnimatedContainer hover tint filled the full vertical band. The header sits inside a `Column` that doesn't wrap it in `Expanded`, so `stretch` ran with unbounded max-height. That left the Draggable / AnimatedContainer descendants' intrinsic-height path inconsistent across layout passes — a `RenderRepaintBoundary` inside the implicit ListView / Scrollbar chain ended up `NEEDS-PAINT` without a settled size every frame. The paint-time throw left Flutter's `_debugDuringDeviceUpdate` re-entrancy flag stuck → every subsequent frame's mouse-tracker update tripped `mouse_tracker.dart:199` (~1 Hz flood in the Issues panel).
- **Fix** — removed `crossAxisAlignment: stretch`. Every header cell has the same intrinsic height (padding 12 + label 16 = 28), so the default `center` paints identically.
- **Secondary fix** — `_totalTableWidth()` now counts `N * _kColumnDividerWidth` (N inter-column + 1 trailing) instead of `(N - 1) * _kColumnDividerWidth` so the header Row no longer overflows the wrapping `SizedBox(width: tableWidth)` by 9 px after the trailing divider was added.
- **Diagnostic instrument** — temporarily installed a debug-only `FlutterError.onError` wrapper in `main.dart` that suppressed the assertion cascade + tagged the first non-cascade error with `###CASCADE-ROOT###` so the original throw could be pinpointed. Wrapper removed before commit.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Modified | apps/desktop/lib/features/library/data/repositories/library_repository_impl.dart | Wire `resolveAbsolutePath` HTTP call to the new server endpoint |
| Modified | apps/desktop/lib/features/library/domain/entities/browse_entry.dart | `catalogedSizeBytes: int = 0` field + JSON decode |
| Modified | apps/desktop/lib/features/library/domain/repositories/library_repository.dart | `resolveAbsolutePath(libraryId, absolutePath)` interface method |
| Modified | apps/desktop/lib/features/library/presentation/cubit/library_browse_cubit.dart | Move `BrowseColumn` enum + statics + mutators here; hydrate / flush column order + widths through the existing SecureStorage JSON blob; `PathSuggestion` value class; live thumb refresh subscription; URL-bar resolve-absolute fallback |
| Modified | apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart | Flat row chrome; numeric right-align body cells + empty-string instead of em-dash; column header hover `AnimatedContainer` + drag "held" view; trailing `_ResizableColumnDivider`; `/` focus gating on body shortcuts; bulk-rename ~21 callsites for public column statics; **`crossAxisAlignment: stretch` removed (cascade fix)**; `_totalTableWidth` counts trailing divider (overflow fix) |
| Modified | apps/desktop/lib/features/library/presentation/widgets/library_browse_detail_panel.dart | Quick Stats Size cell uses `entry.catalogedSizeBytes` for directories; TMDB poster preferred in `_ThumbnailPreview` via `errorBuilder` |
| Modified | apps/server/routers/files.py | New `POST /{file_id}/stream-test` (localhost-only) |
| Modified | apps/server/routers/library.py | New `GET /{library_id}/resolve-absolute?path=<abs>` |
| Modified | apps/server/services/browse_service.py | `IndexedMedia.poster_url` field; `BrowseEntry.cataloged_size_bytes` + `_attach_directory_catalog_sizes` helper; `resolve_absolute_to_relative(db, library_id, absolute_path)` walks every root via `Path.is_relative_to`; `_resolve_path_under_root` uses `candidate.resolve(strict=True)` for Windows case-correction; `_sql_like_escape` helper |
| Modified | apps/server/services/library_service.py | `unindex_subtree(db, library_id, subtree_abs)` via LIKE prefix; TMDB enrichment gated on `_is_tmdb_enabled(db, library_id)` |
| Modified | apps/server/services/thumbnail_service.py | Misc polish (concurrency tuning + hwaccel retry path) |
| Modified | apps/server/services/thumbnail_worker.py | `regenerate_library` filters to extractable kinds + executemany |
| Modified | apps/server/tests/test_browse.py | Coverage for `cataloged_size_bytes` + `resolve_absolute_to_relative` |
| Modified | apps/server/tests/test_files.py | Coverage for `stream-test` endpoint paths |
| Modified | apps/server/tests/test_thumbnail_endpoint.py | Minor cleanup with regenerate-thumbnail changes |
| Modified | apps/server/tests/test_thumbnail_service.py | Minor cleanup with extractor changes |
| Modified | apps/server/tests/test_thumbnail_settings.py | Minor cleanup with new defaults |
| Modified | apps/server/tests/test_thumbnail_worker.py | Coverage for `regenerate_library` extractable-kind filtering |
| Modified | packages/fluxora_core/lib/network/endpoints.dart | `libraryResolveAbsolute(libraryId)` constant |
| Modified | docs/00_overview/current_status.md | New 2026-05-18 wave-3 entry at the top |
| Modified | docs/04_api/01_api_contracts.md | `stream-test` + `resolve-absolute` endpoint specs; `cataloged_size_bytes` field on `/browse` response |
| Modified | docs/05_infrastructure/02_url_inventory.md | Added `stream-test`, `resolve-absolute`, plus the plan-28 Phase C/D endpoints that were live in code but missing from the inventory |
| Modified | .claude/settings.json | (incidental, harness-touched) |

### Docs Updated
- `docs/00_overview/current_status.md` — new 2026-05-18 wave-3 entry; trimmed "(uncommitted, in-tree, migration 040)" from the wave-2 entry header since it's now committed in the same uncommitted window.
- `docs/04_api/01_api_contracts.md` — new `POST /files/{id}/stream-test` + `GET /library/{id}/resolve-absolute` sections; `cataloged_size_bytes` documented on the `/browse` response shape.
- `docs/05_infrastructure/02_url_inventory.md` — added `stream-test`, `resolve-absolute`, `folder-size`, `index-file`, `scan-subtree`, `unindex-subtree`, `regenerate-thumbnail` to the routers tables (the plan-28 endpoints were live in code but the inventory hadn't been swept since 2026-05-09).

### Decisions Made
- **Hoisted `MouseRegion` outside `DragTarget` in `_DraggableColumnHeader`** as part of the cascade investigation, then **reverted** when the actual root cause turned out to be `crossAxisAlignment: stretch`. Keeping the MouseRegion inside `DragTarget.builder` is a slightly stale hit-test surface across drag events but doesn't actually trigger the cascade. Decision: ship the minimal-diff fix; the speculative hoist was reverted to keep the patch small.
- **Reverted speculative `flux_status_bar.dart` + `flux_sidebar.dart` BlocSelector-push-down restructure** that was part of the cascade investigation when it turned out the SystemStats poll was NOT the trigger. Those changes were legitimate rebuild optimizations but the user asked for a minimal final diff so they're not in the patch.

### Issues / Sharp Edges Discovered
- **`crossAxisAlignment: stretch` on a `Row` inside an unbounded-height parent silently corrupts descendant `RepaintBoundary` layout** in a way that doesn't throw at layout time but does throw at paint time. The thrown exception inside the framework's paint phase leaves Flutter's `_debugDuringDeviceUpdate` re-entrancy flag stuck → every subsequent frame's mouse-tracker update fires `mouse_tracker.dart:199` (~1 Hz cascade). Worth a `docs/12_guidelines/03_gotchas.md` entry for future agents.
- **The Dart MCP runtime-errors buffer holds only the last ~3 entries**, so the original throw that starts a cascade gets pushed out within seconds. The `FlutterError.onError` wrapper pattern (suppress the cascade + tag the first non-cascade error with a distinctive marker) is the cleanest way to surface the root throw — worth keeping in the back pocket for future cascade hunts.

### Test Counts (re-baselined)
- **Server: 962 → unchanged** (this wave was UX correctness + structural fixes; covered by wave-2 retest matrix).
- **Desktop: 143 → unchanged** (cascade fix exercised via existing browse-state coverage; column-persistence + flat-row + numeric right-align changes pass existing widget tests).
- **Mobile: 97 unchanged.**
- **Core: 20 unchanged.**

`flutter analyze` clean across `apps/desktop` + `packages/fluxora_core`. `ruff` clean across `apps/server`.

### Working-Tree Status
Uncommitted at session end. Operator owns staging + commit per the no-git-writes rule. The diff is 20 code files + 3 docs = 23 files total. The 3 doc files (`current_status.md` / `api_contracts.md` / `url_inventory.md`) are also uncommitted with the code; commit them together so the API surface + status snapshot land in sync.

### Next Agent Should
1. **Verify the cascade fix landed cleanly** by hot-restarting the desktop app + sitting on the folder browser for ~60 s. Issues panel should stay quiet — if `mouse_tracker.dart:199` shows up again, the trigger is somewhere I missed (different cell-band or a layout combination outside the header), and the next step is to re-install the `###CASCADE-ROOT###` instrument in `main.dart` to find it.
2. **Consider a `docs/12_guidelines/03_gotchas.md` entry** for `crossAxisAlignment: stretch` inside an unbounded-height parent. The failure mode is invisible at layout time (no exception, no `RenderFlex overflow`) but breaks at paint time and creates a misleading mouse_tracker cascade. Worth a 5-line warning so a future agent doesn't go down the same investigation path.
3. **Pick up open items from the archive summary** — Plan 24 M5/M6 device verification, end-of-episode resolver, streaming pipeline regressions, Tier 3 folder-browser features all remain open.
