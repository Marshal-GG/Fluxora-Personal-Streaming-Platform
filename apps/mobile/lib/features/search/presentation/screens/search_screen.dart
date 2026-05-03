/// Search tab — text-driven discover surface.
///
/// Empty state: "Recent searches" list + "Try" suggestion chips. Active
/// state (any non-empty query): top-3 horizontal poster rail + sectioned
/// vertical results. Mocked client-side over [MockData] until the server
/// exposes a `/search` endpoint.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/shared/data/mock_data.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  String _query = '';

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

  List<MockMediaItem> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    // Phase B replaces this client-side filter with `GET /files/search`;
    // the `recentlyAdded` source is gone (now a real Home rail) so search
    // pulls only from the still-mock continue-watching + trending pools
    // until Phase B lands.
    final pool = [
      ...MockData.continueWatching,
      ...MockData.trending,
    ];
    final seen = <String>{};
    return pool
        .where(
          (m) =>
              m.title.toLowerCase().contains(q) ||
              m.subtitle.toLowerCase().contains(q),
        )
        .where((m) => seen.add(m.id))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final isActive = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const FluxAppBar(title: 'Search'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FluxTextField(
              controller: _controller,
              hint: 'Search Fluxora',
              leadingIcon: Icons.search,
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              trailing: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.textMutedV2),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
          ),
          Expanded(
            child: isActive
                ? _ActiveResults(query: _query, results: results)
                : const _EmptyState(),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
            onTap: () {},
          ),
        const SizedBox(height: 16),
        const FluxSectionHeader(eyebrow: 'Try', title: 'Trending searches'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in MockData.trendingSearches)
              GestureDetector(
                onTap: () {},
                child: FluxChip(term, color: FluxChipColor.purple),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActiveResults extends StatelessWidget {
  const _ActiveResults({required this.query, required this.results});

  final String query;
  final List<MockMediaItem> results;

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
                'Try a different title or genre.',
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
    final rest = results.length > 3 ? results.sublist(3) : const <MockMediaItem>[];

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
                title: m.title,
                subtitle: m.subtitle,
                gradient: m.gradient,
                imageUrl: m.imageUrl,
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
                child: Container(
                  width: 44,
                  height: 60,
                  decoration: BoxDecoration(gradient: m.gradient),
                ),
              ),
              title: Text(
                m.title,
                style: AppTypography.body.copyWith(
                  color: AppColors.textBright,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                m.subtitle,
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
