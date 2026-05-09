import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_candidate.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_job.dart';
import 'package:fluxora_desktop/features/transcode/domain/repositories/transcode_repository.dart';

/// Concrete impl over [ApiClient] — paths live here rather than in
/// `packages/fluxora_core/lib/network/endpoints.dart` because the Library
/// Transcode feature is desktop-only and the core endpoints file ships
/// to mobile + control-panel + tests; keeping the surface area minimal
/// avoids dragging the contract through three apps for a one-app feature.
class TranscodeRepositoryImpl implements TranscodeRepository {
  TranscodeRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  // ── Path constants — mirror the spec in
  //    docs/10_planning/18_library_transcode_plan.md §4.2.
  static const String _base = '/api/v1/transcode';
  static const String _candidates = '$_base/candidates';
  static const String _queue = '$_base/queue';
  static const String _jobs = '$_base/jobs';
  static String _job(int id) => '$_base/jobs/$id';
  static String _jobRetry(int id) => '$_base/jobs/$id/retry';

  @override
  Future<List<TranscodeCandidate>> getCandidates() =>
      _apiClient.get<List<TranscodeCandidate>>(
        _candidates,
        fromJson: (data) => (data as List<dynamic>)
            .map((e) =>
                TranscodeCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  Future<List<int>> queueJobs({
    required List<String> fileIds,
    String? encoder,
  }) {
    final body = <String, dynamic>{'file_ids': fileIds};
    if (encoder != null) body['encoder'] = encoder;
    return _apiClient.post<List<int>>(
      _queue,
      data: body,
      fromJson: (data) {
        final raw = (data as Map<String, dynamic>)['job_ids'] as List<dynamic>;
        return raw.map((e) => (e as num).toInt()).toList();
      },
    );
  }

  @override
  Future<List<TranscodeJob>> getJobs({
    List<TranscodeJobStatus>? statuses,
  }) {
    Map<String, dynamic>? query;
    if (statuses != null && statuses.isNotEmpty) {
      // The server accepts a comma-separated `?status=` list — match the
      // contract verbatim instead of relying on Dio's repeat-key behaviour
      // which would emit `?status=foo&status=bar`.
      query = {'status': statuses.map((s) => s.name).join(',')};
    }
    return _apiClient.get<List<TranscodeJob>>(
      _jobs,
      queryParameters: query,
      fromJson: (data) => (data as List<dynamic>)
          .map((e) => TranscodeJob.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<void> cancelJob(int jobId) => _apiClient.delete(_job(jobId));

  @override
  Future<int> retryJob(int jobId) => _apiClient.post<int>(
        _jobRetry(jobId),
        fromJson: (data) =>
            ((data as Map<String, dynamic>)['new_job_id'] as num).toInt(),
      );
}
