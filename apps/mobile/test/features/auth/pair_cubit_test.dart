import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:fluxora_mobile/features/auth/presentation/cubit/pair_cubit.dart';
import 'package:fluxora_mobile/features/auth/presentation/cubit/pair_state.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late _MockAuthRepo mockRepo;
  late _MockSecureStorage mockStorage;

  const server = DiscoveredServer(
    name: 'Test Server',
    ip: '192.168.1.10',
    port: 8000,
  );

  setUp(() {
    mockRepo = _MockAuthRepo();
    mockStorage = _MockSecureStorage();
  });

  // Fast poll interval so timer-based tests don't need multi-second waits.
  PairCubit buildCubit() => PairCubit(
        repository: mockRepo,
        secureStorage: mockStorage,
        pollInterval: const Duration(milliseconds: 30),
      );

  void stubRequestPair() {
    when(
      () => mockRepo.requestPair(
        clientId: any(named: 'clientId'),
        deviceName: any(named: 'deviceName'),
        platform: any(named: 'platform'),
        appVersion: any(named: 'appVersion'),
        email: any(named: 'email'),
      ),
    ).thenAnswer((_) async {});
  }

  /// Helper that drives the new two-step entry: prepare → submitEmail.
  /// Returns a `Future` so tests can await the kick-off.
  Future<void> drivePair(PairCubit cubit, {String? email}) async {
    cubit.prepare(server);
    await cubit.submitEmail(server: server, email: email);
  }

  group('PairCubit — initial-pair flow', () {
    test('initial state is PairInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<PairInitial>());
      cubit.close();
    });

    test('prepare() emits PairCollectEmail with the server', () {
      final cubit = buildCubit();
      cubit.prepare(server);
      expect(cubit.state, isA<PairCollectEmail>());
      expect((cubit.state as PairCollectEmail).server, server);
      cubit.close();
    });

    blocTest<PairCubit, PairState>(
      'emits [CollectEmail, Requesting, Pending] after successful submitEmail',
      build: () {
        stubRequestPair();
        when(() => mockRepo.pollStatus(any()))
            .thenAnswer((_) async => null);
        return buildCubit();
      },
      act: (cubit) => drivePair(cubit),
      expect: () => [
        isA<PairCollectEmail>(),
        isA<PairRequesting>(),
        isA<PairPending>(),
      ],
      wait: const Duration(milliseconds: 100),
    );

    blocTest<PairCubit, PairState>(
      'forwards optional email to requestPair',
      build: () {
        stubRequestPair();
        when(() => mockRepo.pollStatus(any()))
            .thenAnswer((_) async => null);
        return buildCubit();
      },
      act: (cubit) => drivePair(cubit, email: 'alex@fluxora.io'),
      verify: (_) {
        verify(
          () => mockRepo.requestPair(
            clientId: any(named: 'clientId'),
            deviceName: any(named: 'deviceName'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
            email: 'alex@fluxora.io',
          ),
        ).called(1);
      },
      wait: const Duration(milliseconds: 100),
    );

    blocTest<PairCubit, PairState>(
      'emits [CollectEmail, Requesting, Error] when requestPair throws',
      build: () {
        when(
          () => mockRepo.requestPair(
            clientId: any(named: 'clientId'),
            deviceName: any(named: 'deviceName'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
            email: any(named: 'email'),
          ),
        ).thenThrow(Exception('network error'));
        return buildCubit();
      },
      act: (cubit) => drivePair(cubit),
      expect: () => [
        isA<PairCollectEmail>(),
        isA<PairRequesting>(),
        isA<PairError>(),
      ],
    );

    blocTest<PairCubit, PairState>(
      'reaches PairApproved when poll returns a token',
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
      act: (cubit) => drivePair(cubit),
      expect: () => [
        isA<PairCollectEmail>(),
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
      act: (cubit) => drivePair(cubit),
      expect: () => [
        isA<PairCollectEmail>(),
        isA<PairRequesting>(),
        isA<PairPending>(),
        isA<PairRejected>(),
      ],
      wait: const Duration(milliseconds: 200),
    );
  });

  group('PairCubit — reconnect flow', () {
    blocTest<PairCubit, PairState>(
      'reconnect with saved credentials reaches PairPending',
      build: () {
        when(() => mockStorage.getServerUrl())
            .thenAnswer((_) async => 'http://192.168.1.10:8000');
        when(() => mockStorage.getClientId())
            .thenAnswer((_) async => 'persisted-client-id');
        stubRequestPair();
        when(() => mockRepo.pollStatus(any()))
            .thenAnswer((_) async => null);
        return buildCubit();
      },
      act: (cubit) => cubit.reconnect(),
      expect: () => [
        isA<PairRequesting>(),
        isA<PairPending>(),
      ],
      verify: (_) {
        // Re-pair must use the *saved* client_id, not a freshly-generated
        // one — that's how the server links the new approval to the
        // previously-trusted device row.
        verify(
          () => mockRepo.requestPair(
            clientId: 'persisted-client-id',
            deviceName: any(named: 'deviceName'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
            email: null,
          ),
        ).called(1);
      },
      wait: const Duration(milliseconds: 100),
    );

    blocTest<PairCubit, PairState>(
      'reconnect emits PairError when secure storage is empty',
      build: () {
        when(() => mockStorage.getServerUrl()).thenAnswer((_) async => null);
        when(() => mockStorage.getClientId()).thenAnswer((_) async => null);
        return buildCubit();
      },
      act: (cubit) => cubit.reconnect(),
      expect: () => [
        isA<PairRequesting>(),
        isA<PairError>(),
      ],
    );
  });
}
