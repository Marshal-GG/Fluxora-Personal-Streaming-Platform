/// StorageDonut — a 4-segment donut chart with centre text, rendered with
/// [CustomPaint].
///
/// Pixel-matches the `Donut` SVG component defined in the dashboard prototype
/// at:
///   docs/11_design/desktop_prototype/app/screens/dashboard.jsx  (lines 198–216)
///
/// Geometry taken verbatim from the prototype:
///   • SVG canvas  : 120 × 120
///   • Radius (r)  : 44
///   • Centre (cx,cy): 60, 60
///   • Circumference: 2π × 44 ≈ 276.46
///   • Stroke width: 14
///   • Track stroke: rgba(255,255,255,0.06)  → [Color(0x0FFFFFFF)]
///   • Start angle : −90° (top of circle)
///   • Direction   : clockwise
///   • Stroke cap  : butt (matches SVG default)
///
/// Centre text layout from the prototype:
///   • Primary value: x=cx, y=cy−2,  fontSize=14, fontWeight=700, #F1F5F9
///   • Unit label  : x=cx, y=cy+14, fontSize=10, fontWeight=400, #94A3B8
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';

// ── Public model ───────────────────────────────────────────────────────────────

/// A single coloured segment for [StorageDonut].
///
/// [percent] is in the range 0–100; the widget does not enforce that segments
/// sum to 100 — any remainder simply leaves part of the track ring visible.
class StorageDonutSegment {
  const StorageDonutSegment({required this.percent, required this.color});

  /// Share of the total ring, expressed as a percentage (0–100).
  final double percent;

  /// Segment stroke colour.
  final Color color;
}

// ── Public widget ──────────────────────────────────────────────────────────────

/// A donut chart that pixel-matches the prototype `Donut` SVG component.
///
/// Renders a fixed-size [CustomPaint] canvas — the widget does **not** expand;
/// pass [size] to scale it.
class StorageDonut extends StatelessWidget {
  const StorageDonut({
    required this.segments,
    required this.centerText,
    this.unitText = '',
    this.size = 120,
    this.strokeWidth = 14,
    super.key,
  });

  /// Ordered list of coloured segments drawn clockwise from 12 o'clock.
  final List<StorageDonutSegment> segments;

  /// Primary number displayed at the centre (e.g. `"2.72"`).
  final String centerText;

  /// Unit label below [centerText] (e.g. `"TB"`).  Empty string hides the
  /// label.
  final String unitText;

  /// Logical-pixel diameter of the canvas (prototype: 120).
  final double size;

  /// Ring stroke width in logical pixels (prototype: 14).
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _DonutPainter(
        segments: segments,
        centerText: centerText,
        unitText: unitText,
        size: size,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.segments,
    required this.centerText,
    required this.unitText,
    required this.size,
    required this.strokeWidth,
  });

  final List<StorageDonutSegment> segments;
  final String centerText;
  final String unitText;
  final double size;
  final double strokeWidth;

  // Prototype constants (scaled by size / 120 to support non-default sizes).
  static const double _protoSize = 120.0;
  static const double _protoRadius = 44.0;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final double scale = canvasSize.width / _protoSize;
    final double cx = canvasSize.width / 2;
    final double cy = canvasSize.height / 2;
    final double radius = _protoRadius * scale;
    final double sw = strokeWidth * scale;

    // ── 1. Track ring ──────────────────────────────────────────────────────
    // Prototype: <circle ... stroke="rgba(255,255,255,0.06)" strokeWidth="14"/>
    final Paint trackPaint = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    // ── 2. Coloured segments ───────────────────────────────────────────────
    // The prototype draws each segment as a full circle whose visible arc is
    // controlled by strokeDasharray (`len  c-len`) and strokeDashoffset
    // (`-cumulativeLen`).  The circle is rotated −90° so arcs start at the
    // top.  We reproduce this with canvas.drawArc, which is simpler and
    // exactly equivalent.
    //
    // Prototype accumulation:
    //   off starts at 0
    //   dashOff = -off  (negative offset means the dash starts `off` into the
    //                    dash pattern, i.e. the arc is offset by `off`)
    //   off += len      (advance by this segment's length)

    // drawArc parameters:
    //   startAngle: −π/2 + (cumulativeArcRadians)   [top = −π/2]
    //   sweepAngle: (pct/100) × 2π
    double cumulativeFraction = 0.0;

    for (final StorageDonutSegment seg in segments) {
      final double fraction = seg.percent / 100.0;
      if (fraction <= 0.0) {
        cumulativeFraction += fraction;
        continue;
      }

      final double startAngle = -math.pi / 2 + (cumulativeFraction * 2 * math.pi);
      final double sweepAngle = fraction * 2 * math.pi;

      final Paint segPaint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweepAngle,
        false,
        segPaint,
      );

      cumulativeFraction += fraction;
    }

    // ── 3. Centre text ─────────────────────────────────────────────────────
    // Prototype:
    //   <text x={cx} y={cy-2}  ... fontSize="14" fontWeight="700" fill="#F1F5F9">2.72</text>
    //   <text x={cx} y={cy+14} ... fontSize="10" fontFamily="Inter" fill="#94A3B8">TB</text>
    //
    // SVG `y` is the text baseline.  We use TextPainter and offset the box so
    // the baseline aligns with the prototype's y-coordinates.

    _paintCentredText(
      canvas: canvas,
      text: centerText,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14.0 * scale,
        fontWeight: FontWeight.w700,
        color: AppColors.textBright,
        height: 1.0,
      ),
      cx: cx,
      // Baseline at cy − 2 (scaled).  Subtract full ascent so top-of-box is
      // above the baseline by exactly the font ascent — approximated here by
      // aligning the vertical centre of the glyph to the prototype baseline.
      baselineY: cy - 2.0 * scale,
    );

    if (unitText.isNotEmpty) {
      _paintCentredText(
        canvas: canvas,
        text: unitText,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.0 * scale,
          fontWeight: FontWeight.w400,
          color: AppColors.textMutedV2,
          height: 1.0,
        ),
        cx: cx,
        baselineY: cy + 14.0 * scale,
      );
    }
  }

  /// Paints [text] horizontally centred at [cx], with the SVG baseline at
  /// [baselineY].  TextPainter places the origin at the top-left of the text
  /// box, so we offset downward by the ascent to land the baseline correctly.
  void _paintCentredText({
    required Canvas canvas,
    required String text,
    required TextStyle style,
    required double cx,
    required double baselineY,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    // In SVG, y is the alphabetic baseline.  The TextPainter box top is
    // above the baseline by the font's ascent.  We approximate the ascent
    // as 0.72 × fontSize (a well-known typographic heuristic that is close
    // enough for Inter at these sizes).
    final double ascent = (style.fontSize ?? 14.0) * 0.72;
    final double top = baselineY - ascent;
    final double left = cx - tp.width / 2.0;

    tp.paint(canvas, Offset(left, top));
    tp.dispose();
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) {
    if (oldDelegate.centerText != centerText) return true;
    if (oldDelegate.unitText != unitText) return true;
    if (oldDelegate.size != size) return true;
    if (oldDelegate.strokeWidth != strokeWidth) return true;
    if (oldDelegate.segments.length != segments.length) return true;
    if (identical(oldDelegate.segments, segments)) return false;
    for (int i = 0; i < segments.length; i++) {
      if (oldDelegate.segments[i].percent != segments[i].percent) return true;
      if (oldDelegate.segments[i].color != segments[i].color) return true;
    }
    return false;
  }
}
