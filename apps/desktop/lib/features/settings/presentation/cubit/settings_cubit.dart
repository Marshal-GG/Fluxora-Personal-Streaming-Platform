import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/network/api_client.dart';
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
      final saved = await _secureStorage.getServerUrl();
      emit(SettingsLoaded(serverUrl: saved ?? _defaultUrl));
    } catch (e, st) {
      _log.e('Failed to load settings', error: e, stackTrace: st);
      emit(const SettingsLoaded(serverUrl: _defaultUrl));
    }
  }

  Future<void> saveServerUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      emit(const SettingsError(message: 'Server URL cannot be empty.'));
      return;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      emit(const SettingsError(
        message: 'Invalid URL. Example: http://192.168.1.10:8080',
      ));
      return;
    }
    try {
      await _secureStorage.saveServerUrl(trimmed);
      _apiClient.configure(baseUrl: trimmed);
      emit(SettingsSaved(serverUrl: trimmed));
    } catch (e, st) {
      _log.e('Failed to save server URL', error: e, stackTrace: st);
      emit(SettingsError(message: 'Save failed: $e'));
    }
  }
}
