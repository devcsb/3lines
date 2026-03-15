import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daily_entry.dart';
import '../../data/repositories/entry_repository.dart';

enum TimelinePeriod { weeks12, months6, year1 }

class TimelineState {
  final int currentStreak;
  final int longestStreak;
  final Map<String, int> emotionMap;
  final TimelinePeriod period;

  const TimelineState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.emotionMap = const {},
    this.period = TimelinePeriod.weeks12,
  });

  TimelineState copyWith({
    int? currentStreak,
    int? longestStreak,
    Map<String, int>? emotionMap,
    TimelinePeriod? period,
  }) {
    return TimelineState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      emotionMap: emotionMap ?? this.emotionMap,
      period: period ?? this.period,
    );
  }

  DateTime get startDate {
    final now = DateTime.now();
    return switch (period) {
      TimelinePeriod.weeks12 => now.subtract(const Duration(days: 84)),
      TimelinePeriod.months6 => now.subtract(const Duration(days: 182)),
      TimelinePeriod.year1 => now.subtract(const Duration(days: 365)),
    };
  }
}

class TimelineController extends AsyncNotifier<TimelineState> {
  @override
  Future<TimelineState> build() async {
    return _loadData(TimelinePeriod.weeks12);
  }

  Future<TimelineState> _loadData(TimelinePeriod period) async {
    final repo = ref.read(entryRepositoryProvider);
    final now = DateTime.now();
    final start = switch (period) {
      TimelinePeriod.weeks12 => now.subtract(const Duration(days: 84)),
      TimelinePeriod.months6 => now.subtract(const Duration(days: 182)),
      TimelinePeriod.year1 => now.subtract(const Duration(days: 365)),
    };

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
    state = AsyncData(await _loadData(period));
  }

  Future<DailyEntry?> getEntryByDate(String date) async {
    final repo = ref.read(entryRepositoryProvider);
    return repo.getEntryByDate(date);
  }
}

final timelineControllerProvider =
    AsyncNotifierProvider<TimelineController, TimelineState>(
        TimelineController.new);
