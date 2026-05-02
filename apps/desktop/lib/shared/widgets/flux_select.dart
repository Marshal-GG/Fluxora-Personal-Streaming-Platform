/// FluxSelect — glass-styled dropdown primitive.
///
/// Wraps Material [DropdownButtonFormField] with custom theming that matches
/// the prototype `SelectField` in
/// `docs/11_design/desktop_prototype/app/screens/settings.jsx` lines 152–157.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';

/// A single selectable option for [FluxSelect].
class FluxSelectItem<T> {
  const FluxSelectItem({required this.value, required this.label});
  final T value;
  final String label;
}

/// Dropdown selector matching the prototype glass style.
///
/// Generic over [T] — the value type. [items] is a list of [FluxSelectItem]
/// descriptors. [onChanged] receives the new value when the user picks one.
class FluxSelect<T> extends StatelessWidget {
  const FluxSelect({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.width = 200,
  });

  final String? label;
  final T value;
  final List<FluxSelectItem<T>> items;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  /// Width of the dropdown. Defaults to 200 to match the prototype.
  final double? width;

  @override
  Widget build(BuildContext context) {
    Widget dropdown = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF), // rgba(255,255,255,0.03)
        borderRadius: BorderRadius.circular(AppRadii.sm - 1), // 7
        border: Border.all(color: const Color(0x14FFFFFF)), // rgba(255,255,255,0.08)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1730),
          iconEnabledColor: AppColors.textDim,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            color: AppColors.textBody,
          ),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item.value,
                    child: Text(item.label),
                  ))
              .toList(),
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged?.call(v);
                }
              : null,
        ),
      ),
    );

    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMutedV2,
            ),
          ),
          const SizedBox(height: 5),
          dropdown,
        ],
      );
    }

    return dropdown;
  }
}
