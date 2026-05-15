import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart' show Video;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/player/presentation/controllers/player_controls_controller.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';
import 'package:fluxora_mobile/features/player/presentation/widgets/flux_player_controls.dart';
import 'package:fluxora_mobile/features/upgrade/presentation/screens/upgrade_screen.dart';

/// Fullscreen player route. Two entry points:
///
/// * `PlayerScreen(file: ...)` — pushed from a poster tap; calls
///   `cubit.startStream(...)` on the long-lived singleton cubit.
/// * `const PlayerScreen.resume()` — pushed from the mini-player; does
///   *not* call `startStream` since the singleton cubit is already
///   in [PlayerReady] state.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({required MediaFile this.file, super.key})
      : _resume = false;

  const PlayerScreen.resume({super.key})
      : file = null,
        _resume = true;

  final MediaFile? file;
  final bool _resume;

  @override
  Widget build(BuildContext context) {
    final cubit = GetIt.I<PlayerCubit>();
    if (!_resume && file != null) {
      // Fire-and-forget — the cubit is a singleton, this just (re)attaches
      // a stream session. `_disposeCurrentSession` cleans up any prior.
      //
      // HDR sources stream with their HDR bitstream intact — the
      // Android ExoPlayer engine requests codec-level HDR→SDR
      // tone-mapping via `MediaFormat.KEY_COLOR_TRANSFER_REQUEST`
      // (see `TonemappingRenderersFactory.kt`), which is free and
      // hardware-accelerated on Android 13+ devices that support
      // it.  Operator can fall back to the server-side tonemap via
      // the 3-dot menu's "Tone-map HDR to SDR" toggle on older
      // Android or unsupported codec paths.
      cubit.startStream(
        file!.id,
        file!.title ?? file!.name,
        file!.resumeSec,
        posterUrl: file!.posterUrl,
      );
    }
    return BlocProvider<PlayerCubit>.value(
      value: cubit,
      child: const _PlayerView(),
    );
  }
}

class _PlayerView extends StatefulWidget {
  const _PlayerView();

