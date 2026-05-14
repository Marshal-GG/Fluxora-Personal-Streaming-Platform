// Update goldens with:
//   flutter test --tags=golden --update-goldens test/goldens/app_bar_golden_test.dart

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

  testGoldens('FluxAppBar — title + back affordance', (tester) async {
    await tester.pumpWidgetBuilder(
      Material(
        color: const Color(0xFF08061A),
        child: Scaffold(
          backgroundColor: const Color(0xFF08061A),
          appBar: FluxAppBar(
            title: 'Library',
            onBack: () {},
            trailing: const [
              Icon(Icons.search, color: Colors.white),
            ],
          ),
        ),
      ),
      surfaceSize: const Size(412, 80),
    );

    // BackdropFilter blur stabilises after one frame; 300 ms is plenty.
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'flux_app_bar');
  });
}
