import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_cubit.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_state.dart';
import 'package:fluxora_desktop/features/storage/domain/repositories/storage_repository.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_cubit.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
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
  FluxTab(id: 'photos', label: 'Photos', icon: Icons.photo_outlined),
];

LibraryType? _typeForTab(String tabId) => switch (tabId) {
      'movies' => LibraryType.movies,
      'tv' => LibraryType.tv,
      'music' => LibraryType.music,
      'docs' => LibraryType.files,
      _ => null,
    };

// ── Main view ──────────────────────────────────────────────────────────────────

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  String _activeTab = 'all';
  Library? _selectedLibrary;

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
                      _selectedLibrary == null &&
                      state.libraries.isNotEmpty) {
                    setState(() => _selectedLibrary = state.libraries.first);
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
                              child: const Text('Scan Library'),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            FluxButton(
                              variant: FluxButtonVariant.primary,
                              icon: Icons.add_rounded,
                              iconRight: Icons.keyboard_arrow_down_rounded,
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
                            selectedLibrary: _selectedLibrary,
                            onSelectLibrary: (lib) =>
                                setState(() => _selectedLibrary = lib),
                            onAddLibrary: () => _showAddLibraryDialog(context),
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
              final lib = _selectedLibrary;
              if (lib == null) return const SizedBox.shrink();
              return _LibraryDetailPanel(
                library: lib,
                onScan: () => context.read<LibraryCubit>().scanLibrary(lib.id),
                onRemove: () => _confirmRemove(context, lib),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddLibraryDialog(BuildContext context) async {
    final nameController = TextEditingController();
    String type = 'movies';
    final cubit = context.read<LibraryCubit>();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Library'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Library Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Library Type'),
                items: const [
                  DropdownMenuItem(value: 'movies', child: Text('Movies')),
                  DropdownMenuItem(value: 'tv', child: Text('TV Shows')),
                  DropdownMenuItem(value: 'music', child: Text('Music')),
                  DropdownMenuItem(value: 'files', child: Text('Documents')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => type = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final result = await FilePicker.getDirectoryPath();
                if (result != null) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    try {
                      await cubit.createLibrary(
                          nameController.text, type, [result]);
                    } catch (_) {
                      // cubit already logs
                    }
                  }
                }
              },
              child: const Text('Select Folder & Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, Library lib) async {
    // No delete method on cubit yet — show a not-implemented snackbar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Remove library "${lib.name}" — not implemented yet')),
    );
  }
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
              color: AppColors.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            style:
                AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
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
    required this.selectedLibrary,
    required this.onSelectLibrary,
    required this.onAddLibrary,
  });

  final LibraryLoaded state;
  final String activeTab;
  final Library? selectedLibrary;
  final ValueChanged<Library> onSelectLibrary;
  final VoidCallback onAddLibrary;

  List<Library> get _visibleLibraries {
    final typeFilter = _typeForTab(activeTab);
    if (typeFilter == null) return state.libraries;
    return state.libraries.where((l) => l.type == typeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAll = activeTab == 'all';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stat tiles (All tab only) ─────────────────────────────────────
        if (isAll) ...[
          _StatTilesRow(state: state),
          const SizedBox(height: AppSpacing.s18),

          // ── View toggle / sort ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // View toggle (grid active by default — grid is the only view)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0x2DA855F7),
                        borderRadius: BorderRadius.circular(AppRadii.xs),
                      ),
                      child: const Icon(
                        Icons.grid_view_rounded,
                        size: 14,
                        color: AppColors.violetTint,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      child: const Icon(
                        Icons.view_list_rounded,
                        size: 14,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FluxButton(
                    variant: FluxButtonVariant.secondary,
                    size: FluxButtonSize.sm,
                    iconRight: Icons.keyboard_arrow_down_rounded,
                    onPressed: () {},
                    child: const Text('Sort by: Name'),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  FluxButton(
                    variant: FluxButtonVariant.secondary,
                    size: FluxButtonSize.sm,
                    icon: Icons.tune_rounded,
                    onPressed: () {},
                    child: const Text('Filter'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s14),
        ],

        // ── Library grid ─────────────────────────────────────────────────
        _LibraryGrid(
          libraries: _visibleLibraries,
          selectedId: selectedLibrary?.id,
          onSelect: onSelectLibrary,
          onAddLibrary: onAddLibrary,
        ),
      ],
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
    final totalFiles = state.files.length;
    final totalLibraries = state.libraries.length;
    final lastScan = _formatLastScanned(state.libraries);

    final storageState = context.watch<StorageCubit>().state;
    final totalSizeStr = storageState is StorageLoaded
        ? _humanBytes(storageState.breakdown.totalBytes)
        : '—';

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

  static String _humanBytes(int bytes) {
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
}

// ── Library grid ───────────────────────────────────────────────────────────────

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({
    required this.libraries,
    required this.selectedId,
    required this.onSelect,
    required this.onAddLibrary,
  });

  final List<Library> libraries;
  final String? selectedId;
  final ValueChanged<Library> onSelect;
  final VoidCallback onAddLibrary;

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

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final lib in libraries)
              SizedBox(
                width: (constraints.maxWidth - spacing * (cols - 1)) / cols,
                child: _LibraryCard(
                  library: lib,
                  isSelected: lib.id == selectedId,
                  onTap: () => onSelect(lib),
                ),
              ),
            SizedBox(
              width: (constraints.maxWidth - spacing * (cols - 1)) / cols,
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
  });

  final Library library;
  final bool isSelected;
  final VoidCallback onTap;

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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 130),
          decoration: BoxDecoration(
            gradient: _gradientFor(widget.library.type),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg - 1),
            child: Stack(
              children: [
                // Gradient overlay
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xB3000000)],
                        stops: [0.3, 1.0],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type icon badge
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
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
                            _iconFor(widget.library.type),
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Name + file count
                      Text(
                        widget.library.name,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.library.rootPaths.isNotEmpty
                                  ? widget.library.rootPaths.first
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
                          ),
                          const Icon(
                            Icons.more_horiz_rounded,
                            size: 14,
                            color: Color(0x99FFFFFF),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          constraints: const BoxConstraints(minHeight: 130),
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
    required this.onRemove,
  });

  final Library library;
  final VoidCallback onScan;
  final VoidCallback onRemove;

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
        color: Color(0x800D0B1C), // rgba(13,11,28,0.5)
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
                    child: Icon(_iconFor(library.type), size: 18, color: accent),
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
                const Icon(Icons.edit_outlined, size: 14, color: AppColors.textMutedV2),
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
                  const Icon(Icons.open_in_new_rounded,
                      size: 12, color: AppColors.textFaint),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s18),

            // ── Description (no backend field — empty placeholder) ────
            Text(
              'Description',
              style: AppTypography.captionV2.copyWith(
                  color: AppColors.textMutedV2, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.s6),
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x08FFFFFF),
                border: Border.all(color: const Color(0x0DFFFFFF)),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(height: AppSpacing.s18),

            // ── Statistics ────────────────────────────────────────────
            Text(
              'Statistics',
              style: AppTypography.h2.copyWith(color: AppColors.textBright),
            ),
            const SizedBox(height: AppSpacing.s10),
            // TODO: per-library file count + size require adding `fileCount`
            // and `sizeBytes` to the Library entity in fluxora_core
            // (server already returns `file_count` from /api/v1/library);
            // requires a build_runner regen. Tracked for next sprint.
            const _DetailRow(label: 'Total Files', value: '—', isLast: false),
            const _DetailRow(label: 'Total Size', value: '—', isLast: false),
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
            const _ActionTile(
              icon: Icons.auto_awesome_outlined,
              title: 'Rescan Metadata',
              sub: 'Refresh all metadata and thumbnails',
              enabled: false,
            ),
            const SizedBox(height: AppSpacing.s6),
            _ActionTile(
              icon: Icons.folder_open_outlined,
              title: 'View Library Files',
              sub: 'Browse all files in this library',
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.s10),
            // Remove (danger)
            _DangerActionTile(
              onTap: onRemove,
            ),
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
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.45,
      child: MouseRegion(
        cursor: widget.enabled && widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: widget.enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
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
              Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFF87171)),
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
