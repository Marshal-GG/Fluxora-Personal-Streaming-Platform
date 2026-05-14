// Update goldens with:
//   flutter test --tags=golden --update-goldens test/goldens/poster_golden_test.dart
//
// Captures the standalone hero-size poster (150x220) with a
// deterministic gradient fallback — no network image so the golden is
// stable without bundling an asset.

@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('FluxPoster — hero size with quality badge + progress',
      (tester) async {
    await tester.pumpWidgetBuilder(
      ColoredBox(
        color: const Color(0xFF08061A),
        child: Center(
          child: FluxPoster(
            title: 'Inception',
            subtitle: '2010 · 2h 28m',
            size: FluxPosterSize.hero,
            qualityBadge: '4K',
            progress: 0.3,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.violetDeep, AppColors.violet],
            ),
            onTap: () {},
          ),
        ),
      ),
      surfaceSize: const Size(180, 250),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'flux_poster_hero');
  });
}
