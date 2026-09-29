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
    if (entry == null) return;
    await repo.deleteEntry(date);

    // DB 커밋 후 다른 기록과 활성 Today draft가 참조하지 않는 사진만 정리한다.
    if (entry.photoPath != null) {
      await ref
          .read(photoServiceProvider)
          .deleteUnreferencedPhoto(
            entry.photoPath!,
            readReferences: repo.getAllPhotoPaths,
            retainedPaths: _retainedTodayDraftPaths(),
          );
    }

    final period = state.value?.period ?? TimelinePeriod.weeks12;
    // 삭제 후에도 이전 히트맵을 유지한 채 재로드 완료 시 교체(깜빡임 방지).
    state = await AsyncValue.guard(() => _loadData(period));

    ref.read(journalChangesProvider.notifier).markChanged();
    ref.invalidate(todayControllerProvider);
  }

  Iterable<String> _retainedTodayDraftPaths() {
    final today = ref.read(todayControllerProvider).value;
    if (today == null || (today.isCompleted && !today.isEditing)) {
      return const [];
    }
    final path = today.photoPath;
    return path == null ? const [] : [path];
  }
}

final timelineControllerProvider =
    AsyncNotifierProvider<TimelineController, TimelineState>(
      TimelineController.new,
      isAutoDispose: true,
    );
