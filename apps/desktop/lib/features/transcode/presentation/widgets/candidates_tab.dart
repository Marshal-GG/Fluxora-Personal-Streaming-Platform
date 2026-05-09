import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';

import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_candidate.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_cubit.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_state.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/folder_tree.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/queue_dialog.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';

/// Encoder runtime multipliers used to estimate wall-clock duration.
///
/// Numbers come straight from the spec — h264_nvenc encodes at ~5× source
/// duration (i.e. 1 minute of source ≈ 12 s of wall-clock); libx264 slow
/// runs at 0.8× source (1 min ≈ 1m15s).  The encoder choice itself is
/// server-owned, so the desktop has no way to know which one will win
/// per-job; we surface both numbers as a range when the spread matters.
const double _nvencRealtime = 5.0;
const double _libx264Realtime = 0.8;

/// Candidates tab — folder-grouped tree of files needing pre-transcode
/// (plan 19 §M4 replaces the flat list), with an aggregate-disk +
/// aggregate-runtime estimator footer and the `Start transcode` CTA
/// that opens the Queue dialog (§M1 + §M5).
class CandidatesTab extends StatelessWidget {
  const CandidatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscodeCubit, TranscodeState>(
      builder: (context, state) {
        if (state is TranscodeFailure) {
          return _FailureBox(message: state.message);
        }
        if (state is! TranscodeLoaded) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.s28),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (state.candidates.isEmpty) {
          return const _EmptyBox(
            title: 'No candidates',
            body:
                'Every AV1 / VP9 file in the library already has a transcoded sidecar, '
                "or you haven't scanned a library that contains those codecs yet.",
          );
        }
        return _CandidatesView(state: state);
      },
    );
  }
}

class _CandidatesView extends StatelessWidget {
  const _CandidatesView({required this.state});

  final TranscodeLoaded state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TranscodeCubit>();
    final selectedCount = state.selectedFileIds.length;
    final allSelected = selectedCount == state.candidates.length &&
        selectedCount > 0;

    final root = buildFolderTree<TranscodeCandidate>(
      leaves: state.candidates,
      pathOf: (c) => c.path.isEmpty ? c.name : c.path,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header row: count + select-all toggle ──────────────────────
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
                '${state.candidates.length} candidate'
                '${state.candidates.length == 1 ? '' : 's'}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMutedV2,
                ),
              ),
              const Spacer(),
              FluxButton(
                variant: FluxButtonVariant.ghost,
                size: FluxButtonSize.sm,
                onPressed: state.candidates.isEmpty
                    ? null
                    : (allSelected ? cubit.clearSelection : cubit.selectAll),
                child: Text(allSelected ? 'Clear' : 'Select all'),
              ),
            ],
          ),
        ),

        // ── Folder-grouped tree ────────────────────────────────────────
        FluxCard(
          padding: 0,
          child: FolderTreeView<TranscodeCandidate>(
            root: root,
            expandedPaths: state.expandedPaths,
            onToggleExpanded: cubit.toggleExpanded,
            idOf: (c) => c.fileId,
            sizeOf: (c) => c.sizeBytes,
            selectedIds: state.selectedFileIds,
            onFolderToggle: cubit.selectFolder,
            leafBuilder: (ctx, c) => _CandidateRow(
              candidate: c,
              selected: state.selectedFileIds.contains(c.fileId),
              onToggle: () => cubit.toggleSelection(c.fileId),
            ),
          ),
        ),

        // ── Aggregate footer ───────────────────────────────────────────
        const SizedBox(height: AppSpacing.s18),
        _EstimateFooter(state: state),
      ],
    );
  }
}

// ── Single row ───────────────────────────────────────────────────────────────

class _CandidateRow extends StatefulWidget {
  const _CandidateRow({
    required this.candidate,
    required this.selected,
    required this.onToggle,
  });

  final TranscodeCandidate candidate;
  final bool selected;
  final VoidCallback onToggle;

  @override
  State<_CandidateRow> createState() => _CandidateRowState();
}

