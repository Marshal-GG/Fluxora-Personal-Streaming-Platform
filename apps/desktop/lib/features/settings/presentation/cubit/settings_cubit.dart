import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/server_info.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/api_exception.dart';
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

  static const String _defaultUrl = 'http://localhost:8000';

  Future<void> loadSettings() async {
    emit(const SettingsLoading());
    try {
      final savedUrl = await _secureStorage.getServerUrl() ?? _defaultUrl;

      // Fetch server-side settings (tier, name, etc.) — best-effort, non-fatal.
      String serverName = 'Fluxora Server';
      String tier = 'free';
      int maxStreams = 1;
      String? licenseKey;
      String transcodingEncoder = 'libx264';
      String transcodingPreset = 'veryfast';
      int transcodingCrf = 23;
      List<String>? transcodingChain;
      String streamingMode = 'client-decode';

      // §7.10 extended-settings — defaults match `models/settings.py`
      // `UserSettingsResponse` so an offline load + a successful load show
      // the same values when nothing is configured server-side.
      String defaultLibraryView = 'grid';
      bool scanLibrariesOnStartup = true;
      bool generateThumbnails = true;
      String preferredMode = 'auto';
      bool enableMdns = true;
      bool enableWebrtc = true;
      String? relayServerUrl;
      String defaultQuality = 'auto';
      int aiSegmentDurationSeconds = 4;
      bool enablePairingRequired = true;
      int sessionTimeoutMinutes = 60;
      bool enableLogExport = true;
      String? customServerUrl;

      try {
        final data = await _apiClient.get<Map<String, dynamic>>(
          Endpoints.serverSettings,
          fromJson: (json) => json as Map<String, dynamic>,
        );
        serverName = data['server_name'] as String? ?? serverName;
        tier = data['subscription_tier'] as String? ?? tier;
        maxStreams = data['max_concurrent_streams'] as int? ?? maxStreams;
        licenseKey = data['license_key'] as String?;
        transcodingEncoder =
            data['transcoding_encoder'] as String? ?? transcodingEncoder;
        transcodingPreset =
            data['transcoding_preset'] as String? ?? transcodingPreset;
        transcodingCrf = data['transcoding_crf'] as int? ?? transcodingCrf;
        final rawChain = data['transcoding_chain'];
        if (rawChain is List) {
          transcodingChain = rawChain.whereType<String>().toList();
        }
        streamingMode = data['streaming_mode'] as String? ?? streamingMode;
        defaultLibraryView =
            data['default_library_view'] as String? ?? defaultLibraryView;
        scanLibrariesOnStartup =
            data['scan_libraries_on_startup'] as bool? ?? scanLibrariesOnStartup;
        generateThumbnails =
            data['generate_thumbnails'] as bool? ?? generateThumbnails;
        preferredMode = data['preferred_mode'] as String? ?? preferredMode;
        enableMdns = data['enable_mdns'] as bool? ?? enableMdns;
        enableWebrtc = data['enable_webrtc'] as bool? ?? enableWebrtc;
        relayServerUrl = data['relay_server_url'] as String?;
        defaultQuality = data['default_quality'] as String? ?? defaultQuality;
        aiSegmentDurationSeconds =
            data['ai_segment_duration_seconds'] as int? ??
                aiSegmentDurationSeconds;
        enablePairingRequired =
            data['enable_pairing_required'] as bool? ?? enablePairingRequired;
        sessionTimeoutMinutes =
            data['session_timeout_minutes'] as int? ?? sessionTimeoutMinutes;
        enableLogExport =
            data['enable_log_export'] as bool? ?? enableLogExport;
        customServerUrl = data['custom_server_url'] as String?;
      } catch (e) {
        _log.w('Could not fetch server settings (server may be offline): $e');
      }

      // Best-effort: fetch /info for remote_url so the Remote Access
      // section knows what to probe. Failures are silent — the section
      // just shows "not configured" if /info couldn't be reached.
      String? remoteUrl;
      try {
        final info = await _apiClient.get<ServerInfo>(
          Endpoints.info,
          fromJson: (data) => ServerInfo.fromJson(data as Map<String, dynamic>),
        );
        remoteUrl = info.remoteUrl;
      } catch (e) {
        _log.w('Could not fetch /info for remote_url: $e');
      }

      emit(SettingsLoaded(
        serverUrl: savedUrl,
        serverName: serverName,
        tier: tier,
        maxConcurrentStreams: maxStreams,
        licenseKey: licenseKey,
        transcodingEncoder: transcodingEncoder,
        transcodingPreset: transcodingPreset,
        transcodingCrf: transcodingCrf,
        transcodingChain: transcodingChain,
        streamingMode: streamingMode,
        defaultLibraryView: defaultLibraryView,
        scanLibrariesOnStartup: scanLibrariesOnStartup,
        generateThumbnails: generateThumbnails,
        preferredMode: preferredMode,
        enableMdns: enableMdns,
        enableWebrtc: enableWebrtc,
        relayServerUrl: relayServerUrl,
        defaultQuality: defaultQuality,
        aiSegmentDurationSeconds: aiSegmentDurationSeconds,
        enablePairingRequired: enablePairingRequired,
        sessionTimeoutMinutes: sessionTimeoutMinutes,
        enableLogExport: enableLogExport,
        customServerUrl: customServerUrl,
        remoteUrl: remoteUrl,
      ));
    } catch (e, st) {
      _log.e('Failed to load settings', error: e, stackTrace: st);
      emit(const SettingsLoaded(
        serverUrl: _defaultUrl,
        serverName: 'Fluxora Server',
        tier: 'free',
        maxConcurrentStreams: 1,
        transcodingEncoder: 'libx264',
        transcodingPreset: 'veryfast',
        transcodingCrf: 23,
      ));
    }
  }

  /// Probes `<remoteUrl>/api/v1/healthz` directly (bypassing ApiClient's
  /// LAN/WAN smart-path resolver) to confirm the Cloudflare Tunnel is
  /// reachable from the desktop's network.
  Future<void> checkRemoteAccess() async {
    final current = state;
    if (current is! SettingsLoaded) return;
    final url = current.remoteUrl;
    if (url == null || url.isEmpty) return;

    emit(current.copyWith(
      remoteAccessStatus: () => RemoteAccessStatus.checking,
    ));

    final probe = Dio(BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));

    try {
      final response = await probe.get<dynamic>(Endpoints.healthz);
      final ok = response.statusCode == 200;
      emit(current.copyWith(
        remoteAccessStatus: () =>
            ok ? RemoteAccessStatus.reachable : RemoteAccessStatus.unreachable,
      ));
    } catch (e) {
      _log.w('Remote access probe failed for $url: $e');
      emit(current.copyWith(
        remoteAccessStatus: () => RemoteAccessStatus.unreachable,
      ));
    } finally {
      probe.close(force: true);
    }
  }

  Future<void> saveSettings({
    required String serverUrl,
    required String serverName,
    required String tier,
    String? licenseKey,
    String? transcodingEncoder,
    String? transcodingPreset,
    int? transcodingCrf,
    /// Operator's encoder priority chain (Slice C). `null` means "leave
    /// the existing chain unchanged"; an empty list `[]` clears the
    /// chain so the server falls back to the default; a non-empty list
    /// replaces it.
    List<String>? transcodingChain,
    /// `'client-decode'` (Recommended default), `'auto'`, or
    /// `'server-transcode'`. Null means "leave the existing mode unchanged".
    String? streamingMode,
    // §7.10 extended-settings — every field is optional; omit to leave
    // the server-side value unchanged.
    String? defaultLibraryView,
    bool? scanLibrariesOnStartup,
    bool? generateThumbnails,
    String? preferredMode,
    bool? enableMdns,
    bool? enableWebrtc,
    String? relayServerUrl,
    String? defaultQuality,
    int? aiSegmentDurationSeconds,
    bool? enablePairingRequired,
    int? sessionTimeoutMinutes,
    bool? enableLogExport,
    String? customServerUrl,
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
        message: 'Invalid URL. Example: http://192.168.1.10:8000',
      ));
      return;
    }
    if (trimmedName.isEmpty) {
      emit(const SettingsError(message: 'Server name cannot be empty.'));
      return;
    }

    // Phase 1 — local-only state.  Server URL is a *client-side*
    // preference (lives in `secure_storage`), so this step doesn't need
    // network and must always succeed regardless of server reachability.
    // Without this split, the chicken-and-egg case ("I'm changing the
    // URL precisely because I can't reach the server at the old URL")
    // hard-fails the save and leaves the user stuck on the broken URL.
    try {
      await _secureStorage.saveServerUrl(trimmedUrl);
      _apiClient.configure(localBaseUrl: trimmedUrl);
    } catch (e, st) {
      _log.e('Failed to persist server URL locally', error: e, stackTrace: st);
      emit(SettingsError(
        message: 'Could not save the server URL to local storage: $e',
      ));
      return;
    }

    // Phase 2 — push server-side fields (server_name / tier / license /
    // transcoding) to the freshly-configured ApiClient.  May fail if the
    // user just typed a wrong host or the server is down; in that case
    // the URL change *still* landed in step 1, and the user can restart
    // the desktop or fix the URL on the next attempt without losing
    // their save.
    try {
      await _apiClient.patch<void>(
        Endpoints.serverSettings,
        body: {
          'server_name': trimmedName,
          'tier': tier,
          if (licenseKey != null && licenseKey.trim().isNotEmpty)
            'license_key': licenseKey.trim(),
          'transcoding_encoder': ?transcodingEncoder,
          'transcoding_preset': ?transcodingPreset,
          'transcoding_crf': ?transcodingCrf,
          'transcoding_chain': ?transcodingChain,
          'streaming_mode': ?streamingMode,
          // §7.10 extended-settings
          'default_library_view': ?defaultLibraryView,
          'scan_libraries_on_startup': ?scanLibrariesOnStartup,
          'generate_thumbnails': ?generateThumbnails,
          'preferred_mode': ?preferredMode,
          'enable_mdns': ?enableMdns,
          'enable_webrtc': ?enableWebrtc,
          'relay_server_url': ?relayServerUrl,
          'default_quality': ?defaultQuality,
          'ai_segment_duration_seconds': ?aiSegmentDurationSeconds,
          'enable_pairing_required': ?enablePairingRequired,
          'session_timeout_minutes': ?sessionTimeoutMinutes,
          'enable_log_export': ?enableLogExport,
          'custom_server_url': ?customServerUrl,
        },
      );
      emit(SettingsSaved(
        serverUrl: trimmedUrl,
        serverName: trimmedName,
        tier: tier,
      ));
    } on ApiException catch (e, st) {
      _log.e('Server-side settings sync failed', error: e, stackTrace: st);
      // 4xx is a server-side rejection (typically validation): the URL
      // change DID land, but one of the other fields was rejected.  The
      // user needs to know *which* field to fix — surface the parsed
      // detail.  CONNECTION_ERROR / TIMEOUT keep the original "couldn't
      // reach" framing because the URL change still applied locally and
      // the user's recovery action is to retry once the server is up.
      final isClientError =
          e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500;
      emit(SettingsError(
        message: isClientError
            ? 'Server URL saved, but the server rejected one of the '
                'other settings: ${e.message}. Fix the highlighted '
                'value and click Retry save.'
            : 'Server URL saved locally, but couldn\'t reach the server '
                'at $trimmedUrl to sync server-side settings '
                '(${e.message}). Verify the server is running on that '
                'URL — restart the desktop afterwards if changes don\'t '
                'apply.',
      ));
    } catch (e, st) {
      _log.e('Server-side settings sync failed', error: e, stackTrace: st);
      emit(SettingsError(
        message:
            'Server URL saved locally, but the server-side settings '
            'sync failed: $e. Restart the desktop or verify the URL.',
      ));
    }
  }

  @override
  void emit(SettingsState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
