import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/events/journal_changes.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/features/insights/insights_controller.dart';
import 'package:three_lines/features/insights/insights_state.dart';

class FixedClock extends AppClock {
  @override
  DateTime now() => DateTime(2026, 10, 11);
}

class DelayedRepository extends EntryRepository {
  DelayedRepository(super.db) : super(clock: FixedClock());
  Completer<void>? gate;
  @override
  Future<int> getTotalCount() async {
    final pending = gate;
    gate = null;
    if (pending != null) await pending.future;
    return super.getTotalCount();
  }
}

void main() {
  late AppDatabase db;
  late DelayedRepository repo;
  late ProviderContainer container;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DelayedRepository(db);
    container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repo),
        appClockProvider.overrideWithValue(FixedClock()),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> entry(String date, int emotion) =>
      repo.saveEntry(DailyEntry(date: date, emotion: emotion, answer1: '산책'));

  test('한 기록부터 평균을 열고 빈 기간은 null이다', () async {
    await entry('2026-09-01', 4);
    container.listen(insightsControllerProvider, (_, _) {});
    final state = await container.read(insightsControllerProvider.future);
    expect(state.isUnlocked, isTrue);
    expect(state.averageEmotion, isNull);
  });
  test('7/30/90일은 정확한 달력 날짜이며 비교 주는 각각 7일이다', () async {
    for (var day = 4; day <= 11; day++) {
      await entry(
        '2026-10-${day.toString().padLeft(2, '0')}',
        day == 4 ? 5 : 1,
      );
    }
    container.listen(insightsControllerProvider, (_, _) {});
    final state = await container.read(insightsControllerProvider.future);
    expect(state.averageEmotion, 1);
    expect(state.emotionTrend.length, 7);
    expect(state.weeklyDelta, isNull);
    await entry('2026-09-11', 5);
    await entry('2026-09-12', 2);
    await entry('2026-07-13', 5);
    await entry('2026-07-14', 2);
    final controller = container.read(insightsControllerProvider.notifier);
    await controller.setPeriod(InsightsPeriod.month1);
    expect(
      container
          .read(insightsControllerProvider)
          .requireValue
          .emotionTrend
          .length,
      9,
    );
    await controller.setPeriod(InsightsPeriod.month3);
    expect(
      container
          .read(insightsControllerProvider)
          .requireValue
          .emotionTrend
          .length,
      11,
    );
  });
  test('늦은 기간 응답과 journal 갱신 및 refresh는 최신 기간을 유지한다', () async {
    await entry('2026-10-11', 3);
    container.listen(insightsControllerProvider, (_, _) {});
    await container.read(insightsControllerProvider.future);
    final controller = container.read(insightsControllerProvider.notifier);
    final gate = Completer<void>();
    repo.gate = gate;
    final old = controller.setPeriod(InsightsPeriod.month1);
    await controller.setPeriod(InsightsPeriod.month3);
    gate.complete();
    await old;
    expect(
      container.read(insightsControllerProvider).requireValue.period,
      InsightsPeriod.month3,
    );
    container.read(journalChangesProvider.notifier).markChanged();
    expect(
      (await container.read(insightsControllerProvider.future)).period,
      InsightsPeriod.month3,
    );
    expect(
      (await container.refresh(insightsControllerProvider.future)).period,
      InsightsPeriod.month3,
    );
  });
  test('갱신 중 기간 변경 뒤 늦은 build 응답도 최신 기간을 유지한다', () async {
    await entry('2026-10-11', 3);
    container.listen(insightsControllerProvider, (_, _) {});
    await container.read(insightsControllerProvider.future);
    final gate = Completer<void>();
    repo.gate = gate;
    final refreshed = container.refresh(insightsControllerProvider.future);
    await container
        .read(insightsControllerProvider.notifier)
        .setPeriod(InsightsPeriod.month3);
    gate.complete();
    await refreshed;
    expect(
      container.read(insightsControllerProvider).requireValue.period,
      InsightsPeriod.month3,
    );
  });
  test('주간 차이는 각 일곱 날짜의 표본 세 개부터 표시한다', () async {
    for (final day in [28, 29, 30]) {
      await entry('2026-09-$day', 5);
    }
    for (final day in [5, 6, 7]) {
      await entry('2026-10-0$day', 1);
    }
    await entry('2026-09-27', 1); // 이전 비교 주 바깥
    container.listen(insightsControllerProvider, (_, _) {});
    final state = await container.read(insightsControllerProvider.future);
    expect(state.thisWeekCount, 3);
    expect(state.lastWeekCount, 3);
    expect(state.weeklyDelta, -4);
    await repo.deleteEntry('2026-09-30');
    container.read(journalChangesProvider.notifier).markChanged();
    final updated = await container.read(insightsControllerProvider.future);
    expect(updated.lastWeekCount, 2);
    expect(updated.weeklyDelta, isNull);
  });
}