class _CandidateRowState extends State<_CandidateRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: _hover ? const Color(0x08FFFFFF) : Colors.transparent,
            border: const Border(
              top: BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s18,
            vertical: AppSpacing.s10,
          ),
          child: Row(
            children: [
              _Checkbox(checked: widget.selected),
              const SizedBox(width: AppSpacing.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.candidate.name,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textBright,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatBytes(widget.candidate.sizeBytes),
                      style: AppTypography.monoCaption.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              FluxChip(
                widget.candidate.videoCodec.toUpperCase(),
                color: widget.candidate.videoCodec == 'av1'
                    ? FluxChipColor.warning
                    : FluxChipColor.info,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Self-painted checkbox — the prototype's checkbox primitive isn't
/// shared, so we draw it inline rather than introduce a new shared widget.
class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color:
            checked ? AppColors.violet : const Color(0x08FFFFFF),
        border: Border.all(
          color:
              checked ? AppColors.violet : AppColors.borderHover,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }
}

// ── Estimate footer ──────────────────────────────────────────────────────────

class _EstimateFooter extends StatelessWidget {
  const _EstimateFooter({required this.state});

  final TranscodeLoaded state;

  @override
  Widget build(BuildContext context) {
    final selected = state.candidates
        .where((c) => state.selectedFileIds.contains(c.fileId))
        .toList(growable: false);

    final int totalSourceBytes =
        selected.fold<int>(0, (sum, c) => sum + c.sizeBytes);
    final int totalOutputBytes =
        selected.fold<int>(0, (sum, c) => sum + c.estOutputSizeBytes);
    final double totalDurationSec = selected.fold<double>(
      0,
      (sum, c) => sum + (c.durationSec ?? 0),
    );

    return FluxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Selected: ${selected.length}',
                style: AppTypography.body.copyWith(
                  color: AppColors.textBright,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              FluxButton(
                variant: FluxButtonVariant.primary,
                icon: Icons.play_arrow_rounded,
                onPressed: (selected.isEmpty || state.busyAction)
                    ? null
                    : () => _launchQueueDialog(context),
                child: Text(
                  state.busyAction ? 'Queueing…' : 'Start transcode',
                ),
              ),
            ],
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            _StatRow(
              label: 'Source size',
              value: _formatBytes(totalSourceBytes),
              estimate: false,
            ),
            const SizedBox(height: 4),
            _StatRow(
              label: 'Estimated output',
              value: '${_formatBytes(totalOutputBytes)} H.264',
              estimate: true,
            ),
            const SizedBox(height: 4),
            _StatRow(
              label: 'Estimated runtime',
              value: _formatRuntimeRange(totalDurationSec),
              estimate: true,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _launchQueueDialog(BuildContext context) async {
    final cubit = context.read<TranscodeCubit>();
    final confirmed = await showQueueDialog(context);
    if (confirmed == true) {
      await cubit.startTranscode();
    }
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.estimate,
  });

  final String label;
  final String value;
  final bool estimate;

  @override
  Widget build(BuildContext context) {
    final TextStyle valueStyle = AppTypography.bodySmall.copyWith(
      color: AppColors.textBody,
      // Italic + the leading "≈" make the estimate-y rows visually
      // distinct from the deterministic "Source size" row above.
      fontStyle: estimate ? FontStyle.italic : FontStyle.normal,
    );
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
          estimate ? '≈ $value' : value,
          style: valueStyle,
        ),
      ],
    );
  }
}

// ── Empty / failure boxes ────────────────────────────────────────────────────

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.title, required this.body});

  final String title;
  final String body;

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
              Icons.check_circle_outline_rounded,
              color: AppColors.emerald,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.s10),
            Text(
              title,
              style: AppTypography.body.copyWith(
                color: AppColors.textBright,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              body,
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

class _FailureBox extends StatelessWidget {
  const _FailureBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s24,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.red,
              size: 28,
            ),
            const SizedBox(height: AppSpacing.s10),
            Text(
              'Failed to load candidates',
              style: AppTypography.body.copyWith(
                color: AppColors.textBright,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMutedV2,
              ),
            ),
            const SizedBox(height: AppSpacing.s14),
            FluxButton(
              variant: FluxButtonVariant.outline,
              size: FluxButtonSize.sm,
              icon: Icons.refresh_rounded,
              onPressed: () => context
                  .read<TranscodeCubit>()
                  .loadCandidates(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Format bytes with three significant figures, switching between units.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1024;
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  // 1 decimal once we get to MB and above; readable for "780 MB" / "3.2 GB".
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

/// Render the runtime estimate as a tight range covering the NVENC and
/// libx264 endpoints.  The desktop never knows which encoder the server
/// will pick per-job, so we surface both — the "~50 min" wording in the
/// spec corresponds to the NVENC path alone.
String _formatRuntimeRange(double durationSec) {
  if (durationSec <= 0) return 'unknown';
  final fast = durationSec / _nvencRealtime;
  final slow = durationSec / _libx264Realtime;
  final fastFmt = _formatDuration(fast);
  final slowFmt = _formatDuration(slow);
  if (fastFmt == slowFmt) return fastFmt;
  return '$fastFmt – $slowFmt runtime';
}

String _formatDuration(double seconds) {
  if (seconds < 60) return '${seconds.toStringAsFixed(0)} s';
  final mins = seconds / 60;
  if (mins < 60) return '${mins.toStringAsFixed(0)} min';
  final hours = mins / 60;
  if (hours < 10) return '${hours.toStringAsFixed(1)} h';
  return '${hours.toStringAsFixed(0)} h';
}
