import 'package:flutter/material.dart';

/// V2 design palette — values harvested from `docs/11_design/desktop_prototype/`.
/// All hex values are exact matches to the prototype CSS — never approximate.
///
/// The legacy V1 mobile palette (`primary` indigo `#6366F1`, `accent`,
/// `surface`, `textPrimary`, etc.) was removed at the M9 mobile theme cutover
/// (2026-05-03). Both apps now share this single V2 token set.
class AppColors {
  AppColors._();

  // ── Surfaces ───────────────────────────────────────────────────────────
  static const Color bgRoot = Color(0xFF08061A);
  static const Color surfaceGlass = Color(0xB3141226); // rgba(20,18,38,0.7)
  // Opaque raised surface for popup menus, dialog backgrounds, AppBar /
  // SnackBar / Card chrome, and any floating panel that mounts directly
  // over the `bgRoot` scaffold. The translucent `surfaceGlass` lets the
  // page bleed through, which reads as "broken" rather than "glass" on
  // popups. Hex matches the prototype's canonical raised value already
  // used by `FluxBottomSheet` (`packages/fluxora_core/lib/widgets/flux_bottom_sheet.dart`)
  // and the mobile theme's `InputDecorationTheme.fillColor` — using one
  // token keeps desktop popups visually identical to the mobile variant.
  static const Color bgRaised = Color(0xFF0F0C24);
  static const Color borderSubtle = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const Color borderHover = Color(0x66A855F7); // rgba(168,85,247,0.4)
  static const Color sidebarGlass = Color(0xB30D0B1C); // rgba(13,11,28,0.7)
  static const Color titlebarGlass = Color(0xE606040F); // rgba(6,4,16,0.9)

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color textBright = Color(0xFFF1F5F9);
  static const Color textBody = Color(0xFFE2E8F0);
  static const Color textMutedV2 = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);
  static const Color textFaint = Color(0xFF475569);

  // ── Accent / brand ─────────────────────────────────────────────────────
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

  // ── Pill backgrounds (translucent variants used throughout). ───────────
  static const Color pillBgNeutral = Color(0x2E475569); // rgba(71,85,105,0.18)
  static const Color pillBgPurple = Color(0x29A855F7); // rgba(168,85,247,0.16)
  static const Color pillBgSuccess = Color(0x2610B981); // rgba(16,185,129,0.15)
  static const Color pillBgWarning = Color(0x26F59E0B); // rgba(245,158,11,0.15)
  static const Color pillBgError = Color(0x26EF4444); // rgba(239,68,68,0.15)
  static const Color pillBgInfo = Color(0x263B82F6); // rgba(59,130,246,0.15)
  static const Color pillBgPink = Color(0x26EC4899); // rgba(236,72,153,0.15)

  // ── Pill foregrounds. ──────────────────────────────────────────────────
  static const Color pillFgNeutral = textMutedV2;
  static const Color pillFgPurple = violetTint;
  static const Color pillFgSuccess = Color(0xFF34D399);
  static const Color pillFgWarning = Color(0xFFFBBF24);
  static const Color pillFgError = Color(0xFFF87171);
  static const Color pillFgInfo = Color(0xFF60A5FA);
  static const Color pillFgPink = Color(0xFFF472B6);

  // ── Status-dot fills (re-exposed by status semantic name). ─────────────
  static const Color statusOnline = emerald;
  static const Color statusActive = emerald;
  static const Color statusStreaming = violet;
  static const Color statusIdle = amber;
  static const Color statusPending = amber;
  static const Color statusOffline = textFaint;
  static const Color statusInactive = textDim;
  static const Color statusError = red;
}
