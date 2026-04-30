abstract class LogsRepository {
  /// Fetch the last 1000 lines of server logs.
  Future<String> getLogs();
}
