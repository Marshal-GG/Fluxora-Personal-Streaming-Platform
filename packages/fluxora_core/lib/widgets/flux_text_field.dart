/// FluxTextField — glass-styled single-line text input for the mobile redesign.
///
/// Mobile prototype spec: 48 px tall, radius 10, `rgba(255,255,255,0.04)` bg,
/// 1.5 px violet focus border. Optional leading icon (search / mail / etc.)
/// and trailing widget (icon button, mic, etc.).
///
/// `density: FluxTextFieldDensity.compact` switches to the desktop-style
/// 12.5/600 size used in settings forms (kept here as a compatibility hook
/// — desktop still ships its own `apps/desktop/lib/shared/widgets/flux_text_field.dart`
/// with extra features today and consumers there shouldn't switch yet).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';

enum FluxTextFieldDensity { mobile, compact }

class FluxTextField extends StatelessWidget {
  const FluxTextField({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.leadingIcon,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.density = FluxTextFieldDensity.mobile,
  });

  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final IconData? leadingIcon;
  final Widget? trailing;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final FluxTextFieldDensity density;

  bool get _isMobile => density == FluxTextFieldDensity.mobile;

  @override
  Widget build(BuildContext context) {
    final double fontSize = _isMobile ? 14 : 12.5;
    final double height = _isMobile ? 48 : 32;
    final double radius = _isMobile ? 10 : AppRadii.sm - 1;
    final EdgeInsets contentPadding = _isMobile
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 7);

    final field = SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        enabled: enabled,
        autofocus: autofocus,
        cursorColor: AppColors.violet,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          color: AppColors.textBright,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: fontSize,
            color: AppColors.textDim,
          ),
          prefixIcon: leadingIcon != null
              ? Icon(leadingIcon, size: 18, color: AppColors.textMutedV2)
              : null,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: trailing,
          filled: true,
          fillColor: const Color(0x0AFFFFFF),
          contentPadding: contentPadding,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: Color(0x14FFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: Color(0x0AFFFFFF)),
          ),
          isDense: !_isMobile,
        ),
      ),
    );

    if (label == null) return field;

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
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}
