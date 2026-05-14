// Update goldens with:
//   flutter test --tags=golden --update-goldens test/goldens/top_bar_golden_test.dart
//
// CI runs `flutter test --exclude-tags=golden` so this baseline only
// matters on the maintainer's Windows machine.  See _README.md.

@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_mobile/features/player/presentation/widgets/flux_player_controls.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('PlayerTopBar — title + back + overflow', (tester) async {
    await tester.pumpWidgetBuilder(
      // Top bar paints over a black scrim in production — match that
      // so the white-on-black contrast is captured the same way.
      const ColoredBox(
        color: Color(0xCC000000),
        child: Align(
          alignment: Alignment.topCenter,
          child: PlayerTopBar(
            title: 'Inception',
            onBack: _noop,
            onMore: _noop,
            onPip: _noop,
            onXRay: _noop,
            sleepActive: false,
            onLock: _noop,
            onFit: _noop,
            fitCover: false,
            hdrFormat: 'HDR10',
          ),
        ),
      ),
      surfaceSize: const Size(412, 88),
    );

    // Drain the IconButton ink-ripple settle; no animations otherwise.
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'player_top_bar');
  });
}

void _noop() {}
