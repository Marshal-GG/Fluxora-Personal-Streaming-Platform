/// `FluxoraAudioHandler` — bridges the [media_kit](https://pub.dev/packages/media_kit)
/// `Player` to the OS [MediaSession] (Android) / `MPNowPlayingInfoCenter`
/// (iOS) via the [audio_service] package.
///
/// Player polish round (2026-05-04).  Lights up:
///   - Lockscreen / shade / notification transport controls (play/pause,
///     seek, skip — though we don't have a queue so skip is hidden).
///   - Bluetooth-headset / wired-headset media-button events.
///   - A persistent foreground service on Android so the OS won't kill
///     the process while the user is in another app and audio is still
///     playing.
///
/// **Architecture — sidecar, not subclass.**  [PlayerCubit] keeps owning
/// its [Player]; this handler holds a *weak* reference to the same
/// instance, observes its event streams, and forwards state into
/// audio_service's [PlaybackState] + [MediaItem] sinks.  When the OS
/// fires a transport command (play / pause / seek), we delegate back to
/// the same Player.  Both sides write through the same Player, so
/// there's no consistency state to reconcile.
///
/// The cubit calls [bind] after a successful `startStream` and [detach]
/// from `dismiss`.  Multiple binds (a new file plays while one is already
/// loaded) cleanly replace the previous subscription.
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart' show Player;

class FluxoraAudioHandler extends BaseAudioHandler with SeekHandler {
  FluxoraAudioHandler();

  static final _log = Logger();

  Player? _player;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _bufferedSub;
  StreamSubscription<bool>? _completedSub;

  /// Hook a freshly-opened [Player] up to the OS media session.  The
  /// caller is responsible for calling [detach] before the player is
  /// disposed — otherwise our stream subscriptions hold a reference and
  /// the player can't be GC'd.
  Future<void> bind({
    required Player player,
    required String id,
    required String title,
    String? album,
    String? artUri,
  }) async {
    await detach();
    _player = player;

    mediaItem.add(MediaItem(
      id: id,
      title: title,
      album: album,
      artUri: artUri == null ? null : Uri.tryParse(artUri),
      // We don't always know duration up-front — pushed via the duration
      // subscription below as soon as media_kit reports it.
    ));

    // Initial state — the player just opened, so it's loading.  audio_service
    // expects an explicit state push before the first user-driven command.
    playbackState.add(PlaybackState(
      controls: const [MediaControl.pause],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      processingState: AudioProcessingState.loading,
      playing: player.state.playing,
      updatePosition: player.state.position,
    ));

    _playingSub = player.stream.playing.listen(_onPlayingChanged);
    _positionSub = player.stream.position.listen(_onPositionChanged);
    _durationSub = player.stream.duration.listen(_onDurationChanged);
    _bufferedSub = player.stream.buffer.listen(_onBufferedChanged);
    _completedSub = player.stream.completed.listen(_onCompletedChanged);
  }

  /// Drop the current Player binding and reset the OS session.  Safe to
  /// call when there's nothing bound — every cancel is null-guarded.
  Future<void> detach() async {
    await _playingSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _bufferedSub?.cancel();
    await _completedSub?.cancel();
    _playingSub = null;
    _positionSub = null;
    _durationSub = null;
    _bufferedSub = null;
    _completedSub = null;
    _player = null;
    // Push an idle state so the lockscreen card disappears.
    playbackState.add(PlaybackState(
      controls: const [],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  // ── Player → MediaSession ─────────────────────────────────────────────────

  void _onPlayingChanged(bool playing) {
    final controls = playing
        ? const [MediaControl.pause]
        : const [MediaControl.play];
    playbackState.add(playbackState.value.copyWith(
      controls: controls,
      playing: playing,
      processingState: AudioProcessingState.ready,
    ));
  }

  void _onPositionChanged(Duration position) {
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
  }

  void _onDurationChanged(Duration duration) {
    final current = mediaItem.value;
    if (current != null && current.duration != duration) {
      mediaItem.add(current.copyWith(duration: duration));
    }
  }

  void _onBufferedChanged(Duration buffered) {
    playbackState.add(playbackState.value.copyWith(
      bufferedPosition: buffered,
    ));
  }

  void _onCompletedChanged(bool completed) {
    if (!completed) return;
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.completed,
      playing: false,
    ));
  }

  // ── MediaSession → Player ─────────────────────────────────────────────────

  @override
  Future<void> play() async {
    final p = _player;
    if (p == null) return;
    try {
      await p.play();
    } catch (e, st) {
      _log.w('AudioHandler.play() forward to Player failed',
          error: e, stackTrace: st);
    }
  }

  @override
  Future<void> pause() async {
    final p = _player;
    if (p == null) return;
    try {
      await p.pause();
    } catch (e, st) {
      _log.w('AudioHandler.pause() forward to Player failed',
          error: e, stackTrace: st);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    final p = _player;
    if (p == null) return;
    try {
      await p.seek(position);
    } catch (e, st) {
      _log.w('AudioHandler.seek() forward to Player failed',
          error: e, stackTrace: st);
    }
  }

  @override
  Future<void> stop() async {
    final p = _player;
    if (p != null) {
      try {
        await p.pause();
      } catch (_) {
        // Stop is idempotent — failures here are not actionable.
      }
    }
    await detach();
    await super.stop();
  }
}
