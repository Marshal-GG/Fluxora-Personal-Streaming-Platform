import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_state.dart';
import 'package:logger/logger.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required SecureStorage secureStorage,
    required ApiClient apiClient,
  })  : _secureStorage = secureStorage,
        _apiClient = apiClient,
        super(const SettingsInitial());

  final SecureStorage _secureStorage;
  final ApiClient _apiClient;
  static final _log = Logger();

  static const String _defaultUrl = 'http://localhost:8080';

  Future<void> loadSettings() async {
    emit(const SettingsLoading());
    try {
      final savedUrl = await _secureStorage.getServerUrl() ?? _defaultUrl;

      // Fetch server-side settings (tier, name, etc.) — best-effort, non-fatal.
      String serverName = 'Fluxora Server';
      String tier = 'free';
      int maxStreams = 1;
      String? licenseKey;

      try {
        final data = await _apiClient.get<Map<String, dynamic>>(
          Endpoints.serverSettings,
          fromJson: (json) => json as Map<String, dynamic>,
        );
        serverName = data['server_name'] as String? ?? serverName;
        tier = data['subscription_tier'] as String? ?? tier;
        maxStreams = data['max_concurrent_streams'] as int? ?? maxStreams;
        licenseKey = data['license_key'] as String?;
      } catch (e) {
        _log.w('Could not fetch server settings (server may be offline): $e');
      }

      emit(SettingsLoaded(
        serverUrl: savedUrl,
        serverName: serverName,
        tier: tier,
        maxConcurrentStreams: maxStreams,
        licenseKey: licenseKey,
      ));
    } catch (e, st) {
      _log.e('Failed to load settings', error: e, stackTrace: st);
      emit(const SettingsLoaded(
        serverUrl: _defaultUrl,
        serverName: 'Fluxora Server',
        tier: 'free',
        maxConcurrentStreams: 1,
      ));
    }
  }

  Future<void> saveSettings({
    required String serverUrl,
    required String serverName,
    required String tier,
    String? licenseKey,
  }) async {
    final trimmedUrl = serverUrl.trim();
    final trimmedName = serverName.trim();

    if (trimmedUrl.isEmpty) {
      emit(const SettingsError(message: 'Server URL cannot be empty.'));
      return;
    }
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      emit(const SettingsError(
        message: 'Invalid URL. Example: http://192.168.1.10:8080',
      ));
      return;
    }
    if (trimmedName.isEmpty) {
      emit(const SettingsError(message: 'Server name cannot be empty.'));
      return;
    }

    try {
      // Persist server URL locally.
      await _secureStorage.saveServerUrl(trimmedUrl);
      _apiClient.configure(baseUrl: trimmedUrl);

      // Push server-side settings to the API.
      await _apiClient.patch<void>(
        Endpoints.serverSettings,
        body: {
          'server_name': trimmedName,
          'tier': tier,
          if (licenseKey != null && licenseKey.trim().isNotEmpty)
            'license_key': licenseKey.trim(),
        },
      );

      emit(SettingsSaved(
        serverUrl: trimmedUrl,
        serverName: trimmedName,
        tier: tier,
      ));
    } catch (e, st) {
      _log.e('Failed to save settings', error: e, stackTrace: st);
      emit(SettingsError(message: 'Save failed: $e'));
    }
  }
}
