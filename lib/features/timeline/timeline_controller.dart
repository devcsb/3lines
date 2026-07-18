import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/journal_changes.dart';
import '../../core/services/photo_service.dart';
import '../../core/time/app_clock.dart';
import '../../data/models/daily_entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../today/today_controller.dart';
import 'timeline_state.dart';

class TimelineController extends AsyncNotifier<TimelineState> {
  @override
  Future<TimelineState> build() async {
    // Watch to rebuild when the repository changes (e.g. database reconnect)
    ref.watch(entryRepositoryProvider);
    ref.watch(journalChangesProvider);
    return _loadData(TimelinePeriod.weeks12);
  }

  Future<TimelineState> _loadData(TimelinePeriod period) async {
    final repo = ref.read(entryRepositoryProvider);
    final now = ref.read(appClockProvider).now();
    final start = now.subtract(Duration(days: period.days));

    final results = await Future.wait([
      repo.getCurrentStreak(),
      repo.getLongestStreak(),
      repo.getEmotionMap(start, now),
    ]);

    return TimelineState(
      currentStreak: results[0] as int,
      longestStreak: results[1] as int,
      emotionMap: results[2] as Map<String, int>,
      period: period,
    );
  }

  Future<void> setPeriod(TimelinePeriod period) async {
    // AsyncLoading 전환을 생략해 이전 히트맵을 유지한 채 로드 완료 시점에만
    // 새 데이터로 교체한다(insights 와 일관 — 전체화면 스피너 깜빡임 방지).
    state = await AsyncValue.guard(() => _loadData(period));
  }

  Future<void> search(String query) async {
    final current = state.value;
    if (current == null) return;
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    final repo = ref.read(entryRepositoryProvider);
    final results = await repo.searchEntries(query);
    state = AsyncData(
      current.copyWith(searchQuery: query, searchResults: results),
    );
  }

  void clearSearch() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(searchQuery: '', searchResults: const []),
    );
  }

  Future<DailyEntry?> getEntryByDate(String date) async {
    final repo = ref.read(entryRepositoryProvider);
    return repo.getEntryByDate(date);
  }

  Future<void> deleteEntry(String date) async {
    final repo = ref.read(entryRepositoryProvider);

    // 삭제 전에 해당 기록의 사진 파일 경로를 확보한다.
    final entry = await repo.getEntryByDate(date);
    await repo.deleteEntry(date);

    // 첨부 사진 파일이 있으면 디스크에서도 삭제한다.
    if (entry?.photoPath != null) {
      final photoService = ref.read(photoServiceProvider);
      await photoService.deletePhoto(entry!.photoPath!);
    }

    final period = state.value?.period ?? TimelinePeriod.weeks12;
    // 삭제 후에도 이전 히트맵을 유지한 채 재로드 완료 시 교체(깜빡임 방지).
    state = await AsyncValue.guard(() => _loadData(period));

    ref.read(journalChangesProvider.notifier).markChanged();
    ref.invalidate(todayControllerProvider);
  }
}

final timelineControllerProvider =
    AsyncNotifierProvider<TimelineController, TimelineState>(
      TimelineController.new,
      isAutoDispose: true,
    );
