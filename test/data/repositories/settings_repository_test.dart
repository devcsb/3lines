import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getSetting', () {
    test('returns default value when key does not exist', () async {
      final result =
          await repo.getSetting('nonexistent', defaultValue: 'fallback');
      expect(result, 'fallback');
    });

    test('returns stored value when key exists', () async {
      await repo.setSetting('test_key', 'test_value');
      final result =
          await repo.getSetting('test_key', defaultValue: 'fallback');
      expect(result, 'test_value');
    });
  });

  group('setSetting', () {
    test('creates new setting', () async {
      await repo.setSetting('new_key', 'new_value');
      final result =
          await repo.getSetting('new_key', defaultValue: '');
      expect(result, 'new_value');
    });

    test('updates existing setting (upsert)', () async {
      await repo.setSetting('key', 'value1');
      await repo.setSetting('key', 'value2');
      final result = await repo.getSetting('key', defaultValue: '');
      expect(result, 'value2');
    });
  });

  group('getPrompts', () {
    test('returns default prompts when none customized', () async {
      final prompts = await repo.getPrompts();
      expect(prompts.length, 3);
      expect(prompts[0], '오늘 감사한 작은 것 하나는?');
      expect(prompts[1], '오늘 불편했던 감정을, 있는 그대로 인정한다면?');
      expect(prompts[2], '내일 내가 되고 싶은 모습은?');
    });

    test('returns customized prompts', () async {
      await repo.setSetting('prompt_1', '커스텀 질문');
      final prompts = await repo.getPrompts();
      expect(prompts[0], '커스텀 질문');
      expect(prompts[1], '오늘 불편했던 감정을, 있는 그대로 인정한다면?');
    });
  });

  group('getReminderSettings', () {
    test('returns default reminder settings', () async {
      final settings = await repo.getReminderSettings();
      expect(settings.enabled, false);
      expect(settings.hour, 21);
      expect(settings.minute, 0);
    });

    test('returns customized reminder settings', () async {
      await repo.setSetting('reminder_enabled', 'true');
      await repo.setSetting('reminder_hour', '8');
      await repo.setSetting('reminder_minute', '30');
      final settings = await repo.getReminderSettings();
      expect(settings.enabled, true);
      expect(settings.hour, 8);
      expect(settings.minute, 30);
    });
  });

  group('getThemeMode', () {
    test('returns system by default', () async {
      final mode = await repo.getThemeMode();
      expect(mode, 'system');
    });

    test('returns stored theme mode', () async {
      await repo.setSetting('theme_mode', 'dark');
      final mode = await repo.getThemeMode();
      expect(mode, 'dark');
    });
  });

  group('isOnboardingDone', () {
    test('returns false by default', () async {
      expect(await repo.isOnboardingDone(), false);
    });

    test('returns true after completing onboarding', () async {
      await repo.setSetting('onboarding_done', 'true');
      expect(await repo.isOnboardingDone(), true);
    });
  });
}
