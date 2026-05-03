/// `PlayerControlsController` — UI-only state for the redesigned player
/// chrome. Lives inside the player screen (one per `_PlayerView` mount).
/// Owns visibility / lock-mode / fit-cover toggles + auto-hide timer +
/// drag-HUD scratchpad fields used by M6 gestures.
///
/// Per plan §1 row 8 + §9.1, this is a `ChangeNotifier` not a `Cubit` —
/// it is owned by the screen, not registered in DI, and purely UI state.
/// `PlayerCubit` keeps owning network / transport / progress concerns.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Which gesture is currently driving the drag HUD overlay.
enum PlayerDragKind { brightness, volume, seek }

class PlayerControlsController extends ChangeNotifier {
  PlayerControlsController();

  bool _visible = true;
  bool _lockMode = false;
  bool _fitCover = true;
  Timer? _autoHide;

  PlayerDragKind? _activeDrag;
  double _dragHudValue = 0.0;
  bool _dragHudVisible = false;

  /// Top / side / bottom overlay visibility.
  bool get visible => _visible;

  /// True while the lock overlay is engaged — disables every gesture
  /// except unlock.
  bool get lockMode => _lockMode;

  /// `true` = video filled to cover; `false` = letterbox fit.
  bool get fitCover => _fitCover;

  PlayerDragKind? get activeDrag => _activeDrag;
  double get dragHudValue => _dragHudValue;
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

  /// Toggle fit/letterbox.
  void toggleFit() {
    _fitCover = !_fitCover;
    notifyListeners();
  }

  // ── Drag HUD scratchpad (consumed by M6 gestures). ──

  void setBrightnessHud(double v) {
    _activeDrag = PlayerDragKind.brightness;
    _dragHudValue = v;
    _dragHudVisible = true;
    notifyListeners();
  }

  void setVolumeHud(double v) {
    _activeDrag = PlayerDragKind.volume;
    _dragHudValue = v;
    _dragHudVisible = true;
    notifyListeners();
  }

  void setSeekHud(Duration v) {
    _activeDrag = PlayerDragKind.seek;
    _dragHudValue = v.inMilliseconds.toDouble();
    _dragHudVisible = true;
    notifyListeners();
  }

  void clearHud() {
    _activeDrag = null;
    _dragHudVisible = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _autoHide = null;
    super.dispose();
  }
}
