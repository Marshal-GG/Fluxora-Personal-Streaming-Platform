# Library Screen — Audit & Implementation Plan

> Status: 🟢 P0 + P1 SHIPPED · 2026-05-03
> Scope: `apps/desktop` Library surface only. Mobile Library tab uses mock data and is tracked separately under mobile redesign M11.
> Owner decision required before any code lands. Marked `[D#]` items are open questions.

This page tracks every gap found during the 2026-05-03 audit of `apps/desktop/lib/features/library/`. The Library screen is **navigable but functionally inert** — buttons exist, most do nothing.

---

## Audit summary

| Area | Working | Broken / missing |
|------|---------|------------------|
| List + filter by type | ✅ | Photos tab is dead (no enum value) |
| Stat tiles row | ✅ | — |
| Library detail panel | partial | Per-library file count + size show `—`; pencil-edit is decorative |
| Add | ✅ | Single-folder only; no error UI; no validation toast |
| Scan | ✅ | Silent — `files_added` not surfaced |
| **Delete** | ❌ | Server route exists; cubit + UI not wired (shows "not implemented" snackbar) |
| **Edit** | ❌ | No server route, no UI |
| **Posters / artwork** | ❌ | Cards are flat gradients only |
| **File browser** | ❌ | Action is `onTap: () {}`; no screen exists |
| Sort / Filter / List view | ❌ | All `onPressed: () {}` placeholders |
| Description field | ❌ | Empty container; no input, no server field |
| Rescan Metadata | ❌ | `enabled: false`; no endpoint |
| Upload | ❌ | Cubit method exists; no UI entry point |

---

## P0 — Ship blockers for "Library actually works"

### 1. Wire Delete end-to-end
- **Server:** `DELETE /api/v1/library/{id}` already exists at [`apps/server/routers/library.py:96`](../../apps/server/routers/library.py) — returns 204, records `library.delete` activity event. **No backend work.**
- **Repository:** add `Future<void> deleteLibrary(String id)` to `LibraryRepository` + `LibraryRepositoryImpl` (`DELETE` via `ApiClient`).
- **Cubit:** add `Future<void> deleteLibrary(String id)` — call repo, then optimistically drop from local state list (avoid full `load()` flash); catch + rethrow on error.
- **UI:** replace `_confirmRemove`'s snackbar with a real `AlertDialog` — title "Remove library?" + body "This cannot be undone. Files on disk are not deleted." + cancel/destructive-confirm buttons. On success, clear `_selectedLibrary` if it matched. On failure, show error snackbar with message.
- Files: `library_repository.dart`, `library_repository_impl.dart`, `library_cubit.dart`, `library_screen.dart`.

