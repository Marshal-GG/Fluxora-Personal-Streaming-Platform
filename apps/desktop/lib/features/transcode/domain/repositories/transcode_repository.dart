import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_candidate.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_job.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_storage.dart';

/// Quality preset accepted by `POST /api/v1/transcode/queue?preset=…`.
///
/// Multipliers are the same numbers the server uses to estimate output
/// size — the Queue dialog reads them client-side so the operator sees
/// a live "Estimated total" without an extra round trip.
enum TranscodePreset {
  smaller(wireValue: 'smaller', multiplier: 1.2),
  recommended(wireValue: 'recommended', multiplier: 2.0),
  mastering(wireValue: 'mastering', multiplier: 4.0);

  const TranscodePreset({
    required this.wireValue,
    required this.multiplier,
  });

  /// On-the-wire string sent to the server in the `preset` field.
  final String wireValue;

  /// Multiplier of the source size used by the server to estimate the
  /// H.264 output size.  AV1 sources hit the multiplier directly; VP9
  /// sources are 0.7× (smaller transcoded targets), see
  /// [estimateOutputBytes].
  final double multiplier;
}

/// Estimate the H.264 output size for a single source file.
///
/// AV1 → multiplier × source.  VP9 → 0.7 × multiplier × source — VP9 is
/// already a smaller payload than AV1 at equivalent visual quality, so
/// the H.264 sidecar lands proportionally smaller.
int estimateOutputBytes({
  required int sourceBytes,
  required String sourceCodec,
  required TranscodePreset preset,
}) {
  final factor = sourceCodec.toLowerCase() == 'vp9'
      ? preset.multiplier * 0.7
      : preset.multiplier;
  return (sourceBytes * factor).round();
}

/// Contract for `/api/v1/transcode/...` — locked against the API spec in
/// `docs/10_planning/19_library_transcode_followups.md` (plan 19 §M1
/// adds `preset`; §M3 adds the `/storage` endpoint).  All endpoints are
/// bearer-authenticated; the desktop's [ApiClient] singleton attaches
/// the token.
abstract interface class TranscodeRepository {
  /// `GET /api/v1/transcode/candidates` — every AV1 / VP9 file that does
  /// not yet have a transcoded sidecar.  Newest-first ordering is the
  /// server's job; clients render verbatim.
  Future<List<TranscodeCandidate>> getCandidates();

  /// `POST /api/v1/transcode/queue` — enqueue one job per file id.
  ///
  /// [preset] picks the quality / size trade-off (smaller / recommended /
  /// mastering); when omitted the server defaults to `recommended`.
  /// [encoder] is rarely set; the server picks NVENC vs libx264 per its
  /// own capability probe.
  Future<List<int>> queueJobs({
    required List<String> fileIds,
    TranscodePreset? preset,
    String? encoder,
  });

  /// `GET /api/v1/transcode/jobs` — every job whose status is in the
  /// supplied list.  Pass null to get the server's default set
  /// (typically `running,queued,done,failed,cancelled`).
  Future<List<TranscodeJob>> getJobs({List<TranscodeJobStatus>? statuses});

  /// `GET /api/v1/transcode/storage` — cache root + total size + free
  /// disk + per-codec breakdown.  Polled by the Transcode screen's
  /// `_StorageStrip` every 5 s while mounted.
  Future<TranscodeStorage> getStorage();

  /// `DELETE /api/v1/transcode/jobs/{id}` — cancels if running, removes
  /// from the queue if queued.  Server returns 204; we return void.
  Future<void> cancelJob(int jobId);

  /// `POST /api/v1/transcode/jobs/{id}/retry` — re-enqueues a failed or
  /// cancelled job, preserving the original row in History.  Returns
  /// the new job id.
  Future<int> retryJob(int jobId);
}
