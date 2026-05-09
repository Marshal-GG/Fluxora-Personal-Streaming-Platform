import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';

import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_job.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_cubit.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';

/// History tab — every terminal job (done / failed / cancelled).  Failed
/// rows expose a Retry button which re-enqueues the job preserving the
/// original error in the row above.
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscodeCubit, TranscodeState>(
      builder: (context, state) {
        if (state is! TranscodeLoaded) return const SizedBox.shrink();
        // Most-recent first — `finished_at` is set on every terminal row,
        // falling back to `created_at` for the rare row without one.
        final jobs = state.terminalJobs.toList()
          ..sort((a, b) {
            final ta = a.finishedAt ?? a.createdAt;
            final tb = b.finishedAt ?? b.createdAt;
            return tb.compareTo(ta);
          });
        if (jobs.isEmpty) return const _EmptyHistory();
        return FluxCard(
          padding: 0,
          child: Column(
            children: [
              for (var i = 0; i < jobs.length; i++)
                _HistoryRow(
                  job: jobs[i],
                  isFirst: i == 0,
                  busy: state.busyJobIds.contains(jobs[i].id),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.job,
    required this.isFirst,
    required this.busy,
  });

  final TranscodeJob job;
  final bool isFirst;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TranscodeCubit>();
    return Container(
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : const Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s18,
        vertical: AppSpacing.s14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.fileName,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitleFor(job),
                  style: AppTypography.monoCaption.copyWith(
                    color: AppColors.textDim,
                  ),
                ),
                if (job.status == TranscodeJobStatus.failed &&
                    job.error != null) ...[
                  const SizedBox(height: AppSpacing.s6),
                  Text(
                    job.error!,
                    style: AppTypography.monoCaption.copyWith(
                      color: AppColors.pillFgError,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          _statusChip(job.status),
          if (job.status == TranscodeJobStatus.failed) ...[
            const SizedBox(width: AppSpacing.s8),
            FluxButton(
              variant: FluxButtonVariant.outline,
              size: FluxButtonSize.sm,
              icon: Icons.refresh_rounded,
              onPressed: busy ? null : () => cubit.retryJob(job.id),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  static FluxChip _statusChip(TranscodeJobStatus status) {
    switch (status) {
      case TranscodeJobStatus.done:
        return const FluxChip('done', color: FluxChipColor.success);
      case TranscodeJobStatus.failed:
        return const FluxChip('failed', color: FluxChipColor.error);
      case TranscodeJobStatus.cancelled:
        return const FluxChip('cancelled', color: FluxChipColor.neutral);
      case TranscodeJobStatus.running:
        return const FluxChip('running', color: FluxChipColor.purple);
      case TranscodeJobStatus.queued:
        return const FluxChip('queued', color: FluxChipColor.info);
    }
  }

  String _subtitleFor(TranscodeJob job) {
    final parts = <String>[job.encoder];
    if (job.finishedAt != null) {
      parts.add(_relativeTime(job.finishedAt!));
    }
    return parts.join(' · ');
  }

  /// Render an epoch-second timestamp as a coarse "Xm ago" / "Xh ago"
  /// string.  Coarse-grained on purpose — the History tab cares about
  /// "is this fresh or old?" not the exact second.
  String _relativeTime(int epochSec) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final diff = now - epochSec;
    if (diff < 60) return 'just now';
    if (diff < 3600) return '${diff ~/ 60}m ago';
    if (diff < 86400) return '${diff ~/ 3600}h ago';
    return '${diff ~/ 86400}d ago';
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s28,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.history_rounded,
              color: AppColors.textMutedV2,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.s10),
            Text(
              'No history yet',
              style: AppTypography.body.copyWith(
                color: AppColors.textBright,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Completed, failed, and cancelled jobs will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMutedV2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
