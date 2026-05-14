// Update goldens with:
//   flutter test --tags=golden --update-goldens test/goldens/lock_overlay_golden_test.dart
//
// The lock affordance is inline within `FluxPlayerControls` — there is
// no standalone `_LockOverlay` widget.  Capture the entire chrome with
// `controller.lock()` engaged so the hold-to-unlock pill + caption are
// the only visible elements.

@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_mobile/features/player/presentation/controllers/player_controls_controller.dart';
import 'package:fluxora_mobile/features/player/presentation/widgets/flux_player_controls.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '_player_mocks.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('FluxPlayerControls — lock-mode overlay at rest',
      (tester) async {
    final engine = buildFakeEngine(
      position: const Duration(minutes: 27),
      duration: const Duration(hours: 1, minutes: 30),
    );
    final controller = PlayerControlsController();
    // Engage lock mode before pump so the build emits only the
    // hold-to-unlock affordance (no chrome).
    controller.lock();

    await tester.pumpWidgetBuilder(
      Stack(
        children: [
          // Black backdrop stands in for the video surface.
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          FluxPlayerControls(
            engine: engine,
            controller: controller,
            title: 'Inception',
            onBack: () {},
          ),
        ],
      ),
      surfaceSize: const Size(412, 892),
    );

    // 250 ms scrim fade + ink-ripple settle on the hold pill.
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    await screenMatchesGolden(tester, 'player_lock_overlay');

    controller.dispose();
  });
}
