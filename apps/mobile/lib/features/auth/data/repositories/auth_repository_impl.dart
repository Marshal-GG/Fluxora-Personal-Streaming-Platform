import 'package:logger/logger.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required ApiClient apiClient,
    required SecureStorage secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  static final _log = Logger();

  @override
  Future<void> requestPair({
    required String clientId,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async {
    _log.i('Requesting pair: $deviceName ($platform)');
    await _apiClient.post<dynamic>(
      Endpoints.requestPair,
      data: {
        'client_id': clientId,
        'device_name': deviceName,
        'platform': platform,
        'app_version': appVersion,
      },
    );
  }

  @override
  Future<String?> pollStatus(String clientId) async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      Endpoints.authStatus(clientId),
      fromJson: (d) => d as Map<String, dynamic>,
    );
    final status = data['status'] as String?;
    if (status == 'approved') return data['auth_token'] as String?;
    if (status == 'rejected') throw const PairRejectedException();
    return null;
  }

  @override
  Future<void> saveCredentials({
    required String serverUrl,
    required String authToken,
    required String clientId,
  }) async {
    await _secureStorage.saveServerUrl(serverUrl);
    await _secureStorage.saveAuthToken(authToken);
    await _secureStorage.saveClientId(clientId);
    _apiClient.configure(localBaseUrl: serverUrl, bearerToken: authToken);
    _log.i('Credentials saved for client $clientId');
  }
}
