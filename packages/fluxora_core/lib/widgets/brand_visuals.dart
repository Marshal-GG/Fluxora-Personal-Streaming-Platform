/// Branded visual primitives — thin Flutter wrappers around the SVG assets
/// in `packages/fluxora_core/assets/illustrations/` and around the official
/// brand PNG logo.
///
/// Each widget here covers a visual where pure-Flutter implementation would
/// be either expensive (multiple AnimationControllers, custom paths) or
/// non-pixel-faithful. SVG owns animation via SMIL where possible; the
/// `BrandLoader` is the exception — it composites the official logo PNG
/// inside a Flutter-driven gradient ring so the brand mark itself is never
/// recreated, only decorated.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/widgets/fluxora_logo.dart';

/// Decorative flowing-wave backdrop — drop into hero / empty-state areas.
///
/// Renders the prototype's banner-style wave texture as an animated SVG.
/// Stretches to fill, so wrap in a `SizedBox` or `Positioned.fill` to
/// constrain. `BoxFit.cover` is the default to preserve the gradient flow.
class HeroWaves extends StatelessWidget {
  const HeroWaves({
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.opacity = 1.0,
  });

  /// How the SVG fills its parent.
  final BoxFit fit;

  /// Alignment within the parent.
  final AlignmentGeometry alignment;

  /// Multiplier applied on top of the SVG's own opacity stops. Use a value
  /// like `0.6` when the waves should sit under busy content.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final svg = SvgPicture.asset(
      'assets/illustrations/hero_waves.svg',
      package: 'fluxora_core',
      fit: fit,
      alignment: alignment,
    );
    if (opacity == 1.0) return svg;
    return Opacity(opacity: opacity, child: svg);
  }
}

/// Branded loading spinner.
///
/// Composites the official [FluxoraMark] PNG (untouched) inside a rotating
/// gradient ring with a subtle scale-pulse on the mark itself. The brand
/// logo is never re-drawn — the ring and the breathing animation are the
/// only Flutter-side additions.
///
/// Use whenever the user is waiting on something Fluxora-specific
/// (pairing, library scan, transcode kickoff).
class BrandLoader extends StatefulWidget {
  const BrandLoader({super.key, this.size = 48});

  /// Total dimension including the surrounding ring. The inner mark renders
  /// at ~70 % of this size so the ring has visual room to breathe.
  final double size;

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringStroke = widget.size * 0.06;
    final markSize = widget.size * 0.70;

    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating gradient ring — pure Flutter, doesn't touch the logo.
          AnimatedBuilder(
            animation: _spin,
            builder: (context, _) {
              return Transform.rotate(
                angle: _spin.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _LoaderRingPainter(strokeWidth: ringStroke),
                ),
              );
            },
          ),

          // Untouched brand mark with a gentle scale-pulse.
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final scale = 0.94 + 0.06 * _pulse.value;
              return Transform.scale(scale: scale, child: child);
            },
            child: FluxoraMark(size: markSize),
          ),
        ],
      ),
    );
  }
}

/// Paints the loader's rotating ring — a violet→cyan sweep along an arc,
/// fading to transparent at one end.
class _LoaderRingPainter extends CustomPainter {
  const _LoaderRingPainter({required this.strokeWidth});

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Sweep gradient: opaque violet → cyan → transparent. Drawn over a
    // 280-degree arc; the remaining 80 degrees is the visible "tail" gap.
    const sweep = 280.0 * math.pi / 180;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Color(0x008B5CF6), // transparent at start
          Color(0xFF8B5CF6),
          Color(0xFFA855F7),
          Color(0xFF22D3EE),
        ],
        stops: [0.0, 0.4, 0.7, 1.0],
        startAngle: 0,
        endAngle: sweep,
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _LoaderRingPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth;
}

/// Pulse ring around a live-status dot. Drop on top of a [StatusDot] (via
/// `Stack`) when the indicator should read as "actively transmitting".
///
/// Recolour the ring by passing a [color] — it propagates through the SVG's
/// `currentColor` placeholders.
class PulseRing extends StatelessWidget {
  const PulseRing({
    super.key,
    this.size = 64,
    this.color = AppColors.statusStreaming,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        'assets/illustrations/pulse_ring.svg',
        package: 'fluxora_core',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

/// Empty-state slot — pairs an illustration with a title + optional
/// supporting line. Intentionally minimal so screens compose their own
/// CTA buttons below.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
    this.illustrationHeight = 160,
  });

  /// The illustration variant — the `EmptyStateIllustration` enum maps to
  /// an SVG asset under `assets/illustrations/`.
  final EmptyStateIllustration illustration;

  /// Big title — what's missing or what the user needs to do.
  final String title;

  /// Optional supporting line below the title. Keep to one short sentence.
  final String? message;

  /// Height of the illustration. Width scales to preserve aspect.
  final double illustrationHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: illustrationHeight,
          child: SvgPicture.asset(
            illustration._asset,
            package: 'fluxora_core',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textBright,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: AppColors.textMutedV2,
            ),
          ),
        ],
      ],
    );
  }
}

/// Available empty-state illustration assets.
enum EmptyStateIllustration {
  libraries('assets/illustrations/empty_libraries.svg'),
  clients('assets/illustrations/empty_clients.svg');

  const EmptyStateIllustration(this._asset);
  final String _asset;
}
