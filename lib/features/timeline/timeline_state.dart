import '../../data/models/daily_entry.dart';

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

  DateTime startDateFrom(DateTime now) {
    return now.subtract(Duration(days: period.days));
  }
}
