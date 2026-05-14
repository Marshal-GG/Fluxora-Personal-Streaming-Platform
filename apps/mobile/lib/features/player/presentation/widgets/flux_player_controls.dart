/// `FluxPlayerControls` — the redesigned overlay that sits over `Video`
/// and replaces `MaterialVideoControls` from `media_kit_video`.
///
/// Composed of: tap-toggle scrim, top bar, center transport, progress
/// bar, quick-action grid, side rails, drag HUD, and lock-mode hold-to-
/// unlock. Wires gestures (double-tap seek ±10 s, long-press 2× peek,
/// vertical drag = brightness on left half / volume on right half, pinch
/// fit toggle) and the 5 bottom sheets (Audio/Subs / Speed / Sleep —
/// live; Quality / Cast — stub-disabled).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:media_kit/media_kit.dart' show Player;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:fluxora_mobile/features/player/data/services/pip_service.dart';
import 'package:fluxora_mobile/features/player/presentation/controllers/player_controls_controller.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';
import 'package:fluxora_mobile/features/player/presentation/sheets/audio_subs_sheet.dart';
import 'package:fluxora_mobile/features/player/presentation/sheets/cast_sheet.dart';
import 'package:fluxora_mobile/features/player/presentation/sheets/quality_sheet.dart';
import 'package:fluxora_mobile/features/player/presentation/sheets/sleep_sheet.dart';
import 'package:fluxora_mobile/features/player/presentation/sheets/speed_sheet.dart';

// ── Animation timings (M14 polish spec) ────────────────────────────────────
// Named so the durations are auditable in one place rather than scattered
// as magic ints.  All values come from `docs/11_design/mobile_redesign_plan.md`
// §7 row M14: fade 250 ms, transport press 50 ms, ripple expand 400 ms.
//
// Exceptions intentionally NOT funnelled through these constants:
//   * `_unlockHoldDuration = 1200ms` — hold-to-unlock affordance timing, not
//     a fade.  Per plan §7 row M6 this is a deliberate UX hold, not a
//     visual transition; keeping it as its own const inside the State.
//   * `_onVerticalDragEnd` 600 ms `Future.delayed` — delay before the drag
//     HUD is cleared so the value lingers long enough for the operator to
//     read it, not a fade duration.  Left as-is.
//   * `flux_mini_player.dart` `AnimatedSize` 200 ms — bar mount / unmount
//     timing is a layout transition, not an overlay fade.  Out of scope
//     for this slice (mini-player is shared chrome, fade-spec applies to
//     player-overlay surfaces).
const Duration _kFadeMs = Duration(milliseconds: 250);
const Duration _kTransportPressMs = Duration(milliseconds: 50);
const Duration _kRippleMs = Duration(milliseconds: 400);

class FluxPlayerControls extends StatefulWidget {
  const FluxPlayerControls({
    required this.player,
    required this.controller,
    required this.title,
    required this.onBack,
    this.hdrFormat,
    this.tonemapped = false,
    this.onTonemapChanged,
    this.onSeek,
    this.onXRay,
    this.onGroupWatch,
    this.playlistOffsetSec = 0.0,
    this.isSeeking = false,
    super.key,
  });

  final Player player;
  final PlayerControlsController controller;
  final String title;
  final VoidCallback onBack;

  /// Invoked when the user taps the X-Ray chip on the top bar.  Wired
  /// from `player_screen.dart` to push `Routes.xray` with the current
  /// `MediaFile` as `extra`.  Null hides the chip — useful for
  /// surfaces where X-Ray context isn't meaningful (resume sessions
  /// where the file isn't in scope).
  final VoidCallback? onXRay;

  /// Invoked when the user taps "Start Group Watch" in the overflow
  /// menu.  Wired from `player_screen.dart` to push
  /// `Routes.groupWatch` with the source title as `extra`.  Null
  /// hides the entry — useful for resume sessions where group-watch
  /// context isn't meaningful.
  final VoidCallback? onGroupWatch;

  /// Source HDR format for the current stream (e.g. `"HDR10"`).  Null
  /// hides the HDR badge.  Provided by the player_screen from
  /// `PlayerReady.hdrFormat`.
  final String? hdrFormat;

  /// True when the server is currently tonemapping HDR → SDR.  Drives
  /// the toggle's checkmark in the overflow menu.
  final bool tonemapped;

  /// Invoked when the operator toggles tonemap.  Player_screen wires
  /// this to `PlayerCubit.setTonemap(bool)`.  Null disables the toggle
  /// item in the overflow menu.
  final ValueChanged<bool>? onTonemapChanged;

  /// Invoked when the user requests a seek (scrubber drag, double-tap
  /// skip ±10 s).  The cubit decides whether to do an in-player seek
  /// (small delta / backward) or a server-side restart (large forward
  /// delta) — the controls just emit the desired target and don't try
  /// to call ``player.seek`` themselves.  Wired from player_screen to
  /// ``PlayerCubit.seekTo``.  Null falls back to the legacy direct
  /// ``player.seek`` path.
  final ValueChanged<Duration>? onSeek;

  /// Server-supplied source-time offset for the playlist's t=0
  /// (streaming pipeline plan §16 scrubber-offset patch).  Threaded
  /// from `PlayerReady.playlistOffsetSec` via player_screen.  When
  /// non-zero, the scrubber displays `position + offset` so the user
  /// sees source-time after a server-side seek-restart has shifted
  /// the playlist's media-sequence.
  final double playlistOffsetSec;

  /// True while a server-side seek-restart is in flight.  Threaded
  /// down to the scrubber so it pins to the user's just-released
  /// target while libmpv pauses + reloads the playlist instead of
  /// chasing the position/duration streams (which briefly emit
  /// stale-old-position-against-new-duration ratios > 1.0 — the
  /// "scrubber jumps to end then comes back" regression).
  final bool isSeeking;

