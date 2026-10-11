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
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service_test.dart'
    show RecordingNotificationPlatform, FixedTimeZoneResolver;

final class RecordingReminderScheduler implements ReminderScheduler {
  bool permissionGranted = true;
  Object? permissionError;
  bool failCancelAll = false;
  bool failWeekly = false;
  final failReplaceOnCalls = <int>{};
  final calls = <String>[];
  final contexts = <ReminderContext>[];
  Completer<void>? replaceGate;

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    if (permissionError != null) throw permissionError!;
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
  Future<void> scheduleWeeklyRetrospective() async {
    calls.add('weekly');
    if (failWeekly) throw StateError('weekly failed');
  }

  @override
  Future<void> cancelAll() async {
    calls.add('cancelAll');
    if (failCancelAll) throw StateError('cancelAll failed');
  }

  @override
  Future<void> migrateLegacyReminders() async => calls.add('migrate');
}

final class FixedAppClock extends AppClock {
  const FixedAppClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

final class TrackingSettingsRepository extends SettingsRepository {
  TrackingSettingsRepository(super.db);

  int getReminderSettingsCalls = 0;

  @override
  Future<({bool enabled, int hour, int minute})> getReminderSettings() {
    getReminderSettingsCalls++;
    return super.getReminderSettings();
  }
}

final class FailingReminderSettingsRepository extends SettingsRepository {
  FailingReminderSettingsRepository(super.db);

  @override
  Future<void> setReminderTime(int hour, int minute) async {
    throw StateError('settings write failed');
  }
}

final class FailingTodayEntryRepository extends EntryRepository {
  FailingTodayEntryRepository(super.db);

  @override
  Future<DailyEntry?> getTodayEntry() async {
    throw StateError('today entry read failed');
  }
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

  test('권한 요청 예외 시 UI 실패로 닫고 예약과 DB 활성화를 하지 않는다', () async {
    scheduler.permissionError = StateError('permission failed');

    expect(await coordinator.setEnabled(true), isFalse);
    expect(scheduler.calls, ['permission']);
    expect((await settings.getReminderSettings()).enabled, isFalse);
  });

  test('권한 거부 시 저장된 설정을 조회하지 않는다', () async {
    final trackingSettings = TrackingSettingsRepository(db);
    coordinator = DefaultReminderCoordinator(
      settingsRepository: trackingSettings,
      entryRepository: entries,
      scheduler: scheduler,
    );
    scheduler.permissionGranted = false;

    expect(await coordinator.setEnabled(true), isFalse);
    expect(trackingSettings.getReminderSettingsCalls, 0);
    expect(scheduler.calls, ['permission']);
  });

  test('활성화는 권한과 일일 예약 뒤 저장하며 회고를 예약하지 않는다', () async {
    expect(await coordinator.setEnabled(true), isTrue);
    expect(scheduler.calls, ['permission', 'replace:21:0']);
    expect((await settings.getReminderSettings()).enabled, isTrue);
  });

  test('비활성화는 예약 취소 성공 뒤 DB를 저장한다', () async {
    await storeReminder(enabled: true);

    expect(await coordinator.setEnabled(false), isTrue);
    expect(scheduler.calls, ['cancelAll']);
    expect((await settings.getReminderSettings()).enabled, isFalse);
  });

  test('예약 취소 실패 시 DB를 유지하고 이전 계획을 복원한다', () async {
    await storeReminder(enabled: true, hour: 20, minute: 15);
    scheduler.failCancelAll = true;

    expect(await coordinator.setEnabled(false), isFalse);
    expect(scheduler.calls, ['cancelAll', 'replace:20:15']);
    expect((await settings.getReminderSettings()).enabled, isTrue);
  });

  test('활성화 중 일일 예약 실패 시 DB를 저장하지 않고 비활성 계획을 복원한다', () async {
    scheduler.failReplaceOnCalls.add(1);

    expect(await coordinator.setEnabled(true), isFalse);
    expect(scheduler.calls, ['permission', 'replace:21:0', 'cancelAll']);
    expect((await settings.getReminderSettings()).enabled, isFalse);
  });

  test('비활성 상태 시간 변경은 플랫폼 호출 없이 DB만 저장한다', () async {
    expect(await coordinator.setTime(8, 30), isTrue);
    expect(scheduler.calls, isEmpty);
    final stored = await settings.getReminderSettings();
    expect((stored.hour, stored.minute), (8, 30));
  });

