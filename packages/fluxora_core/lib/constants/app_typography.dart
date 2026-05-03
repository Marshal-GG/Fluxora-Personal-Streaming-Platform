import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';

class AppTypography {
  AppTypography._();

  static const String _fontFamily = 'Inter';
  static const String _monoFamily = 'JetBrains Mono';

  /// 24/700/-0.01em — primary stat values, hero numbers.
  static const TextStyle displayV2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.24,
    color: AppColors.textBright,
  );

  /// 18/700 — page-title weight on subscription / billing cards.
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textBright,
  );

  /// 14/600 — section / card titles ("Server Information", "Quick Access").
  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textBright,
  );

  /// 13/500 — primary body text, nav labels, table cell values.
  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textBody,
  );

  /// 12/500 — dense rows, label/value strings.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textMutedV2,
  );

  /// 11/500 — captions, sub-labels.
  static const TextStyle captionV2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textMutedV2,
  );

  /// 10.5/500 — sidebar IP / "uptime" metadata. Matches the prototype's
  /// odd 10.5 size verbatim — yes, half-pixels render fine.
  static const TextStyle micro = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textDim,
  );

  /// 11/600 / 0.14em uppercase — section eyebrows ("SYSTEM STATUS").
  static const TextStyle eyebrow = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 1.54, // 0.14em × 11
    color: AppColors.textDim,
  );

  /// JetBrains Mono variants used for IPs, codecs, timestamps.
  static const TextStyle monoBody = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textBody,
  );

  static const TextStyle monoCaption = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textMutedV2,
  );

  static const TextStyle monoMicro = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textDim,
  );
}
