import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/entities/fallback_event.dart';

import 'package:fluxora_desktop/features/transcoding/presentation/cubit/fallback_history_cubit.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/widgets/fallback_history_panel.dart';

class _StubCubit extends Cubit<FallbackHistoryState>
    implements FallbackHistoryCubit {
  _StubCubit(super.initial);
  @override
  void start() {}
  @override
  void stop() {}
  @override
  Future<void> refresh() async {}
}

Widget _wrap(FallbackHistoryState state) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<FallbackHistoryCubit>.value(
        value: _StubCubit(state),
        child: const FallbackHistoryPanel(),
      ),
    ),
  );
}

const _evtConfigured = FallbackEvent(
  timestamp: '2026-05-04T10:30:00Z',
  sessionId: 's1',
  requestedEncoder: 'h264_nvenc',
  actualEncoder: 'h264_nvenc',
  reason: 'configured',
);

const _evtCapHit = FallbackEvent(
  timestamp: '2026-05-04T10:31:15Z',
  sessionId: 's2',
  requestedEncoder: 'h264_nvenc',
  actualEncoder: 'h264_qsv',
  reason: 'gpu_session_cap_hit',
);

const _evtSaturated = FallbackEvent(
  timestamp: '2026-05-04T10:32:30Z',
  sessionId: 's3',
  requestedEncoder: 'h264_nvenc',
  actualEncoder: 'libx264',
  reason: 'all_encoders_saturated',
);

void main() {
  group('FallbackHistoryPanel', () {
    testWidgets('renders nothing while loading', (tester) async {
      await tester.pumpWidget(_wrap(const FallbackHistoryLoading()));
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders nothing on failure (silent)', (tester) async {
      await tester.pumpWidget(_wrap(const FallbackHistoryFailure('boom')));
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('renders nothing when history is empty', (tester) async {
      await tester.pumpWidget(_wrap(const FallbackHistoryLoaded([])));
      expect(find.text('Recent encoder fallbacks'), findsNothing);
    });

    testWidgets('renders header + one row per recent event', (tester) async {
      await tester.pumpWidget(_wrap(const FallbackHistoryLoaded(
        [_evtConfigured, _evtCapHit, _evtSaturated],
      )));
      expect(find.text('Recent encoder fallbacks'), findsOneWidget);
      // Reason chips.
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cap hit'), findsOneWidget);
      expect(find.text('All saturated'), findsOneWidget);
    });

    testWidgets('cap-hit row renders requested → actual arrow',
        (tester) async {
      await tester.pumpWidget(_wrap(const FallbackHistoryLoaded([_evtCapHit])));
      // The arrow + actual encoder are rendered as a RichText TextSpan.
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('caps display at 5 most recent events', (tester) async {
      final events = List.generate(
        10,
        (i) => FallbackEvent(
          timestamp: '2026-05-04T10:${30 + i}:00Z',
          sessionId: 's$i',
          requestedEncoder: 'h264_nvenc',
          actualEncoder: 'libx264',
          reason: 'gpu_session_cap_hit',
        ),
      );
      await tester.pumpWidget(_wrap(FallbackHistoryLoaded(events)));
      // Only 5 "Cap hit" chips render (the remaining 5 are dropped).
      expect(find.text('Cap hit'), findsNWidgets(5));
    });
  });
}
