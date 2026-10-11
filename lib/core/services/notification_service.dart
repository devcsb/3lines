import 'package:flutter/foundation.dart' show kIsWeb;
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
  });

  final int hour;
  final int minute;
  final bool hasEntryToday;
  final int currentStreak;
}

abstract interface class ReminderScheduler {
  Future<bool> requestPermission();

  Future<void> replaceDailyAndStreak(ReminderContext context);

  Future<void> scheduleWeeklyRetrospective();

  Future<void> cancelAll();

  Future<void> migrateLegacyReminders();
}

final class NotificationService implements ReminderScheduler {
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
  static const streakReminderCount = 30;
  static const weeklyId = 300;
  static const legacyIds = <int>[0, 1, 2];

  final NotificationPlatform _platform;
  final DeviceTimeZoneResolver _timeZoneResolver;
  final tz.TZDateTime Function(tz.Location) _now;

  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> initialize() {
    if (kIsWeb || _initialized) return Future<void>.value();
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
    if (kIsWeb) return false;
    await initialize();
    return _platform.requestPermission();
  }

  @override
  Future<void> replaceDailyAndStreak(ReminderContext context) async {
    if (kIsWeb) return;
    await initialize();
    final current = _now(tz.local);
    await _cancelIds([...dailyIds, ..._streakIds(), weeklyId, ...legacyIds]);

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

    // 30일 단발 예약으로 오늘 건너뛰기를 보장하며 앱 진입/기록 변경 때 범위를 갱신한다.
    for (var index = 0; index < dailyIds.length; index++) {
      await _platform.schedule(
        ScheduledLocalNotification(
          id: dailyIds[index],
          title: '3Lines',
          body: '오늘 마음을 짧게 남겨볼까요?',
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
  }

  @override
  Future<void> scheduleWeeklyRetrospective() async {
    if (kIsWeb) return;
    // 이전 호출자와의 호환만 유지하며 opt-in 없는 회고 예약은 제거한다.
    await _cancelIds([weeklyId]);
  }

  @override
  Future<void> cancelAll() {
    if (kIsWeb) return Future<void>.value();
    return _cancelIds([...dailyIds, ..._streakIds(), weeklyId, ...legacyIds]);
  }

  @override
  Future<void> migrateLegacyReminders() {
    if (kIsWeb) return Future<void>.value();
    return cancelAll();
  }

  List<int> _streakIds() =>
      List<int>.generate(streakReminderCount, (index) => streakId + index);

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
}

const _dailyDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'daily_reminder',
    '매일 리마인더',
    channelDescription: '매일 저널 작성 리마인더',
  ),
  iOS: DarwinNotificationDetails(),
);

final notificationServiceProvider = Provider<ReminderScheduler>((ref) {
  final platform = ref.read(notificationPlatformProvider);
  final resolver = ref.read(deviceTimeZoneResolverProvider);
  return NotificationService(platform: platform, timeZoneResolver: resolver);
});
