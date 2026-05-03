/// FluxPoster — poster card with optional network image, quality badge,
/// and progress bar.
///
/// Three sizes from the prototype:
///
/// * [FluxPosterSize.rail] — 116×174 (continue-watching / trending rails)
/// * [FluxPosterSize.hero] — 150×220 (large hero rail)
/// * [FluxPosterSize.full] — full-width responsive (detail / library grid)
///
/// `gradient` is rendered as a fallback when [imageUrl] is null or while
/// the network image is loading; matches the prototype's CSS
/// `linear-gradient(...)` mock-data values via [LinearGradient].
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';

enum FluxPosterSize { rail, hero, full }

class FluxPoster extends StatelessWidget {
  const FluxPoster({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.gradient,
    this.size = FluxPosterSize.rail,
    this.qualityBadge,
    this.progress,
    this.onTap,
  });

  /// Title text — overlaid at the bottom on top of a dark gradient.
  final String title;

  /// Optional subtitle (year, episode, etc.) under the title.
  final String? subtitle;

  /// Network image URL. Cached via `cached_network_image`.
  final String? imageUrl;

  /// Optional gradient drawn behind the image (also used as the fallback
  /// when [imageUrl] is null).
  final Gradient? gradient;

  /// Size preset. Defaults to [FluxPosterSize.rail].
  final FluxPosterSize size;

  /// Optional quality badge ("4K" / "HDR" / "1080p"). Rendered top-right.
  final String? qualityBadge;

  /// Optional resume-progress bar (0.0–1.0). Rendered along the bottom edge.
  final double? progress;

  /// Optional tap handler. When `null` the poster is non-interactive.
  final VoidCallback? onTap;

  static (double, double) _dimsFor(FluxPosterSize size) {
    switch (size) {
      case FluxPosterSize.rail:
        return (116, 174);
      case FluxPosterSize.hero:
        return (150, 220);
      case FluxPosterSize.full:
        return (double.infinity, double.infinity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (double w, double h) = _dimsFor(size);

    Widget poster = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (gradient != null)
            DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
          if (imageUrl != null)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (context, url) => const ColoredBox(
                color: AppColors.surfaceGlass,
              ),
              errorWidget: (context, url, error) => const ColoredBox(
                color: AppColors.surfaceGlass,
              ),
            ),
          // Bottom title overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0xCC000000),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBright,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.captionV2.copyWith(
                          color: AppColors.textMutedV2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Quality badge
          if (qualityBadge != null)
            Positioned(
              top: 8,
              right: 8,
              child: FluxChip(qualityBadge!, color: FluxChipColor.purple),
            ),
          // Progress bar
          if (progress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  backgroundColor: const Color(0x33FFFFFF),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.violet),
                  minHeight: 3,
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      poster = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          splashColor: AppColors.pillBgPurple,
          child: poster,
        ),
      );
    }

    if (size == FluxPosterSize.full) {
      return AspectRatio(aspectRatio: 116 / 174, child: poster);
    }

    return SizedBox(width: w, height: h, child: poster);
  }
}