  @override
  State<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<_PlayerView>
    with WidgetsBindingObserver {
  final PlayerControlsController _controlsController =
      PlayerControlsController();
  bool _showResumeBanner = false;
  bool _showTransportBadge = false;
  bool _readyOnce = false;

  // Background-playback first-time prompt — Phase 3.  Set when the
  // cubit auto-paused on backgrounding AND the user hasn't yet been
  // asked whether they'd like to keep playback going.  The actual
  // dialog fires on the next AppLifecycleState.resumed event so the
  // user sees it after they come back to the app.
  bool _bgPromptPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Hold KEEP_SCREEN_ON for the entire player-screen lifetime
    // instead of letting `media_kit_video`'s `Video` widget toggle it
    // on every play/pause.  See `Video(wakelock: false)` below — that
    // turns off the per-play-state toggle which was triggering an
    // Oplus surface-recreation cascade (AudioTrack + MediaCodec
    // teardown → audio dies after ~32 ms).  Fire-and-forget; failures
    // mean the screen may dim under no-input timeout but playback is
    // unaffected.
    WakelockPlus.enable().catchError((_) => null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable().catchError((_) => null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Capture intent: the cubit will set wasAutoPausedOnBackground
      // *during* the lifecycle event, but reading it from here would
      // race.  Mark the flag — we'll consult the cubit on resume.
      _bgPromptPending = true;
    } else if (state == AppLifecycleState.resumed && _bgPromptPending) {
      _bgPromptPending = false;
      _maybeShowBackgroundPlaybackPrompt();
    }
  }

  Future<void> _maybeShowBackgroundPlaybackPrompt() async {
    if (!mounted) return;
    final cubit = context.read<PlayerCubit>();
    if (!cubit.wasAutoPausedOnBackground) return;
    cubit.clearAutoPausedFlag();

    final storage = GetIt.I<SecureStorage>();
    final shown = await storage.getBackgroundPlaybackPromptShown();
    if (shown || !mounted) return;

    final keep = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xCC0F0C24),
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F0C24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Text(
          'Keep playing in the background?',
          style: AppTypography.h2.copyWith(color: AppColors.textBright),
        ),
        content: Text(
          'When you minimize the app or lock your screen, Fluxora can '
          'either keep audio playing (with controls on the lockscreen) '
          'or pause until you come back. You can change this later in '
          'Profile → Playback.',
          style: AppTypography.body.copyWith(color: AppColors.textMutedV2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Pause when minimized',
              style: AppTypography.body.copyWith(color: AppColors.textBright),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Keep playing',
              style: AppTypography.body.copyWith(
                color: AppColors.violetTint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    // Persist whichever way the user answered, plus mark the prompt
    // shown so we don't re-ask on every backgrounding.  A null
    // dialog-dismiss (back button) is treated as "keep current
    // behaviour" — we still mark the prompt shown so we don't pester.
    final value = keep ?? false;
    try {
      await storage.setBackgroundPlaybackEnabled(value);
      await storage.setBackgroundPlaybackPromptShown(true);
    } catch (_) {
      // Storage failure isn't actionable here; cubit will retry the
      // pref read on the next backgrounding.
    }
    // If the user said "keep playing", resume now — they were just
    // auto-paused.
    if (value && mounted) {
      final cubitState = context.read<PlayerCubit>().state;
      if (cubitState is PlayerReady) {
        await cubitState.engine.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<PlayerCubit, PlayerState>(
            listenWhen: (_, current) => current is PlayerReady,
            listener: (context, state) {
              if (state is PlayerReady) {
                if (!_readyOnce) {
                  _readyOnce = true;
                  if (state.resumeSec > 0) {
                    setState(() => _showResumeBanner = true);
                    Future.delayed(const Duration(seconds: 4), () {
                      if (mounted) setState(() => _showResumeBanner = false);
                    });
                  }
                }
                setState(() => _showTransportBadge = true);
                Future.delayed(const Duration(seconds: 5), () {
                  if (mounted) setState(() => _showTransportBadge = false);
                });
              }
            },
            builder: (context, state) => switch (state) {
              PlayerInitial() || PlayerLoading() => const _LoadingView(),
              PlayerReady(:final engine, :final fileName, :final streamPath) =>
                  Stack(
                    children: [
                      _VideoView(
                        engine: engine,
                        fileName: fileName,
                        controlsController: _controlsController,
                        hdrFormat: state.hdrFormat,
                        tonemapped: state.tonemapped,
                        onTonemapChanged: (v) =>
                            context.read<PlayerCubit>().setTonemap(v),
                        onSeek: (d) =>
                            context.read<PlayerCubit>().seekTo(d),
                        onXRay: () =>
                            context.push(Routes.xray, extra: fileName),
                        onGroupWatch: () => context.push(
                          Routes.groupWatch,
                          extra: fileName,
                        ),
                        isSeeking: state.isSeeking,
                        playlistOffsetSec: state.playlistOffsetSec,
                      ),
                      if (_showResumeBanner && state.resumeSec > 0)
                        _ResumeBanner(resumeSec: state.resumeSec),
                      if (_showTransportBadge)
                        _TransportBadge(streamPath: streamPath),
                    ],
                  ),
              PlayerTierLimit() => const _TierLimitView(),
              PlayerGated(:final reason) => _GatedView(reason: reason),
              PlayerFailure(:final message) => _ErrorView(message: message),
            },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.violet),
          SizedBox(height: 16),
          Text(
            'Starting stream…',
            style: TextStyle(color: AppColors.textMutedV2),
          ),
        ],
      ),
    );
  }
}

class _VideoView extends StatelessWidget {
  const _VideoView({
    required this.engine,
    required this.fileName,
    required this.controlsController,
    this.hdrFormat,
    this.tonemapped = false,
    this.onTonemapChanged,
    this.onSeek,
    this.onXRay,
    this.onGroupWatch,
    this.isSeeking = false,
    this.playlistOffsetSec = 0.0,
  });

  final PlayerEngine engine;
  final String fileName;
  final PlayerControlsController controlsController;
  final String? hdrFormat;
  final bool tonemapped;
  final ValueChanged<bool>? onTonemapChanged;
  final ValueChanged<Duration>? onSeek;

  /// X-Ray entry point on the top bar.  Wired from the player_screen's
  /// BlocBuilder.  Null hides the chip.
  final VoidCallback? onXRay;

  /// Group Watch entry point in the overflow menu.  Wired from the
  /// player_screen's BlocBuilder.  Null hides the menu item.
  final VoidCallback? onGroupWatch;

  /// True while a server-side seek-restart is in flight.  Renders a
  /// dimming scrim + spinner so the user understands why playback is
  /// paused (the server may take ≥1 segment of wall-time to produce
  /// the new first segment, especially under tonemap / software
  /// transcode).
  final bool isSeeking;

  /// Source-time offset for the playlist's t=0.  Threaded down to the
  /// scrubber in `FluxPlayerControls` so it displays source-time after
  /// a server-side seek-restart instead of playlist-local time.
  final double playlistOffsetSec;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Two independent systems sized into the surface:
        //   * fit/fill — handled per engine (`Video(fit:)` for the
        //     MediaKit path, `FittedBox(fit:)` inside the texture
        //     surface for the ExoPlayer path).  Keeps the layout
        //     pipeline native to each engine, which is what worked
        //     correctly in portrait + landscape before unification.
        //   * pinch zoom — wraps the surface in `Transform.scale
        //     (userScale)` on top of whatever the fit mode produced.
        // Operator feedback was unambiguous: unifying these into one
        // scalar broke portrait-mode aspect handling.  Keep them
        // separate.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: controlsController,
            builder: (context, _) => Transform.scale(
              scale: controlsController.userScale,
              child: engine is MediaKitEngine
                  ? Video(
                      controller: (engine as MediaKitEngine).videoController,
                      controls: (state) => const SizedBox.shrink(),
                      fit: _fitModeToBoxFit(controlsController.fitMode),
                      // Disable media_kit_video's per-play-state
                      // wakelock toggling — we hold KEEP_SCREEN_ON
                      // for the entire player-screen lifetime in
                      // `_PlayerViewState.initState` instead.
                      wakelock: false,
                    )
                  : _EngineTextureSurface(
                      engine: engine,
                      fitMode: controlsController.fitMode,
                    ),
            ),
          ),
        ),
        FluxPlayerControls(
          engine: engine,
          controller: controlsController,
          title: fileName,
          onBack: () => Navigator.of(context).pop(),
          hdrFormat: hdrFormat,
          tonemapped: tonemapped,
          onTonemapChanged: onTonemapChanged,
          onSeek: onSeek,
          onXRay: onXRay,
          onGroupWatch: onGroupWatch,
          playlistOffsetSec: playlistOffsetSec,
          isSeeking: isSeeking,
        ),
        if (isSeeking) const _SeekingOverlay(),
      ],
    );
  }
}


