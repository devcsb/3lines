import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'notification_service.dart';

abstract interface class ReminderCoordinator {
  Future<bool> setEnabled(bool enabled);

  Future<bool> setTime(int hour, int minute);

  Future<void> reconcileOnLaunch();

  Future<void> reconcileAfterJournalChange();
}

final class DefaultReminderCoordinator implements ReminderCoordinator {
  DefaultReminderCoordinator({
    required SettingsRepository settingsRepository,
    required EntryRepository entryRepository,
    required ReminderScheduler scheduler,
  }) : _settingsRepository = settingsRepository,
       _entryRepository = entryRepository,
       _scheduler = scheduler;

  final SettingsRepository _settingsRepository;
  final EntryRepository _entryRepository;
  final ReminderScheduler _scheduler;

  Future<void> _tail = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  Future<bool> setEnabled(bool enabled) {
    return _serialize(() => _setEnabled(enabled));
  }

  Future<bool> _setEnabled(bool enabled) async {
    if (enabled && !await _scheduler.requestPermission()) return false;

    final stored = await _settingsRepository.getReminderSettings();
    final storedContext = await _context(
      hour: stored.hour,
      minute: stored.minute,
    );

    return _applyWithCompensation(
      apply: () async {
        if (enabled) {
          await _scheduler.replaceDailyAndStreak(storedContext);
          await _scheduler.scheduleWeeklyRetrospective();
        } else {
          await _scheduler.cancelAll();
        }
        await _settingsRepository.setReminderEnabled(enabled);
      },
      compensate: () => _restore(stored, storedContext),
    );
  }

  @override
  Future<bool> setTime(int hour, int minute) {
    return _serialize(() => _setTime(hour, minute));
  }

  Future<bool> _setTime(int hour, int minute) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return false;

    final stored = await _settingsRepository.getReminderSettings();
    if (!stored.enabled) {
      try {
        await _settingsRepository.setReminderTime(hour, minute);
        return true;
      } catch (error, stackTrace) {
        developer.log(
          'Failed to store reminder time',
          error: error,
          stackTrace: stackTrace,
        );
        return false;
      }
    }

    final storedContext = await _context(
      hour: stored.hour,
      minute: stored.minute,
    );
    final nextContext = await _context(hour: hour, minute: minute);
    return _applyWithCompensation(
      apply: () async {
        await _scheduler.replaceDailyAndStreak(nextContext);
        await _settingsRepository.setReminderTime(hour, minute);
      },
      compensate: () => _restore(stored, storedContext),
    );
  }

  @override
  Future<void> reconcileOnLaunch() {
    return _serialize(() async {
      final stored = await _settingsRepository.getReminderSettings();
      await _scheduler.migrateLegacyReminders();
      if (!stored.enabled) return;

      final context = await _context(hour: stored.hour, minute: stored.minute);
      await _scheduler.replaceDailyAndStreak(context);
      await _scheduler.scheduleWeeklyRetrospective();
    });
  }

  @override
  Future<void> reconcileAfterJournalChange() {
    return _serialize(() async {
      final stored = await _settingsRepository.getReminderSettings();
      if (!stored.enabled) return;

      final context = await _context(hour: stored.hour, minute: stored.minute);
      await _scheduler.replaceDailyAndStreak(context);
    });
  }

  Future<ReminderContext> _context({int? hour, int? minute}) async {
    final settings = await _settingsRepository.getReminderSettings();
    final entry = await _entryRepository.getTodayEntry();
    final streak = await _entryRepository.getCurrentStreak();
    return ReminderContext(
      hour: hour ?? settings.hour,
      minute: minute ?? settings.minute,
      hasEntryToday: entry != null,
      currentStreak: streak,
      gratitudeAnswer: entry?.answer1,
    );
  }

  Future<void> _restore(
    ({bool enabled, int hour, int minute}) stored,
    ReminderContext storedContext,
  ) async {
    if (stored.enabled) {
      await _scheduler.replaceDailyAndStreak(storedContext);
      await _scheduler.scheduleWeeklyRetrospective();
    } else {
      await _scheduler.cancelAll();
    }
  }

  Future<bool> _applyWithCompensation({
    required Future<void> Function() apply,
    required Future<void> Function() compensate,
  }) async {
    try {
      await apply();
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to apply reminder plan',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        await compensate();
      } catch (restoreError, restoreStack) {
        developer.log(
          'Failed to restore reminder plan',
          error: restoreError,
          stackTrace: restoreStack,
        );
      }
      return false;
    }
  }
}

final reminderCoordinatorProvider = Provider<ReminderCoordinator>((ref) {
  return DefaultReminderCoordinator(
    settingsRepository: ref.watch(settingsRepositoryProvider),
    entryRepository: ref.watch(entryRepositoryProvider),
    scheduler: ref.watch(notificationServiceProvider),
  );
});
