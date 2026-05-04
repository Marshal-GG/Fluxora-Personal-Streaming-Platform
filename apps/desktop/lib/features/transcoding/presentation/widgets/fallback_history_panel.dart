/// FallbackHistoryPanel — diagnostic surface for the
/// `services/session_router.py` ring buffer.  Shows the last few encoder
/// routing decisions so the operator can answer "why did N+1 fall back
/// to libx264?" without reading the server log.
///
/// Slice C of the GPU UX plan.  Sits at the bottom of the Transcoding
/// screen; collapses to nothing when there's no history (which is the
/// happy path).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/fallback_event.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/fallback_history_cubit.dart';

class FallbackHistoryPanel extends StatelessWidget {
  const FallbackHistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FallbackHistoryCubit, FallbackHistoryState>(
      builder: (context, state) {
        if (state is FallbackHistoryInitial ||
            state is FallbackHistoryLoading) {
          return const SizedBox.shrink();
        }
        if (state is FallbackHistoryFailure) {
          // Fail silently for the panel — this is a diagnostic surface,
          // not a critical one; the rest of the screen renders fine.
          return const SizedBox.shrink();
        }
        final loaded = state as FallbackHistoryLoaded;
        if (loaded.events.isEmpty) {
          return const SizedBox.shrink();
        }
        // Show only the last 5 — the ring buffer holds 50, but the
        // diagnostic question is usually about *the most recent* event.
        final recent = loaded.events.reversed.take(5).toList();
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
              const _Header(),
              const SizedBox(height: AppSpacing.s10),
              for (final event in recent) ...[
                _EventRow(event: event),
                if (event != recent.last) const SizedBox(height: 6),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.history_rounded,
          size: 16,
          color: AppColors.textMutedV2,
        ),
        const SizedBox(width: 8),
        Text(
          'Recent encoder fallbacks',
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final FallbackEvent event;

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  ({String label, FluxChipColor color}) _reasonChip() {
    switch (event.reason) {
      case 'configured':
        return (label: 'OK', color: FluxChipColor.success);
      case 'gpu_session_cap_hit':
        return (label: 'Cap hit', color: FluxChipColor.warning);
      case 'all_encoders_saturated':
        return (label: 'All saturated', color: FluxChipColor.error);
      case 'encoder_unknown':
        return (label: 'Unknown encoder', color: FluxChipColor.error);
      default:
        return (label: event.reason, color: FluxChipColor.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = _reasonChip();
    final isFallback = event.requestedEncoder != event.actualEncoder;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgRoot.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Text(
            _formatTime(event.timestamp),
            style: AppTypography.captionV2.copyWith(
              color: AppColors.textDim,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textBright,
                ),
                children: [
                  TextSpan(
                    text: event.requestedEncoder,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  if (isFallback) ...[
                    TextSpan(
                      text: '  →  ',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMutedV2,
                      ),
                    ),
                    TextSpan(
                      text: event.actualEncoder,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.pillFgWarning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          FluxChip(chip.label, color: chip.color),
        ],
      ),
    );
  }
}
