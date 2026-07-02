abstract final class SettingKeys {
  static const prompt1 = 'prompt_1';
  static const prompt2 = 'prompt_2';
  static const prompt3 = 'prompt_3';
  static const promptKeys = [prompt1, prompt2, prompt3];

  static const reminderEnabled = 'reminder_enabled';
  static const reminderHour = 'reminder_hour';
  static const reminderMinute = 'reminder_minute';

  static const themeMode = 'theme_mode';
  static const accentTheme = 'accent_theme';
  static const unlockedMilestones = 'unlocked_milestones';
  static const biometricLockEnabled = 'biometric_lock_enabled';
  static const onboardingDone = 'onboarding_done';
}

abstract final class SettingDefaults {
  static const reminderEnabled = 'false';
  static const reminderHour = '21';
  static const reminderMinute = '0';
  static const themeMode = 'system';
  static const accentTheme = 'sage';
  static const unlockedMilestones = '';
  static const biometricLockEnabled = 'false';
  static const onboardingDone = 'false';
}
