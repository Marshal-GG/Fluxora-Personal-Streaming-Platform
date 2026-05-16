import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';

/// Sortable columns in the folder browser.  Phase A of plan 28.
enum BrowseSortColumn { name, size, modified }

/// Two display modes for the folder browser body.  Phase A of plan 28.
enum BrowseViewMode { list, grid }

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
/// One cubit per screen mount; the UI prefs reset on remount.
class LibraryBrowseCubit extends Cubit<LibraryBrowseState> {
  LibraryBrowseCubit({
    required this.libraryId,
    required LibraryRepository repository,
  })  : _repository = repository,
        super(const LibraryBrowseInitial());

  final String libraryId;
  final LibraryRepository _repository;
  static final _log = Logger();

  // ── UI preferences (in-memory, per cubit-instance) ──────────────────────

  bool _showHidden = false;
  bool _indexedOnly = false;
  BrowseSortColumn _sortBy = BrowseSortColumn.name;
  bool _sortAsc = true;
  BrowseViewMode _viewMode = BrowseViewMode.list;
  String _search = '';
  BrowseKindFilter _kindFilter = BrowseKindFilter.all;

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
  Set<String> get selectedNames => Set.unmodifiable(_selectedNames);

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
  /// selection + search on navigation.
  Future<void> navigateTo(String relativePath) async {
    _selectedNames.clear();
    _search = '';
    emit(LibraryBrowseLoading(path: relativePath));
    await _fetch(relativePath);
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
  Future<void> refresh() async {
    final path = _currentPath();
    emit(LibraryBrowseLoading(path: path));
    await _fetch(path);
  }

  /// Flip the hidden-files toggle + re-fetch the current directory
  /// (show_hidden lives server-side — it changes which entries the
  /// response contains).
  Future<void> setShowHidden(bool value) async {
    if (_showHidden == value) return;
    _showHidden = value;
    final path = _currentPath();
    emit(LibraryBrowseLoading(path: path));
    await _fetch(path);
  }

  // ── UI-only methods (no network) ────────────────────────────────────────

  /// Toggle indexed-only filter.  Pure client-side filter on the
  /// already-loaded response — no re-fetch.
  void setIndexedOnly(bool value) {
    if (_indexedOnly == value) return;
    _indexedOnly = value;
    _reemit();
  }

  /// Set the kind-filter chip.  Pure client-side filter on the
  /// loaded response — no re-fetch.  Phase B of plan 28.
  void setKindFilter(BrowseKindFilter filter) {
    if (_kindFilter == filter) return;
    _kindFilter = filter;
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
    _reemit();
  }

  /// Flip between list + grid view.  Pure local state.
  void setViewMode(BrowseViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    _reemit();
  }

  /// Update the search filter substring.  Case-insensitive match on
  /// entry `name`; empty string clears the filter.  Pure client-side.
  void setSearch(String query) {
    if (_search == query) return;
    _search = query;
    _reemit();
  }

  /// Single-click selection.  Replaces any prior selection.  Phase C
  /// adds [toggleSelection] / [extendSelection] for Ctrl + Shift click.
  void selectOnly(String entryName) {
    _selectedNames
      ..clear()
      ..add(entryName);
    _reemit();
  }

  /// Clear the entire selection (Esc / clicked empty space).
  void clearSelection() {
    if (_selectedNames.isEmpty) return;
    _selectedNames.clear();
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
  const LibraryBrowseLoaded({required this.response});

  final BrowseResponse response;
}

class LibraryBrowseFailure extends LibraryBrowseState {
  const LibraryBrowseFailure({required this.path, required this.message});

  final String path;
  final String message;
}