/// Raw-texture rendering for the ExoPlayer path.  Reads
/// `engine.textureId` on every build; the engine emits texture id
/// changes through its own state machine and the parent rebuilds
/// when `PlayerReady` re-emits.
///
/// Fit / fill goes through `FittedBox(fit: BoxFit.contain | cover)`
/// wrapping a `SizedBox(videoWidth, videoHeight)` so the texture is
/// rendered at the decoded frame's aspect ratio and Flutter layouts
/// it correctly in portrait + landscape.  Pinch zoom is applied
/// separately one level up via `Transform.scale(userScale)`.
class _EngineTextureSurface extends StatelessWidget {
  const _EngineTextureSurface({required this.engine, required this.fitMode});

  final PlayerEngine engine;

  /// Discrete fit mode driven by [PlayerControlsController.fitMode]:
  /// fit (letterbox) / fill (cover) / stretch (ignore aspect).
  final FitMode fitMode;

  @override
  Widget build(BuildContext context) {
    final id = engine.textureId;
    if (id == null) {
      return const ColoredBox(color: Colors.black);
    }
    return StreamBuilder<({int width, int height})?>(
      stream: engine.videoSizeStream,
      initialData: engine.videoSize,
      builder: (context, snap) {
        final size = snap.data;
        final texture = Texture(textureId: id);
        if (size == null || size.width <= 0 || size.height <= 0) {
          // Pre-size-known: stretched Texture at parent size.  Lasts
          // only until the engine emits the first videoSize event
          // (Media3 fires it as soon as `onTracksChanged` parses the
          // playlist — much earlier than first-decoded-frame).
          return texture;
        }
        return ClipRect(
          child: FittedBox(
            fit: _fitModeToBoxFit(fitMode),
            child: SizedBox(
              width: size.width.toDouble(),
              height: size.height.toDouble(),
              child: texture,
            ),
          ),
        );
      },
    );
  }
}

