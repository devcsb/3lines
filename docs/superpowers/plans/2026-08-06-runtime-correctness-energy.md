# Runtime Correctness and Energy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기기 현지 시간에 정확히 동작하는 독립 알림 정책과 중복 없는 저비용 홈 위젯 동기화를 구축해 루프 1의 정확성·배터리·구조 종료 조건을 충족한다.

**Architecture:** 플랫폼 플러그인은 `NotificationPlatform`과 `DeviceTimeZoneResolver` 뒤로 격리하고, `NotificationService`는 ID·날짜 계산만, `ReminderCoordinator`는 저장 설정과 저널 상태에 따른 정책·직렬화·보상 복구만 담당한다. 위젯은 단일 `JournalSideEffects` 진입점에서 동기화하며 `WidgetSyncService`가 진행 중 요청을 병합하고 마지막 성공 스냅샷과 같은 플랫폼 쓰기를 생략한다.

**Tech Stack:** Flutter 3.44.6, Dart 3.12.2, Riverpod 3.x, Drift 2.34, `flutter_local_notifications` 22.0.1, `timezone` 0.11.1, `flutter_timezone` 5.1.0, `home_widget` 0.9.3, Kotlin/JVM 17, JUnit 4.13.2

## Global Constraints

- 앱의 모든 사용자 문구와 작업 보고는 한국어를 유지한다.
- Dart SDK 제약은 `^3.9.0`, Android JVM은 Java 17을 유지한다.
- `flutter_timezone`은 정확히 `^5.1.0`을 사용한다.
- 기기 IANA 시간대 확인 실패 시 UTC로 대체 예약하지 않고 실패를 상위 계층에 전달한다.
- 알림 권한은 사용자가 설정에서 알림을 켜는 명시적 행동 뒤에만 요청한다.
- 일일 알림과 스트릭 위험 알림은 향후 30일을 관리 ID 30개씩 예약한 단발 알림이며, 주간 회고만 요일·시간 반복 1개다.
- 예약 후 기기 시간대가 바뀌면 앱의 다음 실행·재개에서 IANA 식별자를 감지해 전체
  알림 계획을 현지 시각으로 다시 예약한다. 앱이 종료된 동안에는 OS가 기존 예약을
  자동 변환한다고 가정하지 않는다.
- 저널 DB 커밋은 알림 또는 위젯 후속 작업 실패로 되돌리지 않는다.
- 데이터베이스 스키마와 JSON 내보내기 형식은 변경하지 않는다.
- 네트워크, 분석 SDK, 원격 로깅, 새 사용자 추적을 추가하지 않는다.
- 루프 2의 전경 성능과 루프 3의 UI/UX·접근성은 이번 계획에 포함하지 않는다. 루프
  4의 릴리스 서명 작업은 별도 운영 작업이지만, 이 계획에서 추가한 Android
  `validateReleaseSigning` fail-closed 게이트와 CI keystore 주입 검증은 릴리스
  산출물 우회를 막기 위한 필수 범위로 포함한다.
- 각 Task는 실패 테스트 확인, 최소 구현, 대상 테스트 통과, 독립 커밋 순서로 수행한다.

---

## File Map

### 새 파일

- `lib/core/services/device_time_zone_resolver.dart`: 기기 IANA 시간대 식별자를 제공하는 플랫폼 경계와 Riverpod provider.
- `lib/core/services/notification_platform.dart`: 권한 없는 초기화, 명시적 권한 요청, 단일 예약·취소를 제공하는 플러그인 어댑터.
- `lib/core/services/reminder_coordinator.dart`: 설정 저장소를 진실의 원천으로 사용하는 알림 정책, 직렬화, 보상 복구.
- `lib/core/services/journal_side_effects.dart`: 앱 시작·저널 변경 뒤 위젯과 알림 후속 작업을 서로 독립적으로 실행하는 진입점.
- `test/core/services/notification_platform_test.dart`: Darwin 초기화가 권한을 암묵적으로 요청하지 않는지 검증.
- `test/core/services/notification_service_test.dart`: 실제 날짜·ID·본문·취소 경계를 Recording Fake로 검증.
- `test/core/services/reminder_coordinator_test.dart`: 권한, 저장 순서, 실패 보상, 직렬화, 저널 재조정 정책 검증.
- `test/core/services/journal_side_effects_test.dart`: 시작·저널 이벤트당 호출 수와 오류 격리 검증.
- `test/helpers/fake_widget_sync.dart`: 앱·라우팅 테스트가 HomeWidget 플랫폼 채널을 호출하지 않게 하는 interface Fake.
- `android/app/src/main/kotlin/com/threelines/three_lines/ThreeLinesWidgetState.kt`: 저장 날짜가 지난 위젯의 표시 상태를 순수 함수로 정규화.
- `android/app/src/test/kotlin/com/threelines/three_lines/ThreeLinesWidgetStateTest.kt`: 오늘 상태와 지난 날짜 상태를 JVM에서 검증.

### 수정 파일

- `pubspec.yaml`, `pubspec.lock`: `flutter_timezone` 의존성 고정.
- `lib/core/services/notification_service.dart`: 30일 단발 일일 예약, 단발 스트릭, 반복 주간 예약과 분리 ID 구현.
- `lib/core/services/widget_sync_service.dart`: 스냅샷 값 동등성, 진행 중 병합, 동일 상태 생략, 실패 재시도.
- `lib/app/bootstrap.dart`: 알림 인스턴스 선생성과 첫 프레임 뒤 무조건 초기화 제거.
- `lib/app/widget_bootstrap.dart`: 시작·저널 변경 후속 작업을 단일 진입점으로 연결하고 재개 시 위젯만 동기화.
- `lib/features/settings/settings_controller.dart`: 알림 플러그인 조작 대신 Coordinator 결과로만 UI state 갱신.
- `lib/features/today/today_controller.dart`: 설정 화면 상태 참조와 직접 위젯·알림 호출 제거.
- `lib/data/repositories/settings_repository.dart`: 알림 시·분 두 값을 하나의 Drift transaction으로 저장.
- `test/app/widget_bootstrap_test.dart`: 앱 시작·저널 이벤트·재개가 올바른 후속 작업만 호출하는지 검증.
- `test/features/settings/settings_controller_test.dart`: Coordinator Fake 기반 설정 UI 상태 검증.
- `test/features/today/today_controller_test.dart`: 저장 후 저널 이벤트가 정확히 한 번 발생하는지 검증.
- `test/features/timeline/timeline_controller_test.dart`: 개별 기록 삭제가 저널 이벤트를 정확히 한 번 발생시키는 기존 테스트를 강화.
- `test/integration/app_flow_test.dart`, `test/app/routing_flash_test.dart`: 새 서비스 경계 provider override로 전환.
- `android/app/src/main/kotlin/com/threelines/three_lines/ThreeLinesWidgetProvider.kt`: 현지 날짜와 저장 날짜를 비교해 stale 상태 정규화.
- `android/app/src/main/res/xml/three_lines_widget_info.xml`: 주기 갱신을 30분에서 24시간으로 축소.
- `android/app/build.gradle.kts`: JVM 위젯 상태 테스트용 JUnit 의존성 추가.

### 삭제 파일

- `test/helpers/fake_notification_service.dart`: 구체 구현 상속으로 실제 플랫폼 경계를 숨기는 Fake 제거.

---

### Task 1: 기기 시간대 및 저수준 알림 플랫폼 경계

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/core/services/device_time_zone_resolver.dart`
- Create: `lib/core/services/notification_platform.dart`
- Create: `test/core/services/notification_platform_test.dart`

**Interfaces:**
- Consumes: `FlutterTimezone.getLocalTimezone()`, `FlutterLocalNotificationsPlugin.initialize`, `zonedSchedule`, `cancel`.
- Produces: `DeviceTimeZoneResolver.getIdentifier() -> Future<String>`, `NotificationPlatform.initialize()`, `requestPermission()`, `schedule(ScheduledLocalNotification)`, `cancel(int)`, `notificationInitializationSettings()`.

- [ ] **Step 1: 권한 없는 Darwin 초기화 설정 테스트를 작성한다**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/notification_platform.dart';

void main() {
  test('플랫폼 초기화 설정은 Darwin 권한을 암묵적으로 요청하지 않는다', () {
    final settings = notificationInitializationSettings();
    final ios = settings.iOS!;
    final macOS = settings.macOS!;

    expect(ios.requestAlertPermission, isFalse);
    expect(ios.requestBadgePermission, isFalse);
    expect(ios.requestSoundPermission, isFalse);
    expect(macOS.requestAlertPermission, isFalse);
    expect(macOS.requestBadgePermission, isFalse);
    expect(macOS.requestSoundPermission, isFalse);
  });
}
```

