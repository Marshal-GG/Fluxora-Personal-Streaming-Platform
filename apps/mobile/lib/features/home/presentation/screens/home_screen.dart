/// Home tab — discover landing.
///
/// Three rails: Continue watching (hero size 150×220 with progress bar),
/// Trending now (rail 116×174), Recently added (rail 116×174). App bar:
/// avatar (left) + Fluxora wordmark (center) + bell + cast (right). Mock
/// data backs every rail until the server exposes equivalent endpoints —
/// see `apps/mobile/lib/shared/data/mock_data.dart`.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/shared/data/mock_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: _AvatarChip(),
        ),
        titleWidget: const FluxoraWordmark(height: 22),
        centerTitle: true,
        trailing: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.textBright),
            onPressed: () => context.push(Routes.notifications),
            splashRadius: 22,
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.cast, color: AppColors.textBright),
            onPressed: () {},
            splashRadius: 22,
            tooltip: 'Cast',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.violet,
        backgroundColor: AppColors.surfaceGlass,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 12),
            _Rail(
              title: 'Continue watching',
              eyebrow: 'Pick up where you left off',
              items: MockData.continueWatching,
              size: FluxPosterSize.hero,
            ),
            _Rail(
              title: 'Trending now',
              eyebrow: 'This week',
              items: MockData.trending,
              size: FluxPosterSize.rail,
            ),
            _Rail(
              title: 'Recently added',
              eyebrow: 'Fresh on your server',
              items: MockData.recentlyAdded,
              size: FluxPosterSize.rail,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: MockGradients.violetDeep,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      alignment: Alignment.center,
      child: const Text(
        'M',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.title,
    required this.eyebrow,
    required this.items,
    required this.size,
  });

  final String title;
  final String eyebrow;
  final List<MockMediaItem> items;
  final FluxPosterSize size;

  @override
  Widget build(BuildContext context) {
    final double posterHeight = size == FluxPosterSize.hero ? 220 : 174;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FluxSectionHeader(
              eyebrow: eyebrow,
              title: title,
              trailing: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.violetTint,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See all',
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.violetTint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: posterHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                return FluxPoster(
                  title: item.title,
                  subtitle: item.subtitle,
                  imageUrl: item.imageUrl,
                  gradient: item.gradient,
                  size: size,
                  qualityBadge: item.qualityBadge,
                  progress: item.progress,
                  onTap: () => context.push(Routes.detail(item.id)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
