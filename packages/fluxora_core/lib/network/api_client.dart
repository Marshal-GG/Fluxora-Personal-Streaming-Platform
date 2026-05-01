import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logger/logger.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/network/network_path_detector.dart';

/// HTTP client with smart-path routing between a LAN base URL and an
/// internet-exposed remote base URL (Cloudflare Tunnel).
///
/// Resolution happens per-request via [LanCheck]. When the device is on
/// the same /24 as the server, [localBaseUrl] is used; otherwise
/// [remoteBaseUrl] is used. If the device is off-LAN and no
/// [remoteBaseUrl] is configured, the call throws
/// [NoRemoteConfiguredException].
///
/// See `docs/05_infrastructure/03_public_routing.md` Phase 3.
class ApiClient {
  /// Dual-base constructor.
  ApiClient({
    String? localBaseUrl,
    String? remoteBaseUrl,
    @Deprecated('Use localBaseUrl instead') String? baseUrl,
    String? bearerToken,
    LanCheck lanCheck = NetworkPathDetector.isLan,
  })  : _localBaseUrl = localBaseUrl ?? baseUrl,
        _remoteBaseUrl = remoteBaseUrl,
        _lanCheck = lanCheck {
    _dio = Dio(
      BaseOptions(
        // Seed with whichever base is available so Dio has a non-empty
        // baseUrl until the first request (interceptor will rewrite).
        baseUrl: (localBaseUrl ?? baseUrl ?? remoteBaseUrl ?? ''),
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
  String? _localBaseUrl;
  String? _remoteBaseUrl;
  LanCheck _lanCheck;

  static final _log = Logger();

  String? get localBaseUrl => _localBaseUrl;
  String? get remoteBaseUrl => _remoteBaseUrl;

  /// Updates base URLs and auth token — called after server pairing.
  ///
  /// Only the named arguments that are provided (non-null) are applied;
  /// the rest are preserved. To clear the bearer token use
  /// [clearBearerToken]; to clear the remote URL use [clearRemoteBaseUrl].
  ///
  /// Accepts the legacy single [baseUrl] argument as an alias for
  /// [localBaseUrl] so existing callers keep working until migrated.
  void configure({
    String? localBaseUrl,
    String? remoteBaseUrl,
    @Deprecated('Use localBaseUrl instead') String? baseUrl,
    String? bearerToken,
    LanCheck? lanCheck,
  }) {
    if (localBaseUrl != null || baseUrl != null) {
      _localBaseUrl = localBaseUrl ?? baseUrl;
    }
    if (remoteBaseUrl != null) {
      _remoteBaseUrl = remoteBaseUrl;
    }
    if (lanCheck != null) {
      _lanCheck = lanCheck;
    }
    if (bearerToken != null) {
      _bearerToken = bearerToken;
    }
    _dio.options.baseUrl =
        _localBaseUrl ?? _remoteBaseUrl ?? _dio.options.baseUrl;
    _setupInterceptors();
  }

  /// Clears the remote URL — used when the user unpairs or disables
  /// remote access on the server.
  void clearRemoteBaseUrl() {
    _remoteBaseUrl = null;
  }

  /// Clears the bearer token — used on logout / unpair.
  void clearBearerToken() {
    _bearerToken = null;
    _setupInterceptors();
  }

  /// Test-only access to the smart-path resolver.
  @visibleForTesting
  Future<String> resolveBaseUrlForTest() => _resolveBaseUrl();

  Future<String> _resolveBaseUrl() async {
    final local = _localBaseUrl;
    final remote = _remoteBaseUrl;

    if (local == null && remote == null) {
      throw const NoRemoteConfiguredException();
    }
    // No local URL — only path is the remote.
    if (local == null) return remote!;

    final isLan = await _lanCheck(local);
    if (isLan) return local;

    // Off-LAN — must have a remote URL configured.
    if (remote == null) {
      throw const NoRemoteConfiguredException();
    }
    return remote;
  }

  void _setupInterceptors() {
    _dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            try {
              options.baseUrl = await _resolveBaseUrl();
            } on NoRemoteConfiguredException catch (e) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.unknown,
                  error: e,
                ),
              );
            }
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

  /// If [e] wraps a [NoRemoteConfiguredException], rethrow that
  /// directly so callers can branch on it.
  Never _rethrow(DioException e) {
    final inner = e.error;
    if (inner is NoRemoteConfiguredException) {
      throw inner;
    }
    throw ApiException.fromDioException(e);
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
      _rethrow(e);
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
      _rethrow(e);
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
      _rethrow(e);
    }
  }

  Future<T> patch<T>(
    String path, {
    dynamic body,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(path, data: body);
      if (fromJson != null) return fromJson(response.data);
      return response.data as T;
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete<dynamic>(path);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }
}
