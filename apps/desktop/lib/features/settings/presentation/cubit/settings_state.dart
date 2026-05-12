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
    this.transcodingChain,
    this.streamingMode = 'client-decode',
    // §7.10 extended-settings fields (migration 015 + 023).
    this.defaultLibraryView = 'grid',
    this.scanLibrariesOnStartup = true,
    this.generateThumbnails = true,
    this.preferredMode = 'auto',
    this.enableMdns = true,
    this.enableWebrtc = true,
    this.relayServerUrl,
    this.defaultQuality = 'auto',
    this.aiSegmentDurationSeconds = 4,
    this.enablePairingRequired = true,
    this.sessionTimeoutMinutes = 60,
    this.enableLogExport = true,
    this.customServerUrl,
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

  /// Operator's encoder priority chain (Slice C). `null` means "use the
  /// default chain" (`[transcodingEncoder, libx264]`). Drives the
  /// EncoderPriorityList widget.
  final List<String>? transcodingChain;

  /// Streaming pipeline mode. `'client-decode'` (Recommended default,
  /// plan 19 §M7) stream-copies modern codecs unconditionally — strict,
  /// no fallback.  `'auto'` (plan 20) is opt-in: starts with stream-copy
  /// and falls back to transcode when the client reports a decode error
  /// within 6 s.  `'server-transcode'` is the legacy plan-18 behaviour
  /// (server live-transcodes AV1/VP9 to H.264 before streaming).
  final String streamingMode;

  // ── §7.10 extended-settings fields (migration 015) ──────────────────────
  // General
  final String defaultLibraryView; // 'grid' | 'list'
  final bool scanLibrariesOnStartup;
  final bool generateThumbnails;
  // Network
  final String preferredMode; // 'auto' | 'lan' | 'webrtc'
  final bool enableMdns;
  final bool enableWebrtc;
  final String? relayServerUrl;
  // Streaming
  final String defaultQuality; // 'auto' | '4k' | '1080p' | '720p' | '480p'
  final int aiSegmentDurationSeconds; // server clamps 1..30
  // Security
  final bool enablePairingRequired;
  final int sessionTimeoutMinutes; // server clamps 1..1440
  // Advanced
  final bool enableLogExport;
  final String? customServerUrl;

  /// The server's configured public URL (Cloudflare Tunnel), read from
  /// `GET /api/v1/info`. `null` when the server has no `FLUXORA_PUBLIC_URL`
  /// set AND no `user_settings.custom_server_url` override. Distinct from
  /// [serverUrl] which is the local LAN URL the desktop reaches the server
  /// at.
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
