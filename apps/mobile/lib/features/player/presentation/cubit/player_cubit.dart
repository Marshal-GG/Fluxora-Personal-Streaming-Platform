import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart' show Media, Player;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/player/domain/repositories/player_repository.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';

/// How often (in seconds) the cubit reports playback progress to the server.
const _kProgressIntervalSec = 10;

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

  Future<void> startStream(String fileId, String fileName, double resumeSec) async {
    emit(const PlayerLoading());
    try {
      final response = await _repository.startStream(fileId);
      _sessionId = response.sessionId;

      final token = await _secureStorage.getAuthToken();
      final headers = token != null
          ? <String, String>{'Authorization': 'Bearer $token'}
          : <String, String>{};

      _player = Player();
      _controller = VideoController(_player!);

      await _player!.open(Media(response.playlistUrl, httpHeaders: headers));

      // Seek to the server-provided resume position (takes precedence over
      // the locally-known position since the server is the source of truth).
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
      ));

      _startProgressTimer();
    } on ApiException catch (e, st) {
      _log.e('Failed to start stream', error: e, stackTrace: st);
      emit(PlayerFailure(e.message));
    } catch (e, st) {
      _log.e('Failed to start stream', error: e, stackTrace: st);
      emit(const PlayerFailure('Failed to start stream. Please try again.'));
    }
  }

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
    await _player?.dispose();
    await super.close();
  }
}
