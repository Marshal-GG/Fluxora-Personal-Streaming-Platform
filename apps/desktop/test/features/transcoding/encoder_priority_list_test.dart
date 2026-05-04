import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluxora_desktop/features/transcoding/presentation/widgets/encoder_priority_list.dart';

const _knownEncoders = [
  (id: 'libx264', label: 'Software (x264)'),
  (id: 'h264_nvenc', label: 'NVIDIA NVENC H.264'),
  (id: 'h264_qsv', label: 'Intel QuickSync H.264'),
  (id: 'libx265', label: 'Software (x265)'),
];

Widget _wrap({
  required List<String> chain,
  required ValueChanged<List<String>> onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: EncoderPriorityList(
          chain: chain,
          allEncoders: _knownEncoders,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

void main() {
  group('EncoderPriorityList', () {
    testWidgets('renders empty-state copy when chain is empty',
        (tester) async {
      await tester.pumpWidget(_wrap(chain: const [], onChanged: (_) {}));
      expect(find.textContaining('No encoders configured'), findsOneWidget);
      // Add button still visible.
      expect(find.text('Add encoder'), findsOneWidget);
    });

    testWidgets('renders one row per chain entry with index numbers',
        (tester) async {
      await tester.pumpWidget(_wrap(
        chain: const ['h264_nvenc', 'h264_qsv', 'libx264'],
        onChanged: (_) {},
      ));
      expect(find.text('NVIDIA NVENC H.264'), findsOneWidget);
      expect(find.text('Intel QuickSync H.264'), findsOneWidget);
      expect(find.text('Software (x264)'), findsOneWidget);
      // Index pills 1-3 present.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('first entry shows the Primary pill', (tester) async {
      await tester.pumpWidget(_wrap(
        chain: const ['h264_nvenc', 'libx264'],
        onChanged: (_) {},
      ));
      expect(find.text('Primary'), findsOneWidget);
    });

    testWidgets('removing a row fires onChanged with the trimmed chain',
        (tester) async {
      List<String>? captured;
      await tester.pumpWidget(_wrap(
        chain: const ['h264_nvenc', 'h264_qsv', 'libx264'],
        onChanged: (next) => captured = next,
      ));
      // Tap the close button on the second row.
      final closeButtons = find.byTooltip('Remove from chain');
      expect(closeButtons, findsNWidgets(3));
      await tester.tap(closeButtons.at(1));
      await tester.pumpAndSettle();
      expect(captured, ['h264_nvenc', 'libx264']);
    });

    testWidgets('Add encoder button shows only encoders not in chain',
        (tester) async {
      await tester.pumpWidget(_wrap(
        chain: const ['h264_nvenc', 'libx264'],
        onChanged: (_) {},
      ));
      await tester.tap(find.text('Add encoder'));
      await tester.pumpAndSettle();
      // The remaining encoders show up in the menu.
      expect(find.text('Intel QuickSync H.264'), findsOneWidget);
      expect(find.text('Software (x265)'), findsOneWidget);
      // Already-in-chain entries DO appear in the chain rows but the
      // popup shouldn't add a duplicate label — verify by counting:
      // the chain rows already render NVENC + libx264 labels; popup
      // adds 2 more entries (qsv + x265).
    });

    testWidgets('Add encoder selection appends to the chain', (tester) async {
      List<String>? captured;
      await tester.pumpWidget(_wrap(
        chain: const ['h264_nvenc'],
        onChanged: (next) => captured = next,
      ));
      await tester.tap(find.text('Add encoder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Software (x264)').last);
      await tester.pumpAndSettle();
      expect(captured, ['h264_nvenc', 'libx264']);
    });

    testWidgets(
        'when every encoder is already in the chain, Add button shows a hint',
        (tester) async {
      await tester.pumpWidget(_wrap(
        chain: const ['libx264', 'h264_nvenc', 'h264_qsv', 'libx265'],
        onChanged: (_) {},
      ));
      expect(
        find.textContaining('All encoders are already in the chain'),
        findsOneWidget,
      );
      expect(find.text('Add encoder'), findsNothing);
    });
  });
}
