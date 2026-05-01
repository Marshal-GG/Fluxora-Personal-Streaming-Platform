sealed class SettingsState {
  const SettingsState();
}

final class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

final class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

/// Reachability of the configured remote URL. `null` = not yet probed.
enum RemoteAccessStatus { reachable, unreachable, checking }

final class SettingsLoaded extends SettingsState {
  const SettingsLoaded({
    required this.serverUrl,
    required this.serverName,
    required this.tier,
    required this.maxConcurrentStreams,
    this.licenseKey,
    required this.transcodingEncoder,
    required this.transcodingPreset,
    required this.transcodingCrf,
    this.remoteUrl,
    this.remoteAccessStatus,
  });

  final String serverUrl;
  final String serverName;
  final String tier;
  final int maxConcurrentStreams;
  final String? licenseKey;
  final String transcodingEncoder;
  final String transcodingPreset;
  final int transcodingCrf;

  /// The server's configured public URL (Cloudflare Tunnel), read from
  /// `GET /api/v1/info`. `null` when the server has no `FLUXORA_PUBLIC_URL`
  /// set. Distinct from [serverUrl] which is the local LAN URL.
  final String? remoteUrl;

  /// Status of the most recent reachability probe against [remoteUrl] +
  /// `/api/v1/healthz`. `null` if no probe has run yet.
  final RemoteAccessStatus? remoteAccessStatus;

  SettingsLoaded copyWith({
    String? Function()? remoteUrl,
    RemoteAccessStatus? Function()? remoteAccessStatus,
  }) {
    return SettingsLoaded(
      serverUrl: serverUrl,
      serverName: serverName,
      tier: tier,
      maxConcurrentStreams: maxConcurrentStreams,
      licenseKey: licenseKey,
      transcodingEncoder: transcodingEncoder,
      transcodingPreset: transcodingPreset,
      transcodingCrf: transcodingCrf,
      remoteUrl: remoteUrl != null ? remoteUrl() : this.remoteUrl,
      remoteAccessStatus: remoteAccessStatus != null
          ? remoteAccessStatus()
          : this.remoteAccessStatus,
    );
  }
}

final class SettingsSaved extends SettingsState {
  const SettingsSaved({
    required this.serverUrl,
    required this.serverName,
    required this.tier,
  });

  final String serverUrl;
  final String serverName;
  final String tier;
}

final class SettingsError extends SettingsState {
  const SettingsError({required this.message});

  final String message;
}
