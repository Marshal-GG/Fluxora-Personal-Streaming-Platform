import 'package:fluxora_desktop/features/logs/domain/log_record.dart';

abstract class LogsRepository {
  /// Fetch the last 1000 structured log records from the server.
  Future<List<LogRecord>> getLogs();
}
