import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daily_entry.dart';
import '../../data/repositories/entry_repository.dart';

enum TimelinePeriod {
  weeks12(84),
  months6(182),
  year1(365);

  final int days;
  const TimelinePeriod(this.days);
}

class TimelineState {
  final int currentStreak;
  final int longestStreak;
  final Map<String, int> emotionMap;
  final TimelinePeriod period;
  final String searchQuery;
  final List<DailyEntry> searchResults;

  const TimelineState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.emotionMap = const {},
    this.period = TimelinePeriod.weeks12,
    this.searchQuery = '',
    this.searchResults = const [],
  });

  bool get isSearching => searchQuery.isNotEmpty;

  TimelineState copyWith({
    int? currentStreak,
    int? longestStreak,
    Map<String, int>? emotionMap,
    TimelinePeriod? period,
    String? searchQuery,
    List<DailyEntry>? searchResults,
  }) {
    return TimelineState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      emotionMap: emotionMap ?? this.emotionMap,
      period: period ?? this.period,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
    );
  }

  DateTime get startDate =>
      DateTime.now().subtract(Duration(days: period.days));
}

class TimelineController extends AutoDisposeAsyncNotifier<TimelineState> {
  @override
  Future<TimelineState> build() async {
    // Watch to rebuild when the repository changes (e.g. database reconnect)
    ref.watch(entryRepositoryProvider);
    return _loadData(TimelinePeriod.weeks12);
  }

  Future<TimelineState> _loadData(TimelinePeriod period) async {
    final repo = ref.read(entryRepositoryProvider);
    final now = DateTime.now();
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadData(period));
  }

  Future<void> search(String query) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    final repo = ref.read(entryRepositoryProvider);
    final results = await repo.searchEntries(query);
    state = AsyncData(current.copyWith(
      searchQuery: query,
      searchResults: results,
    ));
  }

  void clearSearch() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      searchQuery: '',
      searchResults: const [],
    ));
  }

  Future<DailyEntry?> getEntryByDate(String date) async {
    final repo = ref.read(entryRepositoryProvider);
    return repo.getEntryByDate(date);
  }

  Future<void> deleteEntry(String date) async {
    final repo = ref.read(entryRepositoryProvider);
    await repo.deleteEntry(date);
    final period = state.valueOrNull?.period ?? TimelinePeriod.weeks12;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadData(period));
  }
}

final timelineControllerProvider =
    AutoDisposeAsyncNotifierProvider<TimelineController, TimelineState>(
        TimelineController.new);
