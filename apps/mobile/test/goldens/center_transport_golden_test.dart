// Update goldens with:
//   flutter test --tags=golden --update-goldens test/goldens/center_transport_golden_test.dart

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

  testGoldens('PlayerCenterTransport — paused, ready to play', (tester) async {
    await tester.pumpWidgetBuilder(
      const ColoredBox(
        color: Color(0x99000000),
        child: Center(
          child: PlayerCenterTransport(
            isPlaying: false,
            onRewind: _noop,
            onPlayPause: _noop,
            onForward: _noop,
          ),
        ),
      ),
      surfaceSize: const Size(412, 140),
    );

    // Drain the 50 ms press-scale animation + autofocus ring settle.
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'player_center_transport_paused');
  });
}

void _noop() {}
