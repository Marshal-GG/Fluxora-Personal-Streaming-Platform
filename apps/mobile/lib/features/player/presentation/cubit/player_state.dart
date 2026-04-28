import 'package:media_kit/media_kit.dart' show Player;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;

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
  });

  final String sessionId;
  final String fileName;
  final Player player;
  final VideoController controller;
}

class PlayerFailure extends PlayerState {
  const PlayerFailure(this.message);
  final String message;
}
