/// Home tab — discover landing.
///
/// Three rails: Continue watching (hero size 150×220 with progress bar),
/// Trending now (rail 116×174), Recently added (rail 116×174). App bar:
/// avatar (left) + Fluxora wordmark (center) + bell + cast (right).
///
/// Phase A backfill: the Recently-added rail now consumes [RecentCubit]
/// (real `GET /files/recent` data — no more `MockData.recentlyAdded`).
/// Continue-watching + Trending are still mock-backed; Phase B replaces
/// them with `/clients/me/continue-watching` + a deletion of the
/// trending rail (decision §5 row 3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/home/presentation/cubit/recent_cubit.dart';
import 'package:fluxora_mobile/shared/data/mock_data.dart';
import 'package:fluxora_mobile/shared/widgets/gradients.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RecentCubit _recent;

  @override
  void initState() {
    super.initState();
    _recent = GetIt.I<RecentCubit>();
    if (_recent.state is RecentInitial) {
      _recent.load();
    }
  }

  Future<void> _refresh() async {
    await _recent.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecentCubit>.value(
      value: _recent,
      child: Scaffold(
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
              _MockRail(
                title: 'Continue watching',
                eyebrow: 'Pick up where you left off',
                items: MockData.continueWatching,
                size: FluxPosterSize.hero,
              ),
              _MockRail(
                title: 'Trending now',
                eyebrow: 'This week',
                items: MockData.trending,
                size: FluxPosterSize.rail,
              ),
              const _RecentRail(),
            ],
          ),
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
        gradient: AppGradientPlaceholders.violetDeep,
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

class _MockRail extends StatelessWidget {
  const _MockRail({
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
    return _RailFrame(
      title: title,
      eyebrow: eyebrow,
      size: size,
      itemCount: items.length,
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
    );
  }
}

/// Recently-added rail — wired to the live [RecentCubit] (Phase A).
class _RecentRail extends StatelessWidget {
  const _RecentRail();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecentCubit, RecentState>(
      builder: (context, state) {
        return switch (state) {
          RecentInitial() || RecentLoading() => const _RailFrame(
              title: 'Recently added',
              eyebrow: 'Fresh on your server',
              size: FluxPosterSize.rail,
              itemCount: 4,
              itemBuilder: _placeholderTile,
            ),
          RecentFailure(:final message) => _RailFailure(message: message),
          RecentLoaded(:final items) when items.isEmpty =>
            const _RailEmpty(),
          RecentLoaded(:final items) => _RailFrame(
              title: 'Recently added',
              eyebrow: 'Fresh on your server',
              size: FluxPosterSize.rail,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final f = items[i];
                final placeholder =
                    AppGradientPlaceholders.forKey(f.id);
                return FluxPoster(
                  title: f.title ?? f.name,
                  subtitle: _subtitleFor(f),
                  imageUrl: f.posterUrl,
                  gradient: placeholder,
                  size: FluxPosterSize.rail,
                  qualityBadge: f.qualityBadge,
                  onTap: () => context.push(Routes.detail(f.id)),
                );
              },
            ),
        };
      },
    );
  }

  static Widget _placeholderTile(BuildContext context, int i) {
    return Container(
      width: 116,
      height: 174,
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
    );
  }

  static String _subtitleFor(MediaFile f) {
    final added = f.createdAt;
    final now = DateTime.now();
    final delta = now.difference(added);
    if (delta.inHours < 24) return 'Added today';
    if (delta.inDays < 2) return 'Added yesterday';
    if (delta.inDays < 8) return 'Added ${delta.inDays}d ago';
    return 'Added ${delta.inDays ~/ 7}w ago';
  }
}

class _RailFrame extends StatelessWidget {
  const _RailFrame({
    required this.title,
    required this.eyebrow,
    required this.size,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String title;
  final String eyebrow;
  final FluxPosterSize size;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

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
              itemCount: itemCount,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: itemBuilder,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailEmpty extends StatelessWidget {
  const _RailEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FluxSectionHeader(
            eyebrow: 'Fresh on your server',
            title: 'Recently added',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0x08FFFFFF),
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No files yet — your next library scan will land here.',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textMutedV2),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailFailure extends StatelessWidget {
  const _RailFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FluxSectionHeader(
            eyebrow: 'Fresh on your server',
            title: 'Recently added',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0x14EF4444),
              border: Border.all(color: const Color(0x40EF4444)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 18, color: Color(0xFFF87171)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: AppTypography.captionV2
                        .copyWith(color: const Color(0xFFF87171)),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.read<RecentCubit>().refresh(),
                  child: Text(
                    'Retry',
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.violetTint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
