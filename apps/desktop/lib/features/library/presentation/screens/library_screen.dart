import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/features/library/domain/entities/library.dart' as desktop;
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_cubit.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_state.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_storage.dart';
import 'package:fluxora_desktop/features/transcode/domain/repositories/transcode_repository.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/storage_strip.dart'
    show openPathInFileManager;
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_cubit.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_state.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_dialog.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_menu.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.embedded = false});

  /// When `true`, the screen is hosted inside a parent shell that already
  /// renders its own page header + action buttons — skip the inner ones.
  /// The shell also owns the `LibraryCubit` + `StorageCubit` providers;
  /// this widget is therefore only valid inside a tree that already
  /// provides them (the `LibraryShell`).  Direct mounting is no longer
  /// supported.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return _LibraryView(embedded: embedded);
  }
}

// ── Tab definitions ────────────────────────────────────────────────────────────

const _kTabs = [
  FluxTab(id: 'all', label: 'All Libraries', icon: Icons.folder_outlined),
  FluxTab(id: 'movies', label: 'Movies', icon: Icons.movie_outlined),
  FluxTab(id: 'tv', label: 'TV Shows', icon: Icons.tv_outlined),
  FluxTab(id: 'music', label: 'Music', icon: Icons.music_note_outlined),
  FluxTab(id: 'docs', label: 'Documents', icon: Icons.description_outlined),
];

LibraryType? _typeForTab(String tabId) => switch (tabId) {
      'movies' => LibraryType.movies,
      'tv' => LibraryType.tv,
      'music' => LibraryType.music,
      'docs' => LibraryType.files,
      _ => null,
    };

// ── Type filter chips ─────────────────────────────────────────────────────────

/// Lighter-weight than the outer `FluxPillTabs` — fully rounded pill
/// shape, smaller padding, slightly muted typography.  Reads as a
/// filter row rather than a second level of page navigation.
class _TypeFilterChips extends StatelessWidget {
  const _TypeFilterChips({
    required this.tabs,
    required this.activeId,
    required this.onChange,
  });

  final List<FluxTab> tabs;
  final String activeId;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      child: Wrap(
        spacing: AppSpacing.s6,
        runSpacing: AppSpacing.s6,
        children: [
          for (final tab in tabs)
            _TypeFilterChip(
              tab: tab,
              isActive: tab.id == activeId,
              onTap: () => onChange(tab.id),
            ),
        ],
      ),
    );
  }
}

