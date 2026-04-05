import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app.dart';
import '../../core/constants/default_prompts.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/photo_service.dart';
import '../../core/theme/theme_notifier.dart';
import '../lock/lock_screen.dart';
import '../../core/utils/date_utils.dart' as du;
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

class SettingsController extends AutoDisposeAsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    final results = await Future.wait([
      settingsRepo.getPrompts(),
      settingsRepo.getReminderSettings(),
      settingsRepo.getThemeMode(),
      PackageInfo.fromPlatform().then((info) => info.version).catchError((_) => '1.0.0'),
      settingsRepo.isBiometricLockEnabled(),
    ]);
    final prompts = results[0] as List<String>;
    final reminder = results[1] as ({bool enabled, int hour, int minute});
    final themeMode = results[2] as String;
    final version = results[3] as String;
    final biometricLock = results[4] as bool;

    return SettingsState(
      prompts: prompts,
      reminderEnabled: reminder.enabled,
      reminderHour: reminder.hour,
      reminderMinute: reminder.minute,
      themeMode: themeMode,
      appVersion: version,
      biometricLockEnabled: biometricLock,
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
      final entryRepo = ref.read(entryRepositoryProvider);
      final scheduled = await notifService.scheduleSmartDailyReminder(
        hour: current.reminderHour,
        minute: current.reminderMinute,
        entryExistsToday: () async => await entryRepo.getTodayEntry() != null,
      );
      if (!scheduled) return false;

      // Schedule streak-at-risk notification (1hr before) if user has a streak
      final streak = await entryRepo.getCurrentStreak();
      if (streak > 0) {
        await notifService.scheduleStreakAtRiskReminder(
          reminderHour: current.reminderHour,
          reminderMinute: current.reminderMinute,
        );
      }

      // Schedule Sunday weekly retrospective reminder
      await notifService.scheduleWeeklyRetrospectiveReminder();
    } else {
      await notifService.cancelReminder();
    }

    await repo.setSetting('reminder_enabled', enabled.toString());
    state = AsyncData(current.copyWith(reminderEnabled: enabled));
    return true;
  }

  /// Updates the reminder time. Returns false if rescheduling fails.
  Future<bool> setReminderTime(int hour, int minute) async {
    final repo = ref.read(settingsRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);
    final current = state.valueOrNull;
    if (current == null) return false;

    try {
      await repo.setSetting('reminder_hour', hour.toString());
      await repo.setSetting('reminder_minute', minute.toString());

      if (current.reminderEnabled) {
        final entryRepo = ref.read(entryRepositoryProvider);
        final scheduled = await notifService.scheduleSmartDailyReminder(
          hour: hour,
          minute: minute,
          entryExistsToday: () async => await entryRepo.getTodayEntry() != null,
        );
        if (!scheduled) return false;

        // Reschedule streak-at-risk with new time
        final streak = await entryRepo.getCurrentStreak();
        if (streak > 0) {
          await notifService.scheduleStreakAtRiskReminder(
            reminderHour: hour,
            reminderMinute: minute,
          );
        } else {
          await notifService.cancelStreakAtRiskReminder();
        }
      }

      state = AsyncData(
          current.copyWith(reminderHour: hour, reminderMinute: minute));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Enables or disables biometric lock. Returns false if device doesn't support it.
  Future<bool> setBiometricLockEnabled(bool enabled) async {
    final repo = ref.read(settingsRepositoryProvider);

    if (enabled) {
      final bioService = ref.read(biometricServiceProvider);
      final available = await bioService.isAvailable();
      if (!available) return false;
      // Verify user can authenticate before enabling
      final authenticated = await bioService.authenticate();
      if (!authenticated) return false;
    }

    await repo.setSetting('biometric_lock_enabled', enabled.toString());
    final current = state.valueOrNull;
    if (current == null) return false;
    state = AsyncData(current.copyWith(biometricLockEnabled: enabled));

    // biometricLockEnabledProvider를 갱신하여 라우터가 변경을 감지하게 한다.
    ref.invalidate(biometricLockEnabledProvider);

    // 비활성화 시 현재 잠금 상태도 즉시 해제한다.
    if (!enabled) {
      ref.read(biometricLockStateProvider.notifier).state = false;
    }

    return true;
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
      'exported_at': du.formatWithTimezone(DateTime.now()),
      'total_entries': entries.length,
      'entries': entries,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Imports entries from a JSON string (exported format). Returns import
  /// result with counts, or throws on invalid JSON.
  Future<({int imported, int skipped})> importData(String jsonStr) async {
    final decoded = json.decode(jsonStr);
    final List<dynamic> entriesList;
    if (decoded is List<dynamic>) {
      entriesList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final list = decoded['entries'] as List<dynamic>?;
      if (list == null) {
        throw const FormatException('No entries found in file');
      }
      entriesList = list;
    } else {
      throw const FormatException('Invalid export format');
    }
    // cast<>() 대신 whereType으로 안전하게 필터링하여
    // 잘못된 타입의 항목이 전체 가져오기를 실패시키지 않도록 한다.
    final entries = entriesList.whereType<Map<String, dynamic>>().toList();
    final skippedByType = entriesList.length - entries.length;
    final entryRepo = ref.read(entryRepositoryProvider);
    final result = await entryRepo.importEntries(entries);

    // Refresh dependent screens
    ref.invalidate(todayControllerProvider);
    ref.invalidate(timelineControllerProvider);
    ref.invalidate(insightsControllerProvider);

    return (imported: result.imported, skipped: result.skipped + skippedByType);
  }

  /// Deletes all entries. Returns false on failure.
  Future<bool> deleteAllData() async {
    try {
      final entryRepo = ref.read(entryRepositoryProvider);
      final photoService = ref.read(photoServiceProvider);

      // 삭제 전에 모든 사진 파일 경로를 확보한다.
      final photoPaths = await entryRepo.getAllPhotoPaths();

      await entryRepo.deleteAllEntries();

      // 고아 사진 파일을 디스크에서 정리한다.
      for (final path in photoPaths) {
        await photoService.deletePhoto(path);
      }

      // Invalidate all data-dependent screens
      ref.invalidate(todayControllerProvider);
      ref.invalidate(timelineControllerProvider);
      ref.invalidate(insightsControllerProvider);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final settingsControllerProvider =
    AutoDisposeAsyncNotifierProvider<SettingsController, SettingsState>(
        SettingsController.new);
