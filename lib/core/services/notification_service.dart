import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const _dailyReminderId = 0;
  static const _streakAtRiskId = 1;
  static const _weeklyRetrospectiveId = 2;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Schedules a daily reminder notification. Returns true on success.
  /// [body] overrides the default message — pass yesterday's gratitude for
  /// a personalized pull effect.
  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    String? body,
  }) async {
    if (kIsWeb) return false;
    if (!_initialized) await initialize();
    if (!_initialized) return false;
    try {
      await cancelReminder();

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the scheduled time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: _dailyReminderId,
        title: '3Lines',
        body: body ?? '오늘의 3줄을 기록할 시간이에요',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            '매일 리마인더',
            channelDescription: '매일 저널 작성 리마인더',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e, stack) {
      developer.log('Failed to schedule reminder', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Schedules a daily reminder only if today's entry doesn't exist yet.
  Future<bool> scheduleSmartDailyReminder({
    required int hour,
    required int minute,
    required Future<bool> Function() entryExistsToday,
  }) async {
    if (await entryExistsToday()) {
      await cancelReminder();
      return true;
    }
    return scheduleDailyReminder(hour: hour, minute: minute);
  }

  /// Schedules a streak-at-risk notification 1 hour before the regular
  /// reminder. Only meaningful when the user has an active streak and
  /// hasn't written today yet.
  Future<bool> scheduleStreakAtRiskReminder({
    required int reminderHour,
    required int reminderMinute,
  }) async {
    if (kIsWeb) return false;
    if (!_initialized) await initialize();
    if (!_initialized) return false;
    try {
      await _plugin.cancel(id: _streakAtRiskId);

      // Calculate 1 hour before the regular reminder
      final atRiskMinute = reminderMinute;
      var atRiskHour = reminderHour - 1;
      if (atRiskHour < 0) atRiskHour = 23;

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        atRiskHour,
        atRiskMinute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: _streakAtRiskId,
        title: '3Lines',
        body: '스트릭이 위험해요! 오늘의 기록을 잊지 마세요 🔥',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_at_risk',
            '스트릭 위험 알림',
            channelDescription: '미기록 시 스트릭 유지를 위한 사전 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e, stack) {
      developer.log('Failed to schedule streak-at-risk reminder',
          error: e, stackTrace: stack);
      return false;
    }
  }

  /// Cancels the streak-at-risk notification.
  Future<void> cancelStreakAtRiskReminder() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: _streakAtRiskId);
    } catch (e, stack) {
      developer.log('Failed to cancel streak-at-risk reminder',
          error: e, stackTrace: stack);
    }
  }

  /// Schedules a weekly retrospective notification every Sunday at 20:00.
  Future<bool> scheduleWeeklyRetrospectiveReminder() async {
    if (kIsWeb) return false;
    if (!_initialized) await initialize();
    if (!_initialized) return false;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, 20, 0,
      );
      // Advance to the next Sunday (ISO weekday 7)
      final daysUntilSunday = (DateTime.sunday - scheduled.weekday + 7) % 7;
      scheduled = scheduled.add(Duration(days: daysUntilSunday));
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 7));
      }

      await _plugin.zonedSchedule(
        id: _weeklyRetrospectiveId,
        title: '3Lines 주간 회고',
        body: '이번 주를 돌아볼 시간이에요. 7일간의 감정 흐름을 확인해보세요.',
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly_retrospective',
            '주간 회고 알림',
            channelDescription: '매주 일요일 저녁 주간 회고 알림',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      return true;
    } catch (e, stack) {
      developer.log('Failed to schedule weekly retrospective reminder',
          error: e, stackTrace: stack);
      return false;
    }
  }

  Future<void> cancelWeeklyRetrospectiveReminder() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: _weeklyRetrospectiveId);
    } catch (e, stack) {
      developer.log('Failed to cancel weekly retrospective reminder',
          error: e, stackTrace: stack);
    }
  }

  Future<void> cancelReminder() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: _dailyReminderId);
      await _plugin.cancel(id: _streakAtRiskId);
      await _plugin.cancel(id: _weeklyRetrospectiveId);
    } catch (e, stack) {
      developer.log('Failed to cancel reminder', error: e, stackTrace: stack);
    }
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (!_initialized) await initialize();
    if (!_initialized) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