### 2. Wire Edit (rename / re-root)
- **Server:** **add** `PATCH /api/v1/library/{id}` accepting `{name?, root_paths?}`. Append migration / not needed (column-level update only). Record `library.update` activity event.
- **Repository:** add `Future<Library> updateLibrary({required String id, String? name, List<String>? rootPaths})`.
- **Cubit:** add `Future<void> updateLibrary(...)` mirror of `createLibrary`.
- **UI:** make the pencil icon at [`library_screen.dart:947`](../../apps/desktop/lib/features/library/presentation/screens/library_screen.dart#L947) tappable; open a dialog identical to Add but pre-filled, with optional add/remove root paths. Saving triggers `updateLibrary` and refreshes the detail panel.
- Files: new server route + tests; `library_repository.dart`, `library_repository_impl.dart`, `library_cubit.dart`, `library_screen.dart`.

### 3. Real per-library statistics in detail panel
- **Server change:** extend `LibraryResponse` with `total_size_bytes: int` (sum of `media_files.size_bytes` filtered by `library_id`). `library_service.list_libraries` / `get_library` queries already join file counts — extend the same SQL with `SUM(size_bytes)`. Default to `0` for empty libs.
- **Entity:** add `int? fileCount` and `int? totalSizeBytes` to `Library` in `packages/fluxora_core/lib/entities/library.dart`. **Run `dart run build_runner build --delete-conflicting-outputs`** for `fluxora_core`.
- **UI:** wire `_DetailRow` rows in [`library_screen.dart:1019-1020`](../../apps/desktop/lib/features/library/presentation/screens/library_screen.dart#L1019-L1020) to `library.fileCount?.toString() ?? '—'` and `_humanBytes(library.totalSizeBytes ?? 0)`. Reuse `_humanBytes` already defined in `_StatTilesRow`.
- Files: server `models/library.py`, `services/library_service.py`, server tests; `packages/fluxora_core/lib/entities/library.dart`, regenerated `library.freezed.dart` + `library.g.dart`; `library_screen.dart`.

### 4. Real artwork on library cards (the "no pictures" complaint)
Two viable approaches — owner picks `[D1]`:

| Option | How | Pros | Cons |
|--------|-----|------|------|
| **A. Client-side mosaic** | After `load()`, the cubit picks 1–4 newest enriched poster URLs per library from `state.files` filtered by `libraryId` and exposes them as `Map<String, List<String>>`. Card replaces the gradient with a 2×2 poster mosaic (or 1× hero for movies/tv) with a soft gradient overlay. | Zero backend work; uses what's already loaded. | Requires `files` list to actually be populated for that lib (so a library that hasn't been scanned shows nothing); breaks if `files` list is large (current load is unbounded). |
| **B. Server-computed `cover_urls`** | Add `cover_urls: list[str]` to `LibraryResponse` — server returns up to 4 `poster_url`s from the most-recently-modified enriched files in that library. | Cards render from the list response alone — no need to load files. | New server work; new field; requires extra SQL aggregation. |

**Recommendation: A first** (one PR, no backend), B as a later optimization once we paginate `/api/v1/files`.

For libraries with no enriched posters (music, files), keep the existing gradient + larger icon — but add a subtle `file_count` badge in the bottom-right.

- Files: `library_cubit.dart`, `library_state.dart` (add `posterUrlsByLibrary`), `library_screen.dart` (`_LibraryCard` build).

### 5. Files browser route + screen
- **New screen:** `apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart` — header (library name, breadcrumb back to Library), 4 stat chips (file count, total size, last scanned, type), table with columns (`name` / `extension` / `size` / `duration` / `created`) reusing the existing `MediaFile` shape and **scoped to the loaded `files` list filtered by `libraryId`**. No new endpoint required (`getFiles(libraryId:)` already supports the filter).
- **Routing:** add `/library/:id/files` in `app_router.dart`. Wire the "View Library Files" action at [`library_screen.dart:1054`](../../apps/desktop/lib/features/library/presentation/screens/library_screen.dart#L1054) to `context.go('/library/${library.id}/files')`.
- Add a Cmd+K command "Open library files: <name>" for each library while we're there.
- Files: new screen + route entry + 1 line in Cmd+K command list.

---

## P1 — Dead surfaces to either implement or remove

### 6. Photos tab — remove or implement `[D2]`
The "Photos" tab at [`library_screen.dart:52`](../../apps/desktop/lib/features/library/presentation/screens/library_screen.dart#L52) maps to no `LibraryType`, so the tab is always empty.

- **Drop:** delete the tab definition (1-line change). Recommended unless owner has near-term plans.
- **Implement:** add `photos` to `LibraryType` enum + server `type` Literal + scanner support for image extensions. ~1 day of work + new tests.

### 7. Sort + Filter buttons
- Sort: implement client-side sort over `_visibleLibraries` by Name / Date Created / File Count / Total Size. Pop a `PopupMenuButton` on click.
- Filter: open a `FluxBottomSheet`-style overlay with checkboxes (`enriched only`, `with files`, `recently scanned`). Filter is purely client-side over the same list.
- If we don't want to ship these now, **remove the buttons entirely** rather than leave dead controls.

### 8. Grid / List view toggle
The list-view icon at [`library_screen.dart:374-381`](../../apps/desktop/lib/features/library/presentation/screens/library_screen.dart#L374-L381) is unclickable. Either:
- **Implement** a list view (single-row per library: type icon + name + path + file count + size + scan/edit/delete actions inline). One `_LibraryList` widget; toggle stored in `_LibraryViewState`.
- **Remove** the toggle for now and only render the grid.

### 9. Card `more_horiz` context menu
The dots icon at [`library_screen.dart:763`](../../apps/desktop/lib/features/library/presentation/screens/library_screen.dart#L763) suggests an action. Implement as `PopupMenuButton` (Open files / Scan / Edit / Remove) — duplicates detail-panel actions but is faster for users who want to act without selecting first.

### 10. Description field
[`library_screen.dart:992-1006`](../../apps/desktop/lib/features/library/presentation/screens/library_screen.dart#L992-L1006) is an empty container. To make it real:
- Server: add `description: str | None` column on `libraries` table — append-only migration.
- Editable inline (click → `TextField`, blur → `PATCH`).
- Or **delete the block** if we don't want this field.

### 11. Rescan Metadata action
Currently `enabled: false`. To enable:
- Server: add `POST /api/v1/library/{id}/rescan-metadata` that re-runs TMDB enrichment for every existing file (skips disk scan).
- Cubit + repo passthrough.
- Without this, the action should just be **removed** from the panel — `enabled: false` rows are clutter.

### 12. Surface scan results
After `scan_library` resolves, the response has `files_added: N`. Today the cubit just reloads. Add: snackbar "Scan complete — N files added" on success, error snackbar on failure. Same for create / update / delete.

### 13. Per-tab empty state
When a tab has zero libraries, [`_LibraryGrid`](../../apps/desktop/lib/features/library/presentation/screens/library_screen.dart#L548) just shows the Add tile. Add a `_TabEmptyState` widget with type-specific copy: "No movies libraries yet. Add a folder of movies to get started."

---

## P2 — Nice-to-haves

### 14. Multi-root in Add dialog
Server accepts `List<String>`; UI offers one folder. Add a "+" button to append more paths before submitting.

### 15. Validation in Add dialog
Empty name silently no-ops. Show inline `errorText` and disable Submit until valid.

### 16. Optimistic mutation state
`load()` after every mutation flashes the loader. Update local list in-place on create/update/delete (with rollback on error) for snappier UX.

### 17. Drag-and-drop folder onto card
Drop a folder onto an existing library card → adds the path as an additional root. Uses `desktop_drop` package (need to evaluate).

### 18. Upload UI
`LibraryCubit.uploadFile` exists. Add a "+ Upload file" entry on the file browser screen (not the library list) so it lives next to the file table.

---

## Backend changes summary

| Change | Required for | Migration? |
|--------|--------------|------------|
| `LibraryResponse.total_size_bytes` | P0 #3 | No (computed in SQL) |
| `PATCH /api/v1/library/{id}` | P0 #2 | No |
| `LibraryResponse.cover_urls` | P0 #4 (Option B only) | No |
| `LibraryResponse.description` + `libraries.description` column | P1 #10 | **Yes** — append-only migration |
| `POST /api/v1/library/{id}/rescan-metadata` | P1 #11 | No |
| `LibraryType.photos` | P1 #6 | Possibly (scanner config) |

All changes are **additive** — no existing API contract breaks.

---

## Decisions (resolved 2026-05-03)

- **[D1] ✅ Option A** — client-side poster mosaic (no backend work).
- **[D2] ✅ Drop** — Photos tab removed from `_kTabs`.
- **[D3] ❌ Drop** — description field not shipped. Names + types convey enough; an empty column adds migration cost for marginal value.
- **[D4] ❌ Drop** — Rescan Metadata action removed. Full `Scan` already re-enriches new files; rare full-resweep need is covered by Delete + Re-scan.
- **[D5] ✅ Implement** — Sort (Name / Last Scanned / File Count / Total Size), Filters (enriched only · with files · recently scanned), Grid/List view toggle all shipped.
- **[D6] ✅ Locked: name + root paths only** — type is **immutable** after creation. Type changes would orphan or mis-render scanned files. To switch types, delete + recreate.
- **[D7] 🔒 LOCKED: Files on disk are NEVER deleted by Fluxora.** Delete only removes the library entry + file index from the database. The server has no file-deletion code; this policy is enforced by the absence of any `os.remove` / `shutil.rmtree` / `Path.unlink` call on the library track. Confirm dialog copy reflects this explicitly. **This rule does not change without an ADR.**

---

## Effort estimate (P0 only, assuming D1=A and the rest of P1 deferred)

| Task | Effort |
|------|--------|
| #1 Delete (repo + cubit + dialog) | ~1 h |
| #2 Edit (server route + tests + repo + cubit + dialog) | ~3 h |
| #3 Per-library stats (server SUM + entity regen + UI) | ~2 h |
| #4 Client-side poster mosaic | ~2 h |
| #5 Files browser route + screen | ~3 h |
| Wiring + analyze + tests | ~1 h |
| **Total** | **~12 h / ~1.5 days** |

P1 surface decisions land in a separate sweep once the owner answers `[D2]`–`[D5]`.

---

## Files that will change (P0)

```
apps/server/routers/library.py             (PATCH route)
apps/server/services/library_service.py    (update_library, total_size_bytes)
apps/server/models/library.py              (UpdateLibraryBody, total_size_bytes)
apps/server/tests/test_library.py          (PATCH + size tests)

packages/fluxora_core/lib/entities/library.dart           (fileCount, totalSizeBytes)
packages/fluxora_core/lib/entities/library.freezed.dart   (regen)
packages/fluxora_core/lib/entities/library.g.dart         (regen)

apps/desktop/lib/features/library/domain/repositories/library_repository.dart
apps/desktop/lib/features/library/data/repositories/library_repository_impl.dart
apps/desktop/lib/features/library/presentation/cubit/library_cubit.dart
apps/desktop/lib/features/library/presentation/cubit/library_state.dart
apps/desktop/lib/features/library/presentation/screens/library_screen.dart
apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart  (NEW)
apps/desktop/lib/app/app_router.dart                                              (route)
apps/desktop/lib/features/command_palette/...                                     (Cmd+K entries)
```

---

## Cross-references

- `docs/10_planning/01_roadmap.md` — Library is in Phase 1 ("Done") but functionally only Add+Scan are real.
- `docs/00_overview/current_status.md` line 64 currently states "Library (create/scan/upload/filter) ✅" — this is misleading; once P0 lands, line should read "Library (create/scan/edit/delete/browse files + posters)".
- `docs/04_api/01_api_contracts.md` — needs the new `PATCH` route + `total_size_bytes` field documented.