  @override
  State<FluxPlayerControls> createState() => _FluxPlayerControlsState();
}

class _FluxPlayerControlsState extends State<FluxPlayerControls> {
  // Long-press 2× peek state.
  double? _peekRestoreRate;

  // Vertical-drag tracking (brightness/volume).
  double? _dragStartY;
  double _dragStartValue = 0.0;
  bool _dragIsLeftHalf = false;

  // Lock-hold progress ring.
  Timer? _unlockTimer;
  DateTime? _unlockHoldStart;
  static const _unlockHoldDuration = Duration(milliseconds: 1200);

  // Sleep timer.
  Duration? _sleepDuration;
  Timer? _sleepTimer;

  // Double-tap ripple location.
  Offset? _ripplePos;
  bool _rippleIsForward = true;
  Timer? _rippleTimer;

  Sheet _activeSheet = Sheet.none;

  Sheet get activeSheet => _activeSheet;

  // PIP availability — probed once on first build via [PipService].
  // Stays null until the probe resolves; the top-bar button is hidden in
  // that window (a single frame on Android, permanently on iOS / desktop).
  bool? _pipSupported;

  Future<void> _enterPip() async {
    final w = widget.player.state.width ?? 16;
    final h = widget.player.state.height ?? 9;
    await PipService.enter(width: w, height: h);
    // Hide the controls overlay once we've asked the system for PIP — by
    // the time we redraw we'll be in a small window where the overlay
    // would be useless chrome.
    widget.controller.hide();
  }

