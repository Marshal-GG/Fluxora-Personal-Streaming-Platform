import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/widgets/flux_button.dart';

import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_candidate.dart';
import 'package:fluxora_desktop/features/transcode/domain/repositories/transcode_repository.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_cubit.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_dialog.dart';

/// Queue confirmation dialog — plan 19 §M1 + §M5.  Three-row preset
/// chooser, live "Estimated total" derived from the same multipliers
/// the server uses, plus a "Stored at" cache-root readout pulled from
/// the cubit's storage slice (populated by the §M3 5-second poll).
///
/// Returns true when the operator clicked `[Queue]` (the cubit then
/// fires `startTranscode()`); returns false / null on cancel.
Future<bool?> showQueueDialog(BuildContext context) {
  // Capture cubit & current state before opening — the dialog runs in
  // its own Navigator subtree, but the BlocProvider is above the
  // Navigator so providing it explicitly to the child via BlocProvider.value
  // keeps the live updates flowing.
  final cubit = context.read<TranscodeCubit>();
  return showDialog<bool>(
    context: context,
    builder: (dialogCtx) => BlocProvider<TranscodeCubit>.value(
      value: cubit,
      child: const _QueueDialog(),
    ),
  );
}

class _QueueDialog extends StatelessWidget {
  const _QueueDialog();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscodeCubit, TranscodeState>(
      builder: (context, state) {
        if (state is! TranscodeLoaded) {
          return FluxGlassDialog(
            title: const Text('Queue files'),
            content: const SizedBox.shrink(),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Close'),
              ),
            ],
          );
        }
        return _DialogBody(state: state);
      },
    );
  }
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({required this.state});

  final TranscodeLoaded state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TranscodeCubit>();
    final selected = state.candidates
        .where((c) => state.selectedFileIds.contains(c.fileId))
        .toList(growable: false);
    final preset = state.queuePreset;

    final estTotalBytes = _estimatedTotal(selected, preset);
    final freeBytes = state.storage?.freeBytesAtCacheRoot;
    final cacheRoot = state.storage?.cacheRoot;

    return FluxGlassDialog(
      maxWidth: 560,
      title:
          Text('Queue ${selected.length} file${selected.length == 1 ? '' : 's'} for transcoding'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quality preset',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textMutedV2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.s10),

            // Three radio rows.  Use the same self-painted radio dot as
            // _StreamingModeOption — Material Radio's groupValue API was
            // deprecated post-Flutter 3.32.
            for (final p in TranscodePreset.values)
              _PresetRow(
                preset: p,
                selected: preset == p,
                onTap: () => cubit.setQueuePreset(p),
              ),

            const SizedBox(height: AppSpacing.s14),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: AppSpacing.s14),

            _SummaryRow(
              label: 'Estimated total output',
              value: '~${_formatBytes(estTotalBytes)}',
              accent: false,
            ),
            if (freeBytes != null) ...[
              const SizedBox(height: AppSpacing.s4),
              _SummaryRow(
                label: 'Free on cache disk',
                value: _formatBytes(freeBytes),
                // Render the free-disk row in red when the estimate
                // exceeds the disk's free space — operator catches the
                // out-of-space case before queueing.
                accent: estTotalBytes > freeBytes,
              ),
            ],
            if (cacheRoot != null && cacheRoot.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x08FFFFFF),
                  border: Border.all(color: const Color(0x0DFFFFFF)),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 14,
                      color: AppColors.violet,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Tooltip(
                        message: cacheRoot,
                        child: Text(
                          'Stored at: $cacheRoot',
                          style: AppTypography.monoCaption.copyWith(
                            color: AppColors.textBody,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FluxButton(
          variant: FluxButtonVariant.primary,
          icon: Icons.play_arrow_rounded,
          onPressed: selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(true),
          child: const Text('Queue'),
        ),
      ],
    );
  }

  /// Sum of `estimateOutputBytes` for every selected candidate at the
  /// chosen preset.  Mirrors the server's math so the operator sees the
  /// same number the queued jobs will produce.
  int _estimatedTotal(
    List<TranscodeCandidate> selected,
    TranscodePreset preset,
  ) {
    return selected.fold<int>(
      0,
      (sum, c) => sum +
          estimateOutputBytes(
            sourceBytes: c.sizeBytes,
            sourceCodec: c.videoCodec,
            preset: preset,
          ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final TranscodePreset preset;
  final bool selected;
  final VoidCallback onTap;

  static const Map<TranscodePreset, ({String title, String body})> _copy = {
    TranscodePreset.smaller: (
      title: 'Smaller',
      body: '~1.2× source · noticeable on critical viewing',
    ),
    TranscodePreset.recommended: (
      title: 'Recommended',
      body: '~2× source · indistinguishable in normal viewing',
    ),
    TranscodePreset.mastering: (
      title: 'Mastering',
      body: '~4× source · visually lossless',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final copy = _copy[preset]!;
    final isDefault = preset == TranscodePreset.recommended;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Self-painted radio dot — see _StreamingModeOption for the
            // origin of this pattern (Flutter 3.32 deprecated the
            // groupValue Radio API).
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.violet : AppColors.textFaint,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.violet,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        copy.title,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textBright,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          '(default)',
                          style: AppTypography.captionV2.copyWith(
                            color: AppColors.textMutedV2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    copy.body,
                    style: AppTypography.bodySmall.copyWith(
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;

  /// When true the value renders in red — used on the "Free on cache
  /// disk" row when the estimated total exceeds free space.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textMutedV2,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: accent ? AppColors.pillFgError : AppColors.textBright,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Local copy of the shared bytes formatter — kept inline so the
/// dialog widget stays decoupled from individual tabs' helpers.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1024;
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}
