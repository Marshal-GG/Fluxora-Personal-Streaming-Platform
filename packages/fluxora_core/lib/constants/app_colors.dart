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

  // ── Desktop redesign palette ────────────────────────────────────────────
  // Tokens harvested from docs/11_design/desktop_prototype/. Values are
  // exact matches to the prototype CSS — never approximate.
  // Old Fluxora-mobile constants above are preserved during the redesign
  // migration and removed at M9 cutover.

  static const Color bgRoot = Color(0xFF08061A);
  static const Color surfaceGlass = Color(0xB3141226); // rgba(20,18,38,0.7)
  static const Color borderSubtle = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const Color borderHover = Color(0x66A855F7); // rgba(168,85,247,0.4)
  static const Color sidebarGlass = Color(0xB30D0B1C); // rgba(13,11,28,0.7)
  static const Color titlebarGlass = Color(0xE606040F); // rgba(6,4,16,0.9)

  static const Color textBright = Color(0xFFF1F5F9);
  static const Color textBody = Color(0xFFE2E8F0);
  static const Color textMutedV2 = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);
  static const Color textFaint = Color(0xFF475569);

  static const Color violet = Color(0xFFA855F7);
  static const Color violetDeep = Color(0xFF8B5CF6);
  static const Color violetTint = Color(0xFFC4A8F5);
  static const Color violetSoft = Color(0xFFE9D5FF);

  static const Color cyan = Color(0xFF22D3EE);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color blue = Color(0xFF3B82F6);
  static const Color pink = Color(0xFFEC4899);

  // Pill backgrounds — translucent variants used throughout.
  static const Color pillBgNeutral = Color(0x2E475569); // rgba(71,85,105,0.18)
  static const Color pillBgPurple = Color(0x29A855F7); // rgba(168,85,247,0.16)
  static const Color pillBgSuccess = Color(0x2610B981); // rgba(16,185,129,0.15)
  static const Color pillBgWarning = Color(0x26F59E0B); // rgba(245,158,11,0.15)
  static const Color pillBgError = Color(0x26EF4444); // rgba(239,68,68,0.15)
  static const Color pillBgInfo = Color(0x263B82F6); // rgba(59,130,246,0.15)
  static const Color pillBgPink = Color(0x26EC4899); // rgba(236,72,153,0.15)

  // Pill foregrounds.
  static const Color pillFgNeutral = textMutedV2;
  static const Color pillFgPurple = violetTint;
  static const Color pillFgSuccess = Color(0xFF34D399);
  static const Color pillFgWarning = Color(0xFFFBBF24);
  static const Color pillFgError = Color(0xFFF87171);
  static const Color pillFgInfo = Color(0xFF60A5FA);
  static const Color pillFgPink = Color(0xFFF472B6);

  // Status-dot fills (re-exposed by status semantic name).
  static const Color statusOnline = emerald;
  static const Color statusActive = emerald;
  static const Color statusStreaming = violet;
  static const Color statusIdle = amber;
  static const Color statusPending = amber;
  static const Color statusOffline = textFaint;
  static const Color statusInactive = textDim;
  static const Color statusError = red;
}
