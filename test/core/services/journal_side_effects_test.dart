import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/journal_side_effects.dart';
import 'package:three_lines/core/services/reminder_coordinator.dart';
import 'package:three_lines/core/services/widget_sync_service.dart';

final class RecordingWidgetSync implements WidgetSync {
  int syncCount = 0;
  bool throwOnSync = false;

  @override
  Future<void> sync() async {
    syncCount++;
    if (throwOnSync) throw StateError('widget failed');
  }

  @override
  Future<Uri?> initiallyLaunchedUri() async => null;

  @override
  StreamSubscription<Uri?>? listenWidgetClicks(void Function(Uri uri) onUri) =>
      null;
}

final class RecordingReminderCoordinator implements ReminderCoordinator {
  int launchCount = 0;
  int journalCount = 0;
  bool throwOnLaunch = false;
  bool throwOnJournal = false;

  @override
  Future<void> reconcileOnLaunch() async {
    launchCount++;
    if (throwOnLaunch) throw StateError('launch failed');
  }

  @override
  Future<void> reconcileAfterJournalChange() async {
    journalCount++;
    if (throwOnJournal) throw StateError('journal failed');
  }

  @override
  Future<bool> setEnabled(bool enabled) async => true;

  @override
  Future<bool> setTime(int hour, int minute) async => true;
}

void main() {
  test('launch는 위젯 동기화와 알림 launch 조정을 한 번씩 호출한다', () async {
    final widget = RecordingWidgetSync();
    final reminders = RecordingReminderCoordinator();
    final effects = DefaultJournalSideEffects(
      widgetSync: widget,
      reminders: reminders,
    );

    await effects.onLaunch();

    expect(widget.syncCount, 1);
    expect(reminders.launchCount, 1);
  });

  test('저널 변경은 위젯 동기화와 알림 journal 조정을 한 번씩 호출한다', () async {
    final widget = RecordingWidgetSync();
    final reminders = RecordingReminderCoordinator();
    final effects = DefaultJournalSideEffects(
      widgetSync: widget,
      reminders: reminders,
    );

    await effects.onJournalChanged();

    expect(widget.syncCount, 1);
    expect(reminders.journalCount, 1);
  });

  test('위젯 실패가 알림 조정을 막지 않는다', () async {
    final widget = RecordingWidgetSync()..throwOnSync = true;
    final reminders = RecordingReminderCoordinator();
    final effects = DefaultJournalSideEffects(
      widgetSync: widget,
      reminders: reminders,
    );

    await effects.onJournalChanged();

    expect(widget.syncCount, 1);
    expect(reminders.journalCount, 1);
  });

  test('알림 실패가 위젯 동기화를 막지 않는다', () async {
    final widget = RecordingWidgetSync();
    final reminders = RecordingReminderCoordinator()..throwOnJournal = true;
    final effects = DefaultJournalSideEffects(
      widgetSync: widget,
      reminders: reminders,
    );

    await effects.onJournalChanged();

    expect(widget.syncCount, 1);
    expect(reminders.journalCount, 1);
  });
}
