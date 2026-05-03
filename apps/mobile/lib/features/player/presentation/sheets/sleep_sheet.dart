/// Sleep timer bottom sheet.
///
/// Five presets per the prototype: Off / 15 min / 30 min / End of episode
/// / Custom… ("End of episode" + "Custom" are stub-disabled until the
/// surrounding episode/time-picker work lands. Selection schedules a
/// `Timer` on a top-level singleton or returns the duration to the
/// caller — for now the sheet is presentational and pops with the
/// chosen `Duration?`).
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';

class SleepSheet extends StatelessWidget {
  const SleepSheet({this.current, super.key});

  /// Currently set sleep duration. When `null`, the "Off" row is selected.
  final Duration? current;

  @override
  Widget build(BuildContext context) {
    return FluxBottomSheet(
      title: 'Sleep timer',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Row(
            label: 'Off',
            selected: current == null,
            onTap: () => Navigator.of(context).pop<Duration?>(null),
          ),
          _Row(
            label: '15 minutes',
            selected: current == const Duration(minutes: 15),
            onTap: () =>
                Navigator.of(context).pop<Duration?>(const Duration(minutes: 15)),
          ),
          _Row(
            label: '30 minutes',
            selected: current == const Duration(minutes: 30),
            onTap: () =>
                Navigator.of(context).pop<Duration?>(const Duration(minutes: 30)),
          ),
          _Row(
            label: '60 minutes',
            selected: current == const Duration(minutes: 60),
            onTap: () =>
                Navigator.of(context).pop<Duration?>(const Duration(minutes: 60)),
          ),
          const _Row(label: 'End of episode', selected: false, disabled: true),
          const _Row(label: 'Custom…', selected: false, disabled: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.selected,
    this.onTap,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: ListTile(
        dense: false,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? AppColors.violet : AppColors.textDim,
          size: 20,
        ),
        title: Text(
          label,
          style: AppTypography.body.copyWith(
            color: selected ? AppColors.textBright : AppColors.textBody,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: disabled ? null : onTap,
      ),
    );
  }
}
