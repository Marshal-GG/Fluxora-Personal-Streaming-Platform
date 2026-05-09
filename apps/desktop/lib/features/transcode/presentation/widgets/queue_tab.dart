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
import 'package:fluxora_desktop/shared/widgets/flux_progress.dart';

/// Queue tab — running + queued jobs, each with a live progress bar and
/// a per-row Cancel button, plus a "Cancel selected" bulk action that
/// kills every active job currently shown.
class QueueTab extends StatelessWidget {
  const QueueTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscodeCubit, TranscodeState>(
      builder: (context, state) {
        if (state is! TranscodeLoaded) {
          return const SizedBox.shrink();
        }
        final jobs = state.activeJobs.toList(growable: false);
        if (jobs.isEmpty) {
          return const _EmptyQueue();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header row + bulk-cancel ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s8,
                AppSpacing.s4,
                AppSpacing.s14,
              ),
              child: Row(
                children: [
                  Text(
                    '${jobs.length} active job'
                    '${jobs.length == 1 ? '' : 's'}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMutedV2,
                    ),
                  ),
                  const Spacer(),
                  FluxButton(
                    variant: FluxButtonVariant.danger,
                    size: FluxButtonSize.sm,
                    icon: Icons.stop_rounded,
                    onPressed: () => context
                        .read<TranscodeCubit>()
                        .cancelJobs(jobs.map((j) => j.id)),
                    child: const Text('Cancel all'),
                  ),
                ],
              ),
            ),
            FluxCard(
              padding: 0,
              child: Column(
                children: [
                  for (var i = 0; i < jobs.length; i++)
                    _JobRow(
                      job: jobs[i],
                      isFirst: i == 0,
                      busy: state.busyJobIds.contains(jobs[i].id),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({
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
    final running = job.status == TranscodeJobStatus.running;
    final progress = (job.progressPct / 100).clamp(0.0, 1.0);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              FluxChip(
                running ? 'running' : 'queued',
                color: running ? FluxChipColor.purple : FluxChipColor.info,
              ),
              const SizedBox(width: AppSpacing.s8),
              FluxButton(
                variant: FluxButtonVariant.danger,
                size: FluxButtonSize.sm,
                icon: Icons.stop_rounded,
                onPressed: busy ? null : () => cubit.cancelJob(job.id),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          Row(
            children: [
              Expanded(
                child: FluxProgress(
                  value: progress,
                  color: running ? AppColors.violet : AppColors.textFaint,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              SizedBox(
                width: 44,
                child: Text(
                  running ? '${job.progressPct.toStringAsFixed(0)}%' : '—',
                  textAlign: TextAlign.right,
                  style: AppTypography.monoCaption.copyWith(
                    color: AppColors.textMutedV2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitleFor(TranscodeJob job) {
    final parts = <String>[job.encoder];
    if (job.status == TranscodeJobStatus.running && job.etaSec != null) {
      parts.add('ETA ${_formatEta(job.etaSec!)}');
    }
    return parts.join(' · ');
  }

  String _formatEta(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final remSec = seconds % 60;
    if (mins < 60) {
      return remSec == 0 ? '${mins}m' : '${mins}m${remSec.toString().padLeft(2, '0')}s';
    }
    final hours = mins ~/ 60;
    final remMin = mins % 60;
    return '${hours}h${remMin.toString().padLeft(2, '0')}m';
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

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
              Icons.hourglass_empty_rounded,
              color: AppColors.textMutedV2,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.s10),
            Text(
              'No active jobs',
              style: AppTypography.body.copyWith(
                color: AppColors.textBright,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Pick a few candidates and hit Start transcode to queue some up.',
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
