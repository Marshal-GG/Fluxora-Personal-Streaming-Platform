import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';

import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_candidate.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_storage.dart';
import 'package:fluxora_desktop/features/transcode/domain/repositories/transcode_repository.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_cubit.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_state.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/candidates_tab.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/history_tab.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/queue_dialog.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/queue_tab.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/storage_strip.dart'
    show openPathInFileManager;
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

/// Three-tab Transcode page — `Candidates`, `Queue`, `History`.  All
/// three tabs read from the same [TranscodeCubit] so a job that lands
/// in the Queue tab is visible to the History tab on the very next poll
/// without an extra fetch.
///
/// Storage stats and the bulk-convert action live in a fixed right panel
/// (`_TranscodeRightPanel`) so the left-side table can use the full width
/// for its columns.  The bulk-convert block within the right panel only
/// renders when the Candidates tab is active AND something is selected.
class TranscodeScreen extends StatelessWidget {
  const TranscodeScreen({super.key, this.embedded = false});

  /// When `true`, hosted inside a parent shell that already renders a
  /// page header — skip ours.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TranscodeCubit>(
      create: (_) => TranscodeCubit(
        repository: GetIt.I<TranscodeRepository>(),
      )..start(),
      child: _TranscodeView(embedded: embedded),
    );
  }
}

class _TranscodeView extends StatefulWidget {
  const _TranscodeView({required this.embedded});

  final bool embedded;

  @override
  State<_TranscodeView> createState() => _TranscodeViewState();
}

class _TranscodeViewState extends State<_TranscodeView> {
  static const String _tabCandidates = 'candidates';
  static const String _tabQueue = 'queue';
  static const String _tabHistory = 'history';

  String _activeTab = _tabCandidates;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgRoot,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s28,
                AppSpacing.s20,
                AppSpacing.s28,
                AppSpacing.s28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.embedded)
                    const PageHeader(
                      title: 'Transcode',
                      subtitle:
                          'Pre-convert AV1 / VP9 sources to H.264 sidecars so playback stream-copies',
                    ),
                  BlocBuilder<TranscodeCubit, TranscodeState>(
                    buildWhen: (a, b) => _countsChanged(a, b),
                    builder: (context, state) {
                      return FluxTabBar(
                        tabs: _buildTabs(state),
                        activeId: _activeTab,
                        onChange: (id) => setState(() => _activeTab = id),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s18),
                  switch (_activeTab) {
                    _tabCandidates => const CandidatesTab(),
                    _tabQueue => const QueueTab(),
                    _tabHistory => const HistoryTab(),
                    _ => const SizedBox.shrink(),
                  },
                ],
              ),
            ),
          ),
          _TranscodeRightPanel(activeTab: _activeTab),
        ],
      ),
    );
  }

  List<FluxTab> _buildTabs(TranscodeState state) {
    int candidatesCount = 0;
    int queueCount = 0;
    int historyCount = 0;
    if (state is TranscodeLoaded) {
      candidatesCount = state.candidates.length;
      queueCount = state.activeJobs.length;
      historyCount = state.terminalJobs.length;
    }
    return [
      FluxTab(
        id: _tabCandidates,
        label: 'Candidates'
            '${candidatesCount == 0 ? '' : ' ($candidatesCount)'}',
        icon: Icons.fast_forward_rounded,
      ),
      FluxTab(
        id: _tabQueue,
        label: 'Queue${queueCount == 0 ? '' : ' ($queueCount)'}',
        icon: Icons.hourglass_top_rounded,
      ),
      FluxTab(
        id: _tabHistory,
        label: 'History${historyCount == 0 ? '' : ' ($historyCount)'}',
        icon: Icons.history_rounded,
      ),
    ];
  }

  /// Rebuild the tab bar only when one of the three counts changes —
  /// avoids spinning the FluxTabBar 30× a minute on /jobs polls that
  /// only mutate progress percentages.
  bool _countsChanged(TranscodeState a, TranscodeState b) {
    if (a is! TranscodeLoaded || b is! TranscodeLoaded) return true;
    return a.candidates.length != b.candidates.length ||
        a.activeJobs.length != b.activeJobs.length ||
        a.terminalJobs.length != b.terminalJobs.length;
  }
}

// ── Right panel ──────────────────────────────────────────────────────────────