/// Map the discrete [FitMode] enum to Flutter's [BoxFit].
/// * fit → `contain` (letterbox/pillarbox)
/// * fill → `cover` (crop to fill viewport)
/// * stretch → `fill` (ignore aspect, distort to viewport)
BoxFit _fitModeToBoxFit(FitMode mode) {
  return switch (mode) {
    FitMode.fit => BoxFit.contain,
    FitMode.fill => BoxFit.cover,
    FitMode.stretch => BoxFit.fill,
  };
}

/// Translucent dimming scrim + centred spinner shown while a server
/// seek-restart is in flight.  Distinct from media_kit's own buffering
/// indicator because the server restart needs the ≥10 s of FFmpeg
/// startup time before the new first segment lands — without this
/// overlay the user sees a frozen frame and assumes the player crashed.
class _SeekingOverlay extends StatelessWidget {
  const _SeekingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Color(0x66000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: AppColors.violet,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Seeking…',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.resumeSec});

  final double resumeSec;

  String get _formatted {
    final d = Duration(seconds: resumeSec.toInt());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 96,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Text(
            'Resumed from $_formatted',
            style: AppTypography.body.copyWith(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textMutedV2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

class _TierLimitView extends StatelessWidget {
  const _TierLimitView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: AppGradients.brand,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Stream Limit Reached',
              style: AppTypography.displayV2
                  .copyWith(color: AppColors.textBright),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your current plan only allows a limited number of simultaneous '
              'streams. Free a slot or upgrade to stream on more devices.',
              style: AppTypography.body.copyWith(color: AppColors.textMutedV2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FluxButton(
                fullWidth: true,
                icon: Icons.workspace_premium,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const UpgradeScreen(),
                  ),
                ),
                child: const Text('Upgrade Plan'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FluxButton(
                variant: FluxButtonVariant.secondary,
                fullWidth: true,
                icon: Icons.arrow_back,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft block view shown when the server denied the stream start with a
/// Client Group restriction (group_service.reason_to_deny).  Distinct from
/// [_ErrorView] (which says "Stream failed") because a gate is not a bug
/// — the operator deliberately set this up.  Mirrors [_TierLimitView]'s
/// shape but with parental-control framing instead of an upgrade prompt.
class _GatedView extends StatelessWidget {
  const _GatedView({required this.reason});

  final String reason;

  /// Friendly title that frames the restriction without sounding like a
  /// permissions error.  Heuristic: detect the time-window vs library
  /// flavour from the reason text and pick a header that matches.  Falls
  /// back to a generic "Not available right now" for any future server
  /// reason this client doesn't recognise.
  String get _title {
    final lower = reason.toLowerCase();
    if (lower.contains('time window')) return 'Outside playback hours';
    if (lower.contains('library')) return 'Not in your library access';
    return 'Not available right now';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.violet,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _title,
              style: AppTypography.displayV2
                  .copyWith(color: AppColors.textBright),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              reason,
              style: AppTypography.body.copyWith(color: AppColors.textMutedV2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FluxButton(
                fullWidth: true,
                icon: Icons.arrow_back,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransportBadge extends StatelessWidget {
  const _TransportBadge({required this.streamPath});

  final StreamPath streamPath;

  @override
  Widget build(BuildContext context) {
    final isWebRtc = streamPath == StreamPath.webRtc;
    return Positioned(
      top: 80,
      right: 16,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isWebRtc
                ? AppColors.violet.withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isWebRtc
                  ? AppColors.violetTint
                  : AppColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isWebRtc ? Icons.cell_tower : Icons.stream,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                isWebRtc ? 'WebRTC' : 'HLS',
                style: AppTypography.captionV2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
