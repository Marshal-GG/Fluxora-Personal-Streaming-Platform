/// SectionLabel — uppercase eyebrow label primitive.
///
/// Matches `SectionLabel` in
/// `docs/11_design/desktop_prototype/app/components/primitives.jsx` lines 15–20.
///
/// Usage:
/// ```dart
/// const SectionLabel('SYSTEM STATUS')
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';

/// Uppercase, letter-spaced section eyebrow.
///
/// Renders [text] with [AppTypography.eyebrow] (11 px / 600 / 0.14 em
/// uppercase) and adds [AppSpacing.s14] of bottom margin, matching the
/// prototype's `marginBottom: 14`.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  /// The label text. Rendered uppercase automatically by [AppTypography.eyebrow].
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s14),
      child: Text(
        text,
        style: AppTypography.eyebrow,
      ),
    );
  }
}
