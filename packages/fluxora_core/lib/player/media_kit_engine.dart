/// `MediaKitEngine` — concrete [PlayerEngine] backed by a libmpv-based
/// `media_kit.Player` + `VideoController`.  Used on desktop and iOS
/// platforms, and as the fallback path on Android.
///
/// Every libmpv-specific behaviour the cubit needs (buffer-size config,
/// the Android-only `ao=audiotrack` libmpv property override,
/// VideoController construction) lives here so the cubit can talk to
/// one abstraction without caring which engine is underneath.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;

import 'package:fluxora_core/player/engine_error.dart';
import 'package:fluxora_core/player/player_engine.dart';

/// libmpv demuxer cache cap.  Default is 32 MB which gates first-frame
/// latency on 3-5 segments worth of readahead — visible to the user as
/// a "Loading…" spinner of 18-30 s on transcode sessions.  4 MB still
/// buffers ~3 segments at typical
/// 1080p HEVC bitrate (≈8 Mbps) but lets playback start as soon as
/// libmpv has decoded the first segment's first GOP.  Trade-off: a
/// >2 s network stall mid-playback will rebuffer instead of riding
/// through; acceptable on LAN where stalls are rare.
const int kMediaKitPlayerBufferBytes = 4 * 1024 * 1024;

class MediaKitEngine implements PlayerEngine {
  MediaKitEngine._(this._player, this._videoController);

  static final _log = Logger();

  final mk.Player _player;
  final VideoController _videoController;

  /// Errors translated from libmpv's flat-string `stream.error` into
  /// the structured [EngineErrorEvent] shape the cubit consumes.
  final StreamController<EngineErrorEvent> _errorController =
      StreamController<EngineErrorEvent>.broadcast();

  /// Audio-track selection emissions.  libmpv doesn't have a clean
  /// "selected audio track" stream — we mirror cubit-initiated changes
  /// through this controller so the [selectedAudioTrackStream] contract
  /// is honoured even before an ExoPlayer-style listener exists.
  final StreamController<int?> _selectedAudioController =
      StreamController<int?>.broadcast();

  StreamSubscription<String>? _errorBridgeSub;

  int? _selectedAudioTrackIndex;

  /// Factory.  Builds the `media_kit.Player` + `VideoController`, then
  /// applies the Android-only `ao=audiotrack` libmpv property override
  /// before any media is opened (so libmpv picks it on first init).
  ///
  /// Best-effort: a failure to set the property logs and falls back to
  /// the default `opensles` AO.  See the rationale inline below for
  /// why the override exists.
  static Future<MediaKitEngine> create() async {
    final player = mk.Player(
      configuration: const mk.PlayerConfiguration(
        bufferSize: kMediaKitPlayerBufferBytes,
      ),
    );

    // Core audio-output fix for Android: switch libmpv from the
    // default `opensles` AO to `audiotrack`.  Symptoms with the
    // OpenSL ES backend on Oplus/OnePlus (and likely other vendor
    // skins):
    //   * `libOpenSLES: Emulating old channel mask behavior` on
    //     every track init — channel mask negotiation broken, falls
    //     back to stereo regardless of source channel count.
    //   * AudioTrack churn on `setAudioTrack` mid-playback (audio
    //     dies for 20 s then libmpv stalls; only a manual seek
    //     recovers).
    //   * Flutter_webrtc's audio focus listener fires on every
    //     route change because OpenSL ES doesn't claim focus
    //     cleanly.
    // The `audiotrack` AO uses Android's AudioTrack API directly,
    // handles multi-channel correctly, and respects audio focus.
    // Set BEFORE `Player.open` so libmpv picks it on first init.
    if (Platform.isAndroid && player.platform is mk.NativePlayer) {
      try {
        await (player.platform! as mk.NativePlayer)
            .setProperty('ao', 'audiotrack');
        _log.i('[Player] libmpv ao=audiotrack set for Android session');
      } catch (e, st) {
        _log.w(
          '[Player] failed to set ao=audiotrack; falling back to '
          'default opensles',
          error: e,
          stackTrace: st,
        );
      }
    }

    final controller = VideoController(player);
    final engine = MediaKitEngine._(player, controller);
    engine._attachErrorBridge();
    return engine;
  }

