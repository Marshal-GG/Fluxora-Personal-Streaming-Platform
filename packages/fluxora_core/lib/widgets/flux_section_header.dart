/// FluxSectionHeader — uppercase eyebrow + bold heading pair.
///
/// Mobile prototype `M.SectionHeader` (mobile-primitives.jsx) — used at the
/// top of every list / rail to label the section. Eyebrow: 11 / 600 / dim,
/// uppercase, 1.4 letter-spacing. Heading: 14 / 700 / bright. Optional
/// trailing widget (e.g. "See all" button) sits on the right of the heading
/// row.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';

class FluxSectionHeader extends StatelessWidget {
  const FluxSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  /// Bold heading (14 / 700). Required.
  final String title;

  /// Optional uppercase eyebrow rendered above the heading.
  final String? eyebrow;

  /// Optional trailing widget — typically a `TextButton` ("See all"),
  /// chip, or icon. Aligned to the end of the heading row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              eyebrow!.toUpperCase(),
              style: AppTypography.eyebrow,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.h2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBright,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}
