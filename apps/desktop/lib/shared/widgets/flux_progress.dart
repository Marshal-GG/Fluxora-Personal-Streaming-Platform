/// FluxProgress — animated determinate progress bar.
///
/// Matches `Progress` in
/// `docs/11_design/desktop_prototype/app/components/primitives.jsx` lines 66–70.
///
/// Usage:
/// ```dart
/// FluxProgress(value: 0.65)
/// FluxProgress(value: 0.4, height: 6, color: AppColors.emerald)
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:fluxora_core/constants/app_gradients.dart';
import 'package:fluxora_core/constants/app_radii.dart';

/// Animated determinate progress bar with a gradient fill.
///
/// - Track: `rgba(255,255,255,0.06)` rounded rect, full width.
/// - Fill: [AppGradients.progress] (`#8B5CF6 → #A855F7`) or a solid [color]
///   when provided.
/// - Fill width animates to [value] × available width over 400 ms with
///   [Curves.easeOut].
/// - Does **not** use [LinearProgressIndicator] from Material.
class FluxProgress extends StatelessWidget {
  const FluxProgress({
    super.key,
    required this.value,
    this.height = 4,
    this.color,
    this.trackColor,
  });

  /// Fill level in the range 0.0–1.0. Clamped automatically.
  final double value;

  /// Height of the bar in logical pixels. Defaults to 4.
  final double height;

  /// When provided, overrides the gradient fill with a solid colour.
  final Color? color;

  /// Track (background) colour. Defaults to `rgba(255,255,255,0.06)`.
  final Color? trackColor;

  // Default track colour from the prototype: `rgba(255,255,255,0.06)`.
  static const Color _defaultTrack = Color(0x0FFFFFFF);

  @override
  Widget build(BuildContext context) {
    final double clamped = value.clamp(0.0, 1.0);
    final Color track = trackColor ?? _defaultTrack;
    final BorderRadius radius = BorderRadius.circular(AppRadii.pill);

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Track — full width background.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: track),
              ),
            ),
            // Fill — fractional width, animated.
            Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: clamped),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (BuildContext ctx, double animatedValue, Widget? _) {
                  return FractionallySizedBox(
                    widthFactor: animatedValue,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        gradient: color == null ? AppGradients.progress : null,
                        borderRadius: radius,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
