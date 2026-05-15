import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import 'package:media_kit/media_kit.dart' show AudioParams, VideoParams;
import 'package:fluxora_core/fluxora_core.dart';
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

/// Factory function for the playback engine.  Default points at
/// [PlayerEngineFactory.create] in production; unit tests substitute a
/// fake so the cubit can run headlessly without instantiating libmpv.
typedef PlayerEngineBuilder = Future<PlayerEngine> Function();

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

/// How long (in seconds) the auto-fallback watcher listens for libmpv
/// `error` events after `PlayerReady` is emitted.  Six seconds covers
/// the worst-case "device-cannot-decode" window — libmpv typically
/// emits the error within ~1 s of the first segment download
/// completing, but slower handsets / WAN paths can lag.  Picked to
/// match plan 20's "first 6 s" wording.
const _kFallbackWatcherSec = 6;

/// Plan 21 — how long the audio watcher waits for the FIRST non-empty
/// `audioParams` emission before treating silence as a stream-copied
/// audio decode failure.  libmpv populates `audioParams` after it
/// successfully decodes the first audio frame; if nothing has arrived
/// inside this window we assume the source codec is unsupported and
/// flip to server-side audio transcode.  4 s is tighter than the
/// outer 6 s watcher window so the silent-audio path can fire before
/// the watcher disarms.
const _kAudioParamsTimeoutSec = 4;

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
    PlayerEngineBuilder? engineBuilder,
  }) : _repository = repository,
       _secureStorage = secureStorage,
       _audioHandler = audioHandler,
       _checkConnectivity =
           connectivityChecker ?? Connectivity().checkConnectivity,
       _engineBuilder = engineBuilder ?? PlayerEngineFactory.create,
       super(const PlayerInitial()) {
    _lifecycleObserver = _PlayerLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  final PlayerRepository _repository;
  final SecureStorage _secureStorage;
  final ConnectivityChecker _checkConnectivity;
  final PlayerEngineBuilder _engineBuilder;

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

  PlayerEngine? _engine;
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
  // same Media on the engine (the server rewrites the playlist contents
  // in place; clients that loaded the old VOD list need an explicit re-
  // open to pick up the new media-sequence + discontinuity markers).
  String? _lastPlaylistUrl;
  Map<String, String>? _lastPlaylistHeaders;

  // Seek-restart debounce.  Coalesces a drag-bar's many in-flight position
  // updates into a single server restart at the final position.
  Timer? _seekDebounceTimer;
  Duration? _pendingSeekTarget;

  // Plan 20 — auto-mode client-error fallback watcher.  When the global
  // `streaming_mode` is `auto`, the server starts the session in stream-
  // copy mode.  If the device can't decode the source codec, the engine
  // emits an error within the first few seconds; we POST to
  // `/fallback-transcode` so the server re-spawns FFmpeg in transcode
  // mode, then re-open the playlist.  Watcher cancels on first non-empty
  // `videoParams` (proof of a successful decode) OR on the 6 s timer.
  // `_fallbackTriggered` is a one-shot latch so a noisy error stream
  // doesn't fire the POST twice.
  StreamSubscription<EngineErrorEvent>? _fallbackWatcherSub;
  Timer? _fallbackWatcherTimer;
  bool _fallbackTriggered = false;

  // Plan 21 — auto-mode client-side audio fallback watcher.  Runs
  // INDEPENDENTLY of the video watcher above so a session can recover
  // a stream-copied audio failure even when the video leg decodes
  // fine.  Two parallel detectors per plan 21 sharp edge #1:
  //   1. Engine error events whose message contains `audio` / `aac` /
  //      `codec` (case-insensitive).
  //   2. A 4 s silence-watchdog over libmpv's `audioParams` stream
  //      (only available on the MediaKitEngine path — ExoPlayerEngine
  //      reports the same condition through its native error stream
  //      and detector 1 covers it there).
  // Cancels on first non-empty `audioParams` emission (proves audio
  // is live).  `_audioFallbackTriggered` is a one-shot latch so a
  // noisy error stream can't fire the POST twice.
  StreamSubscription<EngineErrorEvent>? _audioFallbackWatcherErrorSub;
  StreamSubscription<AudioParams>? _audioFallbackWatcherParamsSub;
  Timer? _audioFallbackWatcherTimer;
  Timer? _audioFallbackParamsTimeoutTimer;
  bool _audioFallbackTriggered = false;

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
      _log.w(
        '[Player] Wi-Fi-only check failed — allowing stream',
        error: e,
        stackTrace: st,
      );
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

    // Plan 20 — reset the one-shot auto-fallback latch.  Each new stream
    // gets its own 6 s probe window.
    _fallbackTriggered = false;
    // Plan 21 — same reset for the audio-leg latch.  Independent of the
    // video latch above so both watchers can fire on the same session
    // when the source happens to have both an unsupported video codec
    // AND an unsupported audio codec.
    _audioFallbackTriggered = false;

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
      emit(
        const PlayerFailure(
          'Wi-Fi only mode is on. Connect to Wi-Fi to start streaming, or '
          'turn it off in Profile → Playback.',
        ),
      );
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

      // HLS path is always the media source for the engine regardless of
      // the signaling path, since the WebRTC data-channel streaming
      // layer isn't complete yet.  The `streamPath` field signals to the
      // UI which transport is active so it can display the correct badge.
      final headers = token != null
          ? <String, String>{'Authorization': 'Bearer $token'}
          : <String, String>{};

      // Plan 24 M2 — engine construction is delegated to the factory
      // which today always picks `MediaKitEngine` regardless of
      // platform.  M3 will branch in `PlayerEngineFactory.create` so
      // Android gets `ExoPlayerEngine` instead, without touching this
      // cubit.  The Android-only `ao=audiotrack` libmpv property
      // override moved into `MediaKitEngine.create` along with the
      // shared buffer-size constant.
      final engine = await _engineBuilder();
      _engine = engine;

      _lastPlaylistUrl = response.playlistUrl;
      _lastPlaylistHeaders = headers;
      await engine.open(response.playlistUrl, headers: headers);

      // No client-side `engine.seek(...)` here.  The server now lands
      // FFmpeg at the resume position via `-ss` (streaming pipeline
      // plan §16 M1) and shifts the static VOD playlist's media-
      // sequence accordingly so segment 0 of the playlist IS the
      // segment containing the resume timestamp.  A post-open seek
      // would race the initial buffer fill and either be a no-op or
      // throw the engine into a 404-retry loop on a not-yet-encoded
      // segment.
      final seekSec = response.resumeSec > 0 ? response.resumeSec : resumeSec;

      // Hook the OS media session (lockscreen / notification card / BT
      // headset).  Best-effort — if audio_service hasn't initialised
      // (unit tests, embedded preview) this is a no-op.
      //
      // Plan 24 M7 — gate to MediaKitEngine only.  The
      // `FluxoraAudioHandler` binds to a `media_kit.Player` directly,
      // so it's only valid on that engine path.  On the
      // `ExoPlayerEngine` path the Kotlin-side
      // `FluxoraMediaSessionService` owns the OS media session via
      // Media3's first-party `MediaSession.Builder(this, exoPlayer)`,
      // which wires every transport command back into ExoPlayer
      // automatically.  Binding the audio_service handler on top would
      // produce two competing sessions fighting for audio focus and
      // the lockscreen card would flicker between them.
      if (engine is MediaKitEngine) {
        try {
          await _audioHandler?.bind(
            player: engine.mediaKitPlayer,
            id: fileId,
            title: fileName,
            artUri: posterUrl,
          );
        } catch (e, st) {
          _log.w('AudioHandler.bind failed', error: e, stackTrace: st);
        }
      } else {
        // ExoPlayerEngine — Media3's `FluxoraMediaSessionService` owns
        // the OS MediaSession natively; the Dart handler is skipped.
        _log.d(
          '[Player] OS media session owned natively by Media3 '
          '(engine=${engine.runtimeType}); Dart audio handler skipped',
        );
      }

      emit(
        PlayerReady(
          sessionId: response.sessionId,
          fileName: fileName,
          engine: engine,
          resumeSec: seekSec,
          // Server-supplied: the segment-snapped source-time at which
          // the playlist's t=0 sits.  The scrubber adds this to the
          // player's reported position so the user sees source-time
          // (streaming pipeline plan §16 scrubber-offset patch).
          playlistOffsetSec: response.appliedSeekSec,
          streamPath: path,
          hdrFormat: response.hdrFormat,
          tonemapped: response.tonemapped,
          // Plan 22 — multi-audio-track support.  Server returns every
          // audio track in the source container; default selection is
          // FFmpeg's track 0 (the first audio stream), matching the
          // server's `-map 0:a?` ordering.  Operator can switch via
          // [selectAudioTrack] which only changes the decoded track —
          // no server round-trip.
          availableAudioTracks: response.audioTracks,
          selectedAudioTrackIndex: response.audioTracks.isNotEmpty
              ? response.audioTracks.first.index
              : 0,
        ),
      );

      // Plan 20 — auto-fallback watcher only fires when the operator has
      // opted into `streaming_mode='auto'`.  Strict `'client-decode'` is
      // documented as "modern devices only" and `'server-transcode'` is
      // already transcoding, so the watcher would be a no-op in both
      // cases; arming it would race a successful playback against a
      // misleading fallback POST that the server rejects with 409.
      if (response.streamingMode == 'auto') {
        _scheduleAutoFallbackWatcher(
          sessionId: response.sessionId,
          streamPath: response.playlistUrl,
          headers: headers,
        );
      }

      // Plan 21 — audio-leg watcher.  Runs independently of the video
      // watcher above, but only when BOTH `streamingMode='auto'` AND
      // `audioStreamingMode='stream-copy'`.  `'transcode'` audio is
      // already going through the encoder so a client-side audio
      // decode failure can't happen; `'client-decode'`/
      // `'server-transcode'` video modes are out of the auto-fallback
      // contract entirely.  The 6 s outer watcher + 4 s audioParams
      // silence-watchdog both live inside _scheduleAutoAudioFallback
      // Watcher.
      if (response.streamingMode == 'auto' &&
          response.audioStreamingMode == 'stream-copy') {
        _scheduleAutoAudioFallbackWatcher(
          sessionId: response.sessionId,
          streamPath: response.playlistUrl,
          headers: headers,
        );
      }

      // Streaming pipeline plan §16 M4 — diagnostics only.  libmpv
      // populates `audioParams` after the first audio frame decodes
      // (typically a few hundred ms post-open).  Subscribe to the
      // stream, log the FIRST non-empty value so an operator
      // diagnosing AV-sync issues can grep for `audio_negotiated`
      // and pair it with the server's `audio_probe` line.  Stream is
      // torn down by `_disposeCurrentSession` so we don't bother
      // canceling the subscription manually.  Only meaningful on the
      // MediaKitEngine path — libmpv-specific.
      if (engine is MediaKitEngine) {
        final mk = engine.mediaKitPlayer;
        mk.stream.audioParams
            .firstWhere(
              (p) => p.sampleRate != null || p.channelCount != null,
              orElse: () => mk.state.audioParams,
            )
            .then((p) {
              _log.i(
                '[Player] audio_negotiated session=${response.sessionId} '
                'format=${p.format} sample_rate=${p.sampleRate} '
                'channels=${p.channels} channel_count=${p.channelCount}',
              );
            })
            .catchError((Object e, StackTrace st) {
              _log.d(
                'audioParams subscription failed',
                error: e,
                stackTrace: st,
              );
            });
      }

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
    return lower.contains('group(s)') || lower.contains('time window');
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
    final currentMs = _engine?.position.inMilliseconds ?? 0;
    final fallbackSec = currentState is PlayerReady
        ? currentState.resumeSec
        : 0.0;
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

  /// Switch the active session's audio track to the one whose source
  /// stream index matches [sourceIndex] (i.e. [AudioTrackInfo.index]).
  ///
  /// Plan 23 — server-restart switching.  Every client-side approach
  /// we tried (bare setAudioTrack, pause+swap+seek+play, self-seek,
  /// 1-s-back seek, ao=audiotrack) hit the same wall: libmpv-on-
  /// Android can't reliably swap audio decoders mid-stream against a
  /// multi-track fmp4 init.  Going server-side means the respawned
  /// FFmpeg only emits ONE audio track, so the engine never has to
  /// switch — it just opens a fresh stream with the desired track
  /// already selected.  ~2 s visible gap (server restart + buffer
  /// fill); rock-solid in exchange.
  ///
  /// Plan 24 follow-up — when M3 ships ExoPlayerEngine, Android moves
  /// to native client-side switching via TrackSelectionParameters and
  /// the server-restart path becomes a fallback for clients without
  /// native track support.
  ///
  /// No-op when there is no active session.  Failures from the
  /// engine (track index out of range, decoder error) log and DO NOT
  /// update state — the picker UI's checkmark stays on the previous
  /// track so the operator sees that the switch didn't take.
  Future<void> selectAudioTrack(int sourceIndex) async {
    final engine = _engine;
    final currentState = state;
    if (engine == null || currentState is! PlayerReady) {
      _log.d('[Player] selectAudioTrack($sourceIndex) — no active session');
      return;
    }

    // Find the matching entry in the cubit's own track list first so we
    // can log meaningful track metadata if the engine call fails.
    final tracks = currentState.availableAudioTracks;
    final trackInfoIdx = tracks.indexWhere((t) => t.index == sourceIndex);
    if (trackInfoIdx < 0) {
      _log.w(
        '[Player] selectAudioTrack($sourceIndex) — index not in '
        'availableAudioTracks (size=${tracks.length})',
      );
      return;
    }
    final trackInfo = tracks[trackInfoIdx];

    final currentPositionSec = engine.position.inMilliseconds / 1000.0;
    final wasPlaying = engine.isPlaying;
    final headers = _lastPlaylistHeaders ?? const <String, String>{};
    try {
      final appliedSeek = await _repository.switchAudioTrack(
        sessionId: currentState.sessionId,
        index: sourceIndex,
        currentPositionSec: currentPositionSec,
      );
      _log.i(
        '[Player] audio_track_switched session=${currentState.sessionId} '
        'source_index=$sourceIndex codec=${trackInfo.codec} '
        'channels=${trackInfo.channels} language=${trackInfo.language} '
        'applied_seek_sec=$appliedSeek (server-restart)',
      );
      // Re-open the playlist on the engine so it flushes its cached
      // VOD playlist + init segment and pulls the new single-audio-
      // track stream.  Same URL — the server-side restart rewrote the
      // segments in place.
      final url = _lastPlaylistUrl;
      if (url != null) {
        await engine.open(url, headers: headers, play: wasPlaying);
      }
      if (state is PlayerReady) {
        emit(
          (state as PlayerReady).copyWith(
            selectedAudioTrackIndex: sourceIndex,
            playlistOffsetSec: appliedSeek,
          ),
        );
      }
    } catch (e, st) {
      _log.w(
        '[Player] selectAudioTrack($sourceIndex) — server-restart '
        'switch failed; cubit state unchanged so the picker rolls '
        'back to the previous track',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Seek the active stream to [position].
  ///
  /// Two paths, picked by the size of the seek delta and the playlist's
  /// currently-loaded source-time range:
  ///
  /// - **Small forward seek**, or **backward seek that still lands inside
  ///   the currently-loaded playlist**: handled in the engine.  Backward
  ///   within the playlist is safe — segments are already on disk and
  ///   the engine seeks within its loaded data.  Small forward seeks
  ///   fit inside the engine's prefetch buffer plus the server's 5 s
  ///   segment-wait absorbing a brief miss.
  /// - **Forward seek at or above the threshold**: server-side restart.
  ///   The current FFmpeg only ever encodes from t=0 (or wherever the
  ///   last restart left it), so a far-ahead seek lands in territory it
  ///   has not produced yet.  The cubit pauses the engine, POSTs to
  ///   `/seek`, re-opens the same playlist URL, seeks within the new
  ///   playlist to [position], and resumes.
  ///
  /// Server-restart calls debounce by [_kSeekDebounceMs] so a seek-bar
  /// drag fires exactly one restart at the final position.  No-op when
  /// no session is active.  Failures fall back to in-player seek so the
  /// drag never feels totally dead.
  Future<void> seekTo(Duration position) async {
    final engine = _engine;
    final currentState = state;
    if (engine == null || currentState is! PlayerReady) return;
    if (position.isNegative) position = Duration.zero;

    // Source-time vs player-time bookkeeping (streaming pipeline plan
    // §16 scrubber-offset patch).  `position` is the user's target in
    // SOURCE time (what the scrubber shows).  The engine's reported
    // position runs in PLAYER time which is offset by
    // `playlistOffsetSec` when a seek-restart has shifted the playlist.
    // Compute the delta in source-time for the threshold compare; pass
    // player-time to `engine.seek` since the backend operates in
    // playlist-local coordinates.
    final offsetMs = (currentState.playlistOffsetSec * 1000).toInt();
    final currentPlayerMs = engine.position.inMilliseconds;
    final currentSourceMs = currentPlayerMs + offsetMs;
    final targetSourceMs = position.inMilliseconds;
    final deltaMs = targetSourceMs - currentSourceMs;

    // Map source-time target → player-time, then check against the
    // currently-loaded playlist's bounds.  A backward seek to a
    // source-time BEFORE the current playlist's origin (which is
    // non-zero whenever a prior forward seek triggered a server-
    // restart) cannot be served in-player — the engine's earliest
    // addressable position is the playlist's t=0, and clamping to it
    // would silently strand the user at the playlist start instead of
    // honouring their drag.  Route those out-of-bounds backward seeks
    // through the server-restart path so FFmpeg re-encodes from a
    // segment boundary at-or-before the requested source-time.
    final playerTargetMs = targetSourceMs - offsetMs;
    final playerDurMs = engine.duration.inMilliseconds;
    final inBounds =
        playerTargetMs >= 0 &&
        (playerDurMs <= 0 || playerTargetMs <= playerDurMs);

    final smallForward =
        deltaMs >= 0 && deltaMs < _kSeekRestartThresholdSec * 1000;
    final backwardInPlaylist = deltaMs < 0 && inBounds;

    // In-player path; cancel any in-flight server-restart debounce so
    // we don't double-act.
    if (smallForward || backwardInPlaylist) {
      _seekDebounceTimer?.cancel();
      _seekDebounceTimer = null;
      _pendingSeekTarget = null;
      try {
        // `playerTargetMs` is already non-negative under both branches;
        // the engine will clamp the upper bound to actual playlist length.
        await engine.seek(
          Duration(milliseconds: playerTargetMs.clamp(0, 1 << 30)),
        );
      } catch (e, st) {
        _log.w('In-player seek failed', error: e, stackTrace: st);
      }
      return;
    }

    // Server-restart path: debounce drag-end events, store the latest
    // target.  When the timer fires we read whatever the most-recent
    // target was, so a slow drag from 0:30 → 5:00 ends up calling
    // _commitServerSeek(5:00) once instead of N times.
    //
    // Flip `isSeeking` true *now* — before the debounce — so the
    // scrubber's release-pin (see _ProgressBar in flux_player_controls)
    // is tied 1:1 to the cubit's seeking flag for the entire restart
    // window (debounce + pause + open + seek + play).  Without this,
    // there's a 300 ms gap where isSeeking is still false but the
    // engine is still emitting position/duration updates, and any
    // transient stale-old-position-against-new-duration ratio > 1.0
    // can clear the pin's settle guard and snap the thumb to the
    // playlist end before _commitServerSeek even starts.
    if (!currentState.isSeeking) {
      emit(currentState.copyWith(isSeeking: true));
    }
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
  /// Pre-conditions verified at call time: an engine exists, a session
  /// is active, and the playlist URL was cached at start_stream time.
  /// All three are immutable for the duration of a session, so the
  /// happy path never recovers from a missing prerequisite — instead
  /// it logs and falls back to an in-player seek so playback isn't
  /// completely dead.
  Future<void> _commitServerSeek(Duration target) async {
    final engine = _engine;
    final sid = _sessionId;
    final url = _lastPlaylistUrl;
    final headers = _lastPlaylistHeaders;
    final currentState = state;
    if (engine == null ||
        sid == null ||
        url == null ||
        currentState is! PlayerReady) {
      return;
    }

    emit(currentState.copyWith(isSeeking: true));
    try {
      await engine.pause();
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
      // marker); the engine won't re-fetch on its own because the
      // original load saw `#EXT-X-ENDLIST` and considers VOD playlists
      // immutable.  Re-opening forces a fresh GET.
      await engine.open(
        url,
        headers: headers ?? const <String, String>{},
        play: false,
      );
      // The new playlist starts at `appliedSeekSec` of source-time
      // (segment-snapped by the server).  Seek WITHIN the playlist to
      // the sub-segment offset between the user's exact target and the
      // segment boundary.  Was previously `await engine.seek(target)` which
      // tried to seek to source-time T inside a playlist whose own
      // timeline runs 0..(N-K)*hls_time — the engine would either clamp
      // or reset, manifesting as "scrubber jumps back to 0".
      final withinPlaylistSec =
          target.inMilliseconds / 1000.0 - appliedSeekSec;
      if (withinPlaylistSec > 0) {
        await engine.seek(
          Duration(milliseconds: (withinPlaylistSec * 1000).toInt()),
        );
      }
      await engine.play();
      emit(
        currentState.copyWith(
          isSeeking: false,
          playlistOffsetSec: appliedSeekSec,
        ),
      );
    } catch (e, st) {
      _log.w(
        'Server seek-restart failed; falling back to in-player seek',
        error: e,
        stackTrace: st,
      );
      try {
        await engine.seek(target);
        await engine.play();
      } catch (e2, st2) {
        _log.w(
          'In-player fallback seek also failed',
          error: e2,
          stackTrace: st2,
        );
      }
      // Drop the seeking flag whether the fallback worked or not — the
      // overlay should not stay up forever on a hard failure.
      if (state is PlayerReady) {
        emit((state as PlayerReady).copyWith(isSeeking: false));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-fallback watcher (plan 20)
  // ---------------------------------------------------------------------------

  /// Subscribe to [PlayerEngine.errorStream] for [_kFallbackWatcherSec]
  /// and POST `/fallback-transcode` on the first error event so the
  /// server flips the same session into transcode mode.  Cancel the
  /// watcher early as soon as the first video frame decodes (proof the
  /// client can play the stream-copied source) — for the MediaKitEngine
  /// path we read libmpv's `videoParams` stream for that signal.  All
  /// cleanup is funnelled through [_cancelAutoFallbackWatcher] so
  /// [_disposeCurrentSession] doesn't have to duplicate the logic.
  void _scheduleAutoFallbackWatcher({
    required String sessionId,
    required String streamPath,
    required Map<String, String> headers,
  }) {
    // Cancel any previously-active watcher — defensive, _disposeCurrent
    // Session already covers the singleton-replay case but this keeps
    // the contract obvious at the call site.
    _cancelAutoFallbackWatcher();

    final engine = _engine;
    if (engine == null) return;

    _fallbackWatcherSub = engine.errorStream.listen((event) {
      if (_fallbackTriggered) return;
      _fallbackTriggered = true;
      // Fire-and-forget — `_handleAutoFallback` owns its own try/catch.
      unawaited(
        _handleAutoFallback(
          sessionId: sessionId,
          streamPath: streamPath,
          headers: headers,
          errorMessage: event.message ?? event.type.name,
        ),
      );
    });

    _fallbackWatcherTimer = Timer(
      const Duration(seconds: _kFallbackWatcherSec),
      _cancelAutoFallbackWatcher,
    );

    // Cancel early on first decoded frame.  libmpv's `videoParams`
    // emits as soon as a stream is negotiated; we treat `w > 0` as
    // proof of a working decode path.  ExoPlayerEngine path doesn't
    // need this because its error stream is authoritative (a decode
    // failure surfaces as a PlaybackException, not silence).
    if (engine is MediaKitEngine) {
      engine.mediaKitPlayer.stream.videoParams
          .firstWhere((VideoParams p) => (p.w ?? 0) > 0)
          .then((_) => _cancelAutoFallbackWatcher())
          .catchError((Object e, StackTrace st) {
            _log.d(
              'videoParams watcher unsubscribed',
              error: e,
              stackTrace: st,
            );
          });
    }
  }

  /// Cancels the auto-fallback watcher's subscription and timer.  Safe
  /// to call multiple times.  Does NOT reset [_fallbackTriggered] — the
  /// latch only resets at the start of a brand-new `startStream` so a
  /// late error from a previously-fallen-back session can't trigger a
  /// second fallback against an already-transcoded stream.
  void _cancelAutoFallbackWatcher() {
    _fallbackWatcherSub?.cancel();
    _fallbackWatcherSub = null;
    _fallbackWatcherTimer?.cancel();
    _fallbackWatcherTimer = null;
  }

  /// Reports the client-side decode failure to the server (plan 20) and
  /// re-opens the playlist URL so the engine re-fetches the now-
  /// transcoded segments.  Best-effort — a failure here just logs (the
  /// engine will surface its own error via the existing `errorStream`).
  Future<void> _handleAutoFallback({
    required String sessionId,
    required String streamPath,
    required Map<String, String> headers,
    required String errorMessage,
  }) async {
    final engine = _engine;
    if (engine == null) return;
    final positionSec = engine.position.inMilliseconds / 1000.0;
    _log.w(
      '[Player] auto-fallback triggered session=$sessionId '
      'pos=${positionSec.toStringAsFixed(3)}s error="$errorMessage"',
    );
    try {
      await _repository.reportFallbackTranscode(
        sessionId: sessionId,
        currentPositionSec: positionSec,
      );
      await engine.open(streamPath, headers: headers);
      _log.i('[Player] auto-fallback to transcode for session=$sessionId');
    } catch (e, st) {
      _log.w(
        '[Player] auto-fallback POST/reopen failed for session=$sessionId',
        error: e,
        stackTrace: st,
      );
    } finally {
      _cancelAutoFallbackWatcher();
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-fallback watcher — audio leg (plan 21)
  // ---------------------------------------------------------------------------

  /// Detects a stream-copied audio decode failure within the
  /// [_kFallbackWatcherSec]-second window after `PlayerReady` and POSTs
  /// `/fallback-audio-transcode` so the server flips the audio leg into
  /// transcode mode while leaving video stream-copy intact.  Mirrors
  /// the structure of [_scheduleAutoFallbackWatcher] but uses two
  /// detectors that together cover plan 21 sharp edge #1:
  ///
  ///   1. [PlayerEngine.errorStream] events whose lower-case message
  ///      contains `audio`, `aac`, or `codec` — libmpv tags audio-
  ///      specific failures with at least one of those substrings.
  ///      Generic errors (e.g. network drops) fall through to the
  ///      video watcher's catch-all.
  ///   2. A 4 s silence-watchdog over libmpv's `audioParams` stream
  ///      (only on the MediaKitEngine path): if no AudioParams emit
  ///      carries a non-null `sampleRate` or `channelCount` within the
  ///      window the audio decoder never came up, which on
  ///      `auto + stream-copy` only happens when the source codec
  ///      isn't supported on this device.  ExoPlayerEngine reports
  ///      the same condition through its error stream and detector 1
  ///      covers it there.
  ///
  /// Cancels early on the first non-empty audioParams emission (proof
  /// of a working audio decode).  All cleanup goes through
  /// [_cancelAutoAudioFallbackWatcher] so [_disposeCurrentSession]
  /// doesn't duplicate the logic.
  void _scheduleAutoAudioFallbackWatcher({
    required String sessionId,
    required String streamPath,
    required Map<String, String> headers,
  }) {
    _cancelAutoAudioFallbackWatcher();

    final engine = _engine;
    if (engine == null) return;

    void trigger(String reason) {
      if (_audioFallbackTriggered) return;
      _audioFallbackTriggered = true;
      unawaited(
        _handleAutoAudioFallback(
          sessionId: sessionId,
          streamPath: streamPath,
          headers: headers,
          reason: reason,
        ),
      );
    }

    // Detector 1 — audio-tagged error events.  We re-use the engine's
    // error stream rather than spawning a parallel listener pipeline;
    // matching on the message substring keeps the audio path from
    // stealing generic errors that belong to the video watcher.
    _audioFallbackWatcherErrorSub = engine.errorStream.listen((event) {
      final message = event.message ?? '';
      final lower = message.toLowerCase();
      if (lower.contains('audio') ||
          lower.contains('aac') ||
          lower.contains('codec')) {
        trigger('error="$message"');
      }
    });

    // Detector 2 — audioParams silence-watchdog (MediaKitEngine only).
    // The 4 s window fires BEFORE the outer 6 s watcher disarms so the
    // audio-only fallback path has a chance to take effect.  Cancelled
    // by the first non-empty audioParams emission below.
    if (engine is MediaKitEngine) {
      _audioFallbackParamsTimeoutTimer = Timer(
        const Duration(seconds: _kAudioParamsTimeoutSec),
        () => trigger('no audioParams within ${_kAudioParamsTimeoutSec}s'),
      );

      _audioFallbackWatcherParamsSub = engine.mediaKitPlayer.stream.audioParams
          .listen((AudioParams p) {
            if (p.sampleRate != null || p.channelCount != null) {
              // Audio decoder is alive — disarm both detectors
              // immediately.
              _cancelAutoAudioFallbackWatcher();
            }
          });
    }

    // Outer 6 s watcher matches the video leg's window so the audio
    // probe never lingers past the point where the user would have
    // given up on a stuck stream.
    _audioFallbackWatcherTimer = Timer(
      const Duration(seconds: _kFallbackWatcherSec),
      _cancelAutoAudioFallbackWatcher,
    );
  }

  /// Cancels the audio fallback watcher's subscriptions + timers.
  /// Safe to call multiple times.  Does NOT reset
  /// [_audioFallbackTriggered] — the latch only resets at the start of
  /// a brand-new `startStream` so a late error from a previously-
  /// fallen-back session can't fire a second POST against an already-
  /// transcoded audio leg.
  void _cancelAutoAudioFallbackWatcher() {
    _audioFallbackWatcherErrorSub?.cancel();
    _audioFallbackWatcherErrorSub = null;
    _audioFallbackWatcherParamsSub?.cancel();
    _audioFallbackWatcherParamsSub = null;
    _audioFallbackWatcherTimer?.cancel();
    _audioFallbackWatcherTimer = null;
    _audioFallbackParamsTimeoutTimer?.cancel();
    _audioFallbackParamsTimeoutTimer = null;
  }

  /// Reports the client-side audio decode failure to the server (plan
  /// 21) and re-opens the playlist URL so the engine re-fetches the
  /// audio-transcoded segments.  Best-effort — a failure here just
  /// logs (the engine will surface its own error via the existing
  /// error stream).
  Future<void> _handleAutoAudioFallback({
    required String sessionId,
    required String streamPath,
    required Map<String, String> headers,
    required String reason,
  }) async {
    final engine = _engine;
    if (engine == null) return;
    final positionSec = engine.position.inMilliseconds / 1000.0;
    _log.w(
      '[Player] audio auto-fallback triggered session=$sessionId '
      'pos=${positionSec.toStringAsFixed(3)}s reason=$reason',
    );
    try {
      await _repository.reportFallbackAudioTranscode(
        sessionId: sessionId,
        currentPositionSec: positionSec,
      );
      await engine.open(streamPath, headers: headers);
      _log.i(
        '[Player] audio auto-fallback to transcode for session=$sessionId',
      );
    } catch (e, st) {
      _log.w(
        '[Player] audio auto-fallback POST/reopen failed for '
        'session=$sessionId',
        error: e,
        stackTrace: st,
      );
    } finally {
      _cancelAutoAudioFallbackWatcher();
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
        _log.w(
          '[WebRTC] ICE timeout after ${_kWebRtcTimeoutSec}s — falling back to HLS',
        );
        return StreamPath.hls;
      },
    );
  }

  /// Called when ICE degrades after the stream is already playing.
  ///
  /// Updates the transport badge to HLS and closes the signaling session.
  /// The engine continues uninterrupted because it was always reading
  /// from an HLS playlist — WebRTC only drove the signaling badge.
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
    final engine = _engine;
    if (sid == null || engine == null) return;

    final posMicros = engine.position.inMicroseconds;
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
  /// engine) and clear the local references. Safe to call when nothing is
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
    // Plan 20 — make sure the watcher subscription doesn't outlive the
    // engine.  `_cancelAutoFallbackWatcher` is idempotent.
    _cancelAutoFallbackWatcher();
    // Plan 21 — same for the audio-leg watcher.
    _cancelAutoAudioFallbackWatcher();
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
    // Detach from the OS media session before disposing the engine —
    // otherwise the handler holds stream subscriptions to the player
    // and the dispose will throw.
    try {
      await _audioHandler?.detach();
    } catch (e, st) {
      _log.w('AudioHandler.detach failed', error: e, stackTrace: st);
    }
    await _engine?.dispose();
    _engine = null;
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
  /// background playback we pause the engine so the audio doesn't keep
  /// running silently — Android's foreground service from
  /// [audio_service] keeps the lockscreen card alive either way.
  Future<void> _onAppBackgrounded() async {
    final engine = _engine;
    if (engine == null) return;
    if (state is! PlayerReady) return;
    if (!engine.isPlaying) return;

    bool enabled;
    try {
      enabled = await _secureStorage.getBackgroundPlaybackEnabled();
    } catch (e, st) {
      _log.w(
        'Could not read bg-playback pref — defaulting to disabled',
        error: e,
        stackTrace: st,
      );
      enabled = false;
    }
    if (enabled) return;

    try {
      await engine.pause();
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
