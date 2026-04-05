import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' as du;
import '../../data/models/weekly_retrospective.dart';
import '../../data/repositories/entry_repository.dart';

enum InsightsPeriod {
  week1(7),
  month1(30),
  month3(90);

  final int days;
  const InsightsPeriod(this.days);
}

class MonthlySummary {
  final String monthLabel; // e.g. "3월"
  final double averageEmotion;
  final int entryCount;
  final String topKeyword;

  const MonthlySummary({
    required this.monthLabel,
    required this.averageEmotion,
    required this.entryCount,
    required this.topKeyword,
  });
}

class InsightsState {
  final bool isUnlocked;
  final int totalCount;
  final int requiredCount;
  final double averageEmotion;
  final int currentStreak;
  final String bestDayOfWeek;
  final List<({DateTime date, int emotion})> emotionTrend;
  final Map<int, double> dayOfWeekEmotions;
  final Map<String, int> keywords;
  final Map<String, int> gratitudeKeywords;
  final InsightsPeriod period;
  final double? weeklyDelta; // this week avg - last week avg
  final MonthlySummary? monthlySummary;
  final WeeklyRetrospective? weeklyRetrospective;

  const InsightsState({
    this.isUnlocked = false,
    this.totalCount = 0,
    this.requiredCount = 7,
    this.averageEmotion = 0.0,
    this.currentStreak = 0,
    this.bestDayOfWeek = '',
    this.emotionTrend = const [],
    this.dayOfWeekEmotions = const {},
    this.keywords = const {},
    this.gratitudeKeywords = const {},
    this.period = InsightsPeriod.week1,
    this.weeklyDelta,
    this.monthlySummary,
    this.weeklyRetrospective,
  });

  InsightsState copyWith({
    bool? isUnlocked,
    int? totalCount,
    int? requiredCount,
    double? averageEmotion,
    int? currentStreak,
    String? bestDayOfWeek,
    List<({DateTime date, int emotion})>? emotionTrend,
    Map<int, double>? dayOfWeekEmotions,
    Map<String, int>? keywords,
    Map<String, int>? gratitudeKeywords,
    InsightsPeriod? period,
    double? Function()? weeklyDelta,
    MonthlySummary? Function()? monthlySummary,
    WeeklyRetrospective? Function()? weeklyRetrospective,
  }) {
    return InsightsState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      totalCount: totalCount ?? this.totalCount,
      requiredCount: requiredCount ?? this.requiredCount,
      averageEmotion: averageEmotion ?? this.averageEmotion,
      currentStreak: currentStreak ?? this.currentStreak,
      bestDayOfWeek: bestDayOfWeek ?? this.bestDayOfWeek,
      emotionTrend: emotionTrend ?? this.emotionTrend,
      dayOfWeekEmotions: dayOfWeekEmotions ?? this.dayOfWeekEmotions,
      keywords: keywords ?? this.keywords,
      gratitudeKeywords: gratitudeKeywords ?? this.gratitudeKeywords,
      period: period ?? this.period,
      weeklyDelta: weeklyDelta != null ? weeklyDelta() : this.weeklyDelta,
      monthlySummary: monthlySummary != null ? monthlySummary() : this.monthlySummary,
      weeklyRetrospective: weeklyRetrospective != null ? weeklyRetrospective() : this.weeklyRetrospective,
    );
  }
}

class InsightsController extends AutoDisposeAsyncNotifier<InsightsState> {
  @override
  Future<InsightsState> build() async {
    // Watch to rebuild when the repository changes (e.g. database reconnect)
    ref.watch(entryRepositoryProvider);
    return _loadData(InsightsPeriod.week1);
  }

  Future<InsightsState> _loadData(InsightsPeriod period) async {
    final repo = ref.read(entryRepositoryProvider);
    final totalCount = await repo.getTotalCount();

    if (totalCount < 7) {
      return InsightsState(
        isUnlocked: false,
        totalCount: totalCount,
      );
    }

    final now = DateTime.now();
    final start = now.subtract(Duration(days: period.days));

    // Weekly delta: this week avg vs last week avg
    final thisWeekStart = now.subtract(const Duration(days: 7));
    final lastWeekStart = now.subtract(const Duration(days: 14));
    final lastWeekEnd = now.subtract(const Duration(days: 8));

    final results = await Future.wait([
      repo.getAverageEmotion(start, now),           // 0
      repo.getCurrentStreakWithGrace(),              // 1 (replaces getCurrentStreak)
      repo.getEmotionTrend(start, now),              // 2
      repo.getEmotionByDayOfWeek(start, now),        // 3
      repo.getKeywordFrequency(start, now),          // 4
      repo.getGratitudeKeywords(start, now),         // 5
      repo.getAverageEmotionOrNull(thisWeekStart, now), // 6
      repo.getAverageEmotionOrNull(lastWeekStart, lastWeekEnd), // 7
      repo.getMonthlySummary(now.year, now.month),   // 8
    ]);

    final streakResult = results[1] as ({int count, bool usedGraceDay});
    final currentStreak = streakResult.count;

    // Pass streak to avoid redundant DB query inside getWeeklyRetrospective
    final weeklyRetro = await repo.getWeeklyRetrospective(currentStreak: currentStreak);

    final dayOfWeek = results[3] as Map<int, double>;
    String bestDay = '';
    double bestAvg = 0;
    for (final entry in dayOfWeek.entries) {
      if (entry.value > bestAvg) {
        bestAvg = entry.value;
        bestDay = du.getDayOfWeekLabel(entry.key);
      }
    }

    final thisWeekAvg = results[6] as double?;
    final lastWeekAvg = results[7] as double?;
    final weeklyDelta = (thisWeekAvg != null && lastWeekAvg != null)
        ? thisWeekAvg - lastWeekAvg
        : null;

    final monthlyRaw = results[8]
        as ({double averageEmotion, int entryCount, String topKeyword});
    final monthlySummary = monthlyRaw.entryCount > 0
        ? MonthlySummary(
            monthLabel: '${now.month}월',
            averageEmotion: monthlyRaw.averageEmotion,
            entryCount: monthlyRaw.entryCount,
            topKeyword: monthlyRaw.topKeyword,
          )
        : null;

    return InsightsState(
      isUnlocked: true,
      totalCount: totalCount,
      averageEmotion: results[0] as double,
      currentStreak: currentStreak,
      bestDayOfWeek: bestDay.isEmpty ? '-' : '$bestDay요일',
      emotionTrend: results[2] as List<({DateTime date, int emotion})>,
      dayOfWeekEmotions: dayOfWeek,
      keywords: results[4] as Map<String, int>,
      gratitudeKeywords: results[5] as Map<String, int>,
      period: period,
      weeklyDelta: weeklyDelta,
      monthlySummary: monthlySummary,
      weeklyRetrospective: weeklyRetro,

    );
  }

  Future<void> setPeriod(InsightsPeriod period) async {
    // 이전 데이터를 유지하여 전체 화면 로딩 스피너를 방지한다.
    state = AsyncLoading<InsightsState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _loadData(period));
  }
}

final insightsControllerProvider =
    AutoDisposeAsyncNotifierProvider<InsightsController, InsightsState>(
        InsightsController.new);
