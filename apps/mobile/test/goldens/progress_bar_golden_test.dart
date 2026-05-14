// Update goldens with:
//   flutter test --tags=golden --update-goldens test/goldens/progress_bar_golden_test.dart

@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_mobile/features/player/presentation/widgets/flux_player_controls.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '_player_mocks.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('PlayerProgressBar — 30% through a 1h30m movie', (tester) async {
    // Deterministic playhead: 27 m of 1 h 30 m -> 30% (matches plan
    // §14 sample-data spec for the scrubber capture).
    final player = buildFakePlayer(
      position: const Duration(minutes: 27),
      duration: const Duration(hours: 1, minutes: 30),
    );

    await tester.pumpWidgetBuilder(
      ColoredBox(
        color: const Color(0xCC000000),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: PlayerProgressBar(player: player),
        ),
      ),
      surfaceSize: const Size(412, 60),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'player_progress_bar');
  });
}
