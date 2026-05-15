/// Widget tests for [PlayerProgressBar] — plan 24 M8.
///
/// The scrubber pin behaviour (`_pendingValue` + `_pinFallbackTimer`)
/// was tuned against libmpv's post-server-restart emit cadence (plan 17
/// §10 fix, 2026-05-09): libmpv briefly emits `oldPlayerPos + newOffset`
/// over `newPlayerDur + newOffset` for one paint after `Player.open`,
/// which clamps the displayed ratio to 1.0 and visually jumps the thumb
/// to the end of the track before settling.
///
/// ExoPlayer's emission shape after `prepare()` differs:
///
///   1. Kotlin emits no immediate position-zero or duration-zero on
///      `stop()` + `clearMediaItems()` — `duration` stays at the
///      previous playlist's value until `STATE_READY`, at which point
///      `onPlaybackStateChanged` fires a `durationChanged` event with
///      the new total.  `position` stays at the prior value too unless
///      the cubit issues a `seek` after `open` (which fires
///      `onPositionDiscontinuity`).
///
///   2. The Dart-side [ExoPlayerEngine.open] resets the cached
///      `_position` + `_duration` to zero and pushes those values onto
///      the streams BEFORE the channel call, so the
///      [PlayerProgressBar] sees `playerDur == 0` during the
///      open→STATE_READY window.  The settle check is gated on
///      `playerDur > 0` to hold the pin through that window — these
///      tests pin the contract.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:fluxora_mobile/features/player/presentation/widgets/flux_player_controls.dart';

/// Stream-driven [PlayerEngine] fake.  Production engines update their
/// cached `position` / `duration` synchronously alongside emitting on
/// the streams; this fake mirrors that contract via [setPosition] /
/// [setDuration] so the M8 transient-sequence tests can pump the same
/// (position, duration, isSeeking) tuples that ExoPlayer would emit
/// during a server-restart and assert the pin holds.
class _StreamableFakeEngine implements PlayerEngine {
  _StreamableFakeEngine({
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
  }) : _position = position,
       _duration = duration;

  Duration _position;
  Duration _duration;

  final StreamController<Duration> _positionCtl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationCtl =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _playingCtl =
      StreamController<bool>.broadcast();
  final StreamController<int?> _audioCtl =
      StreamController<int?>.broadcast();
  final StreamController<EngineErrorEvent> _errorCtl =
      StreamController<EngineErrorEvent>.broadcast();

  void setPosition(Duration value) {
    _position = value;
    _positionCtl.add(value);
  }

  void setDuration(Duration value) {
    _duration = value;
    _durationCtl.add(value);
  }

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  bool get isPlaying => false;

  @override
  double get rate => 1.0;

  @override
  double get volume => 100.0;

  @override
  int? get selectedAudioTrackIndex => 0;

  @override
  List<int> get availableAudioTrackIndices => const [];

  @override
  int? get textureId => null;

  @override
  Stream<Duration> get positionStream => _positionCtl.stream;

  @override
  Stream<Duration> get durationStream => _durationCtl.stream;

  @override
  Stream<bool> get isPlayingStream => _playingCtl.stream;

  @override
  Stream<int?> get selectedAudioTrackStream => _audioCtl.stream;

  @override
  Stream<EngineErrorEvent> get errorStream => _errorCtl.stream;

  @override
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool play = true,
  }) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {
    setPosition(position);
  }

  @override
  Future<void> setAudioTrack(int trackIndex) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setVolume(double volume0to100) async {}

  @override
  Future<void> dispose() async {
    await _positionCtl.close();
    await _durationCtl.close();
    await _playingCtl.close();
    await _audioCtl.close();
    await _errorCtl.close();
  }
}

/// Helper that returns the currently-rendered [Slider] inside the
/// [PlayerProgressBar].  Convenience over `tester.widget<Slider>()`
/// scoped to the progress-bar subtree.
Slider _findSlider(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider));

/// Wraps the progress bar in a [ValueListenableBuilder]-style harness so
/// the test can update `playlistOffsetSec` / `isSeeking` from outside
/// without re-pumping the full widget tree — the underlying
/// `_PlayerProgressBarState` (and its `_pendingValue`) must persist
/// across those updates, exactly as it does in production when the
/// parent `FluxPlayerControls` rebuilds in response to cubit state
/// changes.
class _ProgressBarHarness {
  _ProgressBarHarness({
    required this.engine,
    this.onSeekCommit,
  });

