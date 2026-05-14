import 'package:fluxora_core/fluxora_core.dart';
import 'package:fluxora_mobile/features/player/domain/entities/stream_start_response.dart';

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
    required this.engine,
    this.resumeSec = 0.0,
    this.playlistOffsetSec = 0.0,
    this.streamPath = StreamPath.hls,
    this.hdrFormat,
    this.tonemapped = false,
    this.isSeeking = false,
    this.availableAudioTracks = const [],
    this.selectedAudioTrackIndex = 0,
  });

  final String sessionId;
  final String fileName;

  /// Plan 24 — the active playback engine.  Was previously a raw
  /// `media_kit.Player` + `VideoController` pair; refactored to the
  /// shared [PlayerEngine] abstraction so the rest of the player
  /// code doesn't depend on which backend (libmpv vs. Media3) is
  /// running underneath.  For the MediaKitEngine path the embedded
  /// `Player` + `VideoController` are reachable via the engine's
  /// own typed accessors (`mediaKitPlayer` / `videoController`) —
  /// transitional escape hatches that disappear when the remaining
  /// libmpv-specific call sites (audio_service binding, subtitle
  /// picker) move to platform-agnostic equivalents (M7+).
  final PlayerEngine engine;

  /// The position the player was seeked to on open (0 = fresh start).
  final double resumeSec;

  /// Server-supplied source-time offset for the playlist's t=0
  /// (streaming pipeline plan §16 scrubber-offset patch 2026-05-08).
  ///
  /// When `start_stream` / `restart_stream` snap the requested seek to
  /// a segment boundary (`floor(seek / hls_time) * hls_time`), the
  /// player's reported playback position is relative to that snap, not
  /// to t=0 of the source file.  Add this value to the engine's
  /// reported position when rendering the scrubber so the user sees
  /// source-time, not playlist-time (otherwise: forward-seek looks
  /// like "scrubber reset to 0" because the new playlist's t=0 is the
  /// seek target's segment boundary).
  final double playlistOffsetSec;

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
  /// the user understands why playback paused.  Distinct from the
  /// engine's own buffering signal because the server restart needs ≥1
  /// segment of wall-time to produce its first new segment, which is a
  /// longer gap than the player's normal buffer-fill animation can
  /// explain.
  final bool isSeeking;

  /// Plan 22 — every audio track exposed by the source container, as
  /// returned by `/stream/start`.  Drives the Audio bottom-sheet
  /// picker.  Empty list (pre-plan-22 server) means the picker greys
  /// out; single-entry list also greys out per behavior matrix ("UI
  /// hides picker when only one track").
  final List<AudioTrackInfo> availableAudioTracks;

  /// Plan 22 — the source stream index (`AudioTrackInfo.index`) of the
  /// currently-selected audio track.  Defaults to 0 — FFmpeg's first
  /// audio track, which matches the server's "default track 0" rule.
  /// Updated via [PlayerCubit.selectAudioTrack].  Per-session only —
  /// next playback resets to 0 (sharp edge #4).
  final int selectedAudioTrackIndex;

  /// True when the source is HDR.  Convenience alias.
  bool get isHdrSource => hdrFormat != null && hdrFormat!.isNotEmpty;

  /// Flutter texture id the player screen should embed.  For the
  /// MediaKitEngine path this round-trips through
  /// `VideoController.id.value`; for the future ExoPlayerEngine path
  /// it's the `SurfaceProducer`-issued id.  Null while the engine is
  /// initialising.
  int? get textureId => engine.textureId;

  PlayerReady copyWith({
    StreamPath? streamPath,
    bool? isSeeking,
    double? playlistOffsetSec,
    List<AudioTrackInfo>? availableAudioTracks,
    int? selectedAudioTrackIndex,
  }) => PlayerReady(
    sessionId: sessionId,
    fileName: fileName,
    engine: engine,
    resumeSec: resumeSec,
    playlistOffsetSec: playlistOffsetSec ?? this.playlistOffsetSec,
    streamPath: streamPath ?? this.streamPath,
    hdrFormat: hdrFormat,
    tonemapped: tonemapped,
    isSeeking: isSeeking ?? this.isSeeking,
    availableAudioTracks: availableAudioTracks ?? this.availableAudioTracks,
    selectedAudioTrackIndex:
        selectedAudioTrackIndex ?? this.selectedAudioTrackIndex,
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

/// The server rejected the stream start because a Client Group restriction
/// applies — the file's library isn't on this client's allowlist, or the
/// current time is outside the group's allowed streaming window.
///
/// [reason] carries the server-supplied detail string verbatim so the UI
/// can surface it.  Distinct from [PlayerFailure] so the player screen
/// renders a soft "this isn't available right now" card instead of an
/// alarming error — a gate is not a bug.  Pattern mirrors [PlayerTierLimit]
/// which is the v1 precedent for "not an error, but you can't play this".
class PlayerGated extends PlayerState {
  const PlayerGated(this.reason);
  final String reason;
}
