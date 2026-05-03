/// Cast picker bottom sheet — STUB DISABLED in v1.
///
/// Chromecast (`flutter_cast_video`) and AirPlay (iOS platform-channel)
/// are Phase-5+ features. Sheet ships visible + disabled so the design is
/// present in the app menu; rows are non-tappable.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';

class CastSheet extends StatelessWidget {
  const CastSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return FluxBottomSheet(
      title: 'Cast to a device',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pillBgWarning,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border:
                  Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Casting to TVs and speakers is coming in a future release.',
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.pillFgWarning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Opacity(
            opacity: 0.5,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.tv_outlined, color: AppColors.textDim),
              title: Text(
                'Living-room TV',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBody,
                ),
              ),
              subtitle: Text(
                'Chromecast · 192.168.1.42',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDim,
                ),
              ),
              trailing: Icon(Icons.lock_outline,
                  size: 16, color: AppColors.textDim),
              onTap: null,
            ),
          ),
          const Opacity(
            opacity: 0.5,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.speaker_outlined, color: AppColors.textDim),
              title: Text(
                'Kitchen speaker',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBody,
                ),
              ),
              subtitle: Text(
                'AirPlay · 192.168.1.78',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDim,
                ),
              ),
              trailing: Icon(Icons.lock_outline,
                  size: 16, color: AppColors.textDim),
              onTap: null,
            ),
          ),
        ],
      ),
    );
  }
}