  /// Bottom sheet wired to the 3-dot icon in the top bar.  Hosts options
  /// that don't deserve a permanent button — currently the HDR → SDR
  /// tonemap toggle (only shown when the source is HDR).  Future
  /// additions like a quality / speed picker live here too.
  Future<void> _showOverflowMenu() async {
    final isHdr = widget.hdrFormat != null;
    final canTonemap = isHdr && widget.onTonemapChanged != null;
    final canGroupWatch = widget.onGroupWatch != null;
    if (!canTonemap && !canGroupWatch) {
      // Nothing to show yet — the menu would be an empty sheet.  Don't
      // open it; gives the operator a hint that the icon is reserved
      // for future controls without making it look broken.
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1626),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (canTonemap)
              ListTile(
                leading: Icon(
                  widget.tonemapped
                      ? Icons.hdr_off_rounded
                      : Icons.hdr_on_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Tone-map HDR to SDR',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  widget.tonemapped
                      ? 'Server is converting BT.2020 PQ to BT.709 (slower).'
                      : 'Source is ${widget.hdrFormat}; tap to convert if '
                            'colours look washed.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                trailing: Switch(
                  value: widget.tonemapped,
                  onChanged: (v) {
                    Navigator.of(ctx).pop();
                    widget.onTonemapChanged?.call(v);
                  },
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onTonemapChanged?.call(!widget.tonemapped);
                },
              ),
            if (canGroupWatch)
              ListTile(
                leading: const Icon(Icons.groups_rounded, color: Colors.white),
                title: const Text(
                  'Group Watch',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Co-watch with friends — UI shell, sync ships in v1.1.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onGroupWatch?.call();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller.show();
    widget.controller.addListener(_onChange);
    PipService.isSupported().then((ok) {
      if (mounted) setState(() => _pipSupported = ok);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _unlockTimer?.cancel();
    _sleepTimer?.cancel();
    _rippleTimer?.cancel();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  // ── Player commands ────────────────────────────────────────────────────────

  void _seekRelative(Duration delta) {
    // Convert player-time to source-time before passing to the cubit:
    // after a forward server-restart `playlistOffsetSec` is non-zero
    // and the cubit's `seekTo` expects source-time targets.  Without
    // this, a `+10 s` skip after a 5:00 forward seek-restart would land
    // at source-time 0:10 instead of 5:10 (the cubit subtracts the
    // offset internally and the in-player path clamps the negative
    // result to 0).
    final playerPos = widget.player.state.position;
    final playerDur = widget.player.state.duration;
    final offset = Duration(
      milliseconds: (widget.playlistOffsetSec * 1000).toInt(),
    );
    final sourceDur = playerDur + offset;
    final sourcePos = playerPos + offset;
    var target = sourcePos + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (sourceDur > Duration.zero && target > sourceDur) target = sourceDur;
    _emitSeek(target);
    widget.controller.show();
  }

  /// Single seek funnel — routes through the cubit when the parent has
  /// supplied [FluxPlayerControls.onSeek], otherwise falls back to a
  /// direct `player.seek` call.  Used by the scrubber, the double-tap-
  /// skip ripple, and the side-rail skip buttons.  Callers emit
  /// SOURCE-time targets; the fallback path converts back to player-
  /// time (`target - playlistOffsetSec`, clamped to player-duration)
  /// because libmpv's `seek` expects playlist-local coordinates.
  void _emitSeek(Duration target) {
    final cb = widget.onSeek;
    if (cb != null) {
      cb(target);
    } else {
      final offsetMs = (widget.playlistOffsetSec * 1000).toInt();
      final playerDurMs = widget.player.state.duration.inMilliseconds;
      final playerMs = (target.inMilliseconds - offsetMs).clamp(
        0,
        playerDurMs > 0 ? playerDurMs : 1 << 30,
      );
      widget.player.seek(Duration(milliseconds: playerMs));
    }
  }

  void _togglePlay() {
    widget.player.playOrPause();
    widget.controller.show();
  }

  // ── Gestures ───────────────────────────────────────────────────────────────

  void _onDoubleTapDown(TapDownDetails d) {
    if (widget.controller.lockMode) return;
    final width = MediaQuery.of(context).size.width;
    final isForward = d.localPosition.dx > width / 2;
    _seekRelative(Duration(seconds: isForward ? 10 : -10));
    HapticFeedback.lightImpact();
    setState(() {
      _ripplePos = d.localPosition;
      _rippleIsForward = isForward;
    });
    _rippleTimer?.cancel();
    _rippleTimer = Timer(_kRippleMs, () {
      if (mounted) setState(() => _ripplePos = null);
    });
  }

  void _onLongPressStart(LongPressStartDetails _) {
    if (widget.controller.lockMode) return;
    _peekRestoreRate = widget.player.state.rate;
    widget.player.setRate(2.0);
    HapticFeedback.mediumImpact();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (_peekRestoreRate != null) {
      widget.player.setRate(_peekRestoreRate!);
      _peekRestoreRate = null;
    }
  }

  Future<void> _onVerticalDragStart(DragStartDetails d) async {
    if (widget.controller.lockMode) return;
    final width = MediaQuery.of(context).size.width;
    _dragIsLeftHalf = d.localPosition.dx < width / 2;
    _dragStartY = d.localPosition.dy;
    if (_dragIsLeftHalf) {
      try {
        _dragStartValue = await ScreenBrightness.instance.application;
      } catch (_) {
        _dragStartValue = 0.5;
      }
    } else {
      _dragStartValue = widget.player.state.volume / 100.0;
    }
  }

  Future<void> _onVerticalDragUpdate(DragUpdateDetails d) async {
    if (widget.controller.lockMode || _dragStartY == null) return;
    final height = MediaQuery.of(context).size.height;
    final delta = (_dragStartY! - d.localPosition.dy) / height;
    final value = (_dragStartValue + delta).clamp(0.0, 1.0);
    if (_dragIsLeftHalf) {
      try {
        await ScreenBrightness.instance.setApplicationScreenBrightness(value);
      } catch (_) {
        // brightness not available — silently ignore.
      }
      widget.controller.setBrightnessHud(value);
    } else {
      widget.player.setVolume(value * 100.0);
      widget.controller.setVolumeHud(value);
    }
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    _dragStartY = null;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) widget.controller.clearHud();
    });
  }

  void _onPinchEnd(ScaleEndDetails _) {
    // Use scale-end so a single pinch gesture toggles fit once. The plan
    // calls for "pinch = fit toggle" — we just flip on every pinch
    // regardless of magnitude.
    if (widget.controller.lockMode) return;
    widget.controller.toggleFit();
    HapticFeedback.lightImpact();
  }

  // ── Lock hold-to-unlock ────────────────────────────────────────────────────

  void _onUnlockHoldStart() {
    _unlockHoldStart = DateTime.now();
    _unlockTimer?.cancel();
    _unlockTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_unlockHoldStart!);
      if (elapsed >= _unlockHoldDuration) {
        t.cancel();
        widget.controller.unlock();
        HapticFeedback.mediumImpact();
        _unlockHoldStart = null;
      } else {
        setState(() {}); // repaint progress
      }
    });
  }

  void _onUnlockHoldEnd() {
    _unlockTimer?.cancel();
    _unlockTimer = null;
    setState(() => _unlockHoldStart = null);
  }

  double get _unlockProgress {
    if (_unlockHoldStart == null) return 0.0;
    final elapsed = DateTime.now().difference(_unlockHoldStart!);
    return (elapsed.inMilliseconds / _unlockHoldDuration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  // ── Sheets ─────────────────────────────────────────────────────────────────

  Future<void> _openSheet(Sheet which) async {
    if (widget.controller.lockMode) return;
    setState(() => _activeSheet = which);
    widget.controller.show();
    switch (which) {
      case Sheet.audioSubs:
        await showFluxBottomSheet<void>(
          context: context,
          builder: (_) => AudioSubsSheet(player: widget.player),
        );
      case Sheet.speed:
        await showFluxBottomSheet<void>(
          context: context,
          builder: (_) => SpeedSheet(player: widget.player),
        );
      case Sheet.sleep:
        final picked = await showFluxBottomSheet<Duration?>(
          context: context,
          builder: (_) => SleepSheet(current: _sleepDuration),
        );
        _setSleepTimer(picked);
      case Sheet.quality:
        await showFluxBottomSheet<void>(
          context: context,
          builder: (_) => const QualitySheet(),
        );
      case Sheet.cast:
        await showFluxBottomSheet<void>(
          context: context,
          builder: (_) => const CastSheet(),
        );
      case Sheet.none:
        break;
    }
    if (mounted) setState(() => _activeSheet = Sheet.none);
  }

  void _setSleepTimer(Duration? d) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    setState(() => _sleepDuration = d);
    if (d != null) {
      _sleepTimer = Timer(d, () {
        if (mounted) {
          widget.player.pause();
          setState(() => _sleepDuration = null);
        }
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: c.lockMode ? null : c.toggle,
        onDoubleTapDown: _onDoubleTapDown,
        onDoubleTap: () {
          // Required by Flutter to register onDoubleTapDown — handled there.
        },
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onScaleEnd: _onPinchEnd,
        child: Stack(
          children: [
            AnimatedOpacity(
              opacity: c.visible ? 1.0 : 0.0,
              duration: _kFadeMs,
              curve: Curves.easeOut,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0x33000000),
                      Color(0x99000000),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            if (_ripplePos != null)
              _SeekRipple(position: _ripplePos!, isForward: _rippleIsForward),

            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedSwitcher(
                  duration: _kFadeMs,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  child: _peekRestoreRate != null
                      ? const _PeekBadge()
                      : const SizedBox.shrink(),
                ),
              ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                ignoring: !c.dragHudVisible,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: c.dragHudVisible ? 1.0 : 0.0,
                    duration: _kFadeMs,
                    curve: Curves.easeOut,
                    child: _DragHud(kind: c.activeDrag, value: c.dragHudValue),
                  ),
                ),
              ),
            ),

            if (c.visible && !c.lockMode)
              FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: FocusTraversalOrder(
                          order: const NumericFocusOrder(1),
                          child: PlayerTopBar(
                            title: widget.title,
                            onBack: widget.onBack,
                            onMore: _showOverflowMenu,
                            onPip: _pipSupported == true ? _enterPip : null,
                            onXRay: widget.onXRay,
                            sleepActive: _sleepDuration != null,
                            hdrFormat: widget.hdrFormat,
                            tonemapped: widget.tonemapped,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: FocusTraversalOrder(
                          order: const NumericFocusOrder(2),
                          child: PlayerCenterTransport(
                            isPlaying: widget.player.state.playing,
                            onRewind: () =>
                                _seekRelative(const Duration(seconds: -10)),
                            onPlayPause: _togglePlay,
                            onForward: () =>
                                _seekRelative(const Duration(seconds: 10)),
                          ),
                        ),
                      ),
                    ),
                    if (isLandscape) ...[
                      const Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        child: FocusTraversalOrder(
                          order: NumericFocusOrder(3),
                          child: PlayerSideRail(
                            icon: Icons.brightness_6_outlined,
                            label: 'Brightness',
                            align: Alignment.centerLeft,
                            kind: PlayerDragKind.brightness,
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        child: FocusTraversalOrder(
                          order: NumericFocusOrder(4),
                          child: PlayerSideRail(
                            icon: Icons.volume_up_outlined,
                            label: 'Volume',
                            align: Alignment.centerRight,
                            kind: PlayerDragKind.volume,
                          ),
                        ),
                      ),
                    ],
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(5),
                              child: PlayerProgressBar(
                                player: widget.player,
                                onSeekCommit: _emitSeek,
                                playlistOffsetSec: widget.playlistOffsetSec,
                                isSeeking: widget.isSeeking,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(6),
                              // Plan 22 — wrap the quick-action row in a
                              // BlocBuilder so the Audio action's
                              // disabled state tracks the cubit's
                              // `availableAudioTracks` count.  Greyed
                              // when 0-or-1 tracks (no point in opening
                              // a picker with nothing to pick).
                              child: BlocBuilder<PlayerCubit, PlayerState>(
                                buildWhen: (prev, next) {
                                  final prevCount = prev is PlayerReady
                                      ? prev.availableAudioTracks.length
                                      : 0;
                                  final nextCount = next is PlayerReady
                                      ? next.availableAudioTracks.length
                                      : 0;
                                  return prevCount != nextCount;
                                },
                                builder: (context, state) {
                                  final audioTrackCount = state is PlayerReady
                                      ? state.availableAudioTracks.length
                                      : 0;
                                  return PlayerQuickActions(
                                    onLock: c.lock,
                                    onFit: c.toggleFit,
                                    fitCover: c.fitCover,
                                    onOpenSheet: _openSheet,
                                    sleepActive: _sleepDuration != null,
                                    audioTrackCount: audioTrackCount,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (c.lockMode)
              // Lock mode is its own focus scope: while engaged, the
              // hold-to-unlock affordance is the only focusable element
              // (FocusTraversalGroup absorbs traversal so the hidden
              // chrome above can't be reached via D-pad / Tab).
              FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 24 + MediaQuery.of(context).padding.bottom,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Semantics(
                          label: 'Press and hold to unlock player',
                          button: true,
                          child: GestureDetector(
                            onLongPressStart: (_) => _onUnlockHoldStart(),
                            onLongPressEnd: (_) => _onUnlockHoldEnd(),
                            onLongPressCancel: _onUnlockHoldEnd,
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_unlockHoldStart != null)
                                    SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: CircularProgressIndicator(
                                        value: _unlockProgress,
                                        strokeWidth: 3,
                                        color: AppColors.violet,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.15),
                                      ),
                                    ),
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.borderSubtle,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.lock_open_outlined,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_unlockHoldStart == null)
                      Positioned(
                        bottom: 8 + MediaQuery.of(context).padding.bottom,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Semantics(
                            label: 'Press and hold the lock icon to unlock',
                            child: ExcludeSemantics(
                              child: Text(
                                'Press and hold to unlock',
                                style: AppTypography.captionV2.copyWith(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum Sheet { none, audioSubs, speed, sleep, quality, cast }

/// Player top bar — back chevron, title, optional HDR chip, sleep
/// indicator, X-Ray / PIP / overflow buttons.
///
/// Public + `@visibleForTesting` so golden-tests in
/// `apps/mobile/test/goldens/` can construct it directly without
/// having to spin up a real `Player`.  Outside tests it is only
/// instantiated by `FluxPlayerControls.build`.
class PlayerTopBar extends StatelessWidget {
  @visibleForTesting
  const PlayerTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onMore,
    required this.onPip,
    required this.onXRay,
    required this.sleepActive,
    this.hdrFormat,
    this.tonemapped = false,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onMore;

  /// Picture-in-Picture entry point.  `null` when the platform doesn't
  /// support PIP (iOS, desktop, Android 7 or older) so the icon hides
  /// instead of rendering a no-op chip.
  final VoidCallback? onPip;

  /// X-Ray entry point.  `null` hides the chip (e.g. resume-session
  /// where the file isn't in scope on the player_screen side).
  final VoidCallback? onXRay;

  final bool sleepActive;

  /// HDR format of the source — drives the `HDR10` / `HLG` / `DV` chip
  /// next to the PIP icon.  Null hides the chip entirely (SDR sources).
  final String? hdrFormat;

  /// True when the server is currently tonemapping HDR → SDR; the chip
  /// switches from a violet `HDR10` to a neutral `SDR` to make the
  /// override state visible at a glance.
  final bool tonemapped;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          Semantics(
            label: 'Back',
            button: true,
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: onBack,
              splashRadius: 22,
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              label: 'Now playing: $title',
              child: ExcludeSemantics(
                child: Text(
                  title,
                  style: AppTypography.h1.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          if (sleepActive)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                label: 'Sleep timer active',
                child: const ExcludeSemantics(
                  child: Icon(
                    Icons.bedtime,
                    color: AppColors.violetTint,
                    size: 18,
                  ),
                ),
              ),
            ),
          if (hdrFormat != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _HdrChip(format: hdrFormat!, tonemapped: tonemapped),
            ),
          if (onXRay != null)
            Semantics(
              label: 'X-Ray: cast and scene details',
              button: true,
              child: IconButton(
                tooltip: 'X-Ray',
                icon: const Icon(Icons.science_outlined, color: Colors.white),
                onPressed: onXRay,
                splashRadius: 22,
              ),
            ),
          if (onPip != null)
            Semantics(
              label: 'Picture in picture',
              button: true,
              child: IconButton(
                tooltip: 'Picture-in-picture',
                icon: const Icon(
                  Icons.picture_in_picture_alt_rounded,
                  color: Colors.white,
                ),
                onPressed: onPip,
                splashRadius: 22,
              ),
            ),
          Semantics(
            label: 'More options',
            button: true,
            child: IconButton(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: onMore,
              splashRadius: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3-button transport row (rewind 10 / play-pause / forward 10).
///
/// Public + `@visibleForTesting` to enable golden capture without a
/// live `Player`.  Production code only constructs it from
/// `FluxPlayerControls.build`.
class PlayerCenterTransport extends StatelessWidget {
  @visibleForTesting
  const PlayerCenterTransport({
    super.key,
    required this.isPlaying,
    required this.onRewind,
    required this.onPlayPause,
    required this.onForward,
  });

  final bool isPlaying;
  final VoidCallback onRewind;
  final VoidCallback onPlayPause;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          icon: Icons.replay_10,
          size: 56,
          onPressed: onRewind,
          semanticLabel: 'Rewind 10 seconds',
        ),
        const SizedBox(width: 24),
        _CircleButton(
          icon: isPlaying ? Icons.pause : Icons.play_arrow,
          size: 72,
          gradient: true,
          onPressed: onPlayPause,
          // State-dependent label — read out loud by screen readers, so
          // it reflects the action the button will perform on tap, not
          // the current playback state.
          semanticLabel: isPlaying ? 'Pause' : 'Play',
          // Lands the keyboard / D-pad cursor on play-pause when chrome
          // appears (M14 focus traversal spec).
          autofocus: true,
        ),
        const SizedBox(width: 24),
        _CircleButton(
          icon: Icons.forward_10,
          size: 56,
          onPressed: onForward,
          semanticLabel: 'Forward 10 seconds',
        ),
      ],
    );
  }
}

/// Transport circle button with a 50-ms press scale-down (M14 spec).
/// Stateful so the scale animation can run in response to tap-down /
/// tap-up / tap-cancel without rebuilding the parent transport row on
/// every press.
class _CircleButton extends StatefulWidget {
  const _CircleButton({
    required this.icon,
    required this.size,
    required this.onPressed,
    this.gradient = false,
    this.semanticLabel,
    this.autofocus = false,
  });

  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final bool gradient;

  /// Screen-reader-friendly label.  For the play-pause button this is
  /// state-dependent ("Play" vs "Pause") — passed in by the parent so
  /// the rebuild on play-state change refreshes the announced label.
  final String? semanticLabel;

  /// True for the primary action (play / pause) — autofocuses so a
  /// keyboard / D-pad operator lands there first when chrome appears.
  final bool autofocus;

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: _kTransportPressMs,
          curve: Curves.easeOut,
          child: Focus(
            autofocus: widget.autofocus,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: widget.gradient
                  ? const BoxDecoration(
                      gradient: AppGradients.brand,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.buttonGlow,
                    )
                  : BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: widget.size * 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrubber + elapsed / total timestamps.
///
/// Public + `@visibleForTesting` so golden tests can supply a mocked
/// `Player` and capture the bar at a deterministic playhead without
/// having to mount the full player overlay.
class PlayerProgressBar extends StatefulWidget {
  @visibleForTesting
  const PlayerProgressBar({
    super.key,
    required this.player,
    this.onSeekCommit,
    this.playlistOffsetSec = 0.0,
    this.isSeeking = false,
  });

  final Player player;

  /// Called once on `onChangeEnd` with the final scrub target so the
  /// cubit can decide between in-player seek and server restart.
  final ValueChanged<Duration>? onSeekCommit;

  /// Server-supplied source-time offset for the playlist's t=0
  /// (streaming pipeline plan §16 scrubber-offset patch 2026-05-08).
  /// Added to libmpv's reported position when displaying the scrubber
  /// so the user sees source-time, not playlist-time, after a server-
  /// side seek-restart has shifted the playlist.
  final double playlistOffsetSec;

  /// True while the cubit is mid-server-restart.  When set, the
  /// scrubber pins to the user's just-released target instead of
  /// reading the player's position/duration streams — those briefly
  /// emit a stale-old-position against a newer-shorter duration during
  /// `Player.open()`, which clamps to ratio 1.0 and visually jumps the
  /// thumb to the end of the track before settling.
  final bool isSeeking;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  /// While the user is actively dragging the scrubber, this holds the
  /// in-flight slider value (0..1) so the thumb tracks their finger
  /// without us having to call `player.seek` continuously.  Null
  /// otherwise — the slider then renders the player's actual reported
  /// position via the StreamBuilder.
  ///
  /// Pre-fix (2026-05-08 evening): the live `onChanged` callback called
  /// `player.seek(targetPlayerMs)` continuously during drag for visual
  /// preview.  When the user dragged forward past the current
  /// playlist's apparent end (because the playlist starts at segment K
  /// after a prior server-restart), the player-time clamp sent libmpv
  /// to the playlist's end → scrubber jumped to max → reset to target
  /// only after release fired the server-restart.  Operator-reported.
  /// Local drag-state fixes it: during drag we only render the new
  /// position, no player.seek; on release the cubit decides
  /// in-player-vs-server-restart with the source-time target.
  double? _dragValue;

  /// Holds the released drag value across the seek-commit window so
  /// the scrubber doesn't snap back to liveValue (current position) or
  /// chase the position/duration streams while libmpv is mid-reload.
  /// Cleared when:
  ///   1. the player's reported source-time settles within tolerance
  ///      of the pending target while not seeking — covers both the
  ///      in-player path (where `widget.isSeeking` never flips) and
  ///      the post-restart path once libmpv catches up to its new
  ///      coordinates.  See the post-frame callback in `build`.
  ///   2. the fallback timer fires after [_kPinMaxHoldSec] without
  ///      streams settling — guards against pathological seeks where
  ///      the player never converges on the target (paused, stalled,
  ///      or restart failure paths).
  ///
  /// Crucially we DO NOT clear the pin on the bare `isSeeking`
  /// true → false transition.  After server-restart's final emit, the
  /// new `playlistOffsetSec` lands a frame or two before the position
  /// stream catches up — clearing the pin then renders a transient
  /// `oldPlayerPos + newOffset` over `newPlayerDur + newOffset` ratio
  /// that exceeds 1.0 and clamps the scrubber to the end of the track
  /// for one paint, then settles.  Operator-reported "scrubber jumps
  /// to end then comes back" after the §17 follow-on patch.
  double? _pendingValue;
  Timer? _pinFallbackTimer;

  /// Tolerance for "player has caught up to the pending target", in ms.
  /// 750 ms covers a single segment-grain mismatch on stream-copy
  /// without making the hold linger after a clean in-player seek.
  static const _kPendingSettleToleranceMs = 750;

  /// Hard upper bound on how long the post-release pin can stay set.
  /// Server-restart with cold-cache seeks complete in ~1–2 s; 5 s
  /// covers slow networks and gives the streams time to converge.
  /// Past this point we drop the pin even if streams haven't settled,
  /// so a seek that fails or stalls doesn't strand the scrubber.
  static const _kPinMaxHoldSec = 5;

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _pinFallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offsetMs = (widget.playlistOffsetSec * 1000).toInt();
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      initialData: widget.player.state.position,
      builder: (context, posSnap) {
        final playerPos = posSnap.data ?? Duration.zero;
        // Display position is in source-time = player-time + offset.
        final sourcePos = Duration(
          milliseconds: playerPos.inMilliseconds + offsetMs,
        );
        return StreamBuilder<Duration>(
          stream: widget.player.stream.duration,
          initialData: widget.player.state.duration,
          builder: (context, durSnap) {
            final playerDur = durSnap.data ?? Duration.zero;
            // Total duration in source-time = playlist-duration + offset.
            // (The playlist runs from t=0 to (N-K)*hls_time; total source
            // is K*hls_time + (N-K)*hls_time = N*hls_time.)
            final sourceDur = Duration(
              milliseconds: playerDur.inMilliseconds + offsetMs,
            );
            // Slider's `value` follows the user's finger during drag
            // (via _dragValue), else mirrors the player's reported
            // source-time.  Avoids the "jumps to max" regression where
            // a forward drag past the current playlist's apparent end
            // would clamp player.seek to playerDur and the StreamBuilder
            // would render value=1.0 mid-drag.
            final liveValue = (sourceDur.inMilliseconds == 0)
                ? 0.0
                : (sourcePos.inMilliseconds / sourceDur.inMilliseconds).clamp(
                    0.0,
                    1.0,
                  );
            // Precedence: live drag (touch) > post-release pin > live
            // player position.  The pin holds while the cubit drives a
            // seek (debounce window + server-restart open/seek) so the
            // thumb doesn't snap back to the playhead and doesn't chase
            // libmpv's transient stale-position-against-new-duration
            // emissions.
            final value = _dragValue ?? _pendingValue ?? liveValue;
            // While the pin is active and we're not in a server-
            // restart, schedule a one-shot clear once the player's
            // reported source-time settles within tolerance of the
            // pinned target — this catches the in-player seek path
            // where `widget.isSeeking` never transitions.
            if (_dragValue == null &&
                _pendingValue != null &&
                !widget.isSeeking &&
                sourceDur.inMilliseconds > 0) {
              final pendingMs = (sourceDur.inMilliseconds * _pendingValue!)
                  .round();
              if ((sourcePos.inMilliseconds - pendingMs).abs() <
                  _kPendingSettleToleranceMs) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _pendingValue != null) {
                    setState(() => _pendingValue = null);
                  }
                });
              }
            }
            // Display position: while pinned (drag or post-release)
            // show the pinned target in source-time so the timestamp
            // tracks the thumb instead of the live playhead.
            final pinned = _dragValue ?? _pendingValue;
            final displayPos = pinned == null
                ? sourcePos
                : Duration(
                    milliseconds: (sourceDur.inMilliseconds * pinned).round(),
                  );

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Semantics(
                    label: 'Elapsed',
                    child: ExcludeSemantics(
                      child: Text(
                        _format(displayPos),
                        style: AppTypography.monoMicro.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      slider: true,
                      label: 'Seek',
                      value: '${_format(displayPos)} of ${_format(sourceDur)}',
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: AppColors.violet,
                          inactiveTrackColor: const Color(0x33FFFFFF),
                          thumbColor: AppColors.violet,
                          overlayColor: AppColors.pillBgPurple,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: value,
                          onChangeStart: (v) {
                            setState(() => _dragValue = v);
                          },
                          onChanged: (v) {
                            // No `player.seek` here — local-state-only
                            // preview avoids the "jumps to max" bug when
                            // dragging past the current playlist's end.
                            // Visual feedback is fluid because the slider
                            // re-renders with the new `_dragValue` on
                            // every onChanged tick.
                            setState(() => _dragValue = v);
                          },
                          onChangeEnd: (v) {
                            final sourceMs = (sourceDur.inMilliseconds * v)
                                .round();
                            // Hand the cubit a SOURCE-time target — the
                            // cubit decides server-restart vs in-player
                            // and converts to player-time itself.
                            final target = Duration(milliseconds: sourceMs);
                            // Pin the released value so the slider stays
                            // there across the cubit's seek-commit
                            // window (300 ms debounce + pause + open +
                            // seek for the server-restart path) and the
                            // post-emit settle-out where libmpv's
                            // position stream catches up to the new
                            // playlist coordinates.  Pin is dropped by
                            // the post-frame settle check in `build`
                            // once the player's source-time converges
                            // on the target, or by the fallback timer
                            // armed below if convergence never happens.
                            setState(() {
                              _dragValue = null;
                              _pendingValue = v;
                            });
                            _pinFallbackTimer?.cancel();
                            _pinFallbackTimer = Timer(
                              const Duration(seconds: _kPinMaxHoldSec),
                              () {
                                if (mounted && _pendingValue != null) {
                                  setState(() => _pendingValue = null);
                                }
                              },
                            );
                            if (widget.onSeekCommit != null) {
                              widget.onSeekCommit!(target);
                            } else {
                              // No cubit hookup → fall through to a raw
                              // in-player seek using player-time.
                              final playerMs = (sourceMs - offsetMs).clamp(
                                0,
                                playerDur.inMilliseconds,
                              );
                              widget.player.seek(
                                Duration(milliseconds: playerMs),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: 'Total duration',
                    child: ExcludeSemantics(
                      child: Text(
                        _format(sourceDur),
                        style: AppTypography.monoMicro.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 4x2 grid of quick actions (Lock / Fit-Fill / Audio / Subs / Speed /
/// Quality / Sleep / Cast).
///
/// Public + `@visibleForTesting` so golden tests can capture the row in
/// isolation.  Production code only instantiates it from
/// `FluxPlayerControls.build`.
class PlayerQuickActions extends StatelessWidget {
  @visibleForTesting
  const PlayerQuickActions({
    super.key,
    required this.onLock,
    required this.onFit,
    required this.fitCover,
    required this.onOpenSheet,
    required this.sleepActive,
    this.audioTrackCount = 0,
  });

  final VoidCallback onLock;
  final VoidCallback onFit;
  final bool fitCover;
  final ValueChanged<Sheet> onOpenSheet;
  final bool sleepActive;

  /// Plan 22 — number of audio tracks the source container exposes,
  /// surfaced from the cubit's `availableAudioTracks`.  When `<= 1`
  /// the Audio quick-action greys out with a tooltip explaining why
  /// (the picker would be empty / single-row).  Default `0` keeps the
  /// action disabled when no `PlayerCubit` is above the widget (golden
  /// tests, widget previews).
  final int audioTrackCount;

  @override
  Widget build(BuildContext context) {
    // 4x2 grid per plan §14 ("4x2 quick-control grid"). Two Rows of four
    // Expanded cells fits at portrait widths (412 px) where the prior
    // single 8-cell Row overflowed by ~111 px. Equal Expanded weights
    // give the same spacing landscape and portrait, no MediaQuery branch.
    final audioDisabled = audioTrackCount <= 1;
    final row1 = [
      _Action(
        icon: Icons.lock_outline,
        label: 'Lock',
        semanticLabel: 'Lock controls',
        onTap: onLock,
      ),
      _Action(
        icon: fitCover ? Icons.fit_screen : Icons.aspect_ratio,
        label: fitCover ? 'Fit' : 'Fill',
        semanticLabel: fitCover
            ? 'Switch to fit (letterbox) mode'
            : 'Switch to fill (cover) mode',
        onTap: onFit,
      ),
      _Action(
        icon: Icons.audiotrack_outlined,
        label: 'Audio',
        semanticLabel: 'Audio tracks',
        onTap: audioDisabled ? null : () => onOpenSheet(Sheet.audioSubs),
        disabled: audioDisabled,
        tooltip: audioDisabled ? 'Only one audio track in this file' : null,
      ),
      _Action(
        icon: Icons.subtitles_outlined,
        label: 'Subs',
        semanticLabel: 'Subtitles',
        onTap: () => onOpenSheet(Sheet.audioSubs),
      ),
    ];
    final row2 = [
      _Action(
        icon: Icons.speed,
        label: 'Speed',
        semanticLabel: 'Playback speed',
        onTap: () => onOpenSheet(Sheet.speed),
      ),
      _Action(
        icon: Icons.high_quality_outlined,
        label: 'Quality',
        semanticLabel: 'Video quality',
        onTap: () => onOpenSheet(Sheet.quality),
      ),
      _Action(
        icon: sleepActive ? Icons.bedtime : Icons.bedtime_outlined,
        label: 'Sleep',
        semanticLabel: sleepActive ? 'Sleep timer (active)' : 'Sleep timer',
        onTap: () => onOpenSheet(Sheet.sleep),
        highlight: sleepActive,
      ),
      _Action(
        icon: Icons.cast,
        label: 'Cast',
        semanticLabel: 'Cast to device',
        onTap: () => onOpenSheet(Sheet.cast),
      ),
    ];
    return Semantics(
      container: true,
      label: 'Quick actions',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [for (final a in row1) Expanded(child: a)]),
            const SizedBox(height: 8),
            Row(children: [for (final a in row2) Expanded(child: a)]),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    this.semanticLabel,
    this.onTap,
    this.highlight = false,
    this.disabled = false,
    this.tooltip,
  });

  final IconData icon;
  final String label;

  /// Screen-reader-friendly label.  Falls back to [label] (the visible
  /// caption text) when omitted — but most call sites should pass an
  /// explicit verb-phrase ("Lock controls", "Cast to device") because
  /// the short caption is too cryptic when announced aloud.
  final String? semanticLabel;
  final VoidCallback? onTap;
  final bool highlight;

  /// Plan 22 — when true the action renders dimmed and skips its
  /// InkWell `onTap`.  Currently driven by the Audio quick-action's
  /// "≤ 1 audio track" gate.  Distinct from `onTap == null` so the
  /// caller can pass both (the InkWell still mounts so the long-press
  /// tooltip can fire on the disabled affordance).
  final bool disabled;

  /// Optional Material tooltip displayed on long-press / hover.  Used
  /// by plan 22 to explain why the Audio action is greyed when the
  /// source carries 0-or-1 audio tracks.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (disabled) {
      color = Colors.white.withValues(alpha: 0.35);
    } else if (highlight) {
      color = AppColors.violetTint;
    } else {
      color = Colors.white;
    }
    final inkwell = InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.captionV2.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final tip = tooltip;
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      enabled: !disabled,
      hint: tip,
      child: tip != null ? Tooltip(message: tip, child: inkwell) : inkwell,
    );
  }
}

/// Edge-anchored brightness / volume passive indicator rail.
///
/// Public + `@visibleForTesting` so golden tests can capture each rail
/// (left = brightness, right = volume) without standing up the full
/// player overlay or a landscape MediaQuery.
class PlayerSideRail extends StatelessWidget {
  @visibleForTesting
  const PlayerSideRail({
    super.key,
    required this.icon,
    required this.label,
    required this.align,
    required this.kind,
  });

  final IconData icon;
  final String label;
  final Alignment align;

  /// Which axis the rail represents — drives the screen-reader hint
  /// ("Drag up or down on the left half / right half to change …").
  final PlayerDragKind kind;

  String get _hint {
    switch (kind) {
      case PlayerDragKind.brightness:
        return 'Drag up or down on the left half of the screen to change brightness';
      case PlayerDragKind.volume:
        return 'Drag up or down on the right half of the screen to change volume';
      case PlayerDragKind.seek:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: _hint,
      // Rail itself is a passive indicator — the value-reporting slider
      // semantics live on the centred drag HUD that appears while the
      // operator is actually dragging.  Flagging it `readOnly` so screen
      // readers don't announce it as actionable.
      readOnly: true,
      child: SizedBox(
        width: 64,
        child: Align(
          alignment: align,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppTypography.captionV2.copyWith(
                      color: Colors.white70,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Double-tap seek ripple — expands from 0.4 → 1.0 over 400 ms with an
/// `easeOut` curve, then is removed by the parent's `_rippleTimer`
/// after the same duration.  Stateful so the animation runs once on
/// mount instead of every parent rebuild.  Per plan §7 row M14 the
/// ripple-expand timing target is 400 ms.
class _SeekRipple extends StatefulWidget {
  const _SeekRipple({required this.position, required this.isForward});

  final Offset position;
  final bool isForward;

  @override
  State<_SeekRipple> createState() => _SeekRippleState();
}

class _SeekRippleState extends State<_SeekRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _kRippleMs,
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 60,
      top: widget.position.dy - 60,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = Curves.easeOut.transform(_ctrl.value);
            final scale = 0.4 + (0.6 * t);
            final opacity = (1.0 - t).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.violet.withValues(alpha: 0.18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.isForward ? Icons.forward_10 : Icons.replay_10,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PeekBadge extends StatelessWidget {
  const _PeekBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fast_forward, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            '2× speed',
            style: AppTypography.captionV2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DragHud extends StatelessWidget {
  const _DragHud({required this.kind, required this.value});

  final PlayerDragKind? kind;
  final double value;

  IconData get _icon {
    if (kind == PlayerDragKind.brightness) {
      if (value < 0.33) return Icons.brightness_low;
      if (value < 0.66) return Icons.brightness_medium;
      return Icons.brightness_high;
    }
    if (kind == PlayerDragKind.volume) {
      if (value == 0) return Icons.volume_off;
      if (value < 0.5) return Icons.volume_down;
      return Icons.volume_up;
    }
    return Icons.drag_handle;
  }

  String get _label {
    switch (kind) {
      case PlayerDragKind.brightness:
        return 'Brightness';
      case PlayerDragKind.volume:
        return 'Volume';
      case PlayerDragKind.seek:
      case null:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: const Color(0x33FFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.violet),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_label  ${(value * 100).round()}%',
            style: AppTypography.captionV2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small inline pill showing the current stream's HDR format.  When
/// the server is tonemapping HDR → SDR, the pill flips to a neutral
/// "SDR" label so the override state is visible at a glance.
class _HdrChip extends StatelessWidget {
  const _HdrChip({required this.format, required this.tonemapped});

  final String format; // "HDR10" / "HLG" / "DolbyVision"
  final bool tonemapped;

  String get _label {
    if (tonemapped) return 'SDR';
    if (format == 'DolbyVision') return 'DV';
    return format;
  }

  @override
  Widget build(BuildContext context) {
    final bg = tonemapped
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.violet.withValues(alpha: 0.85);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
