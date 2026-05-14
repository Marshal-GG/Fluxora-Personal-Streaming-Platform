// Update goldens with:
//   flutter test --tags=golden --update-goldens test/goldens/side_rail_left_golden_test.dart

@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_mobile/features/player/presentation/controllers/player_controls_controller.dart';
import 'package:fluxora_mobile/features/player/presentation/widgets/flux_player_controls.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('PlayerSideRail — left brightness rail', (tester) async {
    await tester.pumpWidgetBuilder(
      const ColoredBox(
        color: Color(0x99000000),
        child: Align(
          alignment: Alignment.centerLeft,
          child: PlayerSideRail(
            icon: Icons.brightness_6_outlined,
            label: 'Brightness',
            align: Alignment.centerLeft,
            kind: PlayerDragKind.brightness,
          ),
        ),
      ),
      surfaceSize: const Size(80, 540),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'player_side_rail_left_brightness');
  });
}
