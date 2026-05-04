import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/entities/encoder_advice.dart';
import 'package:fluxora_core/entities/transcoding_status.dart';

import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_cubit.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_state.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/widgets/encoder_status_panel.dart';

EncoderLoad _load(
  String id, {
  bool? testPassed,
  String? error,
  String? engine,
  int sessions = 0,
}) {
  return EncoderLoad(
    encoder: id,
    activeSessions: sessions,
    encoderTestPassed: testPassed,
    encoderTestError: error,
    encoderTestedAt: testPassed != null ? '2026-05-04T12:00:00Z' : null,
    gpuEngine: engine,
  );
}

TranscodingStatus _status({
  String active = 'libx264',
  List<String> available = const ['libx264', 'h264_nvenc'],
  List<EncoderLoad>? loads,
}) {
  return TranscodingStatus(
    activeEncoder: active,
    availableEncoders: available,
    encoderLoads: loads ?? const [],
    activeSessions: const [],
  );
}

const _knownEncoders = [
  (id: 'libx264', label: 'Software (x264)'),
  (id: 'h264_nvenc', label: 'NVIDIA NVENC H.264'),
  (id: 'h264_qsv', label: 'Intel QuickSync H.264'),
];

Widget _wrap(Widget child, TranscodingState state) {
  // Direct BlocProvider.value with a constant cubit-shaped stand-in:
  // we can't construct a real Cubit without a repo, so we wrap a
  // singleton stub Bloc that emits the given state.
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<TranscodingCubit>.value(
        value: _StubCubit(state),
        child: child,
      ),
    ),
  );
}

/// Minimal cubit stand-in that emits a fixed state.  Used so widgets can
/// be built in isolation without spinning up a real polling cubit.
class _StubCubit extends Cubit<TranscodingState> implements TranscodingCubit {
  _StubCubit(super.initial);
  @override
  void start() {}
  @override
  void stop() {}
  @override
  Future<void> refresh() async {}
}

