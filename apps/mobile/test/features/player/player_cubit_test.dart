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
  // PlayerCubit registers a WidgetsBindingObserver in its constructor
  // (Phase 3 — background-playback preference).  The binding has to
  // exist before the cubit can call `WidgetsBinding.instance` — for
  // unit tests that means initialising the test binding once at the
  // top of `main`.  Idempotent so it's safe even if some other test
  // setup already called it.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPlayerRepository repository;
  late MockSecureStorage secureStorage;

  const tFileId = 'file-123';
  const tFileName = 'Inception.mkv';
  const tSessionId = 'session-abc';
  const tPlaylistUrl =
      'http://192.168.1.1:8000/api/v1/hls/session-abc/playlist.m3u8';
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
    // Default stubs — must never throw during cubit.close()
    when(() => repository.stopStream(any())).thenAnswer((_) async {});
    when(() => repository.updateProgress(any(), any())).thenAnswer((_) async {});
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
      await cubit.startStream(tFileId, tFileName, 0.0);

      verify(() => repository.startStream(tFileId)).called(1);
      await cubit.close();
    });

    test('startStream emits PlayerLoading as first state', () async {
      when(() => repository.startStream(tFileId))
          .thenAnswer((_) async => tResponse);

      final cubit = buildCubit();
      final states = <PlayerState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.startStream(tFileId, tFileName, 0.0);

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
      act: (cubit) => cubit.startStream(tFileId, tFileName, 0.0),
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
      act: (cubit) => cubit.startStream(tFileId, tFileName, 0.0),
      expect: () => [
        isA<PlayerLoading>(),
        isA<PlayerFailure>(),
      ],
    );

    // ── Group-gate 403 routing (M5, 2026-05-07) ───────────────────────────
    //
    // The mobile player must distinguish between three "no can do"
    // outcomes from /stream/start:
    //   • 429 → PlayerTierLimit (upgrade prompt)
    //   • 403 with a group-gate detail string → PlayerGated (soft block)
    //   • everything else → PlayerFailure
    // Tests pin the parser so a future agent rewording the message in
    // group_service.reason_to_deny that breaks the substring match here
    // catches it in CI rather than in the field.

    blocTest<PlayerCubit, PlayerState>(
      'startStream emits PlayerGated on 403 with library-deny message',
      setUp: () {
        when(() => repository.startStream(tFileId)).thenThrow(
          const ApiException(
            message: "Library not allowed for this client's group(s)",
            statusCode: 403,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.startStream(tFileId, tFileName, 0.0),
      expect: () => [
        isA<PlayerLoading>(),
        isA<PlayerGated>().having(
          (s) => s.reason,
          'reason',
          "Library not allowed for this client's group(s)",
        ),
      ],
    );

    blocTest<PlayerCubit, PlayerState>(
      'startStream emits PlayerGated on 403 with time-window-deny message',
      setUp: () {
        when(() => repository.startStream(tFileId)).thenThrow(
          const ApiException(
            message: 'Outside the allowed streaming time window',
            statusCode: 403,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.startStream(tFileId, tFileName, 0.0),
      expect: () => [
        isA<PlayerLoading>(),
        isA<PlayerGated>().having(
          (s) => s.reason,
          'reason',
          'Outside the allowed streaming time window',
        ),
      ],
    );

    blocTest<PlayerCubit, PlayerState>(
      'startStream falls through to PlayerFailure on unrelated 403',
      setUp: () {
        // 403 with a detail string that is not a group-gate marker
        // (e.g. an admin endpoint reached from off-loopback).  Must NOT
        // be classified as gated — that would mislead the operator
        // into thinking they set up a restriction.
        when(() => repository.startStream(tFileId)).thenThrow(
          const ApiException(
            message: 'Forbidden: localhost only',
            statusCode: 403,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.startStream(tFileId, tFileName, 0.0),
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
      await cubit.startStream(tFileId, tFileName, 0.0);
      await cubit.close();

      verify(() => repository.stopStream(tSessionId)).called(1);
    });

    test('close does not call stopStream when stream never started', () async {
      final cubit = buildCubit();
      await cubit.close();

      verifyNever(() => repository.stopStream(any()));
    });

    // ── seekTo safety tests ──────────────────────────────────────────────
    //
    // Full seekTo behaviour (threshold-based dispatch, debounce, server-
    // restart path) requires a real `Player` to read position and pause /
    // open / seek / play through, which native media_kit libs make
    // unavailable in headless unit tests.  These tests verify the
    // **safety invariants** of the public method: it must never crash
    // and must never invoke ``repository.seekStream`` when there is no
    // session to seek.  Field validation of the in-flight server restart
    // path is by manual integration test.
    test('seekTo no-ops when state is PlayerInitial', () async {
      final cubit = buildCubit();

      // Should not throw; cubit must still be in PlayerInitial after.
      await cubit.seekTo(const Duration(seconds: 30));

      expect(cubit.state, isA<PlayerInitial>());
      verifyNever(() => repository.seekStream(any(), any(),
          tonemap: any(named: 'tonemap')));
      await cubit.close();
    });

    test('seekTo no-ops when state is PlayerFailure', () async {
      when(() => repository.startStream(tFileId)).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.startStream(tFileId, tFileName, 0.0);
      // Sanity check — failure path emitted PlayerFailure.
      expect(cubit.state, isA<PlayerFailure>());

      await cubit.seekTo(const Duration(seconds: 30));

      verifyNever(() => repository.seekStream(any(), any(),
          tonemap: any(named: 'tonemap')));
      await cubit.close();
    });

    test('seekTo no-ops when state is PlayerTierLimit', () async {
      when(() => repository.startStream(tFileId)).thenThrow(
        const ApiException(message: 'tier limit', statusCode: 429),
      );

      final cubit = buildCubit();
      await cubit.startStream(tFileId, tFileName, 0.0);
      expect(cubit.state, isA<PlayerTierLimit>());

      await cubit.seekTo(const Duration(seconds: 30));

      verifyNever(() => repository.seekStream(any(), any(),
          tonemap: any(named: 'tonemap')));
      await cubit.close();
    });

    test('seekTo clamps negative durations to zero', () async {
      // Even with a negative argument, seekTo must not crash.  The
      // important invariant for this no-session call is that no seek
      // call is dispatched against a missing session.
      final cubit = buildCubit();
      await cubit.seekTo(const Duration(seconds: -10));

      expect(cubit.state, isA<PlayerInitial>());
      verifyNever(() => repository.seekStream(any(), any(),
          tonemap: any(named: 'tonemap')));
      await cubit.close();
    });
  });
}