class _TypeFilterChip extends StatefulWidget {
  const _TypeFilterChip({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final FluxTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_TypeFilterChip> createState() => _TypeFilterChipState();
}

class _TypeFilterChipState extends State<_TypeFilterChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.isActive
        ? const Color(0x24A855F7)
        : (_hover ? const Color(0x08FFFFFF) : Colors.transparent);
    final Color border = widget.isActive
        ? const Color(0x4DA855F7)
        : AppColors.borderSubtle;
    final Color fg = widget.isActive
        ? AppColors.violetSoft
        : (_hover ? AppColors.textBody : AppColors.textMutedV2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s10,
            vertical: AppSpacing.s6,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            // Fully rounded for the "chip" feel — distinct from the
            // small-radius FluxPillTabs above.
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.tab.icon != null) ...[
                Icon(widget.tab.icon, size: 12, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                widget.tab.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sort / Filter / View-mode types ────────────────────────────────────────────

enum _SortBy {
  name('Name (A–Z)'),
  lastScanned('Last Scanned'),
  fileCount('File Count'),
  totalSize('Total Size');

  const _SortBy(this.label);
  final String label;
}

enum _ViewMode { grid, list }

class _LibraryFilters {
  const _LibraryFilters({
    this.enrichedOnly = false,
    this.withFilesOnly = false,
    this.recentlyScanned = false,
  });

  final bool enrichedOnly;
  final bool withFilesOnly;
  final bool recentlyScanned;

  bool get isActive => enrichedOnly || withFilesOnly || recentlyScanned;

  int get activeCount =>
      (enrichedOnly ? 1 : 0) +
      (withFilesOnly ? 1 : 0) +
      (recentlyScanned ? 1 : 0);

  _LibraryFilters copyWith({
    bool? enrichedOnly,
    bool? withFilesOnly,
    bool? recentlyScanned,
  }) =>
      _LibraryFilters(
        enrichedOnly: enrichedOnly ?? this.enrichedOnly,
        withFilesOnly: withFilesOnly ?? this.withFilesOnly,
        recentlyScanned: recentlyScanned ?? this.recentlyScanned,
      );
}

// ── Main view ──────────────────────────────────────────────────────────────────

class _LibraryView extends StatefulWidget {
  const _LibraryView({required this.embedded});

  final bool embedded;

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  String _activeTab = 'all';
  String? _selectedLibraryId;
  _SortBy _sortBy = _SortBy.name;
  _ViewMode _viewMode = _ViewMode.grid;
  _LibraryFilters _filters = const _LibraryFilters();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Stale-while-revalidate — kick off a silent background refresh on
    // every page mount so cached data caught up to whatever the server
    // currently has.  `.refresh()` re-fetches without flipping the
    // state back to Loading, so the cached UI stays visible while the
    // request is in flight; if the response differs, the new
    // `LibraryLoaded` emission updates the UI seamlessly.
    final libraryCubit = context.read<LibraryCubit>();
    final storageCubit = context.read<StorageCubit>();
    if (libraryCubit.state is LibraryLoaded) {
      // Don't refresh during the initial load (Loading state) — the
      // initial `load()` is already in flight.
      libraryCubit.refresh();
    }
    if (storageCubit.state is StorageLoaded) {
      storageCubit.refresh();
    }

    // Singleton cubits (registered in GetIt) may already hold a
    // `LibraryLoaded` state from a previous mount of this screen.  The
    // `BlocConsumer.listener` below only fires for FRESH state
    // emissions, so on re-mount against cached data it never auto-
    // selects.  Run the same picker here against whatever state the
    // cubit currently holds.
    if (_selectedLibraryId != null) return;
    final state = libraryCubit.state;
    if (state is! LibraryLoaded || state.libraries.isEmpty) return;
    final sorted = List<Library>.from(state.libraries)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final firstId = sorted.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedLibraryId = firstId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgRoot,
      child: Row(
        // Stretch so the right detail panel's background fills the full
        // available height instead of stopping at its intrinsic content
        // height — closes the visible gap below "Remove Library" when the
        // left-side library list runs taller than the panel.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Main content ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              // Tightened top padding (was s20) so the filter chips sit
              // closer to the card's top edge — frees ~8 px of vertical
              // space.  Sides stay at s28 to match the original layout.
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s28,
                AppSpacing.s12,
                AppSpacing.s28,
                AppSpacing.s28,
              ),
              child: BlocConsumer<LibraryCubit, LibraryState>(
                listener: (context, state) {
                  // Pick the alphabetically-first library so the auto-
                  // selection matches the first card in the displayed
                  // (sorted) grid.  Using `state.libraries.first` would
                  // pick whatever order the server returned (creation
                  // order in practice) which doesn't line up with the
                  // visible grid sort.
                  Library? firstByDisplayedSort() {
                    if (state is! LibraryLoaded || state.libraries.isEmpty) {
                      return null;
                    }
                    final sorted = List<Library>.from(state.libraries)
                      ..sort((a, b) =>
                          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                    return sorted.first;
                  }

                  // Auto-select first library when loaded.
                  if (state is LibraryLoaded &&
                      _selectedLibraryId == null &&
                      state.libraries.isNotEmpty) {
                    final first = firstByDisplayedSort();
                    if (first != null) {
                      setState(() => _selectedLibraryId = first.id);
                    }
                  }
                  // Drop selection if the selected library disappeared (e.g. delete).
                  if (state is LibraryLoaded &&
                      _selectedLibraryId != null &&
                      !state.libraries.any((l) => l.id == _selectedLibraryId)) {
                    final first = firstByDisplayedSort();
                    setState(() => _selectedLibraryId = first?.id);
                  }
                },
                builder: (context, state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.embedded)
                        PageHeader(
                          title: 'Library',
                          subtitle: 'Manage your media libraries and files',
                          actions: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FluxButton(
                                variant: FluxButtonVariant.secondary,
                                icon: Icons.refresh_rounded,
                                onPressed: state is LibraryLoaded
                                    ? () =>
                                        context.read<LibraryCubit>().load()
                                    : null,
                                child: const Text('Refresh'),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              FluxButton(
                                variant: FluxButtonVariant.primary,
                                icon: Icons.add_rounded,
                                onPressed: () =>
                                    _showAddLibraryDialog(context),
                                child: const Text('Add Library'),
                              ),
                            ],
                          ),
                        ),

                      // ── Type filter chips (was a FluxTabBar) ───────────
                      // Smaller fully-rounded chips so they read as
                      // filters, not as a second level of navigation
                      // (the outer FluxPillTabs already owns the nav
                      // role).  2026-05-16 owner review.
                      _TypeFilterChips(
                        tabs: _kTabs,
                        activeId: _activeTab,
                        onChange: (id) => setState(() => _activeTab = id),
                      ),
                      const SizedBox(height: AppSpacing.s18),

                      // ── Body ───────────────────────────────────────────
                      // Skeleton on first paint + during reload — keeps
                      // the page structure visible so operators see
                      // chrome + stat strip placeholders + ghost cards
                      // instead of a blank spinner while the cubit
                      // fetches `/library` + `/storage`.
                      switch (state) {
                        LibraryInitial() || LibraryLoading() => _SkeletonBody(
                            activeTab: _activeTab,
                            sortBy: _sortBy,
                            viewMode: _viewMode,
                            filters: _filters,
                            onSortChanged: (s) => setState(() => _sortBy = s),
                            onViewModeChanged: (m) =>
                                setState(() => _viewMode = m),
                            onFiltersChanged: (f) =>
                                setState(() => _filters = f),
                          ),
                        LibraryLoaded() => _LoadedBody(
                            state: state,
                            activeTab: _activeTab,
                            selectedLibraryId: _selectedLibraryId,
                            sortBy: _sortBy,
                            viewMode: _viewMode,
                            filters: _filters,
                            onSelectLibrary: (lib) =>
                                setState(() => _selectedLibraryId = lib.id),
                            onAddLibrary: () => _showAddLibraryDialog(context),
                            onScan: (lib) => _scan(context, lib),
                            onEdit: (lib) => _showEditLibraryDialog(context, lib),
                            onRemove: (lib) => _confirmRemove(context, lib),
                            onSortChanged: (s) => setState(() => _sortBy = s),
                            onViewModeChanged: (m) =>
                                setState(() => _viewMode = m),
                            onFiltersChanged: (f) =>
                                setState(() => _filters = f),
                          ),
                        LibraryFailure(:final message) =>
                          _ErrorBody(
                            message: message,
                            onRetry: () =>
                                context.read<LibraryCubit>().load(),
                          ),
                      },
                    ],
                  );
                },
              ),
            ),
          ),

          // ── Right detail panel ─────────────────────────────────────────
          BlocBuilder<LibraryCubit, LibraryState>(
            builder: (context, state) {
              if (state is! LibraryLoaded) return const SizedBox.shrink();
              final lib = state.libraries.cast<Library?>().firstWhere(
                    (l) => l?.id == _selectedLibraryId,
                    orElse: () => null,
                  );
              if (lib == null) return const SizedBox.shrink();
              return _LibraryDetailPanel(
                library: lib,
                onScan: () => _scan(context, lib),
                onEnrichTmdb: () => _enrichTmdb(context, lib),
                onRegenerateThumbnails: () =>
                    _regenerateThumbnails(context, lib),
                onEdit: () => _showEditLibraryDialog(context, lib),
                onRemove: () => _confirmRemove(context, lib),
                onOpenFiles: () =>
                    context.go(Routes.libraryFiles(lib.id)),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _scan(BuildContext context, Library lib) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await context.read<LibraryCubit>().scanLibrary(lib.id);
      messenger.showSnackBar(SnackBar(
        content: Text(added > 0
            ? 'Scan complete — $added file(s) added to "${lib.name}"'
            : 'Scan complete — no new files in "${lib.name}"'),
      ));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  /// Re-runs TMDB enrichment for files in [lib] that lack a `tmdb_id`.
  /// The "Rescan TMDB" action tile in the detail panel calls this; it
  /// surfaces the matched / enriched / DVR-skipped counts in a toast
  /// so the operator knows whether the rescan actually filled gaps or
  /// found nothing new to enrich.
  Future<void> _enrichTmdb(BuildContext context, Library lib) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await context
          .read<LibraryCubit>()
          .enrichLibraryTmdb(lib.id);
      String body;
      if (result.matched == 0) {
        body = 'No files needing enrichment in "${lib.name}".';
      } else if (result.enriched == 0) {
        body = 'TMDB rescan — checked ${result.matched} file(s) in '
            '"${lib.name}", no matches found'
            '${result.skippedDvr > 0 ? " (${result.skippedDvr} skipped as DVR captures)" : ""}.';
      } else {
        body = 'TMDB rescan — enriched ${result.enriched} of '
            '${result.matched} file(s) in "${lib.name}"'
            '${result.skippedDvr > 0 ? " (${result.skippedDvr} skipped as DVR captures)" : ""}.';
      }
      messenger.showSnackBar(SnackBar(content: Text(body)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('TMDB rescan failed: $e')),
      );
    }
  }

  /// Queue every file in [lib] for thumbnail regeneration.  Backed by
  /// `POST /api/v1/library/{id}/regenerate-thumbnails`.  The server
  /// deletes the existing cached JPEGs and flips each row back to
  /// `pending`; the BG worker re-renders them at current settings.
  /// Toast reports the queued count.  Plan 27 M5.
  Future<void> _regenerateThumbnails(
      BuildContext context, Library lib) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final queued = await context
          .read<LibraryCubit>()
          .regenerateThumbnails(lib.id);
      final body = queued == 0
          ? 'No files to regenerate in "${lib.name}".'
          : 'Queued $queued file(s) in "${lib.name}" for thumbnail '
              'regeneration. Cards will refresh as the worker catches up.';
      messenger.showSnackBar(SnackBar(content: Text(body)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not regenerate thumbnails: $e')),
      );
    }
  }

  Future<void> _showAddLibraryDialog(BuildContext context) =>
      showAddLibraryDialog(context);

  Future<void> _showEditLibraryDialog(
      BuildContext context, Library lib) async {
    final cubit = context.read<LibraryCubit>();
    final state = cubit.state;
    final initialOverrides = state is LibraryLoaded
        ? state.overridesFor(lib.id)
        : desktop.LibraryCodecOverrides.empty;
    final messenger = ScaffoldMessenger.of(context);
    await _showLibraryFormDialog(
      context: context,
      title: 'Edit Library',
      submitLabel: 'Save Changes',
      initialName: lib.name,
      initialType: _typeKey(lib.type),
      initialPaths: List<String>.from(lib.rootPaths),
      typeEditable: false,
      showCodecOverrides: true,
      initialAv1Override: initialOverrides.av1StreamCopyOverride,
      initialVp9Override: initialOverrides.vp9StreamCopyOverride,
      onSubmit: (name, _, paths,
          {required av1Override, required vp9Override}) async {
        try {
          await cubit.updateLibrary(
            libraryId: lib.id,
            name: name == lib.name ? null : name,
            rootPaths: _pathsEqual(paths, lib.rootPaths) ? null : paths,
            av1Override: _diffOverride(
              initialOverrides.av1StreamCopyOverride,
              av1Override,
            ),
            vp9Override: _diffOverride(
              initialOverrides.vp9StreamCopyOverride,
              vp9Override,
            ),
          );
          messenger.showSnackBar(SnackBar(
            content: Text('Library "$name" updated'),
          ));
        } catch (e) {
          messenger.showSnackBar(SnackBar(
            content: Text('Could not update library: $e'),
          ));
        }
      },
    );
  }

  /// Build the 3-state PATCH update sentinel for one codec — `null`
  /// when the operator didn't touch the field, otherwise an explicit
  /// `clear` / `value(true|false)`.
  static LibraryOverrideUpdate? _diffOverride(bool? initial, bool? next) {
    if (initial == next) return null; // unchanged
    if (next == null) return const LibraryOverrideUpdate.clear();
    return LibraryOverrideUpdate.value(next);
  }

  Future<void> _confirmRemove(BuildContext context, Library lib) async {
    final cubit = context.read<LibraryCubit>();
    final messenger = ScaffoldMessenger.of(context);
    // Plan 19 §M8 — sidecar cleanup checkbox; defaults to true so the
    // common-case "I'm removing this library and don't want orphan
    // transcoded files lying around" is the one-click path.
    bool deleteSidecars = true;
    // Fetch the per-library sidecar count + size (plan-19 close-out
    // sharp edge fix) so the operator sees what the checkbox is
    // actually about to delete.  One-shot, best-effort — if the
    // request fails we render the checkbox without the count rather
    // than block the deletion entirely.
    TranscodeStorageLibraryBreakdown? sidecarSummary;
    try {
      final storage =
          await GetIt.I<TranscodeRepository>().getStorage();
      sidecarSummary = storage.byLibrary[lib.id];
    } catch (_) {
      sidecarSummary = null;
    }
    // Guard the BuildContext usage across the async gap above — if
    // the Library page got disposed while the storage probe was in
    // flight, abort the dialog cleanly rather than touching a stale
    // context.
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => FluxGlassDialog(
          title: Text('Remove "${lib.name}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This removes only the library entry and its file index from '
                'Fluxora. Your source files on disk are never deleted by this '
                'app.',
              ),
              const SizedBox(height: AppSpacing.s14),
              InkWell(
                onTap: () => setLocal(() => deleteSidecars = !deleteSidecars),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: deleteSidecars
                              ? AppColors.violet
                              : const Color(0x08FFFFFF),
                          border: Border.all(
                            color: deleteSidecars
                                ? AppColors.violet
                                : AppColors.borderHover,
                            width: 1,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppRadii.xs),
                        ),
                        child: deleteSidecars
                            ? const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.s10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sidecarSummary != null && sidecarSummary.count > 0
                                  ? 'Also delete ${sidecarSummary.count} '
                                      'transcoded sidecar'
                                      '${sidecarSummary.count == 1 ? "" : "s"}'
                                      ' (${_formatBytes(sidecarSummary.bytes)})'
                                  : 'Also delete transcoded sidecars',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textBright,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sidecarSummary != null && sidecarSummary.count == 0
                                  ? 'No transcoded files to delete for this '
                                      'library.'
                                  : 'Removes any H.264 transcoded files this '
                                      'library produced. Source files are '
                                      'never touched.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMutedV2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await cubit.deleteLibrary(lib.id, deleteSidecars: deleteSidecars);
      messenger.showSnackBar(SnackBar(
        content: Text('Library "${lib.name}" removed'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not remove library: $e'),
      ));
    }
  }

  static String _typeKey(LibraryType t) => switch (t) {
        LibraryType.movies => 'movies',
        LibraryType.tv => 'tv',
        LibraryType.music => 'music',
        LibraryType.files => 'files',
      };

  static bool _pathsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ── Add / Edit shared dialog ───────────────────────────────────────────────────

/// Callback signature for the shared library form dialog.  The override
/// args are always passed (default `null` when the dialog isn't showing
/// the codec section); call sites that don't care about overrides
/// declare them as `_, _` in their lambda.
typedef LibraryFormSubmit = void Function(
  String name,
  String type,
  List<String> paths, {
  required bool? av1Override,
  required bool? vp9Override,
});

/// Top-level helper that opens the "Add Library" form.
///
/// Lifted out of `_LibraryViewState` so the surrounding shell can reuse it
/// (the Refresh / Add Library buttons now live on the `LibraryShell` page
/// header, outside the screen's State scope).  Only uses `context` for the
/// cubit + messenger lookups; no widget-state access.
Future<void> showAddLibraryDialog(BuildContext context) async {
  final cubit = context.read<LibraryCubit>();
  final messenger = ScaffoldMessenger.of(context);
  await _showLibraryFormDialog(
    context: context,
    title: 'Add Library',
    submitLabel: 'Create Library',
    typeEditable: true,
    onSubmit: (name, type, paths,
        {required av1Override, required vp9Override}) async {
      try {
        await cubit.createLibrary(name, type, paths);
        messenger.showSnackBar(SnackBar(
          content: Text('Library "$name" created'),
        ));
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('Could not create library: $e'),
        ));
      }
    },
  );
}

