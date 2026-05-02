/// FluxTextField — glass-styled single-line text input.
///
/// Thin Material [TextField] wrapper with custom [InputDecoration] that
/// matches the prototype `TextField` component in
/// `docs/11_design/desktop_prototype/app/screens/settings.jsx` lines 144–151.
///
/// No Material chrome (label floating, underline, ripple) bleeds through.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';

class FluxTextField extends StatelessWidget {
  const FluxTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.enabled = true,
    this.inputFormatters,
    this.onChanged,
    this.width = 200,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  /// Width of the input field. Defaults to 200 to match the prototype.
  final double? width;

  @override
  Widget build(BuildContext context) {
    Widget field = TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12.5,
        color: AppColors.textBody,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.5,
          color: AppColors.textDim,
        ),
        filled: true,
        fillColor: const Color(0x08FFFFFF), // rgba(255,255,255,0.03)
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm - 1), // 7
          borderSide:
              const BorderSide(color: Color(0x14FFFFFF)), // rgba(255,255,255,0.08)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm - 1),
          borderSide:
              const BorderSide(color: AppColors.violet, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm - 1),
          borderSide: const BorderSide(color: Color(0x0AFFFFFF)),
        ),
        border: InputBorder.none,
        isDense: true,
      ),
    );

    if (width != null) {
      field = SizedBox(width: width, child: field);
    }

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
          field,
        ],
      );
    }

    return field;
  }
}
