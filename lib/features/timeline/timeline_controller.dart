import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/journal_changes.dart';
import '../../core/services/photo_service.dart';
import '../../core/time/app_clock.dart';
import '../../data/models/daily_entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../today/today_controller.dart';
import 'timeline_state.dart';

class TimelineController extends AsyncNotifier<TimelineState> {
  TimelinePeriod _period = TimelinePeriod.weeks12;
  String _query = '';
  int _request = 0;

  @override
  Future<TimelineState> build() async {
    // Watch to rebuild when the repository changes (e.g. database reconnect)
    ref.watch(entryRepositoryProvider);
    ref.watch(journalChangesProvider);
    ++_request;
    // Riverpod의 build Future도 수동 검색/기간 변경보다 늦게 끝날 수 있다.
    // 같은 notifier의 현재 선택을 읽어 오래된 build snapshot을 반환하지 않는다.
    while (true) {
      final request = _request;
      try {
        final loaded = await _loadData(_period, _query);
        if (!ref.mounted || request == _request) return loaded;
      } catch (_) {
        if (!ref.mounted) rethrow;
        if (request == _request) {
          final current = state.value;
          if (current == null) rethrow;
          return current.copyWith(
            period: _period,
            searchQuery: _query,
            searchResults: const [],
            isLoading: false,
            loadFailed: true,
          );
        }
      }
    }
  }

  Future<TimelineState> _loadData(TimelinePeriod period, String query) async {
    final repo = ref.read(entryRepositoryProvider);
    final now = ref.read(appClockProvider).now();
    final start = DateTime(now.year, now.month, now.day - period.days + 1);

    final results = await Future.wait([
      repo.getCurrentStreak(),
      repo.getLongestStreak(),
      repo.getEmotionMap(start, now),
      repo.getTotalCount(),
      if (query.isNotEmpty) repo.searchEntries(query),
    ]);

    return TimelineState(
      currentStreak: results[0] as int,
      longestStreak: results[1] as int,
      emotionMap: results[2] as Map<String, int>,
      period: period,
      totalCount: results[3] as int,
      searchQuery: query,
      searchResults: query.isEmpty ? const [] : results[4] as List<DailyEntry>,
      loadedThrough: DateTime(now.year, now.month, now.day),
    );
  }

  Future<void> setPeriod(TimelinePeriod period) async {
    _period = period;
    await _reload();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }
    _query = query.trim();
    await _reload();
  }

  // 입력 순간에 응답을 무효화한다. UI debounce가 끝나기 전에도 이전 검색은
  // 새 입력의 결과로 표시할 수 없다.
  void prepareSearch(String query) {
    _query = query.trim();
    ++_request;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        searchQuery: _query,
        searchResults: const [],
        isLoading: _query.isNotEmpty,
        loadFailed: false,
      ),
    );
  }

  void clearSearch() {
    _query = '';
    ++_request;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        searchQuery: '',
        searchResults: const [],
        isLoading: false,
        loadFailed: false,
      ),
    );
    unawaited(_reload());
  }

  Future<void> retry() => _reload();

  Future<void> _reload() async {
    final request = ++_request;
    final current = state.value ?? const TimelineState();
    state = AsyncData(
      current.copyWith(
        period: _period,
        searchQuery: _query,
        searchResults: const [],
        isLoading: true,
        loadFailed: false,
      ),
    );
    try {
      final loaded = await _loadData(_period, _query);
      if (!ref.mounted || request != _request) return;
      state = AsyncData(loaded);
    } catch (_) {
      if (!ref.mounted || request != _request) return;
      state = AsyncData(
        state.value!.copyWith(isLoading: false, loadFailed: true),
      );
    }
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

    await _reload();

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
