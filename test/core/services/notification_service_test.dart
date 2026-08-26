import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/device_time_zone_resolver.dart';
import 'package:three_lines/core/services/notification_platform.dart';
import 'package:three_lines/core/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final class RecordingNotificationPlatform implements NotificationPlatform {
  final scheduled = <ScheduledLocalNotification>[];
  final cancelled = <int>[];
  var initializeCount = 0;
  var permissionCount = 0;
  var permissionGranted = true;
  int? failOnScheduleCall;
  Object? initializeError;
  final cancelFailures = <int>{};

  @override
  Future<void> initialize() async {
    initializeCount++;
    if (initializeError != null) throw initializeError!;
  }

  @override
  Future<bool> requestPermission() async {
    permissionCount++;
    return permissionGranted;
  }

  @override
  Future<void> schedule(ScheduledLocalNotification notification) async {
    if (scheduled.length + 1 == failOnScheduleCall) {
      throw StateError('schedule failed');
    }
    scheduled.add(notification);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    if (cancelFailures.contains(id)) throw StateError('cancel failed: $id');
  }
}

final class FixedTimeZoneResolver implements DeviceTimeZoneResolver {
  const FixedTimeZoneResolver(this.identifier);

  final String identifier;

  @override
  Future<String> getIdentifier() async => identifier;
}

