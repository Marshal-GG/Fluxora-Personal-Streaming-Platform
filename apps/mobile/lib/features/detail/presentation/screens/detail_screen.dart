/// Title detail screen — hero + actions + synopsis + cast + similar.
///
/// Pulled by id from `MockData.findById(id)`. For shows, exposes a
/// "Episodes" entry-point that pushes `/episodes/:id`. For movies the
/// primary action is "Play" (currently a no-op until M5 player rebuild).
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/shared/data/mock_data.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({required this.id, super.key});

  final String id;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = MockData.findById(widget.id);
    if (item == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: FluxAppBar(
          title: 'Not found',
          onBack: () => context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        body: const Center(
          child: Text(
            'Item not found',
            style: TextStyle(color: AppColors.textBright),
          ),
        ),
      );
    }

    final similar = item.similarIds
        .map(MockData.findById)
        .whereType<MockMediaItem>()
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: FluxAppBar(
        transparent: true,
        title: '',
        onBack: () => context.canPop() ? context.pop() : context.go(Routes.home),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Hero(item: item),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _PrimaryActions(item: item),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SecondaryActions(item: item),
          ),
          if (item.synopsis != null) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Synopsis(
                text: item.synopsis!,
                expanded: _expanded,
                onToggle: () => setState(() => _expanded = !_expanded),
              ),
            ),
          ],
          if (item.cast.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: FluxSectionHeader(eyebrow: 'Starring', title: 'Cast'),
            ),
            const SizedBox(height: 12),
            _CastRail(members: item.cast),
          ],
          if (item.crew.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: FluxSectionHeader(eyebrow: 'Behind', title: 'Crew'),
            ),
            const SizedBox(height: 12),
            _CastRail(members: item.crew),
          ],
          if (similar.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: FluxSectionHeader(eyebrow: 'You might like', title: 'Similar titles'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 174,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: similar.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final m = similar[i];
                  return FluxPoster(
                    title: m.title,
                    subtitle: m.subtitle,
                    gradient: m.gradient,
                    imageUrl: m.imageUrl,
                    qualityBadge: m.qualityBadge,
                    onTap: () => context.push('/detail/${m.id}'),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.item});

  final MockMediaItem item;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 340 + topPadding,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(gradient: item.gradient)),
          if (item.imageUrl != null)
            Image.network(item.imageUrl!, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0xFF08061A),
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.qualityBadge != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FluxChip(
                      item.qualityBadge!,
                      color: FluxChipColor.purple,
                    ),
                  ),
                Text(
                  item.title,
                  style: AppTypography.displayV2.copyWith(
                    color: AppColors.textBright,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                _MetaRow(item: item),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});

  final MockMediaItem item;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (item.year != null) item.year!,
      if (item.rating != null) '★ ${item.rating}',
      if (item.duration != null) item.duration!,
      if (item.kind == 'show') 'Series',
      if (item.kind == 'movie') 'Movie',
    ];
    return Text(
      parts.join('  ·  '),
      style: AppTypography.captionV2.copyWith(
        color: AppColors.textBody,
        fontSize: 12,
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.item});

  final MockMediaItem item;

  @override
  Widget build(BuildContext context) {
    final isShow = item.kind == 'show' && (item.seasons?.isNotEmpty ?? false);
    return Row(
      children: [
        Expanded(
          child: FluxButton(
            icon: Icons.play_arrow,
            onPressed: () {},
            child: Text(item.progress != null ? 'Resume' : 'Play'),
          ),
        ),
        if (isShow) ...[
          const SizedBox(width: 10),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            onPressed: () => context.push('/episodes/${item.id}'),
            icon: Icons.list_rounded,
            child: const Text('Episodes'),
          ),
        ],
      ],
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.item});

  final MockMediaItem item;

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _IconAction(icon: Icons.add, label: 'Watchlist'),
        ),
        Expanded(
          child: _IconAction(icon: Icons.download_outlined, label: 'Download'),
        ),
        Expanded(
          child: _IconAction(icon: Icons.share_outlined, label: 'Share'),
        ),
        Expanded(
          child: _IconAction(icon: Icons.cast, label: 'Cast'),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textBright, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textMutedV2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Synopsis extends StatelessWidget {
  const _Synopsis({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expanded ? null : 3,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppTypography.body.copyWith(
            color: AppColors.textBody,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onToggle,
          child: Text(
            expanded ? 'Less' : 'More',
            style: AppTypography.captionV2.copyWith(
              color: AppColors.violetTint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CastRail extends StatelessWidget {
  const _CastRail({required this.members});

  final List<MockCastMember> members;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final m = members[i];
          return SizedBox(
            width: 80,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: m.gradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    m.name.split(' ').map((s) => s[0]).take(2).join(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  m.name,
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  m.role,
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textDim,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