Future<void> _showLibraryFormDialog({
  required BuildContext context,
  required String title,
  required String submitLabel,
  required LibraryFormSubmit onSubmit,
  String? initialName,
  String? initialType,
  List<String>? initialPaths,
  bool typeEditable = true,
  bool showCodecOverrides = false,
  bool? initialAv1Override,
  bool? initialVp9Override,
}) async {
  final nameController = TextEditingController(text: initialName ?? '');
  String type = initialType ?? 'movies';
  final paths = List<String>.from(initialPaths ?? const <String>[]);
  String? nameError;
  bool? av1Override = initialAv1Override;
  bool? vp9Override = initialVp9Override;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setLocal) => FluxGlassDialog(
        maxWidth: 540,
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Library Name',
                  errorText: nameError,
                ),
              ),
              const SizedBox(height: AppSpacing.s14),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Library Type'),
                items: const [
                  DropdownMenuItem(value: 'movies', child: Text('Movies')),
                  DropdownMenuItem(value: 'tv', child: Text('TV Shows')),
                  DropdownMenuItem(value: 'music', child: Text('Music')),
                  DropdownMenuItem(value: 'files', child: Text('Documents')),
                ],
                onChanged: typeEditable
                    ? (val) {
                        if (val != null) setLocal(() => type = val);
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.s18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Folders',
                      style: AppTypography.captionV2.copyWith(
                        color: AppColors.textMutedV2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Add folder'),
                    onPressed: () async {
                      final picked = await FilePicker.getDirectoryPath();
                      if (picked != null && !paths.contains(picked)) {
                        setLocal(() {
                          paths.add(picked);
                          // Auto-populate the Library Name from the
                          // picked folder's basename when the field is
                          // still empty — operators can override it for
                          // a custom name.  2026-05-16 owner ask.
                          if (nameController.text.trim().isEmpty) {
                            final basename = picked
                                .split(RegExp(r'[\\/]'))
                                .where((p) => p.isNotEmpty)
                                .lastOrNull;
                            if (basename != null && basename.isNotEmpty) {
                              nameController.text = basename;
                            }
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
              if (paths.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x08FFFFFF),
                    border: Border.all(color: const Color(0x0DFFFFFF)),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    'No folders selected. Add at least one to continue.',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textFaint),
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < paths.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x08FFFFFF),
                          border: Border.all(color: const Color(0x0DFFFFFF)),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_outlined,
                                size: 14, color: AppColors.violet),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                paths[i],
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  color: AppColors.textBody,
                                  height: 1.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 14),
                              tooltip: 'Remove path',
                              onPressed: () =>
                                  setLocal(() => paths.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              if (showCodecOverrides) ...[
                const SizedBox(height: AppSpacing.s18),
                Text(
                  'Stream original codec to clients',
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textMutedV2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.s10),
                _CodecOverrideRow(
                  label: 'AV1',
                  value: av1Override,
                  onChanged: (v) => setLocal(() => av1Override = v),
                ),
                const SizedBox(height: AppSpacing.s8),
                _CodecOverrideRow(
                  label: 'VP9',
                  value: vp9Override,
                  onChanged: (v) => setLocal(() => vp9Override = v),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                setLocal(() => nameError = 'Name is required');
                return;
              }
              if (paths.isEmpty) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('Add at least one folder.')),
                );
                return;
              }
              Navigator.of(dialogCtx).pop();
              onSubmit(
                name,
                type,
                List<String>.from(paths),
                av1Override: av1Override,
                vp9Override: vp9Override,
              );
            },
            child: Text(submitLabel),
          ),
        ],
      ),
    ),
  );
}

