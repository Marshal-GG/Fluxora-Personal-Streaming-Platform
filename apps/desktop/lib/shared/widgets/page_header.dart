/// PageHeader — every screen's title row.
///
/// Pixel-matches the inline `PageHeader` invoked at the top of every
/// `docs/11_design/desktop_prototype/app/screens/*.jsx` — a left-aligned
/// title (with an optional muted subtitle) and an optional right-aligned
/// `actions` widget (typically a row of [FluxButton]s).
///
/// Vertical padding of 24 px top and bottom; **no horizontal padding** —
/// each screen owns its own horizontal padding via the screen wrapper, so
/// the header tracks alignment with the content below.
library;

import 'package:flutter/widgets.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  /// Big title string. Rendered with [AppTypography.h1].
  final String title;

  /// Optional muted subtitle below the title. [AppTypography.bodySmall].
  final String? subtitle;

  /// Optional widget aligned to the right edge — usually a `Row` of
  /// `FluxButton`s. When null, the right side is empty.
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.h1.copyWith(
                    color: AppColors.textBright,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMutedV2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: AppSpacing.s16),
            actions!,
          ],
        ],
      ),
    );
  }
}
