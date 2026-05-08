import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart' show Media, Player, PlayerConfiguration;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_core/network/network_path_detector.dart';
import 'package:fluxora_mobile/features/player/data/services/fluxora_audio_handler.dart';
import 'package:fluxora_mobile/features/player/data/services/webrtc_signaling_service.dart';
import 'package:fluxora_mobile/features/player/domain/repositories/player_repository.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';

/// Function-typed connectivity probe — defaults to
/// `Connectivity().checkConnectivity()` in production but can be
/// substituted in tests so the cubit doesn't depend on a real network
/// interface.  Mobile-settings remediation plan §M3 follow-up
/// (Wi-Fi-only enforcement).
typedef ConnectivityChecker = Future<List<ConnectivityResult>> Function();

/// libmpv demuxer cache cap (streaming pipeline plan §16 M3).  Default
/// is 32 MB which gates first-frame latency on 3-5 segments worth of
/// readahead — visible to the user as a "Loading…" spinner of 18-30 s
/// on transcode sessions.  4 MB still buffers ~3 segments at typical
/// 1080p HEVC bitrate (≈8 Mbps) but lets playback start as soon as
/// libmpv has decoded the first segment's first GOP.  Trade-off: a
/// >2 s network stall mid-playback will rebuffer instead of riding
/// through; acceptable on LAN where stalls are rare.
const int _kPlayerBufferBytes = 4 * 1024 * 1024;

/// How often (in seconds) the cubit reports playback progress to the server.
const _kProgressIntervalSec = 10;

/// How long to wait for WebRTC ICE to connect before falling back to HLS.
const _kWebRtcTimeoutSec = 8;

/// Seek-restart threshold.  Forward seeks at or above this delta go
/// through the server (POST /seek → FFmpeg restart from the new
/// timestamp); smaller forward seeks AND any backward seek stay
/// in-player.  Backward is always safe in-player because the segments
/// already exist on disk; small forward seeks fit inside the player's
/// buffer + the HLS router's 5 s segment-wait.  5 s is intentionally
/// conservative — bumping after field reports is cheap, but a too-large
/// threshold leaves the user staring at a 404 retry storm.
const _kSeekRestartThresholdSec = 5;

/// Debounce window for seek-bar drag events.  Multiple `seekTo` calls
/// within this window collapse into one server restart at the final
/// position — without this, the user dragging the scrubber from 0:30 →
/// 5:00 would trigger 30+ FFmpeg restarts as the drag progresses.  300 ms
/// matches Material's drag-end throttle and is short enough that the
/// user perceives "I let go and it seeked" rather than a lag.
const _kSeekDebounceMs = 300;

