import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class SecureStorage {
  const SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _keyAuthToken = 'auth_token';
  static const String _keyServerUrl = 'server_url';
  static const String _keyRemoteUrl = 'remote_url';
  static const String _keyClientId = 'client_id';
  static const String _keyBgPlaybackEnabled = 'bg_playback_enabled';
  static const String _keyBgPlaybackPromptShown = 'bg_playback_prompt_shown';
  // Playback prefs (M3 — settings remediation, 2026-05-08).  Stored
  // alongside the bg-playback flags so all five player prefs live in
  // one bucket of secure-storage keys.
  static const String _keyWifiOnlyStreaming = 'wifi_only_streaming';
  static const String _keyMaxStreamingQuality = 'max_streaming_quality';
  static const String _keyAutoplayNext = 'autoplay_next';
  static const String _keySubtitlesDefaultOn = 'subtitles_default_on';

  /// Allowed values for [getMaxStreamingQuality] / [setMaxStreamingQuality].
  /// Anything else round-trips back as [maxStreamingQualityDefault].
  static const String maxStreamingQualityDefault = 'auto';
  static const Set<String> allowedMaxStreamingQualities = {
    'auto',
    '1080p',
    '720p',
    '480p',
  };

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

  // ── Player polish: background-playback preference (Phase 3) ────────────────
  // Persisted in flutter_secure_storage rather than shared_preferences to
  // avoid pulling another dep — secure storage's overhead is irrelevant for
  // a once-per-session bool read.

  /// `true` when the user has opted to keep audio playing while the app
  /// is in the background.  Defaults to `false` (the safer / less
  /// surprising option).  Set after the user answers the first-time
  /// prompt or toggles the option in Profile → Playback.
  Future<bool> getBackgroundPlaybackEnabled() async {
    try {
      final raw = await _storage.read(key: _keyBgPlaybackEnabled);
      return raw == 'true';
    } catch (e, st) {
      _log.e('Failed to read bg-playback pref', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> setBackgroundPlaybackEnabled(bool value) async {
    try {
      await _storage.write(
        key: _keyBgPlaybackEnabled,
        value: value ? 'true' : 'false',
      );
    } catch (e, st) {
      _log.e('Failed to write bg-playback pref', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Whether the first-time bg-playback confirmation prompt has been
  /// shown.  Once true the player no longer interrupts the user; the
  /// answer (enabled / disabled) drives behaviour from Profile
  /// → Playback.
  Future<bool> getBackgroundPlaybackPromptShown() async {
    try {
      final raw = await _storage.read(key: _keyBgPlaybackPromptShown);
      return raw == 'true';
    } catch (e, st) {
      _log.e('Failed to read bg-playback prompt flag',
          error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> setBackgroundPlaybackPromptShown(bool value) async {
    try {
      await _storage.write(
        key: _keyBgPlaybackPromptShown,
        value: value ? 'true' : 'false',
      );
    } catch (e, st) {
      _log.e('Failed to write bg-playback prompt flag',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Playback prefs (M3 — settings remediation) ────────────────────────────
  // Same flutter_secure_storage bucket as bg-playback above; same
  // logger.error+rethrow contract.  Defaults are documented in
  // `docs/10_planning/archive/15_mobile_settings_remediation_plan.md` §4 M3.

  /// `true` when the player should refuse to start a stream over a
  /// cellular connection.  Default `false` (no Wi-Fi-only enforcement).
  /// The actual cellular check + refusal is the `PlayerCubit`'s job in a
  /// follow-up milestone; this is purely the persisted preference.
  Future<bool> getWifiOnlyStreaming() async {
    try {
      final raw = await _storage.read(key: _keyWifiOnlyStreaming);
      return raw == 'true';
    } catch (e, st) {
      _log.e('Failed to read wifi-only streaming pref',
          error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> setWifiOnlyStreaming(bool value) async {
    try {
      await _storage.write(
        key: _keyWifiOnlyStreaming,
        value: value ? 'true' : 'false',
      );
    } catch (e, st) {
      _log.e('Failed to write wifi-only streaming pref',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Maximum streaming quality the player may request.  One of
  /// [allowedMaxStreamingQualities].  Defaults to [maxStreamingQualityDefault]
  /// (`auto`) when unset or when the persisted value falls outside the
  /// allow-list — defending against a stale install whose enum was widened.
  Future<String> getMaxStreamingQuality() async {
    try {
      final raw = await _storage.read(key: _keyMaxStreamingQuality);
      if (raw == null || !allowedMaxStreamingQualities.contains(raw)) {
        return maxStreamingQualityDefault;
      }
      return raw;
    } catch (e, st) {
      _log.e('Failed to read max-streaming-quality pref',
          error: e, stackTrace: st);
      return maxStreamingQualityDefault;
    }
  }

  Future<void> setMaxStreamingQuality(String value) async {
    if (!allowedMaxStreamingQualities.contains(value)) {
      // Refuse out-of-range values rather than silently coercing — a
      // bad caller is a bug we want to surface, not paper over.
      throw ArgumentError.value(
        value,
        'value',
        'must be one of $allowedMaxStreamingQualities',
      );
    }
    try {
      await _storage.write(key: _keyMaxStreamingQuality, value: value);
    } catch (e, st) {
      _log.e('Failed to write max-streaming-quality pref',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// `true` when the player should auto-advance to the next episode at
  /// end-of-stream.  Default `true` (matches user expectation for serial
  /// content).
  Future<bool> getAutoplayNext() async {
    try {
      final raw = await _storage.read(key: _keyAutoplayNext);
      // Default-true: a missing key means "never set" → use the default.
      if (raw == null) return true;
      return raw == 'true';
    } catch (e, st) {
      _log.e('Failed to read autoplay-next pref',
          error: e, stackTrace: st);
      return true;
    }
  }

  Future<void> setAutoplayNext(bool value) async {
    try {
      await _storage.write(
        key: _keyAutoplayNext,
        value: value ? 'true' : 'false',
      );
    } catch (e, st) {
      _log.e('Failed to write autoplay-next pref',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// `true` when subtitles should be enabled by default on new streams.
  /// Default `false` (matches the existing player behaviour — subtitles
  /// off until the user opts in via the Subtitles sheet).
  Future<bool> getSubtitlesDefaultOn() async {
    try {
      final raw = await _storage.read(key: _keySubtitlesDefaultOn);
      return raw == 'true';
    } catch (e, st) {
      _log.e('Failed to read subtitles-default-on pref',
          error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> setSubtitlesDefaultOn(bool value) async {
    try {
      await _storage.write(
        key: _keySubtitlesDefaultOn,
        value: value ? 'true' : 'false',
      );
    } catch (e, st) {
      _log.e('Failed to write subtitles-default-on pref',
          error: e, stackTrace: st);
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
