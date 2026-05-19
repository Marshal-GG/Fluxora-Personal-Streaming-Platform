import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_desktop/features/library/data/services/library_events_service.dart';
import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';

/// Sortable columns in the folder browser.  Phase A of plan 28.
enum BrowseSortColumn { name, size, modified }

/// Two display modes for the folder browser body.  Phase A of plan 28.
enum BrowseViewMode { list, grid }

/// Row-density for the listing.  `comfortable` is the default and
/// matches the Phase A row height (44 px in list view, 200 px tile in
/// grid view).  `compact` shrinks to ~28 px rows / ~140 px tiles for
/// scanning huge directories without scrolling.  `cosy` sits in
/// between (~38 px rows / ~170 px tiles).
enum BrowseDensity { compact, cosy, comfortable }

/// Type-filter chip values for the chip group.  `all` is the default;
/// any other value restricts the visible entries to the matching
/// [BrowseKind] (or directories for `folders`).  Phase B of plan 28.
enum BrowseKindFilter {
  all,
  folders,
  videos,
  images,
  audio,
  pdfs,
  other;

  /// Whether an entry of the given [BrowseKind] passes this filter.
  /// Folders are special-cased: only `all` + `folders` admit them.
  bool admits(BrowseEntry entry) {
    if (this == BrowseKindFilter.all) return true;
    if (this == BrowseKindFilter.folders) return entry.isDir;
    if (entry.isDir) return false;
    return switch (this) {
      BrowseKindFilter.videos => entry.kind == BrowseKind.video,
      BrowseKindFilter.images => entry.kind == BrowseKind.image,
      BrowseKindFilter.audio => entry.kind == BrowseKind.audio,
      BrowseKindFilter.pdfs => entry.kind == BrowseKind.pdf,
      BrowseKindFilter.other => entry.kind == BrowseKind.other,
      BrowseKindFilter.all || BrowseKindFilter.folders =>
        true, // unreachable; covered above
    };
  }
}

/// Drives the folder-browser surface inside the library files screen.
///
/// State splits in two:
/// * **Async fetch state** — sealed [LibraryBrowseState] (Initial /
///   Loading / Loaded / Failure) that wraps the server response.
/// * **UI prefs** — selection / sort / view-mode / search / hidden /
///   indexed-only stored as plain fields on the cubit instance.
///   Pure prefs don't trigger network reloads (they re-emit Loaded
///   with the same response so the UI re-renders).  Only show-hidden
///   round-trips to the server since it changes which entries are
///   in the response.
///
/// Process-wide persisted UI preferences for the folder browser.
///
/// `LibraryBrowseCubit` is constructed fresh on every screen mount
/// (one cubit per `/library/{id}/files` open), so plain instance
/// fields would reset every time the operator navigates away and
/// back.  These module-level statics hold the last-known values + the
/// cubit's constructor seeds itself from them; mutating setters
/// write back so the next mount picks up the operator's choices.
///
/// Cross-restart persistence: [hydrateLibraryBrowsePrefs] runs once
/// at app startup (from `main.dart` after the DI container is built)
/// + populates the statics from a single JSON blob stored in
/// [SecureStorage].  Mutating setters then call [_flushBrowsePrefs]
/// which re-encodes the bundle + writes it back.  We use
/// `flutter_secure_storage` because it's already in the pubspec for
/// the auth token (Hard Prohibition #6 — no new pub deps for the
/// sake of it); the small per-write encrypt overhead doesn't matter
/// for a once-per-toggle bool / enum write.
bool _persistedShowHidden = false;
bool _persistedIndexedOnly = false;
BrowseSortColumn _persistedSortBy = BrowseSortColumn.name;
bool _persistedSortAsc = true;
BrowseViewMode _persistedViewMode = BrowseViewMode.list;
BrowseKindFilter _persistedKindFilter = BrowseKindFilter.all;
BrowseDensity _persistedDensity = BrowseDensity.comfortable;

/// Backing storage handle.  Assigned by [hydrateLibraryBrowsePrefs];
/// stays null in tests + during the brief window before the hydrate
/// call lands, in which case [_flushBrowsePrefs] becomes a no-op (the
/// statics still update in-memory so the current session sees the
/// change).
SecureStorage? _persistedStorage;

/// Debounce timer for browse-prefs persistence.  Column-resize drags
/// fire setters 50+ times per second; coalesces to one write 400 ms
/// after the last mutation so secure-storage's platform channel
/// isn't hammered.
Timer? _browsePrefsFlushDebounce;

/// Circuit-breaker — flipped to `false` the first time a write
/// rethrows (corrupt secure-storage file, locked DAT, DPAPI failure).
/// Subsequent flushes return early so the in-memory statics keep
/// updating but the platform channel no longer spams identical
/// failures.  Resets on process restart.
bool _browsePrefsWritable = true;

// ── Folder-browser column layout ──────────────────────────────────────────
//
// Operator-configurable list of which columns appear in the desktop
// folder browser's listing + their pixel widths.  Mutators here own
// both the in-memory statics + the SecureStorage flush so the screen
// just calls the public mutator after each toggle / drag / resize.
//
// Defaults match the original 3-column layout (Name / Size / Modified)
// so first launch looks identical to before the column-customisation
// feature shipped.

/// Visible columns in the folder browser's row table.  `name` is
/// pinned to slot 0 and can't be toggled off (it's the entry's primary
/// identifier).  Every other column toggles independently via the
/// right-click column-picker popup.
enum BrowseColumn {
  name,
  size,
  modified,
  kind,
  indexed,
  codec,
  dimensions,
  duration,
}

/// Default pixel width for each column when the operator hasn't set
/// an explicit override.  Name's "default" is the width it lands at
/// the first time it's resized (it ships as flexible / Expanded).
double defaultBrowseColumnWidth(BrowseColumn col) => switch (col) {
      BrowseColumn.name => 280,
      BrowseColumn.size => 100,
      BrowseColumn.modified => 160,
      BrowseColumn.kind => 90,
      BrowseColumn.indexed => 110,
      BrowseColumn.codec => 80,
      BrowseColumn.dimensions => 110,
      BrowseColumn.duration => 90,
    };

