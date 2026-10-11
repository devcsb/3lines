import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/events/journal_changes.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/features/timeline/timeline_controller.dart';
import 'package:three_lines/features/timeline/timeline_state.dart';

class MutableClock extends AppClock {
  DateTime value = DateTime(2026, 10, 11, 23, 50);
  @override
  DateTime now() => value;
}

class DelayedSearchRepository extends EntryRepository {
  DelayedSearchRepository(super.db, {required super.clock});
  final gates = <String, Completer<void>>{};
  final mapGates = <String, Completer<void>>{};
  bool searchFails = false;
  @override
  Future<List<DailyEntry>> searchEntries(String query) async {
    if (searchFails) throw StateError('search failed');
    // 실제 SQLite 검색 결과를 보관한 뒤 응답 전달만 지연한다.
    final entries = await super.searchEntries(query);
    await gates[query]?.future;
    return entries;
  }

  @override
  Future<Map<String, int>> getEmotionMap(DateTime start, DateTime end) async {
    final result = await super.getEmotionMap(start, end);
    await mapGates[start.toIso8601String().substring(0, 10)]?.future;
    return result;
  }
}

void main() {
  late AppDatabase db;
  late MutableClock clock;
  late DelayedSearchRepository repo;
  late ProviderContainer container;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = MutableClock();
    repo = DelayedSearchRepository(db, clock: clock);
    container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repo),
        appClockProvider.overrideWithValue(clock),
      ],
    );
    final subscription = container.listen(
      timelineControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> seed() async {
    await repo.saveEntry(
      DailyEntry(
        date: '2026-03-01',
        emotion: 4,
        answer1: '여행',
        answer2: '',
        answer3: '',
      ),
    );
    await repo.saveEntry(
      DailyEntry(
        date: '2026-10-11',
        emotion: 2,
        answer1: '운동',
        answer2: '',
        answer3: '',
      ),
    );
    await container.refresh(timelineControllerProvider.future);
  }

  test('검색 clear 뒤 늦은 응답은 검색을 되살리지 않는다', () async {
    await seed();
    repo.gates['여행'] = Completer<void>();
    final controller = container.read(timelineControllerProvider.notifier);
    final pending = controller.search('여행');
    controller.clearSearch();
    repo.gates['여행']!.complete();
    await pending;
    expect(
      container.read(timelineControllerProvider).value!.isSearching,
      false,
    );
  });
  test('전체 건수는 기간 밖 기록도 세며 실제 빈 DB와 구분한다', () async {
    final empty = await container.read(timelineControllerProvider.future);
    expect(empty.totalCount, 0);
    await repo.saveEntry(
      DailyEntry(
        date: '2026-03-01',
        emotion: 4,
        answer1: '여행',
        answer2: '',
        answer3: '',
      ),
    );
    final oldOnly = await container.refresh(timelineControllerProvider.future);
    expect(oldOnly.totalCount, 1);
    expect(oldOnly.emotionMap, isEmpty);
  });
  test('B 응답 이후 A 응답은 최신 검색을 바꾸지 않는다', () async {
    await seed();
    repo.gates['여행'] = Completer<void>();
    final controller = container.read(timelineControllerProvider.notifier);
    final pending = controller.search('여행');
    await controller.search('운동');
    repo.gates['여행']!.complete();
    await pending;
    final state = container.read(timelineControllerProvider).value!;
    expect(state.searchQuery, '운동');
    expect(state.searchResults.single.date, '2026-10-11');
  });
  test('기간 변경과 검색 교차 및 journal/refresh는 선택을 유지한다', () async {
    await seed();
    final controller = container.read(timelineControllerProvider.notifier);
    repo.gates['여행'] = Completer<void>();
    final search = controller.search('여행');
    final period = controller.setPeriod(TimelinePeriod.year1);
    repo.gates['여행']!.complete();
    await Future.wait([search, period]);
    container.read(journalChangesProvider.notifier).markChanged();
    await container.read(timelineControllerProvider.future);
    var state = await container.refresh(timelineControllerProvider.future);
    expect(state.period, TimelinePeriod.year1);
    expect(state.searchQuery, '여행');
    expect(state.searchResults.single.date, '2026-03-01');
    clock.value = DateTime(2026, 10, 12, 0, 10);
    state = await container.refresh(timelineControllerProvider.future);
    expect(state.period, TimelinePeriod.year1);
    expect(state.searchQuery, '여행');
  });
  test('84일은 오늘 포함 7월20일부터이며 전날은 제외한다', () async {
    for (final date in ['2026-07-19', '2026-07-20', '2026-10-11']) {
      await repo.saveEntry(
        DailyEntry(
          date: date,
          emotion: 4,
          answer1: date,
          answer2: '',
          answer3: '',
        ),
      );
    }
    final state = await container.refresh(timelineControllerProvider.future);
    expect(state.emotionMap.keys.toSet(), {'2026-07-20', '2026-10-11'});
    expect(state.startDateFrom(clock.now()), DateTime(2026, 7, 20));
  });
  test('refresh 중 새 검색이 끝나면 늦은 refresh도 최신 검색을 유지한다', () async {
    await seed();
    final controller = container.read(timelineControllerProvider.notifier);
    await controller.search('여행');
    repo.gates['여행'] = Completer<void>();
    final refresh = container.refresh(timelineControllerProvider.future);
    // rebuild가 이전 검색을 실제로 시작하게 한다.
    await Future<void>.delayed(Duration.zero);
    await controller.search('운동');
    repo.gates['여행']!.complete();
    await refresh;
    final state = container.read(timelineControllerProvider).value!;
    expect(state.searchQuery, '운동');
    expect(state.searchResults.single.date, '2026-10-11');
  });
  test('기간 응답 역전과 clear는 마지막 기간과 그 지도만 유지한다', () async {
    await seed();
    final controller = container.read(timelineControllerProvider.notifier);
    repo.mapGates['2025-10-12'] = Completer<void>();
    final year = controller.setPeriod(TimelinePeriod.year1);
    await controller.setPeriod(TimelinePeriod.months6);
    controller.clearSearch();
    repo.mapGates['2025-10-12']!.complete();
    await year;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final state = container.read(timelineControllerProvider).value!;
    expect(state.period, TimelinePeriod.months6);
    expect(state.emotionMap.keys.toSet(), {'2026-10-11'});
  });
  test('검색 실패를 상태로 표시하고 입력을 보존해 재시도한다', () async {
    await seed();
    final controller = container.read(timelineControllerProvider.notifier);
    repo.searchFails = true;
    await controller.search('여행');
    var state = container.read(timelineControllerProvider).value!;
    expect(state.searchQuery, '여행');
    expect(state.loadFailed, true);
    expect(state.isLoading, false);
    repo.searchFails = false;
    await controller.retry();
    state = container.read(timelineControllerProvider).value!;
    expect(state.loadFailed, false);
    expect(state.searchResults.single.date, '2026-03-01');
  });
}
