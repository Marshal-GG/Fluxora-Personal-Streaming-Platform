import 'package:fluxora_core/entities/activity_event.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/recent_activity/domain/repositories/recent_activity_repository.dart';

class RecentActivityRepositoryImpl implements RecentActivityRepository {
  RecentActivityRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<ActivityEvent>> fetch({int limit = 4}) => _apiClient.get(
        '${Endpoints.activity}?limit=$limit',
        fromJson: (json) => (json as List<dynamic>)
            .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
