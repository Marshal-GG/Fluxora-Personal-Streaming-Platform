/// Local model for a structured server log record.
///
/// Parsed from the `GET /api/v1/logs?limit=1000` JSON response.
/// Kept inside the logs feature rather than fluxora_core because it is
/// desktop-only and does not need to be shared with mobile.
class LogRecord {
  const LogRecord({
    required this.ts,
    required this.level,
    required this.source,
    required this.message,
  });

  /// ISO-8601 timestamp string, e.g. `"2024-11-01T12:34:56.789Z"`.
  final String ts;

  /// Normalised level: `"INFO"`, `"WARN"`, `"ERROR"`, `"DEBUG"`.
  final String level;

  /// Source / logger name, e.g. `"fluxora.stream"`.
  final String source;

  /// Human-readable log message.
  final String message;

  factory LogRecord.fromJson(Map<String, dynamic> json) {
    final rawLevel = (json['level'] as String? ?? '').toUpperCase();
    // Normalise "WARNING" → "WARN" so the UI level map stays simple.
    final level = rawLevel == 'WARNING' ? 'WARN' : rawLevel;
    return LogRecord(
      ts: json['ts'] as String? ?? '',
      level: level,
      source: json['source'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  /// Returns just the `HH:mm:ss` portion of [ts] for compact display.
  String get shortTime {
    if (ts.length >= 19) return ts.substring(11, 19);
    return ts;
  }
}
