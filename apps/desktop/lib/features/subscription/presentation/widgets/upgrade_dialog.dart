/// Upgrade-to-Pro dialog — surfaced on every desktop app startup.
///
/// Wraps [FluxGlassDialog] with a value-prop body and two actions:
/// "Maybe Later" (dismiss) and "View Plans" (navigate to `/subscription`).
/// Dismissable via outside-tap, Esc, or the explicit dismiss action.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/widgets/flux_button.dart';

import 'package:fluxora_desktop/shared/widgets/flux_glass_dialog.dart';

/// Shows the dismissable upgrade dialog. Returns when the user closes it
/// (via Maybe Later, View Plans, outside-tap, or Esc).
Future<void> showUpgradeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _UpgradeDialog(),
  );
}

class _UpgradeDialog extends StatelessWidget {
  const _UpgradeDialog();

  static const _features = <_FeatureRow>[
    _FeatureRow(
      icon: Icons.devices_other_outlined,
      label: 'Unlimited concurrent streams across every device',
    ),
    _FeatureRow(
      icon: Icons.high_quality_outlined,
      label: 'Hardware-accelerated 4K transcoding',
    ),
    _FeatureRow(
      icon: Icons.cloud_outlined,
      label: 'Remote access over WebRTC with relay fallback',
    ),
    _FeatureRow(
      icon: Icons.support_agent_outlined,
      label: 'Priority support and early access to new features',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FluxGlassDialog(
      maxWidth: 460,
      title: const Text('Upgrade to Pro'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlock premium features and experience Fluxora without limits.',
            style: AppTypography.body.copyWith(color: AppColors.textBody),
          ),
          const SizedBox(height: AppSpacing.s16),
          for (final feature in _features) ...[
            feature,
            const SizedBox(height: AppSpacing.s10),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        FluxButton(
          variant: FluxButtonVariant.primary,
          size: FluxButtonSize.md,
          onPressed: () {
            Navigator.of(context).pop();
            context.go('/subscription');
          },
          child: const Text('View Plans'),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.violetTint),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textBody),
          ),
        ),
      ],
    );
  }
}