/// Fixed 300 px sidebar on the right of the Transcode page.
///
/// Layout (2026-05-16 owner review):
///   1. Selection Details — header + count + size arrow + delta
///   2. Details — source / output / runtime rows
///   3. Storage — Transcoded · Cache · Free disk · Sources by codec
///   4. Quick Actions — Start Transcode · Add to Queue · Clear Selection
///   5. Transcoding Settings (navigates to /transcoding/encoder)
///
/// Sections 1, 2, and 4 only render when the Candidates tab is active AND
/// the operator has selected at least one row.  Sections 3 and 5 are
/// always visible.
class _TranscodeRightPanel extends StatelessWidget {
  const _TranscodeRightPanel({required this.activeTab});

  final String activeTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0x0DFFFFFF)),
        ),
        color: Color(0x800D0B1C),
      ),
      child: BlocBuilder<TranscodeCubit, TranscodeState>(
        builder: (context, state) {
          if (state is! TranscodeLoaded) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.s20),
              child: Text(
                'Loading…',
                style: TextStyle(color: AppColors.textDim),
              ),
            );
          }
          final selected = state.candidates
              .where((c) => state.selectedFileIds.contains(c.fileId))
              .toList(growable: false);
          final showSelection =
              activeTab == _TranscodeViewState._tabCandidates &&
                  selected.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSelection) ...[
                  _SelectionDetailsSection(selected: selected),
                  const SizedBox(height: AppSpacing.s20),
                  _DetailsSection(selected: selected),
                  const SizedBox(height: AppSpacing.s20),
                  const _PanelDivider(),
                  const SizedBox(height: AppSpacing.s20),
                ],
                _StorageSection(storage: state.storage),
                const SizedBox(height: AppSpacing.s20),
                const _PanelDivider(),
                const SizedBox(height: AppSpacing.s20),
                _ActionsSection(state: state, showSelection: showSelection),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(color: Color(0x14FFFFFF), height: 1, thickness: 1);
}

// ── Selection Details + Details sections ─────────────────────────────────────

class _SelectionDetailsSection extends StatelessWidget {
  const _SelectionDetailsSection({required this.selected});

  final List<TranscodeCandidate> selected;

  @override
  Widget build(BuildContext context) {
    final int totalSource =
        selected.fold<int>(0, (sum, c) => sum + c.sizeBytes);
    final int totalOutput =
        selected.fold<int>(0, (sum, c) => sum + c.estOutputSizeBytes);
    final int delta = totalOutput - totalSource;
    final double deltaPct =
        totalSource > 0 ? (delta / totalSource) * 100 : 0;

    // For Fluxora's AV1/VP9 → H.264 pipeline the output is always *bigger*
    // than the source — so the delta line surfaces a disk *cost* in amber.
    // The "Saving …" branch is kept for future codecs where the target is
    // smaller (e.g. HEVC source → H.264 sidecar would shrink).
    final bool isSaving = delta < 0;
    final Color deltaColor = isSaving
        ? AppColors.emerald
        : (delta > 0 ? AppColors.amber : AppColors.textBody);
    final String deltaText = isSaving
        ? 'Saving ${_formatBytes(-delta)} (${(-deltaPct).toStringAsFixed(0)}%)'
        : (delta > 0
            ? 'Adds ${_formatBytes(delta)} (+${deltaPct.toStringAsFixed(0)}%)'
            : 'No size change');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(child: _SectionTitle('Selection Details')),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textDim,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s10),
        Text(
          '${selected.length} file${selected.length == 1 ? '' : 's'} selected',
          style: AppTypography.body.copyWith(
            color: AppColors.textBright,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatBytes(totalSource)} → ${_formatBytes(totalOutput)} (est.)',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textBody),
        ),
        const SizedBox(height: 4),
        Text(
          deltaText,
          style: AppTypography.bodySmall.copyWith(
            color: deltaColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.selected});

  final List<TranscodeCandidate> selected;

