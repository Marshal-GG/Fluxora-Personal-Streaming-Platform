import 'package:flutter/material.dart';

/// Gradients harvested from `docs/11_design/desktop_prototype/`.
///
/// Use these instead of inline `LinearGradient(...)` so colour edits flow
/// through one file. Angles match the CSS source: `135deg` ≈ topLeft →
/// bottomRight, `90deg` ≈ centerLeft → centerRight.
class AppGradients {
  AppGradients._();

  /// Primary CTA gradient — `linear-gradient(135deg, #8B5CF6, #A855F7)`.
  /// Used by FluxButton.primary, the user-footer avatar fallback, and any
  /// "brand" emphasis.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
  );

  /// Determinate progress fill — `linear-gradient(90deg, #8B5CF6, #A855F7)`.
  static const LinearGradient progress = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
  );

  /// Sidebar "Upgrade" callout —
  /// `linear-gradient(135deg, rgba(168,85,247,0.18), rgba(139,92,246,0.08))`.
  static const LinearGradient upgradeCallout = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2EA855F7), Color(0x148B5CF6)],
  );

  /// Ambient background glow — top-left violet wash.
  /// CSS: `radial-gradient(1200px circle at 0% 0%, rgba(168,85,247,0.12), transparent 50%)`.
  static const RadialGradient bgRadialViolet = RadialGradient(
    center: Alignment.topLeft,
    radius: 1.2,
    colors: [Color(0x1FA855F7), Colors.transparent],
    stops: [0.0, 0.5],
  );

  /// Ambient background glow — bottom-right cyan wash.
  /// CSS: `radial-gradient(1000px circle at 100% 100%, rgba(34,211,238,0.06), transparent 50%)`.
  static const RadialGradient bgRadialCyan = RadialGradient(
    center: Alignment.bottomRight,
    radius: 1.0,
    colors: [Color(0x0F22D3EE), Colors.transparent],
    stops: [0.0, 0.5],
  );
}
