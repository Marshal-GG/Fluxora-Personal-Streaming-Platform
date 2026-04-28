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