  test('범위를 벗어난 시간은 DB와 플랫폼을 변경하지 않는다', () async {
    expect(await coordinator.setTime(24, 0), isFalse);
    expect(scheduler.calls, isEmpty);
    final stored = await settings.getReminderSettings();
    expect((stored.hour, stored.minute), (21, 0));
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
    expect(scheduler.calls, ['replace:8:30', 'replace:21:0']);
    final stored = await settings.getReminderSettings();
    expect((stored.hour, stored.minute), (21, 0));
  });

  test('비활성 launch는 일일 예약까지 정리하고 새 알림은 만들지 않는다', () async {
    await coordinator.reconcileOnLaunch();
    expect(scheduler.calls, ['migrate', 'cancelAll']);
  });

  test('활성 launch는 legacy 취소 후 전체 계획을 조정한다', () async {
    await storeReminder(enabled: true, hour: 20, minute: 15);
    await coordinator.reconcileOnLaunch();
    expect(scheduler.calls, ['migrate', 'replace:20:15']);
  });

  test('저널 변경은 일일 계획만 조정하고 회고를 예약하지 않는다', () async {
    await storeReminder(enabled: true);
    await coordinator.reconcileAfterJournalChange();
    expect(scheduler.calls, ['replace:21:0']);
  });

  test('비활성 저널 변경도 남아 있는 기존 예약을 정리한다', () async {
    await coordinator.reconcileAfterJournalChange();
    expect(scheduler.calls, ['cancelAll']);
  });

  test('오늘 기록이 있으면 알림 context에 완료 상태만 전달한다', () async {
    await storeReminder(enabled: true);
    await storeTodayEntry(answer1: '친구의 안부');
    await coordinator.reconcileAfterJournalChange();
    expect(scheduler.contexts.single.hasEntryToday, isTrue);
  });

