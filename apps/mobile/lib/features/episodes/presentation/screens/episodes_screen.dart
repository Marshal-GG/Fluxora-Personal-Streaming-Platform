/// Episodes screen for shows.
///
/// Season selector chips at the top, then a vertical list of episode rows
/// (thumbnail 120×68 + title + date + duration + violet progress bar).
/// Pulls from `MockMediaItem.seasons`; if the item isn't a show or has no
/// seasons, renders an empty state.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/shared/data/mock_data.dart';

class EpisodesScreen extends StatefulWidget {
  const EpisodesScreen({required this.id, super.key});

  final String id;

  @override
  State<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends State<EpisodesScreen> {
  late int _seasonIndex;
  late MockMediaItem? _item;

  @override
  void initState() {
    super.initState();
    _item = MockData.findById(widget.id);
    _seasonIndex = (_item?.seasons?.isNotEmpty ?? false) ? 0 : -1;
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item == null || item.seasons == null || item.seasons!.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: FluxAppBar(
          title: 'Episodes',
          onBack: () => context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        body: const _EmptyState(),
      );
    }

    final season = item.seasons![_seasonIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        title: item.title,
        onBack: () => context.canPop() ? context.pop() : context.go(Routes.home),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: item.seasons!.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final s = item.seasons![i];
                  final selected = i == _seasonIndex;
                  return _SeasonChip(
                    label: 'Season ${s.number}',
                    selected: selected,
                    onTap: () => setState(() => _seasonIndex = i),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _EpisodeRow(
                episode: season.episodes[i],
                index: i + 1,
              ),
              childCount: season.episodes.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _SeasonChip extends StatelessWidget {
  const _SeasonChip({
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

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, required this.index});

  final MockEpisode episode;
  final int index;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 68,
                    decoration: BoxDecoration(gradient: episode.gradient),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  if (episode.progress != null && episode.progress! > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: 3,
                        child: LinearProgressIndicator(
                          value: episode.progress!.clamp(0.0, 1.0),
                          backgroundColor: const Color(0x33FFFFFF),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.violet),
                          minHeight: 3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index.toString().padLeft(2, '0')}.  ${episode.title}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textBright,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${episode.date}  ·  ${episode.duration}',
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.textMutedV2,
                    ),
                  ),
                ],
              ),
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
            const Icon(Icons.tv_off_outlined,
                size: 48, color: AppColors.textDim),
            const SizedBox(height: 12),
            Text(
              'No episodes available',
              style: AppTypography.h2.copyWith(color: AppColors.textBright),
            ),
            const SizedBox(height: 4),
            Text(
              'Episode metadata isn\'t wired up for this title yet.',
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
