/// Home tab — discover landing.
///
/// Two rails + a browse strip:
///   1. Continue watching (hero size 150×220 with progress bar)
///   2. Browse — 4-up content-type quick-jump strip (Movies / Shows /
///      Music / Documents) routing to the Library tab pre-filtered by
///      `?filter=`.  Replaces the old "Trending now" rail per mobile
///      redesign plan §17.2 (2026-05-08 trending rip-out).
///   3. Recently added (rail 116×174)
///
/// App bar: avatar (left) + Fluxora wordmark (center) + bell + cast
/// (right).
///
/// Phase A: Recently-added consumes [RecentCubit] (`GET /files/recent`).
/// Phase B: Continue-watching consumes [ContinueWatchingCubit]
/// (`GET /auth/clients/me/continue-watching`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/home/presentation/cubit/continue_watching_cubit.dart';
import 'package:fluxora_mobile/features/home/presentation/cubit/recent_cubit.dart';
import 'package:fluxora_mobile/shared/widgets/gradients.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RecentCubit _recent;
  late final ContinueWatchingCubit _cw;

  @override
  void initState() {
    super.initState();
    _recent = GetIt.I<RecentCubit>();
    _cw = GetIt.I<ContinueWatchingCubit>();
    if (_recent.state is RecentInitial) {
      _recent.load();
    }
    if (_cw.state is ContinueWatchingInitial) {
      _cw.load();
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_recent.refresh(), _cw.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RecentCubit>.value(value: _recent),
        BlocProvider<ContinueWatchingCubit>.value(value: _cw),
      ],
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
            children: const [
              SizedBox(height: 12),
              _ContinueWatchingRail(),
              _BrowseStrip(),
              _RecentRail(),
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

/// Browse strip — 4-up content-type quick-jump tiles.  Replaces the old
/// "Trending now" rail (mobile redesign plan §17.2).  Each tile pushes
/// the Library tab pre-filtered via `?filter=`.  Documents map to the
/// `files` filter since v1 collapsed Documents into the Files type.
class _BrowseStrip extends StatelessWidget {
  const _BrowseStrip();

  static const _tiles = <_BrowseTileSpec>[
    _BrowseTileSpec(
      label: 'Movies',
      filter: 'movies',
      icon: LucideIcons.clapperboard,
      gradient: AppGradientPlaceholders.violetDeep,
    ),
    _BrowseTileSpec(
      label: 'Shows',
      filter: 'shows',
      icon: LucideIcons.tv,
      gradient: AppGradientPlaceholders.indigoCyan,
    ),
    _BrowseTileSpec(
      label: 'Music',
      filter: 'music',
      icon: LucideIcons.music,
      gradient: AppGradientPlaceholders.pinkAmber,
    ),
    _BrowseTileSpec(
      label: 'Documents',
      filter: 'files',
      icon: LucideIcons.fileText,
      gradient: AppGradientPlaceholders.emeraldBlue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FluxSectionHeader(eyebrow: 'Browse', title: 'Your library'),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _BrowseTile(spec: _tiles[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BrowseTileSpec {
  const _BrowseTileSpec({
    required this.label,
    required this.filter,
    required this.icon,
    required this.gradient,
  });

  final String label;
  final String filter;
  final IconData icon;
  final Gradient gradient;
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({required this.spec});

  final _BrowseTileSpec spec;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(Routes.libraryWithFilter(spec.filter)),
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: spec.gradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(spec.icon, size: 20, color: AppColors.textBright),
            Text(
              spec.label,
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textBright,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Continue-watching rail — wired to the live [ContinueWatchingCubit]
/// (Phase B).  Falls back to a 4-tile placeholder while loading and to
/// an empty surface when there are no in-progress files.
class _ContinueWatchingRail extends StatelessWidget {
  const _ContinueWatchingRail();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContinueWatchingCubit, ContinueWatchingState>(
      builder: (context, state) {
        return switch (state) {
          ContinueWatchingInitial() || ContinueWatchingLoading() =>
            const _RailFrame(
              title: 'Continue watching',
              eyebrow: 'Pick up where you left off',
              size: FluxPosterSize.hero,
              itemCount: 4,
              itemBuilder: _placeholderHeroTile,
            ),
          ContinueWatchingFailure(:final message) =>
            _CwRailFailure(message: message),
          ContinueWatchingLoaded(:final items) when items.isEmpty =>
            const _CwRailEmpty(),
          ContinueWatchingLoaded(:final items) => _RailFrame(
              title: 'Continue watching',
              eyebrow: 'Pick up where you left off',
              size: FluxPosterSize.hero,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final f = items[i];
                final placeholder =
                    AppGradientPlaceholders.forKey(f.id);
                final progress = (f.durationSec ?? 0) > 0
                    ? (f.resumeSec / f.durationSec!).clamp(0.0, 1.0)
                    : null;
                return FluxPoster(
                  title: f.title ?? f.name,
                  subtitle: _resumeSubtitle(f),
                  imageUrl: f.posterUrl,
                  gradient: placeholder,
                  size: FluxPosterSize.hero,
                  qualityBadge: f.qualityBadge,
                  progress: progress,
                  onTap: () => context.push(Routes.detail(f.id)),
                );
              },
            ),
        };
      },
    );
  }

  static Widget _placeholderHeroTile(BuildContext context, int i) {
    return Container(
      width: 150,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
    );
  }

  static String _resumeSubtitle(MediaFile f) {
    final dur = f.durationSec;
    if (dur == null || dur <= 0) return 'Continue';
    final remaining = (dur - f.resumeSec).clamp(0.0, dur);
    final minutes = (remaining / 60).round();
    if (minutes < 1) return 'Almost done';
    if (minutes < 60) return '$minutes min left';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h left' : '${h}h ${m}m left';
  }
}

class _CwRailEmpty extends StatelessWidget {
  const _CwRailEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FluxSectionHeader(
            eyebrow: 'Pick up where you left off',
            title: 'Continue watching',
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
              'Nothing in progress yet — start a title and it\'ll show up here.',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textMutedV2),
            ),
          ),
        ],
      ),
    );
  }
}

class _CwRailFailure extends StatelessWidget {
  const _CwRailFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FluxSectionHeader(
            eyebrow: 'Pick up where you left off',
            title: 'Continue watching',
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
                      context.read<ContinueWatchingCubit>().refresh(),
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
