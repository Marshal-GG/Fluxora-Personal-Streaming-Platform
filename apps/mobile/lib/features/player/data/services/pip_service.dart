/// Picture-in-Picture method-channel bridge.
///
/// Player polish round (2026-05-04).  Calls into the native side
/// (`MainActivity.kt`) to enter PIP mode with the source video's
/// intrinsic aspect ratio.  Android-only — the method channel is
/// registered only by the Android Activity, so [enter] resolves to
/// `false` on iOS / desktop builds and the caller can hide the
/// affordance.
///
/// **Why a method channel and not a pub dep:** PIP is a single
/// `enterPictureInPictureMode()` call backed by a single
/// `PictureInPictureParams` builder.  Pulling `floating` /
/// `pip_mode` would add a transitive supply-chain footprint for ~40
/// lines of Kotlin.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class PipService {
  PipService._();

  static const _channel = MethodChannel('dev.marshalx.fluxora/pip');
  static final _log = Logger();

  /// Best-effort capability probe — returns `false` on iOS, on Android
  /// devices without the PIP system feature, or if the method channel
  /// throws for any reason.  UI uses this to decide whether to render
  /// the PIP button at all.
  static Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('isSupported');
      return ok ?? false;
    } catch (e, st) {
      _log.w('PIP isSupported probe failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Enter Picture-in-Picture with the supplied source aspect ratio.
  /// `width` / `height` are the video's intrinsic pixel dimensions —
  /// the native side clamps to Android's accepted aspect range.
  ///
  /// Returns `true` when the system accepted the request, `false`
  /// otherwise (denied permission, Android <8.0, or method-channel
  /// error).  Caller should treat any failure as a no-op rather than
  /// surfacing an error to the user — PIP is a polish affordance.
  static Future<bool> enter({
    required int width,
    required int height,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('enter', {
        'width': width,
        'height': height,
      });
      return ok ?? false;
    } catch (e, st) {
      _log.w('PIP enter failed', error: e, stackTrace: st);
      return false;
    }
  }
}
