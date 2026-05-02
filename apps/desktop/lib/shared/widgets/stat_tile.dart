/// StatTile — compact metric card primitive.
///
/// Pixel-matches `StatTile` in
/// `docs/11_design/desktop_prototype/app/components/primitives.jsx` lines 72–90.
///
/// Wraps a [FluxCard] and renders a coloured icon badge beside a label /
/// value / optional sub-text column.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';

/// A compact stat display card with an icon, label, value, and optional note.
///
/// Example:
/// ```dart
/// StatTile(
///   icon: Icons.folder_outlined,
///   label: 'Libraries',
///   value: '4',
///   sub: '+1 this week',
///   color: AppColors.violet,
/// )
/// ```
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.color = AppColors.violet,
    this.iconBg,
    this.accent,
  });

  /// Icon rendered inside the coloured badge.
  final IconData icon;

  /// Short descriptor shown above the value (e.g. "Libraries").
  final String label;

  /// Primary metric value (e.g. "4" or "18%").
  final String value;

  /// Optional sub-text rendered below the value in [accent] colour.
  final String? sub;

  /// Tint applied to the icon and (when [iconBg] is null) the badge background.
  /// Defaults to [AppColors.violet].
  final Color color;

  /// Explicit badge background. When null, derived as `color` at 12 % opacity.
  final Color? iconBg;

  /// Colour for the [sub] text. Defaults to [AppColors.statusActive] (emerald).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color badgeBg = iconBg ?? color.withValues(alpha: 0.12);
    final Color subColor = accent ?? AppColors.statusActive;

    return FluxCard(
      padding: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge — 44×44, rounded md.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Center(
              child: Icon(icon, size: 20, color: color),
            ),
          ),
          const SizedBox(width: 14),
          // Text column — expands to fill remaining space, clipping if needed.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label — allowed to wrap to 2 lines so that compact
                // 4-up layouts (esp. when a detail panel is open and per-
                // tile width drops to ~140 px) don't truncate "Total
                // Libraries", "Connected Clients", etc.
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMutedV2,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Value
                Text(
                  value,
                  style: AppTypography.displayV2.copyWith(
                    color: AppColors.textBright,
                    height: 1.1,
                    letterSpacing: -0.24,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Sub-text (optional)
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      sub!,
                      style: AppTypography.captionV2.copyWith(
                        color: subColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
