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
import 'package:fluxora_desktop/features/transcode/presentation/widgets/folder_tree.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/storage_strip.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_menu.dart';

/// History tab — every terminal job (done / failed / cancelled), grouped
/// into a folder tree by source path (plan 19 §M4).  Each row shows the
/// actual `Source → Sidecar` size column (no leading `~` since this is
/// the real `output_size_bytes`), a Stored at menu, and a Retry button
/// for failed rows.
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

        final root = buildFolderTree<TranscodeJob>(
          leaves: jobs,
          // Fallback to file_name when src_path is absent (older server).
          pathOf: (j) => j.srcPath.isEmpty ? j.fileName : j.srcPath,
        );

        return FluxCard(
          padding: 0,
          child: FolderTreeView<TranscodeJob>(
            root: root,
            expandedPaths: state.expandedPaths,
            onToggleExpanded: context.read<TranscodeCubit>().toggleExpanded,
            idOf: (j) => j.id.toString(),
            // History rows surface output bytes — the operator's "did
            // this actually shrink things?" view.  Falls back to source
            // bytes when the job didn't complete.
            sizeOf: (j) => j.outputSizeBytes ?? j.srcSizeBytes ?? 0,
            // No selection on the History tab — read-only review.
            showCheckbox: false,
            leafBuilder: (ctx, j) => _HistoryRow(
              job: j,
              busy: state.busyJobIds.contains(j.id),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.job,
    required this.busy,
  });

  final TranscodeJob job;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TranscodeCubit>();
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle),
        ),
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
                if (_sizeColumnText(job).isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    _sizeColumnText(job),
                    style: AppTypography.monoCaption.copyWith(
                      color: AppColors.textMutedV2,
                    ),
                  ),
                ],
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
          const SizedBox(width: AppSpacing.s8),
          _StoredAtMenu(outputPath: job.outputPath),
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

/// "Source → Sidecar" — uses the actual `output_size_bytes` (no `~`)
/// for done jobs; falls back to source-only when output is unknown
/// (failed / cancelled rows that didn't produce a sidecar).
String _sizeColumnText(TranscodeJob job) {
  if (job.srcSizeBytes == null) return '';
  final src = _formatBytes(job.srcSizeBytes!);
  if (job.outputSizeBytes != null) {
    return '$src → ${_formatBytes(job.outputSizeBytes!)}';
  }
  return src;
}

/// Stored-at menu — same widget logic as the Queue tab's, kept inline
/// here to avoid a cross-tab shared widget that pulls both Queue and
/// History into the same compilation unit.  Disabled when `output_path`
/// is null (typical for failed/cancelled rows).
class _StoredAtMenu extends StatelessWidget {
  const _StoredAtMenu({required this.outputPath});

  final String? outputPath;

  @override
  Widget build(BuildContext context) {
    final enabled = outputPath != null && outputPath!.isNotEmpty;
    if (!enabled) {
      return Tooltip(
        message: 'No sidecar on disk',
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: const Icon(
            Icons.folder_outlined,
            size: 16,
            color: AppColors.textFaint,
          ),
        ),
      );
    }
    return FluxGlassMenu<String>(
      width: 200,
      items: const [
        FluxGlassMenuItem(
          value: 'copy',
          label: 'Copy path',
          icon: Icons.copy_rounded,
        ),
        FluxGlassMenuItem(
          value: 'open',
          label: 'Open folder',
          icon: Icons.open_in_new_rounded,
        ),
      ],
      onSelected: (v) {
        final messenger = ScaffoldMessenger.of(context);
        if (v == 'copy') {
          copyPathToClipboard(outputPath!, messenger: messenger);
        } else if (v == 'open') {
          final dir = _parentDir(outputPath!);
          openPathInFileManager(dir, messenger: messenger);
        }
      },
      child: Tooltip(
        message: outputPath!,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: const Icon(
            Icons.folder_open_rounded,
            size: 16,
            color: AppColors.textBody,
          ),
        ),
      ),
    );
  }
}

String _parentDir(String path) {
  final norm = path.replaceAll('\\', '/');
  final idx = norm.lastIndexOf('/');
  if (idx <= 0) return path;
  return path.contains('\\')
      ? path.substring(0, path.lastIndexOf('\\'))
      : norm.substring(0, idx);
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
