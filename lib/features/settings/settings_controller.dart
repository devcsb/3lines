import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/router.dart';
import '../../core/constants/default_prompts.dart';
import '../../core/events/journal_changes.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/photo_service.dart';
import '../../core/services/reminder_coordinator.dart';
import '../../core/settings/settings_keys.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/time/app_clock.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../data/models/entry_import.dart';
import '../../data/models/journal_draft.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../lock/lock_screen.dart';
import '../today/today_controller.dart';
import 'settings_state.dart';

class SettingsController extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    final results = await Future.wait([
      settingsRepo.getPrompts(),
      settingsRepo.getReminderSettings(),
      settingsRepo.getThemeMode(),
      PackageInfo.fromPlatform()
          .then((info) => info.version)
          .catchError((_) => 'unknown'),
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
    if (index < 0 || index >= SettingKeys.promptKeys.length) {
      return;
    }

    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSetting(SettingKeys.promptKeys[index], value);
    ref.read(journalChangesProvider.notifier).markChanged();
    final current = state.value;
    if (current == null) return;
    final newPrompts = List<String>.from(current.prompts);
    newPrompts[index] = value;
    state = AsyncData(current.copyWith(prompts: newPrompts));
    // Questions are fixed for the current session; new records read new settings.
  }

  Future<void> resetPrompts() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.resetPrompts();
    ref.read(journalChangesProvider.notifier).markChanged();
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(prompts: List.from(defaultPromptQuestions)),
    );
  }

  /// Enables or disables the daily reminder. Returns false if scheduling fails.
  Future<bool> setReminderEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return false;
    final success = await ref
        .read(reminderCoordinatorProvider)
        .setEnabled(enabled);
    if (!success) return false;
    final latest = state.value ?? current;
    state = AsyncData(latest.copyWith(reminderEnabled: enabled));
    return true;
  }

  /// Updates the reminder time. Returns false if rescheduling fails.
  Future<bool> setReminderTime(int hour, int minute) async {
    final current = state.value;
    if (current == null) return false;
    final success = await ref
        .read(reminderCoordinatorProvider)
        .setTime(hour, minute);
    if (!success) return false;
    final latest = state.value ?? current;
    state = AsyncData(
      latest.copyWith(reminderHour: hour, reminderMinute: minute),
    );
    return true;
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

    await repo.setSetting(SettingKeys.biometricLockEnabled, enabled.toString());
    final current = state.value;
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
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(themeMode: mode));
  }

  Future<String> exportData() async {
    final entryRepo = ref.read(entryRepositoryProvider);
    final entries = await entryRepo.exportAllEntries();
    final version = await _readAppVersion();
    final data = {
      'app': '3Lines',
      'version': version,
      'exported_at': du.formatWithTimezone(ref.read(appClockProvider).now()),
      'total_entries': entries.length,
      'entries': entries,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String> _readAppVersion() async {
    try {
      final version = (await PackageInfo.fromPlatform()).version.trim();
      if (version.isNotEmpty) return version;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read app version for export',
        name: 'settings',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final loadedVersion = state.value?.appVersion.trim();
    return loadedVersion == null || loadedVersion.isEmpty
        ? 'unknown'
        : loadedVersion;
  }

  final _applications = <ImportPreview, Future<ImportResult>>{};

  Future<ImportPreview> previewImport(String text) =>
      ref.read(entryRepositoryProvider).previewImport(text);

  Future<ImportResult> applyImport(
    ImportPreview preview, {
    ConflictPolicy policy = ConflictPolicy.preserve,
  }) => _applications.putIfAbsent(preview, () async {
    // 이미 확인한 작업의 커밋과 이벤트까지 controller 수명을 유지한다.
    final retain = ref.keepAlive();
    try {
      final result = await ref
          .read(entryRepositoryProvider)
          .applyImport(preview, policy: policy);
      if (ref.mounted && result.changedCount > 0) {
        ref.read(journalChangesProvider.notifier).markChanged();
        await ref.read(todayControllerProvider.notifier).refresh();
      }
      return result;
    } catch (_) {
      unawaited(_applications.remove(preview));
      rethrow;
    } finally {
      retain.close();
    }
  });

  /// Deletes all entries. Returns false on failure.
  Future<bool> deleteAllData() async {
    final retain = ref.keepAlive();
    try {
      return await _deleteAllData();
    } finally {
      retain.close();
    }
  }

  Future<bool> _deleteAllData() async {
    final entryRepo = ref.read(entryRepositoryProvider);
    final photoService = ref.read(photoServiceProvider);
    late final List<String> photoPaths;
    try {
      // 삭제 전에 모든 사진 파일 경로를 확보한다.
      try {
        photoPaths = await entryRepo.getAllPhotoPaths();
      } on CorruptDraft {
        // Unknown draft references preserve files; explicit whole-delete can still clear rows.
        photoPaths = const [];
        developer.log(
          'Photo cleanup skipped for unreadable draft',
          name: 'SettingsController',
        );
      }
      await entryRepo.deleteAllEntries();
    } catch (_) {
      return false;
    }

    if (ref.mounted) {
      try {
        await ref.read(todayControllerProvider.notifier).resetAfterDelete();
      } catch (e, stack) {
        developer.log(
          'Post-delete UI refresh failed',
          error: e,
          stackTrace: stack,
        );
      }
    }
    // 삭제한 live 초안은 더 이상 정리 후보를 보호하지 않는다.
    for (final path in photoPaths) {
      await photoService.deleteUnreferencedPhoto(
        path,
        readReferences: entryRepo.getAllPhotoPaths,
        retainedPaths: ref.mounted ? _retainedTodayDraftPaths() : const [],
      );
    }

    if (ref.mounted) ref.read(journalChangesProvider.notifier).markChanged();
    return true;
  }

  Iterable<String> _retainedTodayDraftPaths() {
    final today = ref.read(todayControllerProvider).value;
    if (today == null ||
        today.epoch != ref.read(entryRepositoryProvider).journalEpoch ||
        (today.isCompleted && !today.isEditing))
      return const [];
    return [?today.photoPath, ?today.existingEntry?.photoPath];
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(
      SettingsController.new,
      isAutoDispose: true,
    );
