import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
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

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Schedules a daily reminder notification. Returns true on success.
  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
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
        0,
        '3Lines',
        '오늘의 3줄을 기록할 시간이에요',
        scheduledDate,
        const NotificationDetails(
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
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
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

  Future<void> cancelReminder() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(0);
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
