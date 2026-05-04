import 'package:fluxora_core/entities/encoder_advice.dart';
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
}
