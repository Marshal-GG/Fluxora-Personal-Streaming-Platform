/// Sparkline — a single-stroke open polyline chart rendered with [CustomPaint].
///
/// Pixel-matches the `Sparkline` SVG component defined in the dashboard
/// prototype at:
///   docs/11_design/desktop_prototype/app/screens/dashboard.jsx  (lines 185–196)
///
/// The prototype formula for every point's y-coordinate is:
///   `h - ((v - min) / r) * (h - 4) - 2`
/// where `h` = canvas height, `r` = max − min (or 1 when flat), giving 2 px
/// padding at both the top and the bottom of the drawing area.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';

// ── Public widget ──────────────────────────────────────────────────────────────

/// A minimal, single-line sparkline that pixel-matches the prototype SVG.
///
/// The widget expands to the full available width (matching `width: 100%` in
/// the prototype) and fixes its height to [height].  Pass at least two data
/// points; fewer than two renders an empty box of the correct height.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.data,
    this.color = AppColors.violet,
    this.height = 36,
    this.strokeWidth = 1.5,
    super.key,
  });

  /// The data series.  Values may be any finite [double]; the painter
  /// normalises them internally.
  final List<double> data;

  /// Stroke colour (prototype default: `#A855F7` — [AppColors.violet]).
  final Color color;

  /// Fixed height of the drawing area in logical pixels (prototype: 36).
  final double height;

  /// Stroke width in logical pixels (prototype: 1.5).
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return SizedBox(height: height);
    }

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, height),
          painter: _SparklinePainter(
            data: data,
            color: color,
            strokeWidth: strokeWidth,
          ),
        );
      },
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
  });

  final List<double> data;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Compute min / max; guard against flat series (prototype: `r = max-min || 1`).
    double min = data.first;
    double max = data.first;
    for (final double v in data) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final double r = (max - min == 0.0) ? 1.0 : (max - min);

    // Horizontal spacing between consecutive points.
    final double step = w / (data.length - 1);

    // Build the path using the exact prototype formula.
    // Prototype: `${i*step},${h - ((v-min)/r)*(h-4)-2}`
    final Path path = Path();
    for (int i = 0; i < data.length; i++) {
      final double x = i * step;
      final double y = h - ((data[i] - min) / r) * (h - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (oldDelegate.strokeWidth != strokeWidth) return true;
    if (oldDelegate.data.length != data.length) return true;
    // Fast identity check first — avoids element-wise scan when the same list
    // instance is passed unchanged (common in const widget trees).
    if (identical(oldDelegate.data, data)) return false;
    for (int i = 0; i < data.length; i++) {
      if (oldDelegate.data[i] != data[i]) return true;
    }
    return false;
  }
}
