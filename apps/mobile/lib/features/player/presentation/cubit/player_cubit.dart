import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart' show Media, Player;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/player/data/services/network_path_detector.dart';
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
  })  : _repository = repository,
        _secureStorage = secureStorage,
        super(const PlayerInitial());

  final PlayerRepository _repository;
  final SecureStorage _secureStorage;
  static final _log = Logger();

  Player? _player;
  VideoController? _controller;
  String? _sessionId;
  Timer? _progressTimer;
  WebRtcSignalingService? _signaling;

  // ---------------------------------------------------------------------------
  // Public
  // ---------------------------------------------------------------------------

  Future<void> startStream(String fileId, String fileName, double resumeSec) async {
    emit(const PlayerLoading());
    try {
      final response = await _repository.startStream(fileId);
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

      emit(PlayerReady(
        sessionId: response.sessionId,
        fileName: fileName,
        player: _player!,
        controller: _controller!,
        resumeSec: seekSec,
        streamPath: path,
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

  @override
  Future<void> close() async {
    _progressTimer?.cancel();
    // Report final position before closing
    await _reportProgress();
    if (_sessionId != null) {
      try {
        await _repository.stopStream(_sessionId!);
      } catch (e, st) {
        _log.w('Failed to stop stream on close', error: e, stackTrace: st);
      }
    }
    await _signaling?.close();
    await _player?.dispose();
    await super.close();
  }
}
