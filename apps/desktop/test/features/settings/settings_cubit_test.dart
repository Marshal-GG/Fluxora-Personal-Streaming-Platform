import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_state.dart';

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockSecureStorage mockStorage;
  late _MockApiClient mockApiClient;

  const kDefaultUrl = 'http://localhost:8080';
  const kSavedUrl = 'http://192.168.1.10:8080';

  setUp(() {
    mockStorage = _MockSecureStorage();
    mockApiClient = _MockApiClient();
  });

  SettingsCubit buildCubit() => SettingsCubit(
        secureStorage: mockStorage,
        apiClient: mockApiClient,
      );

  // ── Shared stubs ────────────────────────────────────────────────────────────

  void stubStorageEmpty() =>
      when(() => mockStorage.getServerUrl()).thenAnswer((_) async => null);

  void stubStorageUrl(String url) =>
      when(() => mockStorage.getServerUrl()).thenAnswer((_) async => url);

  void stubStorageSaveUrl() =>
      when(() => mockStorage.saveServerUrl(any())).thenAnswer((_) async {});

  void stubApiGetOffline() =>
      when(() => mockApiClient.get<Map<String, dynamic>>(
            any(),
            fromJson: any(named: 'fromJson'),
          )).thenThrow(const ApiException(
        message: 'Cannot reach server.',
        errorCode: 'CONNECTION_ERROR',
      ));

  void stubApiGetSettings(Map<String, dynamic> data) =>
      when(() => mockApiClient.get<Map<String, dynamic>>(
            any(),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => data);

  void stubApiConfigure() =>
      when(() =>
              mockApiClient.configure(localBaseUrl: any(named: 'localBaseUrl')))
          .thenAnswer((_) {});

  void stubApiPatchSuccess() =>
      when(() => mockApiClient.patch<void>(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async {});

  void stubApiPatchThrows() =>
      when(() => mockApiClient.patch<void>(
            any(),
            body: any(named: 'body'),
          )).thenThrow(
        const ApiException(message: 'Server error', statusCode: 500),
      );

  // ── loadSettings ────────────────────────────────────────────────────────────

  group('SettingsCubit.loadSettings', () {
    test('initial state is SettingsInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<SettingsInitial>());
      cubit.close();
    });

    blocTest<SettingsCubit, SettingsState>(
      'emits [Loading, Loaded] with all defaults when storage is empty and server offline',
      build: () {
        stubStorageEmpty();
        stubApiGetOffline();
        return buildCubit();
      },
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<SettingsLoading>(),
        isA<SettingsLoaded>()
            .having((s) => s.serverUrl, 'serverUrl', kDefaultUrl)
            .having((s) => s.serverName, 'serverName', 'Fluxora Server')
            .having((s) => s.tier, 'tier', 'free')
            .having((s) => s.maxConcurrentStreams, 'maxConcurrentStreams', 1)
            .having((s) => s.licenseKey, 'licenseKey', isNull),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'uses saved URL from SecureStorage when present',
      build: () {
        stubStorageUrl(kSavedUrl);
        stubApiGetOffline();
        return buildCubit();
      },
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<SettingsLoading>(),
        isA<SettingsLoaded>()
            .having((s) => s.serverUrl, 'serverUrl', kSavedUrl),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'merges server-side settings when API call succeeds',
      build: () {
        stubStorageEmpty();
        stubApiGetSettings({
          'server_name': 'Home Media Server',
          'subscription_tier': 'plus',
          'max_concurrent_streams': 3,
          'license_key': 'FLUXORA-TEST-KEY',
        });
        return buildCubit();
      },
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<SettingsLoading>(),
        isA<SettingsLoaded>()
            .having((s) => s.serverName, 'serverName', 'Home Media Server')
            .having((s) => s.tier, 'tier', 'plus')
            .having((s) => s.maxConcurrentStreams, 'maxConcurrentStreams', 3)
            .having((s) => s.licenseKey, 'licenseKey', 'FLUXORA-TEST-KEY'),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'uses saved URL alongside server settings',
      build: () {
        stubStorageUrl(kSavedUrl);
        stubApiGetSettings({
          'server_name': 'My Server',
          'subscription_tier': 'pro',
          'max_concurrent_streams': 10,
          'license_key': null,
        });
        return buildCubit();
      },
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<SettingsLoading>(),
        isA<SettingsLoaded>()
            .having((s) => s.serverUrl, 'serverUrl', kSavedUrl)
            .having((s) => s.tier, 'tier', 'pro'),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'emits Loaded with all defaults when getServerUrl throws',
      build: () {
        when(() => mockStorage.getServerUrl())
            .thenThrow(Exception('keychain error'));
        return buildCubit();
      },
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<SettingsLoading>(),
        isA<SettingsLoaded>()
            .having((s) => s.serverUrl, 'serverUrl', kDefaultUrl)
            .having((s) => s.tier, 'tier', 'free')
            .having((s) => s.maxConcurrentStreams, 'maxConcurrentStreams', 1),
      ],
    );
  });

  // ── saveSettings ────────────────────────────────────────────────────────────

  group('SettingsCubit.saveSettings', () {
    blocTest<SettingsCubit, SettingsState>(
      'emits SettingsError when URL is blank',
      build: buildCubit,
      act: (cubit) => cubit.saveSettings(
        serverUrl: '   ',
        serverName: 'Test',
        tier: 'free',
      ),
      expect: () => [
        isA<SettingsError>().having(
          (s) => s.message,
          'message',
          'Server URL cannot be empty.',
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'emits SettingsError when URL has no HTTP scheme',
      build: buildCubit,
      act: (cubit) => cubit.saveSettings(
        serverUrl: '192.168.1.10:8080',
        serverName: 'Test',
        tier: 'free',
      ),
      expect: () => [isA<SettingsError>()],
    );

    blocTest<SettingsCubit, SettingsState>(
      'emits SettingsError when server name is blank',
      build: buildCubit,
      act: (cubit) => cubit.saveSettings(
        serverUrl: kSavedUrl,
        serverName: '   ',
        tier: 'free',
      ),
      expect: () => [
        isA<SettingsError>().having(
          (s) => s.message,
          'message',
          'Server name cannot be empty.',
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'emits SettingsSaved with trimmed values when all inputs are valid',
      build: () {
        stubStorageSaveUrl();
        stubApiConfigure();
        stubApiPatchSuccess();
        return buildCubit();
      },
      act: (cubit) => cubit.saveSettings(
        serverUrl: '  $kSavedUrl  ',
        serverName: '  My Server  ',
        tier: 'plus',
      ),
      expect: () => [
        isA<SettingsSaved>()
            .having((s) => s.serverUrl, 'serverUrl', kSavedUrl)
            .having((s) => s.serverName, 'serverName', 'My Server')
            .having((s) => s.tier, 'tier', 'plus'),
      ],
      verify: (_) {
        verify(() => mockStorage.saveServerUrl(kSavedUrl)).called(1);
        verify(() => mockApiClient.configure(localBaseUrl: kSavedUrl))
            .called(1);
        verify(() => mockApiClient.patch<void>(
              any(),
              body: any(named: 'body'),
            )).called(1);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'emits SettingsError when API patch throws',
      build: () {
        stubStorageSaveUrl();
        stubApiConfigure();
        stubApiPatchThrows();
        return buildCubit();
      },
      act: (cubit) => cubit.saveSettings(
        serverUrl: kSavedUrl,
        serverName: 'My Server',
        tier: 'free',
      ),
      expect: () => [
        isA<SettingsError>().having(
          (s) => s.message,
          'message',
          startsWith('Save failed:'),
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'includes license_key in PATCH body when provided',
      build: () {
        stubStorageSaveUrl();
        stubApiConfigure();
        stubApiPatchSuccess();
        return buildCubit();
      },
      act: (cubit) => cubit.saveSettings(
        serverUrl: kSavedUrl,
        serverName: 'My Server',
        tier: 'pro',
        licenseKey: 'FLUXORA-ABCD-1234-EFGH-5678',
      ),
      verify: (_) {
        verify(() => mockApiClient.patch<void>(
              any(),
              body: any(
                named: 'body',
                that: predicate<Map<String, dynamic>>(
                  (body) =>
                      body['license_key'] == 'FLUXORA-ABCD-1234-EFGH-5678',
                  'body contains license_key',
                ),
              ),
            )).called(1);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'omits license_key from PATCH body when null',
      build: () {
        stubStorageSaveUrl();
        stubApiConfigure();
        stubApiPatchSuccess();
        return buildCubit();
      },
      act: (cubit) => cubit.saveSettings(
        serverUrl: kSavedUrl,
        serverName: 'My Server',
        tier: 'free',
      ),
      verify: (_) {
        verify(() => mockApiClient.patch<void>(
              any(),
              body: any(
                named: 'body',
                that: predicate<Map<String, dynamic>>(
                  (body) => !body.containsKey('license_key'),
                  'body does not contain license_key',
                ),
              ),
            )).called(1);
      },
    );
  });
}
