class SettingsState {
  final List<String> prompts;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final String themeMode;
  final String appVersion;
  final bool biometricLockEnabled;

  const SettingsState({
    this.prompts = const ['', '', ''],
    this.reminderEnabled = false,
    this.reminderHour = 21,
    this.reminderMinute = 0,
    this.themeMode = 'system',
    this.appVersion = '',
    this.biometricLockEnabled = false,
  });

  SettingsState copyWith({
    List<String>? prompts,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    String? themeMode,
    String? appVersion,
    bool? biometricLockEnabled,
  }) {
    return SettingsState(
      prompts: prompts ?? this.prompts,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      themeMode: themeMode ?? this.themeMode,
      appVersion: appVersion ?? this.appVersion,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
    );
  }
}
