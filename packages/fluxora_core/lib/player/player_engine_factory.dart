/// Picks the right [PlayerEngine] implementation for the current
/// platform.
///
/// Android runs Media3 [ExoPlayerEngine] by default; every other
/// platform (desktop, iOS) runs libmpv-via-[MediaKitEngine].
/// [_kForceMediaKitOnAndroid] is the operator escape hatch — flip
/// to `true` in a test branch or hotfix to force libmpv on Android
/// if Media3 ever regresses on a specific device.
library;

import 'dart:io' show Platform;

import 'package:fluxora_core/player/exo_player_engine.dart';
import 'package:fluxora_core/player/media_kit_engine.dart';
import 'package:fluxora_core/player/player_engine.dart';

/// Force the legacy libmpv path on Android.  Stays `false` for normal
/// builds; flip to `true` if Media3 turns out to regress on a specific
/// device pool.
// ignore: unused_element
const bool _kForceMediaKitOnAndroid = false;

class PlayerEngineFactory {
  const PlayerEngineFactory._();

  /// Build the right engine for the current platform.
  ///
  /// Android with [_kForceMediaKitOnAndroid] = false → [ExoPlayerEngine].
  /// Every other path (desktop, iOS, Android with the rollback flag
  /// flipped) → [MediaKitEngine].
  static Future<PlayerEngine> create() async {
    if (Platform.isAndroid && !_kForceMediaKitOnAndroid) {
      return ExoPlayerEngine.create();
    }
    return MediaKitEngine.create();
  }
}
