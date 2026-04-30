import 'package:fluxora_core/entities/stream_session.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_desktop/features/activity/domain/repositories/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<StreamSession>> getActiveSessions() async {
    return _apiClient.get(
      '/api/v1/stream/sessions',
      fromJson: (json) => (json as List<dynamic>)
          .map((e) => StreamSession.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<void> stopSession(String sessionId) async {
    await _apiClient.delete('/api/v1/stream/$sessionId');
  }
}
