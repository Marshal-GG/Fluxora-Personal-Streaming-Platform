/// Downloads tab — storage indicator + downloading rows + offline rows.
///
/// Matches the prototype JSX at
/// `docs/11_design/prototype/app/mobile/screens/downloads.jsx`.
/// All data is mocked from [MockData.downloads] until the real download
/// manager lands (its own ticket — server-side multi-quality plus a
/// client-side queue runner).
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';

import 'package:fluxora_mobile/shared/data/mock_data.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late List<MockDownload> _items;

  @override
  void initState() {
    super.initState();
    _items = List<MockDownload>.from(MockData.downloads);
  }

  void _delete(String id) {
    setState(() => _items.removeWhere((d) => d.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final downloading = _items
        .where((d) => d.status == MockDownloadStatus.downloading)
        .toList(growable: false);
    final completed = _items
        .where((d) => d.status == MockDownloadStatus.completed)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const _Header(),
            if (downloading.isNotEmpty) ...[
              _SectionLabel(text: 'Downloading · ${downloading.length}'),
              for (final d in downloading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _DownloadingRow(
                    item: d,
                    onPause: () {},
                  ),
                ),
            ],
            if (completed.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionLabel(text: 'Available offline · ${completed.length}'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (var i = 0; i < completed.length; i++)
                      _CompletedRow(
                        item: completed[i],
                        showDivider: i < completed.length - 1,
                        onDelete: () => _delete(completed[i].id),
                      ),
                  ],
                ),
              ),
            ],
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: _EmptyState(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Header (title + storage indicator) ──────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    const used = MockData.storageUsedGb;
    const total = MockData.storageTotalGb;
    final pct = (used / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Downloads',
            style: AppTypography.displayV2.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.textBright,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${used.toStringAsFixed(1)} GB used · '
            '${total.toStringAsFixed(0)} GB available on device',
            style: AppTypography.captionV2.copyWith(
              fontSize: 12.5,
              color: AppColors.textMutedV2,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0x0FFFFFFF)),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF8B5CF6),
                            Color(0xFFA855F7),
                            Color(0xFF22D3EE),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.eyebrow.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textDim,
        ),
      ),
    );
  }
}

// ── Downloading row (violet-tinted card with progress bar + pause) ──────────

class _DownloadingRow extends StatelessWidget {
  const _DownloadingRow({required this.item, required this.onPause});

  final MockDownload item;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final pct = ((item.progress ?? 0) * 100).round();
    final metaParts = <String>[
      if (item.episodes != null) item.episodes!,
      item.size,
      if (item.speed != null) item.speed!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0FA855F7),
        border: Border.all(color: AppColors.pillBgPurple),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Poster(gradient: item.gradient, width: 56, height: 80, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  metaParts.join(' · '),
                  style: AppTypography.captionV2.copyWith(
                    fontSize: 11,
                    color: AppColors.textMutedV2,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: Color(0x14FFFFFF)),
                        ),
                        FractionallySizedBox(
                          widthFactor: (item.progress ?? 0).clamp(0.0, 1.0),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF8B5CF6),
                                  Color(0xFFA855F7),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pct%',
                  style: AppTypography.captionV2.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.violet,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CircleIconButton(
            icon: Icons.pause_rounded,
            iconSize: 14,
            background: const Color(0x0FFFFFFF),
            color: AppColors.textBright,
            onTap: onPause,
            tooltip: 'Pause download',
          ),
        ],
      ),
    );
  }
}

// ── Completed row (flat row with divider + more menu) ───────────────────────

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({
    required this.item,
    required this.showDivider,
    required this.onDelete,
  });

  final MockDownload item;
  final bool showDivider;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final metaParts = <String>[
      if (item.episodes != null) item.episodes!,
      item.size,
      if (item.qualityBadge != null) item.qualityBadge!,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: showDivider ? AppColors.borderSubtle : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Poster(gradient: item.gradient, width: 50, height: 72, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBright,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  metaParts.join(' · '),
                  style: AppTypography.captionV2.copyWith(
                    fontSize: 11,
                    color: AppColors.textMutedV2,
                  ),
                ),
                const SizedBox(height: 2),
                if (item.expires != null)
                  Text(
                    'Expires ${item.expires}',
                    style: AppTypography.captionV2.copyWith(
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CircleIconButton(
            icon: Icons.more_horiz_rounded,
            iconSize: 15,
            background: const Color(0x0AFFFFFF),
            border: AppColors.borderSubtle,
            color: AppColors.textMutedV2,
            onTap: () => _showActions(context),
            tooltip: 'More actions',
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context) {
    showFluxBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => FluxBottomSheet(
        title: item.title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetAction(
              icon: Icons.play_arrow_rounded,
              label: 'Play offline',
              onTap: () => Navigator.of(sheetCtx).pop(),
            ),
            _SheetAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete download',
              destructive: true,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.statusError : AppColors.textBright;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTypography.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _Poster extends StatelessWidget {
  const _Poster({
    required this.gradient,
    required this.width,
    required this.height,
    required this.radius,
  });

  final Gradient gradient;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.iconSize,
    required this.background,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.border,
  });

  final IconData icon;
  final double iconSize;
  final Color background;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: border != null ? Border.all(color: border!) : null,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.cloud_download_outlined,
          size: 40,
          color: AppColors.textDim,
        ),
        const SizedBox(height: 12),
        Text(
          'No downloads yet',
          style: AppTypography.h2.copyWith(color: AppColors.textBright),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap Download on any title to keep it offline.',
          textAlign: TextAlign.center,
          style:
              AppTypography.captionV2.copyWith(color: AppColors.textMutedV2),
        ),
      ],
    );
  }
}