/// Process-wide persisted display order of enabled listing columns.
/// Iteration order IS the on-screen left-to-right order; mutable via
/// drag-and-drop on column headers (handled by [reorderBrowseColumn]).
List<BrowseColumn> persistedColumnOrder = [
  BrowseColumn.name,
  BrowseColumn.size,
  BrowseColumn.modified,
];

/// Operator-overridden widths for fixed-size columns.  Empty by
/// default — columns fall back to [defaultBrowseColumnWidth].  Set by
/// [resizeBrowseColumn] when the operator drags a column-header's
/// right-edge resize handle.
Map<BrowseColumn, double> persistedColumnWidths = {};

/// Bumps every time the column set or any width mutates.  Widgets
/// that depend on the column layout (header row + visible body rows)
/// wrap themselves in a [ValueListenableBuilder] against this so a
/// toggle / drag / resize repaints them on the same frame, instead
/// of waiting for each row to re-build for an unrelated reason.
final ValueNotifier<int> columnsVersion = ValueNotifier(0);

const double kBrowseColumnMinWidth = 60;
const double kBrowseColumnMaxWidth = 360;

bool isBrowseColumnEnabled(BrowseColumn col) =>
    persistedColumnOrder.contains(col);

void toggleBrowseColumn(BrowseColumn col) {
  if (col == BrowseColumn.name) return; // locked
  if (persistedColumnOrder.contains(col)) {
    persistedColumnOrder = [...persistedColumnOrder]..remove(col);
  } else {
    persistedColumnOrder = [...persistedColumnOrder, col];
  }
  columnsVersion.value = columnsVersion.value + 1;
  _flushBrowsePrefs();
}

/// Move [moved] adjacent to [target] inside [persistedColumnOrder].
/// [placeAfter] picks whether the moved column lands to the RIGHT
/// (true) or LEFT (false) of target — driven by which half of
/// target's cell the operator dropped on, Windows Explorer style.
/// Name is pinned to slot 0; attempts to move Name or drop onto Name
/// are ignored.
void reorderBrowseColumn(
  BrowseColumn moved,
  BrowseColumn target, {
  bool placeAfter = false,
}) {
  if (moved == target) return;
  if (moved == BrowseColumn.name) return;
  if (target == BrowseColumn.name) return;
  final list = [...persistedColumnOrder];
  final fromIdx = list.indexOf(moved);
  if (fromIdx < 0) return;
  list.removeAt(fromIdx);
  // After the removal the target's index may have shifted left by one
  // — read it fresh from the post-removal list so the insert slot is
  // always correct regardless of drag direction.
  final targetIdx = list.indexOf(target);
  if (targetIdx < 0) return;
  list.insert(placeAfter ? targetIdx + 1 : targetIdx, moved);
  persistedColumnOrder = list;
  columnsVersion.value = columnsVersion.value + 1;
  _flushBrowsePrefs();
}

double effectiveColumnWidth(BrowseColumn col) =>
    persistedColumnWidths[col] ?? defaultBrowseColumnWidth(col);

void resizeBrowseColumn(BrowseColumn col, double newWidth) {
  final clamped =
      newWidth.clamp(kBrowseColumnMinWidth, kBrowseColumnMaxWidth);
  if ((persistedColumnWidths[col] ?? defaultBrowseColumnWidth(col)) == clamped) {
    return;
  }
  persistedColumnWidths = {...persistedColumnWidths, col: clamped};
  columnsVersion.value = columnsVersion.value + 1;
  _flushBrowsePrefs();
}

/// Read the persisted browse prefs from [storage] + populate the
/// module-level statics.  Call once at app startup from
/// `main.dart` after `setupInjector()` so the first cubit mount sees
/// the operator's last-saved values instead of the defaults.
///
/// Tolerant of corrupt / partial payloads: any missing or
/// unparseable field falls back to its default.  Never throws —
/// failing to hydrate just leaves the defaults in place + logs.
Future<void> hydrateLibraryBrowsePrefs(SecureStorage storage) async {
  _persistedStorage = storage;
  final raw = await storage.getBrowsePrefsJson();
  if (raw == null || raw.isEmpty) return;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _persistedShowHidden = map['showHidden'] as bool? ?? _persistedShowHidden;
    _persistedIndexedOnly =
        map['indexedOnly'] as bool? ?? _persistedIndexedOnly;
    _persistedSortAsc = map['sortAsc'] as bool? ?? _persistedSortAsc;
    _persistedSortBy =
        _decodeEnum(BrowseSortColumn.values, map['sortBy']) ?? _persistedSortBy;
    _persistedViewMode =
        _decodeEnum(BrowseViewMode.values, map['viewMode']) ??
            _persistedViewMode;
    _persistedKindFilter =
        _decodeEnum(BrowseKindFilter.values, map['kindFilter']) ??
            _persistedKindFilter;
    _persistedDensity =
        _decodeEnum(BrowseDensity.values, map['density']) ?? _persistedDensity;

    // Column layout — order + widths.  Schema:
    //   columnOrder:  ["name", "size", "modified", ...]
    //   columnWidths: {"size": 100.0, "modified": 130.0, ...}
    // Both tolerant of unknown enum names (skipped silently).  Name is
    // re-pinned to slot 0 if missing or moved away from there — the
    // toggle / reorder mutators enforce this invariant at write time
    // but a corrupt blob could otherwise smuggle a Name-less order
    // through.
    final orderRaw = map['columnOrder'];
    if (orderRaw is List) {
      final restored = <BrowseColumn>[];
      for (final v in orderRaw) {
        final col = _decodeEnum(BrowseColumn.values, v);
        if (col != null && !restored.contains(col)) restored.add(col);
      }
      if (restored.isNotEmpty) {
        // Force Name to slot 0; drop a stray Name elsewhere.
        restored.removeWhere((c) => c == BrowseColumn.name);
        persistedColumnOrder = [BrowseColumn.name, ...restored];
      }
    }
    final widthsRaw = map['columnWidths'];
    if (widthsRaw is Map) {
      final restored = <BrowseColumn, double>{};
      widthsRaw.forEach((k, v) {
        final col = _decodeEnum(BrowseColumn.values, k);
        if (col != null && v is num) {
          restored[col] = v.toDouble().clamp(
                kBrowseColumnMinWidth,
                kBrowseColumnMaxWidth,
              );
        }
      });
      persistedColumnWidths = restored;
    }
    // Bump the notifier so any widget that mounted before hydrate ran
    // re-renders against the restored layout.  Cheap — only the column
    // header + row body subscribe.
    columnsVersion.value = columnsVersion.value + 1;
  } catch (e, st) {
    // Corrupt payload — keep defaults + wipe so the next write starts
    // clean.  Don't rethrow; UI prefs being reset is an annoyance,
    // not a launch-blocker.
    Logger().w('Failed to parse browse prefs; resetting',
        error: e, stackTrace: st);
    unawaited(storage.setBrowsePrefsJson('{}'));
  }
}