  test('오늘 기록 삭제 뒤 미완료 상태 context를 전달한다', () async {
    await storeReminder(enabled: true);
    await storeTodayEntry();
    await entries.deleteEntry('2026-08-06');
    await coordinator.reconcileAfterJournalChange();
    expect(scheduler.contexts.single.hasEntryToday, isFalse);
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

  test('선행 queue 작업 실패 후에도 다음 작업은 계속 실행된다', () async {
    await storeReminder(enabled: true);
    scheduler.failReplaceOnCalls.add(1);

    final failed = coordinator.setTime(8, 10);
    final succeeding = coordinator.setTime(9, 20);

    expect(await failed, isFalse);
    expect(await succeeding, isTrue);
    expect(scheduler.calls, ['replace:8:10', 'replace:21:0', 'replace:9:20']);
    final stored = await settings.getReminderSettings();
    expect((stored.hour, stored.minute), (9, 20));
  });

  group('실제 일일 scheduler와 플랫폼 경계', () {
    late RecordingNotificationPlatform platform;

    setUp(() {
      tz_data.initializeTimeZones();
      final seoul = tz.getLocation('Asia/Seoul');
      platform = RecordingNotificationPlatform();
      entries = EntryRepository(
        db,
        clock: FixedAppClock(DateTime(2026, 8, 9, 12)),
      );
      coordinator = DefaultReminderCoordinator(
        settingsRepository: settings,
        entryRepository: entries,
        scheduler: NotificationService(
          platform: platform,
          timeZoneResolver: const FixedTimeZoneResolver('Asia/Seoul'),
          now: (_) => tz.TZDateTime(seoul, 2026, 8, 9, 12),
        ),
      );
    });

    void expectDailyPlan({
      required int firstDay,
      required int hour,
      int minute = 0,
    }) {
      final notifications = platform.pending.values.toList();
      expect(notifications, hasLength(30));
      expect(
        notifications.map((item) => item.id),
        List<int>.generate(30, (i) => 100 + i),
      );
      expect(
        notifications.first.scheduledDate,
        tz.TZDateTime(tz.local, 2026, 8, firstDay, hour, minute),
      );
      expect(
        notifications.last.scheduledDate,
        tz.TZDateTime(tz.local, 2026, 8, firstDay + 29, hour, minute),
      );
      expect(
        notifications.every((item) => item.matchDateTimeComponents == null),
        isTrue,
      );
      expect(
        notifications.every((item) => item.body == '오늘 마음을 짧게 남겨볼까요?'),
        isTrue,
      );
      expect(
        notifications
            .map(
              (item) =>
                  '${item.scheduledDate.year}-${item.scheduledDate.month}-${item.scheduledDate.day}',
            )
            .toSet(),
        hasLength(30),
      );
    }

    test('일요일 launch와 시간 변경과 저장 뒤에도 날짜별 예약 한 건만 남는다', () async {
      await storeReminder(enabled: true, hour: 20);
      await coordinator.reconcileOnLaunch();
      expectDailyPlan(firstDay: 9, hour: 20);
      expect(platform.cancelled, containsAll([0, 1, 2, 200, 229, 300]));

      expect(await coordinator.setTime(20, 15), isTrue);
      expectDailyPlan(firstDay: 9, hour: 20, minute: 15);
      await entries.saveEntry(
        DailyEntry(
          date: '2026-08-09',
          emotion: 4,
          prompt1: '감사',
          answer1: '친구',
          prompt2: '수용',
          answer2: '',
          prompt3: '의도',
          answer3: '',
        ),
      );
      await coordinator.reconcileAfterJournalChange();
      expectDailyPlan(firstDay: 10, hour: 20, minute: 15);

      expect(await coordinator.setEnabled(false), isTrue);
      expect(platform.pending, isEmpty);
      expect(await coordinator.setEnabled(true), isTrue);
      expectDailyPlan(firstDay: 10, hour: 20, minute: 15);
    });

    test('권한 거부는 플랫폼 예약과 저장을 바꾸지 않는다', () async {
      platform.permissionGranted = false;
      expect(await coordinator.setEnabled(true), isFalse);
      expect(platform.pending, isEmpty);
      expect(platform.cancelled, isEmpty);
      expect((await settings.getReminderSettings()).enabled, isFalse);
    });

    test('활성 launch의 기록 조회 실패에도 기존 일일 예약은 유지한다', () async {
      await storeReminder(enabled: true);
      await coordinator.reconcileOnLaunch();
      platform.cancelled.clear();
      coordinator = DefaultReminderCoordinator(
        settingsRepository: settings,
        entryRepository: FailingTodayEntryRepository(db),
        scheduler: NotificationService(
          platform: platform,
          timeZoneResolver: const FixedTimeZoneResolver('Asia/Seoul'),
          now: (_) => tz.TZDateTime(tz.local, 2026, 8, 9, 12),
        ),
      );
      await expectLater(coordinator.reconcileOnLaunch(), throwsStateError);
      expectDailyPlan(firstDay: 9, hour: 21);
      expect(platform.cancelled, containsAll([0, 1, 2, 200, 229, 300]));
      expect(platform.cancelled.where((id) => id >= 100 && id <= 129), isEmpty);
    });

    test('활성 launch의 플랫폼 초기화 실패에도 기존 일일 예약은 유지한다', () async {
      await storeReminder(enabled: true);
      await coordinator.reconcileOnLaunch();
      platform.cancelled.clear();
      platform.initializeError = StateError('initialize failed');
      coordinator = DefaultReminderCoordinator(
        settingsRepository: settings,
        entryRepository: entries,
        scheduler: NotificationService(
          platform: platform,
          timeZoneResolver: const FixedTimeZoneResolver('Asia/Seoul'),
          now: (_) => tz.TZDateTime(tz.local, 2026, 8, 9, 12),
        ),
      );
      await expectLater(coordinator.reconcileOnLaunch(), throwsStateError);
      expectDailyPlan(firstDay: 9, hour: 21);
      expect(platform.cancelled, containsAll([0, 1, 2, 200, 229, 300]));
      expect(platform.cancelled.where((id) => id >= 100 && id <= 129), isEmpty);
    });

    test('비활성 launch는 남아 있는 기존 일일 예약도 제거한다', () async {
      await storeReminder(enabled: true);
      await coordinator.reconcileOnLaunch();
      expectDailyPlan(firstDay: 9, hour: 21);
      await storeReminder(enabled: false);
      await coordinator.reconcileOnLaunch();
      expect(platform.pending, isEmpty);
    });

    test('DB 시간 저장 실패는 이전 시각 단일 일일 계획을 복원한다', () async {
      await storeReminder(enabled: true);
      coordinator = DefaultReminderCoordinator(
        settingsRepository: FailingReminderSettingsRepository(db),
        entryRepository: entries,
        scheduler: NotificationService(
          platform: platform,
          timeZoneResolver: const FixedTimeZoneResolver('Asia/Seoul'),
          now: (_) => tz.TZDateTime(tz.local, 2026, 8, 9, 12),
        ),
      );
      expect(await coordinator.setTime(20, 15), isFalse);
      expectDailyPlan(firstDay: 9, hour: 21);
      final stored = await settings.getReminderSettings();
      expect((stored.hour, stored.minute), (21, 0));
    });
  });
}