void main() {
  group('EncoderStatusPanel', () {
    testWidgets('renders one row per known encoder with Available pill for tested',
        (tester) async {
      final state = TranscodingLoaded(
        _status(
          available: ['libx264', 'h264_nvenc'],
          loads: [
            _load('libx264', testPassed: true),
            _load('h264_nvenc', testPassed: true),
          ],
        ),
      );
      await tester.pumpWidget(_wrap(
        const EncoderStatusPanel(
          knownEncoders: _knownEncoders,
          activeEncoder: 'libx264',
        ),
        state,
      ));

      expect(find.text('Software (x264)'), findsOneWidget);
      expect(find.text('NVIDIA NVENC H.264'), findsOneWidget);
      // h264_qsv isn't in available → "Not detected" → hidden by default
      expect(find.text('Intel QuickSync H.264'), findsNothing);
      // The "Show 1 unsupported encoder" toggle should appear instead.
      expect(find.textContaining('unsupported'), findsOneWidget);
    });

    testWidgets('Failed encoder gets Failed pill + error tooltip',
        (tester) async {
      final state = TranscodingLoaded(
        _status(
          available: ['libx264', 'h264_nvenc'],
          loads: [
            _load('libx264', testPassed: true),
            _load('h264_nvenc',
                testPassed: false, error: 'driver missing'),
          ],
        ),
      );
      await tester.pumpWidget(_wrap(
        const EncoderStatusPanel(
          knownEncoders: _knownEncoders,
          activeEncoder: 'libx264',
        ),
        state,
      ));

      expect(find.text('Failed'), findsOneWidget);
      // Tooltip carries the FFmpeg stderr.
      expect(
        find.byTooltip('Self-test failed: driver missing'),
        findsOneWidget,
      );
    });

    testWidgets('Recommended encoder is sorted to the top with purple pill',
        (tester) async {
      final state = TranscodingLoaded(
        _status(
          available: ['libx264', 'h264_nvenc'],
          loads: [
            _load('libx264', testPassed: true),
            _load('h264_nvenc', testPassed: true),
          ],
        ),
        advice: const EncoderAdvice(
          recommendedEncoder: 'h264_nvenc',
          reasonCode: 'cpu_fallback',
          reasonText: 'Switch to GPU',
          severity: 'info',
        ),
      );
      await tester.pumpWidget(_wrap(
        const EncoderStatusPanel(
          knownEncoders: _knownEncoders,
          activeEncoder: 'libx264',
        ),
        state,
      ));

      expect(find.text('Recommended'), findsOneWidget);
      // First visible encoder name in the column should be the recommended one.
      final encoderTexts = tester
          .widgetList<Text>(find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data == 'NVIDIA NVENC H.264' ||
                    w.data == 'Software (x264)'),
          ))
          .map((t) => t.data)
          .toList();
      expect(encoderTexts.first, 'NVIDIA NVENC H.264');
    });
  });

  group('EncoderRecommendationBanner', () {
    testWidgets('renders nothing when reasonCode is none', (tester) async {
      final state = TranscodingLoaded(
        _status(),
        advice: const EncoderAdvice(
          reasonCode: 'none',
          reasonText: '',
          severity: 'none',
        ),
      );
      await tester.pumpWidget(_wrap(
        const EncoderRecommendationBanner(),
        state,
      ));

      // No pill, no text, no icon — banner collapsed.
      expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('renders info banner with action button on cpu_fallback',
        (tester) async {
      String? capturedSwitch;
      final state = TranscodingLoaded(
        _status(),
        advice: const EncoderAdvice(
          recommendedEncoder: 'h264_nvenc',
          reasonCode: 'cpu_fallback',
          reasonText: 'You are on CPU. Switch to NVENC.',
          severity: 'info',
        ),
      );
      await tester.pumpWidget(_wrap(
        EncoderRecommendationBanner(
          onApplyRecommendation: (id) => capturedSwitch = id,
        ),
        state,
      ));

      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
      expect(find.text('You are on CPU. Switch to NVENC.'), findsOneWidget);

      await tester.tap(find.text('Switch to h264_nvenc'));
      expect(capturedSwitch, 'h264_nvenc');
    });

    testWidgets('renders warning banner on failed_active severity',
        (tester) async {
      final state = TranscodingLoaded(
        _status(),
        advice: const EncoderAdvice(
          recommendedEncoder: 'libx264',
          reasonCode: 'failed_active',
          reasonText: 'NVENC failed. Switch to CPU.',
          severity: 'warning',
        ),
      );
      await tester.pumpWidget(_wrap(
        const EncoderRecommendationBanner(
          onApplyRecommendation: _noop,
        ),
        state,
      ));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('ActiveEncoderStrip', () {
    testWidgets('renders CPU pill for software encoder', (tester) async {
      final state = TranscodingLoaded(
        _status(
          active: 'libx264',
          loads: [_load('libx264', testPassed: true)],
        ),
      );
      await tester.pumpWidget(_wrap(const ActiveEncoderStrip(), state));

      expect(find.text('CPU'), findsOneWidget);
      expect(find.byIcon(Icons.memory_outlined), findsOneWidget);
    });

    testWidgets('renders GPU pill + cuda label for h264_nvenc active',
        (tester) async {
      final state = TranscodingLoaded(
        _status(
          active: 'h264_nvenc',
          available: ['libx264', 'h264_nvenc'],
          loads: [
            _load('h264_nvenc',
                testPassed: true, engine: 'cuda', sessions: 2),
          ],
        ),
      );
      await tester.pumpWidget(_wrap(const ActiveEncoderStrip(), state));

      expect(find.text('GPU'), findsOneWidget);
      expect(find.byIcon(Icons.developer_board_outlined), findsOneWidget);
      // Summary text mentions the engine + session count.
      expect(find.textContaining('cuda'), findsOneWidget);
      expect(find.textContaining('2 streams active'), findsOneWidget);
    });

    testWidgets('renders nothing when state is not Loaded', (tester) async {
      await tester.pumpWidget(_wrap(
        const ActiveEncoderStrip(),
        const TranscodingLoading(),
      ));
      expect(find.byType(Row), findsNothing);
    });
  });
}

void _noop(String _) {}
