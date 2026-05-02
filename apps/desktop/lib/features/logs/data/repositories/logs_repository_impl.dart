import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/logs/domain/log_record.dart';
import 'package:fluxora_desktop/features/logs/domain/repositories/logs_repository.dart';

class LogsRepositoryImpl implements LogsRepository {
  LogsRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<LogRecord>> getLogs() => _apiClient.get(
        Endpoints.logs,
        queryParameters: const {'limit': 1000},
        fromJson: (json) {
          final items = (json['items'] as List).cast<Map<String, dynamic>>();
          // Most-recent-last: the screen auto-scrolls to the bottom.
          return items.reversed
              .map(LogRecord.fromJson)
              .toList(growable: false);
        },
      );
}
