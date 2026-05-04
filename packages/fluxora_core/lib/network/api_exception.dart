import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;

  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'Connection timed out. Check your network.',
          errorCode: 'TIMEOUT',
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final body = e.response?.data;
        // FastAPI uses `detail` for HTTPException + RequestValidationError;
        // Fluxora's older handlers used `error`.  Prefer `error` when the
        // server has the field; fall back to `detail`.  When `detail` is a
        // Pydantic-style list of validation entries, render each as
        // `<field>: <msg>` so the UI can surface the actual rejection
        // instead of a generic "Server error".
        String? extractMessage(dynamic body) {
          if (body is! Map) return null;
          final err = body['error'];
          if (err is String) return err;
          final detail = body['detail'];
          if (detail is String) return detail;
          if (detail is List) {
            return detail
                .whereType<Map>()
                .map((entry) {
                  final loc = entry['loc'];
                  final msg = entry['msg'] ?? entry['message'];
                  if (loc is List && loc.isNotEmpty && msg != null) {
                    final field = loc
                        .where((p) => p != 'body')
                        .map((p) => p.toString())
                        .join('.');
                    return field.isEmpty ? '$msg' : '$field: $msg';
                  }
                  return msg?.toString() ?? entry.toString();
                })
                .join('; ');
          }
          return null;
        }

        final message = extractMessage(body) ?? 'Server error';
        final errorCode =
            body is Map ? body['code'] as String? : null;
        return ApiException(
          message: message,
          statusCode: statusCode,
          errorCode: errorCode,
        );
      case DioExceptionType.cancel:
        return const ApiException(
          message: 'Request cancelled.',
          errorCode: 'CANCELLED',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'Cannot reach server. Check your connection.',
          errorCode: 'CONNECTION_ERROR',
        );
      default:
        return ApiException(
          message: e.message ?? 'An unexpected error occurred.',
          errorCode: 'UNKNOWN',
        );
    }
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isTierLimit => statusCode == 429;

  @override
  String toString() => 'ApiException($errorCode, $statusCode): $message';
}

/// Thrown when [ApiClient] needs to send a request from off-LAN but no
/// remote URL has been configured for the paired server.
///
/// Surfaces as a recoverable error in the UI: typically prompts the user
/// to reconnect to the LAN where the server lives, or to set up remote
/// access on the server (Phase 1 of the public-routing plan).
class NoRemoteConfiguredException implements Exception {
  const NoRemoteConfiguredException();

  @override
  String toString() =>
      'NoRemoteConfiguredException: device is off-LAN and the paired '
      'server has no remote URL configured';
}
