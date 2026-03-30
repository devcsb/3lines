import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/default_prompts.dart';
import '../../core/utils/date_utils.dart' as du;
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

  /// Returns today's prompts. Uses the rotating pool unless the user has
  /// explicitly saved a custom prompt for that slot.
  Future<List<String>> getRotatingPrompts() async {
    final dayIndex = du.daysSinceEpoch();
    final pools = [gratitudePromptPool, acceptancePromptPool, intentionPromptPool];
    final keys = ['prompt_1', 'prompt_2', 'prompt_3'];

    final results = await Future.wait(
      List.generate(3, (i) async {
        final stored = await getSetting(keys[i], defaultValue: '');
        if (stored.isNotEmpty) return stored;
        // No custom prompt — pick from rotating pool
        return pools[i][dayIndex % pools[i].length];
      }),
    );
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
      hour: int.tryParse(results[1]) ?? 21,
      minute: int.tryParse(results[2]) ?? 0,
    );
  }

  Future<String> getThemeMode() async {
    return getSetting('theme_mode', defaultValue: 'system');
  }

  Future<String> getAccentTheme() async {
    return getSetting('accent_theme', defaultValue: 'sage');
  }

  Future<void> setAccentTheme(String accent) async {
    await setSetting('accent_theme', accent);
  }

  /// Returns a set of unlocked milestone streak values (e.g. {7, 30, 100}).
  Future<Set<int>> getUnlockedMilestones() async {
    final raw = await getSetting('unlocked_milestones', defaultValue: '');
    if (raw.isEmpty) return {};
    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
  }

  Future<void> unlockMilestone(int streak) async {
    final current = await getUnlockedMilestones();
    current.add(streak);
    await setSetting('unlocked_milestones', current.join(','));
  }

  Future<bool> isBiometricLockEnabled() async {
    final value =
        await getSetting('biometric_lock_enabled', defaultValue: 'false');
    return value == 'true';
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
