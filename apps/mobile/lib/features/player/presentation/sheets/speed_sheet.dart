/// Playback speed bottom sheet.
///
/// Reads `player.state.rate`, dispatches `player.setRate` on selection.
/// Six presets per the prototype: 0.5× / 0.75× / 1× / 1.25× / 1.5× / 2×.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:media_kit/media_kit.dart' show Player;

class SpeedSheet extends StatelessWidget {
  const SpeedSheet({required this.player, super.key});

  final Player player;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final current = player.state.rate;
    return FluxBottomSheet(
      title: 'Playback speed',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final speed in _speeds)
            _SpeedRow(
              speed: speed,
              selected: speed == current,
              onTap: () {
                player.setRate(speed);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.speed,
    required this.selected,
    required this.onTap,
  });

  final double speed;
  final bool selected;
  final VoidCallback onTap;

  String get _label {
    if (speed == 1.0) return 'Normal (1×)';
    return '${speed.toString().replaceAll(RegExp(r'\.0$'), '')}×';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: false,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? AppColors.violet : AppColors.textDim,
        size: 20,
      ),
      title: Text(
        _label,
        style: AppTypography.body.copyWith(
          color: selected ? AppColors.textBright : AppColors.textBody,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