// ── Loading ────────────────────────────────────────────────────────────────────

/// Renders the same outer scaffold as `_LoadedBody` (optional stat
/// strip + toolbar + grid area) but with placeholder content in the
/// data-dependent slots — `_SmallStatTile` values become "—", grid
/// shows ghost cards.  Lets the operator see the page shell + chrome
/// immediately while the cubit fetches `/library` + `/storage`.
class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody({
    required this.activeTab,
    required this.sortBy,
    required this.viewMode,
    required this.filters,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onFiltersChanged,
  });

  final String activeTab;
  final _SortBy sortBy;
  final _ViewMode viewMode;
  final _LibraryFilters filters;
  final ValueChanged<_SortBy> onSortChanged;
  final ValueChanged<_ViewMode> onViewModeChanged;
  final ValueChanged<_LibraryFilters> onFiltersChanged;

  @override
  Widget build(BuildContext context) {
    final isAll = activeTab == 'all';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAll) ...[
          const _SkeletonStatTilesRow(),
          const SizedBox(height: AppSpacing.s18),
        ],
        _ToolbarRow(
          sortBy: sortBy,
          viewMode: viewMode,
          filters: filters,
          // No real result count yet — toolbar's count label hides
          // when 0 / handles gracefully.
          resultCount: 0,
          onSortChanged: onSortChanged,
          onViewModeChanged: onViewModeChanged,
          onFiltersChanged: onFiltersChanged,
        ),
        const SizedBox(height: AppSpacing.s14),
        const _SkeletonGrid(),
      ],
    );
  }
}

class _SkeletonStatTilesRow extends StatelessWidget {
  const _SkeletonStatTilesRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _SmallStatTile(
            icon: Icons.folder_outlined,
            label: 'Total Libraries',
            value: '—',
            color: AppColors.violet,
          ),
        ),
        SizedBox(width: AppSpacing.s14),
        Expanded(
          child: _SmallStatTile(
            icon: Icons.insert_drive_file_outlined,
            label: 'Total Files',
            value: '—',
            color: AppColors.blue,
          ),
        ),
        SizedBox(width: AppSpacing.s14),
        Expanded(
          child: _SmallStatTile(
            icon: Icons.storage_outlined,
            label: 'Total Size',
            value: '—',
            color: AppColors.emerald,
          ),
        ),
        SizedBox(width: AppSpacing.s14),
        Expanded(
          child: _SmallStatTile(
            icon: Icons.refresh_rounded,
            label: 'Last Scan',
            value: '—',
            color: AppColors.amber,
          ),
        ),
      ],
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 280.0;
        final cols = (constraints.maxWidth / itemWidth).floor().clamp(1, 3);
        const spacing = AppSpacing.s14;
        final tileWidth =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < 4; i++)
              SizedBox(
                width: tileWidth,
                child: const _SkeletonLibraryCard(),
              ),
          ],
        );
      },
    );
  }
}

class _SkeletonLibraryCard extends StatelessWidget {
  const _SkeletonLibraryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    );
  }
}

// ── Error ──────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined,
              color: AppColors.textDim, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            style:
                AppTypography.body.copyWith(color: AppColors.textMutedV2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Loaded body ────────────────────────────────────────────────────────────────

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.state,
    required this.activeTab,
    required this.selectedLibraryId,
    required this.sortBy,
    required this.viewMode,
    required this.filters,
    required this.onSelectLibrary,
    required this.onAddLibrary,
    required this.onScan,
    required this.onEdit,
    required this.onRemove,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onFiltersChanged,
  });

  final LibraryLoaded state;
  final String activeTab;
  final String? selectedLibraryId;
  final _SortBy sortBy;
  final _ViewMode viewMode;
  final _LibraryFilters filters;
  final ValueChanged<Library> onSelectLibrary;
  final VoidCallback onAddLibrary;
  final ValueChanged<Library> onScan;
  final ValueChanged<Library> onEdit;
  final ValueChanged<Library> onRemove;
  final ValueChanged<_SortBy> onSortChanged;
  final ValueChanged<_ViewMode> onViewModeChanged;
  final ValueChanged<_LibraryFilters> onFiltersChanged;

  List<Library> get _visibleLibraries {
    Iterable<Library> list = state.libraries;

    final typeFilter = _typeForTab(activeTab);
    if (typeFilter != null) list = list.where((l) => l.type == typeFilter);

    if (filters.enrichedOnly) {
      final enrichedLibIds = state.files
          .where((f) => f.posterUrl != null)
          .map((f) => f.libraryId)
          .toSet();
      list = list.where((l) => enrichedLibIds.contains(l.id));
    }
    if (filters.withFilesOnly) {
      list = list.where((l) => l.fileCount > 0);
    }
    if (filters.recentlyScanned) {
      final cutoff =
          DateTime.now().toUtc().subtract(const Duration(days: 7));
      list = list.where(
          (l) => l.lastScanned != null && l.lastScanned!.toUtc().isAfter(cutoff));
    }

    final sorted = list.toList();
    switch (sortBy) {
      case _SortBy.name:
        sorted.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortBy.lastScanned:
        sorted.sort((a, b) => (b.lastScanned ?? DateTime.utc(0))
            .compareTo(a.lastScanned ?? DateTime.utc(0)));
      case _SortBy.fileCount:
        sorted.sort((a, b) => b.fileCount.compareTo(a.fileCount));
      case _SortBy.totalSize:
        sorted.sort((a, b) => b.totalSizeBytes.compareTo(a.totalSizeBytes));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final isAll = activeTab == 'all';
    final visible = _visibleLibraries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAll) ...[
          _StatTilesRow(state: state),
          const SizedBox(height: AppSpacing.s18),
        ],

        _ToolbarRow(
          sortBy: sortBy,
          viewMode: viewMode,
          filters: filters,
          resultCount: visible.length,
          onSortChanged: onSortChanged,
          onViewModeChanged: onViewModeChanged,
          onFiltersChanged: onFiltersChanged,
        ),
        const SizedBox(height: AppSpacing.s14),

        if (visible.isEmpty && filters.isActive)
          _FiltersEmptyState(
            onClear: () => onFiltersChanged(const _LibraryFilters()),
          )
        else if (visible.isEmpty && !isAll)
          _TabEmptyState(activeTab: activeTab, onAdd: onAddLibrary)
        else if (viewMode == _ViewMode.grid)
          _LibraryGrid(
            libraries: visible,
            selectedId: selectedLibraryId,
            onSelect: onSelectLibrary,
            onAddLibrary: onAddLibrary,
            onScan: onScan,
            onEdit: onEdit,
            onRemove: onRemove,
          )
        else
          _LibraryList(
            libraries: visible,
            files: state.files,
            selectedId: selectedLibraryId,
            onSelect: onSelectLibrary,
            onScan: onScan,
            onEdit: onEdit,
            onRemove: onRemove,
          ),
      ],
    );
  }
}

class _TabEmptyState extends StatelessWidget {
  const _TabEmptyState({required this.activeTab, required this.onAdd});

  final String activeTab;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final label = switch (activeTab) {
      'movies' => 'movies',
      'tv' => 'TV shows',
      'music' => 'music',
      'docs' => 'documents',
      _ => 'libraries',
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_outlined,
              size: 56, color: AppColors.textFaint),
          const SizedBox(height: 14),
          Text('No $label libraries yet',
              style:
                  AppTypography.body.copyWith(color: AppColors.textMutedV2)),
          const SizedBox(height: 6),
          Text('Add a folder of $label to get started.',
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textFaint)),
          const SizedBox(height: 16),
          FluxButton(
            variant: FluxButtonVariant.primary,
            icon: Icons.add_rounded,
            onPressed: onAdd,
            child: const Text('Add Library'),
          ),
        ],
      ),
    );
  }
}

// ── Stat tiles row ─────────────────────────────────────────────────────────────

class _StatTilesRow extends StatelessWidget {
  const _StatTilesRow({required this.state});

  final LibraryLoaded state;

