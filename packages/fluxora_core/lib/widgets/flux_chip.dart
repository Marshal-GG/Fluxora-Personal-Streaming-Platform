/// FluxChip — compact inline badge with colour variants and an optional icon.
///
/// Was `Pill` on desktop (matches `Pill` in
/// `docs/11_design/prototype/app/desktop/components/primitives.jsx` lines
/// 28–40). Renamed during the M1 lift so the mobile redesign can adopt the
/// same widget without a desktop-only name.
///
/// Usage:
/// ```dart
/// const FluxChip('Pro', color: FluxChipColor.purple)
/// FluxChip('Streaming', color: FluxChipColor.success, icon: Icons.play_arrow)
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';

/// Colour variant for [FluxChip].
///
/// Each value maps to a [AppColors.pillBg*] background and [AppColors.pillFg*]
/// foreground pair harvested from the prototype palette.
enum FluxChipColor {
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
class FluxChip extends StatelessWidget {
  const FluxChip(
    this.text, {
    super.key,
    this.color = FluxChipColor.neutral,
    this.icon,
  });

  final String text;
  final FluxChipColor color;
  final IconData? icon;

  static (Color bg, Color fg) _paletteFor(FluxChipColor variant) {
    switch (variant) {
      case FluxChipColor.neutral:
        return (AppColors.pillBgNeutral, AppColors.pillFgNeutral);
      case FluxChipColor.purple:
        return (AppColors.pillBgPurple, AppColors.pillFgPurple);
      case FluxChipColor.success:
        return (AppColors.pillBgSuccess, AppColors.pillFgSuccess);
      case FluxChipColor.warning:
        return (AppColors.pillBgWarning, AppColors.pillFgWarning);
      case FluxChipColor.error:
        return (AppColors.pillBgError, AppColors.pillFgError);
      case FluxChipColor.info:
        return (AppColors.pillBgInfo, AppColors.pillFgInfo);
      case FluxChipColor.pink:
        return (AppColors.pillBgPink, AppColors.pillFgPink);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = _paletteFor(color);

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
