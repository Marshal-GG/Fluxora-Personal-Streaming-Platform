import 'package:media_kit/media_kit.dart' show Player;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;

/// Which transport is being used for the current stream.
enum StreamPath {
  /// HTTP-based HLS (default LAN path).
  hls,

  /// Direct peer-to-peer WebRTC data channel (internet path).
  webRtc,
}

sealed class PlayerState {
  const PlayerState();
}

class PlayerInitial extends PlayerState {
  const PlayerInitial();
}

class PlayerLoading extends PlayerState {
  const PlayerLoading();
}

class PlayerReady extends PlayerState {
  const PlayerReady({
    required this.sessionId,
    required this.fileName,
    required this.player,
    required this.controller,
    this.resumeSec = 0.0,
    this.streamPath = StreamPath.hls,
  });

  final String sessionId;
  final String fileName;
  final Player player;
  final VideoController controller;
  /// The position the player was seeked to on open (0 = fresh start).
  final double resumeSec;
  /// The active streaming transport.
  final StreamPath streamPath;
}

class PlayerFailure extends PlayerState {
  const PlayerFailure(this.message);
  final String message;
}
