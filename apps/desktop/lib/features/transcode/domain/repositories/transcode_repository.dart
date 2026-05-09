import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_candidate.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_job.dart';

/// Contract for `/api/v1/transcode/...` — locked against the API spec in
/// `docs/10_planning/18_library_transcode_plan.md`.  All five endpoints
/// are bearer-authenticated; the desktop's [ApiClient] singleton already
/// attaches the token.
abstract interface class TranscodeRepository {
  /// `GET /api/v1/transcode/candidates` — every AV1 / VP9 file that does
  /// not yet have a transcoded sidecar.  Newest-first ordering is the
  /// server's job; clients render verbatim.
  Future<List<TranscodeCandidate>> getCandidates();

  /// `POST /api/v1/transcode/queue` — enqueue one job per file id, with
  /// the server picking encoder + preset.  `encoder` is optional; pass
  /// it only when the operator has a reason to override the default.
  Future<List<int>> queueJobs({
    required List<String> fileIds,
    String? encoder,
  });

  /// `GET /api/v1/transcode/jobs` — every job whose status is in the
  /// supplied list.  Pass null to get the server's default set
  /// (typically `running,queued,done,failed,cancelled`).
  Future<List<TranscodeJob>> getJobs({List<TranscodeJobStatus>? statuses});

  /// `DELETE /api/v1/transcode/jobs/{id}` — cancels if running, removes
  /// from the queue if queued.  Server returns 204; we return void.
  Future<void> cancelJob(int jobId);

  /// `POST /api/v1/transcode/jobs/{id}/retry` — re-enqueues a failed or
  /// cancelled job, preserving the original row in History.  Returns
  /// the new job id.
  Future<int> retryJob(int jobId);
}