  final _StreamableFakeEngine engine;
  final ValueChanged<Duration>? onSeekCommit;
  final ValueNotifier<double> playlistOffsetSec = ValueNotifier(0.0);
  final ValueNotifier<bool> isSeeking = ValueNotifier(false);

  Widget build() {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: ValueListenableBuilder<double>(
              valueListenable: playlistOffsetSec,
              builder: (context, offset, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: isSeeking,
                  builder: (context, seeking, _) {
                    return PlayerProgressBar(
                      engine: engine,
                      playlistOffsetSec: offset,
                      isSeeking: seeking,
                      onSeekCommit: onSeekCommit,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerProgressBar — pin behaviour across engines', () {
    testWidgets(
      'thumb does not snap to end during ExoPlayer post-restart transient',
      (tester) async {
        // Scenario: user is at source-time 0:30 in a 2400 s movie with
        // `playlistOffsetSec == 0`.  They drag the scrubber to source-
        // time 1830 s (30:30) — a large forward jump that the cubit
        // routes through the server-restart path.  Cubit emits
        // `isSeeking: true`, performs the restart, and finally emits
        // `isSeeking: false` with the new `playlistOffsetSec = 1800`.
        // ExoPlayer takes a few hundred ms to emit the new
        // `durationChanged` (only fires on STATE_READY).  In that
        // window the Dart-side `_position` + `_duration` caches have
        // been reset to zero by `ExoPlayerEngine.open` (plan 24 M8)
        // — and the pin's `playerDur > 0` settle gate is exactly what
        // keeps the released target visible until the new duration
        // catches up.

        final engine = _StreamableFakeEngine(
          position: const Duration(seconds: 30),
          duration: const Duration(seconds: 2400),
        );

        Duration? committedTarget;
        final harness = _ProgressBarHarness(
          engine: engine,
          onSeekCommit: (d) => committedTarget = d,
        );

        await tester.pumpWidget(harness.build());

        // Initial emissions so the StreamBuilder snapshot lands.
        engine.setPosition(const Duration(seconds: 30));
        engine.setDuration(const Duration(seconds: 2400));
        await tester.pumpAndSettle();
        expect(_findSlider(tester).value, closeTo(30 / 2400, 0.001));

        // Drag to source-time 1830 s and release.
        final slider = _findSlider(tester);
        const targetRatio = 1830.0 / 2400.0;
        slider.onChangeStart!(slider.value);
        slider.onChanged!(targetRatio);
        slider.onChangeEnd!(targetRatio);
        await tester.pump();
        expect(committedTarget!.inMilliseconds, 1830 * 1000);

        // Cubit's seek-restart window — flips `isSeeking: true`.
        harness.isSeeking.value = true;
        await tester.pump();

        // Mid-restart: cubit emits the new playlistOffsetSec then
        // ExoPlayerEngine.open resets player-position + player-
        // duration to zero (plan 24 M8 patch).  Pin must hold.
        engine.setPosition(Duration.zero);
        engine.setDuration(Duration.zero);
        harness.playlistOffsetSec.value = 1800.0;
        harness.isSeeking.value = false;
        await tester.pumpAndSettle();
        expect(
          _findSlider(tester).value,
          closeTo(targetRatio, 0.001),
          reason: 'Pin must hold while playerDur == 0 post-open transient.',
        );

        // STATE_READY arrives — Kotlin emits the new
        // `durationChanged` (here: new playlist duration = 600 s,
        // since 2400 - 1800 = 600).  ExoPlayer also fires
        // `onPositionDiscontinuity` for the within-playlist sub-
        // segment seek; emit a 30-second player-time position to
        // represent that, which in source-time settles exactly to
        // the user's release target of 1830 s.
        engine.setDuration(const Duration(seconds: 600));
        engine.setPosition(const Duration(seconds: 30));
        await tester.pumpAndSettle();

        // Pin should clear now: playerDur > 0, sourcePos = 30 + 1800
        // = 1830 matches pendingMs (sourceDur * 0.7625 = 2400 *
        // 0.7625 = 1830) within tolerance.  Slider tracks the live
        // playhead.
        expect(_findSlider(tester).value, closeTo(1830 / 2400, 0.001));
      },
    );

    testWidgets(
      'in-player seek: pin clears once player position settles to target',
      (tester) async {
        final engine = _StreamableFakeEngine(
          position: const Duration(seconds: 60),
          duration: const Duration(seconds: 2400),
        );

        Duration? committed;
        final harness = _ProgressBarHarness(
          engine: engine,
          onSeekCommit: (d) => committed = d,
        );

        await tester.pumpWidget(harness.build());
        engine.setPosition(const Duration(seconds: 60));
        engine.setDuration(const Duration(seconds: 2400));
        await tester.pumpAndSettle();

        final slider = _findSlider(tester);
        const targetRatio = 120.0 / 2400.0;
        slider.onChangeStart!(slider.value);
        slider.onChanged!(targetRatio);
        slider.onChangeEnd!(targetRatio);
        await tester.pump();
        expect(committed!.inSeconds, 120);

        // Pin holds at released value until the engine catches up.
        expect(_findSlider(tester).value, closeTo(targetRatio, 0.001));

        // Cubit issues engine.seek(120) → _StreamableFakeEngine.seek
        // updates _position + emits.  Settle check: playerDur > 0 and
        // |sourcePos - pendingMs| < tolerance → pin clears.
        await engine.seek(const Duration(seconds: 120));
        await tester.pumpAndSettle();
        expect(_findSlider(tester).value, closeTo(120 / 2400, 0.001));
      },
    );

    testWidgets(
      'pin holds while widget.isSeeking == true (server-restart window)',
      (tester) async {
        // Cubit has emitted `isSeeking: true` and the
        // pause / seek / open / play cycle is in flight.  The pin
        // must NOT clear even if the engine's reported source-time
        // briefly matches the pending target (which can happen if
        // ExoPlayer fires an early position discontinuity at 0
        // before the new playlist is fully prepared).

        final engine = _StreamableFakeEngine(
          position: const Duration(seconds: 30),
          duration: const Duration(seconds: 2400),
        );

        final harness = _ProgressBarHarness(engine: engine, onSeekCommit: (_) {})
          ..isSeeking.value = true;
        await tester.pumpWidget(harness.build());
        engine.setPosition(const Duration(seconds: 30));
        engine.setDuration(const Duration(seconds: 2400));
        await tester.pumpAndSettle();

        final slider = _findSlider(tester);
        const targetRatio = 1830.0 / 2400.0;
        slider.onChangeStart!(slider.value);
        slider.onChanged!(targetRatio);
        slider.onChangeEnd!(targetRatio);
        await tester.pump();

        // Ghost position emission that matches the pending ratio.
        engine.setPosition(const Duration(seconds: 1830));
        await tester.pumpAndSettle();

        expect(
          _findSlider(tester).value,
          closeTo(targetRatio, 0.001),
          reason: 'Pin must hold while widget.isSeeking is true.',
        );
      },
    );

    testWidgets(
      'pin holds while playerDur == 0 (post-open transient under ExoPlayer)',
      (tester) async {
        // Cubit has emitted `isSeeking: false` and the new
        // `playlistOffsetSec`, but the engine's reported playerDur
        // is still zero (ExoPlayerEngine.open reset it; the Kotlin
        // side hasn't emitted a new `durationChanged` yet).  The
        // `playerDur > 0` settle gate is the only thing keeping the
        // pin held — without it, the pendingMs math would compute
        // against `sourceDur = 0 + offsetMs` and could clear
        // prematurely.

        final engine = _StreamableFakeEngine(
          position: const Duration(seconds: 30),
          duration: const Duration(seconds: 2400),
        );

        final harness = _ProgressBarHarness(engine: engine, onSeekCommit: (_) {});
        await tester.pumpWidget(harness.build());
        engine.setPosition(const Duration(seconds: 30));
        engine.setDuration(const Duration(seconds: 2400));
        await tester.pumpAndSettle();

        final slider = _findSlider(tester);
        const targetRatio = 1830.0 / 2400.0;
        slider.onChangeStart!(slider.value);
        slider.onChanged!(targetRatio);
        slider.onChangeEnd!(targetRatio);
        await tester.pump();

        // Simulate engine.open reset.
        engine.setPosition(Duration.zero);
        engine.setDuration(Duration.zero);
        await tester.pumpAndSettle();

        expect(
          _findSlider(tester).value,
          closeTo(targetRatio, 0.001),
          reason:
              'Pin must hold while playerDur == 0 (post-`open` transient).',
        );
      },
    );
  });
}