  static String _formatLastScanned(List<Library> libs) {
    DateTime? latest;
    for (final lib in libs) {
      if (lib.lastScanned != null) {
        if (latest == null || lib.lastScanned!.isAfter(latest)) {
          latest = lib.lastScanned;
        }
      }
    }
    if (latest == null) return 'Never';
    final now = DateTime.now().toUtc();
    final diff = now.difference(latest.toUtc());
    // Compact "10h" instead of "10h ago" — the stat tile is narrow and
    // the trailing "ago" was truncating to "10h a…".  The "Last Scan"
    // label already implies the "ago" reading.
    if (diff.inSeconds < 60) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final totalFiles =
        state.libraries.fold<int>(0, (acc, l) => acc + l.fileCount);
    final totalLibraries = state.libraries.length;
    final lastScan = _formatLastScanned(state.libraries);

    final storageState = context.watch<StorageCubit>().state;
    final totalSizeStr = storageState is StorageLoaded
        ? humanBytes(storageState.breakdown.totalBytes)
        : humanBytes(state.libraries
            .fold<int>(0, (acc, l) => acc + l.totalSizeBytes));

    // Original 4-card layout restored at ~60 % size — uses a local
    // `_SmallStatTile` instead of the shared `StatTile` so the
    // Dashboard's full-size version isn't affected.
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Total Libraries $totalLibraries',
            child: _SmallStatTile(
              icon: Icons.folder_outlined,
              label: 'Total Libraries',
              value: '$totalLibraries',
              color: AppColors.violet,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Semantics(
            label: 'Total Files $totalFiles',
            child: _SmallStatTile(
              icon: Icons.insert_drive_file_outlined,
              label: 'Total Files',
              value: totalFiles.toString(),
              color: AppColors.blue,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Semantics(
            label: 'Total Size $totalSizeStr',
            child: _SmallStatTile(
              icon: Icons.storage_outlined,
              label: 'Total Size',
              value: totalSizeStr,
              color: AppColors.emerald,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Semantics(
            label: 'Last Scan $lastScan',
            child: _SmallStatTile(
              icon: Icons.refresh_rounded,
              label: 'Last Scan',
              value: lastScan,
              color: AppColors.amber,
            ),
          ),
        ),
      ],
    );
  }
}

/// Smaller variant of the shared `StatTile` — same visual treatment
/// (FluxCard + icon badge + label + value) at ~60 % of the original
/// height.  Local to the Library screen so the Dashboard's full-size
/// metric tiles aren't affected.
class _SmallStatTile extends StatelessWidget {
  const _SmallStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge — 32×32 (was 44×44 in the full-size StatTile).
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Center(
              child: Icon(icon, size: 16, color: color),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textMutedV2,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textBright,
                    height: 1.1,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


String humanBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final formatted = value < 10
      ? value.toStringAsFixed(2)
      : value < 100
          ? value.toStringAsFixed(1)
          : value.toStringAsFixed(0);
  return '$formatted ${units[unitIndex]}';
}

// ── Library grid ───────────────────────────────────────────────────────────────

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({
    required this.libraries,
    required this.selectedId,
    required this.onSelect,
    required this.onAddLibrary,
    required this.onScan,
    required this.onEdit,
    required this.onRemove,
  });

  final List<Library> libraries;
  final String? selectedId;
  final ValueChanged<Library> onSelect;
  final VoidCallback onAddLibrary;
  final ValueChanged<Library> onScan;
  final ValueChanged<Library> onEdit;
  final ValueChanged<Library> onRemove;

  @override
  Widget build(BuildContext context) {
    if (libraries.isEmpty) {
      return _AddLibraryPlaceholder(onTap: onAddLibrary);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 280.0;
        final cols = (constraints.maxWidth / itemWidth).floor().clamp(1, 3);
        const spacing = AppSpacing.s14;
        final tileWidth =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;

        // Inline "+ Add library" placeholder retired 2026-05-16 — the
        // header's `+ Add Library` button is the single entry point;
        // having two duplicated affordances was confusing.
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final lib in libraries)
              SizedBox(
                width: tileWidth,
                child: _LibraryCard(
                  library: lib,
                  isSelected: lib.id == selectedId,
                  onTap: () => onSelect(lib),
                  onScan: () => onScan(lib),
                  onEdit: () => onEdit(lib),
                  onRemove: () => onRemove(lib),
                  onOpenFiles: () =>
                      context.go(Routes.libraryFiles(lib.id)),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Library card ───────────────────────────────────────────────────────────────

class _LibraryCard extends StatefulWidget {
  const _LibraryCard({
    required this.library,
    required this.isSelected,
    required this.onTap,
    required this.onScan,
    required this.onEdit,
    required this.onRemove,
    required this.onOpenFiles,
  });

  final Library library;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onScan;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onOpenFiles;

  @override
  State<_LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<_LibraryCard> {
  bool _hovered = false;

  // Timestamp-based double-tap detection.  Used instead of
  // `GestureDetector.onDoubleTap` because having DoubleTap in the arena
  // forces Tap to wait ~300 ms for double-tap disambiguation, which
  // makes selection feel sluggish.  With only `onTap` registered, the
  // arena has no competition and fires instantly on release.
  DateTime? _lastTapAt;

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!).inMilliseconds < 300) {
      _lastTapAt = null;
      widget.onOpenFiles();
      return;
    }
    _lastTapAt = now;
    widget.onTap();
  }

  static Gradient _gradientFor(LibraryType type) => switch (type) {
        LibraryType.movies => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a0f2e), Color(0xFF3a1a5a), Color(0xFF6b3aa6)],
            stops: [0.0, 0.5, 1.0],
          ),
        LibraryType.tv => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0a1929), Color(0xFF1e3a5f), Color(0xFF3b82c4)],
            stops: [0.0, 0.5, 1.0],
          ),
        LibraryType.music => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2a0a1f), Color(0xFF5a1a3a), Color(0xFFc43a6a)],
            stops: [0.0, 0.5, 1.0],
          ),
        LibraryType.files => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0a1a2a), Color(0xFF1a3f5f), Color(0xFF06b6d4)],
            stops: [0.0, 0.5, 1.0],
          ),
      };

  static Color _accentFor(LibraryType type) => switch (type) {
        LibraryType.movies => AppColors.violet,
        LibraryType.tv => AppColors.blue,
        LibraryType.music => AppColors.pink,
        LibraryType.files => AppColors.cyan,
      };

  static IconData _iconFor(LibraryType type) => switch (type) {
        LibraryType.movies => Icons.movie_outlined,
        LibraryType.tv => Icons.tv_outlined,
        LibraryType.music => Icons.music_note_outlined,
        LibraryType.files => Icons.folder_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(widget.library.type);
    final lib = widget.library;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        // Plain `onTap` (no `onDoubleTap`) so Tap is alone in the
        // gesture arena and fires instantly on release — no 300 ms
        // disambiguation wait.  Double-tap detection is timestamp-
        // based inside `_handleTap`.
        onTap: _handleTap,
        child: AnimatedContainer(
          // 80 ms (was 150 ms) so the border / shadow change snaps in
          // quickly enough to feel "instant" after a click.  Long
          // enough not to be jarring; short enough that operators
          // don't perceive it as latency.
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 168),
          decoration: BoxDecoration(
            gradient: _gradientFor(lib.type),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.violet
                  : const Color(0x0FFFFFFF),
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    // Toned-down selection glow (2026-05-16 owner review).
                    // Drops the 1 px spread shadow that was creating a
                    // violet "ring" around the card; keeps a softer drop
                    // shadow so the selected card still reads as lifted.
                    BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          transform: (_hovered && !widget.isSelected)
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          // Card body uses a fixed height + ConstrainedBox so the Stack
          // and its non-positioned Column child get tight vertical
          // constraints — required for the inner Spacers to flex
          // correctly. Without this, the Column receives unbounded
          // height from the Stack and layout collapses (the bug that
          // piled stat tiles + toolbar + page header into the same
          // vertical band).
          child: SizedBox(
            height: 168,
            child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (lib.coverUrls.isNotEmpty)
                  Positioned.fill(child: _PosterMosaic(urls: lib.coverUrls))
                else
                  // Fallback when no TMDB posters exist (Music / Documents,
                  // or movie libraries without enrichment).  Libraries with
                  // files render a 2×2 mosaic of deterministic gradient
                  // tiles seeded by library id so the card still reads as
                  // a populated surface; empty libraries keep the single
                  // centered icon so the operator can tell at a glance the
                  // library has nothing in it yet.
                  Positioned.fill(
                    child: _GradientMosaicFallback(
                      libraryId: lib.id,
                      typeIcon: _iconFor(lib.type),
                      showMosaic: lib.fileCount > 0,
                    ),
                  ),
                // Dark gradient overlay — darker at both top (behind the
                // icon badge + file-count pill + menu) and bottom (behind
                // the name + path), lighter in the middle so the poster
                // mosaic stays visible.  Sandwich pattern requested by
                // owner on 2026-05-16.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xAA000000), // top scrim: ~67% black
                          Color(0x22000000), // mid:        ~13% black
                          Color(0xDD000000), // bottom:    ~87% black
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Compact type-icon badge.  Shrunk from 32×32
                          // (2026-05-16) since the new 72 px faded
                          // centre-icon already conveys the library
                          // type — this small chip is now just a colour
                          // accent matching the type.
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.3),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.xs),
                            ),
                            child: Center(
                              child: Icon(
                                _iconFor(lib.type),
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // File count pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0x66000000),
                              border: Border.all(
                                  color: const Color(0x33FFFFFF)),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.xs),
                            ),
                            child: Text(
                              '${lib.fileCount} file${lib.fileCount == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _CardMenuButton(
                            onScan: widget.onScan,
                            onEdit: widget.onEdit,
                            onRemove: widget.onRemove,
                            onOpenFiles: widget.onOpenFiles,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        lib.name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lib.rootPaths.isEmpty
                            ? 'No path'
                            : lib.rootPaths.length == 1
                                ? lib.rootPaths.first
                                : '${lib.rootPaths.first}  +${lib.rootPaths.length - 1} more',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xB3FFFFFF),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _CardMenuButton extends StatelessWidget {
  const _CardMenuButton({
    required this.onScan,
    required this.onEdit,
    required this.onRemove,
    required this.onOpenFiles,
  });

  final VoidCallback onScan;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onOpenFiles;

  @override
  Widget build(BuildContext context) {
    return FluxGlassMenu<String>(
      width: 180,
      onSelected: (value) {
        switch (value) {
          case 'open':
            onOpenFiles();
          case 'scan':
            onScan();
          case 'edit':
            onEdit();
          case 'remove':
            onRemove();
        }
      },
      items: const [
        FluxGlassMenuItem(
            value: 'open',
            label: 'Open files',
            icon: Icons.folder_open_outlined),
        FluxGlassMenuItem(
            value: 'scan', label: 'Scan', icon: Icons.refresh_rounded),
        FluxGlassMenuItem(
            value: 'edit', label: 'Edit', icon: Icons.edit_outlined),
        FluxGlassMenuItem(
          value: 'remove',
          label: 'Remove',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        child: const Icon(Icons.more_horiz_rounded,
            size: 16, color: Colors.white),
      ),
    );
  }
}

// ── Poster mosaic (1× hero / 2×2 grid) ────────────────────────────────────────

class _PosterMosaic extends StatelessWidget {
  const _PosterMosaic({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return _Poster(url: urls[0]);
    }
    final pair = urls.take(4).toList();
    if (pair.length == 2) {
      return Row(
        children: [
          Expanded(child: _Poster(url: pair[0])),
          const SizedBox(width: 1),
          Expanded(child: _Poster(url: pair[1])),
        ],
      );
    }
    if (pair.length == 3) {
      return Row(
        children: [
          Expanded(child: _Poster(url: pair[0])),
          const SizedBox(width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _Poster(url: pair[1])),
                const SizedBox(height: 1),
                Expanded(child: _Poster(url: pair[2])),
              ],
            ),
          ),
        ],
      );
    }
    // 4-up
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _Poster(url: pair[0])),
              const SizedBox(width: 1),
              Expanded(child: _Poster(url: pair[1])),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _Poster(url: pair[2])),
              const SizedBox(width: 1),
              Expanded(child: _Poster(url: pair[3])),
            ],
          ),
        ),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0x14000000)),
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const ColoredBox(color: Color(0x14000000)),
    );
  }
}

