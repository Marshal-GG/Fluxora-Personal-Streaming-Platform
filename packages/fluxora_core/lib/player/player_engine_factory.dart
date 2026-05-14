/// Picks the right [PlayerEngine] implementation for the current
/// platform.
///
/// Plan 24 M2 — always returns [MediaKitEngine] regardless of
/// platform.  M3 introduces an `ExoPlayerEngine` for Android; the
/// switch happens here at that point, gated by
/// [_kForceMediaKitOnAndroid] so the operator can fall back instantly
/// if Media3 regresses something subtle.  M9 deletes the flag once
/// ExoPlayer ships cleanly.
library;

import 'package:fluxora_core/player/media_kit_engine.dart';
import 'package:fluxora_core/player/player_engine.dart';

/// Force the legacy libmpv path on Android even after the ExoPlayer
/// engine is wired in (M3+).  Stays `false` for normal builds; flip
/// to `true` in a test branch / dev settings hook if Media3 turns
/// out to regress on a specific device.  Deleted in M9.
///
/// As of M2 this flag has no observable effect because the
/// `ExoPlayerEngine` doesn't exist yet — the factory always returns
/// [MediaKitEngine] on every platform.
// ignore: unused_element
const bool _kForceMediaKitOnAndroid = false;

class PlayerEngineFactory {
  const PlayerEngineFactory._();

  /// Build the right engine for the current platform.
  ///
  /// As of M2 every platform gets [MediaKitEngine] — including
  /// Android.  M3 changes the Android branch to return an
  /// `ExoPlayerEngine` instance instead, unless [_kForceMediaKitOnAndroid]
  /// is set (operator escape hatch).
  static Future<PlayerEngine> create() async {
    // Future M3 shape (kept commented to document the rollout plan):
    //
    //   if (Platform.isAndroid && !_kForceMediaKitOnAndroid) {
    //     return ExoPlayerEngine.create();
    //   }
    //
    // Today every platform falls through to MediaKitEngine — desktop
    // and iOS where it's the long-term answer, Android until M3 ships
    // its replacement.
    return MediaKitEngine.create();
  }
}
