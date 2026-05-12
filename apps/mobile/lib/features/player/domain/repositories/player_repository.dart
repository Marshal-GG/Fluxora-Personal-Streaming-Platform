import 'package:fluxora_mobile/features/player/domain/entities/stream_start_response.dart';

abstract class PlayerRepository {
  /// `POST /api/v1/stream/start/{file_id}` — kick off an HLS streaming
  /// session.  Returns the playlist URL + the resume position the
  /// server actually applied (segment-snapped to a multiple of
  /// `hls_time` so the player's first segment request hits encoded
  /// bytes immediately).
  ///
  /// [seekSec] (optional) overrides the server's DB-stored
  /// `last_progress_sec` fallback — use this when the caller knows
  /// the live playhead more precisely than the DB does (e.g. the
  /// HDR↔SDR toggle path, where `setTonemap` captures
  /// `_player.state.position` at toggle time).  When omitted, the
  /// server reads `media_files.last_progress_sec` so a half-watched
  /// file resumes from where the user left off.  Streaming pipeline
  /// plan §16 M1.
  Future<StreamStartResponse> startStream(
    String fileId, {
    bool tonemap = false,
    double? seekSec,
  });
  Future<void> stopStream(String sessionId);
  Future<void> updateProgress(String sessionId, double progressSec);

  /// Re-spawn the active FFmpeg from [seekSec] for [sessionId].
  ///
  /// Returns the segment-snapped seek value the server actually applied
  /// (`applied_seek_sec` in the response) — the cubit uses this as the
  /// new `_playlistOffsetSec` so the scrubber displays source-time
  /// rather than playlist-time after the restart (streaming pipeline
  /// plan §16 scrubber-offset patch).
  ///
  /// The playlist URL is unchanged but its *contents* are rewritten
  /// with new segment numbering + a discontinuity marker — the caller
  /// is responsible for re-opening the playlist on the player so
  /// libmpv flushes its cached VOD playlist.  Pass [tonemap] = whatever
  /// the session is currently streaming with so the seek doesn't
  /// silently revert HDR→SDR.
  Future<double> seekStream(
    String sessionId,
    double seekSec, {
    bool tonemap = false,
  });

  /// `POST /api/v1/stream/{session_id}/fallback-transcode` (plan 20) —
  /// tells the server that the client just failed to decode the current
  /// stream-copy session and asks it to flip the same session into
  /// transcode mode from [currentPositionSec] onwards.  The playlist URL
  /// is unchanged on success; the caller is expected to re-open it so
  /// libmpv re-fetches the rewritten segments.
  ///
  /// Returns when the server has acknowledged the switch (200) — no
  /// payload of interest to the caller.  Bubbles errors so the caller
  /// can decide whether to surface them (the cubit treats this as
  /// best-effort and logs without crashing the player).
  Future<void> reportFallbackTranscode({
    required String sessionId,
    required double currentPositionSec,
  });
}
