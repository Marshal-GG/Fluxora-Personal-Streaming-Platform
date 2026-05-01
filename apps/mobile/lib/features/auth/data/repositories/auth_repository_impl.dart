import 'package:logger/logger.dart';
import 'package:fluxora_core/entities/server_info.dart';
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
    // Configure the ApiClient first so the /info call below is sent to the
    // freshly paired server. /info is public so the bearer token is not
    // strictly required, but we set it anyway so downstream calls work.
    _apiClient.configure(localBaseUrl: serverUrl, bearerToken: authToken);

    // Discover the server's remote URL (Cloudflare Tunnel) so off-LAN
    // requests can fall back to it. Failure is non-fatal — paired clients
    // without a remote URL just keep using LAN-direct.
    final remoteUrl = await _fetchRemoteUrl();

    await _secureStorage.savePairing(
      authToken: authToken,
      serverUrl: serverUrl,
      clientId: clientId,
      remoteUrl: remoteUrl,
    );

    if (remoteUrl != null) {
      _apiClient.configure(remoteBaseUrl: remoteUrl);
    }

    _log.i(
      'Credentials saved for client $clientId '
      '(remote_url=${remoteUrl ?? "<none>"})',
    );
  }

  Future<String?> _fetchRemoteUrl() async {
    try {
      final info = await _apiClient.get<ServerInfo>(
        Endpoints.info,
        fromJson: (data) => ServerInfo.fromJson(data as Map<String, dynamic>),
      );
      return info.remoteUrl;
    } catch (e, st) {
      _log.w(
        'Failed to fetch /info for remote_url — proceeding without remote URL',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
