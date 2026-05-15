/// `ExoPlayerEngine` — concrete [PlayerEngine] backed by a Media3
/// ExoPlayer instance owned by Kotlin code on the Android platform
/// side.  The Dart and Kotlin halves communicate over two
/// `flutter/services` channels:
///
///   * `MethodChannel`  `dev.marshalx.fluxora/exo_player`
///     — Dart → Kotlin commands (`create`, `open`, `play`, `pause`,
///       `seek`, `setAudioTrack`, `setRate`, `setVolume`, `dispose`).
///       Every call carries a `playerId` so the channel can multiplex
///       across multiple [ExoPlayerEngine] instances in the future.
///
///   * `EventChannel` `dev.marshalx.fluxora/exo_player_events`
///     — Kotlin → Dart push.  Every event payload starts with the
///       `playerId` field so listeners can demultiplex.
///
/// This engine never imports anything from `media_kit` — it talks only
/// to the platform channels, so it works on host-test runs (where the
/// channels are mocked) without pulling in libmpv binaries.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_core/player/engine_error.dart';
import 'package:fluxora_core/player/player_engine.dart';

/// Method-channel namespace.  Must match the Kotlin side.
@visibleForTesting
const String kExoPlayerMethodChannel = 'dev.marshalx.fluxora/exo_player';

/// Event-channel namespace.  Must match the Kotlin side.
@visibleForTesting
const String kExoPlayerEventChannel = 'dev.marshalx.fluxora/exo_player_events';

class ExoPlayerEngine implements PlayerEngine {
  ExoPlayerEngine._internal({
    required MethodChannel methodChannel,
    required EventChannel eventChannel,
    required int playerId,
    required int? textureId,
  }) : _methodChannel = methodChannel,
       _eventChannel = eventChannel,
       _playerId = playerId,
       _textureId = textureId;

  static final _log = Logger();

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final int _playerId;
  final int? _textureId;

  StreamSubscription<dynamic>? _eventSub;
  bool _disposed = false;

  // Cached engine state.  Updated from the EventChannel — the cubit and
  // UI read these via the synchronous getters below.
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _rate = 1.0;
  double _volume = 100.0;
  int? _selectedAudioTrackIndex;
  List<int> _availableAudioTrackIndices = const <int>[];
  ({int width, int height})? _videoSize;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _isPlayingController =
      StreamController<bool>.broadcast();
  final StreamController<int?> _selectedAudioController =
      StreamController<int?>.broadcast();
  final StreamController<EngineErrorEvent> _errorController =
      StreamController<EngineErrorEvent>.broadcast();
  final StreamController<({int width, int height})?> _videoSizeController =
      StreamController<({int width, int height})?>.broadcast();

  /// Default factory — production code uses this.  Allocates a Kotlin-
  /// side ExoPlayer + SurfaceProducer pair via the `create` method, then
  /// subscribes to the event stream filtered by the returned `playerId`.
  static Future<ExoPlayerEngine> create() {
    return createWithChannels(
      methodChannel: const MethodChannel(kExoPlayerMethodChannel),
      eventChannel: const EventChannel(kExoPlayerEventChannel),
    );
  }