class PlayerCubit extends Cubit<PlayerState> {
  PlayerCubit({
    required PlayerRepository repository,
    required SecureStorage secureStorage,
    FluxoraAudioHandler? audioHandler,
    ConnectivityChecker? connectivityChecker,
  })  : _repository = repository,
        _secureStorage = secureStorage,
        _audioHandler = audioHandler,
        _checkConnectivity =
            connectivityChecker ?? Connectivity().checkConnectivity,
        super(const PlayerInitial()) {
    _lifecycleObserver = _PlayerLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  final PlayerRepository _repository;
  final SecureStorage _secureStorage;
  final ConnectivityChecker _checkConnectivity;

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

  // Cached playlist URL — needed by the seek-restart path to re-open the
  // same Media on libmpv (the server rewrites the playlist contents in
  // place; clients that loaded the old VOD list need an explicit re-open
  // to pick up the new media-sequence + discontinuity markers).
  String? _lastPlaylistUrl;
  Map<String, String>? _lastPlaylistHeaders;

  // Seek-restart debounce.  Coalesces a drag-bar's many in-flight position
  // updates into a single server restart at the final position.
  Timer? _seekDebounceTimer;
  Duration? _pendingSeekTarget;

  // ---------------------------------------------------------------------------
  // Public
  // ---------------------------------------------------------------------------

  /// Wi-Fi-only-mode gate (settings remediation plan §M3).  Returns
  /// `true` when the user has Wi-Fi-only on AND the device is currently
  /// on cellular without a Wi-Fi link.  Connectivity-probe failures
  /// fail-open (return `false`) — a permission glitch on the
  /// connectivity API shouldn't trap the user with no playback.
  Future<bool> _shouldRefuseOverCellular() async {
    try {
      final wifiOnly = await _secureStorage.getWifiOnlyStreaming();
      if (!wifiOnly) return false;
      final results = await _checkConnectivity();
      final hasWifi = results.contains(ConnectivityResult.wifi);
      final hasMobile = results.contains(ConnectivityResult.mobile);
      return hasMobile && !hasWifi;
    } catch (e, st) {
      _log.w('[Player] Wi-Fi-only check failed — allowing stream',
          error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> startStream(
    String fileId,
    String fileName,
    double resumeSec, {
    String? posterUrl,
    bool tonemap = false,
    double? serverSeekSec,
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

    // Wi-Fi-only enforcement (settings remediation plan §M3 follow-up).
    // The pref is set in Profile → Playback → Wi-Fi only streaming and
    // persisted in SecureStorage.  When on, refuse to start a stream
    // over cellular.  Failure is non-fatal in the sense that the user
    // can flip the toggle off and try again — the gate is intentional,
    // not a hard error.
    if (await _shouldRefuseOverCellular()) {
      emit(const PlayerFailure(
        'Wi-Fi only mode is on. Connect to Wi-Fi to start streaming, or '
        'turn it off in Profile → Playback.',
      ));
      return;
    }

    emit(const PlayerLoading());
    try {
      // Pass `serverSeekSec` through when present (HDR-toggle path knows
      // the live playhead more precisely than the DB).  Server falls
      // back to `media_files.last_progress_sec` when omitted (initial-
      // play resume path) — streaming pipeline plan §16 M1.
      final response = await _repository.startStream(
        fileId,
        tonemap: tonemap,
        seekSec: serverSeekSec,
      );
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

      _player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: _kPlayerBufferBytes,
        ),
      );
      _controller = VideoController(_player!);
      _lastPlaylistUrl = response.playlistUrl;
      _lastPlaylistHeaders = headers;
      await _player!.open(Media(response.playlistUrl, httpHeaders: headers));

      // No client-side `player.seek(...)` here.  The server now lands
      // FFmpeg at the resume position via `-ss` (streaming pipeline
      // plan §16 M1) and shifts the static VOD playlist's media-
      // sequence accordingly so segment 0 of the playlist IS the
      // segment containing the resume timestamp.  A post-open seek
      // would race the initial buffer fill and either be a no-op or
      // throw libmpv into a 404-retry loop on a not-yet-encoded
      // segment.
      final seekSec = response.resumeSec > 0 ? response.resumeSec : resumeSec;

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
        // Server-supplied: the segment-snapped source-time at which
        // the playlist's t=0 sits.  The scrubber adds this to the
        // player's reported position so the user sees source-time
        // (streaming pipeline plan §16 scrubber-offset patch).
        playlistOffsetSec: response.appliedSeekSec,
        streamPath: path,
        hdrFormat: response.hdrFormat,
        tonemapped: response.tonemapped,
      ));

      // Streaming pipeline plan §16 M4 — diagnostics only.  libmpv
      // populates `audioParams` after the first audio frame decodes
      // (typically a few hundred ms post-open).  Subscribe to the
      // stream, log the FIRST non-empty value so an operator
      // diagnosing AV-sync issues can grep for `audio_negotiated`
      // and pair it with the server's `audio_probe` line.  Stream is
      // torn down by `_disposeCurrentSession` so we don't bother
      // canceling the subscription manually.
      _player!.stream.audioParams.firstWhere(
        (p) => p.sampleRate != null || p.channelCount != null,
        orElse: () => _player!.state.audioParams,
      ).then((p) {
        _log.i(
          '[Player] audio_negotiated session=${response.sessionId} '
          'format=${p.format} sample_rate=${p.sampleRate} '
          'channels=${p.channels} channel_count=${p.channelCount}',
        );
      }).catchError((Object e, StackTrace st) {
        _log.d('audioParams subscription failed', error: e, stackTrace: st);
      });

      _startProgressTimer();
    } on ApiException catch (e, st) {
      if (e.isTierLimit) {
        _log.w('[Player] Stream concurrency limit reached (429)');
        emit(const PlayerTierLimit());
      } else if (e.isForbidden && _isGroupGateMessage(e.message)) {
        // 403 + one of the known group-gate strings emitted by
        // `services/group_service.reason_to_deny` server-side.  Bubble
        // up the reason verbatim so the UI can render the operator's
        // own copy ("Outside the allowed streaming time window") rather
        // than a generic "Stream failed".  Other 403s (auth issues,
        // tunneled-from-LAN admin endpoints) still fall through to
        // PlayerFailure — group-gate matching is conservative.
        _log.i('[Player] Group gate denied stream: ${e.message}');
        emit(PlayerGated(e.message));
      } else {
        _log.e('Failed to start stream', error: e, stackTrace: st);
        emit(PlayerFailure(e.message));
      }
    } catch (e, st) {
      _log.e('Failed to start stream', error: e, stackTrace: st);
      emit(const PlayerFailure('Failed to start stream. Please try again.'));
    }
  }

  /// Match the server's group-gate detail strings (see
  /// `apps/server/services/group_service.reason_to_deny`).  Substring
  /// match keeps us tolerant of a future agent rewording the messages
  /// without changing intent — both phrases use distinctive markers
  /// ("group(s)" / "time window") that are unlikely to appear in
  /// unrelated 403 responses.
  static bool _isGroupGateMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('group(s)') ||
        lower.contains('time window');
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
    // Pass the live playhead as `serverSeekSec` so the new FFmpeg
    // session lands at the toggle's actual position — not the DB's
    // `last_progress_sec` (which lags by up to 5 s due to the
    // progress-write throttle).  Streaming pipeline plan §16 M1.
    await startStream(
      fileId,
      fileName,
      resumeSec,
      posterUrl: _lastPosterUrl,
      tonemap: enabled,
      serverSeekSec: resumeSec > 0 ? resumeSec : null,
    );
  }