- [ ] **Step 2: 새 경계가 없어 테스트가 실패하는지 확인한다**

Run: `flutter test test/core/services/notification_platform_test.dart`

Expected: `notification_platform.dart`를 찾을 수 없어 FAIL.

- [ ] **Step 3: 의존성과 시간대 resolver를 추가한다**

`pubspec.yaml` dependencies에 다음 한 줄을 추가하고 `flutter pub get`으로 lockfile을 갱신한다.

```yaml
  flutter_timezone: ^5.1.0
```

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

abstract interface class DeviceTimeZoneResolver {
  Future<String> getIdentifier();
}

final class FlutterDeviceTimeZoneResolver implements DeviceTimeZoneResolver {
  @override
  Future<String> getIdentifier() async {
    final info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  }
}

final deviceTimeZoneResolverProvider = Provider<DeviceTimeZoneResolver>((ref) {
  return FlutterDeviceTimeZoneResolver();
});
```

- [ ] **Step 4: 단일 작업만 노출하는 알림 플랫폼 어댑터를 구현한다**

`ScheduledLocalNotification`은 `id`, `title`, `body`, `scheduledDate`, `notificationDetails`, `matchDateTimeComponents`를 모두 보존한다. `notificationInitializationSettings()`의 Darwin 세 권한 플래그는 모두 `false`로 둔다.

```dart
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
```

`LiveNotificationPlatform.schedule`은 아래 인자를 그대로 전달하며 선행 취소를 하지 않는다.

```dart
await _plugin.zonedSchedule(
  id: notification.id,
  title: notification.title,
  body: notification.body,
  scheduledDate: notification.scheduledDate,
  notificationDetails: notification.notificationDetails,
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  matchDateTimeComponents: notification.matchDateTimeComponents,
);
```

Android는 `requestNotificationsPermission`, iOS는 alert·badge·sound가 `true`인 `requestPermissions`를 명시적 메서드 안에서만 호출한다. 지원 대상 이외 플랫폼은 `true`를 반환한다. `notificationPlatformProvider`의 정적 타입은 `Provider<NotificationPlatform>`으로 둔다.

- [ ] **Step 5: 포맷과 대상 테스트를 통과시킨다**

Run: `dart format lib/core/services/device_time_zone_resolver.dart lib/core/services/notification_platform.dart test/core/services/notification_platform_test.dart && flutter test test/core/services/notification_platform_test.dart`

Expected: 1 test PASS.

- [ ] **Step 6: 경계를 독립 커밋한다**

```bash
git add pubspec.yaml pubspec.lock lib/core/services/device_time_zone_resolver.dart lib/core/services/notification_platform.dart test/core/services/notification_platform_test.dart
git commit -m "refactor: isolate notification platform boundaries"
```

---

### Task 2: 독립 ID 기반 알림 날짜 계산과 예약

**Files:**
- Modify: `lib/core/services/notification_service.dart`
- Create: `test/core/services/notification_service_test.dart`

**Interfaces:**
- Consumes: `NotificationPlatform`, `DeviceTimeZoneResolver`, `timezone` location database.
- Produces: `ReminderContext`, `ReminderScheduler.requestPermission`, `replaceDailyAndStreak`, `scheduleWeeklyRetrospective`, `cancelAll`, `migrateLegacyReminders`.
- Compatibility boundary: until Task 5 rewires all existing call sites, retain `NotificationService` as a non-final class with a no-argument constructor and keep `notificationServiceProvider` statically typed as `Provider<NotificationService>`. Deprecated wrappers for the existing Controller/Fake methods may delegate to the new scheduler. Task 5 must remove the wrappers, delete the old Fake, and change the provider to `Provider<ReminderScheduler>`.

- [ ] **Step 1: Recording Fake와 날짜·ID 회귀 테스트를 작성한다**

테스트 Fake는 상속 대신 인터페이스를 구현하고 모든 예약과 취소를 기록한다.

```dart
final class RecordingNotificationPlatform implements NotificationPlatform {
  final scheduled = <ScheduledLocalNotification>[];
  final cancelled = <int>[];
  var initializeCount = 0;
  var permissionCount = 0;
  var permissionGranted = true;
  int? failOnScheduleCall;

  @override
  Future<void> initialize() async => initializeCount++;

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
  Future<void> cancel(int id) async => cancelled.add(id);
}

final class FixedTimeZoneResolver implements DeviceTimeZoneResolver {
  const FixedTimeZoneResolver(this.identifier);
  final String identifier;

  @override
  Future<String> getIdentifier() async => identifier;
}
```

고정 현재 시각 `tz.TZDateTime(tz.getLocation('Asia/Seoul'), 2026, 8, 6, 19, 30)`을 사용해 아래 테스트 본문을 작성한다. 공통 setup은 서비스 생성까지만 하고 각 테스트가 필요한 시점에 `initialize` 또는 정책 메서드를 호출한다.

```dart
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
    invalid.replaceDailyAndStreak(const ReminderContext(
      hour: 21,
      minute: 0,
      hasEntryToday: false,
      currentStreak: 0,
    )),
    throwsA(isA<tz.LocationNotFoundException>()),
  );
  expect(platform.scheduled, isEmpty);
});

test('미작성이고 시각 전이면 오늘부터 30개 단발 일일 알림을 만든다', () async {
  await service.replaceDailyAndStreak(const ReminderContext(
    hour: 21,
    minute: 0,
    hasEntryToday: false,
    currentStreak: 0,
  ));
  final daily = platform.scheduled.where((item) => item.id >= 100 && item.id <= 129).toList();
  expect(daily, hasLength(30));
  expect(daily.first.id, 100);
  expect(daily.last.id, 129);
  expect(daily.first.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 6, 21));
  expect(daily.last.scheduledDate, tz.TZDateTime(tz.local, 2026, 9, 4, 21));
  expect(daily.every((item) => item.matchDateTimeComponents == null), isTrue);
});

test('미작성이고 시각 후면 내일부터 30개 단발 일일 알림을 만든다', () async {
  await service.replaceDailyAndStreak(const ReminderContext(
    hour: 18,
    minute: 0,
    hasEntryToday: false,
    currentStreak: 0,
  ));
  final daily = platform.scheduled.where((item) => item.id >= 100 && item.id <= 129).toList();
  expect(daily.first.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 7, 18));
  expect(daily.last.scheduledDate, tz.TZDateTime(tz.local, 2026, 9, 5, 18));
});

test('작성 완료면 내일부터 시작하고 모든 알림은 중립 문구를 쓴다', () async {
  await service.replaceDailyAndStreak(const ReminderContext(
    hour: 21,
    minute: 0,
    hasEntryToday: true,
    currentStreak: 7,
  ));
  final daily = platform.scheduled.where((item) => item.id >= 100 && item.id <= 129).toList();
  expect(daily.first.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 7, 21));
  expect(daily.first.body, '오늘의 3줄을 기록할 시간이에요');
  expect(daily.skip(1).every((item) => item.body == '오늘의 3줄을 기록할 시간이에요'), isTrue);
  final risk = platform.scheduled.singleWhere((item) => item.id == 200);
  expect(risk.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 7, 20));
});

test('활성 스트릭은 한 시간 전부터 30일치 단발 위험 알림을 만든다', () async {
  await service.replaceDailyAndStreak(const ReminderContext(
    hour: 21,
    minute: 0,
    hasEntryToday: false,
    currentStreak: 3,
  ));
  final risks = platform.scheduled.where((item) => item.id >= 200 && item.id <= 229).toList();
  expect(risks, hasLength(30));
  expect(risks.first.scheduledDate, tz.TZDateTime(tz.local, 2026, 8, 6, 20));
  expect(risks.every((item) => item.matchDateTimeComponents == null), isTrue);
});

test('스트릭이 없으면 위험 ID만 취소한다', () async {
  await service.replaceDailyAndStreak(const ReminderContext(
    hour: 21,
    minute: 0,
    hasEntryToday: false,
    currentStreak: 0,
  ));
  expect(platform.cancelled, contains(200));
  expect(platform.scheduled.where((item) => item.id == 200), isEmpty);
});