  @override
  Widget build(BuildContext context) {
    final int totalSource =
        selected.fold<int>(0, (sum, c) => sum + c.sizeBytes);
    final int totalOutput =
        selected.fold<int>(0, (sum, c) => sum + c.estOutputSizeBytes);
    final double totalDurationSec = selected.fold<double>(
      0,
      (sum, c) => sum + (c.durationSec ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Details'),
        const SizedBox(height: AppSpacing.s10),
        _DetailsRow(label: 'Source size', value: _formatBytes(totalSource)),
        const SizedBox(height: 6),
        _DetailsRow(
          label: 'Output size (est.)',
          value: _formatBytes(totalOutput),
        ),
        const SizedBox(height: 6),
        _DetailsRow(
          label: 'Runtime (est.)',
          value: _formatRuntimeRange(totalDurationSec),
        ),
      ],
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({required this.label, required this.value});

  final String label;
  final String value;

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
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textBright,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

// ── Actions section ──────────────────────────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.state,
    required this.showSelection,
  });

  final TranscodeLoaded state;

  /// `true` when at least one candidate is selected — gates the
  /// selection-scoped actions (Start Transcode, Add to Queue, Clear).
  final bool showSelection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Actions'),
        const SizedBox(height: AppSpacing.s14),
        if (showSelection) ...[
          _ActionCard(
            icon: Icons.play_arrow_rounded,
            title: state.busyAction ? 'Queueing…' : 'Start Transcode',
            subtitle: 'Queue with preset chooser',
            onTap: state.busyAction ? null : () => _startTranscode(context),
          ),
          const SizedBox(height: AppSpacing.s8),
          _ActionCard(
            icon: Icons.playlist_add_rounded,
            title: 'Add to Queue',
            subtitle: 'Queue immediately with current preset',
            onTap: state.busyAction ? null : () => _addToQueue(context),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        _ActionCard(
          icon: Icons.settings_outlined,
          title: 'Transcoding Settings',
          subtitle: 'Configure encoders and presets',
          onTap: () => context.go(Routes.encoderSettings),
        ),
        if (showSelection) ...[
          const SizedBox(height: AppSpacing.s8),
          _ActionCard(
            icon: Icons.delete_outline_rounded,
            title: 'Clear Selection',
            subtitle: 'Deselect all candidates',
            destructive: true,
            onTap: state.busyAction
                ? null
                : () => context.read<TranscodeCubit>().clearSelection(),
          ),
        ],
      ],
    );
  }

  /// Opens the preset-picker dialog and queues on confirm.
  Future<void> _startTranscode(BuildContext context) async {
    final cubit = context.read<TranscodeCubit>();
    final confirmed = await showQueueDialog(context);
    if (confirmed == true) {
      await cubit.startTranscode();
    }
  }

  /// Queues immediately with the current preset, skipping the dialog.
  /// Same underlying `repository.queueJobs(...)` call as Start Transcode —
  /// the server's single-worker FIFO picks it up regardless.
  Future<void> _addToQueue(BuildContext context) async {
    await context.read<TranscodeCubit>().startTranscode();
  }
}

/// Tappable card matching the right-panel actions on the Folders tab.
/// Icon + (title + muted subtitle) + chevron, with a destructive variant
/// that flips icon / title / border to red.  Disabled state when [onTap]
/// is null — dims the contents and disables the hover affordance.
class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final Color borderColor;
    final Color iconColor;
    final Color titleColor;
    final Color chevronColor;

    if (widget.destructive) {
      borderColor = enabled
          ? (_hover
              ? AppColors.red.withValues(alpha: 0.6)
              : AppColors.red.withValues(alpha: 0.35))
          : AppColors.red.withValues(alpha: 0.2);
      iconColor = enabled
          ? AppColors.red
          : AppColors.red.withValues(alpha: 0.5);
      titleColor = iconColor;
      chevronColor = AppColors.red.withValues(alpha: enabled ? 0.7 : 0.4);
    } else {
      borderColor = !enabled
          ? AppColors.borderSubtle
          : (_hover ? AppColors.borderHover : AppColors.borderSubtle);
      iconColor =
          enabled ? AppColors.violetSoft : AppColors.textDim;
      titleColor = enabled ? AppColors.textBright : AppColors.textDim;
      chevronColor = enabled
          ? (_hover ? AppColors.textBody : AppColors.textDim)
          : AppColors.textDim;
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s14,
            vertical: AppSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: enabled && _hover
                ? (widget.destructive
                    ? AppColors.red.withValues(alpha: 0.06)
                    : const Color(0x08FFFFFF))
                : Colors.transparent,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: iconColor),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.body.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textDim,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: chevronColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Storage section ──────────────────────────────────────────────────────────

class _StorageSection extends StatelessWidget {
  const _StorageSection({required this.storage});

  final TranscodeStorage? storage;

