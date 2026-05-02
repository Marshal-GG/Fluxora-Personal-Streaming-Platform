/// Pill — compact inline badge with colour variants and an optional icon.
///
/// Matches `Pill` in
/// `docs/11_design/desktop_prototype/app/components/primitives.jsx` lines 28–40.
///
/// Usage:
/// ```dart
/// const Pill('Pro', color: PillColor.purple)
/// Pill('Streaming', color: PillColor.success, icon: Icons.play_arrow)
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';

/// Colour variant for [Pill].
///
/// Each value maps to a [AppColors.pillBg*] background and [AppColors.pillFg*]
/// foreground pair harvested from the prototype palette.
enum PillColor {
  neutral,
  purple,
  success,
  warning,
  error,
  info,
  pink,
}

/// Compact, fully-rounded badge used for statuses, tags, and tiers.
///
/// Text is capped at one line and never wraps. An optional leading [icon]
/// (12 px) may be supplied.
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.color = PillColor.neutral,
    this.icon,
  });

  /// Display text. Always single-line.
  final String text;

  /// Colour variant. Defaults to [PillColor.neutral].
  final PillColor color;

  /// Optional leading icon, rendered at 12 px.
  final IconData? icon;

  /// Returns the (background, foreground) colour pair for [variant].
  static (Color bg, Color fg) _paletteFor(PillColor variant) {
    switch (variant) {
      case PillColor.neutral:
        return (AppColors.pillBgNeutral, AppColors.pillFgNeutral);
      case PillColor.purple:
        return (AppColors.pillBgPurple, AppColors.pillFgPurple);
      case PillColor.success:
        return (AppColors.pillBgSuccess, AppColors.pillFgSuccess);
      case PillColor.warning:
        return (AppColors.pillBgWarning, AppColors.pillFgWarning);
      case PillColor.error:
        return (AppColors.pillBgError, AppColors.pillFgError);
      case PillColor.info:
        return (AppColors.pillBgInfo, AppColors.pillFgInfo);
      case PillColor.pink:
        return (AppColors.pillBgPink, AppColors.pillFgPink);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = _paletteFor(color);

    // Prototype text style: Inter / 11 px / w600 — not a named token but
    // matches the numbers from AppTypography.eyebrow minus the letter-spacing
    // and uppercase transform, so we build it inline.
    const TextStyle textStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: textStyle.copyWith(color: fg),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }
}