  /// Test seam — lets unit tests inject mockable channels.  Production
  /// callers should use [create].
  @visibleForTesting
  static Future<ExoPlayerEngine> createWithChannels({
    required MethodChannel methodChannel,
    required EventChannel eventChannel,
  }) async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'create',
    );
    if (result == null) {
      throw StateError(
        '[ExoPlayerEngine] create() returned null from the platform side',
      );
    }
    final playerId = (result['playerId'] as num?)?.toInt();
    if (playerId == null) {
      throw StateError(
        '[ExoPlayerEngine] create() did not return a playerId '
        '(payload=$result)',
      );
    }
    final textureId = (result['textureId'] as num?)?.toInt();
    _log.i(
      '[ExoPlayerEngine] create — playerId=$playerId textureId=$textureId',
    );

    final engine = ExoPlayerEngine._internal(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
      playerId: playerId,
      textureId: textureId,
    );
    engine._attachEventBridge();
    return engine;
  }

  void _attachEventBridge() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object error, StackTrace stackTrace) {
        _log.w(
          '[ExoPlayerEngine] event stream error',
          error: error,
          stackTrace: stackTrace,
        );
        _errorController.add(
          EngineErrorEvent(
            type: EngineError.generic,
            message: error.toString(),
            cause: error,
          ),
        );
      },
    );
  }

  void _onEvent(dynamic raw) {
    if (raw is! Map) {
      _log.w('[ExoPlayerEngine] non-map event payload: $raw');
      return;
    }
    final event = Map<String, dynamic>.from(raw);
    final pid = (event['playerId'] as num?)?.toInt();
    if (pid != _playerId) {
      // Multiplexed channel — silently drop events meant for a
      // different ExoPlayerEngine instance.
      return;
    }
    final type = event['type'] as String?;
    if (type == null) {
      _log.w('[ExoPlayerEngine] event missing type: $event');
      return;
    }
    try {
      switch (type) {
        case 'positionChanged':
          final ms = (event['positionMs'] as num?)?.toInt() ?? 0;
          _position = Duration(milliseconds: ms);
          _positionController.add(_position);
          break;
        case 'durationChanged':
          final ms = (event['durationMs'] as num?)?.toInt() ?? 0;
          _duration = Duration(milliseconds: ms);
          _durationController.add(_duration);
          break;
        case 'isPlayingChanged':
          _isPlaying = event['isPlaying'] == true;
          _isPlayingController.add(_isPlaying);
          break;
        case 'tracksChanged':
          _onTracksChanged(event);
          break;
        case 'videoSizeChanged':
          final w = (event['width'] as num?)?.toInt() ?? 0;
          final h = (event['height'] as num?)?.toInt() ?? 0;
          final size = (w > 0 && h > 0) ? (width: w, height: h) : null;
          if (size != _videoSize) {
            _videoSize = size;
            _videoSizeController.add(size);
          }
          break;
        case 'playbackStateChanged':
          // Currently advisory — the cubit doesn't subscribe to a
          // dedicated state stream.  Log for diagnostics.
          _log.d(
            '[ExoPlayerEngine] playbackState=${event['state']} '
            'playerId=$_playerId',
          );
          break;
        case 'playerError':
          _onPlayerError(event);
          break;
        default:
          _log.w('[ExoPlayerEngine] unknown event type=$type payload=$event');
      }
    } catch (e, st) {
      _log.w(
        '[ExoPlayerEngine] event handler threw for type=$type',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _onTracksChanged(Map<String, dynamic> event) {
    final rawTracks = event['audioTracks'];
    final List<int> indices = <int>[];
    if (rawTracks is List) {
      for (final t in rawTracks) {
        if (t is Map) {
          final src = (t['sourceIndex'] as num?)?.toInt();
          if (src != null) indices.add(src);
        }
      }
    }
    _availableAudioTrackIndices = List<int>.unmodifiable(indices);
    final selected = (event['selectedAudioSourceIndex'] as num?)?.toInt();
    if (selected != _selectedAudioTrackIndex) {
      _selectedAudioTrackIndex = selected;
      _selectedAudioController.add(selected);
    }
  }

  void _onPlayerError(Map<String, dynamic> event) {
    final code = event['errorCode'] as String? ?? 'unknown';
    final message = event['message'] as String?;
    final type = _mapErrorCode(code);
    _log.w(
      '[ExoPlayerEngine] playerError code=$code mapped=$type message=$message',
    );
    _errorController.add(
      EngineErrorEvent(type: type, message: message, cause: code),
    );
  }

  /// The locked Kotlin → Dart error code vocabulary.  Any other
  /// string lands in [EngineError.generic] with the original code
  /// preserved on [EngineErrorEvent.cause] for diagnostic logging.
  static EngineError _mapErrorCode(String code) {
    switch (code) {
      case 'auth_failed':
        return EngineError.auth;
      case 'network_error':
        return EngineError.network;
      case 'decoder_failed':
        return EngineError.decode;
      case 'format_unsupported':
        return EngineError.formatUnsupported;
      case 'unknown':
      default:
        return EngineError.generic;
    }
  }

  Map<String, dynamic> _args([Map<String, dynamic>? extra]) {
    final m = <String, dynamic>{'playerId': _playerId};
    if (extra != null) m.addAll(extra);
    return m;
  }

  // ── PlayerEngine — commands ──────────────────────────────────────

  @override
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool play = true,
  }) async {
    // Reset cached state to "fresh source" semantics BEFORE issuing the
    // channel call.  libmpv's `Player.open` clears `state.position` /
    // `state.duration` to zero as a side effect; the Kotlin ExoPlayer
    // side has no analogous "everything-resets-now" event — it
    // deduplicates `durationChanged` (only fires on `STATE_READY` when
    // the new duration differs from the last emitted) and doesn't
    // synthesise a position-zero discontinuity on `stop()` +
    // `clearMediaItems()`.  Without this reset, the Dart caches keep
    // the *previous* playlist's position + duration while the new one
    // is preparing — observable as a transient where the scrubber
    // renders `oldPlayerPos + newOffsetMs` over `oldPlayerDur +
    // newOffsetMs`, the same shape the scrubber is already pinned
    // against on the libmpv path.
    //
    // Resetting + emitting matches the contract `MediaKitEngine` gets
    // for free via libmpv state-reset.  The pin-hold logic in
    // `PlayerProgressBar` gates its settle check on `playerDur > 0`:
    // while we're in the open→STATE_READY transient the pin stays
    // held to the user's release value, then clears once the Kotlin
    // side emits the new `durationChanged`.
    _position = Duration.zero;
    _duration = Duration.zero;
    _videoSize = null;
    _positionController.add(_position);
    _durationController.add(_duration);
    _videoSizeController.add(null);

    // The cubit drives all seek decisions via [seek]; `open` always
    // starts at position 0 unless the cubit later issues a seek.  The
    // locked channel contract allows the Kotlin side to honour a
    // `startPositionMs` for future use, but the Dart side does not
    // need it today.
    await _methodChannel.invokeMethod<void>(
      'open',
      _args({
        'url': url,
        if (headers != null) 'headers': headers,
        'play': play,
        'startPositionMs': 0,
      }),
    );
  }

  @override
  Future<void> play() async {
    await _methodChannel.invokeMethod<void>('play', _args());
  }

  @override
  Future<void> pause() async {
    await _methodChannel.invokeMethod<void>('pause', _args());
  }

  @override
  Future<void> seek(Duration position) async {
    final clamped = position.isNegative ? Duration.zero : position;
    await _methodChannel.invokeMethod<void>(
      'seek',
      _args({'positionMs': clamped.inMilliseconds}),
    );
  }

  @override
  Future<void> setAudioTrack(int trackIndex) async {
    await _methodChannel.invokeMethod<void>(
      'setAudioTrack',
      _args({'sourceIndex': trackIndex}),
    );
    // Optimistic local cache — the Kotlin side will follow up with a
    // `tracksChanged` event carrying the authoritative selection.
    _selectedAudioTrackIndex = trackIndex;
    _selectedAudioController.add(trackIndex);
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
    await _methodChannel.invokeMethod<void>(
      'setRate',
      _args({'rate': rate}),
    );
  }

  @override
  Future<void> setVolume(double volume0to100) async {
    _volume = volume0to100;
    final clamped = volume0to100.clamp(0.0, 100.0);
    // ExoPlayer uses 0-1; the PlayerEngine contract is 0-100.
    await _methodChannel.invokeMethod<void>(
      'setVolume',
      _args({'volume0to1': clamped / 100.0}),
    );
  }

  /// Pushes the title to the Kotlin side so Media3's `MediaSession`
  /// renders it on the lockscreen card / notification.  Null sends as
  /// a null value; the native side falls back to its default
  /// (`"Fluxora"` today).
  @override
  Future<void> setMetadata(String? title) async {
    await _methodChannel.invokeMethod<void>(
      'setMetadata',
      _args({'title': title}),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _eventSub?.cancel();
    } catch (e, st) {
      _log.w(
        '[ExoPlayerEngine] event-subscription cancel threw',
        error: e,
        stackTrace: st,
      );
    }
    _eventSub = null;
    try {
      await _methodChannel.invokeMethod<void>('dispose', _args());
    } catch (e, st) {
      // Don't propagate — the Kotlin side may already be torn down (the
      // FlutterEngine detach path calls dispose too).  Log and keep
      // closing the Dart-side controllers regardless.
      _log.w(
        '[ExoPlayerEngine] native dispose() threw',
        error: e,
        stackTrace: st,
      );
    }
    await _positionController.close();
    await _durationController.close();
    await _isPlayingController.close();
    await _selectedAudioController.close();
    await _errorController.close();
    await _videoSizeController.close();
  }

  // ── PlayerEngine — state snapshots ───────────────────────────────

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  bool get isPlaying => _isPlaying;

  @override
  double get rate => _rate;

  @override
  double get volume => _volume;

  @override
  int? get selectedAudioTrackIndex => _selectedAudioTrackIndex;

  @override
  List<int> get availableAudioTrackIndices => _availableAudioTrackIndices;

  @override
  int? get textureId => _textureId;

  @override
  ({int width, int height})? get videoSize => _videoSize;

  // ── PlayerEngine — streams ───────────────────────────────────────

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  @override
  Stream<int?> get selectedAudioTrackStream => _selectedAudioController.stream;

  @override
  Stream<EngineErrorEvent> get errorStream => _errorController.stream;

  @override
  Stream<({int width, int height})?> get videoSizeStream =>
      _videoSizeController.stream;

  // ── Diagnostics (test-only accessors) ────────────────────────────

  @visibleForTesting
  int get debugPlayerId => _playerId;
}
