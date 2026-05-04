/// EncoderPriorityList — drag-and-drop reorderable chain editor.
///
/// Slice C of the GPU UX plan.  The operator picks a priority chain like
/// `[h264_nvenc, h264_qsv, libx264]`; on every transcode session start
/// the server's `session_router` walks the chain and uses the first
/// encoder whose live-session count is below its
/// `concurrent_session_cap` (NVENC = 3 on consumer cards).
///
/// The widget is "controlled" — it doesn't own state; the parent passes
/// the current chain and an `onChanged` callback fires on every reorder /
/// add / remove.  Save happens at the parent level via `SettingsCubit`.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';

class EncoderPriorityList extends StatelessWidget {
  const EncoderPriorityList({
    super.key,
    required this.chain,
    required this.allEncoders,
    required this.onChanged,
  });

  /// Current chain — list of encoder IDs in priority order.  Top of the
  /// list is tried first.
  final List<String> chain;

  /// Every encoder the desktop knows about: `(id, label)`.  Drives the
  /// "+ Add encoder" picker; encoders already in the chain are excluded.
  final List<({String id, String label})> allEncoders;

  /// Fires with the new chain on every reorder / add / remove.
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final available = allEncoders
        .where((e) => !chain.contains(e.id))
        .toList();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(chainLength: chain.length),
          const SizedBox(height: AppSpacing.s10),
          if (chain.isEmpty)
            const _EmptyState()
          else
            _ReorderableChain(
              chain: chain,
              allEncoders: allEncoders,
              onChanged: onChanged,
            ),
          const SizedBox(height: AppSpacing.s10),
          _AddEncoderRow(
            available: available,
            onAdd: (id) => onChanged([...chain, id]),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.chainLength});
  final int chainLength;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.layers_outlined,
          size: 16,
          color: AppColors.textMutedV2,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Encoder priority chain',
                style: AppTypography.captionV2.copyWith(
                  color: AppColors.textMutedV2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                chainLength == 0
                    ? 'Using the default chain (configured encoder, then libx264).'
                    : 'Drag to reorder. The first encoder whose session cap '
                        'isn\'t hit gets the next stream.',
                style: AppTypography.captionV2.copyWith(
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'No encoders configured. Add one below to start customising the '
        'fallback chain.',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textDim),
      ),
    );
  }
}

class _ReorderableChain extends StatelessWidget {
  const _ReorderableChain({
    required this.chain,
    required this.allEncoders,
    required this.onChanged,
  });

  final List<String> chain;
  final List<({String id, String label})> allEncoders;
  final ValueChanged<List<String>> onChanged;

  String _labelFor(String id) {
    for (final e in allEncoders) {
      if (e.id == id) return e.label;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: chain.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final next = [...chain];
        final moved = next.removeAt(oldIndex);
        next.insert(newIndex, moved);
        onChanged(next);
      },
      itemBuilder: (context, index) {
        final id = chain[index];
        return _ChainRow(
          key: ValueKey(id),
          index: index,
          id: id,
          label: _labelFor(id),
          isPrimary: index == 0,
          onRemove: () {
            final next = [...chain]..removeAt(index);
            onChanged(next);
          },
        );
      },
    );
  }
}

class _ChainRow extends StatelessWidget {
  const _ChainRow({
    super.key,
    required this.index,
    required this.id,
    required this.label,
    required this.isPrimary,
    required this.onRemove,
  });

  final int index;
  final String id;
  final String label;
  final bool isPrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgRoot.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: isPrimary
                ? AppColors.pillFgPurple.withValues(alpha: 0.4)
                : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: AppColors.textMutedV2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isPrimary
                    ? AppColors.pillBgPurple
                    : AppColors.pillBgNeutral,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                '${index + 1}',
                style: AppTypography.captionV2.copyWith(
                  color: isPrimary
                      ? AppColors.pillFgPurple
                      : AppColors.pillFgNeutral,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textBright,
                      fontWeight: isPrimary
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    id,
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.textDim,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            if (isPrimary)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: FluxChip(
                  'Primary',
                  color: FluxChipColor.purple,
                ),
              ),
            IconButton(
              tooltip: 'Remove from chain',
              icon: const Icon(Icons.close_rounded, size: 16),
              color: AppColors.textMutedV2,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEncoderRow extends StatelessWidget {
  const _AddEncoderRow({required this.available, required this.onAdd});

  final List<({String id, String label})> available;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    if (available.isEmpty) {
      return Text(
        'All encoders are already in the chain.',
        style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        tooltip: 'Add encoder to chain',
        onSelected: onAdd,
        position: PopupMenuPosition.under,
        color: AppColors.bgRaised,
        itemBuilder: (context) => [
          for (final e in available)
            PopupMenuItem<String>(
              value: e.id,
              child: Text(
                e.label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textBright,
                ),
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.pillBgPurple.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: AppColors.pillFgPurple),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 14,
                color: AppColors.pillFgPurple,
              ),
              const SizedBox(width: 4),
              Text(
                'Add encoder',
                style: AppTypography.captionV2.copyWith(
                  color: AppColors.pillFgPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
