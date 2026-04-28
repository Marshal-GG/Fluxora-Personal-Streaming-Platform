import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_sizes.dart';
import 'package:fluxora_core/constants/app_typography.dart';

enum BadgeStatus { online, idle, offline }

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final BadgeStatus status;

  Color get _color => switch (status) {
        BadgeStatus.online => AppColors.success,
        BadgeStatus.idle => AppColors.warning,
        BadgeStatus.offline => AppColors.textMuted,
      };

  String get _label => switch (status) {
        BadgeStatus.online => 'Online',
        BadgeStatus.idle => 'Idle',
        BadgeStatus.offline => 'Offline',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s2,
        vertical: AppSizes.s1,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSizes.s1),
          Text(
            _label,
            style: AppTypography.label.copyWith(color: _color),
          ),
        ],
      ),
    );
  }
}
