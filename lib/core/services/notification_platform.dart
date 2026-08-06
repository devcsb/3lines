import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

final class ScheduledLocalNotification {
  const ScheduledLocalNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.notificationDetails,
    this.matchDateTimeComponents,
  });

  final int id;
  final String title;
  final String body;
  final tz.TZDateTime scheduledDate;
  final NotificationDetails notificationDetails;
  final DateTimeComponents? matchDateTimeComponents;
}

abstract interface class NotificationPlatform {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> schedule(ScheduledLocalNotification notification);
  Future<void> cancel(int id);
}

InitializationSettings notificationInitializationSettings() {
  const darwin = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  return const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: darwin,
    macOS: darwin,
  );
}

final class LiveNotificationPlatform implements NotificationPlatform {
  LiveNotificationPlatform({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    await _plugin.initialize(settings: notificationInitializationSettings());
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }

    return true;
  }

  @override
  Future<void> schedule(ScheduledLocalNotification notification) async {
    await _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      scheduledDate: notification.scheduledDate,
      notificationDetails: notification.notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: notification.matchDateTimeComponents,
    );
  }

  @override
  Future<void> cancel(int id) {
    return _plugin.cancel(id: id);
  }
}

final Provider<NotificationPlatform> notificationPlatformProvider =
    Provider<NotificationPlatform>((ref) {
      return LiveNotificationPlatform();
    });
