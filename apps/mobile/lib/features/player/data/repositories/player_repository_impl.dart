import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_mobile/features/player/domain/entities/stream_start_response.dart';
import 'package:fluxora_mobile/features/player/domain/repositories/player_repository.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  const PlayerRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<StreamStartResponse> startStream(String fileId) =>
      _apiClient.post<StreamStartResponse>(
        Endpoints.streamStart(fileId),
        fromJson: (data) =>
            StreamStartResponse.fromJson(data as Map<String, dynamic>),
      );

  @override
  Future<void> stopStream(String sessionId) =>
      _apiClient.delete(Endpoints.streamSession(sessionId));

  @override
  Future<void> updateProgress(String sessionId, double progressSec) =>
      _apiClient.patch<void>(
        Endpoints.streamProgress(sessionId),
        body: {'progress_sec': progressSec},
      );
}
