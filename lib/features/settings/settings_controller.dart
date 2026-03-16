import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/default_prompts.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/theme_notifier.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../insights/insights_controller.dart';
import '../timeline/timeline_controller.dart';
import '../today/today_controller.dart';

class SettingsState {
  final List<String> prompts;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final String themeMode;
  final String appVersion;

  const SettingsState({
    this.prompts = const ['', '', ''],
    this.reminderEnabled = false,
    this.reminderHour = 21,
    this.reminderMinute = 0,
    this.themeMode = 'system',
    this.appVersion = '',
  });

  SettingsState copyWith({
    List<String>? prompts,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    String? themeMode,
    String? appVersion,
  }) {
    return SettingsState(
      prompts: prompts ?? this.prompts,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      themeMode: themeMode ?? this.themeMode,
      appVersion: appVersion ?? this.appVersion,
    );
  }
}

class SettingsController extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final results = await Future.wait([
      settingsRepo.getPrompts(),
      settingsRepo.getReminderSettings(),
      settingsRepo.getThemeMode(),
      PackageInfo.fromPlatform().then((info) => info.version).catchError((_) => '1.0.0'),
    ]);
    final prompts = results[0] as List<String>;
    final reminder = results[1] as ({bool enabled, int hour, int minute});
    final themeMode = results[2] as String;
    final version = results[3] as String;

    return SettingsState(
      prompts: prompts,
      reminderEnabled: reminder.enabled,
      reminderHour: reminder.hour,
      reminderMinute: reminder.minute,
      themeMode: themeMode,
      appVersion: version,
    );
  }

  Future<void> updatePrompt(int index, String value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSetting('prompt_${index + 1}', value);
    final current = state.valueOrNull;
    if (current == null) return;
    final newPrompts = List<String>.from(current.prompts);
    newPrompts[index] = value;
    state = AsyncData(current.copyWith(prompts: newPrompts));
    // Refresh Today screen so it shows the updated prompts
    ref.invalidate(todayControllerProvider);
  }

  Future<void> resetPrompts() async {
    final repo = ref.read(settingsRepositoryProvider);
    for (int i = 0; i < 3; i++) {
      await repo.setSetting('prompt_${i + 1}', defaultPromptQuestions[i]);
    }
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
        current.copyWith(prompts: List.from(defaultPromptQuestions)));
    ref.invalidate(todayControllerProvider);
  }

  /// Enables or disables the daily reminder. Returns false if scheduling fails.
  Future<bool> setReminderEnabled(bool enabled) async {
    final repo = ref.read(settingsRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);

    if (enabled) {
      final granted = await notifService.requestPermission();
      if (!granted) return false;
    }

    final current = state.valueOrNull;
    if (current == null) return false;

    if (enabled) {
      final scheduled = await notifService.scheduleDailyReminder(
        hour: current.reminderHour,
        minute: current.reminderMinute,
      );
      if (!scheduled) return false;
    } else {
      await notifService.cancelReminder();
    }

    await repo.setSetting('reminder_enabled', enabled.toString());
    state = AsyncData(current.copyWith(reminderEnabled: enabled));
    return true;
  }

  Future<void> setReminderTime(int hour, int minute) async {
    final repo = ref.read(settingsRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);
    await repo.setSetting('reminder_hour', hour.toString());
    await repo.setSetting('reminder_minute', minute.toString());
    final current = state.valueOrNull;
    if (current == null) return;

    if (current.reminderEnabled) {
      await notifService.scheduleDailyReminder(hour: hour, minute: minute);
    }

    state = AsyncData(
        current.copyWith(reminderHour: hour, reminderMinute: minute));
  }

  Future<void> setThemeMode(String mode) async {
    // Update via ThemeNotifier (which persists to DB and updates app theme)
    await ref.read(themeNotifierProvider.notifier).setThemeMode(mode);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(themeMode: mode));
  }

  Future<String> exportData() async {
    final entryRepo = ref.read(entryRepositoryProvider);
    final entries = await entryRepo.exportAllEntries();
    final data = {
      'app': '3Lines',
      'version': '1.0.0',
      'exported_at': _formatWithTimezone(DateTime.now()),
      'total_entries': entries.length,
      'entries': entries,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String _formatWithTimezone(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final base = dt.toIso8601String().split('.').first;
    return '$base$sign$hours:$minutes';
  }

  /// Imports entries from a JSON string (exported format). Returns the count
  /// of entries imported, or throws on invalid JSON.
  Future<int> importData(String jsonStr) async {
    final decoded = json.decode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid export format');
    }
    final entriesList = decoded['entries'] as List<dynamic>?;
    if (entriesList == null) {
      throw const FormatException('No entries found in file');
    }
    final entries = entriesList.cast<Map<String, dynamic>>();
    final entryRepo = ref.read(entryRepositoryProvider);
    final count = await entryRepo.importEntries(entries);

    // Refresh dependent screens
    ref.invalidate(todayControllerProvider);
    ref.invalidate(timelineControllerProvider);
    ref.invalidate(insightsControllerProvider);

    return count;
  }

  Future<void> deleteAllData() async {
    final entryRepo = ref.read(entryRepositoryProvider);
    await entryRepo.deleteAllEntries();

    // Invalidate all data-dependent screens
    ref.invalidate(todayControllerProvider);
    ref.invalidate(timelineControllerProvider);
    ref.invalidate(insightsControllerProvider);
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(
        SettingsController.new);
