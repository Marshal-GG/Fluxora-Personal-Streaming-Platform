import 'package:fluxora_core/entities/system_stats.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/system_stats/domain/repositories/system_stats_repository.dart';

class SystemStatsRepositoryImpl implements SystemStatsRepository {
  SystemStatsRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<SystemStats> fetch() => _apiClient.get(
        Endpoints.infoStats,
        fromJson: (json) => SystemStats.fromJson(json as Map<String, dynamic>),
      );
}