/// Deterministic gradient-mosaic fallback for libraries without TMDB
/// poster art.  Same six gradients as the mobile `AppGradientPlaceholders`
/// palette so the visual language stays consistent across surfaces; key is
/// `<libraryId>-<tileIndex>` so a single library always renders the same
/// colour band per slot (stable across scroll / rebuild).
class _GradientMosaicFallback extends StatelessWidget {
  const _GradientMosaicFallback({
    required this.libraryId,
    required this.typeIcon,
    required this.showMosaic,
  });

  final String libraryId;
  final IconData typeIcon;
  final bool showMosaic;

  static const _palette = <LinearGradient>[
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA855F7), Color(0xFF22D3EE)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEC4899), Color(0xFFF59E0B)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFFA855F7), Color(0xFFEC4899)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
  ];

  static LinearGradient _gradientForKey(String key) {
    if (key.isEmpty) return _palette.first;
    final h = key.hashCode & 0x7fffffff;
    return _palette[h % _palette.length];
  }

  Widget _tile(int index) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _gradientForKey('$libraryId-$index'),
      ),
      child: Center(
        child: Icon(
          typeIcon,
          size: 26,
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showMosaic) {
      // No files — keep the single centered faded icon so it's obvious the
      // library is empty (not "we couldn't fetch posters").
      return Center(
        child: Icon(
          typeIcon,
          size: 72,
          color: Colors.white.withValues(alpha: 0.10),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _tile(0)),
              const SizedBox(width: 1),
              Expanded(child: _tile(1)),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _tile(2)),
              const SizedBox(width: 1),
              Expanded(child: _tile(3)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Add Library placeholder tile ───────────────────────────────────────────────

class _AddLibraryPlaceholder extends StatefulWidget {
  const _AddLibraryPlaceholder({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddLibraryPlaceholder> createState() =>
      _AddLibraryPlaceholderState();
}

class _AddLibraryPlaceholderState extends State<_AddLibraryPlaceholder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 168),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0x0DA855F7)
                : const Color(0x0AA855F7),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: _hovered
                  ? const Color(0x66A855F7)
                  : const Color(0x4DA855F7),
              width: 1.5,
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AddIcon(),
                SizedBox(height: 8),
                Text(
                  'Add Library',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Add a new library to get started',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.textFaint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddIcon extends StatelessWidget {
  const _AddIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0x2DA855F7),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.add_rounded, size: 18, color: AppColors.violet),
      ),
    );
  }
}

// ── Right detail panel ─────────────────────────────────────────────────────────

class _LibraryDetailPanel extends StatelessWidget {
  const _LibraryDetailPanel({
    required this.library,
    required this.onScan,
    required this.onEnrichTmdb,
    required this.onRegenerateThumbnails,
    required this.onEdit,
    required this.onRemove,
    required this.onOpenFiles,
  });

  final Library library;
  final VoidCallback onScan;
  final VoidCallback onEnrichTmdb;
  final VoidCallback onRegenerateThumbnails;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onOpenFiles;

  static Color _accentFor(LibraryType type) => switch (type) {
        LibraryType.movies => AppColors.violet,
        LibraryType.tv => AppColors.blue,
        LibraryType.music => AppColors.pink,
        LibraryType.files => AppColors.cyan,
      };

