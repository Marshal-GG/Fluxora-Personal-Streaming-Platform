/// EncoderStatusPanel + ActiveEncoderStrip + EncoderRecommendationBanner.
///
/// Slice A of the GPU UX plan ([docs/10_planning/10_gpu_ux_plan.md]) —
/// surfaces the data the server already returns from
/// `/api/v1/transcoding/status` + `/api/v1/transcoding/advisor` so the
/// operator can tell which encoders work, which failed self-test, and
/// which the advisor recommends — without picking blind from a dropdown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/encoder_advice.dart';
import 'package:fluxora_core/entities/transcoding_status.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_cubit.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_state.dart';

/// Status the UI uses to render a pill next to each encoder name.
enum EncoderStatus {
  /// Advisor's `recommendedEncoder`.  Sorts to the top of the list.
  recommended,

  /// Tested-passing or untested-but-detected.  Selectable as-is.
  available,

  /// Self-test failed.  Selectable but greyed; tooltip shows the error.
  failed,

  /// Not in `available_encoders` — either FFmpeg build doesn't include it
  /// or the OS doesn't support it.  Hidden by default.
  notDetected,
}

class EncoderStatusInfo {
  const EncoderStatusInfo({
    required this.id,
    required this.label,
    required this.status,
    this.errorMessage,
    this.testedAt,
    this.suggestion,
  });

  final String id;
  final String label;
  final EncoderStatus status;
  final String? errorMessage;
  final String? testedAt;

  /// Plain-language fix the server worked out from the failure
  /// signature — e.g. "Update Intel Graphics driver" rather than
  /// "MFX session: -9".  Shown in the failed-encoder modal in place
  /// of the raw error when present.
  final String? suggestion;
}

/// Active-encoder strip — one-line summary at the top of the Streaming tab.
///
/// Reads from [TranscodingCubit] and renders "Active: NVIDIA GeForce …
/// (NVENC, h264_nvenc) · 2 of N streams · CPU 14%".
class ActiveEncoderStrip extends StatelessWidget {
  const ActiveEncoderStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscodingCubit, TranscodingState>(
      builder: (context, state) {
        if (state is! TranscodingLoaded) {
          return const SizedBox.shrink();
        }
        final status = state.status;
        final activeLoad = status.encoderLoads.firstWhere(
          (e) => e.encoder == status.activeEncoder,
          orElse: () => EncoderLoad(
            encoder: status.activeEncoder,
            activeSessions: 0,
          ),
        );
        final engine = activeLoad.gpuEngine;
        final isCpu = engine == null;
        final sessions = activeLoad.activeSessions;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s14,
            vertical: AppSpacing.s10,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgRaised,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(
                isCpu ? Icons.memory_outlined : Icons.developer_board_outlined,
                size: 16,
                color: isCpu
                    ? AppColors.pillFgInfo
                    : AppColors.pillFgPurple,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  _summary(status.activeEncoder, engine, sessions),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBright,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FluxChip(
                isCpu ? 'CPU' : 'GPU',
                color: isCpu ? FluxChipColor.info : FluxChipColor.purple,
              ),
            ],
          ),
        );
      },
    );
  }

  String _summary(String encoder, String? engine, int sessions) {
    final engineLabel = switch (engine) {
      'cuda' => 'NVENC (cuda)',
      'qsv' => 'Quick Sync (qsv)',
      'vaapi' => 'VAAPI',
      'videotoolbox' => 'VideoToolbox',
      _ => 'Software',
    };
    final sessionsLabel = sessions == 0
        ? 'idle'
        : '$sessions stream${sessions == 1 ? '' : 's'} active';
    return 'Active: $encoder · $engineLabel · $sessionsLabel';
  }
}

/// Recommendation banner — info / warning surface keyed off
/// [EncoderAdvice.severity].  Returns `SizedBox.shrink()` when the advisor
/// returns `reasonCode == 'none'` so it disappears completely when there's
/// nothing to suggest.
class EncoderRecommendationBanner extends StatelessWidget {
  const EncoderRecommendationBanner({
    super.key,
    this.onApplyRecommendation,
  });