  @override
  Widget build(BuildContext context) {
    final s = storage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Storage'),
        const SizedBox(height: AppSpacing.s14),
        _StatField(
          label: 'Transcoded',
          value: s == null
              ? '—'
              : '${_formatBytes(s.transcodedSizeBytes)} · '
                  '${s.transcodedFileCount} file'
                  '${s.transcodedFileCount == 1 ? '' : 's'}',
        ),
        const SizedBox(height: AppSpacing.s14),
        _CachePathField(path: s?.cacheRoot ?? ''),
        const SizedBox(height: AppSpacing.s14),
        _StatField(
          label: 'Free on disk',
          value: s == null ? '—' : _formatBytes(s.freeBytesAtCacheRoot),
        ),
        const SizedBox(height: AppSpacing.s14),
        _CodecBreakdown(
          breakdown: s?.byCodec ?? const {},
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    // Body-weight bold, matching the per-library detail panel's
    // "Statistics" / "Actions" headers (right-side info column on the
    // Folders tab).  Slightly bolder than `eyebrow` so the section
    // breaks read clearly without dividers.
    return Text(
      text,
      style: AppTypography.body.copyWith(
        color: AppColors.textBright,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _StatField extends StatelessWidget {
  const _StatField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.body.copyWith(
            color: AppColors.textBright,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CachePathField extends StatefulWidget {
  const _CachePathField({required this.path});
  final String path;

  @override
  State<_CachePathField> createState() => _CachePathFieldState();
}

class _CachePathFieldState extends State<_CachePathField> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.path.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cache',
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
          ),
        ),
        const SizedBox(height: 6),
        MouseRegion(
          cursor: disabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onEnter: disabled ? null : (_) => setState(() => _hover = true),
          onExit: disabled ? null : (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: disabled
                ? null
                : () => openPathInFileManager(widget.path),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s10,
              ),
              decoration: BoxDecoration(
                color: _hover ? const Color(0x08FFFFFF) : Colors.transparent,
                border: Border.all(
                  color: _hover
                      ? AppColors.borderHover
                      : AppColors.borderSubtle,
                ),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    size: 16,
                    color: AppColors.violetSoft,
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Tooltip(
                      message: widget.path,
                      child: Text(
                        widget.path.isEmpty ? '—' : widget.path,
                        style: AppTypography.monoCaption.copyWith(
                          color: AppColors.textBright,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (!disabled) ...[
                    const SizedBox(width: AppSpacing.s6),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color:
                          _hover ? AppColors.textBody : AppColors.textDim,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CodecBreakdown extends StatelessWidget {
  const _CodecBreakdown({required this.breakdown});

  final Map<String, TranscodeStorageCodecBreakdown> breakdown;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sources by codec',
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
          ),
        ),
        const SizedBox(height: 6),
        if (breakdown.isEmpty)
          Text(
            'none',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textDim,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.s6,
            runSpacing: AppSpacing.s6,
            children: [
              for (final entry in breakdown.values)
                FluxChip(
                  '${entry.codec.toUpperCase()} · ${entry.count}',
                  color: _chipColorFor(entry.codec),
                ),
            ],
          ),
      ],
    );
  }

  FluxChipColor _chipColorFor(String codec) => switch (codec) {
        'av1' => FluxChipColor.warning,
        'vp9' => FluxChipColor.info,
        _ => FluxChipColor.neutral,
      };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

// Encoder runtime multipliers used to estimate wall-clock duration.
const double _nvencRealtime = 5.0;
const double _libx264Realtime = 0.8;

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
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

String _formatRuntimeRange(double durationSec) {
  if (durationSec <= 0) return 'unknown';
  final fast = durationSec / _nvencRealtime;
  final slow = durationSec / _libx264Realtime;
  final fastFmt = _formatDuration(fast);
  final slowFmt = _formatDuration(slow);
  if (fastFmt == slowFmt) return fastFmt;
  return '$fastFmt – $slowFmt';
}

String _formatDuration(double seconds) {
  if (seconds < 60) return '${seconds.toStringAsFixed(0)} s';
  final mins = seconds / 60;
  if (mins < 60) return '${mins.toStringAsFixed(0)} min';
  final hours = mins / 60;
  if (hours < 10) return '${hours.toStringAsFixed(1)} h';
  return '${hours.toStringAsFixed(0)} h';
}