test('일일 교체는 주간 ID를 취소하지 않는다', () async {
  await service.replaceDailyAndStreak(const ReminderContext(
    hour: 21,
    minute: 0,
    hasEntryToday: false,
    currentStreak: 0,
  ));
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
  expect(
    platform.cancelled.toSet(),
    {
      ...NotificationService.dailyIds,
      ...List<int>.generate(30, (i) => 200 + i),
      300,
      0,
      1,
      2,
    },
  );
});
```

첫 일일 ID는 100, 마지막은 129, 스트릭 ID 범위는 200~229, 주간 ID는 300으로 단언한다. 30개 일일·스트릭 요청의 `matchDateTimeComponents`는 전부 `null`, 주간 요청만 `DateTimeComponents.dayOfWeekAndTime`인지 단언한다.

- [ ] **Step 2: 기존 구현에서 새 인터페이스 테스트가 실패하는지 확인한다**

Run: `flutter test test/core/services/notification_service_test.dart`

Expected: `ReminderContext`와 `ReminderScheduler`가 정의되지 않아 FAIL.

- [ ] **Step 3: 서비스의 공용 정책 타입과 관리 ID를 구현한다**

```dart
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
  static const dailyIds = <int>[
    100, 101, 102, 103, 104, 105, 106, 107, 108, 109,
    110, 111, 112, 113, 114, 115, 116, 117, 118, 119,
    120, 121, 122, 123, 124, 125, 126, 127, 128, 129,
  ];
  static const streakId = 200;
  static const weeklyId = 300;
  static const legacyIds = <int>[0, 1, 2];
}
```

생성자는 `NotificationPlatform platform`, `DeviceTimeZoneResolver timeZoneResolver`, `tz.TZDateTime Function(tz.Location) now`를 주입받는다. `initialize()`는 하나의 in-flight Future를 공유하고 실패하면 Future 캐시를 비운다. 초기화 순서는 `tz.initializeTimeZones()` → resolver identifier → `tz.getLocation` → `tz.setLocalLocation` → `platform.initialize()`이며 권한 메서드는 호출하지 않는다.

- [ ] **Step 4: 30일 단발 일일 예약과 30일 단발 스트릭 위험 예약을 구현한다**

일일 날짜는 DST에서도 달력 날짜가 보존되도록 Duration 누적 대신 생성자 day offset을 사용한다.

```dart
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

var firstOffset = context.hasEntryToday ? 1 : 0;
final todayAtTime = _dailyDate(
  now: current,
  dayOffset: 0,
  hour: context.hour,
  minute: context.minute,
);
if (!context.hasEntryToday && !todayAtTime.isAfter(current)) firstOffset = 1;

for (var index = 0; index < dailyIds.length; index++) {
  await _platform.schedule(ScheduledLocalNotification(
    id: dailyIds[index],
    title: '3Lines',
    body: '오늘의 3줄을 기록할 시간이에요',
    scheduledDate: _dailyDate(
      now: current,
      dayOffset: firstOffset + index,
      hour: context.hour,
      minute: context.minute,
    ),
    notificationDetails: _dailyDetails,
  ));
}

```

`replaceDailyAndStreak`는 100~129와 200~229를 취소한 뒤 일일 30개를 만든다. `currentStreak > 0`이면 각 일일 알림 날짜의 정확히 한 시간 전을 200~229 단발 후보로 만들고, 현재 시각 이후인 후보만 예약한다. 따라서 오늘 작성 완료 뒤에도 다음 날부터 30일간의 위험 알림이 유지된다. 자정 이전 계산은 `tz.TZDateTime` 생성자의 전날/다음날 정규화를 사용한다. ID 300은 이 메서드에서 취소하거나 예약하지 않는다.

```dart
if (context.currentStreak > 0) {
  for (var index = 0; index < dailyIds.length; index++) {
    final targetDaily = _dailyDate(
      now: current,
      dayOffset: firstOffset + index,
      hour: context.hour,
      minute: context.minute,
    );
    final riskDate = targetDaily.subtract(const Duration(hours: 1));
    if (!riskDate.isAfter(current)) continue;
    await _platform.schedule(ScheduledLocalNotification(
      id: streakId + index,
      title: '3Lines',
      body: '스트릭이 위험해요! 오늘의 기록을 잊지 마세요 🔥',
      scheduledDate: riskDate,
      notificationDetails: _streakDetails,
    ));
  }
}
```

세 알림 상세 설정은 아래 상수로 정의한다.

```dart
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
```

- [ ] **Step 5: 주간 반복, 전체 취소, 기존 ID migration을 구현한다**

```dart
await _platform.schedule(ScheduledLocalNotification(
  id: weeklyId,
  title: '3Lines 주간 회고',
  body: '이번 주를 돌아볼 시간이에요. 7일간의 감정 흐름을 확인해보세요.',
  scheduledDate: nextSundayAt20,
  notificationDetails: _weeklyDetails,
  matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
));
```

`scheduleWeeklyRetrospective`는 ID 300만 취소·예약한다. `migrateLegacyReminders`는 0, 1, 2만 취소한다. `cancelAll`은 100~129, 200~229, 300, 0, 1, 2를 모두 취소하고 한 번이라도 플랫폼 취소가 실패하면 호출자에게 예외를 전달한다. Task 2 동안 provider의 정적 타입은 기존 호출부를 위한 `Provider<NotificationService>`로 유지하며, Task 5에서 `Provider<ReminderScheduler>`로 전환한다. 두 타입 모두 같은 `NotificationService` 인스턴스를 사용한다.

`nextSundayAt20`은 아래처럼 현지 달력으로 계산한다.

```dart
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
```

여러 ID 취소는 첫 오류에서 중단하지 않고 전부 시도한 뒤 첫 오류를 전달한다.

```dart
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
if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
```

- [ ] **Step 6: 알림 서비스 테스트와 분석을 통과시킨다**

Run: `dart format lib/core/services/notification_service.dart test/core/services/notification_service_test.dart && flutter test test/core/services/notification_platform_test.dart test/core/services/notification_service_test.dart && flutter analyze`

Expected: 두 테스트 파일 PASS, analyze 0 issues.

- [ ] **Step 7: 알림 날짜 정책을 독립 커밋한다**

```bash
git add lib/core/services/notification_service.dart test/core/services/notification_service_test.dart
git commit -m "fix: schedule reminders in the device timezone"
```

---

### Task 3: 저장소 기반 ReminderCoordinator와 실패 보상

**Files:**
- Modify: `lib/data/repositories/settings_repository.dart`
- Create: `lib/core/services/reminder_coordinator.dart`
- Create: `test/core/services/reminder_coordinator_test.dart`

**Interfaces:**
- Consumes: `SettingsRepository.getReminderSettings`, `setReminderEnabled`, `setReminderTime`, `EntryRepository.getTodayEntry`, `getCurrentStreak`, `ReminderScheduler`.
- Produces: `ReminderCoordinator.setEnabled(bool)`, `setTime(int, int)`, `reconcileOnLaunch()`, `reconcileAfterJournalChange()`.

- [ ] **Step 1: 권한·저장 순서·보상·직렬화 테스트를 작성한다**

in-memory `AppDatabase`, 고정 `AppClock`, 실제 repository와 아래 Fake scheduler를 사용한다.

```dart
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
```

아래 공통 setup과 테스트 본문을 작성한다. `FixedAppClock`은 `now()`가 생성자 값을 반환하는 `AppClock` 하위 클래스다.

```dart
final class FixedAppClock extends AppClock {
  const FixedAppClock(this.value);
  final DateTime value;