  /// Seek the active stream to [position].
  ///
  /// Two paths, picked by the size of the seek delta:
  ///
  /// - **Backward seek**, or **forward seek under [_kSeekRestartThresholdSec]**:
  ///   handled in the player.  Backward is always safe — segments are
  ///   already on disk and libmpv seeks within its loaded data.  Small
  ///   forward seeks fit inside the player's prefetch buffer plus the
  ///   server's 5 s segment-wait absorbing a brief miss.
  /// - **Forward seek at or above the threshold**: server-side restart.
  ///   The current FFmpeg only ever encodes from t=0 (or wherever the
  ///   last restart left it), so a far-ahead seek lands in territory it
  ///   has not produced yet.  The cubit pauses the player, POSTs to
  ///   `/seek`, re-opens the same playlist URL (libmpv has cached the
  ///   VOD list and won't re-fetch on its own), seeks within the new
  ///   playlist to [position], and resumes.
  ///
  /// Server-restart calls debounce by [_kSeekDebounceMs] so a seek-bar
  /// drag fires exactly one restart at the final position.  No-op when
  /// no session is active.  Failures fall back to in-player seek so the
  /// drag never feels totally dead.
  Future<void> seekTo(Duration position) async {
    final p = _player;
    final currentState = state;
    if (p == null || currentState is! PlayerReady) return;
    if (position.isNegative) position = Duration.zero;

    // Source-time vs player-time bookkeeping (streaming pipeline plan
    // §16 scrubber-offset patch).  `position` is the user's target in
    // SOURCE time (what the scrubber shows).  libmpv's reported
    // position runs in PLAYER time which is offset by
    // `playlistOffsetSec` when a seek-restart has shifted the playlist.
    // Compute the delta in source-time for the threshold compare; pass
    // player-time to `p.seek` since libmpv operates in playlist-local
    // coordinates.
    final offsetMs = (currentState.playlistOffsetSec * 1000).toInt();
    final currentPlayerMs = p.state.position.inMilliseconds;
    final currentSourceMs = currentPlayerMs + offsetMs;
    final targetSourceMs = position.inMilliseconds;
    final deltaMs = targetSourceMs - currentSourceMs;

    // Backward seek + small forward seek → in-player; cancel any
    // in-flight server-restart debounce so we don't double-act.
    if (deltaMs < _kSeekRestartThresholdSec * 1000) {
      _seekDebounceTimer?.cancel();
      _seekDebounceTimer = null;
      _pendingSeekTarget = null;
      try {
        // Convert source-time target back to player-time before passing
        // to libmpv.  Clamp at zero — small backward seeks below the
        // current playlist's t=0 would wrap; clamp to the playlist start
        // so libmpv doesn't error.  (For seeks outside the loaded
        // playlist's range, the seek-restart path above handles it.)
        final playerTargetMs = (targetSourceMs - offsetMs).clamp(
          0,
          // Cap at a very large value; libmpv will clamp to actual
          // playlist length itself.
          1 << 30,
        );
        await p.seek(Duration(milliseconds: playerTargetMs));
      } catch (e, st) {
        _log.w('In-player seek failed', error: e, stackTrace: st);
      }
      return;
    }

    // Server-restart path: debounce drag-end events, store the latest
    // target.  When the timer fires we read whatever the most-recent
    // target was, so a slow drag from 0:30 → 5:00 ends up calling
    // _commitServerSeek(5:00) once instead of N times.
    _pendingSeekTarget = position;
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = Timer(
      const Duration(milliseconds: _kSeekDebounceMs),
      () {
        final target = _pendingSeekTarget;
        if (target != null) {
          _pendingSeekTarget = null;
          _commitServerSeek(target);
        }
      },
    );
  }

