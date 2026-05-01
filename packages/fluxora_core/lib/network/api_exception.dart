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
        final message = body is Map
            ? (body['error'] as String? ?? 'Server error')
            : 'Server error';
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