  @override
  DateTime now() => value;
}

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
  return entries.saveEntry(DailyEntry(
    date: '2026-08-06',
    emotion: 4,
    prompt1: '감사',
    answer1: answer1,
    prompt2: '수용',
    answer2: '',
    prompt3: '의도',
    answer3: '',
  ));
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
  expect(scheduler.contexts.map((item) => (item.hour, item.minute)), [(8, 10)]);
  scheduler.replaceGate!.complete();
  expect(await first, isTrue);
  expect(await second, isTrue);
  final stored = await settings.getReminderSettings();
  expect((stored.hour, stored.minute), (9, 20));
  expect(scheduler.contexts.map((item) => (item.hour, item.minute)), [(8, 10), (9, 20)]);
});
```

- [ ] **Step 2: Coordinator가 없어 테스트가 실패하는지 확인한다**

Run: `flutter test test/core/services/reminder_coordinator_test.dart`

Expected: `reminder_coordinator.dart`를 찾을 수 없어 FAIL.

- [ ] **Step 3: 정책 인터페이스와 저장소 context 조립을 구현한다**

먼저 두 시간 필드가 부분 저장되지 않도록 repository에 원자 메서드를 추가한다.

```dart
Future<void> setReminderEnabled(bool enabled) {
  return setSetting(SettingKeys.reminderEnabled, enabled.toString());
}

Future<void> setReminderTime(int hour, int minute) {
  return _db.transaction(() async {
    await setSetting(SettingKeys.reminderHour, hour.toString());
    await setSetting(SettingKeys.reminderMinute, minute.toString());
  });
}
```

```dart
abstract interface class ReminderCoordinator {
  Future<bool> setEnabled(bool enabled);
  Future<bool> setTime(int hour, int minute);
  Future<void> reconcileOnLaunch();
  Future<void> reconcileAfterJournalChange();
}

final class DefaultReminderCoordinator implements ReminderCoordinator {
  DefaultReminderCoordinator({
    required SettingsRepository settingsRepository,
    required EntryRepository entryRepository,
    required ReminderScheduler scheduler,
  }) : _settingsRepository = settingsRepository,
       _entryRepository = entryRepository,
       _scheduler = scheduler;

  final SettingsRepository _settingsRepository;
  final EntryRepository _entryRepository;
  final ReminderScheduler _scheduler;
}

Future<ReminderContext> _context({int? hour, int? minute}) async {
  final settings = await _settingsRepository.getReminderSettings();
  final entry = await _entryRepository.getTodayEntry();
  final streak = await _entryRepository.getCurrentStreak();
  return ReminderContext(
    hour: hour ?? settings.hour,
    minute: minute ?? settings.minute,
    hasEntryToday: entry != null,
    currentStreak: streak,
  );
}
```

`reminderCoordinatorProvider`는 `Provider<ReminderCoordinator>`이고 실제 repositories와 `notificationServiceProvider`를 `ReminderScheduler`로 주입한다. Task 2의 호환 provider가 concrete subtype이므로 Coordinator는 새 scheduler 메서드만 사용하며, Task 5에서 provider의 정적 타입을 interface로 바꾼다.

- [ ] **Step 4: 모든 변경을 하나의 직렬 queue에서 실행한다**

```dart
Future<void> _tail = Future<void>.value();

