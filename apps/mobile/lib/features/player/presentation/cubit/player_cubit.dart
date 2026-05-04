import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart' show Media, Player;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_core/network/network_path_detector.dart';
import 'package:fluxora_mobile/features/player/data/services/fluxora_audio_handler.dart';
import 'package:fluxora_mobile/features/player/data/services/webrtc_signaling_service.dart';
import 'package:fluxora_mobile/features/player/domain/repositories/player_repository.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';

/// How often (in seconds) the cubit reports playback progress to the server.
const _kProgressIntervalSec = 10;

/// How long to wait for WebRTC ICE to connect before falling back to HLS.
const _kWebRtcTimeoutSec = 8;

class PlayerCubit extends Cubit<PlayerState> {
  PlayerCubit({
    required PlayerRepository repository,
    required SecureStorage secureStorage,
    FluxoraAudioHandler? audioHandler,
  })  : _repository = repository,
        _secureStorage = secureStorage,
        _audioHandler = audioHandler,
        super(const PlayerInitial()) {
    _lifecycleObserver = _PlayerLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  final PlayerRepository _repository;
  final SecureStorage _secureStorage;

  /// Optional — null in unit tests where the OS audio_service hasn't
  /// been initialised.  Production wires it via the injector.
  final FluxoraAudioHandler? _audioHandler;

  late final _PlayerLifecycleObserver _lifecycleObserver;

  /// Set when the cubit auto-pauses on background and the app's
  /// background-playback preference is currently disabled.  Drives the
  /// first-time prompt: when the user comes back, the player_screen
  /// reads this and (if the prompt hasn't been shown yet) asks whether
  /// they'd like to keep playing through future minimisations.
  bool _autoPausedOnBackground = false;
  bool get wasAutoPausedOnBackground => _autoPausedOnBackground;
  void clearAutoPausedFlag() => _autoPausedOnBackground = false;
  static final _log = Logger();

  Player? _player;
  VideoController? _controller;
  String? _sessionId;
  Timer? _progressTimer;
  WebRtcSignalingService? _signaling;

  // Cached `startStream` call args so `setTonemap()` can restart with the
  // same file + name + poster after a tonemap toggle.  Cleared on
  // `dismiss()` / `_disposeCurrentSession()`.
  String? _lastFileId;
  String? _lastFileName;
  String? _lastPosterUrl;

  // ---------------------------------------------------------------------------
  // Public
  // ---------------------------------------------------------------------------

  Future<void> startStream(
    String fileId,
    String fileName,
    double resumeSec, {
    String? posterUrl,
    bool tonemap = false,
  }) async {
    // M7: when the cubit is a long-lived singleton, a second `startStream`
    // must clean up the previous session before opening the next one.
    // First-call (no prior session) is cheap — every dispose is null-guarded.
    await _disposeCurrentSession();

    // Remember the call args so `setTonemap` can restart with the same
    // file + resume position when the user toggles the HDR option mid-
    // playback.
    _lastFileId = fileId;
    _lastFileName = fileName;
    _lastPosterUrl = posterUrl;

    emit(const PlayerLoading());
    try {
      final response = await _repository.startStream(fileId, tonemap: tonemap);
      _sessionId = response.sessionId;

      final token = await _secureStorage.getAuthToken();
      final serverUrl = await _secureStorage.getServerUrl();

      // Only attempt WebRTC when the server is on the internet (WAN).
      // On LAN, HLS is faster and WebRTC adds unnecessary latency.
      StreamPath path = StreamPath.hls;
      if (token != null && serverUrl != null) {
        final isLan = await NetworkPathDetector.isLan(serverUrl);
        if (!isLan) {
          path = await _tryWebRtc(serverUrl: serverUrl, token: token);
        } else {
          _log.d('[Player] LAN detected — using HLS directly');
        }
      }

      // HLS path is always the media source for media_kit regardless of the
      // signaling path, since the WebRTC data-channel streaming layer isn't
      // complete yet.  The `streamPath` field signals to the UI which transport
      // is active so it can display the correct badge.
      final headers = token != null
          ? <String, String>{'Authorization': 'Bearer $token'}
          : <String, String>{};

      _player = Player();
      _controller = VideoController(_player!);
      await _player!.open(Media(response.playlistUrl, httpHeaders: headers));

      final seekSec = response.resumeSec > 0 ? response.resumeSec : resumeSec;
      if (seekSec > 0) {
        await _player!.seek(Duration(milliseconds: (seekSec * 1000).toInt()));
      }

      // Hook the OS media session (lockscreen / notification card / BT
      // headset).  Best-effort — if audio_service hasn't initialised
      // (unit tests, embedded preview) this is a no-op.
      try {
        await _audioHandler?.bind(
          player: _player!,
          id: fileId,
          title: fileName,
          artUri: posterUrl,
        );
      } catch (e, st) {
        _log.w('AudioHandler.bind failed', error: e, stackTrace: st);
      }

      emit(PlayerReady(
        sessionId: response.sessionId,
        fileName: fileName,
        player: _player!,
        controller: _controller!,
        resumeSec: seekSec,
        streamPath: path,
        hdrFormat: response.hdrFormat,
        tonemapped: response.tonemapped,
      ));

      _startProgressTimer();
    } on ApiException catch (e, st) {
      if (e.isTierLimit) {
        _log.w('[Player] Stream concurrency limit reached (429)');
        emit(const PlayerTierLimit());
      } else {
        _log.e('Failed to start stream', error: e, stackTrace: st);
        emit(PlayerFailure(e.message));
      }
    } catch (e, st) {
      _log.e('Failed to start stream', error: e, stackTrace: st);
      emit(const PlayerFailure('Failed to start stream. Please try again.'));
    }
  }

  /// Toggle server-side HDR → SDR tonemapping for the current session.
  ///
  /// Restarts the stream with the new flag — the server has to respin
  /// the FFmpeg pipeline because tonemap forces transcode mode (decoded
  /// pixels needed by the zscale + Hable filter chain).  Resume position
  /// is preserved from the player's current playback time, falling back
  /// to the original `resumeSec` if no time is available yet.
  ///
  /// No-op when there's no active session, or when the cached file
  /// arguments are missing (e.g. between dispose and the next start).
  Future<void> setTonemap(bool enabled) async {
    final fileId = _lastFileId;
    final fileName = _lastFileName;
    if (fileId == null || fileName == null) {
      _log.w('setTonemap called with no active stream; ignoring');
      return;
    }
    final currentState = state;
    final currentMs = _player?.state.position.inMilliseconds ?? 0;
    final fallbackSec = currentState is PlayerReady ? currentState.resumeSec : 0.0;
    final resumeSec = currentMs > 0 ? currentMs / 1000.0 : fallbackSec;
    await startStream(
      fileId,
      fileName,
      resumeSec,
      posterUrl: _lastPosterUrl,
      tonemap: enabled,
    );
  }

  // ---------------------------------------------------------------------------
  // WebRTC negotiation
  // ---------------------------------------------------------------------------

  /// Attempts to establish a WebRTC connection within [_kWebRtcTimeoutSec].
  ///
  /// Returns [StreamPath.webRtc] on success, [StreamPath.hls] on any failure
  /// or timeout (so the caller always gets a usable path).
  Future<StreamPath> _tryWebRtc({
    required String serverUrl,
    required String token,
  }) async {
    final completer = Completer<StreamPath>();

    _signaling = WebRtcSignalingService(
      serverWsUrl: serverUrl,
      authToken: token,
      onStateChange: (sigState) {
        if (!completer.isCompleted) {
          // Pre-connection: drive the initial path selection.
          switch (sigState) {
            case SignalingState.connected:
              completer.complete(StreamPath.webRtc);
            case SignalingState.failed:
              _log.w('[WebRTC] Signaling failed — falling back to HLS');
              completer.complete(StreamPath.hls);
            case SignalingState.closed:
              if (!completer.isCompleted) completer.complete(StreamPath.hls);
            default:
              break;
          }
        } else {
          // Post-connection: handle ICE degradation while streaming.
          _handleSignalingDegradation(sigState);
        }
      },
    );

    try {
      await _signaling!.connect();
    } catch (e) {
      _log.w('[WebRTC] connect() threw — falling back to HLS: $e');
      return StreamPath.hls;
    }

    // Race: ICE connected vs. timeout
    return completer.future.timeout(
      const Duration(seconds: _kWebRtcTimeoutSec),
      onTimeout: () {
        _log.w('[WebRTC] ICE timeout after ${_kWebRtcTimeoutSec}s — falling back to HLS');
        return StreamPath.hls;
      },
    );
  }

  /// Called when ICE degrades after the stream is already playing.
  ///
  /// Updates the transport badge to HLS and closes the signaling session.
  /// The media_kit player continues uninterrupted because it was always
  /// reading from an HLS playlist — WebRTC only drove the signaling badge.
  void _handleSignalingDegradation(SignalingState sigState) {
    if (sigState != SignalingState.failed) return;
    final current = state;
    if (current is! PlayerReady) return;
    if (current.streamPath != StreamPath.webRtc) return;

    _log.w('[Player] WebRTC degraded — switching transport badge to HLS');
    emit(current.copyWith(streamPath: StreamPath.hls));
    _signaling?.close();
    _signaling = null;
  }

  // ---------------------------------------------------------------------------
  // Progress reporting
  // ---------------------------------------------------------------------------

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(seconds: _kProgressIntervalSec),
      (_) => _reportProgress(),
    );
  }

  Future<void> _reportProgress() async {
    final sid = _sessionId;
    final player = _player;
    if (sid == null || player == null) return;

    final posMicros = player.state.position.inMicroseconds;
    final progressSec = posMicros / 1e6;
    if (progressSec <= 0) return;

    try {
      await _repository.updateProgress(sid, progressSec);
    } catch (e) {
      // Silently swallow — progress reporting is non-critical
      _log.w('Progress update failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Tear down the current playback session (timer / progress / signaling /
  /// `Player`) and clear the local references. Safe to call when nothing is
  /// playing — every step is null-guarded. Used by both `startStream`
  /// (when a long-lived singleton replaces an existing session) and
  /// [dismiss] (explicit "stop and forget" from the mini-player X button).
  Future<void> _disposeCurrentSession() async {
    _progressTimer?.cancel();
    _progressTimer = null;
    if (_sessionId != null) {
      // Best-effort final progress report; swallow per the original
      // close() behaviour.
      await _reportProgress();
      try {
        await _repository.stopStream(_sessionId!);
      } catch (e, st) {
        _log.w('Failed to stop stream on dispose', error: e, stackTrace: st);
      }
      _sessionId = null;
    }
    await _signaling?.close();
    _signaling = null;
    // Detach from the OS media session before disposing the Player —
    // otherwise the handler holds stream subscriptions to the Player and
    // the dispose will throw.
    try {
      await _audioHandler?.detach();
    } catch (e, st) {
      _log.w('AudioHandler.detach failed', error: e, stackTrace: st);
    }
    await _player?.dispose();
    _player = null;
    _controller = null;
  }

  /// Explicitly end the active stream and reset to [PlayerInitial]. Called
  /// from the mini-player's close (X) button. Distinct from [close] which
  /// is the cubit's own end-of-life — `dismiss` keeps the cubit alive
  /// (because it's a singleton) and just stops the stream.
  Future<void> dismiss() async {
    await _disposeCurrentSession();
    if (state is! PlayerInitial) emit(const PlayerInitial());
  }

  // ---------------------------------------------------------------------------
  // Lifecycle (Phase 3 — background-playback preference)
  // ---------------------------------------------------------------------------

  /// Called by [_PlayerLifecycleObserver] when the OS reports the app
  /// has been backgrounded.  When the user has *not* opted into
  /// background playback we pause the player so the audio doesn't keep
  /// running silently — Android's foreground service from
  /// [audio_service] keeps the lockscreen card alive either way.
  Future<void> _onAppBackgrounded() async {
    final p = _player;
    if (p == null) return;
    if (state is! PlayerReady) return;
    if (!p.state.playing) return;

    bool enabled;
    try {
      enabled = await _secureStorage.getBackgroundPlaybackEnabled();
    } catch (e, st) {
      _log.w('Could not read bg-playback pref — defaulting to disabled',
          error: e, stackTrace: st);
      enabled = false;
    }
    if (enabled) return;

    try {
      await p.pause();
      _autoPausedOnBackground = true;
    } catch (e, st) {
      _log.w('Auto-pause on background failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    await _disposeCurrentSession();
    await super.close();
  }
}

/// Tiny [WidgetsBindingObserver] sidecar — the cubit isn't a Widget so
/// it can't implement the binding observer mixin directly.  Mounted in
/// the cubit's constructor and removed in [PlayerCubit.close].  Only
/// the `paused` event is forwarded; the cubit doesn't auto-resume on
/// `resumed` because the user might have intentionally walked away.
class _PlayerLifecycleObserver with WidgetsBindingObserver {
  _PlayerLifecycleObserver(this._cubit);

  final PlayerCubit _cubit;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Fire-and-forget — the observer interface is sync but the cubit
      // method is async.  Failures are logged inside _onAppBackgrounded.
      _cubit._onAppBackgrounded();
    }
  }
}
