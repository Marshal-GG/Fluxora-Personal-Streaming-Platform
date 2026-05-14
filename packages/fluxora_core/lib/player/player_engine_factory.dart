/// Picks the right [PlayerEngine] implementation for the current
/// platform.
///
/// Plan 24 M2 carved this out so the cubit + UI talk to one
/// abstraction.  M3 added [ExoPlayerEngine] (the Android Media3
/// backend) and wired this factory to return it when both:
///
///   * the host platform is Android, **and**
///   * the rollout flag [_kEnableExoPlayerEngine] is `true`.
///
/// The flag stays `false` by default so a build picked up by the
/// operator before M4 (Kotlin side hardening) lands still gets the
/// proven [MediaKitEngine] path.  The parent agent flips it to `true`
/// once M4 ships.  [_kForceMediaKitOnAndroid] is the operator escape
/// hatch — a single `true` flip there forces Android back onto
/// libmpv-via-media_kit even after ExoPlayer is the default.
///
/// Both flags delete in M9 once the migration is locked in.
library;

import 'dart:io' show Platform;

import 'package:fluxora_core/player/exo_player_engine.dart';
import 'package:fluxora_core/player/media_kit_engine.dart';
import 'package:fluxora_core/player/player_engine.dart';

/// Master switch for plan 24 M3 → M9.  Flipped to `true` 2026-05-15
/// once both M3 (Dart side) and M4 (Kotlin module) landed and the
/// debug APK built cleanly against Media3 1.10.1.  Real-device smoke
/// (M5+) drives the operator validation.  Deleting this flag is the
/// last step of M9.
const bool _kEnableExoPlayerEngine = true;

/// Force the legacy libmpv path on Android even after the ExoPlayer
/// engine is wired in.  Stays `false` for normal builds; flip to
/// `true` in a test branch / dev settings hook if Media3 turns out to
/// regress on a specific device.  Deleted in M9.
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
