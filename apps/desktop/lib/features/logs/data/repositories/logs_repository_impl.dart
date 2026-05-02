import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/logs/domain/repositories/logs_repository.dart';

class LogsRepositoryImpl implements LogsRepository {
  LogsRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<String> getLogs() => _apiClient.get(
        Endpoints.logs,
        queryParameters: const {'limit': 1000},
        fromJson: (json) {
          final items = (json['items'] as List).cast<Map<String, dynamic>>();
          // Most-recent-last so the screen's reverse:true scroll keeps
          // the newest entry at the bottom.
          return items.reversed.map((rec) {
            final ts = rec['ts'] ?? '';
            final level = (rec['level'] ?? '').toString().toUpperCase();
            final source = rec['source'] ?? '';
            final message = rec['message'] ?? '';
            return '$ts [$level] $source: $message';
          }).join('\n');
        },
      );
}
