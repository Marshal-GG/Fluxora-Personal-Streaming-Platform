import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';

/// Fluxora "F" lettermark — square, transparent background.
///
/// Asset is the cropped icon PNG from the brand sheet. Pass [glow] to add
/// the prototype's violet drop-shadow, used on the login splash.
class FluxoraMark extends StatelessWidget {
  const FluxoraMark({super.key, this.size = 32, this.glow = false});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/brand/logo-icon.png',
      package: 'fluxora_core',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (!glow) return image;

    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x8CA855F7), // rgba(168,85,247,0.55)
            blurRadius: 8,
          ),
        ],
      ),
      child: image,
    );
  }
}

/// Fluxora horizontal wordmark — the F lettermark integrated with the
/// FLUXORA text in one image. Use this anywhere a brand identifier is
/// needed; do **not** combine with [FluxoraMark] side-by-side or you'll
/// double the F.
class FluxoraWordmark extends StatelessWidget {
  const FluxoraWordmark({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/logo-wordmark-h.png',
      package: 'fluxora_core',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Wordmark + optional tagline. Used in the sidebar header.
///
/// The wordmark is the integrated logo (F + FLUXORA in one image), so
/// `withWordmark: false` falls back to the standalone [FluxoraMark]
/// only — useful for tight slots where only the mark fits.
class FluxoraLogo extends StatelessWidget {
  const FluxoraLogo({
    super.key,
    this.size = 32,
    this.withWordmark = true,
    this.withTagline = false,
  });

  /// In wordmark mode this controls the wordmark image's height.
  /// In mark-only mode this is the mark's edge size (square).
  final double size;
  final bool withWordmark;
  final bool withTagline;

  @override
  Widget build(BuildContext context) {
    if (!withWordmark) {
      return FluxoraMark(size: size);
    }

    final wordmark = FluxoraWordmark(height: size);

    if (!withTagline) return wordmark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        wordmark,
        SizedBox(height: size * 0.18),
        Text(
          'Stream. Sync. Anywhere.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: size * 0.26,
            fontWeight: FontWeight.w500,
            height: 1.0,
            letterSpacing: size * 0.01,
            color: AppColors.textDim,
          ),
        ),
      ],
    );
  }
}
