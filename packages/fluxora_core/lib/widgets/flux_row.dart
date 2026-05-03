/// FluxRow — settings / list row primitive.
///
/// Mobile prototype `M.Row`. 36×36 violet-tinted icon square on the left,
/// label + optional sub-label stack in the middle, optional trailing widget
/// on the right (chevron, switch, value text). 56-px tap target.
///
/// Used heavily on the Profile screen, Server picker, Host-server screen,
/// notification settings, etc.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_typography.dart';

class FluxRow extends StatelessWidget {
  const FluxRow({
    super.key,
    required this.label,
    this.icon,
    this.iconWidget,
    this.sub,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  /// Primary label (14 / 600).
  final String label;

  /// Optional icon — rendered inside a 36x36 violet-tinted square.
  /// Mutually exclusive with [iconWidget].
  final IconData? icon;

  /// Custom leading widget (replaces the default icon square). Useful for
  /// avatars or custom 36x36 art.
  final Widget? iconWidget;

  /// Optional sub-label rendered under the primary label (12 / 500 / dim).
  final String? sub;

  /// Trailing widget — chevron, value text, switch, etc.
  final Widget? trailing;

  /// Optional tap handler. When `null` the row is non-interactive but the
  /// chrome still renders (used for read-only info rows).
  final VoidCallback? onTap;

  /// Render with red foregrounds (used for "Sign out", "Delete account",
  /// "Stop server" etc.).
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color labelColor =
        destructive ? AppColors.red : AppColors.textBright;
    final Color iconBg = destructive
        ? const Color(0x1AEF4444) // rgba(239,68,68,0.1)
        : AppColors.pillBgPurple;
    final Color iconFg = destructive ? AppColors.red : AppColors.violet;

    final Widget leading = iconWidget ??
        (icon != null
            ? Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(icon, size: 18, color: iconFg),
              )
            : const SizedBox.shrink());

    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          leading,
          if (icon != null || iconWidget != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.textMutedV2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) {
      return body;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.pillBgPurple,
        highlightColor: const Color(0x0AFFFFFF),
        child: body,
      ),
    );
  }
}