  /// Invoked with the recommended encoder ID when the operator clicks
  /// "Switch to `<encoder>`".  Null disables the action button (banner is
  /// purely informational in that case).
  final ValueChanged<String>? onApplyRecommendation;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscodingCubit, TranscodingState>(
      builder: (context, state) {
        if (state is! TranscodingLoaded || state.advice == null) {
          return const SizedBox.shrink();
        }
        final advice = state.advice!;
        if (advice.reasonCode == 'none') return const SizedBox.shrink();

        final isWarning = advice.severity == 'warning';
        final fg = isWarning
            ? AppColors.pillFgWarning
            : AppColors.pillFgInfo;
        final bg = (isWarning ? AppColors.pillBgWarning : AppColors.pillBgInfo)
            .withValues(alpha: 0.5);
        final border = (isWarning
                ? AppColors.pillFgWarning
                : AppColors.pillFgInfo)
            .withValues(alpha: 0.4);

        return Container(
          padding: const EdgeInsets.all(AppSpacing.s14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isWarning
                    ? Icons.warning_amber_rounded
                    : Icons.lightbulb_outline,
                size: 18,
                color: fg,
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  advice.reasonText,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBright,
                  ),
                ),
              ),
              if (advice.recommendedEncoder != null &&
                  onApplyRecommendation != null) ...[
                const SizedBox(width: AppSpacing.s10),
                _BannerActionButton(
                  label: 'Switch to ${advice.recommendedEncoder}',
                  onPressed: () =>
                      onApplyRecommendation!(advice.recommendedEncoder!),
                  foreground: fg,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BannerActionButton extends StatelessWidget {
  const _BannerActionButton({
    required this.label,
    required this.onPressed,
    required this.foreground,
  });

  final String label;
  final VoidCallback onPressed;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Status panel — one row per known encoder with a status pill, last-test
/// timestamp, and (on failure) a tooltip carrying the FFmpeg stderr.
///
/// Renders only the encoders the platform supports by default; a "Show all"
/// toggle reveals the rest (e.g. NVENC on a macOS host).
class EncoderStatusPanel extends StatefulWidget {
  const EncoderStatusPanel({
    super.key,
    required this.knownEncoders,
    required this.activeEncoder,
  });

  /// All encoder IDs the desktop knows about — typically the static
  /// `_kEncoders` list from `settings_screen.dart`.  Each entry is
  /// `(id, label)`.
  final List<({String id, String label})> knownEncoders;

  /// The encoder currently selected in the dropdown — gets the
  /// "Active" affordance regardless of test state.
  final String activeEncoder;

  @override
  State<EncoderStatusPanel> createState() => _EncoderStatusPanelState();
}

class _EncoderStatusPanelState extends State<EncoderStatusPanel> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscodingCubit, TranscodingState>(
      builder: (context, state) {
        final loaded = state is TranscodingLoaded ? state : null;
        final available = loaded?.status.availableEncoders ?? const <String>[];
        final loadByEncoder = <String, EncoderLoad>{
          for (final l in loaded?.status.encoderLoads ?? const <EncoderLoad>[])
            l.encoder: l,
        };
        final recommended = loaded?.advice?.recommendedEncoder;

        final infos = widget.knownEncoders.map((e) {
          final load = loadByEncoder[e.id];
          final EncoderStatus status;
          if (e.id == recommended) {
            status = EncoderStatus.recommended;
          } else if (!available.contains(e.id)) {
            status = EncoderStatus.notDetected;
          } else if (load?.encoderTestPassed == false) {
            status = EncoderStatus.failed;
          } else {
            status = EncoderStatus.available;
          }
          return EncoderStatusInfo(
            id: e.id,
            label: e.label,
            status: status,
            errorMessage: load?.encoderTestError,
            testedAt: load?.encoderTestedAt,
            suggestion: load?.encoderTestSuggestion,
          );
        }).toList();

        // Sort: recommended first, then available, then failed, then not-
        // detected at the bottom.  Within the same bucket, preserve the
        // input order so the operator's mental model stays stable.
        infos.sort((a, b) {
          int rank(EncoderStatus s) => switch (s) {
                EncoderStatus.recommended => 0,
                EncoderStatus.available => 1,
                EncoderStatus.failed => 2,
                EncoderStatus.notDetected => 3,
              };
          return rank(a.status).compareTo(rank(b.status));
        });

        final visible = _showAll
            ? infos
            : infos.where((e) => e.status != EncoderStatus.notDetected).toList();

        final hiddenCount = infos.length - visible.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(
              testedAt: _mostRecentTestedAt(loaded?.status.encoderLoads),
            ),
            const SizedBox(height: AppSpacing.s8),
            ...visible.map(
              (info) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _EncoderRow(
                  info: info,
                  isActive: info.id == widget.activeEncoder,
                ),
              ),
            ),
            if (hiddenCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMutedV2,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    _showAll
                        ? 'Hide unsupported encoders'
                        : 'Show $hiddenCount unsupported encoder${hiddenCount == 1 ? '' : 's'}',
                    style: AppTypography.captionV2,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String? _mostRecentTestedAt(List<EncoderLoad>? loads) {
    if (loads == null || loads.isEmpty) return null;
    final stamps = loads
        .map((l) => l.encoderTestedAt)
        .whereType<String>()
        .toList()
      ..sort();
    return stamps.isEmpty ? null : stamps.last;
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({this.testedAt});
  final String? testedAt;

  @override
  Widget build(BuildContext context) {
    final stamp = testedAt;
    String? label;
    if (stamp != null) {
      final dt = DateTime.tryParse(stamp);
      if (dt != null) {
        final local = dt.toLocal();
        final h = local.hour.toString().padLeft(2, '0');
        final m = local.minute.toString().padLeft(2, '0');
        label = 'tested $h:$m';
      }
    }
    return Row(
      children: [
        Text(
          'Encoder availability',
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: AppSpacing.s8),
          Text(
            '· $label',
            style: AppTypography.captionV2.copyWith(
              color: AppColors.textDim,
            ),
          ),
        ],
      ],
    );
  }
}

class _EncoderRow extends StatelessWidget {
  const _EncoderRow({required this.info, required this.isActive});
  final EncoderStatusInfo info;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isFaded = info.status == EncoderStatus.notDetected ||
        info.status == EncoderStatus.failed;
    final row = Row(
      children: [
        Expanded(
          child: Text(
            info.label,
            style: AppTypography.bodySmall.copyWith(
              color: isFaded
                  ? AppColors.textDim
                  : AppColors.textBright,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (isActive) ...[
          const FluxChip('Active', color: FluxChipColor.neutral),
          const SizedBox(width: 6),
        ],
        _statusChip(info.status),
      ],
    );

    // Prefer the server's plain-language suggestion when present — it
    // turns FFmpeg's `MFX session: -9` into "Update Intel Graphics
    // driver to enable Quick Sync".  Fall back to the raw stderr line
    // for unrecognised failures so the operator at least sees the
    // diagnostic.
    final tooltip = info.status == EncoderStatus.failed
        ? (info.suggestion ??
            (info.errorMessage != null
                ? 'Self-test failed: ${info.errorMessage}'
                : null))
        : info.status == EncoderStatus.notDetected
            ? 'Not detected on this build of FFmpeg or OS'
            : null;

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: row);
    }
    return row;
  }

  Widget _statusChip(EncoderStatus s) {
    switch (s) {
      case EncoderStatus.recommended:
        return const FluxChip(
          'Recommended',
          color: FluxChipColor.purple,
          icon: Icons.auto_awesome,
        );
      case EncoderStatus.available:
        return const FluxChip('Available', color: FluxChipColor.success);
      case EncoderStatus.failed:
        return const FluxChip(
          'Failed',
          color: FluxChipColor.error,
          icon: Icons.error_outline,
        );
      case EncoderStatus.notDetected:
        return const FluxChip(
          'Not detected',
          color: FluxChipColor.neutral,
        );
    }
  }
}
