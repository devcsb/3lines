import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/default_prompts.dart';
import '../database/app_database.dart';

class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  Future<String> getSetting(String key, {required String defaultValue}) async {
    final query = _db.select(_db.settings)
      ..where((t) => t.key.equals(key));
    final result = await query.getSingleOrNull();
    return result?.value ?? defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion(
            key: Value(key),
            value: Value(value),
          ),
        );
  }

  Future<List<String>> getPrompts() async {
    final results = await Future.wait([
      getSetting('prompt_1', defaultValue: defaultPromptQuestions[0]),
      getSetting('prompt_2', defaultValue: defaultPromptQuestions[1]),
      getSetting('prompt_3', defaultValue: defaultPromptQuestions[2]),
    ]);
    return results;
  }

  Future<({bool enabled, int hour, int minute})> getReminderSettings() async {
    final results = await Future.wait([
      getSetting('reminder_enabled', defaultValue: 'false'),
      getSetting('reminder_hour', defaultValue: '21'),
      getSetting('reminder_minute', defaultValue: '0'),
    ]);
    return (
      enabled: results[0] == 'true',
      hour: int.parse(results[1]),
      minute: int.parse(results[2]),
    );
  }

  Future<String> getThemeMode() async {
    return getSetting('theme_mode', defaultValue: 'system');
  }

  Future<bool> isOnboardingDone() async {
    final value =
        await getSetting('onboarding_done', defaultValue: 'false');
    return value == 'true';
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});
