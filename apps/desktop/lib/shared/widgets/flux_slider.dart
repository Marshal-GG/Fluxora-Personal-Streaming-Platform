/// FluxSlider — violet-themed range slider.
///
/// Thin Material [Slider] wrapper with a custom [SliderTheme] that matches
/// the violet palette used in the prototype's transcoding CRF control.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';

class FluxSlider extends StatelessWidget {
  const FluxSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.label,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.violet,
        inactiveTrackColor: const Color(0x29A855F7), // violet at 16% opacity
        thumbColor: AppColors.violet,
        overlayColor: const Color(0x29A855F7),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        valueIndicatorColor: AppColors.violetDeep,
        valueIndicatorTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
      ),
    );
  }
}
