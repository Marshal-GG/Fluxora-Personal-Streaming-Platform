import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/player/domain/entities/stream_start_response.dart';
import 'package:fluxora_mobile/features/player/domain/repositories/player_repository.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';

class MockPlayerRepository extends Mock implements PlayerRepository {}

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late MockPlayerRepository repository;
  late MockSecureStorage secureStorage;

  const tFileId = 'file-123';
  const tFileName = 'Inception.mkv';
  const tSessionId = 'session-abc';
  const tPlaylistUrl =
      'http://192.168.1.1:8080/api/v1/hls/session-abc/playlist.m3u8';
  const tToken = 'tok_test';

  const tResponse = StreamStartResponse(
    sessionId: tSessionId,
    fileId: tFileId,
    playlistUrl: tPlaylistUrl,
  );

  setUp(() {
    repository = MockPlayerRepository();
    secureStorage = MockSecureStorage();
    when(() => secureStorage.getAuthToken()).thenAnswer((_) async => tToken);
    // Default stub — stopStream must never throw during cubit.close()
    when(() => repository.stopStream(any())).thenAnswer((_) async {});
  });

  PlayerCubit buildCubit() => PlayerCubit(
        repository: repository,
        secureStorage: secureStorage,
      );

  group('PlayerCubit', () {
    test('initial state is PlayerInitial', () {
      expect(buildCubit().state, isA<PlayerInitial>());
    });

    // NOTE: PlayerReady requires native media_kit libs — cannot be tested in
    // a headless unit-test environment. We verify repository calls instead.
    test('startStream calls repository.startStream with correct fileId',
        () async {
      when(() => repository.startStream(tFileId))
          .thenAnswer((_) async => tResponse);

      final cubit = buildCubit();
      // await so the async body fully completes (errors are caught internally)
      await cubit.startStream(tFileId, tFileName);

      verify(() => repository.startStream(tFileId)).called(1);
      await cubit.close();
    });

    test('startStream emits PlayerLoading as first state', () async {
      when(() => repository.startStream(tFileId))
          .thenAnswer((_) async => tResponse);

      final cubit = buildCubit();
      final states = <PlayerState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.startStream(tFileId, tFileName);

      expect(states.first, isA<PlayerLoading>());
      await sub.cancel();
      await cubit.close();
    });

    blocTest<PlayerCubit, PlayerState>(
      'startStream emits [Loading, Failure] on ApiException',
      setUp: () {
        when(() => repository.startStream(tFileId)).thenThrow(
          const ApiException(message: 'Server error', statusCode: 503),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.startStream(tFileId, tFileName),
      expect: () => [
        isA<PlayerLoading>(),
        isA<PlayerFailure>(),
      ],
    );

    blocTest<PlayerCubit, PlayerState>(
      'startStream emits [Loading, Failure] on unknown error',
      setUp: () {
        when(() => repository.startStream(tFileId))
            .thenThrow(Exception('network failure'));
      },
      build: buildCubit,
      act: (cubit) => cubit.startStream(tFileId, tFileName),
      expect: () => [
        isA<PlayerLoading>(),
        isA<PlayerFailure>(),
      ],
    );

    test('close calls stopStream when session was set by startStream',
        () async {
      when(() => repository.startStream(tFileId))
          .thenAnswer((_) async => tResponse);

      final cubit = buildCubit();
      // _sessionId is set before Player() — even if Player init fails the
      // server session exists and must be cleaned up on close
      await cubit.startStream(tFileId, tFileName);
      await cubit.close();

      verify(() => repository.stopStream(tSessionId)).called(1);
    });

    test('close does not call stopStream when stream never started', () async {
      final cubit = buildCubit();
      await cubit.close();

      verifyNever(() => repository.stopStream(any()));
    });
  });
}