/// Encode the current persisted statics + push to [SecureStorage].
/// Called from every setter that mutates one of the statics.
/// Debounced 400 ms so a drag-resize collapses to a single write;
/// circuit-broken via [_browsePrefsWritable] so a wedged on-disk DAT
/// stops flooding the log after the first failure.
void _flushBrowsePrefs() {
  final storage = _persistedStorage;
  if (storage == null) return;
  if (!_browsePrefsWritable) return;
  _browsePrefsFlushDebounce?.cancel();
  _browsePrefsFlushDebounce = Timer(const Duration(milliseconds: 400), () {
    final encoded = jsonEncode(<String, dynamic>{
      'showHidden': _persistedShowHidden,
      'indexedOnly': _persistedIndexedOnly,
      'sortBy': _persistedSortBy.name,
      'sortAsc': _persistedSortAsc,
      'viewMode': _persistedViewMode.name,
      'kindFilter': _persistedKindFilter.name,
      'density': _persistedDensity.name,
      'columnOrder': persistedColumnOrder.map((c) => c.name).toList(),
      'columnWidths': {
        for (final entry in persistedColumnWidths.entries)
          entry.key.name: entry.value,
      },
    });
    () async {
      try {
        await storage.setBrowsePrefsJson(encoded);
      } catch (_) {
        // Plugin self-heals on the first failure by deleting the
        // corrupt blob; the retry then writes into an empty store.
        // Breaker trips only if the second attempt also fails.
        try {
          await storage.setBrowsePrefsJson(encoded);
        } catch (_) {
          _browsePrefsWritable = false;
        }
      }
    }();
  });
}

/// Look up an enum value by its string name with a tolerant return —
/// any non-string / unknown name yields null so the caller can fall
/// back to the existing default.  Avoids the throw-on-miss behaviour
/// of `Enum.values.byName(...)`.
T? _decodeEnum<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return null;
}

/// Single result from [LibraryBrowseCubit.pathSuggestions] — bundles
/// the directory entry with the relative path the cubit fetched it
/// against.  The pick handler navigates via
/// `cubit.navigateTo('${parentRelative}/${entry.name}')` directly,
/// bypassing the absolute-string-prefix matching in
/// [LibraryBrowseCubit.navigateToAbsolute] (which is fragile across
/// multi-root libraries, case mismatches, and stale `rootPath`
/// values).  The relative is guaranteed valid because the cubit had
/// to use it to fetch the suggestion in the first place.
///
/// `parentRelative` is empty at the library root.
class PathSuggestion {
  const PathSuggestion({
    required this.parentRelative,
    required this.entry,
  });

  final String parentRelative;
  final BrowseEntry entry;

  /// Compose the absolute-from-library-root relative path that
  /// `cubit.navigateTo(...)` accepts.
  String get relativePath =>
      parentRelative.isEmpty ? entry.name : '$parentRelative/${entry.name}';
}

/// One cubit per screen mount; the UI prefs seed from the module-level
/// statics above and write back to them on every mutation so they
/// survive across screen re-mounts within the same app session.
class LibraryBrowseCubit extends Cubit<LibraryBrowseState> {
  LibraryBrowseCubit({
    required this.libraryId,
    required LibraryRepository repository,
    LibraryEventsService? events,
  })  : _repository = repository,
        _showHidden = _persistedShowHidden,
        _indexedOnly = _persistedIndexedOnly,
        _sortBy = _persistedSortBy,
        _sortAsc = _persistedSortAsc,
        _viewMode = _persistedViewMode,
        _kindFilter = _persistedKindFilter,
        _density = _persistedDensity,
        super(const LibraryBrowseInitial()) {
    // Subscribe to server-side thumbnail-progress events for our
    // library so the listing refreshes as thumbs land in the
    // background.  Without this the operator has to hit Refresh to
    // see newly-rendered thumbs after kicking off a regenerate.
    //
    // Throttled via a debouncer: each event restarts a short timer,
    // and only the last event in a burst triggers a refresh.  Under
    // CONCURRENCY=4 the worker can emit 4 events/second; without
    // throttling the listing would re-fetch 4×/sec for the whole
    // duration of a regenerate.  Completion (`isComplete`) bypasses
    // the debouncer so the operator sees the final state promptly.
    _progressSub = events?.thumbnailsProgress.listen(_onThumbnailProgress);
  }

  final String libraryId;
  final LibraryRepository _repository;
  static final _log = Logger();

  StreamSubscription<ThumbnailProgress>? _progressSub;
  Timer? _progressRefreshDebounce;
  // How long to wait after the last progress event before refreshing
  // the listing.  Long enough to coalesce a burst of completions into
  // one fetch, short enough that the operator perceives the listing
  // as "live."
  static const Duration _progressDebounce = Duration(milliseconds: 600);