void main() {
  late RecordingNotificationPlatform platform;
  late tz.TZDateTime fixedNow;
  late NotificationService service;

  setUp(() {
    tz.initializeTimeZones();
    final seoul = tz.getLocation('Asia/Seoul');
    fixedNow = tz.TZDateTime(seoul, 2026, 8, 6, 19, 30);
    platform = RecordingNotificationPlatform();
    service = NotificationService(
      platform: platform,
      timeZoneResolver: const FixedTimeZoneResolver('Asia/Seoul'),
      now: (_) => fixedNow,
    );
  });

  test('initialize는 권한을 요청하지 않고 Asia/Seoul을 local로 설정한다', () async {
    await service.initialize();
    expect(platform.initializeCount, 1);
    expect(platform.permissionCount, 0);
    expect(tz.local.name, 'Asia/Seoul');
  });

  test('requestPermission만 플랫폼 권한을 한 번 요청한다', () async {
    expect(await service.requestPermission(), isTrue);
    expect(platform.initializeCount, 1);
    expect(platform.permissionCount, 1);
  });

  test('알 수 없는 시간대는 UTC 예약 없이 실패한다', () async {
    final invalid = NotificationService(
      platform: platform,
      timeZoneResolver: const FixedTimeZoneResolver('Mars/Olympus'),
      now: (_) => fixedNow,
    );
    await expectLater(
      invalid.replaceDailyAndStreak(
        const ReminderContext(
          hour: 21,
          minute: 0,
          hasEntryToday: false,
          currentStreak: 0,
        ),
      ),
      throwsA(isA<tz.LocationNotFoundException>()),
    );
    expect(platform.scheduled, isEmpty);
  });

  test('미작성이고 시각 전이면 오늘부터 30개 단발 일일 알림을 만든다', () async {
    await service.replaceDailyAndStreak(
      const ReminderContext(
        hour: 21,
        minute: 0,
        hasEntryToday: false,
        currentStreak: 0,
      ),
    );
    final daily = platform.scheduled
        .where((item) => item.id >= 100 && item.id <= 129)
        .toList();
    expect(daily, hasLength(30));
    expect(daily.first.id, 100);
    expect(daily.last.id, 129);
    expect(daily.first.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 6, 21));
    expect(daily.last.scheduledDate, tz.TZDateTime(tz.local, 2026, 9, 4, 21));
    expect(daily.every((item) => item.matchDateTimeComponents == null), isTrue);
  });

  test('미작성이고 시각 후면 내일부터 30개 단발 일일 알림을 만든다', () async {
    await service.replaceDailyAndStreak(
      const ReminderContext(
        hour: 18,
        minute: 0,
        hasEntryToday: false,
        currentStreak: 0,
      ),
    );
    final daily = platform.scheduled
        .where((item) => item.id >= 100 && item.id <= 129)
        .toList();
    expect(daily.first.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 7, 18));
    expect(daily.last.scheduledDate, tz.TZDateTime(tz.local, 2026, 9, 5, 18));
  });

  test('작성 완료면 내일부터 시작하고 첫 알림만 감사 문구를 쓴다', () async {
    await service.replaceDailyAndStreak(
      const ReminderContext(
        hour: 21,
        minute: 0,
        hasEntryToday: true,
        currentStreak: 7,
        gratitudeAnswer: '저녁의 작은 산책',
      ),
    );
    final daily = platform.scheduled
        .where((item) => item.id >= 100 && item.id <= 129)
        .toList();
    expect(daily.first.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 7, 21));
    expect(daily.first.body, '어제의 감사: "저녁의 작은 산책"');
    expect(
      daily.skip(1).every((item) => item.body == '오늘의 3줄을 기록할 시간이에요'),
      isTrue,
    );
    final risks = platform.scheduled
        .where((item) => item.id >= 200 && item.id <= 229)
        .toList();
    expect(risks, hasLength(30));
    expect(risks.first.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 7, 20));
    expect(risks.last.scheduledDate, tz.TZDateTime(tz.local, 2026, 9, 5, 20));
  });

  test('활성 스트릭은 앱을 열지 않아도 30일치 위험 알림을 만든다', () async {
    await service.replaceDailyAndStreak(
      const ReminderContext(
        hour: 21,
        minute: 0,
        hasEntryToday: false,
        currentStreak: 3,
      ),
    );
    final risks = platform.scheduled
        .where((item) => item.id >= 200 && item.id <= 229)
        .toList();
    expect(risks, hasLength(30));
    expect(risks.first.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 6, 20));
    expect(risks.last.scheduledDate, tz.TZDateTime(tz.local, 2026, 9, 4, 20));
    expect(risks.every((item) => item.matchDateTimeComponents == null), isTrue);
  });

  test('스트릭이 없으면 위험 ID만 취소한다', () async {
    await service.replaceDailyAndStreak(
      const ReminderContext(
        hour: 21,
        minute: 0,
        hasEntryToday: false,
        currentStreak: 0,
      ),
    );
    expect(platform.cancelled, containsAll(List<int>.generate(30, (i) => 200 + i)));
    expect(
      platform.scheduled.where((item) => item.id >= 200 && item.id <= 229),
      isEmpty,
    );
  });

  test('일일 교체는 주간 ID를 취소하지 않는다', () async {
    await service.replaceDailyAndStreak(
      const ReminderContext(
        hour: 21,
        minute: 0,
        hasEntryToday: false,
        currentStreak: 0,
      ),
    );
    expect(platform.cancelled, isNot(contains(300)));
  });

  test('주간 회고는 일요일 20시에 요일 시간 반복으로 예약한다', () async {
    await service.scheduleWeeklyRetrospective();
    final weekly = platform.scheduled.single;
    expect(weekly.id, 300);
    expect(weekly.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 9, 20));
    expect(weekly.matchDateTimeComponents, DateTimeComponents.dayOfWeekAndTime);
    expect(platform.cancelled, [300]);
  });

  test('전체 취소는 신규 관리 ID와 기존 0 1 2 ID를 모두 취소한다', () async {
    await service.cancelAll();
    expect(platform.cancelled.toSet(), {
      ...NotificationService.dailyIds,
      ...List<int>.generate(30, (i) => 200 + i),
      300,
      0,
      1,
      2,
    });
  });

  test('초기화 실패 후 다음 호출은 플랫폼 초기화를 재시도한다', () async {
    platform.initializeError = StateError('initialize failed');
    await expectLater(service.initialize(), throwsStateError);
    platform.initializeError = null;
    await service.initialize();
    expect(platform.initializeCount, 2);
  });

  test('전체 취소는 모든 ID를 시도한 뒤 첫 오류를 전파한다', () async {
    platform.cancelFailures.add(102);
    await expectLater(service.cancelAll(), throwsStateError);
    expect(platform.cancelled, containsAll(NotificationService.dailyIds));
    expect(platform.cancelled, containsAll([200, 300, 0, 1, 2]));
  });

  test('legacy migration은 기존 ID만 취소한다', () async {
    await service.migrateLegacyReminders();
    expect(platform.cancelled, [0, 1, 2]);
  });

  test('DST 전환에서도 일일 예약은 달력 날짜를 30일 보존한다', () async {
    final newYork = tz.getLocation('America/New_York');
    final dstService = NotificationService(
      platform: platform,
      timeZoneResolver: const FixedTimeZoneResolver('America/New_York'),
      now: (_) => tz.TZDateTime(newYork, 2026, 3, 7, 19, 30),
    );
    await dstService.replaceDailyAndStreak(
      const ReminderContext(
        hour: 21,
        minute: 0,
        hasEntryToday: false,
        currentStreak: 0,
      ),
    );
    final daily = platform.scheduled
        .where((item) => item.id >= 100 && item.id <= 129)
        .toList();
    expect(daily.first.scheduledDate, tz.TZDateTime(tz.local, 2026, 3, 7, 21));
    expect(daily.last.scheduledDate, tz.TZDateTime(tz.local, 2026, 4, 5, 21));
  });
}
