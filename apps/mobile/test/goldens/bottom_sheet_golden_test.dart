// Update goldens with:
//   flutter test --tags=golden --update-goldens test/goldens/bottom_sheet_golden_test.dart
//
// Captures the player's 4x2 quick-action grid (renders along the
// bottom of the chrome above the progress bar) — the "bottom sheet"
// surface from the M14 component list refers to this affordance,
// which doubles as the launch point for the audio / speed / sleep /
// quality / cast modal sheets.

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

  testGoldens('PlayerQuickActions — fit + sleep-inactive baseline',
      (tester) async {
    await tester.pumpWidgetBuilder(
      ColoredBox(
        color: const Color(0xCC000000),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: PlayerQuickActions(
            onLock: () {},
            onFit: () {},
            fitCover: true,
            onOpenSheet: (_) {},
            sleepActive: false,
          ),
        ),
      ),
      // 4x2 grid (two Rows of four Expanded cells) — fits at portrait
      // 412 px and matches plan §14's "4x2 quick-control grid" spec.
      // Capture at portrait width so the baseline reflects the most
      // constrained layout; landscape just stretches the columns.
      surfaceSize: const Size(412, 140),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'player_quick_actions');
  });
}