  // ── UI preferences (seeded from process-wide statics) ──────────────────

  bool _showHidden;
  bool _indexedOnly;
  BrowseSortColumn _sortBy;
  bool _sortAsc;
  BrowseViewMode _viewMode;
  String _search = '';
  BrowseKindFilter _kindFilter;
  BrowseDensity _density;

  /// Anchor for shift-click range selection.  Set on every plain click
  /// + ctrl-click; the next shift-click selects the inclusive range
  /// from this anchor through the shift-clicked entry.
  String? _selectionAnchor;

  /// Back history — paths the operator has navigated away from.  Top
  /// of the stack is the most-recent prior path.  Phase D of plan 28.
  /// `goBack()` pops + navigates; every fresh `navigateTo` pushes the
  /// current path on + clears `_forward`.
  final List<String> _back = [];
  final List<String> _forward = [];

  /// Lazy folder-size cache — keyed by relative path under the current
  /// library.  Populated by `computeFolderSize` (right detail panel's
  /// "Compute size" button); persisted across re-selections of the
  /// same folder.  Phase D.
  final Map<String, FolderSize> _folderSizes = {};

  /// Per-parent directory listing cache, populated by [pathSuggestions]
  /// while the operator types into the editable path bar.  Keyed by
  /// the normalised relative parent path (forward slashes, no trailing
  /// `/`).  Bounded only by how many distinct parents the operator
  /// types through in one edit session — small enough not to need an
  /// LRU eviction.  Cleared whenever the screen unmounts.
  final Map<String, List<BrowseEntry>> _childListCache = {};

  /// Currently-selected entries — keyed by their `name` field (unique
  /// inside a single directory).  Single-element on click, grows on
  /// Ctrl+click (phase C).
  final Set<String> _selectedNames = {};

  // Public read-only getters consumed by the screen's BlocBuilder.
  bool get showHidden => _showHidden;
  bool get indexedOnly => _indexedOnly;
  BrowseSortColumn get sortBy => _sortBy;
  bool get sortAsc => _sortAsc;
  BrowseViewMode get viewMode => _viewMode;
  String get search => _search;
  BrowseKindFilter get kindFilter => _kindFilter;
  BrowseDensity get density => _density;
  Set<String> get selectedNames => Set.unmodifiable(_selectedNames);

  /// True when more than one entry is selected.
  bool get hasMultiSelect => _selectedNames.length > 1;

  /// The single selected entry's `BrowseEntry`, or `null` when nothing
  /// is selected or the state isn't [LibraryBrowseLoaded].  Drives the
  /// right detail panel — even with multi-select the panel renders the
  /// most-recently-selected entry.
  BrowseEntry? get selectedEntry {
    final s = state;
    if (s is! LibraryBrowseLoaded) return null;
    if (_selectedNames.isEmpty) return null;
    final lastSelected = _selectedNames.last;
    for (final e in s.response.entries) {
      if (e.name == lastSelected) return e;
    }
    return null;
  }

  // ── Network-driving methods ─────────────────────────────────────────────

  /// Initial load — fetches the library's root directory.
  Future<void> load() async {
    emit(const LibraryBrowseLoading(path: ''));
    await _fetch('');
  }

  /// Navigate into the given relative path (e.g. `sub/nested`).  Used
  /// for both folder clicks and breadcrumb segment clicks.  Clears
  /// selection + search on navigation.  Pushes the previous path onto
  /// the back stack + clears the forward stack — fresh navigation is
  /// always a new branch.
  Future<void> navigateTo(String relativePath) async {
    final previous = _currentPath();
    if (previous != relativePath) {
      _back.add(previous);
      _forward.clear();
    }
    _selectedNames.clear();
    _search = '';
    await _softFetch(relativePath);
  }

  /// Pop the back stack onto the current path, push the current onto
  /// the forward stack, then fetch.  No-op when there's no history to
  /// rewind.
  Future<void> goBack() async {
    if (_back.isEmpty) return;
    final target = _back.removeLast();
    _forward.add(_currentPath());
    _selectedNames.clear();
    _search = '';
    await _softFetch(target);
  }

  /// Inverse of [goBack] — pops the forward stack.
  Future<void> goForward() async {
    if (_forward.isEmpty) return;
    final target = _forward.removeLast();
    _back.add(_currentPath());
    _selectedNames.clear();
    _search = '';
    await _softFetch(target);
  }

  /// Public read-only getters for the toolbar / keyboard handler.
  bool get canGoBack => _back.isNotEmpty;
  bool get canGoForward => _forward.isNotEmpty;

  /// Cached folder-size for a given relative path, or `null` when not
  /// computed yet.  Phase D.
  FolderSize? folderSizeFor(String relativePath) =>
      _folderSizes[relativePath];

