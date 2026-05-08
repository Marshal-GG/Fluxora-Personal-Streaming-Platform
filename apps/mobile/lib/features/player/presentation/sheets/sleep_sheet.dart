/// Sleep timer bottom sheet.
///
/// Six presets per the prototype: Off / 15 min / 30 min / 60 min /
/// End of episode / Custom…  All return a `Duration?` to the caller.
///
/// "Custom…" opens `showTimePicker` (mobile redesign audit §17.3 #9 —
/// the audit explicitly suggested this pattern; the picker's hh:mm
/// output is reinterpreted as `Duration(hours, minutes)` so users can
/// dial in any sleep window from 1 minute up to 23 h 59 min).
///
/// "End of episode" stays stub-disabled — it needs the next-episode
/// resolution logic that hangs off `PlayerCubit`'s end-of-stream hook
/// (same hook autoplay-next will use).  Tracked separately so the
/// next-episode resolver and both consumers ship as one unit.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';

class SleepSheet extends StatelessWidget {
  const SleepSheet({this.current, super.key});

  /// Currently set sleep duration. When `null`, the "Off" row is selected.
  final Duration? current;

  /// Whether `current` matches one of the four built-in presets.  When
  /// false, the row driving `current` is the "Custom…" row, which gets
  /// the selected styling so the user can see at a glance that a custom
  /// value is active.
  bool get _isCustomActive {
    if (current == null) return false;
    return current != const Duration(minutes: 15) &&
        current != const Duration(minutes: 30) &&
        current != const Duration(minutes: 60);
  }

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
          _Row(
            label: _isCustomActive
                ? 'Custom (${_formatDuration(current!)})'
                : 'Custom…',
            selected: _isCustomActive,
            onTap: () => _pickCustom(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    // Repurpose `showTimePicker` as a duration picker: hh:mm chosen by
    // the user → `Duration(hours: hh, minutes: mm)`.  Default seed is
    // 45 minutes — the most common sleep-window for this kind of UI.
    final navigator = Navigator.of(context);
    final seed = _isCustomActive
        ? TimeOfDay(
            hour: current!.inHours,
            minute: current!.inMinutes.remainder(60),
          )
        : const TimeOfDay(hour: 0, minute: 45);
    final picked = await showTimePicker(
      context: context,
      initialTime: seed,
      helpText: 'Sleep after',
      hourLabelText: 'Hours',
      minuteLabelText: 'Minutes',
      builder: (ctx, child) =>
          MediaQuery(
        // Force 24-h mode so the AM/PM toggle doesn't confuse a duration
        // dial-in.  The picker's underlying widget honours
        // `alwaysUse24HourFormat` regardless of the device locale.
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final duration = Duration(hours: picked.hour, minutes: picked.minute);
    if (duration == Duration.zero) return; // 0:00 cancels
    navigator.pop<Duration?>(duration);
  }
}

/// Renders a `Duration` as `Hh Mm` / `Hh` / `Mm` depending on which
/// fields are non-zero.  Used by the "Custom (…)" row label.
String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
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
