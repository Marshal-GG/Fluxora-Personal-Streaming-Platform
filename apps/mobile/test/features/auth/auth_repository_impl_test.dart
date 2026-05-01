import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/server_info.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/auth/data/repositories/auth_repository_impl.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late _MockApiClient mockApiClient;
  late _MockSecureStorage mockStorage;
  late AuthRepositoryImpl repo;

  const serverUrl = 'http://192.168.1.10:8080';
  const authToken = 'tok-abc123';
  const clientId = 'client-xyz';
  const remoteUrl = 'https://fluxora-api.example.dev';

  setUpAll(() {
    registerFallbackValue(
      const ServerInfo(
        serverName: 'fallback',
        version: '0.0.0',
        tier: SubscriptionTier.free,
      ),
    );
  });

  setUp(() {
    mockApiClient = _MockApiClient();
    mockStorage = _MockSecureStorage();
    repo = AuthRepositoryImpl(
      apiClient: mockApiClient,
      secureStorage: mockStorage,
    );

    when(() => mockApiClient.configure(
          localBaseUrl: any(named: 'localBaseUrl'),
          remoteBaseUrl: any(named: 'remoteBaseUrl'),
          bearerToken: any(named: 'bearerToken'),
        )).thenAnswer((_) {});
    when(() => mockStorage.savePairing(
          authToken: any(named: 'authToken'),
          serverUrl: any(named: 'serverUrl'),
          clientId: any(named: 'clientId'),
          remoteUrl: any(named: 'remoteUrl'),
        )).thenAnswer((_) async {});
  });

  group('AuthRepositoryImpl.saveCredentials', () {
    test('fetches /info, persists remote_url, configures dual-base', () async {
      when(() => mockApiClient.get<ServerInfo>(
            Endpoints.info,
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => const ServerInfo(
            serverName: 'My Server',
            version: '0.1.0',
            tier: SubscriptionTier.free,
            remoteUrl: remoteUrl,
          ));

      await repo.saveCredentials(
        serverUrl: serverUrl,
        authToken: authToken,
        clientId: clientId,
      );

      verify(() => mockApiClient.configure(
            localBaseUrl: serverUrl,
            bearerToken: authToken,
          )).called(1);
      verify(() => mockApiClient.get<ServerInfo>(
            Endpoints.info,
            fromJson: any(named: 'fromJson'),
          )).called(1);
      verify(() => mockStorage.savePairing(
            authToken: authToken,
            serverUrl: serverUrl,
            clientId: clientId,
            remoteUrl: remoteUrl,
          )).called(1);
      verify(() => mockApiClient.configure(remoteBaseUrl: remoteUrl)).called(1);
    });

    test('persists null remote_url when /info returns no remote', () async {
      when(() => mockApiClient.get<ServerInfo>(
            Endpoints.info,
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => const ServerInfo(
            serverName: 'My Server',
            version: '0.1.0',
            tier: SubscriptionTier.free,
            // remoteUrl omitted — server has no public URL configured
          ));

      await repo.saveCredentials(
        serverUrl: serverUrl,
        authToken: authToken,
        clientId: clientId,
      );

      verify(() => mockStorage.savePairing(
            authToken: authToken,
            serverUrl: serverUrl,
            clientId: clientId,
            remoteUrl: null,
          )).called(1);
      verifyNever(() =>
          mockApiClient.configure(remoteBaseUrl: any(named: 'remoteBaseUrl')));
    });

    test('falls back gracefully when /info call fails', () async {
      when(() => mockApiClient.get<ServerInfo>(
            Endpoints.info,
            fromJson: any(named: 'fromJson'),
          )).thenThrow(Exception('network error'));

      await repo.saveCredentials(
        serverUrl: serverUrl,
        authToken: authToken,
        clientId: clientId,
      );

      verify(() => mockStorage.savePairing(
            authToken: authToken,
            serverUrl: serverUrl,
            clientId: clientId,
            remoteUrl: null,
          )).called(1);
      verifyNever(() =>
          mockApiClient.configure(remoteBaseUrl: any(named: 'remoteBaseUrl')));
    });
  });
}
