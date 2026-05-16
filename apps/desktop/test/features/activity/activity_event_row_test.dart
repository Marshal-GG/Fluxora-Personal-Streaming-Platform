import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/entities/activity_event.dart';
import 'package:fluxora_desktop/features/activity/presentation/screens/activity_screen.dart';

ActivityEvent _evt(String id) => ActivityEvent(
      id: id,
      type: 'stream.start',
      summary: 'Test event $id',
      createdAt: '2026-05-15T12:00:00Z',
    );

/// Pumps a single [ActivityEventRow] inside a scrollable + Material harness so
/// `Scrollable.ensureVisible` has an ancestor to walk up to.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

/// Walks down from the [ActivityEventRow] to the inner `AnimatedBuilder` and
/// returns the colour the row's tint container is currently painting.
Color? _currentFlashColor(WidgetTester tester) {
  // The AnimatedBuilder rebuilds a Container with the tinted colour every
  // frame.  We grab the Container directly under the AnimatedBuilder — the
  // inner Row + child icon containers don't carry the flash decoration.
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(AnimatedBuilder),
          matching: find.byType(Container),
        )
        .first,
  );
  final decoration = container.decoration as BoxDecoration;
  return decoration.color;
}

void main() {
  group('ActivityEventRow flash animation', () {
    testWidgets('renders transparent when highlighted is false', (tester) async {
      await tester.pumpWidget(_wrap(
        ActivityEventRow(event: _evt('a'), isLast: true),
      ));

      // Initial controller value is 1.0 → end of tween → transparent.
      final color = _currentFlashColor(tester);
      expect(color, isNotNull);
      expect(color!.a, 0.0, reason: 'Non-highlighted row must render with no tint.');
    });

    testWidgets('renders violet tint when highlighted is true', (tester) async {
      await tester.pumpWidget(_wrap(
        ActivityEventRow(
          event: _evt('a'),
          isLast: true,
          highlighted: true,
        ),
      ));
      // Two zero-duration pumps: first runs the post-frame callback that
      // fires `forward(from: 0)`; second renders the AnimatedBuilder with
      // the new controller value.  Comparing RGB exactly is too tight (the
      // ticker advances slightly within the frame) — instead assert the
      // tint is *visible* (non-zero alpha) and skewed toward violet (blue
      // ≥ green, matching #A855F7).
      await tester.pump();
      await tester.pump();

      final color = _currentFlashColor(tester);
      expect(color, isNotNull);
      expect(color!.a, greaterThan(0.0),
          reason: 'Flash should be visible immediately after fire.');
      expect(color.b, greaterThanOrEqualTo(color.g),
          reason: 'Tint should be violet (blue ≥ green channel).');
    });

    testWidgets('flash fades to transparent within 1500ms', (tester) async {
      await tester.pumpWidget(_wrap(
        ActivityEventRow(
          event: _evt('a'),
          isLast: true,
          highlighted: true,
        ),
      ));
      // Wait past the 1500ms duration.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      final color = _currentFlashColor(tester);
      expect(color, isNotNull);
      expect(color!.a, 0.0,
          reason: 'Flash must complete and leave row fully transparent.');
    });

    testWidgets('re-fires when highlighted flips false → true', (tester) async {
      await tester.pumpWidget(_wrap(
        ActivityEventRow(event: _evt('a'), isLast: true),
      ));
      // Initially transparent.
      expect(_currentFlashColor(tester)!.a, 0.0);

      // Flip highlighted to true via rebuild.
      await tester.pumpWidget(_wrap(
        ActivityEventRow(
          event: _evt('a'),
          isLast: true,
          highlighted: true,
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Now visible.
      expect(_currentFlashColor(tester)!.a, greaterThan(0.0));
    });
  });
}
