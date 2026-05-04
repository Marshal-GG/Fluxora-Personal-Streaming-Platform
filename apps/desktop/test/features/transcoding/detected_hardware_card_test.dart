import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/entities/hardware_devices.dart';

import 'package:fluxora_desktop/features/transcoding/presentation/cubit/hardware_cubit.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/widgets/detected_hardware_card.dart';

class _StubCubit extends Cubit<HardwareState> implements HardwareCubit {
  _StubCubit(super.initial);
  @override
  Future<void> load() async {}
  @override
  Future<void> refresh() async {}
}

Widget _wrap(HardwareState state) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<HardwareCubit>.value(
        value: _StubCubit(state),
        child: const DetectedHardwareCard(),
      ),
    ),
  );
}

const _nvidia = GpuInfo(
  vendor: 'nvidia',
  model: 'GeForce RTX 4070',
  vramMb: 12288,
  driverVersion: '535.171.04',
  encoderSupport: ['h264_nvenc', 'hevc_nvenc'],
);

const _intel = GpuInfo(
  vendor: 'intel',
  model: 'UHD Graphics 770',
  vramMb: 1024,
  driverVersion: '31.0.101.4502',
  encoderSupport: ['h264_qsv', 'hevc_qsv'],
);

const _cpu = CpuInfo(
  vendor: 'Intel',
  model: 'Core i7-9750H @ 2.60GHz',
  threads: 12,
);

void main() {
  group('DetectedHardwareCard', () {
    testWidgets('shows spinner when loading', (tester) async {
      await tester.pumpWidget(_wrap(const HardwareLoading()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows failure message on HardwareFailure', (tester) async {
      await tester.pumpWidget(_wrap(const HardwareFailure('boom')));
      expect(find.textContaining('Hardware probe failed'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('shows empty-state when probe returned no devices',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const HardwareLoaded(HardwareDevices())),
      );
      expect(find.textContaining('No CPU or GPU detected'), findsOneWidget);
    });

    testWidgets('renders CPU + GPU tiles with vendor pills', (tester) async {
      await tester.pumpWidget(_wrap(const HardwareLoaded(HardwareDevices(
        cpus: [_cpu],
        gpus: [_nvidia, _intel],
      ))));

      // CPU detail line includes thread count.
      expect(find.textContaining('Core i7-9750H'), findsOneWidget);
      expect(find.textContaining('12 threads'), findsOneWidget);
      // GPU model rows.
      expect(find.text('GeForce RTX 4070'), findsOneWidget);
      expect(find.text('UHD Graphics 770'), findsOneWidget);
      // Vendor pills.
      expect(find.text('NVIDIA'), findsOneWidget);
      expect(find.text('Intel'), findsAtLeastNWidgets(1));
      // VRAM + driver detail line.
      expect(find.textContaining('12 GB'), findsOneWidget);
      expect(find.textContaining('driver 535.171.04'), findsOneWidget);
    });

    testWidgets('encoder-support badges render for each GPU', (tester) async {
      await tester.pumpWidget(_wrap(const HardwareLoaded(HardwareDevices(
        gpus: [_nvidia],
      ))));

      expect(find.text('h264_nvenc'), findsOneWidget);
      expect(find.text('hevc_nvenc'), findsOneWidget);
    });

    testWidgets('formats VRAM under 1 GB as MB', (tester) async {
      await tester.pumpWidget(_wrap(const HardwareLoaded(HardwareDevices(
        gpus: [
          GpuInfo(vendor: 'intel', model: 'Old iGPU', vramMb: 512),
        ],
      ))));
      expect(find.textContaining('512 MB'), findsOneWidget);
    });

    testWidgets('Re-detect button is rendered when state is Loaded',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const HardwareLoaded(HardwareDevices(cpus: [_cpu]))),
      );
      expect(find.byTooltip('Re-detect'), findsOneWidget);
    });

    testWidgets('Re-detect button is hidden during initial load',
        (tester) async {
      await tester.pumpWidget(_wrap(const HardwareInitial()));
      expect(find.byTooltip('Re-detect'), findsNothing);
    });
  });
}
