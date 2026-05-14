/// Library tab — V2 redesign, real data (Phase A backfill).
///
/// Consumes [LibraryBloc] which fetches `GET /api/v1/library` (library
/// containers, not flat media — the v1 server has no aggregated-media
/// endpoint).  Filter chips collapse to the four `LibraryType` values
/// plus All; grid/list toggle stays.  Tapping a library card navigates
/// to the existing `/library-files/:id` files-browser deep-link.
///
/// `MockMediaItem` references are gone — the screen renders zero mock
/// data per Phase A scope.
///
/// 2026-05-08 (mobile redesign plan §17.2): accepts an optional
/// `initialFilter` string from the route's `?filter=` query param so the
/// Home browse strip + Search "Browse" chip group can pre-filter the
/// tab.  Valid values: `movies` / `shows` / `music` / `files`; anything
/// else (or null) falls back to All.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_bloc.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_event.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_state.dart';
import 'package:fluxora_mobile/shared/widgets/gradients.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.initialFilter});

  /// Optional filter slug from the route's `?filter=` query parameter.
  /// See the file-level doc for accepted values.
  final String? initialFilter;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryBloc>(
      create: (_) => LibraryBloc(repository: GetIt.I<LibraryRepository>())
        ..add(const LibraryStarted()),
      child: _LibraryBody(initialFilter: initialFilter),
    );
  }
}

enum _LibraryFilter { all, movies, shows, music, files }

enum _ViewMode { grid, list }

extension on _LibraryFilter {
  String get label => switch (this) {
        _LibraryFilter.all => 'All',
        _LibraryFilter.movies => 'Movies',
        _LibraryFilter.shows => 'Shows',
        _LibraryFilter.music => 'Music',
        _LibraryFilter.files => 'Files',
      };

  LibraryType? get type => switch (this) {
        _LibraryFilter.all => null,
        _LibraryFilter.movies => LibraryType.movies,
        _LibraryFilter.shows => LibraryType.tv,
        _LibraryFilter.music => LibraryType.music,
        _LibraryFilter.files => LibraryType.files,
      };
}

_LibraryFilter _filterFromSlug(String? slug) {
  return switch (slug) {
    'movies' => _LibraryFilter.movies,
    'shows' => _LibraryFilter.shows,
    'music' => _LibraryFilter.music,
    'files' => _LibraryFilter.files,
    _ => _LibraryFilter.all,
  };
}

class _LibraryBody extends StatefulWidget {
  const _LibraryBody({this.initialFilter});

  final String? initialFilter;

  @override
  State<_LibraryBody> createState() => _LibraryBodyState();
}

class _LibraryBodyState extends State<_LibraryBody> {
  late _LibraryFilter _filter = _filterFromSlug(widget.initialFilter);
  _ViewMode _view = _ViewMode.grid;

  Future<void> _refresh() async {
    context.read<LibraryBloc>().add(const LibraryRefreshed());
  }

  List<Library> _applyFilter(List<Library> all) {
    final type = _filter.type;
    if (type == null) return all;
    return all.where((l) => l.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        title: 'Library',
        trailing: [
          IconButton(
            tooltip: _view == _ViewMode.grid ? 'List view' : 'Grid view',
            icon: Icon(
              _view == _ViewMode.grid
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
              color: AppColors.textBright,
            ),
            onPressed: () => setState(
              () => _view = _view == _ViewMode.grid
                  ? _ViewMode.list
                  : _ViewMode.grid,
            ),
            splashRadius: 22,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.violet,
        backgroundColor: AppColors.surfaceGlass,
        child: BlocBuilder<LibraryBloc, LibraryState>(
          builder: (context, state) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _LibraryFilter.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final f = _LibraryFilter.values[i];
                        return _FilterChipButton(
                          label: f.label,
                          selected: f == _filter,
                          onTap: () => setState(() => _filter = f),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ..._buildContent(state),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContent(LibraryState state) {
    return switch (state) {
      LibraryInitial() || LibraryLoading() => const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _LoadingState(),
          ),
        ],
      LibraryFailure(:final message) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _FailureState(message: message),
          ),
        ],
      LibrarySuccess(:final libraries) => () {
          final filtered = _applyFilter(libraries);
          if (filtered.isEmpty) {
            return const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              ),
            ];
          }
          if (_view == _ViewMode.grid) {
            return [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 156 / 184,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _LibraryCard(library: filtered[i]),
                    childCount: filtered.length,
                  ),
                ),
              ),
            ];
          }
          return [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _LibraryListRow(library: filtered[i]),
                childCount: filtered.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ];
        }(),
    };
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filter by $label',
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.pillBgPurple : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? AppColors.violet : AppColors.borderSubtle,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.violetTint : AppColors.textBody,
            height: 1.0,
          ),
        ),
      ),
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    final gradient = AppGradientPlaceholders.forKey(library.id);
    final cover = library.coverUrls.isNotEmpty ? library.coverUrls.first : null;

    return Semantics(
      button: true,
      label: 'Open ${library.name} library, ${library.fileCount} items',
      child: InkWell(
      onTap: () => context.push(Routes.libraryFiles(library.id)),
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
            if (cover != null)
              Image.network(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC000000)],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FluxChip(
                    library.type.label,
                    color: FluxChipColor.purple,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    library.name,
                    style: AppTypography.h2.copyWith(
                      color: AppColors.textBright,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${library.fileCount} ${library.fileCount == 1 ? "item" : "items"}'
                    ' · ${_formatBytes(library.totalSizeBytes)}',
                    style: AppTypography.captionV2
                        .copyWith(color: AppColors.textBody),
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

class _LibraryListRow extends StatelessWidget {
  const _LibraryListRow({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    final gradient = AppGradientPlaceholders.forKey(library.id);
    final cover = library.coverUrls.isNotEmpty ? library.coverUrls.first : null;

    return Semantics(
      button: true,
      label: 'Open ${library.name} library, ${library.fileCount} items',
      child: InkWell(
      onTap: () => context.push(Routes.libraryFiles(library.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 80,
                child: cover != null
                    ? Image.network(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => DecoratedBox(
                          decoration: BoxDecoration(gradient: gradient),
                        ),
                      )
                    : DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    library.name,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textBright,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${library.type.label} · ${library.fileCount} items'
                    ' · ${_formatBytes(library.totalSizeBytes)}',
                    style: AppTypography.captionV2
                        .copyWith(color: AppColors.textMutedV2),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textDim),
          ],
        ),
      ),
      ),
    );
  }
}

extension on LibraryType {
  String get label => switch (this) {
        LibraryType.movies => 'Movies',
        LibraryType.tv => 'Shows',
        LibraryType.music => 'Music',
        LibraryType.files => 'Files',
      };
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  var v = bytes.toDouble();
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final formatted = v >= 100 || i == 0
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1);
  return '$formatted ${units[i]}';
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.violet,
        ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 44, color: Color(0xFFF87171)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textBright),
            ),
            const SizedBox(height: 12),
            FluxButton(
              variant: FluxButtonVariant.secondary,
              onPressed: () =>
                  context.read<LibraryBloc>().add(const LibraryRefreshed()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined,
                size: 48, color: AppColors.textDim),
            const SizedBox(height: 12),
            Text(
              'No libraries match this filter',
              style: AppTypography.h2.copyWith(color: AppColors.textBright),
            ),
            const SizedBox(height: 4),
            Text(
              'Add a library from the desktop control panel, or pick "All" to see what is configured.',
              textAlign: TextAlign.center,
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textMutedV2),
            ),
          ],
        ),
      ),
    );
  }
}
