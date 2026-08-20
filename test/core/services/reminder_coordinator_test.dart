import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/notification_service.dart';
import 'package:three_lines/core/services/reminder_coordinator.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';

final class RecordingReminderScheduler implements ReminderScheduler {
  bool permissionGranted = true;
  final failReplaceOnCalls = <int>{};
  final calls = <String>[];
  final contexts = <ReminderContext>[];
  Completer<void>? replaceGate;

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return permissionGranted;
  }

  @override
  Future<void> replaceDailyAndStreak(ReminderContext context) async {
    calls.add('replace:${context.hour}:${context.minute}');
    contexts.add(context);
    await replaceGate?.future;
    if (failReplaceOnCalls.contains(contexts.length)) {
      throw StateError('replace failed');
    }
  }

  @override
  Future<void> scheduleWeeklyRetrospective() async => calls.add('weekly');

  @override
  Future<void> cancelAll() async => calls.add('cancelAll');

  @override
  Future<void> migrateLegacyReminders() async => calls.add('migrate');
}

final class FixedAppClock extends AppClock {
  const FixedAppClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  late EntryRepository entries;
  late RecordingReminderScheduler scheduler;
  late DefaultReminderCoordinator coordinator;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = FixedAppClock(DateTime(2026, 8, 6, 12));
    settings = SettingsRepository(db);
    entries = EntryRepository(db, clock: clock);
    scheduler = RecordingReminderScheduler();
    coordinator = DefaultReminderCoordinator(
      settingsRepository: settings,
      entryRepository: entries,
      scheduler: scheduler,
    );
  });

  tearDown(() => db.close());

  Future<void> storeReminder({
    required bool enabled,
    int hour = 21,
    int minute = 0,
  }) async {
    await settings.setReminderEnabled(enabled);
    await settings.setReminderTime(hour, minute);
  }

  Future<void> storeTodayEntry({String answer1 = '따뜻한 커피'}) {
    return entries.saveEntry(
      DailyEntry(
        date: '2026-08-06',
        emotion: 4,
        prompt1: '감사',
        answer1: answer1,
        prompt2: '수용',
        answer2: '',
        prompt3: '의도',
        answer3: '',
      ),
    );
  }

  test('권한 거부 시 예약과 DB 활성화를 하지 않는다', () async {
    scheduler.permissionGranted = false;
    expect(await coordinator.setEnabled(true), isFalse);
    expect(scheduler.calls, ['permission']);
    expect((await settings.getReminderSettings()).enabled, isFalse);
  });

  test('활성화는 권한 예약 주간 저장 순서로 완료된다', () async {
    expect(await coordinator.setEnabled(true), isTrue);
    expect(scheduler.calls, ['permission', 'replace:21:0', 'weekly']);
    expect((await settings.getReminderSettings()).enabled, isTrue);
  });

  test('비활성 상태 시간 변경은 플랫폼 호출 없이 DB만 저장한다', () async {
    expect(await coordinator.setTime(8, 30), isTrue);
    expect(scheduler.calls, isEmpty);
    final stored = await settings.getReminderSettings();
    expect((stored.hour, stored.minute), (8, 30));
  });

  test('활성 상태 시간 변경은 새 계획 성공 뒤 DB를 저장한다', () async {
    await storeReminder(enabled: true);
    expect(await coordinator.setTime(8, 30), isTrue);
    expect(scheduler.calls, ['replace:8:30']);
    final stored = await settings.getReminderSettings();
    expect((stored.hour, stored.minute), (8, 30));
  });

  test('새 계획 실패 시 DB를 유지하고 저장된 이전 계획을 복원한다', () async {
    await storeReminder(enabled: true, hour: 21, minute: 0);
    scheduler.failReplaceOnCalls.add(1);
    expect(await coordinator.setTime(8, 30), isFalse);
    expect(scheduler.calls, ['replace:8:30', 'replace:21:0', 'weekly']);
    final stored = await settings.getReminderSettings();
    expect((stored.hour, stored.minute), (21, 0));
  });

  test('비활성 launch는 알림 플랫폼을 호출하지 않는다', () async {
    await coordinator.reconcileOnLaunch();
    expect(scheduler.calls, isEmpty);
  });

  test('활성 launch는 legacy 취소 후 전체 계획을 조정한다', () async {
    await storeReminder(enabled: true, hour: 20, minute: 15);
    await coordinator.reconcileOnLaunch();
    expect(scheduler.calls, ['migrate', 'replace:20:15', 'weekly']);
  });

  test('저널 변경은 일일과 스트릭만 조정하고 주간은 건드리지 않는다', () async {
    await storeReminder(enabled: true);
    await coordinator.reconcileAfterJournalChange();
    expect(scheduler.calls, ['replace:21:0']);
  });

  test('오늘 기록 answer1을 첫 다음 날 개인화 문구 context로 전달한다', () async {
    await storeReminder(enabled: true);
    await storeTodayEntry(answer1: '친구의 안부');
    await coordinator.reconcileAfterJournalChange();
    expect(scheduler.contexts.single.hasEntryToday, isTrue);
    expect(scheduler.contexts.single.gratitudeAnswer, '친구의 안부');
  });

  test('오늘 기록 삭제 뒤 hasEntryToday false context를 전달한다', () async {
    await storeReminder(enabled: true);
    await storeTodayEntry();
    await entries.deleteEntry('2026-08-06');
    await coordinator.reconcileAfterJournalChange();
    expect(scheduler.contexts.single.hasEntryToday, isFalse);
    expect(scheduler.contexts.single.gratitudeAnswer, isNull);
  });

  test('동시 시간 변경은 요청 순서대로 실행되어 마지막 값이 DB에 남는다', () async {
    await storeReminder(enabled: true);
    scheduler.replaceGate = Completer<void>();
    final first = coordinator.setTime(8, 10);
    final second = coordinator.setTime(9, 20);
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.contexts.map((item) => (item.hour, item.minute)), [
      (8, 10),
    ]);
    scheduler.replaceGate!.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    final stored = await settings.getReminderSettings();
    expect((stored.hour, stored.minute), (9, 20));
    expect(scheduler.contexts.map((item) => (item.hour, item.minute)), [
      (8, 10),
      (9, 20),
    ]);
  });
}
