/// Search tab — text-driven discover surface.
///
/// Phase B backfill (`docs/10_planning/08_real_data_backfill_plan.md`
/// §3 row 2): consumes [SearchCubit] over `GET /files/search` (server
/// uses SQL `LIKE` for v1).
///
/// Empty state shows:
///   - "Recent searches" — `MockData.recentSearches`, a persistence
///     target (not actual media); lives on until a real search-history
///     feature ships.
///   - "Browse" chip group — content-type shortcuts that push the
///     Library tab pre-filtered via `Routes.libraryWithFilter(...)`.
///     Replaces the old "Trending searches" chip group per mobile
///     redesign plan §17.2 (2026-05-08 trending rip-out).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_mobile/features/search/presentation/cubit/search_cubit.dart';
import 'package:fluxora_mobile/shared/data/mock_data.dart';
import 'package:fluxora_mobile/shared/widgets/gradients.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SearchCubit>(
      create: (_) =>
          SearchCubit(repository: GetIt.I<LibraryRepository>()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    context.read<SearchCubit>().queryChanged(value);
  }

  void _runChip(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    _setQuery(term);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const FluxAppBar(title: 'Search'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, _) {
                return FluxTextField(
                  controller: _controller,
                  hint: 'Search Fluxora',
                  leadingIcon: Icons.search,
                  autofocus: false,
                  onChanged: _setQuery,
                  trailing: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: AppColors.textMutedV2),
                          onPressed: () {
                            _controller.clear();
                            _setQuery('');
                          },
                          tooltip: 'Clear search',
                        )
                      : null,
                );
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) {
                return switch (state) {
                  SearchIdle() => _EmptyState(onChipTap: _runChip),
                  SearchLoading() => const _LoadingState(),
                  SearchFailure(:final message) => _FailureState(
                      message: message,
                      onRetry: () => _setQuery(_controller.text),
                    ),
                  SearchLoaded(:final query, :final results) =>
                    _ActiveResults(query: query, results: results),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onChipTap});

  final void Function(String) onChipTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        FluxSectionHeader(
          eyebrow: 'History',
          title: 'Recent searches',
          trailing: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.violetTint,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Clear',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.violetTint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final term in MockData.recentSearches)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history,
                size: 18, color: AppColors.textMutedV2),
            title: Text(
              term,
              style: AppTypography.body
                  .copyWith(color: AppColors.textBright, fontSize: 14),
            ),
            trailing: const Icon(Icons.north_west,
                size: 16, color: AppColors.textDim),
            onTap: () => onChipTap(term),
          ),
        const SizedBox(height: 16),
        const FluxSectionHeader(eyebrow: 'Browse', title: 'Jump into a category'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final spec in _browseFilters)
              Semantics(
                button: true,
                label: 'Browse ${spec.label}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      context.push(Routes.libraryWithFilter(spec.filter)),
                  child: FluxChip(spec.label, color: FluxChipColor.purple),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BrowseFilterSpec {
  const _BrowseFilterSpec({required this.label, required this.filter});

  final String label;
  final String filter;
}

const List<_BrowseFilterSpec> _browseFilters = [
  _BrowseFilterSpec(label: 'Movies', filter: 'movies'),
  _BrowseFilterSpec(label: 'Shows', filter: 'shows'),
  _BrowseFilterSpec(label: 'Music', filter: 'music'),
  _BrowseFilterSpec(label: 'Documents', filter: 'files'),
];

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
  const _FailureState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
              style: AppTypography.body
                  .copyWith(color: AppColors.textBright),
            ),
            const SizedBox(height: 12),
            FluxButton(
              variant: FluxButtonVariant.secondary,
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveResults extends StatelessWidget {
  const _ActiveResults({required this.query, required this.results});

  final String query;
  final List<MediaFile> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off,
                  size: 48, color: AppColors.textDim),
              const SizedBox(height: 12),
              Text(
                'No results for "$query"',
                style: AppTypography.h2
                    .copyWith(color: AppColors.textBright),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Try a different title, file name, or genre.',
                style: AppTypography.captionV2
                    .copyWith(color: AppColors.textMutedV2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final top = results.take(3).toList();
    final rest =
        results.length > 3 ? results.sublist(3) : const <MediaFile>[];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: FluxSectionHeader(
            eyebrow: 'Top results',
            title: 'Best matches',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 174,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: top.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final m = top[i];
              return FluxPoster(
                title: m.title ?? m.name,
                subtitle: _subtitleFor(m),
                gradient: AppGradientPlaceholders.forKey(m.id),
                imageUrl: m.posterUrl,
                qualityBadge: m.qualityBadge,
                onTap: () => context.push(Routes.detail(m.id)),
              );
            },
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: FluxSectionHeader(
              eyebrow: 'Movies & shows',
              title: 'More results',
            ),
          ),
          const SizedBox(height: 8),
          for (final m in rest)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44,
                  height: 60,
                  child: m.posterUrl != null
                      ? Image.network(
                          m.posterUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => DecoratedBox(
                            decoration: BoxDecoration(
                              gradient:
                                  AppGradientPlaceholders.forKey(m.id),
                            ),
                          ),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppGradientPlaceholders.forKey(m.id),
                          ),
                        ),
                ),
              ),
              title: Text(
                m.title ?? m.name,
                style: AppTypography.body.copyWith(
                  color: AppColors.textBright,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _subtitleFor(m),
                style: AppTypography.captionV2
                    .copyWith(color: AppColors.textMutedV2),
              ),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.textDim),
              onTap: () => context.push(Routes.detail(m.id)),
            ),
        ],
      ],
    );
  }
}

String _subtitleFor(MediaFile m) {
  final parts = <String>[
    if (m.codecName != null) m.codecName!.toUpperCase(),
    if (m.tmdbShowId != null && m.seasonNumber != null && m.episodeNumber != null)
      'S${m.seasonNumber!.toString().padLeft(2, '0')}'
          ' · E${m.episodeNumber!.toString().padLeft(2, '0')}',
  ];
  if (parts.isEmpty) return m.extension.replaceFirst('.', '').toUpperCase();
  return parts.join('  ·  ');
}
