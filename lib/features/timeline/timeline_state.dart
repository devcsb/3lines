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
  final int totalCount;
  final bool isLoading;
  final bool loadFailed;
  final DateTime? loadedThrough;

  const TimelineState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.emotionMap = const {},
    this.period = TimelinePeriod.weeks12,
    this.searchQuery = '',
    this.searchResults = const [],
    this.totalCount = 0,
    this.isLoading = false,
    this.loadFailed = false,
    this.loadedThrough,
  });

  bool get isSearching => searchQuery.isNotEmpty;

  TimelineState copyWith({
    int? currentStreak,
    int? longestStreak,
    Map<String, int>? emotionMap,
    TimelinePeriod? period,
    String? searchQuery,
    List<DailyEntry>? searchResults,
    int? totalCount,
    bool? isLoading,
    bool? loadFailed,
    DateTime? loadedThrough,
  }) {
    return TimelineState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      emotionMap: emotionMap ?? this.emotionMap,
      period: period ?? this.period,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      loadFailed: loadFailed ?? this.loadFailed,
      loadedThrough: loadedThrough ?? this.loadedThrough,
    );
  }

  DateTime startDateFrom(DateTime now) {
    return DateTime(now.year, now.month, now.day - period.days + 1);
  }
}