  void _attachErrorBridge() {
    _errorBridgeSub = _player.stream.error.listen((message) {
      // libmpv reports errors as flat strings.  We do a coarse text-
      // based classification so the cubit can react — the [generic]
      // bucket is the safe fallback because the cubit's existing
      // failure-reason mapping was built against the same strings.
      final lower = message.toLowerCase();
      EngineError type;
      if (lower.contains('401') || lower.contains('403') || lower.contains('auth')) {
        type = EngineError.auth;
      } else if (lower.contains('network') ||
          lower.contains('timeout') ||
          lower.contains('connection')) {
        type = EngineError.network;
      } else if (lower.contains('format') || lower.contains('demux')) {
        type = EngineError.formatUnsupported;
      } else if (lower.contains('codec') || lower.contains('decode')) {
        type = EngineError.decode;
      } else {
        type = EngineError.generic;
      }
      _errorController.add(EngineErrorEvent(type: type, message: message));
    });
  }

  /// Direct access to the underlying `media_kit.Player`.  Exposed for
  /// pieces of the mobile app that still need libmpv-specific surface
  /// area (audio_service binding in `FluxoraAudioHandler`, the
  /// subtitle-track picker, the speed sheet's track-list fallback in
  /// `AudioSubsSheet`).  Treat this as a transitional escape hatch —
  /// it disappears when those callers move to platform-agnostic
  /// equivalents.
  mk.Player get mediaKitPlayer => _player;

  /// The `VideoController` paired with [_player].  The
  /// `media_kit_video` `Video` widget consumes this directly.  The
  /// player screen keeps using `Video` for the MediaKitEngine path
  /// rather than rendering a raw `Texture` widget, because `Video`
  /// carries the aspect-ratio / fit-mode logic.  The ExoPlayerEngine
  /// path renders [Texture(textureId: id)] directly.
  VideoController get videoController => _videoController;

  // ── PlayerEngine — commands ──────────────────────────────────────

  @override
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool play = true,
  }) async {
    await _player.open(
      mk.Media(url, httpHeaders: headers),
      play: play,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// libmpv tracks are stored in `player.state.tracks.audio` and
  /// numbered positionally inside the audio-group — but the first two
  /// slots are the magic `auto` / `no` sentinels.  Match by ordinal
  /// position after dropping those sentinels; fall back to id-string
  /// match.  Worst-case (no match) we log and leave the engine alone
  /// rather than crashing.
  ///
  /// This method is the fallback for callers that want pure
  /// client-side switching on a backend where it works (desktop
  /// libmpv).  The cubit on Android currently routes through
  /// server-restart and never calls this; the ExoPlayer engine uses
  /// its own TrackSelectionParameters path.
  @override
  Future<void> setAudioTrack(int trackIndex) async {
    final tracks = _player.state.tracks.audio;
    // Drop the leading magic entries (`auto` / `no`) — libmpv emits
    // those at the head of the list.  After dropping, the i-th entry
    // corresponds to the i-th source-stream by ordering.
    final real = tracks
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList(growable: false);
    if (trackIndex < 0 || trackIndex >= real.length) {
      _log.w(
        '[MediaKitEngine] setAudioTrack($trackIndex) — out of range '
        '(real-tracks=${real.length})',
      );
      return;
    }
    try {
      await _player.setAudioTrack(real[trackIndex]);
      _selectedAudioTrackIndex = trackIndex;
      _selectedAudioController.add(trackIndex);
    } catch (e, st) {
      _log.w(
        '[MediaKitEngine] setAudioTrack($trackIndex) failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> setVolume(double volume0to100) =>
      _player.setVolume(volume0to100);

  @override
  Future<void> dispose() async {
    await _errorBridgeSub?.cancel();
    _errorBridgeSub = null;
    await _errorController.close();
    await _selectedAudioController.close();
    await _player.dispose();
  }

  // ── PlayerEngine — state snapshots ───────────────────────────────

  @override
  Duration get position => _player.state.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  bool get isPlaying => _player.state.playing;

  @override
  double get rate => _player.state.rate;

  @override
  double get volume => _player.state.volume;

  @override
  int? get selectedAudioTrackIndex => _selectedAudioTrackIndex;

  @override
  List<int> get availableAudioTrackIndices {
    final tracks = _player.state.tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList(growable: false);
    return List<int>.generate(tracks.length, (i) => i);
  }

  @override
  int? get textureId => _videoController.id.value;

  // ── PlayerEngine — streams ───────────────────────────────────────

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<bool> get isPlayingStream => _player.stream.playing;

  @override
  Stream<int?> get selectedAudioTrackStream => _selectedAudioController.stream;

  @override
  Stream<EngineErrorEvent> get errorStream => _errorController.stream;
}