  /// Backing implementation for the server-restart path of [seekTo].
  ///
  /// Pre-conditions verified at call time: a `Player` exists, a session
  /// is active, and the playlist URL was cached at start_stream time.
  /// All three are immutable for the duration of a session, so the
  /// happy path never recovers from a missing prerequisite — instead
  /// it logs and falls back to an in-player seek so playback isn't
  /// completely dead.
  Future<void> _commitServerSeek(Duration target) async {
    final p = _player;
    final sid = _sessionId;
    final url = _lastPlaylistUrl;
    final headers = _lastPlaylistHeaders;
    final currentState = state;
    if (p == null || sid == null || url == null || currentState is! PlayerReady) {
      return;
    }

    emit(currentState.copyWith(isSeeking: true));
    try {
      await p.pause();
      // Server returns the segment-snapped value it actually applied
      // (`applied_seek_sec` from the response body) — the cubit uses
      // this as the new `_playlistOffsetSec` so the scrubber displays
      // source-time after the restart instead of playlist-time
      // (streaming pipeline plan §16 scrubber-offset patch).
      final appliedSeekSec = await _repository.seekStream(
        sid,
        target.inMilliseconds / 1000.0,
        tonemap: currentState.tonemapped,
      );

      // Re-open the SAME playlist URL.  The server has rewritten
      // playlist.m3u8 in place (new media-sequence + discontinuity
      // marker); libmpv won't re-fetch on its own because the original
      // load saw `#EXT-X-ENDLIST` and considers VOD playlists immutable.
      // Re-opening the Media forces a fresh GET.
      await p.open(
        Media(url, httpHeaders: headers ?? const {}),
        play: false,
      );
      // The new playlist starts at `appliedSeekSec` of source-time
      // (segment-snapped by the server).  Seek WITHIN the playlist to
      // the sub-segment offset between the user's exact target and the
      // segment boundary.  Was previously `await p.seek(target)` which
      // tried to seek to source-time T inside a playlist whose own
      // timeline runs 0..(N-K)*hls_time — libmpv would either clamp
      // or reset, manifesting as "scrubber jumps back to 0".
      final withinPlaylistSec =
          target.inMilliseconds / 1000.0 - appliedSeekSec;
      if (withinPlaylistSec > 0) {
        await p.seek(
          Duration(milliseconds: (withinPlaylistSec * 1000).toInt()),
        );
      }
      await p.play();
      emit(currentState.copyWith(
        isSeeking: false,
        playlistOffsetSec: appliedSeekSec,
      ));
    } catch (e, st) {
      _log.w(
        'Server seek-restart failed; falling back to in-player seek',
        error: e,
        stackTrace: st,
      );
      try {
        await p.seek(target);
        await p.play();
      } catch (e2, st2) {
        _log.w('In-player fallback seek also failed',
            error: e2, stackTrace: st2);
      }
      // Drop the seeking flag whether the fallback worked or not — the
      // overlay should not stay up forever on a hard failure.
      if (state is PlayerReady) {
        emit((state as PlayerReady).copyWith(isSeeking: false));
      }
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

  /// Tear down the current playback session (timer / progress / signaling /
  /// `Player`) and clear the local references. Safe to call when nothing is
  /// playing — every step is null-guarded. Used by both `startStream`
  /// (when a long-lived singleton replaces an existing session) and
  /// [dismiss] (explicit "stop and forget" from the mini-player X button).
  Future<void> _disposeCurrentSession() async {
    _progressTimer?.cancel();
    _progressTimer = null;
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = null;
    _pendingSeekTarget = null;
    _lastPlaylistUrl = null;
    _lastPlaylistHeaders = null;
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
  void emit(PlayerState state) {
    if (isClosed) return;
    super.emit(state);
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
