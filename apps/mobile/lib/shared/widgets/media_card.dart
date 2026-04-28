import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_sizes.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/media_file.dart';

class MediaCard extends StatelessWidget {
  const MediaCard({
    required this.file,
    required this.onTap,
    super.key,
  });

  final MediaFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.s4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.surfaceRaised),
        ),
        child: Row(
          children: [
            _Thumbnail(posterUrl: file.posterUrl),
            const SizedBox(width: AppSizes.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title ?? file.name,
                    style: AppTypography.headingMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (file.overview != null && file.overview!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.s1),
                    Text(
                      file.overview!,
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    const SizedBox(height: AppSizes.s1),
                    Text(
                      _subtitle,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Resume progress indicator
                  if (file.resumeSec > 0 && file.durationSec != null)
                    _ResumeBar(
                      resumeSec: file.resumeSec,
                      durationSec: file.durationSec!,
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    final parts = <String>[file.extension.toUpperCase()];
    final dur = file.durationSec;
    if (dur != null) {
      final d = Duration(seconds: dur.toInt());
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      parts.add(h > 0 ? '${h}h ${m}m' : '${m}m');
    }
    final mb = file.sizeBytes / (1024 * 1024);
    parts.add(
      mb >= 1024
          ? '${(mb / 1024).toStringAsFixed(1)} GB'
          : '${mb.toStringAsFixed(0)} MB',
    );
    return parts.join(' · ');
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.posterUrl});

  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    if (posterUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: CachedNetworkImage(
          imageUrl: posterUrl!,
          width: 44,
          height: 66,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(),
          errorWidget: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: const Icon(
          Icons.movie_outlined,
          color: AppColors.textSecondary,
          size: 20,
        ),
      );
}

class _ResumeBar extends StatelessWidget {
  const _ResumeBar({required this.resumeSec, required this.durationSec});

  final double resumeSec;
  final double durationSec;

  @override
  Widget build(BuildContext context) {
    final progress = (resumeSec / durationSec).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.s2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 3,
          backgroundColor: AppColors.surfaceRaised,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}
