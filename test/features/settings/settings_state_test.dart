import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/settings/settings_state.dart';

void main() {
  group('SettingsState', () {
    test('default values', () {
      const state = SettingsState();
      expect(state.prompts, ['', '', '']);
      expect(state.reminderEnabled, isFalse);
      expect(state.reminderHour, 21);
      expect(state.reminderMinute, 0);
      expect(state.themeMode, 'system');
      expect(state.appVersion, isEmpty);
    });

    test('copyWith preserves unspecified fields', () {
      const original = SettingsState(
        reminderEnabled: true,
        reminderHour: 9,
        reminderMinute: 30,
        themeMode: 'dark',
        appVersion: '1.0.0',
      );
      final copied = original.copyWith(reminderEnabled: false);
      expect(copied.reminderEnabled, isFalse);
      expect(copied.reminderHour, 9);
      expect(copied.reminderMinute, 30);
      expect(copied.themeMode, 'dark');
      expect(copied.appVersion, '1.0.0');
    });

    test('copyWith can update prompts', () {
      const original = SettingsState();
      final copied = original.copyWith(
        prompts: ['질문1', '질문2', '질문3'],
      );
      expect(copied.prompts, ['질문1', '질문2', '질문3']);
    });
  });
}
