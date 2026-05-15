/// Picks the right [PlayerEngine] implementation for the current
/// platform.
///
/// Android returns [ExoPlayerEngine] when both:
///
///   * the host platform is Android, **and**
///   * the rollout flag [_kEnableExoPlayerEngine] is `true`.
///
/// [_kForceMediaKitOnAndroid] is the operator escape hatch — a
/// single `true` flip there forces Android back onto libmpv-via-
/// media_kit even when ExoPlayer is the default.
library;

import 'dart:io' show Platform;

import 'package:fluxora_core/player/exo_player_engine.dart';
import 'package:fluxora_core/player/media_kit_engine.dart';
import 'package:fluxora_core/player/player_engine.dart';

/// Master switch for the Android ExoPlayer engine.  `true` makes
/// Android sessions default to Media3 ExoPlayer; `false` falls back
/// to the libmpv-via-media_kit path.
const bool _kEnableExoPlayerEngine = true;

/// Force the legacy libmpv path on Android even when the ExoPlayer
/// engine is wired in.  Stays `false` for normal builds; flip to
/// `true` in a test branch / dev settings hook if Media3 regresses
/// on a specific device.
// ignore: unused_element
const bool _kForceMediaKitOnAndroid = false;

class PlayerEngineFactory {
  const PlayerEngineFactory._();

  /// Build the right engine for the current platform.
  ///
  /// Android with [_kEnableExoPlayerEngine] = true and
  /// [_kForceMediaKitOnAndroid] = false → [ExoPlayerEngine].
  /// Every other path (desktop, iOS, Android with either flag flipped
  /// the other way) → [MediaKitEngine].
  static Future<PlayerEngine> create() async {
    if (Platform.isAndroid &&
        _kEnableExoPlayerEngine &&
        !_kForceMediaKitOnAndroid) {
      return ExoPlayerEngine.create();
    }
    return MediaKitEngine.create();
  }
}
