import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'device_time_zone_resolver.dart';
import 'notification_platform.dart';

final class ReminderContext {
  const ReminderContext({
    required this.hour,
    required this.minute,
    required this.hasEntryToday,
    required this.currentStreak,
    this.gratitudeAnswer,
  });

  final int hour;
  final int minute;
  final bool hasEntryToday;
  final int currentStreak;
  final String? gratitudeAnswer;
}

abstract interface class ReminderScheduler {
  Future<bool> requestPermission();

  Future<void> replaceDailyAndStreak(ReminderContext context);

  Future<void> scheduleWeeklyRetrospective();

  Future<void> cancelAll();

  Future<void> migrateLegacyReminders();
}

class NotificationService implements ReminderScheduler {
  NotificationService({
    NotificationPlatform? platform,
    DeviceTimeZoneResolver? timeZoneResolver,
    tz.TZDateTime Function(tz.Location)? now,
  }) : _platform = platform ?? LiveNotificationPlatform(),
       _timeZoneResolver = timeZoneResolver ?? FlutterDeviceTimeZoneResolver(),
       _now = now ?? tz.TZDateTime.now;

  static const dailyIds = <int>[
    100,
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112,
    113,
    114,
    115,
    116,
    117,
    118,
    119,
    120,
    121,
    122,
    123,
    124,
    125,
    126,
    127,
    128,
    129,
  ];
  static const streakId = 200;
  static const weeklyId = 300;
  static const legacyIds = <int>[0, 1, 2];

