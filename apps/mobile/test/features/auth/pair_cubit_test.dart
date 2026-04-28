import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:fluxora_mobile/features/auth/presentation/cubit/pair_cubit.dart';
import 'package:fluxora_mobile/features/auth/presentation/cubit/pair_state.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepo mockRepo;

  const server = DiscoveredServer(
    name: 'Test Server',
    ip: '192.168.1.10',
    port: 8000,
  );

  setUp(() => mockRepo = _MockAuthRepo());

  // Fast poll interval so timer-based tests don't need multi-second waits.
  PairCubit buildCubit() => PairCubit(
        repository: mockRepo,
        pollInterval: const Duration(milliseconds: 30),
      );

  void stubRequestPair() {
    when(
      () => mockRepo.requestPair(
        clientId: any(named: 'clientId'),
        deviceName: any(named: 'deviceName'),
        platform: any(named: 'platform'),
        appVersion: any(named: 'appVersion'),
      ),
    ).thenAnswer((_) async {});
  }

  group('PairCubit', () {
    test('initial state is PairInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<PairInitial>());
      cubit.close();
    });

    blocTest<PairCubit, PairState>(
      'emits [Requesting, Pending] after successful requestPair',
      build: () {
        stubRequestPair();
        when(() => mockRepo.pollStatus(any()))
            .thenAnswer((_) async => null);
        return buildCubit();
      },
      act: (cubit) => cubit.startPairing(server),
      expect: () => [isA<PairRequesting>(), isA<PairPending>()],
      wait: const Duration(milliseconds: 100),
    );

    blocTest<PairCubit, PairState>(
      'emits [Requesting, Error] when requestPair throws',
      build: () {
        when(
          () => mockRepo.requestPair(
            clientId: any(named: 'clientId'),
            deviceName: any(named: 'deviceName'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          ),
        ).thenThrow(Exception('network error'));
        return buildCubit();
      },
      act: (cubit) => cubit.startPairing(server),
      expect: () => [isA<PairRequesting>(), isA<PairError>()],
    );

    blocTest<PairCubit, PairState>(
      'emits [Requesting, Pending, Approved] when poll returns a token',
      build: () {
        stubRequestPair();
        when(() => mockRepo.pollStatus(any()))
            .thenAnswer((_) async => 'tok-abc123');
        when(
          () => mockRepo.saveCredentials(
            serverUrl: any(named: 'serverUrl'),
            authToken: any(named: 'authToken'),
            clientId: any(named: 'clientId'),
          ),
        ).thenAnswer((_) async {});
        return buildCubit();
      },
      act: (cubit) => cubit.startPairing(server),
      expect: () => [
        isA<PairRequesting>(),
        isA<PairPending>(),
        isA<PairApproved>(),
      ],
      wait: const Duration(milliseconds: 200),
    );

    blocTest<PairCubit, PairState>(
      'emits PairRejected when poll throws PairRejectedException',
      build: () {
        stubRequestPair();
        when(() => mockRepo.pollStatus(any()))
            .thenThrow(const PairRejectedException());
        return buildCubit();
      },
      act: (cubit) => cubit.startPairing(server),
      expect: () => [
        isA<PairRequesting>(),
        isA<PairPending>(),
        isA<PairRejected>(),
      ],
      wait: const Duration(milliseconds: 200),
    );
  });
}
