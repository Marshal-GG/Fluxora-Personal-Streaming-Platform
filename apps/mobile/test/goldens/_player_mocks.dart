/// Shared mocks for the mobile player golden tests.
///
/// `FakePlayerEngine` satisfies the [PlayerEngine] interface with
/// deterministic position / duration values.  No native libmpv libs
/// required — the engine never opens a real stream, just answers the
/// getters and streams that the chrome widgets read.
///
/// Each golden test file constructs a `FakePlayerEngine` with the
/// position and duration that matches its capture spec (see the table
/// in `test/goldens/_README.md`).
library;

import 'dart:async';

import 'package:fluxora_core/fluxora_core.dart';

/// In-memory [PlayerEngine] for headless golden capture.  Only the
/// fields the player chrome reads are populated; everything else
/// either returns a sensible default (zero duration, no audio tracks)
/// or never gets touched by the widget under test.
class FakePlayerEngine implements PlayerEngine {
  FakePlayerEngine({
    required this.position,
    required this.duration,
    this.isPlaying = false,
    this.volume = 100.0,
    this.rate = 1.0,
  });

  @override
  Duration position;

  @override
  Duration duration;

  @override
  bool isPlaying;

  @override
  double volume;

  @override
  double rate;

  @override
  int? get selectedAudioTrackIndex => 0;

  @override
  List<int> get availableAudioTrackIndices => const [];

  @override
  int? get textureId => null;

  // Streams: emit the seeded values once, then close.  Uses
  // `Stream.value(...)` so a `StreamBuilder.initialData -> first-event`
  // transition lands inside one `pumpAndSettle`.
  @override
  Stream<Duration> get positionStream => Stream.value(position);

  @override
  Stream<Duration> get durationStream => Stream.value(duration);

  @override
  Stream<bool> get isPlayingStream => Stream.value(isPlaying);

  @override
  Stream<int?> get selectedAudioTrackStream => Stream.value(0);

  @override
  Stream<EngineErrorEvent> get errorStream =>
      const Stream<EngineErrorEvent>.empty();

  // Commands — golden tests never exercise these, but the interface
  // requires bodies.
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
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setAudioTrack(int trackIndex) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setVolume(double volume0to100) async {}

  @override
  Future<void> setMetadata(String? title) async {}

  @override
  Future<void> dispose() async {}
}

/// Convenience constructor for [FakePlayerEngine].
FakePlayerEngine buildFakeEngine({
  required Duration position,
  required Duration duration,
  bool playing = false,
  double volume = 100.0,
}) => FakePlayerEngine(
  position: position,
  duration: duration,
  isPlaying: playing,
  volume: volume,
);
