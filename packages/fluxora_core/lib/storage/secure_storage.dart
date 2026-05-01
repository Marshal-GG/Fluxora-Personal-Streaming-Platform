import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class SecureStorage {
  const SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _keyAuthToken = 'auth_token';
  static const String _keyServerUrl = 'server_url';
  static const String _keyRemoteUrl = 'remote_url';
  static const String _keyClientId = 'client_id';

  static final _log = Logger();

  Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: _keyAuthToken, value: token);
    } catch (e, st) {
      _log.e('Failed to save auth token', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: _keyAuthToken);
    } catch (e, st) {
      _log.e('Failed to read auth token', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteAuthToken() async {
    try {
      await _storage.delete(key: _keyAuthToken);
    } catch (e, st) {
      _log.e('Failed to delete auth token', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> saveServerUrl(String url) async {
    try {
      await _storage.write(key: _keyServerUrl, value: url);
    } catch (e, st) {
      _log.e('Failed to save server URL', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<String?> getServerUrl() async {
    try {
      return await _storage.read(key: _keyServerUrl);
    } catch (e, st) {
      _log.e('Failed to read server URL', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> saveRemoteUrl(String url) async {
    try {
      await _storage.write(key: _keyRemoteUrl, value: url);
    } catch (e, st) {
      _log.e('Failed to save remote URL', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<String?> getRemoteUrl() async {
    try {
      return await _storage.read(key: _keyRemoteUrl);
    } catch (e, st) {
      _log.e('Failed to read remote URL', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteRemoteUrl() async {
    try {
      await _storage.delete(key: _keyRemoteUrl);
    } catch (e, st) {
      _log.e('Failed to delete remote URL', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Persists the full pairing payload in one call. Pass `null` for
  /// [remoteUrl] to clear any previously stored remote URL (e.g. when
  /// the server has disabled remote access).
  Future<void> savePairing({
    required String authToken,
    required String serverUrl,
    required String clientId,
    String? remoteUrl,
  }) async {
    await saveAuthToken(authToken);
    await saveServerUrl(serverUrl);
    await saveClientId(clientId);
    if (remoteUrl != null) {
      await saveRemoteUrl(remoteUrl);
    } else {
      await deleteRemoteUrl();
    }
  }

  Future<void> saveClientId(String clientId) async {
    try {
      await _storage.write(key: _keyClientId, value: clientId);
    } catch (e, st) {
      _log.e('Failed to save client ID', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<String?> getClientId() async {
    try {
      return await _storage.read(key: _keyClientId);
    } catch (e, st) {
      _log.e('Failed to read client ID', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e, st) {
      _log.e('Failed to clear secure storage', error: e, stackTrace: st);
      rethrow;
    }
  }
}
