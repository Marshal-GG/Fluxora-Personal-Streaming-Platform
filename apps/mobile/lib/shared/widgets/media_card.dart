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
            Container(
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
            ),
            const SizedBox(width: AppSizes.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: AppTypography.headingMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.s1),
                  Text(
                    _subtitle,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