Future<T> _serialize<T>(Future<T> Function() operation) {
  final completer = Completer<T>();
  _tail = _tail.then((_) async {
    try {
      completer.complete(await operation());
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  });
  return completer.future;
}
```

모든 public 메서드는 `_serialize`를 통과한다. queue의 앞 작업이 실패해도 뒤 작업이 실행되도록 오류는 각 completer에 전달하고 `_tail` 자체는 정상 완료시킨다.

- [ ] **Step 5: 적용 후 저장과 저장된 계획 보상 복구를 구현한다**

`setEnabled(true)`는 권한 → 현재 context 교체 → 주간 예약 → `setReminderEnabled(true)` 순서다. `setEnabled(false)`는 전체 취소 → `setReminderEnabled(false)` 순서다. `setTime`은 0~23시, 0~59분만 허용하며 비활성 상태면 `setReminderTime`으로 DB만 저장하고, 활성 상태면 새 context 적용 성공 뒤 같은 원자 메서드로 hour와 minute를 저장한다.

```dart
Future<bool> _applyWithCompensation({
  required Future<void> Function() apply,
  required Future<void> Function() compensate,
}) async {
  try {
    await apply();
    return true;
  } catch (error, stack) {
    developer.log('Failed to apply reminder plan', error: error, stackTrace: stack);
    try {
      await compensate();
    } catch (restoreError, restoreStack) {
      developer.log(
        'Failed to restore reminder plan',
        error: restoreError,
        stackTrace: restoreStack,
      );
    }
    return false;
  }
}
```

보상은 작업 시작 전에 읽은 저장 설정으로 context를 다시 만들고, 이전에 활성 상태였으면 일일·스트릭과 주간을 다시 적용하며 비활성이었으면 `cancelAll`을 호출한다. DB는 새 계획이 전부 성공하기 전까지 수정하지 않는다.

`reconcileOnLaunch`는 저장 설정이 비활성이면 즉시 반환한다. 활성 상태면 legacy 0·1·2를 취소하고 일일·스트릭과 주간을 다시 적용한다. `reconcileAfterJournalChange`는 활성 상태에서만 최신 context로 `replaceDailyAndStreak`를 호출하며 주간 메서드는 호출하지 않는다.

- [ ] **Step 6: Coordinator 테스트를 통과시킨다**

Run: `dart format lib/data/repositories/settings_repository.dart lib/core/services/reminder_coordinator.dart test/core/services/reminder_coordinator_test.dart && flutter test test/core/services/reminder_coordinator_test.dart`

Expected: 18 tests PASS.

- [ ] **Step 7: 저장소 기반 정책을 독립 커밋한다**

```bash
git add lib/data/repositories/settings_repository.dart lib/core/services/reminder_coordinator.dart test/core/services/reminder_coordinator_test.dart
git commit -m "feat: coordinate reminder policy from persisted state"
```

---

### Task 4: 홈 위젯 동기화 병합과 동일 상태 생략

**Files:**
- Modify: `lib/core/services/widget_sync_service.dart`
- Modify: `test/core/services/widget_sync_service_test.dart`

**Interfaces:**
- Consumes: `EntryRepository`, `SettingsRepository`, `AppClock`, `HomeWidgetBridge`.
- Produces: `WidgetSync.sync()`, `initiallyLaunchedUri()`, `listenWidgetClicks()`, 값 동등성을 가진 `WidgetSnapshot`.

- [ ] **Step 1: 병합·dedupe·실패 재시도 테스트를 추가한다**

`RecordingHomeWidgetBridge`에 `saveCount`, `updateCount`, `activeUpdates`, `maxActiveUpdates`, `Completer<void>? updateGate`, `bool failNextUpdate`를 둔다. in-memory DB와 고정 날짜 clock을 사용하는 아래 setup 및 테스트 본문을 추가한다.

```dart
final class RecordingHomeWidgetBridge implements HomeWidgetBridge {
  int saveCount = 0;
  int updateCount = 0;
  int activeUpdates = 0;
  int maxActiveUpdates = 0;
  bool failNextUpdate = false;
  Completer<void>? updateGate;

  @override
  Future<void> setAppGroupId(String groupId) async {}

  @override
  Future<void> saveString(String key, String? value) async => saveCount++;

  @override
  Future<void> updateWidget({required String iOSName, required String androidName}) async {
    updateCount++;
    activeUpdates++;
    if (activeUpdates > maxActiveUpdates) {
      maxActiveUpdates = activeUpdates;
    }
    try {
      await updateGate?.future;
      if (failNextUpdate) {
        failNextUpdate = false;
        throw StateError('widget update failed');
      }
    } finally {
      activeUpdates--;
    }
  }

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() async => null;

  @override
  Stream<Uri?> get widgetClicked => const Stream<Uri?>.empty();
}

final class FixedWidgetClock extends AppClock {
  const FixedWidgetClock();

  @override
  DateTime now() => DateTime(2026, 8, 6, 12);
}

late AppDatabase db;
late EntryRepository entries;
late SettingsRepository settings;
late RecordingHomeWidgetBridge bridge;
late WidgetSyncService service;

setUp(() {
  db = AppDatabase.forTesting(NativeDatabase.memory());
  entries = EntryRepository(db, clock: const FixedWidgetClock());
  settings = SettingsRepository(db);
  bridge = RecordingHomeWidgetBridge();
  service = WidgetSyncService(
    entryRepository: entries,
    settingsRepository: settings,
    clock: const FixedWidgetClock(),
    bridge: bridge,
  );
});

tearDown(() => db.close());

WidgetSnapshot snapshot() => const WidgetSnapshot(
  date: '2026-08-06',
  streak: 1,
  isCompleted: true,
  prompt: '감사',
  emotion: 4,
  statusMessage: '오늘 기록 완료 · 평온',
  streakLabel: '1일',
);

Future<void> saveToday() => entries.saveEntry(DailyEntry(
  date: '2026-08-06',
  emotion: 4,
  prompt1: '감사',
  answer1: '산책',
  prompt2: '수용',
  answer2: '',
  prompt3: '의도',
  answer3: '',
));

test('동일한 WidgetSnapshot은 값이 같다', () {
  expect(snapshot(), snapshot());
  expect(snapshot().hashCode, snapshot().hashCode);
});

test('동기화 도중 여러 요청은 최대 한 번의 후속 실행으로 병합된다', () async {
  bridge.updateGate = Completer<void>();
  final first = service.sync();
  while (bridge.updateCount == 0) {
    await Future<void>.delayed(Duration.zero);
  }
  await saveToday();
  final second = service.sync();
  final third = service.sync();
  final fourth = service.sync();
  bridge.updateGate!.complete();
  await Future.wait([first, second, third, fourth]);
  expect(bridge.updateCount, 2);
  expect(bridge.maxActiveUpdates, 1);
});

test('동일한 성공 스냅샷은 두 번째 저장과 플랫폼 업데이트를 생략한다', () async {
  await service.sync();
  await service.sync();
  expect(bridge.saveCount, 7);
  expect(bridge.updateCount, 1);
});

test('DB 상태가 바뀌면 새 스냅샷을 저장하고 업데이트한다', () async {
  await service.sync();
  await saveToday();
  await service.sync();
  expect(bridge.saveCount, 14);
  expect(bridge.updateCount, 2);
});

test('플랫폼 업데이트 실패 뒤 같은 스냅샷을 다시 시도한다', () async {
  bridge.failNextUpdate = true;
  await service.sync();
  await service.sync();
  expect(bridge.saveCount, 14);
  expect(bridge.updateCount, 2);
});
```

첫 테스트는 모든 필드가 같은 두 인스턴스의 `==`와 `hashCode`가 같다고 단언한다. 병합 테스트는 첫 update gate가 닫힌 동안 `sync()`를 세 번 더 호출하고 gate 해제 뒤 `maxActiveUpdates == 1`, `updateCount == 2`를 단언한다. 동일 상태 테스트는 두 번째 호출 뒤 `saveCount == 7`, `updateCount == 1`을 단언한다.

- [ ] **Step 2: 기존 서비스에서 병합 테스트가 실패하는지 확인한다**

Run: `flutter test test/core/services/widget_sync_service_test.dart`

Expected: 동시 update가 중복 실행되거나 동일 snapshot이 다시 저장되어 FAIL.

- [ ] **Step 3: WidgetSnapshot 값 동등성과 WidgetSync 인터페이스를 구현한다**

```dart
abstract interface class WidgetSync {
  Future<void> sync();
  Future<Uri?> initiallyLaunchedUri();
  StreamSubscription<Uri?>? listenWidgetClicks(void Function(Uri uri) onUri);
}

@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is WidgetSnapshot &&
        date == other.date &&
        streak == other.streak &&
        isCompleted == other.isCompleted &&
        prompt == other.prompt &&
        emotion == other.emotion &&
        statusMessage == other.statusMessage &&
        streakLabel == other.streakLabel;

@override
int get hashCode => Object.hash(
  date, streak, isCompleted, prompt, emotion, statusMessage, streakLabel,
);
```

`WidgetSyncService implements WidgetSync`로 바꾸고 provider 정적 타입을 `Provider<WidgetSync>`로 바꾼다.

- [ ] **Step 4: 진행 중 요청을 병합하고 성공 snapshot만 캐시한다**

```dart
Future<void>? _syncFuture;
bool _syncRequested = false;
WidgetSnapshot? _lastSuccessfulSnapshot;

@override
Future<void> sync() {
  if (kIsWeb) return Future<void>.value();
  _syncRequested = true;
  return _syncFuture ??= _drainSyncRequests();
}

Future<void> _drainSyncRequests() async {
  try {
    while (_syncRequested) {
      _syncRequested = false;
      await _syncOnce();
    }
  } catch (error, stack) {
    developer.log(
      'Failed to sync home widget',
      name: 'widget_sync',
      error: error,
      stackTrace: stack,
    );
  } finally {
    _syncFuture = null;
    if (_syncRequested) {
      scheduleMicrotask(sync);
    }
  }
}

Future<void> _syncOnce() async {
  await ensureConfigured();
  final snapshot = await buildSnapshot();
  if (snapshot == _lastSuccessfulSnapshot) return;
  await _persist(snapshot);
  await _bridge.updateWidget(
    iOSName: WidgetSyncConfig.iOSWidgetName,
    androidName: WidgetSyncConfig.androidWidgetName,
  );
  _lastSuccessfulSnapshot = snapshot;
}
```

실패한 update 뒤에는 `_lastSuccessfulSnapshot`을 바꾸지 않는다. catch 이후 drain에서 실패 시점에 이미 들어온 요청이 있으면 while가 끊길 수 있으므로 `finally`에서 `_syncRequested`가 true일 때 microtask로 새 `sync()`를 시작해 요청을 잃지 않게 한다. 그 동작도 병합 테스트에서 gate 해제 후 확인한다.

- [ ] **Step 5: 위젯 서비스 테스트를 통과시킨다**

Run: `dart format lib/core/services/widget_sync_service.dart test/core/services/widget_sync_service_test.dart && flutter test test/core/services/widget_sync_service_test.dart`

Expected: 기존 순수 함수 테스트와 신규 5 tests 모두 PASS.

- [ ] **Step 6: 위젯 I/O 절감을 독립 커밋한다**

```bash
git add lib/core/services/widget_sync_service.dart test/core/services/widget_sync_service_test.dart
git commit -m "perf: coalesce and deduplicate widget sync"
```

---

### Task 5: 앱·Controller를 단일 저널 후속 작업 흐름에 연결

**Files:**
- Create: `lib/core/services/journal_side_effects.dart`
- Create: `test/core/services/journal_side_effects_test.dart`
- Modify: `lib/app/bootstrap.dart`
- Modify: `lib/app/widget_bootstrap.dart`
- Modify: `lib/features/settings/settings_controller.dart`
- Modify: `lib/features/today/today_controller.dart`
- Create: `test/app/widget_bootstrap_test.dart`
- Modify: `test/features/settings/settings_controller_test.dart`
- Modify: `test/features/today/today_controller_test.dart`
- Modify: `test/features/timeline/timeline_controller_test.dart`
- Modify: `test/integration/app_flow_test.dart`
- Modify: `test/app/routing_flash_test.dart`
- Create: `test/helpers/fake_widget_sync.dart`
- Delete: `test/helpers/fake_notification_service.dart`

**Interfaces:**
- Consumes: `WidgetSync`, `ReminderCoordinator`, `journalChangesProvider`.
- Produces: `JournalSideEffects.onLaunch()`, `onJournalChanged()`; SettingsController는 Coordinator 결과만 state에 반영.

- [ ] **Step 1: 후속 작업 호출 수와 오류 격리 테스트를 작성한다**

```dart
abstract interface class JournalSideEffects {
  Future<void> onLaunch();
  Future<void> onJournalChanged();
}
```

아래 Recording Fake와 테스트 본문으로 두 작업이 모두 시작되고 한쪽 오류가 다른 쪽을 막지 않는지 검증한다.

```dart
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
  StreamSubscription<Uri?>? listenWidgetClicks(void Function(Uri uri) onUri) => null;
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

test('launch는 위젯 동기화와 알림 launch 조정을 한 번씩 호출한다', () async {
  final widget = RecordingWidgetSync();
  final reminders = RecordingReminderCoordinator();
  final effects = DefaultJournalSideEffects(widgetSync: widget, reminders: reminders);
  await effects.onLaunch();
  expect(widget.syncCount, 1);
  expect(reminders.launchCount, 1);
});

test('저널 변경은 위젯 동기화와 알림 journal 조정을 한 번씩 호출한다', () async {
  final widget = RecordingWidgetSync();
  final reminders = RecordingReminderCoordinator();
  final effects = DefaultJournalSideEffects(widgetSync: widget, reminders: reminders);
  await effects.onJournalChanged();
  expect(widget.syncCount, 1);
  expect(reminders.journalCount, 1);
});

test('위젯 실패가 알림 조정을 막지 않는다', () async {
  final widget = RecordingWidgetSync()..throwOnSync = true;
  final reminders = RecordingReminderCoordinator();
  final effects = DefaultJournalSideEffects(widgetSync: widget, reminders: reminders);
  await effects.onJournalChanged();
  expect(widget.syncCount, 1);
  expect(reminders.journalCount, 1);
});

test('알림 실패가 위젯 동기화를 막지 않는다', () async {
  final widget = RecordingWidgetSync();
  final reminders = RecordingReminderCoordinator()..throwOnJournal = true;
  final effects = DefaultJournalSideEffects(widgetSync: widget, reminders: reminders);
  await effects.onJournalChanged();
  expect(widget.syncCount, 1);
  expect(reminders.journalCount, 1);
});
```

- [ ] **Step 2: 통합 경계가 없어 테스트가 실패하는지 확인한다**

Run: `flutter test test/core/services/journal_side_effects_test.dart`

Expected: `journal_side_effects.dart`를 찾을 수 없어 FAIL.

- [ ] **Step 3: 서로 독립적인 후속 작업 실행기를 구현한다**

```dart
final class DefaultJournalSideEffects implements JournalSideEffects {
  const DefaultJournalSideEffects({
    required WidgetSync widgetSync,
    required ReminderCoordinator reminders,
  }) : _widgetSync = widgetSync,
       _reminders = reminders;

  final WidgetSync _widgetSync;
  final ReminderCoordinator _reminders;

  Future<void> _guard(String name, Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stack) {
      developer.log(
        'Failed journal side effect: $name',
        name: 'journal_side_effects',
        error: error,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<void> onLaunch() async {
    await Future.wait<void>([
      _guard('widget launch sync', _widgetSync.sync),
      _guard('reminder launch reconcile', _reminders.reconcileOnLaunch),
    ]);
  }

  @override
  Future<void> onJournalChanged() async {
    await Future.wait<void>([
      _guard('widget journal sync', _widgetSync.sync),
      _guard('reminder journal reconcile', _reminders.reconcileAfterJournalChange),
    ]);
  }
}
```

provider는 Task 3과 Task 4의 interface provider를 읽어 `Provider<JournalSideEffects>`를 반환한다.

- [ ] **Step 4: Bootstrap과 앱 생명주기를 새 경계에 연결한다**

`lib/app/bootstrap.dart`에서 `NotificationService()` 선생성, provider override, `addPostFrameCallback(...initialize())`, 관련 import와 주석을 제거한다. 잠금·온보딩 seed와 사진 정리는 유지한다.

`WidgetBootstrap._bootstrap` 첫 단계는 아래처럼 바꾸고 deep link 기능은 기존 `widgetSyncServiceProvider`를 통해 유지한다.

```dart
await ref.read(journalSideEffectsProvider).onLaunch();
if (!mounted) return;
final widgetSync = ref.read(widgetSyncServiceProvider);
final initial = await widgetSync.initiallyLaunchedUri();
```

저널 listener는 `unawaited(ref.read(journalSideEffectsProvider).onJournalChanged())`만 호출한다.
`resumed`에서는 먼저 `DeviceTimeZoneResolver`로 이전 resume의 IANA 식별자와 비교한다.
변경이 없으면 `widgetSyncServiceProvider.sync()`와 pending emotion 적용만 수행해
30개 알림 재예약을 피한다. 시간대가 바뀌었으면 `JournalSideEffects.onLaunch()`를
호출해 Android/iOS의 일일·스트릭·주간 예약과 위젯을 함께 현지 시간으로 다시 맞춘다.
앱이 종료된 상태에서 시간대가 바뀐 경우에는 다음 앱 실행 시 `onLaunch()`가 재조정한다.

`widget_bootstrap_test.dart`에는 `RecordingJournalSideEffects`, initial URI가 `null`인
`RecordingWidgetSync`, 가변 식별자를 반환하는 `RecordingTimeZoneResolver`를 override해
아래 harness와 네 테스트를 작성한다.

```dart
final class RecordingWidgetSync implements WidgetSync {
  int syncCount = 0;

  @override
  Future<void> sync() async => syncCount++;

  @override
  Future<Uri?> initiallyLaunchedUri() async => null;

  @override
  StreamSubscription<Uri?>? listenWidgetClicks(void Function(Uri uri) onUri) => null;
}

final class RecordingJournalSideEffects implements JournalSideEffects {
  int launchCount = 0;
  int journalChangedCount = 0;

  @override
  Future<void> onLaunch() async => launchCount++;

  @override
  Future<void> onJournalChanged() async => journalChangedCount++;
}

late ProviderContainer container;
late RecordingJournalSideEffects sideEffects;
late RecordingWidgetSync widgetSync;

setUp(() {
  sideEffects = RecordingJournalSideEffects();
  widgetSync = RecordingWidgetSync();
  container = ProviderContainer(overrides: [
    journalSideEffectsProvider.overrideWithValue(sideEffects),
    widgetSyncServiceProvider.overrideWithValue(widgetSync),
  ]);
});

tearDown(() => container.dispose());

Future<void> pumpBootstrap(WidgetTester tester) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: WidgetBootstrap(child: SizedBox()),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

testWidgets('첫 프레임 뒤 onLaunch를 한 번 호출한다', (tester) async {
  await pumpBootstrap(tester);
  expect(sideEffects.launchCount, 1);
  expect(sideEffects.journalChangedCount, 0);
});

testWidgets('journalChanges 1회 증가가 onJournalChanged 1회로 이어진다', (tester) async {
  await pumpBootstrap(tester);
  container.read(journalChangesProvider.notifier).markChanged();
  await tester.pump();
  expect(sideEffects.journalChangedCount, 1);
});

testWidgets('resumed는 위젯만 동기화하고 알림 journal 조정을 호출하지 않는다', (tester) async {
  await pumpBootstrap(tester);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  expect(widgetSync.syncCount, 1);
  expect(sideEffects.journalChangedCount, 0);
});

testWidgets('resumed에서 timezone이 바뀌면 알림과 위젯을 함께 재조정한다', (tester) async {
  await pumpBootstrap(tester);
  timeZone.identifier = 'America/Los_Angeles';
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  await tester.pump();
  expect(sideEffects.launchCount, 2);
  expect(widgetSync.syncCount, 0);
});
```

각 테스트는 `ProviderScope` 아래 `WidgetBootstrap(child: SizedBox())`를 pump한다. 두 번째 테스트는 같은 `ProviderContainer`의 `journalChangesProvider.notifier.markChanged()`를 한 번 호출한 뒤 `journalChangedCount == 1`을 단언한다. 세 번째 테스트는 동일한 시간대의 `resumed` 뒤 `widgetSync.syncCount == 1`, `sideEffects.journalChangedCount == 0`을 단언하고, 네 번째 테스트는 식별자를 다른 IANA 시간대로 바꾼 `resumed` 뒤 `sideEffects.launchCount == 2`, `widgetSync.syncCount == 0`을 단언한다.

- [ ] **Step 5: SettingsController를 Coordinator 결과에 연결한다**

알림 서비스와 EntryRepository를 직접 조작하는 두 메서드를 아래 형태로 교체한다.

```dart
Future<bool> setReminderEnabled(bool enabled) async {
  final current = state.value;
  if (current == null) return false;
  final success = await ref.read(reminderCoordinatorProvider).setEnabled(enabled);
  if (!success) return false;
  state = AsyncData(current.copyWith(reminderEnabled: enabled));
  return true;
}

Future<bool> setReminderTime(int hour, int minute) async {
  final current = state.value;
  if (current == null) return false;
  final success = await ref.read(reminderCoordinatorProvider).setTime(hour, minute);
  if (!success) return false;
  state = AsyncData(
    current.copyWith(reminderHour: hour, reminderMinute: minute),
  );
  return true;
}
```

설정 테스트는 `FakeNotificationService` 대신 아래 Fake를 provider override한다.

```dart
final class FakeReminderCoordinator implements ReminderCoordinator {
  bool enabledResult = true;
  bool timeResult = true;
  final enabledCalls = <bool>[];
  final timeCalls = <(int, int)>[];

  @override
  Future<bool> setEnabled(bool enabled) async {
    enabledCalls.add(enabled);
    return enabledResult;
  }

  @override
  Future<bool> setTime(int hour, int minute) async {
    timeCalls.add((hour, minute));
    return timeResult;
  }

  @override
  Future<void> reconcileOnLaunch() async {}

  @override
  Future<void> reconcileAfterJournalChange() async {}
}
```

`reminderCoordinatorProvider.overrideWithValue(fakeReminders)`를 추가한다. 활성화 성공은 `enabledCalls == [true]`와 state `reminderEnabled == true`, 실패는 `enabledResult = false` 뒤 state·DB가 이전 값인지를 단언한다. 시간 변경 성공은 `timeCalls == [(8, 30)]`와 state 시·분 갱신, 실패는 `timeResult = false` 뒤 state 시·분 유지로 검증한다. DB 저장 책임은 Task 3 Coordinator 테스트에서 검증하므로 Controller Fake가 DB를 직접 수정하지 않는다.

- [ ] **Step 6: TodayController의 중복 후속 작업을 제거한다**

`save()`의 DB·사진·milestone·UI state 로직은 유지한다. 저장 뒤 `settingsControllerProvider.value`를 읽어 알림을 직접 예약하는 블록 전체와 `widgetSyncServiceProvider.sync()` 호출을 제거한다. 마지막에는 아래 한 줄만 남긴다.

```dart
ref.read(journalChangesProvider.notifier).markChanged();
return true;
```

`Timer` 때문에 `dart:async` import는 유지하고 notification, widget sync, settings controller import만 제거한다. Today 테스트는 저장 전후 `container.read(journalChangesProvider)`가 정확히 1 증가하며 widget/reminder provider를 직접 요구하지 않는다고 단언한다.

`settings_controller_test.dart`의 가져오기 성공과 전체 삭제 성공 테스트에도 이벤트 전후 값을 비교해 각각 정확히 1 증가한다고 단언한다. `timeline_controller_test.dart`는 in-memory DB에 하루 기록을 저장하고 `TimelineController.deleteEntry('2026-08-06')` 호출 뒤 해당 날짜 기록이 없어졌으며 이벤트가 정확히 1 증가했다고 단언한다. 이 세 경로와 Today 저장 테스트가 같은 `WidgetBootstrap` listener로 합류하므로 저장·가져오기·개별 삭제·전체 삭제의 정책 재조정을 모두 회귀 방지한다.

- [ ] **Step 7: 앱 테스트의 provider override를 새 인터페이스로 전환한다**

`app_flow_test.dart`와 `routing_flash_test.dart`에서 `notificationServiceProvider.overrideWithValue(FakeNotificationService())`를 제거하고, 플랫폼 채널을 건드리지 않는 아래 두 Fake를 override한다.

```dart
final class NoOpJournalSideEffects implements JournalSideEffects {
  @override
  Future<void> onLaunch() async {}

  @override
  Future<void> onJournalChanged() async {}
}
```

`test/helpers/fake_widget_sync.dart`에는 다음 구현을 둔다.

```dart
import 'dart:async';

import 'package:three_lines/core/services/widget_sync_service.dart';

final class FakeWidgetSync implements WidgetSync {
  int syncCount = 0;

  @override
  Future<void> sync() async => syncCount++;

  @override
  Future<Uri?> initiallyLaunchedUri() async => null;

  @override
  StreamSubscription<Uri?>? listenWidgetClicks(void Function(Uri uri) onUri) => null;
}
```

두 앱 테스트의 `ProviderScope` overrides에 `journalSideEffectsProvider.overrideWithValue(NoOpJournalSideEffects())`와 `widgetSyncServiceProvider.overrideWithValue(FakeWidgetSync())`를 모두 추가한다.

`test/helpers/fake_notification_service.dart` import와 파일을 삭제한다. `rg -n "FakeNotificationService|scheduleSmartDailyReminder|cancelReminder" lib test` 결과가 비어야 한다.

- [ ] **Step 8: 후속 작업 및 Controller 회귀 테스트를 통과시킨다**

Run: `dart format lib/core/services/journal_side_effects.dart lib/app/bootstrap.dart lib/app/widget_bootstrap.dart lib/features/settings/settings_controller.dart lib/features/today/today_controller.dart test/helpers/fake_widget_sync.dart test/app/widget_bootstrap_test.dart test/core/services/journal_side_effects_test.dart test/features/settings/settings_controller_test.dart test/features/timeline/timeline_controller_test.dart test/features/today/today_controller_test.dart test/integration/app_flow_test.dart test/app/routing_flash_test.dart && flutter test test/app/widget_bootstrap_test.dart test/core/services/journal_side_effects_test.dart test/features/settings/settings_controller_test.dart test/features/timeline/timeline_controller_test.dart test/features/today/today_controller_test.dart test/integration/app_flow_test.dart test/app/routing_flash_test.dart`

Expected: 모든 지정 테스트 PASS, 플랫폼 권한 팝업 호출 없음.

- [ ] **Step 9: 단일 후속 작업 흐름을 독립 커밋한다**

```bash
git add lib/app/bootstrap.dart lib/app/widget_bootstrap.dart lib/core/services/journal_side_effects.dart lib/features/settings/settings_controller.dart lib/features/today/today_controller.dart test/helpers/fake_widget_sync.dart test/app/widget_bootstrap_test.dart test/core/services/journal_side_effects_test.dart test/features/settings/settings_controller_test.dart test/features/timeline/timeline_controller_test.dart test/features/today/today_controller_test.dart test/integration/app_flow_test.dart test/app/routing_flash_test.dart test/helpers/fake_notification_service.dart
git commit -m "refactor: centralize journal side effects"
```

---

### Task 6: Android 위젯 24시간 주기와 stale 날짜 안전 표시

**Files:**
- Create: `android/app/src/main/kotlin/com/threelines/three_lines/ThreeLinesWidgetState.kt`
- Create: `android/app/src/test/kotlin/com/threelines/three_lines/ThreeLinesWidgetStateTest.kt`
- Modify: `android/app/src/main/kotlin/com/threelines/three_lines/ThreeLinesWidgetProvider.kt`
- Modify: `android/app/src/main/res/xml/three_lines_widget_info.xml`
- Modify: `android/app/build.gradle.kts`

**Interfaces:**
- Consumes: HomeWidget `SharedPreferences`, 기기 기본 시간대의 `yyyy-MM-dd` 날짜.
- Produces: `resolveThreeLinesWidgetState(...) -> ThreeLinesWidgetState` 순수 함수와 하루 한 번 이하 주기 갱신 설정.

- [ ] **Step 1: 오늘과 stale 상태 JVM 테스트를 작성한다**

`android/app/build.gradle.kts` dependencies에 다음을 추가한다.

```kotlin
testImplementation("junit:junit:4.13.2")
```

```kotlin
class ThreeLinesWidgetStateTest {
    @Test
    fun `오늘 저장값은 완료 상태와 감정을 유지한다`() {
        val state = resolveThreeLinesWidgetState(
            storedDate = "2026-08-06",
            today = "2026-08-06",
            streakLabel = "7일",
            statusMessage = "오늘 기록 완료 · 감사",
            prompt = "오늘 감사한 작은 것 하나는?",
            isCompleted = true,
            emotionRaw = "5",
        )
        assertTrue(state.isCompleted)
        assertEquals("5", state.emotionRaw)
        assertEquals("오늘 기록 완료 · 감사", state.statusMessage)
    }

    @Test
    fun `지난 날짜 저장값은 오늘 미작성 상태로 정규화한다`() {
        val state = resolveThreeLinesWidgetState(
            storedDate = "2026-08-05",
            today = "2026-08-06",
            streakLabel = "7일",
            statusMessage = "오늘 기록 완료 · 감사",
            prompt = "어제의 질문",
            isCompleted = true,
            emotionRaw = "5",
        )
        assertFalse(state.isCompleted)
        assertEquals("", state.emotionRaw)
        assertEquals("오늘 한 줄만 적어도 돼요", state.statusMessage)
        assertEquals("오늘 감사한 작은 것 하나는?", state.prompt)
        assertEquals("7일", state.streakLabel)
    }
}
```

- [ ] **Step 2: 순수 함수가 없어 JVM 테스트가 실패하는지 확인한다**

Run: `cd android && ./gradlew app:testDebugUnitTest --tests com.threelines.three_lines.ThreeLinesWidgetStateTest`

Expected: `resolveThreeLinesWidgetState` 미정의로 Kotlin compile FAIL.

- [ ] **Step 3: stale 상태 순수 함수를 구현한다**

```kotlin
package com.threelines.three_lines

internal data class ThreeLinesWidgetState(
    val streakLabel: String,
    val statusMessage: String,
    val prompt: String,
    val isCompleted: Boolean,
    val emotionRaw: String,
)

internal fun resolveThreeLinesWidgetState(
    storedDate: String?,
    today: String,
    streakLabel: String,
    statusMessage: String,
    prompt: String,
    isCompleted: Boolean,
    emotionRaw: String,
): ThreeLinesWidgetState {
    if (storedDate != today) {
        return ThreeLinesWidgetState(
            streakLabel = streakLabel,
            statusMessage = "오늘 한 줄만 적어도 돼요",
            prompt = "오늘 감사한 작은 것 하나는?",
            isCompleted = false,
            emotionRaw = "",
        )
    }
    return ThreeLinesWidgetState(
        streakLabel = streakLabel,
        statusMessage = statusMessage,
        prompt = prompt,
        isCompleted = isCompleted,
        emotionRaw = emotionRaw,
    )
}
```

- [ ] **Step 4: provider에서 현지 날짜로 상태를 정규화한다**

```kotlin
val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
val state = resolveThreeLinesWidgetState(
    storedDate = data.getString("date", null),
    today = today,
    streakLabel = data.getString("streak_label", null) ?: "시작해볼까요",
    statusMessage = data.getString("status_message", null)
        ?: "앱을 열어 오늘을 기록해보세요",
    prompt = data.getString("prompt", null) ?: "오늘 감사한 작은 것 하나는?",
    isCompleted = data.getString("is_completed", "false") == "true",
    emotionRaw = data.getString("emotion", "") ?: "",
)
```

기존 binding은 지역 변수 대신 `state.streakLabel`, `state.statusMessage`, `state.prompt`, `state.isCompleted`, `state.emotionRaw`를 사용한다. import에 `java.text.SimpleDateFormat`, `java.util.Date`, `java.util.Locale`을 추가한다.

XML은 다음 정확한 값으로 바꾼다.

```xml
android:updatePeriodMillis="86400000"
```

- [ ] **Step 5: Android 단위 테스트와 XML 값을 검증한다**

Run: `cd android && ./gradlew app:testDebugUnitTest --tests com.threelines.three_lines.ThreeLinesWidgetStateTest`

Expected: 2 tests PASS.

Run: `rg -n 'updatePeriodMillis="86400000"' android/app/src/main/res/xml/three_lines_widget_info.xml`

Expected: 정확히 1 match.

- [ ] **Step 6: Android 위젯 절전을 독립 커밋한다**

```bash
git add android/app/build.gradle.kts android/app/src/main/kotlin/com/threelines/three_lines/ThreeLinesWidgetProvider.kt android/app/src/main/kotlin/com/threelines/three_lines/ThreeLinesWidgetState.kt android/app/src/main/res/xml/three_lines_widget_info.xml android/app/src/test/kotlin/com/threelines/three_lines/ThreeLinesWidgetStateTest.kt
git commit -m "perf: reduce Android widget background updates"
```

---

### Task 7: 루프 1 전체 회귀·크기·권한 검증과 루브릭 판정

**Files:**
- Verify only: 모든 변경 파일과 생성 산출물

**Interfaces:**
- Consumes: Task 1~6의 테스트·빌드 결과.
- Produces: 루프 1 종료 게이트 판정과 다음 루프 기준선.

- [ ] **Step 1: 금지된 옛 경로와 암묵적 권한 설정이 없는지 정적 검사한다**

Run: `rg -n "FakeNotificationService|scheduleSmartDailyReminder|cancelReminder|requestAlertPermission: true|requestBadgePermission: true|requestSoundPermission: true" lib test`

Expected: 0 matches.

Run: `rg -n "settingsControllerProvider|widgetSyncServiceProvider|notificationServiceProvider" lib/features/today/today_controller.dart`

Expected: 0 matches.

- [ ] **Step 2: 변경 영역 테스트를 한 번에 실행한다**

Run: `flutter test test/app/widget_bootstrap_test.dart test/core/services/notification_platform_test.dart test/core/services/notification_service_test.dart test/core/services/reminder_coordinator_test.dart test/core/services/widget_sync_service_test.dart test/core/services/journal_side_effects_test.dart test/features/settings/settings_controller_test.dart test/features/timeline/timeline_controller_test.dart test/features/today/today_controller_test.dart test/integration/app_flow_test.dart test/app/routing_flash_test.dart`

Expected: 모든 지정 테스트 PASS.

- [ ] **Step 3: 정적 분석과 전체 Flutter 테스트를 실행한다**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test`

Expected: 전체 test suite PASS, 기존 기준 324개보다 테스트 수 증가.

- [ ] **Step 4: 커버리지를 재측정하고 핵심 파일 커버리지를 확인한다**

Run: `flutter test --coverage`

Expected: 전체 test suite PASS와 `coverage/lcov.info` 생성.

Run: `awk 'BEGIN{file="";lf=lh=0} /^SF:/{file=$0; sub(/^SF:/,"",file); lf=lh=0} /^LF:/{lf=substr($0,4)} /^LH:/{lh=substr($0,4)} /^end_of_record/{if (file ~ /(notification_service|reminder_coordinator|widget_sync_service|journal_side_effects)\.dart$/) printf "%s %d/%d %.1f%%\n", file, lh, lf, lf ? 100*lh/lf : 0}' coverage/lcov.info`

Expected: 네 핵심 파일이 모두 출력되고 `notification_service.dart`가 기준선 1.4%보다 높다.

- [ ] **Step 5: Android JVM 테스트와 arm64 릴리스 빌드를 실행한다**

Run: `cd android && ./gradlew app:testDebugUnitTest`

Expected: `BUILD SUCCESSFUL`.

Run (CI, keystore 주입): `flutter build apk --release --target-platform android-arm64 --analyze-size`

로컬 서명 없는 검증은 `--android-project-arg=allowUnsignedRelease=true`를 명시한다.

Expected: CI에서는 서명된 release APK와 size analysis가 생성되고, 로컬 override에서는 unsigned APK만 생성된다. unsigned 산출물은 배포하지 않는다.

- [ ] **Step 6: 병합 manifest와 위젯 주기를 검증한다**

Run: `! rg -n "android.permission.INTERNET" build/app/intermediates --glob AndroidManifest.xml`

Expected: 모든 생성 AndroidManifest에서 0 matches.

Run: `rg -n 'updatePeriodMillis="86400000"' android/app/src/main/res/xml/three_lines_widget_info.xml && rg -n "static const dailyIds|static const streakId = 200|static const weeklyId = 300" lib/core/services/notification_service.dart`

Expected: 위젯 주기와 세 ID 경계가 모두 match.

- [ ] **Step 7: 루브릭 종료 조건을 증거로 판정한다**

다음 기준을 모두 만족하면 루프 1을 통과로 기록한다.

- 정확성·안정성 4/5 이상: 시간대, 30일 날짜, ID 격리, 권한, 실패 보상 테스트가 모두 통과.
- 배터리·백그라운드 비용 3/5 이상: Android 주기가 48회/일 요청에서 최대 1회/일 요청으로 감소하고 위젯 병합·dedupe 테스트가 통과.
- 구조·테스트 가능성 4/5 이상: 플랫폼 경계 Fake, Coordinator 정책 테스트, 저널 후속 작업 테스트가 통과.
- 공통 게이트: analyze 0, 전체 tests 통과, arm64 release build 통과, DB schema·JSON 형식 변경 없음, 신규 P0/P1 결함 없음.

실기기 알림 도착 시각과 배터리 수치는 측정하지 못했으므로 신뢰도를 `중간`으로 남기고 프로그램 전체 완료로 표기하지 않는다.

- [ ] **Step 8: 검증 중 발견된 수정이 있으면 해당 Task 테스트부터 다시 실행하고 최종 상태를 커밋한다**

검증으로 코드 수정이 발생한 경우에만 다음을 실행한다.

```bash
git add lib test android pubspec.yaml pubspec.lock
git commit -m "test: close runtime correctness regressions"
```

코드 수정이 없으면 새 커밋을 만들지 않는다. `git status --short`에서 사용자 변경을 포함한 미추적·미커밋 파일을 임의로 stage하지 않는다.