  static IconData _iconFor(LibraryType type) => switch (type) {
        LibraryType.movies => Icons.movie_outlined,
        LibraryType.tv => Icons.tv_outlined,
        LibraryType.music => Icons.music_note_outlined,
        LibraryType.files => Icons.folder_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(library.type);

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0x0DFFFFFF)),
        ),
        color: Color(0x800D0B1C),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Center(
                    child: Icon(_iconFor(library.type),
                        size: 18, color: accent),
                  ),
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Text(
                    library.name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _HeaderIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit library',
                  onTap: onEdit,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),

            // ── Library path ──────────────────────────────────────────
            Text(
              'Library Path',
              style: AppTypography.captionV2.copyWith(
                  color: AppColors.textMutedV2, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.s6),
            _LibraryPathsList(paths: library.rootPaths),
            const SizedBox(height: AppSpacing.s18),

            // ── Statistics ────────────────────────────────────────────
            Text(
              'Statistics',
              style: AppTypography.h2.copyWith(color: AppColors.textBright),
            ),
            const SizedBox(height: AppSpacing.s10),
            _DetailRow(
              label: 'Total Files',
              value: '${library.fileCount}',
              isLast: false,
            ),
            _DetailRow(
              label: 'Total Size',
              value: humanBytes(library.totalSizeBytes),
              isLast: false,
            ),
            _DetailRow(
              label: 'Last Scanned',
              value: library.lastScanned != null
                  ? _formatRelative(library.lastScanned!)
                  : 'Never',
              isLast: true,
            ),
            const SizedBox(height: AppSpacing.s18),

            // ── Actions ───────────────────────────────────────────────
            Text(
              'Actions',
              style: AppTypography.h2.copyWith(color: AppColors.textBright),
            ),
            const SizedBox(height: AppSpacing.s10),
            _ActionTile(
              icon: Icons.refresh_rounded,
              title: 'Scan Library',
              sub: 'Scan for new files and updates',
              onTap: onScan,
            ),
            const SizedBox(height: AppSpacing.s6),
            _ActionTile(
              icon: Icons.cloud_download_outlined,
              title: 'Rescan TMDB',
              sub: 'Fill in missing posters, titles, and overviews',
              onTap: onEnrichTmdb,
            ),
            const SizedBox(height: AppSpacing.s6),
            _ActionTile(
              icon: Icons.image_outlined,
              title: 'Regenerate Thumbnails',
              sub: 'Re-extract video frames + cover art for this library',
              onTap: onRegenerateThumbnails,
            ),
            const SizedBox(height: AppSpacing.s6),
            _ActionTile(
              icon: Icons.folder_open_outlined,
              title: 'View Library Files',
              sub: 'Browse all files in this library',
              onTap: onOpenFiles,
            ),
            const SizedBox(height: AppSpacing.s6),
            _ActionTile(
              icon: Icons.edit_outlined,
              title: 'Edit Library',
              sub: 'Rename or change folders',
              onTap: onEdit,
            ),
            const SizedBox(height: AppSpacing.s10),
            _DangerActionTile(onTap: onRemove),
          ],
        ),
      ),
    );
  }

  static String _formatRelative(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          waitDuration: const Duration(milliseconds: 600),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0x0DA855F7)
                  : Colors.transparent,
              border: Border.all(
                color: _hovered
                    ? const Color(0x1AA855F7)
                    : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hovered ? AppColors.violet : AppColors.textMutedV2,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryPathsList extends StatefulWidget {
  const _LibraryPathsList({required this.paths});

  final List<String> paths;

  static const int _kCollapsedCount = 2;

  @override
  State<_LibraryPathsList> createState() => _LibraryPathsListState();
}

class _LibraryPathsListState extends State<_LibraryPathsList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final paths = widget.paths;
    if (paths.isEmpty) {
      return const _PathTile(path: '—');
    }

    const collapsed = _LibraryPathsList._kCollapsedCount;
    final hasMore = paths.length > collapsed;
    final visible =
        (_expanded || !hasMore) ? paths : paths.sublist(0, collapsed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _PathTile(path: visible[i]),
        ],
        if (hasMore) ...[
          const SizedBox(height: 6),
          _ViewAllToggle(
            expanded: _expanded,
            hiddenCount: paths.length - collapsed,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ],
    );
  }
}

class _PathTile extends StatefulWidget {
  const _PathTile({required this.path});

  final String path;

  @override
  State<_PathTile> createState() => _PathTileState();
}

class _PathTileState extends State<_PathTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final canOpen = widget.path.isNotEmpty && widget.path != '—';
    final hovered = _hovered && canOpen;

    return MouseRegion(
      cursor: canOpen ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canOpen
            ? () => openPathInFileManager(
                  widget.path,
                  messenger: ScaffoldMessenger.maybeOf(context),
                )
            : null,
        child: Tooltip(
          message: canOpen ? widget.path : '',
          waitDuration: const Duration(milliseconds: 600),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: hovered
                  ? const Color(0x0DA855F7)
                  : const Color(0x08FFFFFF),
              border: Border.all(
                color: hovered
                    ? const Color(0x1AA855F7)
                    : const Color(0x0DFFFFFF),
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined,
                    size: 12, color: AppColors.violet),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.path,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      color: AppColors.textBody,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 12,
                  color: hovered
                      ? AppColors.violet
                      : AppColors.textMutedV2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewAllToggle extends StatelessWidget {
  const _ViewAllToggle({
    required this.expanded,
    required this.hiddenCount,
    required this.onTap,
  });

  final bool expanded;
  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          hoverColor: const Color(0x0DA855F7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  expanded ? 'Show less' : 'View all ($hiddenCount more)',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.violet,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: AppColors.violet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.isLast,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0x08FFFFFF))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMutedV2,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              color: AppColors.textBody,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.sub,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0x0DA855F7)
                  : const Color(0x05FFFFFF),
              border: Border.all(
                color: _hovered
                    ? const Color(0x1AA855F7)
                    : const Color(0x0AFFFFFF),
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 14, color: AppColors.textMutedV2),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textBody,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        widget.sub,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          color: AppColors.textFaint,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 11, color: AppColors.textFaint),
              ],
            ),
          ),
        ),
      );
  }
}

class _DangerActionTile extends StatefulWidget {
  const _DangerActionTile({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DangerActionTile> createState() => _DangerActionTileState();
}

class _DangerActionTileState extends State<_DangerActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0x14EF4444)
                : const Color(0x0FEF4444),
            border: Border.all(
              color: _hovered
                  ? const Color(0x4DEF4444)
                  : const Color(0x33EF4444),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 14, color: Color(0xFFF87171)),
              SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remove Library',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF87171),
                        height: 1.3,
                      ),
                    ),
                    Text(
                      'Remove this library and its data',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        color: Color(0xB2F87171),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toolbar row (Sort · Filters · Grid/List toggle) ────────────────────────────

class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({
    required this.sortBy,
    required this.viewMode,
    required this.filters,
    required this.resultCount,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onFiltersChanged,
  });

  final _SortBy sortBy;
  final _ViewMode viewMode;
  final _LibraryFilters filters;
  final int resultCount;
  final ValueChanged<_SortBy> onSortChanged;
  final ValueChanged<_ViewMode> onViewModeChanged;
  final ValueChanged<_LibraryFilters> onFiltersChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ResultCountLabel(count: resultCount, filtersActive: filters.isActive),
        const Spacer(),
        _SortMenu(value: sortBy, onChanged: onSortChanged),
        const SizedBox(width: AppSpacing.s10),
        _FiltersButton(
          filters: filters,
          onTap: () => _openFiltersDialog(context),
        ),
        const SizedBox(width: AppSpacing.s10),
        _ViewModeToggle(value: viewMode, onChanged: onViewModeChanged),
      ],
    );
  }

  Future<void> _openFiltersDialog(BuildContext context) async {
    final result = await showDialog<_LibraryFilters>(
      context: context,
      builder: (ctx) => _FiltersDialog(initial: filters),
    );
    if (result != null) onFiltersChanged(result);
  }
}

class _ResultCountLabel extends StatelessWidget {
  const _ResultCountLabel(
      {required this.count, required this.filtersActive});

  final int count;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    final base = '$count ${count == 1 ? 'library' : 'libraries'}';
    return Text(
      filtersActive ? '$base · filtered' : base,
      style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedV2),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final _SortBy value;
  final ValueChanged<_SortBy> onChanged;

