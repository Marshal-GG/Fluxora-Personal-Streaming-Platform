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
import 'package:fluxora_core/fluxora_core.dart';
import 'package:media_kit/media_kit.dart' show Player;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:fluxora_mobile/features/player/presentation/controllers/player_controls_controller.dart';
import 'package:fluxora_mobile/features/player/presentation/sheets/audio_subs_sheet.dart';
import 'package:fluxora_mobile/features/player/presentation/sheets/cast_sheet.dart';
import 'package:fluxora_mobile/features/player/presentation/sheets/quality_sheet.dart';
import 'package:fluxora_mobile/features/player/presentation/sheets/sleep_sheet.dart';
import 'package:fluxora_mobile/features/player/presentation/sheets/speed_sheet.dart';

class FluxPlayerControls extends StatefulWidget {
  const FluxPlayerControls({
    required this.player,
    required this.controller,
    required this.title,
    required this.onBack,
    super.key,
  });

  final Player player;
  final PlayerControlsController controller;
  final String title;
  final VoidCallback onBack;

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

  @override
  void initState() {
    super.initState();
    widget.controller.show();
    widget.controller.addListener(_onChange);
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
    final pos = widget.player.state.position;
    final dur = widget.player.state.duration;
    var target = pos + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > dur) target = dur;
    widget.player.seek(target);
    widget.controller.show();
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
    _rippleTimer = Timer(const Duration(milliseconds: 400), () {
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
    return (elapsed.inMilliseconds / _unlockHoldDuration.inMilliseconds)
        .clamp(0.0, 1.0);
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
              duration: const Duration(milliseconds: 250),
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
              _SeekRipple(
                position: _ripplePos!,
                isForward: _rippleIsForward,
              ),

            if (_peekRestoreRate != null)
              const Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Center(child: _PeekBadge()),
              ),

            if (c.dragHudVisible)
              Positioned.fill(
                child: Center(
                  child: _DragHud(
                    kind: c.activeDrag,
                    value: c.dragHudValue,
                  ),
                ),
              ),

            if (c.visible && !c.lockMode) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: _TopBar(
                    title: widget.title,
                    onBack: widget.onBack,
                    onMore: () {},
                    sleepActive: _sleepDuration != null,
                  ),
                ),
              ),

              Positioned.fill(
                child: Center(
                  child: _CenterTransport(
                    isPlaying: widget.player.state.playing,
                    onRewind: () =>
                        _seekRelative(const Duration(seconds: -10)),
                    onPlayPause: _togglePlay,
                    onForward: () =>
                        _seekRelative(const Duration(seconds: 10)),
                  ),
                ),
              ),

              if (isLandscape) ...[
                const Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: _SideRail(
                    icon: Icons.brightness_6_outlined,
                    label: 'Brightness',
                    align: Alignment.centerLeft,
                  ),
                ),
                const Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: _SideRail(
                    icon: Icons.volume_up_outlined,
                    label: 'Volume',
                    align: Alignment.centerRight,
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
                      _ProgressBar(player: widget.player),
                      const SizedBox(height: 8),
                      _QuickActions(
                        onLock: c.lock,
                        onFit: c.toggleFit,
                        fitCover: c.fitCover,
                        onOpenSheet: _openSheet,
                        sleepActive: _sleepDuration != null,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ],

            if (c.lockMode)
              Positioned(
                bottom: 24 + MediaQuery.of(context).padding.bottom,
                left: 0,
                right: 0,
                child: Center(
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
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.borderSubtle),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.lock_open_outlined,
                                color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (c.lockMode && _unlockHoldStart == null)
              Positioned(
                bottom: 8 + MediaQuery.of(context).padding.bottom,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Press and hold to unlock',
                    style: AppTypography.captionV2.copyWith(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum Sheet { none, audioSubs, speed, sleep, quality, cast }

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onMore,
    required this.sleepActive,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final bool sleepActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: onBack,
            splashRadius: 22,
          ),
          Expanded(
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
          if (sleepActive)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.bedtime,
                  color: AppColors.violetTint, size: 18),
            ),
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: onMore,
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}

class _CenterTransport extends StatelessWidget {
  const _CenterTransport({
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
        _CircleButton(icon: Icons.replay_10, size: 56, onPressed: onRewind),
        const SizedBox(width: 24),
        _CircleButton(
          icon: isPlaying ? Icons.pause : Icons.play_arrow,
          size: 72,
          gradient: true,
          onPressed: onPlayPause,
        ),
        const SizedBox(width: 24),
        _CircleButton(
          icon: Icons.forward_10,
          size: 56,
          onPressed: onForward,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.size,
    required this.onPressed,
    this.gradient = false,
  });

  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: gradient
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
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.player});

  final Player player;

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, posSnap) {
        final pos = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: player.state.duration,
          builder: (context, durSnap) {
            final dur = durSnap.data ?? Duration.zero;
            final value = (dur.inMilliseconds == 0)
                ? 0.0
                : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    _format(pos),
                    style: AppTypography.monoMicro.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                        onChanged: (v) {
                          final ms = (dur.inMilliseconds * v).round();
                          player.seek(Duration(milliseconds: ms));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _format(dur),
                    style: AppTypography.monoMicro.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onLock,
    required this.onFit,
    required this.fitCover,
    required this.onOpenSheet,
    required this.sleepActive,
  });

  final VoidCallback onLock;
  final VoidCallback onFit;
  final bool fitCover;
  final ValueChanged<Sheet> onOpenSheet;
  final bool sleepActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Action(icon: Icons.lock_outline, label: 'Lock', onTap: onLock),
          _Action(
            icon: fitCover ? Icons.fit_screen : Icons.aspect_ratio,
            label: fitCover ? 'Fit' : 'Fill',
            onTap: onFit,
          ),
          _Action(
            icon: Icons.audiotrack_outlined,
            label: 'Audio',
            onTap: () => onOpenSheet(Sheet.audioSubs),
          ),
          _Action(
            icon: Icons.subtitles_outlined,
            label: 'Subs',
            onTap: () => onOpenSheet(Sheet.audioSubs),
          ),
          _Action(
            icon: Icons.speed,
            label: 'Speed',
            onTap: () => onOpenSheet(Sheet.speed),
          ),
          _Action(
            icon: Icons.high_quality_outlined,
            label: 'Quality',
            onTap: () => onOpenSheet(Sheet.quality),
          ),
          _Action(
            icon: sleepActive ? Icons.bedtime : Icons.bedtime_outlined,
            label: 'Sleep',
            onTap: () => onOpenSheet(Sheet.sleep),
            highlight: sleepActive,
          ),
          _Action(
            icon: Icons.cast,
            label: 'Cast',
            onTap: () => onOpenSheet(Sheet.cast),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.violetTint : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.icon,
    required this.label,
    required this.align,
  });

  final IconData icon;
  final String label;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
    );
  }
}

class _SeekRipple extends StatelessWidget {
  const _SeekRipple({required this.position, required this.isForward});

  final Offset position;
  final bool isForward;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 60,
      top: position.dy - 60,
      child: IgnorePointer(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.violet.withValues(alpha: 0.18),
          ),
          alignment: Alignment.center,
          child: Icon(
            isForward ? Icons.forward_10 : Icons.replay_10,
            color: Colors.white,
            size: 36,
          ),
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
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.violet),
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
