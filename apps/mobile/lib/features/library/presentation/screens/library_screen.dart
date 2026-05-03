/// Library tab — V2 redesign.
///
/// Filter chips (All / Movies / Shows / Music / Photos / Documents) +
/// grid/list toggle + sort button + 3-up `FluxPoster` grid. Pull-to-
/// refresh. Mocked over `MockData` for now since the existing
/// `LibraryRepository` returns *libraries* (containers) rather than the
/// flat media list this redesign expects — a future server endpoint will
/// provide the right shape; until then the legacy `/library-files/:id`
/// deep-link remains the path to actual file browsing.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/shared/data/mock_data.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _LibraryFilter { all, movies, shows, music, photos, docs }
enum _LibraryView { grid, list }
enum _LibrarySort { recent, az, year, rating }

class _LibraryScreenState extends State<LibraryScreen> {
  _LibraryFilter _filter = _LibraryFilter.all;
  _LibraryView _view = _LibraryView.grid;
  _LibrarySort _sort = _LibrarySort.recent;

  static const _filterMeta = {
    _LibraryFilter.all: ('All', null),
    _LibraryFilter.movies: ('Movies', 'movie'),
    _LibraryFilter.shows: ('Shows', 'show'),
    _LibraryFilter.music: ('Music', 'music'),
    _LibraryFilter.photos: ('Photos', 'photo'),
    _LibraryFilter.docs: ('Documents', 'doc'),
  };

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  List<MockMediaItem> get _items {
    final pool = [
      ...MockData.continueWatching,
      ...MockData.trending,
      ...MockData.recentlyAdded,
    ];
    final seen = <String>{};
    final dedup = pool.where((m) => seen.add(m.id)).toList();
    final kindFilter = _filterMeta[_filter]?.$2;
    final filtered = kindFilter == null
        ? dedup
        : dedup.where((m) => m.kind == kindFilter).toList();
    switch (_sort) {
      case _LibrarySort.az:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case _LibrarySort.year:
        filtered.sort((a, b) => b.subtitle.compareTo(a.subtitle));
      case _LibrarySort.rating:
      case _LibrarySort.recent:
        break;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        title: 'Library',
        trailing: [
          IconButton(
            tooltip: _view == _LibraryView.grid ? 'List view' : 'Grid view',
            icon: Icon(
              _view == _LibraryView.grid
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
              color: AppColors.textBright,
            ),
            onPressed: () => setState(
              () => _view = _view == _LibraryView.grid
                  ? _LibraryView.list
                  : _LibraryView.grid,
            ),
            splashRadius: 22,
          ),
          PopupMenuButton<_LibrarySort>(
            tooltip: 'Sort',
            initialValue: _sort,
            color: const Color(0xFF0F0C24),
            icon: const Icon(Icons.sort, color: AppColors.textBright),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => [
              for (final v in _LibrarySort.values)
                PopupMenuItem(
                  value: v,
                  child: Text(
                    switch (v) {
                      _LibrarySort.recent => 'Recently added',
                      _LibrarySort.az => 'A–Z',
                      _LibrarySort.year => 'Year',
                      _LibrarySort.rating => 'Rating',
                    },
                    style: AppTypography.body
                        .copyWith(color: AppColors.textBright, fontSize: 14),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.violet,
        backgroundColor: AppColors.surfaceGlass,
        child: CustomScrollView(
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
                    final selected = f == _filter;
                    return _FilterChipButton(
                      label: _filterMeta[f]!.$1,
                      selected: selected,
                      onTap: () => setState(() => _filter = f),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else if (_view == _LibraryView.grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 116 / 174,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final m = items[i];
                      return FluxPoster(
                        title: m.title,
                        subtitle: m.subtitle,
                        gradient: m.gradient,
                        imageUrl: m.imageUrl,
                        size: FluxPosterSize.full,
                        qualityBadge: m.qualityBadge,
                        progress: m.progress,
                        onTap: () => context.push(Routes.detail(m.id)),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ListRow(
                    item: items[i],
                    onTap: () => context.push(Routes.detail(items[i].id)),
                  ),
                  childCount: items.length,
                ),
              ),
          ],
        ),
      ),
    );
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
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.item, required this.onTap});

  final MockMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 56,
                height: 80,
                decoration: BoxDecoration(gradient: item.gradient),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
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
                    item.subtitle,
                    style: AppTypography.captionV2
                        .copyWith(color: AppColors.textMutedV2),
                  ),
                  if (item.qualityBadge != null) ...[
                    const SizedBox(height: 6),
                    FluxChip(item.qualityBadge!, color: FluxChipColor.purple),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textDim),
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
              'No items in this filter',
              style: AppTypography.h2.copyWith(color: AppColors.textBright),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different category, or pull to refresh.',
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
