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
    this.hdrFormat,
    this.tonemapped = false,
    this.isSeeking = false,
  });

  final String sessionId;
  final String fileName;
  final Player player;
  final VideoController controller;
  /// The position the player was seeked to on open (0 = fresh start).
  final double resumeSec;
  /// The active streaming transport.
  final StreamPath streamPath;

  /// Source HDR format if any: "HDR10" / "HLG" / "DolbyVision" / null
  /// (SDR).  Drives the HDR badge in the player chrome.
  final String? hdrFormat;

  /// True when the server is currently tonemapping HDR → SDR for this
  /// session.  Drives the toggle in the player's overflow menu — when
  /// true, the user has explicitly asked the server to convert; when
  /// false, the source's HDR bitstream is being preserved (player /
  /// display determines the final look).
  final bool tonemapped;

  /// True while a server-side seek-restart is in flight (POST /seek →
  /// playlist re-open).  Drives a small "Seeking…" / spinner overlay so
  /// the user understands why playback paused.  Distinct from media_kit's
  /// own buffering signal because the server restart needs ≥1 segment
  /// of wall-time to produce its first new segment, which is a longer
  /// gap than the player's normal buffer-fill animation can explain.
  final bool isSeeking;

  /// True when the source is HDR.  Convenience alias.
  bool get isHdrSource => hdrFormat != null && hdrFormat!.isNotEmpty;

  PlayerReady copyWith({StreamPath? streamPath, bool? isSeeking}) => PlayerReady(
        sessionId: sessionId,
        fileName: fileName,
        player: player,
        controller: controller,
        resumeSec: resumeSec,
        streamPath: streamPath ?? this.streamPath,
        hdrFormat: hdrFormat,
        tonemapped: tonemapped,
        isSeeking: isSeeking ?? this.isSeeking,
      );
}

class PlayerFailure extends PlayerState {
  const PlayerFailure(this.message);
  final String message;
}

/// The server rejected the stream start because the account's tier concurrency
/// limit has been reached.  Shown as an upgrade prompt rather than a generic error.
class PlayerTierLimit extends PlayerState {
  const PlayerTierLimit();
}
