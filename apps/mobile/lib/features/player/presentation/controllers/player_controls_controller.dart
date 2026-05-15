/// `PlayerControlsController` — UI-only state for the redesigned player
/// chrome. Lives inside the player screen (one per `_PlayerView` mount).
/// Owns visibility / lock-mode / fit-mode toggles + auto-hide timer +
/// drag-HUD scratchpad fields used by gestures.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Which gesture is currently driving the drag HUD overlay.
enum PlayerDragKind { brightness, volume, seek, zoom, fitMode }

/// Discrete aspect-ratio handling mode for the video surface.
///
/// * [fit] — letterbox / pillarbox; preserves aspect ratio, may show
///   black bars on one axis.  Default — matches what most players
///   open with.
/// * [fill] — crop to fill; preserves aspect ratio but trims content
///   on one axis so the surface fills the whole viewport.
/// * [stretch] — ignore aspect ratio; the video is distorted to fill
///   every pixel of the viewport.  Rarely useful but operators
///   occasionally want it.
enum FitMode { fit, fill, stretch }

class PlayerControlsController extends ChangeNotifier {
  PlayerControlsController();

  bool _visible = true;
  bool _lockMode = false;
  FitMode _fitMode = FitMode.fit;
  double _userScale = 1.0;
  Timer? _autoHide;
  Timer? _hudAutoHide;

  /// Free-form pinch-zoom scale applied to the video surface on top of
  /// the discrete fit mode.  Clamped to [_kMinUserScale,
  /// _kMaxUserScale] — 0.5x lets the user shrink an over-large fill
  /// crop back inside the bezel; 4x is a comfortable maximum before
  /// the texture quality drops noticeably on a 1080p source.
  static const double _kMinUserScale = 0.5;
  static const double _kMaxUserScale = 4.0;
  double get userScale => _userScale;

  PlayerDragKind? _activeDrag;
  double _dragHudValue = 0.0;
  String? _dragHudLabel;
  bool _dragHudVisible = false;

  /// Top / side / bottom overlay visibility.
  bool get visible => _visible;

  /// True while the lock overlay is engaged — disables every gesture
  /// except unlock.
  bool get lockMode => _lockMode;

  /// Current discrete fit mode (fit / fill / stretch).
  FitMode get fitMode => _fitMode;

  PlayerDragKind? get activeDrag => _activeDrag;
  double get dragHudValue => _dragHudValue;
  String? get dragHudLabel => _dragHudLabel;
  bool get dragHudVisible => _dragHudVisible;

  /// Toggle visibility. If newly visible, schedule the auto-hide timer.
  void toggle() {
    if (_visible) {
      hide();
    } else {
      show();
    }
  }

  /// Show controls and (re)start the 3-second auto-hide timer.
  void show() {
    _autoHide?.cancel();
    if (!_visible) {
      _visible = true;
      notifyListeners();
    }
    _autoHide = Timer(const Duration(seconds: 3), hide);
  }

  /// Hide controls immediately and cancel any pending auto-hide.
  void hide() {
    _autoHide?.cancel();
    _autoHide = null;
    if (_visible) {
      _visible = false;
      notifyListeners();
    }
  }

  /// Engage lock mode — controls hide and gestures are ignored.
  void lock() {
    _lockMode = true;
    hide();
    notifyListeners();
  }

  /// Release lock mode — controls become re-toggleable.
  void unlock() {
    _lockMode = false;
    show();
    notifyListeners();
  }

  /// Cycle the fit mode: fit → fill → stretch → fit.  Flashes the
  /// current mode's label in the drag HUD for ~1.2 s so the operator
  /// sees what mode they just switched to.
  void cycleFitMode() {
    _fitMode = switch (_fitMode) {
      FitMode.fit => FitMode.fill,
      FitMode.fill => FitMode.stretch,
      FitMode.stretch => FitMode.fit,
    };
    _flashFitModeHud();
    notifyListeners();
  }

  /// Set the fit mode directly (used by tests / debug surfaces).
  void setFitMode(FitMode mode) {
    if (mode == _fitMode) return;
    _fitMode = mode;
    _flashFitModeHud();
    notifyListeners();
  }

  void _flashFitModeHud() {
    _activeDrag = PlayerDragKind.fitMode;
    _dragHudLabel = switch (_fitMode) {
      FitMode.fit => 'Fit',
      FitMode.fill => 'Fill',
      FitMode.stretch => 'Stretch',
    };
    _dragHudValue = 0.0;
    _dragHudVisible = true;
    _scheduleHudClear(const Duration(milliseconds: 1200));
  }

  /// Apply a free-form scale from a pinch gesture, clamped to the
  /// configured range.  Stacks on top of the discrete fit mode — fit
  /// + scale=1.0 = letterboxed; fit + scale=2.0 = letterboxed and 2x
  /// zoomed in centred on the surface.  Also flashes the current
  /// zoom level (e.g. `1.5×`) in the drag HUD.
  void setUserScale(double scale) {
    final clamped = scale.clamp(_kMinUserScale, _kMaxUserScale).toDouble();
    if (clamped == _userScale) return;
    _userScale = clamped;
    _flashZoomHud(clamped);
    notifyListeners();
  }

  /// Reset pinch-zoom back to 1.0.  Wired to long-press on the Fit
  /// button so the user can recover quickly without pinching back.
  void resetUserScale() {
    if (_userScale == 1.0) return;
    _userScale = 1.0;
    _flashZoomHud(1.0);
    notifyListeners();
  }

  void _flashZoomHud(double scale) {
    _activeDrag = PlayerDragKind.zoom;
    _dragHudValue = scale;
    _dragHudLabel = '${scale.toStringAsFixed(scale >= 1.0 ? 2 : 2)}×';
    _dragHudVisible = true;
    // Clear shortly after the user stops pinching.  900 ms is enough
    // for the operator to read the value without lingering during a
    // fast pinch.
    _scheduleHudClear(const Duration(milliseconds: 900));
  }

  void _scheduleHudClear(Duration after) {
    _hudAutoHide?.cancel();
    _hudAutoHide = Timer(after, () {
      if (_dragHudVisible) {
        _activeDrag = null;
        _dragHudLabel = null;
        _dragHudVisible = false;
        notifyListeners();
      }
    });
  }

  // ── Drag HUD scratchpad (consumed by gestures). ──

  void setBrightnessHud(double v) {
    _hudAutoHide?.cancel();
    _activeDrag = PlayerDragKind.brightness;
    _dragHudValue = v;
    _dragHudLabel = null;
    _dragHudVisible = true;
    notifyListeners();
  }

  void setVolumeHud(double v) {
    _hudAutoHide?.cancel();
    _activeDrag = PlayerDragKind.volume;
    _dragHudValue = v;
    _dragHudLabel = null;
    _dragHudVisible = true;
    notifyListeners();
  }

  void setSeekHud(Duration v) {
    _hudAutoHide?.cancel();
    _activeDrag = PlayerDragKind.seek;
    _dragHudValue = v.inMilliseconds.toDouble();
    _dragHudLabel = null;
    _dragHudVisible = true;
    notifyListeners();
  }

  void clearHud() {
    _hudAutoHide?.cancel();
    _hudAutoHide = null;
    _activeDrag = null;
    _dragHudLabel = null;
    _dragHudVisible = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _autoHide = null;
    _hudAutoHide?.cancel();
    _hudAutoHide = null;
    super.dispose();
  }
}
