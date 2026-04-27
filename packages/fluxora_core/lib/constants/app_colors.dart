import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryVariant = Color(0xFF8B5CF6);
  static const Color accent = Color(0xFF22D3EE);
  static const Color accentPurple = Color(0xFFA855F7);

  // Surfaces
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceRaised = Color(0xFF334155);
  static const Color surfaceMuted = Color(0xFF475569);

  // Text
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradient
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, primaryVariant, accent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
