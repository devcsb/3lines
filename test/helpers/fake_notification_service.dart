import 'package:three_lines/core/services/notification_service.dart';

/// NotificationService fake that records calls without scheduling real
/// system notifications.
class FakeNotificationService extends NotificationService {
  bool permissionGranted = true;
  bool scheduleResult = true;

  int scheduledCount = 0;
  int cancelledCount = 0;
  String? lastScheduledBody;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    String? body,
  }) async {
    scheduledCount++;
    lastScheduledBody = body;
    return scheduleResult;
  }

  @override
  Future<bool> scheduleSmartDailyReminder({
    required int hour,
    required int minute,
    required Future<bool> Function() entryExistsToday,
  }) async {
    scheduledCount++;
    return scheduleResult;
  }

  @override
  Future<bool> scheduleStreakAtRiskReminder({
    required int reminderHour,
    required int reminderMinute,
  }) async => scheduleResult;

  @override
  Future<void> cancelStreakAtRiskReminder() async {}

  @override
  Future<bool> scheduleWeeklyRetrospectiveReminder() async => scheduleResult;

  @override
  Future<void> cancelWeeklyRetrospectiveReminder() async {}

  @override
  Future<void> cancelReminder() async {
    cancelledCount++;
  }
}
