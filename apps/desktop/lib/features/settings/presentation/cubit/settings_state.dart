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
  const SettingsLoaded({required this.serverUrl});

  final String serverUrl;
}

final class SettingsSaved extends SettingsState {
  const SettingsSaved({required this.serverUrl});

  final String serverUrl;
}

final class SettingsError extends SettingsState {
  const SettingsError({required this.message});

  final String message;
}
