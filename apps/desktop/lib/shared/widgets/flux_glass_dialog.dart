import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_typography.dart';

/// Glassmorphic replacement for [AlertDialog].
///
/// Wraps content in `ClipRRect > BackdropFilter(blur 20) > Container(surfaceGlass)`
/// — the same pattern used by [`flux_app_bar.dart`](../../../packages/fluxora_core/lib/widgets/flux_app_bar.dart),
/// `flux_sidebar.dart`, and `flux_bottom_tabs.dart`. Without the
/// [BackdropFilter], a translucent `surfaceGlass` background just lets the
/// page bleed through unblurred which reads as "broken" rather than glass —
/// see [`docs/12_guidelines/03_gotchas.md`](../../../../docs/12_guidelines/03_gotchas.md).
///
/// Use for any modal dialog. Popup menus (PopupMenuButton) cannot consume
/// this widget — their items are rendered as separate Material descendants
/// so a single blur layer cannot span the popup. Popup menus stay opaque
/// `AppColors.bgRaised` per the same gotcha.
class FluxGlassDialog extends StatelessWidget {
  const FluxGlassDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.maxWidth = 480,
    this.blurSigma = 20,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                border: Border.all(color: AppColors.borderSubtle),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: AppTypography.h2
                        .copyWith(color: AppColors.textBright),
                    child: title,
                  ),
                  const SizedBox(height: 14),
                  DefaultTextStyle.merge(
                    style: AppTypography.body
                        .copyWith(color: AppColors.textBody),
                    child: content,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
