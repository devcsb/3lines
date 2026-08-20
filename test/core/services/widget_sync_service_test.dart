import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/core/services/widget_sync_service.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';

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
  Future<void> updateWidget({
    required String iOSName,
    required String androidName,
  }) async {
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

void main() {
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

  WidgetSnapshot snapshot() {
    final prompt = <String>['감사'].single;
    return WidgetSnapshot(
      date: '2026-08-06',
      streak: 1,
      isCompleted: true,
      prompt: prompt,
      emotion: 4,
      statusMessage: '오늘 기록 완료 · 평온',
      streakLabel: '1일',
    );
  }

  Future<void> saveToday() => entries.saveEntry(
    DailyEntry(
      date: '2026-08-06',
      emotion: 4,
      prompt1: '감사',
      answer1: '산책',
      prompt2: '수용',
      answer2: '',
      prompt3: '의도',
      answer3: '',
    ),
  );

  group('WidgetSnapshot.buildStatusMessage', () {
    test('completed with emotion', () {
      expect(
        WidgetSnapshot.buildStatusMessage(
          isCompleted: true,
          streak: 3,
          emotion: 5,
        ),
        '오늘 기록 완료 · 감사',
      );
    });

    test('incomplete with streak', () {
      expect(
        WidgetSnapshot.buildStatusMessage(
          isCompleted: false,
          streak: 4,
          emotion: null,
        ),
        '오늘 아직이에요 · 스트릭 유지 중',
      );
    });

    test('incomplete without streak', () {
      expect(
        WidgetSnapshot.buildStatusMessage(
          isCompleted: false,
          streak: 0,
          emotion: null,
        ),
        '오늘 한 줄만 적어도 돼요',
      );
    });
  });

  group('WidgetSnapshot.buildStreakLabel', () {
    test('zero', () {
      expect(WidgetSnapshot.buildStreakLabel(0), '시작해볼까요');
    });

    test('positive', () {
      expect(WidgetSnapshot.buildStreakLabel(12), '12일');
    });
  });

  group('WidgetSnapshot.parseEmotionFromUri', () {
    test('parses valid emotion', () {
      final uri = Uri.parse('threelines://today?emotion=3');
      expect(WidgetSnapshot.parseEmotionFromUri(uri), 3);
    });

    test('rejects out of range', () {
      final uri = Uri.parse('threelines://today?emotion=9');
      expect(WidgetSnapshot.parseEmotionFromUri(uri), isNull);
    });

    test('rejects other schemes', () {
      final uri = Uri.parse('https://example.com/today?emotion=2');
      expect(WidgetSnapshot.parseEmotionFromUri(uri), isNull);
    });

    test('allows open without emotion', () {
      final uri = Uri.parse('threelines://today');
      expect(WidgetSnapshot.parseEmotionFromUri(uri), isNull);
    });
  });

  group('WidgetSnapshot.todayUri', () {
    test('builds without emotion', () {
      expect(WidgetSnapshot.todayUri().toString(), 'threelines://today');
    });

    test('builds with emotion', () {
      expect(
        WidgetSnapshot.todayUri(emotion: 4).toString(),
        'threelines://today?emotion=4',
      );
    });
  });

  group('WidgetSyncService.sync', () {
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
  });
}
