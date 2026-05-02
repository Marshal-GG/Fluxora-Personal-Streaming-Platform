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
}
