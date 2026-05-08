/// Cubit backing the music player screen.
///
/// Uses a [just_audio] [AudioPlayer] for in-app playback.  Audio_service
/// lockscreen integration is deferred to v1.1 — a dedicated MusicHandler
/// bridging the music [AudioPlayer] (separate from the video [PlayerCubit])
/// is needed to avoid shared-state conflicts on the single FluxoraAudioHandler
/// instance initialised in main.dart.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/storage/secure_storage.dart';

sealed class MusicPlayerState {
  const MusicPlayerState();
}

class MusicPlayerInitial extends MusicPlayerState {
  const MusicPlayerInitial();
}

class MusicPlayerLoading extends MusicPlayerState {
  const MusicPlayerLoading();
}

class MusicPlayerReady extends MusicPlayerState {
  const MusicPlayerReady({
    required this.position,
    required this.duration,
    required this.isPlaying,
    this.isBuffering = false,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isBuffering;

  MusicPlayerReady copyWith({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isBuffering,
  }) {
    return MusicPlayerReady(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
    );
  }
}

class MusicPlayerFailure extends MusicPlayerState {
  const MusicPlayerFailure(this.message);

  final String message;
}

class MusicPlayerCubit extends Cubit<MusicPlayerState> {
  MusicPlayerCubit({required SecureStorage secureStorage})
      : _secureStorage = secureStorage,
        super(const MusicPlayerInitial());

  final SecureStorage _secureStorage;
  final AudioPlayer _player = AudioPlayer();
  static final _log = Logger();

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<ProcessingState>? _procSub;

  Future<void> start(MediaFile file) async {
    emit(const MusicPlayerLoading());
    try {
      final serverUrl = await _secureStorage.getServerUrl();
      final token = await _secureStorage.getAuthToken();
      if (serverUrl == null) {
        emit(const MusicPlayerFailure('Server not configured.'));
        return;
      }
      final url = '$serverUrl/api/v1/files/${file.id}/content';
      final headers = token != null
          ? {HttpHeaders.authorizationHeader: 'Bearer $token'}
          : <String, String>{};

      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url), headers: headers),
      );

      emit(MusicPlayerReady(
        position: Duration.zero,
        duration: _player.duration ?? Duration.zero,
        isPlaying: false,
      ));

      _posSub = _player.positionStream.listen((pos) {
        final s = state;
        if (s is MusicPlayerReady) emit(s.copyWith(position: pos));
      });
      _durSub = _player.durationStream.listen((dur) {
        final s = state;
        if (s is MusicPlayerReady) {
          emit(s.copyWith(duration: dur ?? Duration.zero));
        }
      });
      _playingSub = _player.playingStream.listen((playing) {
        final s = state;
        if (s is MusicPlayerReady) emit(s.copyWith(isPlaying: playing));
      });
      _procSub = _player.processingStateStream.listen((ps) {
        final s = state;
        if (s is MusicPlayerReady) {
          emit(s.copyWith(
            isBuffering: ps == ProcessingState.buffering ||
                ps == ProcessingState.loading,
          ));
        }
      });

      await _player.play();
    } catch (e, st) {
      _log.e('Music player failed to start for ${file.id}',
          error: e, stackTrace: st);
      emit(const MusicPlayerFailure('Could not play this audio file.'));
    }
  }

  Future<void> playPause() async {
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (e, st) {
      _log.w('playPause failed', error: e, stackTrace: st);
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e, st) {
      _log.w('seek failed', error: e, stackTrace: st);
    }
  }

  @override
  void emit(MusicPlayerState state) {
    if (isClosed) return;
    super.emit(state);
  }

  @override
  Future<void> close() async {
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _playingSub?.cancel();
    await _procSub?.cancel();
    await _player.dispose();
    return super.close();
  }
}