  @override
  Widget build(BuildContext context) {
    return FluxGlassMenu<_SortBy>(
      width: 200,
      onSelected: onChanged,
      items: [
        for (final option in _SortBy.values)
          FluxGlassMenuItem(
            value: option,
            label: option.label,
            selected: option == value,
          ),
      ],
      child: _ToolbarChip(
        icon: Icons.sort_rounded,
        label: 'Sort: ${value.label}',
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.filters, required this.onTap});

  final _LibraryFilters filters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: _ToolbarChip(
        icon: Icons.tune_rounded,
        label: filters.isActive
            ? 'Filters · ${filters.activeCount}'
            : 'Filters',
        accent: filters.isActive,
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.violet.withValues(alpha: 0.12)
            : AppColors.bgRaised,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: accent ? AppColors.violet : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: accent ? AppColors.violet : AppColors.textMutedV2),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.bodySmall.copyWith(
                color: accent ? AppColors.violet : AppColors.textBright,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.value, required this.onChanged});

  final _ViewMode value;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeButton(
            icon: Icons.grid_view_rounded,
            tooltip: 'Grid view',
            selected: value == _ViewMode.grid,
            onTap: () => onChanged(_ViewMode.grid),
          ),
          _ViewModeButton(
            icon: Icons.view_list_rounded,
            tooltip: 'List view',
            selected: value == _ViewMode.list,
            onTap: () => onChanged(_ViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.violet.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected ? AppColors.violet : AppColors.textMutedV2,
          ),
        ),
      ),
    );
  }
}

// ── Filters dialog ─────────────────────────────────────────────────────────────

class _FiltersDialog extends StatefulWidget {
  const _FiltersDialog({required this.initial});
  final _LibraryFilters initial;

  @override
  State<_FiltersDialog> createState() => _FiltersDialogState();
}

class _FiltersDialogState extends State<_FiltersDialog> {
  late _LibraryFilters _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    return FluxGlassDialog(
      title: const Text('Filter libraries'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterCheckbox(
            label: 'Enriched only',
            description: 'Libraries that have at least one TMDB-matched file',
            value: _draft.enrichedOnly,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(enrichedOnly: v)),
          ),
          _FilterCheckbox(
            label: 'With files',
            description: 'Libraries that have one or more files indexed',
            value: _draft.withFilesOnly,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(withFilesOnly: v)),
          ),
          _FilterCheckbox(
            label: 'Recently scanned',
            description: 'Scanned in the last 7 days',
            value: _draft.recentlyScanned,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(recentlyScanned: v)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const _LibraryFilters()),
          child: const Text('Clear all'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
          onPressed: () => Navigator.of(context).pop(_draft),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _FilterCheckbox extends StatelessWidget {
  const _FilterCheckbox({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.violet,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.body
                          .copyWith(color: AppColors.textBright)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textMutedV2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filters empty-state ────────────────────────────────────────────────────────

class _FiltersEmptyState extends StatelessWidget {
  const _FiltersEmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_alt_off_outlined,
              size: 56, color: AppColors.textFaint),
          const SizedBox(height: 14),
          Text('No libraries match the current filters',
              style:
                  AppTypography.body.copyWith(color: AppColors.textMutedV2)),
          const SizedBox(height: 16),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            icon: Icons.clear_rounded,
            onPressed: onClear,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

// ── Library list view ──────────────────────────────────────────────────────────

class _LibraryList extends StatelessWidget {
  const _LibraryList({
    required this.libraries,
    required this.files,
    required this.selectedId,
    required this.onSelect,
    required this.onScan,
    required this.onEdit,
    required this.onRemove,
  });

  final List<Library> libraries;
  final List<MediaFile> files;
  final String? selectedId;
  final ValueChanged<Library> onSelect;
  final ValueChanged<Library> onScan;
  final ValueChanged<Library> onEdit;
  final ValueChanged<Library> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          for (var i = 0; i < libraries.length; i++)
            _LibraryListRow(
              library: libraries[i],
              isSelected: libraries[i].id == selectedId,
              isFirst: i == 0,
              isLast: i == libraries.length - 1,
              onTap: () => onSelect(libraries[i]),
              onOpenFiles: () =>
                  context.go(Routes.libraryFiles(libraries[i].id)),
              onScan: () => onScan(libraries[i]),
              onEdit: () => onEdit(libraries[i]),
              onRemove: () => onRemove(libraries[i]),
            ),
        ],
      ),
    );
  }
}

class _LibraryListRow extends StatelessWidget {
  const _LibraryListRow({
    required this.library,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onOpenFiles,
    required this.onScan,
    required this.onEdit,
    required this.onRemove,
  });

  final Library library;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onOpenFiles;
  final VoidCallback onScan;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  static IconData _iconFor(LibraryType t) => switch (t) {
        LibraryType.movies => Icons.movie_outlined,
        LibraryType.tv => Icons.tv_outlined,
        LibraryType.music => Icons.music_note_outlined,
        LibraryType.files => Icons.folder_outlined,
      };

  static Color _accentFor(LibraryType t) => switch (t) {
        LibraryType.movies => AppColors.violet,
        LibraryType.tv => AppColors.blue,
        LibraryType.music => AppColors.pink,
        LibraryType.files => AppColors.cyan,
      };

  static String _formatLastScanned(DateTime? ts) {
    if (ts == null) return 'Never';
    final diff = DateTime.now().toUtc().difference(ts.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(library.type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst
            ? const Radius.circular(AppRadii.lg)
            : Radius.zero,
        bottom: isLast
            ? const Radius.circular(AppRadii.lg)
            : Radius.zero,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            bottom: isLast
                ? BorderSide.none
                : const BorderSide(color: AppColors.borderSubtle),
          ),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(_iconFor(library.type), size: 18, color: accent),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    library.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textBright,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    library.rootPaths.isEmpty
                        ? 'No paths'
                        : library.rootPaths.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textMutedV2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                '${library.fileCount} files',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textBody),
              ),
            ),
            Expanded(
              child: Text(
                humanBytes(library.totalSizeBytes),
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textBody),
              ),
            ),
            Expanded(
              child: Text(
                _formatLastScanned(library.lastScanned),
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textMutedV2),
              ),
            ),
            _ListRowAction(
              icon: Icons.folder_open_outlined,
              tooltip: 'Open files',
              onPressed: onOpenFiles,
            ),
            _ListRowAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Scan',
              onPressed: onScan,
            ),
            _ListRowAction(
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            _ListRowAction(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Remove',
              onPressed: onRemove,
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListRowAction extends StatelessWidget {
  const _ListRowAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 18,
        color: destructive
            ? const Color(0xFFEF4444)
            : AppColors.textMutedV2,
      ),
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
    );
  }
}

// ── Per-library codec override segmented control (plan 19 §M8) ──────────────

/// 3-state segmented control for one codec's per-library passthrough
/// override.  Maps to the API field as:
///   - "Use global"  → `null`
///   - "Always"      → `true`
///   - "Never"       → `false`
class _CodecOverrideRow extends StatelessWidget {
  const _CodecOverrideRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: AppTypography.body.copyWith(
              color: AppColors.textBright,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x08FFFFFF),
              border: Border.all(color: const Color(0x0DFFFFFF)),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(
              children: [
                _Segment(
                  label: 'Use global',
                  selected: value == null,
                  onTap: () => onChanged(null),
                ),
                _SegmentDivider(),
                _Segment(
                  label: 'Always',
                  selected: value == true,
                  onTap: () => onChanged(true),
                ),
                _SegmentDivider(),
                _Segment(
                  label: 'Never',
                  selected: value == false,
                  onTap: () => onChanged(false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm - 1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                selected ? AppColors.violet.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(AppRadii.sm - 1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: selected ? AppColors.violetTint : AppColors.textBody,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: const Color(0x0DFFFFFF),
    );
  }
}

/// Human-readable bytes formatter — duplicates the helper in
/// `transcode/presentation/widgets/{candidates,history}_tab.dart` and
/// `folder_tree.dart`.  Worth consolidating into a shared util when
/// the next desktop refactor round comes through.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1024;
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}
