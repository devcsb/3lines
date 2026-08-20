import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reminder_coordinator.dart';
import 'widget_sync_service.dart';

abstract interface class JournalSideEffects {
  Future<void> onLaunch();

  Future<void> onJournalChanged();
}

final class DefaultJournalSideEffects implements JournalSideEffects {
  const DefaultJournalSideEffects({
    required WidgetSync widgetSync,
    required ReminderCoordinator reminders,
  }) : _widgetSync = widgetSync,
       _reminders = reminders;

  final WidgetSync _widgetSync;
  final ReminderCoordinator _reminders;

  Future<void> _guard(String name, Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      developer.log(
        'Failed journal side effect: $name',
        name: 'journal_side_effects',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> onLaunch() async {
    await Future.wait<void>([
      _guard('widget launch sync', _widgetSync.sync),
      _guard('reminder launch reconcile', _reminders.reconcileOnLaunch),
    ]);
  }

  @override
  Future<void> onJournalChanged() async {
    await Future.wait<void>([
      _guard('widget journal sync', _widgetSync.sync),
      _guard(
        'reminder journal reconcile',
        _reminders.reconcileAfterJournalChange,
      ),
    ]);
  }
}

final journalSideEffectsProvider = Provider<JournalSideEffects>((ref) {
  return DefaultJournalSideEffects(
    widgetSync: ref.watch(widgetSyncServiceProvider),
    reminders: ref.watch(reminderCoordinatorProvider),
  );
});
