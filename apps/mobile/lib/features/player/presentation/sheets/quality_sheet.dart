/// Streaming quality bottom sheet — STUB DISABLED in v1.
///
/// Server emits a single HLS playlist per stream today (see
/// `mobile_redesign_plan.md` §6.1). Multi-quality switching needs either
/// an HLS master playlist (preferred — `media_kit` switches automatically)
/// or a `GET /api/v1/stream/{id}/qualities` endpoint and a restart-on-pick
/// flow. Until then, this sheet shows the design + a disabled banner so
/// the menu is visible but no rows are tappable.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';

class QualitySheet extends StatelessWidget {
  const QualitySheet({super.key});

  static const List<String> _options = [
    'Auto (recommended)',
    '4K',
    '1080p',
    '720p',
    '480p',
  ];

  @override
  Widget build(BuildContext context) {
    return FluxBottomSheet(
      title: 'Streaming quality',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pillBgWarning,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Manual quality switching coming soon. Auto-adapts for now.',
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.pillFgWarning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _options.length; i++)
            Opacity(
              opacity: i == 0 ? 0.85 : 0.4,
              child: ListTile(
                dense: false,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  i == 0 ? Icons.check_circle : Icons.circle_outlined,
                  color: i == 0 ? AppColors.violet : AppColors.textDim,
                  size: 20,
                ),
                title: Text(
                  _options[i],
                  style: AppTypography.body.copyWith(
                    color: i == 0 ? AppColors.textBright : AppColors.textBody,
                    fontSize: 14,
                    fontWeight:
                        i == 0 ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                onTap: null,
              ),
            ),
        ],
      ),
    );
  }
}
