import 'package:flutter/material.dart';

/// Shadow tokens for the desktop redesign.
///
/// Values mirror the prototype's `box-shadow` declarations exactly.
class AppShadows {
  AppShadows._();

  /// Glowing card emphasis — used by `FluxCard(glow: true)`.
  /// CSS: `0 0 0 1px rgba(168,85,247,0.25), 0 0 24px rgba(168,85,247,0.10)`.
  static const List<BoxShadow> cardGlow = [
    BoxShadow(
      color: Color(0x40A855F7), // rgba(168,85,247,0.25)
      blurRadius: 0,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Color(0x1AA855F7), // rgba(168,85,247,0.10)
      blurRadius: 24,
    ),
  ];

  /// Primary CTA glow — used by `FluxButton.primary`.
  /// CSS: `0 4px 12px rgba(139,92,246,0.3)`.
  static const List<BoxShadow> buttonGlow = [
    BoxShadow(
      color: Color(0x4D8B5CF6), // rgba(139,92,246,0.3)
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  /// Halo applied to live `StatusDot`s (online/active/streaming).
  /// CSS: `0 0 8px <colour>` — Flutter renders this as a soft glow; pass
  /// the dot colour into the constructor at use site.
  static List<BoxShadow> dotGlow(Color color) => [
        BoxShadow(color: color, blurRadius: 8),
      ];
}
