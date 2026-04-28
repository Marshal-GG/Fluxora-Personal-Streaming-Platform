import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart' show Media, Player;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/player/domain/repositories/player_repository.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';

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

  Future<void> startStream(String fileId, String fileName) async {
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

      emit(PlayerReady(
        sessionId: response.sessionId,
        fileName: fileName,
        player: _player!,
        controller: _controller!,
      ));
    } on ApiException catch (e, st) {
      _log.e('Failed to start stream', error: e, stackTrace: st);
      emit(PlayerFailure(e.message));
    } catch (e, st) {
      _log.e('Failed to start stream', error: e, stackTrace: st);
      emit(const PlayerFailure('Failed to start stream. Please try again.'));
    }
  }

  @override
  Future<void> close() async {
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
