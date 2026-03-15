import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' as du;
import '../../data/repositories/entry_repository.dart';

enum InsightsPeriod { week1, month1, month3 }

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
  });

  InsightsState copyWith({
    bool? isUnlocked,
    int? totalCount,
    double? averageEmotion,
    int? currentStreak,
    String? bestDayOfWeek,
    List<({DateTime date, int emotion})>? emotionTrend,
    Map<int, double>? dayOfWeekEmotions,
    Map<String, int>? keywords,
    Map<String, int>? gratitudeKeywords,
    InsightsPeriod? period,
  }) {
    return InsightsState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      totalCount: totalCount ?? this.totalCount,
      averageEmotion: averageEmotion ?? this.averageEmotion,
      currentStreak: currentStreak ?? this.currentStreak,
      bestDayOfWeek: bestDayOfWeek ?? this.bestDayOfWeek,
      emotionTrend: emotionTrend ?? this.emotionTrend,
      dayOfWeekEmotions: dayOfWeekEmotions ?? this.dayOfWeekEmotions,
      keywords: keywords ?? this.keywords,
      gratitudeKeywords: gratitudeKeywords ?? this.gratitudeKeywords,
      period: period ?? this.period,
    );
  }
}

class InsightsController extends AsyncNotifier<InsightsState> {
  @override
  Future<InsightsState> build() async {
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
    final start = switch (period) {
      InsightsPeriod.week1 => now.subtract(const Duration(days: 7)),
      InsightsPeriod.month1 => now.subtract(const Duration(days: 30)),
      InsightsPeriod.month3 => now.subtract(const Duration(days: 90)),
    };

    final periodDays = switch (period) {
      InsightsPeriod.week1 => 7,
      InsightsPeriod.month1 => 30,
      InsightsPeriod.month3 => 90,
    };

    final results = await Future.wait([
      repo.getAverageEmotion(periodDays),
      repo.getCurrentStreak(),
      repo.getEmotionTrend(start, now),
      repo.getEmotionByDayOfWeek(),
      repo.getKeywordFrequency(),
      repo.getGratitudeKeywords(),
    ]);

    final dayOfWeek = results[3] as Map<int, double>;
    String bestDay = '';
    double bestAvg = 0;
    for (final entry in dayOfWeek.entries) {
      if (entry.value > bestAvg) {
        bestAvg = entry.value;
        bestDay = du.getDayOfWeekLabel(entry.key);
      }
    }

    return InsightsState(
      isUnlocked: true,
      totalCount: totalCount,
      averageEmotion: results[0] as double,
      currentStreak: results[1] as int,
      bestDayOfWeek: bestDay.isEmpty ? '-' : '$bestDay요일',
      emotionTrend: results[2] as List<({DateTime date, int emotion})>,
      dayOfWeekEmotions: dayOfWeek,
      keywords: results[4] as Map<String, int>,
      gratitudeKeywords: results[5] as Map<String, int>,
      period: period,
    );
  }

  Future<void> setPeriod(InsightsPeriod period) async {
    state = const AsyncLoading();
    state = AsyncData(await _loadData(period));
  }
}

final insightsControllerProvider =
    AsyncNotifierProvider<InsightsController, InsightsState>(
        InsightsController.new);
