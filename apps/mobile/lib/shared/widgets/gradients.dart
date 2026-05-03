/// Brand gradient placeholders used by `FluxPoster`, mini-player, avatar
/// chip, and any other surface that needs a deterministic colour fill when
/// no real image / TMDB poster is available.
///
/// Lifted from `shared/data/mock_data.dart` (Phase A backfill plan §5
/// row 8) so the gradients survive after `MockData` is shrunk to the
/// Phase B / C / D fixtures.  Pure colour data — no fixture lists, no
/// imports beyond `material.dart`.
library;

import 'package:flutter/material.dart';

/// Static gradients matching the prototype's named palette.
///
/// All entries are `LinearGradient` from top-left to bottom-right so they
/// compose with each other in lists without abrupt direction changes.
class AppGradientPlaceholders {
  AppGradientPlaceholders._();

  static const violetCyan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA855F7), Color(0xFF22D3EE)],
  );
  static const pinkAmber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEC4899), Color(0xFFF59E0B)],
  );
  static const emeraldBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
  );
  static const violetDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFA855F7), Color(0xFFEC4899)],
  );
  static const indigoCyan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
  );
  static const amberRose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  );

  /// Deterministic placeholder gradient keyed off any string identifier
  /// (file id, library id, etc.).  Stable across rebuilds so a poster
  /// without a TMDB image keeps the same colour band as the user
  /// scrolls.  Six gradients × hash → roughly even visual distribution.
  static const _palette = <LinearGradient>[
    violetCyan,
    pinkAmber,
    emeraldBlue,
    violetDeep,
    indigoCyan,
    amberRose,
  ];

  static LinearGradient forKey(String key) {
    if (key.isEmpty) return violetDeep;
    final h = key.hashCode & 0x7fffffff;
    return _palette[h % _palette.length];
  }
}
