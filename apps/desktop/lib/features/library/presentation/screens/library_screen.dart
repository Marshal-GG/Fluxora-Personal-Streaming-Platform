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
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_cubit.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_state.dart';
import 'package:fluxora_desktop/features/storage/domain/repositories/storage_repository.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_cubit.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_state.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_dialog.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_menu.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/stat_tile.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LibraryCubit>(
          create: (_) => LibraryCubit(
            repository: GetIt.I<LibraryRepository>(),
          )..load(),
        ),
        BlocProvider<StorageCubit>(
          create: (_) =>
              StorageCubit(repository: GetIt.I<StorageRepository>())..load(),
        ),
      ],
      child: const _LibraryView(),
    );
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
  const _LibraryView();

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
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgRoot,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main content ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: AppSpacing.s28,
                right: AppSpacing.s28,
                bottom: AppSpacing.s28,
              ),
              child: BlocConsumer<LibraryCubit, LibraryState>(
                listener: (context, state) {
                  // Auto-select first library when loaded.
                  if (state is LibraryLoaded &&
                      _selectedLibraryId == null &&
                      state.libraries.isNotEmpty) {
                    setState(() =>
                        _selectedLibraryId = state.libraries.first.id);
                  }
                  // Drop selection if the selected library disappeared (e.g. delete).
                  if (state is LibraryLoaded &&
                      _selectedLibraryId != null &&
                      !state.libraries.any((l) => l.id == _selectedLibraryId)) {
                    setState(() => _selectedLibraryId = state.libraries.isEmpty
                        ? null
                        : state.libraries.first.id);
                  }
                },
                builder: (context, state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Page header ────────────────────────────────────
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
                                  ? () => context.read<LibraryCubit>().load()
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

                      // ── Tab bar ────────────────────────────────────────
                      FluxTabBar(
                        tabs: _kTabs,
                        activeId: _activeTab,
                        onChange: (id) => setState(() => _activeTab = id),
                      ),
                      const SizedBox(height: AppSpacing.s18),

                      // ── Body ───────────────────────────────────────────
                      switch (state) {
                        LibraryInitial() || LibraryLoading() =>
                          const _LoadingBody(),
                        LibraryLoaded() =>
                          _LoadedBody(
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

  Future<void> _showAddLibraryDialog(BuildContext context) async {
    final cubit = context.read<LibraryCubit>();
    final messenger = ScaffoldMessenger.of(context);
    await _showLibraryFormDialog(
      context: context,
      title: 'Add Library',
      submitLabel: 'Create Library',
      typeEditable: true,
      onSubmit: (name, type, paths) async {
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

  Future<void> _showEditLibraryDialog(
      BuildContext context, Library lib) async {
    final cubit = context.read<LibraryCubit>();
    final messenger = ScaffoldMessenger.of(context);
    await _showLibraryFormDialog(
      context: context,
      title: 'Edit Library',
      submitLabel: 'Save Changes',
      initialName: lib.name,
      initialType: _typeKey(lib.type),
      initialPaths: List<String>.from(lib.rootPaths),
      typeEditable: false,
      onSubmit: (name, _, paths) async {
        try {
          await cubit.updateLibrary(
            libraryId: lib.id,
            name: name == lib.name ? null : name,
            rootPaths: _pathsEqual(paths, lib.rootPaths) ? null : paths,
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

  Future<void> _confirmRemove(BuildContext context, Library lib) async {
    final cubit = context.read<LibraryCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => FluxGlassDialog(
        title: Text('Remove "${lib.name}"?'),
        content: const Text(
          'This removes only the library entry and its file index from '
          'Fluxora. Your files on disk are never deleted by this app.',
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
    );

    if (confirmed != true) return;
    try {
      await cubit.deleteLibrary(lib.id);
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

Future<void> _showLibraryFormDialog({
  required BuildContext context,
  required String title,
  required String submitLabel,
  required void Function(String name, String type, List<String> paths)
      onSubmit,
  String? initialName,
  String? initialType,
  List<String>? initialPaths,
  bool typeEditable = true,
}) async {
  final nameController = TextEditingController(text: initialName ?? '');
  String type = initialType ?? 'movies';
  final paths = List<String>.from(initialPaths ?? const <String>[]);
  String? nameError;

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
                        setLocal(() => paths.add(picked));
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
              onSubmit(name, type, List<String>.from(paths));
            },
            child: Text(submitLabel),
          ),
        ],
      ),
    ),
  );
}

// ── Loading ────────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.violet,
          ),
        ),
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
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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

    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Total Libraries $totalLibraries',
            child: StatTile(
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
            child: StatTile(
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
            child: StatTile(
              icon: Icons.storage_outlined,
              label: 'Total Size',
              value: totalSizeStr,
              color: AppColors.emerald,
              accent: AppColors.textMutedV2,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Semantics(
            label: 'Last Scan $lastScan',
            child: StatTile(
              icon: Icons.refresh_rounded,
              label: 'Last Scan',
              value: lastScan,
              color: AppColors.amber,
              accent: AppColors.textMutedV2,
            ),
          ),
        ),
      ],
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
            SizedBox(
              width: tileWidth,
              child: _AddLibraryPlaceholder(onTap: onAddLibrary),
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
        onTap: widget.onTap,
        onDoubleTap: widget.onOpenFiles,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
                    BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.3),
                      blurRadius: 0,
                      spreadRadius: 1,
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
                  Positioned.fill(child: _PosterMosaic(urls: lib.coverUrls)),
                // Dark gradient overlay for text legibility
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0xCC000000)],
                        stops: [0.3, 1.0],
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
                          // Type icon badge
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.25),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.sm),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                _iconFor(lib.type),
                                size: 16,
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
                        lib.rootPaths.isNotEmpty
                            ? lib.rootPaths.first
                            : 'No path',
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
    required this.onEdit,
    required this.onRemove,
    required this.onOpenFiles,
  });

  final Library library;
  final VoidCallback onScan;
  final VoidCallback onEnrichTmdb;
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
    final path = library.rootPaths.isNotEmpty ? library.rootPaths.first : '—';

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
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 14, color: AppColors.textMutedV2),
                  tooltip: 'Edit library',
                  onPressed: onEdit,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x08FFFFFF),
                border: Border.all(color: const Color(0x0DFFFFFF)),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined,
                      size: 12, color: AppColors.violet),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path,
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
                ],
              ),
            ),
            if (library.rootPaths.length > 1) ...[
              const SizedBox(height: 4),
              Text(
                '+${library.rootPaths.length - 1} more',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textFaint),
              ),
            ],
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
        onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
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
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
