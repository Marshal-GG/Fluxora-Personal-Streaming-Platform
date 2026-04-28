sealed class SettingsState {
  const SettingsState();
}

final class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

final class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

final class SettingsLoaded extends SettingsState {
  const SettingsLoaded({
    required this.serverUrl,
    required this.serverName,
    required this.tier,
    required this.maxConcurrentStreams,
    this.licenseKey,
  });

  final String serverUrl;
  final String serverName;
  final String tier;
  final int maxConcurrentStreams;
  final String? licenseKey;
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
