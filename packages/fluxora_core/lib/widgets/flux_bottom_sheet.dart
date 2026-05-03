/// FluxBottomSheet — skeleton sheet used by all 5 player sheets.
///
/// Drag handle (40x4) at the top, optional title row (17/700 + close icon),
/// then a scrollable body. Background `#0F0C24` (one tier above bgRoot)
/// with top corners radius 18. Phantom backdrop `rgba(0,0,0,0.55)` is
/// supplied by [showFluxBottomSheet].
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';

/// Show a [FluxBottomSheet] modal with the prototype's phantom backdrop.
///
/// Returns the value passed to [Navigator.pop] from inside the sheet, or
/// `null` if the user dismissed by tapping the backdrop or dragging.
Future<T?> showFluxBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C000000), // rgba(0,0,0,0.55)
    builder: builder,
  );
}

class FluxBottomSheet extends StatelessWidget {
  const FluxBottomSheet({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.maxHeightFraction = 0.85,
  });

  /// Optional title rendered next to the drag handle.
  final String? title;

  /// Optional trailing widget on the title row (e.g. close button).
  final Widget? trailing;

  /// Sheet body — typically a [Column] or [ListView].
  final Widget child;

  /// Cap on sheet height as a fraction of the screen (default 0.85).
  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    final double maxHeight =
        MediaQuery.of(context).size.height * maxHeightFraction;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0C24),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: AppTypography.h1.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBright,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