  final NotificationPlatform _platform;
  final DeviceTimeZoneResolver _timeZoneResolver;
  final tz.TZDateTime Function(tz.Location) _now;

  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initFuture ??= _doInitialize().whenComplete(() {
      if (!_initialized) _initFuture = null;
    });
  }

  Future<void> _doInitialize() async {
    tz_data.initializeTimeZones();
    final identifier = await _timeZoneResolver.getIdentifier();
    final location = tz.getLocation(identifier);
    tz.setLocalLocation(location);
    await _platform.initialize();
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    return _platform.requestPermission();
  }

  @override
  Future<void> replaceDailyAndStreak(ReminderContext context) async {
    await initialize();
    final current = _now(tz.local);
    await _cancelIds([...dailyIds, streakId]);

    var firstOffset = context.hasEntryToday ? 1 : 0;
    final todayAtTime = _dailyDate(
      now: current,
      dayOffset: 0,
      hour: context.hour,
      minute: context.minute,
    );
    if (!context.hasEntryToday && !todayAtTime.isAfter(current)) {
      firstOffset = 1;
    }

    final answer = context.gratitudeAnswer?.trim() ?? '';
    for (var index = 0; index < dailyIds.length; index++) {
      final personalized =
          index == 0 && context.hasEntryToday && answer.isNotEmpty;
      await _platform.schedule(
        ScheduledLocalNotification(
          id: dailyIds[index],
          title: '3Lines',
          body: personalized
              ? '어제의 감사: "${_truncate(answer, 30)}"'
              : '오늘의 3줄을 기록할 시간이에요',
          scheduledDate: _dailyDate(
            now: current,
            dayOffset: firstOffset + index,
            hour: context.hour,
            minute: context.minute,
          ),
          notificationDetails: _dailyDetails,
        ),
      );
    }

    if (context.currentStreak > 0) {
      var targetDaily = _dailyDate(
        now: current,
        dayOffset: firstOffset,
        hour: context.hour,
        minute: context.minute,
      );
      var riskDate = targetDaily.subtract(const Duration(hours: 1));
      if (!riskDate.isAfter(current)) {
        targetDaily = _dailyDate(
          now: current,
          dayOffset: firstOffset + 1,
          hour: context.hour,
          minute: context.minute,
        );
        riskDate = targetDaily.subtract(const Duration(hours: 1));
      }
      await _platform.schedule(
        ScheduledLocalNotification(
          id: streakId,
          title: '3Lines',
          body: '스트릭이 위험해요! 오늘의 기록을 잊지 마세요 🔥',
          scheduledDate: riskDate,
          notificationDetails: _streakDetails,
        ),
      );
    }
  }

  @override
  Future<void> scheduleWeeklyRetrospective() async {
    await initialize();
    final current = _now(tz.local);
    var nextSundayAt20 = tz.TZDateTime(
      tz.local,
      current.year,
      current.month,
      current.day + (DateTime.sunday - current.weekday + 7) % 7,
      20,
    );
    if (!nextSundayAt20.isAfter(current)) {
      nextSundayAt20 = tz.TZDateTime(
        tz.local,
        nextSundayAt20.year,
        nextSundayAt20.month,
        nextSundayAt20.day + 7,
        20,
      );
    }
    await _cancelIds([weeklyId]);
    await _platform.schedule(
      ScheduledLocalNotification(
        id: weeklyId,
        title: '3Lines 주간 회고',
        body: '이번 주를 돌아볼 시간이에요. 7일간의 감정 흐름을 확인해보세요.',
        scheduledDate: nextSundayAt20,
        notificationDetails: _weeklyDetails,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      ),
    );
  }

  @override
  Future<void> cancelAll() =>
      _cancelIds([...dailyIds, streakId, weeklyId, ...legacyIds]);

  @override
  Future<void> migrateLegacyReminders() => _cancelIds(legacyIds);

  Future<void> _cancelIds(Iterable<int> ids) async {
    Object? firstError;
    StackTrace? firstStack;
    for (final id in ids) {
      try {
        await _platform.cancel(id);
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }

  tz.TZDateTime _dailyDate({
    required tz.TZDateTime now,
    required int dayOffset,
    required int hour,
    required int minute,
  }) {
    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + dayOffset,
      hour,
      minute,
    );
  }

  String _truncate(String value, int maxCharacters) {
    if (value.length <= maxCharacters) return value;
    return '${value.substring(0, maxCharacters)}…';
  }

  // Compatibility API; removed when existing callers migrate to ReminderScheduler.
  @Deprecated('Use replaceDailyAndStreak')
  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    String? body,
  }) async {
    await initialize();
    final current = _now(tz.local);
    await _cancelIds([dailyIds.first]);
    await _platform.schedule(
      ScheduledLocalNotification(
        id: dailyIds.first,
        title: '3Lines',
        body: body ?? '오늘의 3줄을 기록할 시간이에요',
        scheduledDate: _dailyDate(
          now: current,
          dayOffset: 1,
          hour: hour,
          minute: minute,
        ),
        notificationDetails: _dailyDetails,
      ),
    );
    return true;
  }

  @Deprecated('Use replaceDailyAndStreak')
  Future<bool> scheduleSmartDailyReminder({
    required int hour,
    required int minute,
    required Future<bool> Function() entryExistsToday,
  }) async {
    final exists = await entryExistsToday();
    if (exists) {
      await _cancelIds([dailyIds.first, streakId]);
      return true;
    }
    return scheduleDailyReminder(hour: hour, minute: minute);
  }

  @Deprecated('Use replaceDailyAndStreak')
  Future<bool> scheduleStreakAtRiskReminder({
    required int reminderHour,
    required int reminderMinute,
  }) async {
    await initialize();
    final current = _now(tz.local);
    await _cancelIds([streakId]);
    var riskDate = _dailyDate(
      now: current,
      dayOffset: 0,
      hour: reminderHour,
      minute: reminderMinute,
    ).subtract(const Duration(hours: 1));
    if (!riskDate.isAfter(current)) {
      riskDate = _dailyDate(
        now: current,
        dayOffset: 1,
        hour: reminderHour,
        minute: reminderMinute,
      ).subtract(const Duration(hours: 1));
    }
    await _platform.schedule(
      ScheduledLocalNotification(
        id: streakId,
        title: '3Lines',
        body: '스트릭이 위험해요! 오늘의 기록을 잊지 마세요 🔥',
        scheduledDate: riskDate,
        notificationDetails: _streakDetails,
      ),
    );
    return true;
  }

  @Deprecated('Use cancelAll')
  Future<void> cancelStreakAtRiskReminder() => _cancelIds([streakId]);

  @Deprecated('Use scheduleWeeklyRetrospective')
  Future<bool> scheduleWeeklyRetrospectiveReminder() async {
    await scheduleWeeklyRetrospective();
    return true;
  }

  @Deprecated('Use cancelAll')
  Future<void> cancelWeeklyRetrospectiveReminder() => _cancelIds([weeklyId]);

  @Deprecated('Use cancelAll')
  Future<void> cancelReminder() => cancelAll();
}

const _dailyDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'daily_reminder',
    '매일 리마인더',
    channelDescription: '매일 저널 작성 리마인더',
  ),
  iOS: DarwinNotificationDetails(),
);

const _streakDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'streak_at_risk',
    '스트릭 위험 알림',
    channelDescription: '미기록 시 스트릭 유지를 위한 사전 알림',
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(),
);

const _weeklyDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'weekly_retrospective',
    '주간 회고 알림',
    channelDescription: '매주 일요일 저녁 주간 회고 알림',
  ),
  iOS: DarwinNotificationDetails(),
);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final platform = ref.read(notificationPlatformProvider);
  final resolver = ref.read(deviceTimeZoneResolverProvider);
  return NotificationService(platform: platform, timeZoneResolver: resolver);
});
