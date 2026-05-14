/// Shared mocks for the mobile player golden tests.
///
/// `media_kit`'s `Player` cannot be instantiated headlessly — the
/// constructor reaches into the native libmpv bindings on first call.
/// For golden capture we don't need real playback; we only need the
/// widget to read deterministic values out of `player.state` /
/// `player.stream`.  Mocktail covers both the synchronous getters and
/// the per-channel `Stream<T>` exposed by `PlayerStream`.
///
/// Each golden test file constructs a `FakePlayer` with the position
/// and duration that matches its capture spec (see the table in
/// `test/goldens/_README.md`).
library;

import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

class MockPlayer extends Mock implements Player {}

class MockPlayerStream extends Mock implements PlayerStream {}

/// Build a `MockPlayer` whose `state` reports `position` / `duration`
/// and whose `stream.position` / `stream.duration` immediately emit
/// the same values.  Other state fields fall back to `PlayerState`'s
/// const defaults — fine for chrome-only captures where the test
/// doesn't touch volume / audio params / tracks.
MockPlayer buildFakePlayer({
  required Duration position,
  required Duration duration,
  bool playing = false,
  double volume = 100.0,
}) {
  final player = MockPlayer();
  final stream = MockPlayerStream();

  final state = PlayerState(
    position: position,
    duration: duration,
    playing: playing,
    volume: volume,
  );

  when(() => player.state).thenReturn(state);
  when(() => player.stream).thenReturn(stream);

  // Streams: a single-shot emit followed by no further events covers
  // the StreamBuilder's `initialData` -> first-event transition in
  // one `pumpAndSettle`.  We use Stream.value so the builder gets the
  // deterministic post-listen frame before the golden is captured.
  when(() => stream.position).thenAnswer((_) => Stream.value(position));
  when(() => stream.duration).thenAnswer((_) => Stream.value(duration));
  when(() => stream.playing).thenAnswer((_) => Stream.value(playing));

  return player;
}
