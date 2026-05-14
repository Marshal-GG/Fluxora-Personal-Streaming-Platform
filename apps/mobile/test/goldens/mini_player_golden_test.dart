// Update goldens with:
//   flutter test --tags=golden --update-goldens test/goldens/mini_player_golden_test.dart

@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:media_kit_video/media_kit_video.dart' show VideoController;
import 'package:mocktail/mocktail.dart';

import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';
import 'package:fluxora_mobile/features/player/domain/repositories/player_repository.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/shared/widgets/flux_mini_player.dart';

import '_player_mocks.dart';

class _MockPlayerRepo extends Mock implements PlayerRepository {}

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockVideoController extends Mock implements VideoController {}

/// Stub cubit so the golden is deterministic — emits a single
/// `PlayerReady` and never touches the network or libmpv.  Subclassing
/// `PlayerCubit` is simpler than mocking it because the mini-player
/// reads via `BlocBuilder` which requires a real `Cubit<T>`.
class _StubPlayerCubit extends PlayerCubit {
  _StubPlayerCubit({
    required super.repository,
    required super.secureStorage,
    required PlayerReady ready,
  }) : _ready = ready;

  final PlayerReady _ready;

  void seed() => emit(_ready);
}

void main() {
  // PlayerCubit registers a WidgetsBindingObserver — the binding has
  // to exist before construction.  Idempotent across files.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  late _StubPlayerCubit cubit;
  late _MockPlayerRepo repo;
  late _MockSecureStorage storage;

  setUp(() async {
    // `GetIt.reset()` is async — if we don't await, the registerSingleton
    // below runs before the previous test's teardown finishes wiping the
    // registry, and the eventual reset clobbers our fresh registration
    // mid-test.  Discovered while bootstrapping the mini-player golden.
    await GetIt.I.reset();

    repo = _MockPlayerRepo();
    storage = _MockSecureStorage();

    // Defensive stubs so cubit.close() doesn't trip on tearDown.
    when(() => repo.stopStream(any())).thenAnswer((_) async {});
    when(() => repo.updateProgress(any(), any())).thenAnswer((_) async {});
    when(() => storage.getAuthToken()).thenAnswer((_) async => 'tok');
    when(() => storage.getWifiOnlyStreaming())
        .thenAnswer((_) async => false);

    final player = buildFakePlayer(
      position: const Duration(minutes: 27),
      duration: const Duration(hours: 1, minutes: 30),
      playing: true,
    );
    final ready = PlayerReady(
      sessionId: 'sess-1',
      fileName: 'Inception',
      player: player,
      controller: _MockVideoController(),
    );

    cubit = _StubPlayerCubit(
      repository: repo,
      secureStorage: storage,
      ready: ready,
    );

    GetIt.I.registerSingleton<PlayerCubit>(cubit);
  });

  tearDown(() async {
    await cubit.close();
    await GetIt.I.reset();
  });

  testGoldens('FluxMiniPlayer — playing state', (tester) async {
    // Mini player calls `context.push(Routes.playerResume)` on tap;
    // provide a router so the InheritedWidget lookup doesn't throw
    // even though the test doesn't exercise navigation.
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Align(
            alignment: Alignment.bottomCenter,
            child: ColoredBox(
              color: Color(0xFF08061A),
              child: FluxMiniPlayer(),
            ),
          ),
        ),
        GoRoute(path: '/resume', builder: (_, __) => const SizedBox()),
      ],
    );

    await tester.pumpWidgetBuilder(
      MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
      surfaceSize: const Size(412, 80),
    );

    cubit.seed();

    // Wait past the AnimatedSize(200ms) mount + the StreamBuilder
    // initial-data settle so the bar is fully laid out.
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    await screenMatchesGolden(tester, 'flux_mini_player_playing');
  });
}
