import 'package:fluxora_core/entities/encoder_advice.dart';
import 'package:fluxora_core/entities/encoder_benchmark.dart';
import 'package:fluxora_core/entities/fallback_event.dart';
import 'package:fluxora_core/entities/hardware_devices.dart';
import 'package:fluxora_core/entities/transcoding_status.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/transcoding/domain/repositories/transcoding_repository.dart';

class TranscodingRepositoryImpl implements TranscodingRepository {
  TranscodingRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<TranscodingStatus> status() => _apiClient.get(
        Endpoints.transcodingStatus,
        fromJson: (json) =>
            TranscodingStatus.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<EncoderAdvice> advisor() => _apiClient.get(
        Endpoints.transcodingAdvisor,
        fromJson: (json) =>
            EncoderAdvice.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<HardwareDevices> devices() => _apiClient.get(
        Endpoints.transcodingDevices,
        fromJson: (json) =>
            HardwareDevices.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<FallbackHistory> fallbackHistory() => _apiClient.get(
        Endpoints.transcodingFallbackHistory,
        fromJson: (json) =>
            FallbackHistory.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<EncoderBenchmarkRun> benchmark({
    int? durationSec,
    int? fps,
    List<Resolution>? resolutions,
  }) {
    final body = <String, dynamic>{
      // Always-on cap verification — the concurrent chip would otherwise
      // lie on patched / driver-530+ / RTX-40 setups (NVIDIA's documented
      // 3-session cap doesn't apply there).
      'verify_caps': true,
    };
    if (durationSec != null) body['duration_sec'] = durationSec;
    if (fps != null) body['fps'] = fps;
    if (resolutions != null && resolutions.isNotEmpty) {
      body['resolutions'] = resolutions
          .map((r) => {'width': r.width, 'height': r.height})
          .toList();
    }
    // Wall-clock budget scales with len(encoders) × len(resolutions).  The
    // baseline single-resolution case takes ~60–90 s; a 3-resolution matrix
    // can run ~3× that.  9-min ceiling absorbs 4K + 60 fps + cap probe on
    // a slow CPU.  Higher than that and the operator should raise it on
    // their end — server itself caps each encoder at 35 s anyway.
    final timeout = (resolutions != null && resolutions.length > 1)
        ? const Duration(minutes: 12)
        : const Duration(minutes: 6);
    return _apiClient.post(
      Endpoints.transcodingBenchmark,
      data: body,
      receiveTimeout: timeout,
      fromJson: (json) =>
          EncoderBenchmarkRun.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<BenchmarkProgress> benchmarkProgress() => _apiClient.get(
        Endpoints.transcodingBenchmarkProgress,
        fromJson: (json) =>
            BenchmarkProgress.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<BenchmarkHistory> benchmarkHistory({int limit = 20}) =>
      _apiClient.get(
        Endpoints.transcodingBenchmarkHistory,
        queryParameters: {'limit': limit},
        fromJson: (json) =>
            BenchmarkHistory.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<EncoderBenchmarkRun> benchmarkHistoryEntry(int id) => _apiClient.get(
        Endpoints.transcodingBenchmarkHistoryEntry(id),
        fromJson: (json) =>
            EncoderBenchmarkRun.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<void> deleteBenchmarkHistoryEntry(int id) =>
      _apiClient.delete(Endpoints.transcodingBenchmarkHistoryEntry(id));
}
