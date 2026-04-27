import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_core/network/api_exception.dart';

class ApiClient {
  ApiClient({required String baseUrl, String? bearerToken}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    _bearerToken = bearerToken;
    _setupInterceptors();
  }

  late final Dio _dio;
  String? _bearerToken;

  static final _log = Logger();

  /// Updates the base URL and auth token — called after server pairing.
  void configure({required String baseUrl, String? bearerToken}) {
    _dio.options.baseUrl = baseUrl;
    _bearerToken = bearerToken;
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (_bearerToken != null) {
              options.headers['Authorization'] = 'Bearer $_bearerToken';
            }
            handler.next(options);
          },
          onError: (error, handler) {
            _log.e(
              'HTTP ${error.response?.statusCode} — ${error.requestOptions.path}',
              error: error,
              stackTrace: error.stackTrace,
            );
            handler.next(error);
          },
        ),
      );
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      if (fromJson != null) return fromJson(response.data);
      return response.data as T;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post<dynamic>(path, data: data);
      if (fromJson != null) return fromJson(response.data);
      return response.data as T;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put<dynamic>(path, data: data);
      if (fromJson != null) return fromJson(response.data);
      return response.data as T;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete<dynamic>(path);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
