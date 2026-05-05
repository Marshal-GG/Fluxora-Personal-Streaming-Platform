import 'package:fluxora_mobile/features/player/domain/entities/stream_start_response.dart';

abstract class PlayerRepository {
  Future<StreamStartResponse> startStream(String fileId, {bool tonemap = false});
  Future<void> stopStream(String sessionId);
  Future<void> updateProgress(String sessionId, double progressSec);

  /// Re-spawn the active FFmpeg from [seekSec] for [sessionId].
  ///
  /// Returns when the server has acknowledged the new seek (HTTP 204).  The
  /// playlist URL is unchanged but its *contents* are rewritten with new
  /// segment numbering + a discontinuity marker — the caller is responsible
  /// for re-opening the playlist on the player so libmpv flushes its cached
  /// VOD playlist.  Pass [tonemap] = whatever the session is currently
  /// streaming with so the seek doesn't silently revert HDR→SDR.
  Future<void> seekStream(
    String sessionId,
    double seekSec, {
    bool tonemap = false,
  });
}
