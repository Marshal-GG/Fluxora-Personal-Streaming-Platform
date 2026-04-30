import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/logs/domain/repositories/logs_repository.dart';

class LogsRepositoryImpl implements LogsRepository {
  LogsRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<String> getLogs() => _apiClient.get(
        Endpoints.logs,
        fromJson: (json) => json['logs'] as String,
      );
}