  /// Kick off a recursive folder-size fetch.  Caches the result under
  /// the requested relative path so re-selecting the same folder reads
  /// from the cache.  Returns the result for callers that want to
  /// snackbar / log on completion.  Rethrows `ApiException` so the
  /// detail panel can render an error state.  Phase D of plan 28.
  Future<FolderSize> computeFolderSize(String relativePath) async {
    final existing = _folderSizes[relativePath];
    if (existing != null) return existing;
    try {
      final result = await _repository.folderSize(
        libraryId: libraryId,
        relativePath: relativePath,
      );
      _folderSizes[relativePath] = result;
      _reemit();
      return result;
    } on ApiException catch (e, st) {
      _log.e('computeFolderSize failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Walk one level up.  No-op at the root.
  Future<void> goUp() async {
    final current = state;
    final parent = current is LibraryBrowseLoaded
        ? current.response.parentPath
        : null;
    if (parent == null) return;
    await navigateTo(parent);
  }

  /// Refresh the current directory in place (no path change).  Selection
  /// + search are preserved.
  /// Soft refresh — re-fetches the current directory IN PLACE without
  /// emitting [LibraryBrowseLoading].  The chrome (breadcrumb, filter
  /// chips, toolbar, detail panel) stays mounted with the existing
  /// response visible; only `state.refreshing` flips true while the
  /// fetch is in flight and the response object swaps when it lands.
  ///
  /// Falls back to a hard load + Loading emission when there's no
  /// existing Loaded state to soft-refresh from (cold boot path).
  Future<void> refresh() async {
    await _softFetch(_currentPath());
  }

  /// Flip the hidden-files toggle + re-fetch the current directory
  /// (show_hidden lives server-side — it changes which entries the
  /// response contains).  Goes through the soft-fetch path so the
  /// toolbar + chrome stay mounted while the listing updates.
  Future<void> setShowHidden(bool value) async {
    if (_showHidden == value) return;
    _showHidden = value;
    _persistedShowHidden = value;
    _flushBrowsePrefs();
    await _softFetch(_currentPath());
  }

  /// Index a single un-indexed entry (Phase C right-click action).
  /// Returns the result so callers can surface a toast.  The current
  /// directory is refreshed on success so the listing flips to
  /// `is_indexed=true` for that row.
  Future<IndexFileResult?> indexEntry(BrowseEntry entry) async {
    if (entry.isDir) return null;
    final relativePath = _relativePathFor(entry);
    if (relativePath == null) return null;
    try {
      final result = await _repository.indexFile(
        libraryId: libraryId,
        relativePath: relativePath,
      );
      // The new file_id needs to be reflected in the listing, so re-
      // fetch the current directory (cheap — same /browse call).
      await refresh();
      return result;
    } on ApiException catch (e, st) {
      _log.e('indexEntry failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Regenerate the selected entry's thumbnail.  Worker picks up the
  /// reset row on its next tick; no refresh needed because the
  /// thumbnail-progress WS event will trigger a card refresh upstream.
  Future<void> regenerateEntryThumbnail(BrowseEntry entry) async {
    if (entry.fileId == null) return;
    try {
      await _repository.regenerateFileThumbnail(entry.fileId!);
      await refresh();
    } on ApiException catch (e, st) {
      _log.e('regenerateEntryThumbnail failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Rescan a subdir (Phase C right-click on a folder).  Returns the
  /// number of newly-ingested files so callers can render a toast.
  Future<int> scanEntrySubtree(BrowseEntry entry) async {
    if (!entry.isDir) return 0;
    final relativePath = _relativePathFor(entry);
    if (relativePath == null) return 0;
    try {
      final added = await _repository.scanSubtree(
        libraryId: libraryId,
        relativePath: relativePath,
      );
      await refresh();
      return added;
    } on ApiException catch (e, st) {
      _log.e('scanEntrySubtree failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Remove a single indexed file from the catalog.  The file on disk
  /// is untouched.  Returns true when the row was removed (or already
  /// gone), false when the entry has no `file_id` to delete.  Backs
  /// the right-click "Unindex this file" action.
  Future<bool> unindexEntry(BrowseEntry entry) async {
    final fileId = entry.fileId;
    if (entry.isDir || fileId == null) return false;
    try {
      await _repository.unindexFile(fileId);
      await refresh();
      return true;
    } on ApiException catch (e, st) {
      _log.e('unindexEntry failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Remove every `media_files` row under a directory entry from the
  /// catalog.  Returns the count of removed rows so callers can render
  /// a toast.  Files on disk are untouched.  Backs the right-click
  /// "Unindex this folder" action.
  Future<int> unindexEntrySubtree(BrowseEntry entry) async {
    if (!entry.isDir) return 0;
    final relativePath = _relativePathFor(entry);
    if (relativePath == null) return 0;
    try {
      final removed = await _repository.unindexSubtree(
        libraryId: libraryId,
        relativePath: relativePath,
      );
      await refresh();
      return removed;
    } on ApiException catch (e, st) {
      _log.e('unindexEntrySubtree failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Navigate to an absolute or library-relative path entered into the
  /// editable path textbox (Phase C).  Strips any matched root prefix
  /// to produce a relative path the server's `/browse?path=` accepts;
  /// when the local prefix-match fails (multi-root library, case
  /// mismatch on Windows, or typed canonical form differs from the
  /// visible `rootPath`), falls back to
  /// `GET /api/v1/library/{id}/resolve-absolute?path=<abs>` which
  /// walks every configured `root_paths` server-side.  Returns false
  /// only when both the local match AND the server fallback fail —
  /// the path is genuinely outside the library or doesn't exist.
  Future<bool> navigateToAbsolute(String input) async {
    final current = state;
    if (current is! LibraryBrowseLoaded) return false;
    final root = current.response.rootPath;
    final trimmedInput = input.trim();
    final normalised = trimmedInput.replaceAll(r'\', '/');
    final normalisedRoot = root.replaceAll(r'\', '/');
    if (normalised.isEmpty) {
      await navigateTo('');
      return true;
    }
    final rootLower = normalisedRoot.toLowerCase();
    final inputLower = normalised.toLowerCase();
    String? relative;
    if (inputLower == rootLower) {
      relative = '';
    } else if (inputLower.startsWith('$rootLower/')) {
      relative = normalised.substring(normalisedRoot.length + 1);
    } else if (!normalised.contains(':') && !normalised.startsWith('/')) {
      // Looks like an already-relative path.
      relative = normalised;
    } else {
      // Absolute path that doesn't match the displayed root.  Ask the
      // server to walk every configured root_paths and see if any of
      // them contain it.  Single round-trip; returns null on miss.
      try {
        relative = await _repository.resolveAbsolutePath(
          libraryId: libraryId,
          absolutePath: trimmedInput,
        );
      } on ApiException catch (e, st) {
        _log.w('resolveAbsolutePath failed', error: e, stackTrace: st);
        relative = null;
      }
    }
    if (relative == null) return false;
    // Same-path commit (Enter on an unchanged URL): route through a
    // SOFT refresh that keeps the breadcrumb / filter chips / toolbar
    // / detail panel mounted — only the listing's response object
    // gets swapped.  Different-path navigation still goes through
    // `navigateTo`, which clears selection + search + emits Loading
    // so the chrome resets correctly for the new path.
    final currentRel = current.response.relativePath
        .replaceAll(r'\', '/')
        .replaceAll(RegExp(r'/+$'), '');
    final targetRel = relative
        .replaceAll(r'\', '/')
        .replaceAll(RegExp(r'/+$'), '');
    if (currentRel == targetRel) {
      await refresh();
      return true;
    }
    await navigateTo(relative);
    final next = state;
    return next is LibraryBrowseLoaded;
  }

  /// Folder-name autocomplete for the editable path bar.
  ///
  /// Parses [input] as `<root>/<some/path>/<typed_prefix>`, fetches
  /// the entries of `<root>/<some/path>` from the server (cached for
  /// the lifetime of this cubit), and returns up to [limit] direct
  /// child directories whose names start with `<typed_prefix>`
  /// (case-insensitive).  Returns an empty list when the input
  /// doesn't sit under the loaded library's root or when the parent
  /// directory can't be listed (permission denied / not on disk).
  ///
  /// The trailing-slash convention matters: `D:\Library\Movies` →
  /// suggests siblings of `Movies` under `D:\Library`; the same
  /// string with a trailing slash (`D:\Library\Movies\`) → suggests
  /// every direct child of `Movies` (empty prefix).
  Future<List<PathSuggestion>> pathSuggestions(
    String input, {
    int limit = 10,
  }) async {
    final current = state;
    if (current is! LibraryBrowseLoaded) return const [];
    final root = current.response.rootPath;
    final normalised = input.replaceAll(r'\', '/');
    final normalisedRoot = root.replaceAll(r'\', '/');
    final rootLower = normalisedRoot.toLowerCase();
    final inputLower = normalised.toLowerCase();

    // Resolve the input to a subpath under the matched root.  When
    // the input doesn't extend the root, we have nothing to suggest.
    String subpath;
    if (inputLower == rootLower || inputLower == '$rootLower/') {
      subpath = '';
    } else if (inputLower.startsWith('$rootLower/')) {
      subpath = normalised.substring(normalisedRoot.length + 1);
    } else {
      return const [];
    }

    final slashIdx = subpath.lastIndexOf('/');
    final parentRelative =
        slashIdx == -1 ? '' : subpath.substring(0, slashIdx);
    final prefix = slashIdx == -1 ? subpath : subpath.substring(slashIdx + 1);
    final prefixLower = prefix.toLowerCase();

    final children = await _fetchChildrenCached(parentRelative);
    if (children.isEmpty) return const [];

    final matches = <PathSuggestion>[];
    for (final e in children) {
      if (!e.isDir) continue;
      if (prefixLower.isEmpty ||
          e.name.toLowerCase().startsWith(prefixLower)) {
        matches.add(PathSuggestion(
          parentRelative: parentRelative,
          entry: e,
        ));
        if (matches.length >= limit) break;
      }
    }
    return matches;
  }

  Future<List<BrowseEntry>> _fetchChildrenCached(
    String parentRelative,
  ) async {
    final key = parentRelative.replaceAll(RegExp(r'/+$'), '');
    final cached = _childListCache[key];
    if (cached != null) return cached;
    try {
      final response = await _repository.browseLibrary(
        libraryId: libraryId,
        path: key,
        showHidden: false,
      );
      _childListCache[key] = response.entries;
      return response.entries;
    } on ApiException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Compose `<currentRelativePath>/<entry.name>` for an entry in the
  /// current directory.  Returns null when state isn't [LibraryBrowseLoaded].
  String? _relativePathFor(BrowseEntry entry) {
    final current = state;
    if (current is! LibraryBrowseLoaded) return null;
    final base = current.response.relativePath;
    return base.isEmpty ? entry.name : '$base/${entry.name}';
  }

  // ── UI-only methods (no network) ────────────────────────────────────────

  /// Toggle indexed-only filter.  Pure client-side filter on the
  /// already-loaded response — no re-fetch.
  void setIndexedOnly(bool value) {
    if (_indexedOnly == value) return;
    _indexedOnly = value;
    _persistedIndexedOnly = value;
    _flushBrowsePrefs();
    _reemit();
  }

  /// Set the kind-filter chip.  Pure client-side filter on the
  /// loaded response — no re-fetch.  Phase B of plan 28.
  void setKindFilter(BrowseKindFilter filter) {
    if (_kindFilter == filter) return;
    _kindFilter = filter;
    _persistedKindFilter = filter;
    _flushBrowsePrefs();
    _reemit();
  }

  /// Click on a column header.  Same column → toggle direction; new
  /// column → switch to it and reset to ascending.
  void setSort(BrowseSortColumn column) {
    if (_sortBy == column) {
      _sortAsc = !_sortAsc;
    } else {
      _sortBy = column;
      _sortAsc = true;
    }
    _persistedSortBy = _sortBy;
    _persistedSortAsc = _sortAsc;
    _flushBrowsePrefs();
    _reemit();
  }

  /// Flip between list + grid view.  Pure local state.
  void setViewMode(BrowseViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    _persistedViewMode = mode;
    _flushBrowsePrefs();
    _reemit();
  }

  /// Update the search filter substring.  Case-insensitive match on
  /// entry `name`; empty string clears the filter.  Pure client-side.
  void setSearch(String query) {
    if (_search == query) return;
    _search = query;
    _reemit();
  }

  /// Single-click selection.  Replaces any prior selection.  Plain
  /// clicks also set the shift-click anchor to this entry.
  void selectOnly(String entryName) {
    _selectedNames
      ..clear()
      ..add(entryName);
    _selectionAnchor = entryName;
    _reemit();
  }

  /// Ctrl/Cmd + click — toggle the clicked entry's membership in the
  /// selection without clearing the rest.  The anchor flips to the
  /// most-recently-toggled entry (matches Explorer + macOS Finder).
  void toggleSelection(String entryName) {
    if (_selectedNames.contains(entryName)) {
      _selectedNames.remove(entryName);
    } else {
      _selectedNames.add(entryName);
    }
    _selectionAnchor = entryName;
    _reemit();
  }

  /// Shift + click — select the inclusive range from the last anchor
  /// through [entryName] in the currently-visible (filtered + sorted)
  /// list.  Replaces the prior selection.  Falls back to [selectOnly]
  /// when no anchor exists or the anchor is no longer in the visible
  /// list (e.g. operator changed the search filter between clicks).
  void extendSelection(String entryName) {
    final visible = _currentVisible();
    if (visible.isEmpty) return;
    final anchor = _selectionAnchor;
    if (anchor == null) {
      selectOnly(entryName);
      return;
    }
    int anchorIdx = -1;
    int targetIdx = -1;
    for (var i = 0; i < visible.length; i++) {
      if (visible[i].name == anchor) anchorIdx = i;
      if (visible[i].name == entryName) targetIdx = i;
    }
    if (anchorIdx < 0 || targetIdx < 0) {
      selectOnly(entryName);
      return;
    }
    final lo = anchorIdx < targetIdx ? anchorIdx : targetIdx;
    final hi = anchorIdx < targetIdx ? targetIdx : anchorIdx;
    _selectedNames.clear();
    for (var i = lo; i <= hi; i++) {
      _selectedNames.add(visible[i].name);
    }
    _reemit();
  }

  /// Ctrl+A — select every currently-visible entry.  No-op when empty.
  void selectAllVisible() {
    final visible = _currentVisible();
    if (visible.isEmpty) return;
    _selectedNames
      ..clear()
      ..addAll(visible.map((e) => e.name));
    _selectionAnchor = visible.first.name;
    _reemit();
  }

  /// Clear the entire selection (Esc / clicked empty space).
  void clearSelection() {
    if (_selectedNames.isEmpty) return;
    _selectedNames.clear();
    _selectionAnchor = null;
    _reemit();
  }

  /// Change the listing density.  Pure local state; affects row + tile
  /// dimensions without touching the response.
  void setDensity(BrowseDensity density) {
    if (_density == density) return;
    _density = density;
    _persistedDensity = density;
    _flushBrowsePrefs();
    _reemit();
  }

  // ── Keyboard navigation helpers (Phase B) ───────────────────────────────
  //
  // All [step*] methods operate on the **filtered + sorted** visible
  // list — they re-derive it from the current state so the cubit owner
  // doesn't need to plumb the visible list back in.  No-op when state
  // isn't [LibraryBrowseLoaded] OR when the visible list is empty.

  List<BrowseEntry> _currentVisible() {
    final current = state;
    if (current is! LibraryBrowseLoaded) return const [];
    return applyBrowseFilters(
      current.response.entries,
      indexedOnly: _indexedOnly,
      kindFilter: _kindFilter,
      search: _search,
      sortBy: _sortBy,
      sortAsc: _sortAsc,
    );
  }

  int _currentVisibleIndex(List<BrowseEntry> visible) {
    if (_selectedNames.isEmpty) return -1;
    final last = _selectedNames.last;
    for (var i = 0; i < visible.length; i++) {
      if (visible[i].name == last) return i;
    }
    return -1;
  }

  /// Move selection N positions (positive = down, negative = up).
  /// Wraps from no-selection to the first/last entry depending on
  /// direction.  Used by arrow keys + Page Up/Down.
  void stepSelection(int delta) {
    final visible = _currentVisible();
    if (visible.isEmpty) return;
    final current = _currentVisibleIndex(visible);
    int next;
    if (current < 0) {
      next = delta > 0 ? 0 : visible.length - 1;
    } else {
      next = (current + delta).clamp(0, visible.length - 1);
    }
    selectOnly(visible[next].name);
  }

  /// Select the first visible entry.  No-op when empty.
  void selectFirst() {
    final visible = _currentVisible();
    if (visible.isEmpty) return;
    selectOnly(visible.first.name);
  }

  /// Select the last visible entry.  No-op when empty.
  void selectLast() {
    final visible = _currentVisible();
    if (visible.isEmpty) return;
    selectOnly(visible.last.name);
  }

  /// Return the currently-selected entry plus its absolute path, ready
  /// for an "open" action.  Null when nothing selected.  Centralises
  /// the absolute-path build (separator handling + relative join) so
  /// the screen's keyboard handler and row click handler share the
  /// same shape.
  ({BrowseEntry entry, String absolutePath, String relativePath})?
      resolveSelected() {
    final entry = selectedEntry;
    final current = state;
    if (entry == null || current is! LibraryBrowseLoaded) return null;
    final response = current.response;
    final separator = response.rootPath.contains(r'\') ? r'\' : '/';
    final relTail = response.relativePath.isEmpty
        ? entry.name
        : '${response.relativePath}/${entry.name}';
    final relForFolder = response.relativePath.isEmpty
        ? entry.name
        : '${response.relativePath}/${entry.name}';
    final tailWithSep = relTail.replaceAll('/', separator);
    return (
      entry: entry,
      absolutePath: '${response.rootPath}$separator$tailWithSep',
      relativePath: relForFolder,
    );
  }

  // ── Internal ────────────────────────────────────────────────────────────

  String _currentPath() {
    final current = state;
    if (current is LibraryBrowseLoaded) return current.response.relativePath;
    if (current is LibraryBrowseLoading) return current.path;
    if (current is LibraryBrowseFailure) return current.path;
    return '';
  }

  /// Re-emit the current Loaded state without re-fetching — used by
  /// pure-UI-pref updates so the BlocBuilder/BlocSelector consumers
  /// see the new prefs.  No-op when not Loaded.
  void _reemit() {
    final current = state;
    if (current is! LibraryBrowseLoaded) return;
    // Sealed states must be brand-new instances for `==` to work —
    // wrap in a copy with the same response.
    emit(LibraryBrowseLoaded(response: current.response));
  }

  Future<void> _fetch(String path) async {
    try {
      final response = await _repository.browseLibrary(
        libraryId: libraryId,
        path: path,
        showHidden: _showHidden,
      );
      emit(LibraryBrowseLoaded(response: response));
    } on ApiException catch (e, st) {
      _log.e('Browse failed', error: e, stackTrace: st);
      emit(LibraryBrowseFailure(path: path, message: e.message));
    } catch (e, st) {
      _log.e('Browse failed', error: e, stackTrace: st);
      emit(LibraryBrowseFailure(
        path: path,
        message: 'Unable to load directory: $e',
      ));
    }
  }

  /// Shared "fetch without unmounting the chrome" helper used by every
  /// path-changing action (`navigateTo` / `goBack` / `goForward` /
  /// `refresh` / `setShowHidden`).
  ///
  /// When there's an existing [LibraryBrowseLoaded] state, this emits
  /// the same response with `refreshing: true` instead of emitting
  /// [LibraryBrowseLoading].  The chrome (breadcrumb / filter chips /
  /// toolbar / detail panel) all read the type-checked state via
  /// `buildWhen` guards that skip Loaded→Loaded transitions where
  /// nothing they care about changed, so nothing rebuilds until the
  /// fetch lands a new response object.
  ///
  /// Falls back to a hard [LibraryBrowseLoading] emission on cold
  /// boot (no prior Loaded state) so the listing skeleton still
  /// appears on first paint.
  Future<void> _softFetch(String path) async {
    final current = state;
    if (current is LibraryBrowseLoaded) {
      emit(LibraryBrowseLoaded(
        response: current.response,
        refreshing: true,
      ));
    } else {
      emit(LibraryBrowseLoading(path: path));
    }
    await _fetch(path);
  }

  /// Drive the listing's live-refresh on a [ThumbnailProgress] event
  /// from the server.  Skips events for other libraries, debounces a
  /// burst into one refresh, and bypasses the debouncer when the
  /// library finishes (`isComplete`) so the operator sees the final
  /// thumbs as soon as the worker drains.
  void _onThumbnailProgress(ThumbnailProgress progress) {
    if (progress.libraryId != libraryId) return;
    _progressRefreshDebounce?.cancel();
    if (progress.isComplete) {
      // No more events incoming — refresh now without waiting for
      // a debounce window that nothing will land in.
      unawaited(refresh());
      return;
    }
    _progressRefreshDebounce = Timer(_progressDebounce, () {
      unawaited(refresh());
    });
  }

  @override
  Future<void> close() {
    _progressSub?.cancel();
    _progressRefreshDebounce?.cancel();
    return super.close();
  }

  @override
  void emit(LibraryBrowseState state) {
    if (isClosed) return;
    super.emit(state);
  }
}

/// Apply the cubit's UI prefs (filter + search + sort) to a raw server
/// response.  Pure function — kept outside the cubit so widgets can
/// recompute incrementally as prefs change without firing a re-emit.
///
/// Filter order: kind filter → indexed-only → search.  Search is the
/// most operator-tweaked input so it runs last to avoid recomputing
/// the broader filters on every keystroke (the predicate's branches
/// short-circuit anyway, but ordering the cheap checks first keeps
/// the visible-list update snappy on large directories).
///
/// Sort order: directories always first (matches Explorer + the server
/// default).  Within each group, the operator's selected column +
/// direction wins.
List<BrowseEntry> applyBrowseFilters(
  List<BrowseEntry> entries, {
  required bool indexedOnly,
  required String search,
  required BrowseSortColumn sortBy,
  required bool sortAsc,
  BrowseKindFilter kindFilter = BrowseKindFilter.all,
}) {
  final query = search.trim().toLowerCase();
  var filtered = entries.where((e) {
    if (!kindFilter.admits(e)) return false;
    if (indexedOnly && !e.isIndexed && !e.isDir) return false;
    if (query.isNotEmpty &&
        !e.name.toLowerCase().contains(query)) {
      return false;
    }
    return true;
  }).toList();

  int cmp(BrowseEntry a, BrowseEntry b) {
    // Directories before files always.
    if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
    int result;
    switch (sortBy) {
      case BrowseSortColumn.name:
        result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case BrowseSortColumn.size:
        result = a.sizeBytes.compareTo(b.sizeBytes);
      case BrowseSortColumn.modified:
        result = a.mtimeUnix.compareTo(b.mtimeUnix);
    }
    return sortAsc ? result : -result;
  }

  filtered.sort(cmp);
  return filtered;
}

sealed class LibraryBrowseState {
  const LibraryBrowseState();
}

class LibraryBrowseInitial extends LibraryBrowseState {
  const LibraryBrowseInitial();
}

class LibraryBrowseLoading extends LibraryBrowseState {
  const LibraryBrowseLoading({required this.path});

  /// Path being loaded — lets the breadcrumb stay stable while the
  /// listing is in flight (otherwise the operator would see the crumb
  /// vanish on every navigation).
  final String path;
}

class LibraryBrowseLoaded extends LibraryBrowseState {
  const LibraryBrowseLoaded({
    required this.response,
    this.refreshing = false,
  });

  final BrowseResponse response;

  /// True while a background re-fetch is in flight after the operator
  /// hit Refresh / re-pressed Enter on the same path / triggered any
  /// soft-refresh path.  Surfaces as a thin progress indicator on the
  /// listing area without unmounting the chrome (breadcrumb / filter
  /// chips / toolbar / detail panel all stay live).
  final bool refreshing;
}

class LibraryBrowseFailure extends LibraryBrowseState {
  const LibraryBrowseFailure({required this.path, required this.message});

  final String path;
  final String message;
}
