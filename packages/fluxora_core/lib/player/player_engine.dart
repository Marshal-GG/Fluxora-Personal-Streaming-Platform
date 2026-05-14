/// Abstract playback engine — the cubit and UI talk to this, NOT to
/// `media_kit.Player` or `androidx.media3.exoplayer.ExoPlayer` directly.
///
/// Plan 24 carves this interface out of the previous direct-to-
/// `media_kit` shape so that:
///
/// 1. Android can switch to a Media3 ExoPlayer backend (M3+) without
///    changing a single line of cubit or UI code.
/// 2. Desktop + iOS keep using `media_kit` (libmpv on desktop, AVPlayer
///    under media_kit_video on iOS).
/// 3. Future engines (TVOS, web playback) can plug in by implementing
///    this contract.
///
/// Only the subset of `media_kit.Player` that the cubit and the player
/// chrome actually use lives on this interface — anything specific to
/// one backend stays behind that backend's wrapper.
library;

import 'package:fluxora_core/player/engine_error.dart';

/// Playback engine contract.  Implementations:
///
/// - [MediaKitEngine] — wraps a `media_kit.Player`.  Used on desktop,
///   iOS, and on Android until the `ExoPlayerEngine` (M3) ships.
/// - `ExoPlayerEngine` (Android, ships in M3) — talks to a Kotlin
///   platform channel that owns a Media3 ExoPlayer.
abstract class PlayerEngine {
  /// Open [url] for playback.  When [play] is true the engine starts
  /// playback as soon as the first frame is decodable; when false the
  /// engine prepares the stream paused (used by the seek-restart path
  /// that re-opens the playlist then seeks within it before resuming).
  ///
  /// [headers] are attached to every HTTP request the engine makes for
  /// the URL — Fluxora threads the bearer token through this map.
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool play = true,
  });

  /// Resume playback from the current position.
  Future<void> play();

  /// Pause playback at the current position.
  Future<void> pause();

  /// Seek to [position] within the currently-loaded source.  Engine
  /// implementations are responsible for clamping to [0, duration].
  Future<void> seek(Duration position);

  /// Switch the active audio track to the one whose source-stream
  /// index (FFmpeg's `0:a:<index>`) matches [trackIndex].  The cubit
  /// already deduplicates the index using its server-supplied
  /// `availableAudioTracks` list; the engine implementation maps it
  /// into whatever native handle its backend uses.
  Future<void> setAudioTrack(int trackIndex);

  /// Set playback rate.  1.0 = real-time, 2.0 = double-speed (long-
  /// press peek), 0.5 = half-speed.
  Future<void> setRate(double rate);

  /// Set output volume on a 0-100 scale (matches `media_kit.Player`'s
  /// existing volume range — the ExoPlayerEngine converts internally).
  Future<void> setVolume(double volume0to100);

  /// Release all resources held by the engine.  After this call no
  /// other method on this engine instance is valid.
  Future<void> dispose();

  // ── State (read-only snapshots) ───────────────────────────────────

  /// Latest known playback position.  Engines update this on the same
  /// cadence as [positionStream].
  Duration get position;

  /// Total source duration, or [Duration.zero] when not yet known.
  Duration get duration;

  /// True iff the engine is currently in the playing state.  Distinct
  /// from "has audio" — a paused engine returns false.
  bool get isPlaying;

  /// Current playback rate.  1.0 = real-time.  Read by the long-press
  /// peek path which restores the previous rate on release.
  double get rate;

  /// Current output volume on the 0-100 scale.  Read by the vertical-
  /// drag volume control which restores the existing level as its
  /// drag-start anchor.
  double get volume;

  /// Source-stream index of the currently-selected audio track, or
  /// null when the engine hasn't decoded any audio yet.
  int? get selectedAudioTrackIndex;

  /// Source-stream indices for every audio track the engine has
  /// discovered in the current source.  Empty when nothing is loaded.
  List<int> get availableAudioTrackIndices;

  /// Flutter texture id that renders the engine's video output.  Both
  /// MediaKitEngine and ExoPlayerEngine expose this so the player
  /// screen can embed a [Texture(textureId: id)] widget directly.
  /// Null while the engine is initialising or when no video stream is
  /// loaded.
  int? get textureId;

  // ── Streams (push updates as state changes) ───────────────────────

  /// Position emissions — engine-defined cadence, ~250 ms is typical.
  Stream<Duration> get positionStream;

  /// Emits whenever the engine learns the total duration (typically
  /// once per [open]).
  Stream<Duration> get durationStream;

  /// Emits on every play/pause transition.
  Stream<bool> get isPlayingStream;

  /// Emits whenever the active audio track changes — either via
  /// [setAudioTrack] or via a backend's own track-selection logic.
  Stream<int?> get selectedAudioTrackStream;

  /// Engine errors mapped into the structured [EngineErrorEvent]
  /// shape.  Native error payloads are preserved on the event's
  /// [EngineErrorEvent.cause] field for diagnostic logging.
  Stream<EngineErrorEvent> get errorStream;
}
