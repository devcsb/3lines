import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/journal_changes.dart';
import '../../core/time/app_clock.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../data/repositories/entry_repository.dart';
import 'insights_state.dart';

class InsightsController extends AsyncNotifier<InsightsState> {
  @override
  Future<InsightsState> build() async {
    // Watch to rebuild when the repository changes (e.g. database reconnect)
    ref.watch(entryRepositoryProvider);
    ref.watch(journalChangesProvider);
    return _loadData(InsightsPeriod.week1);
  }

  Future<InsightsState> _loadData(InsightsPeriod period) async {
    final repo = ref.read(entryRepositoryProvider);
    final totalCount = await repo.getTotalCount();

    if (totalCount < 7) {
      return InsightsState(isUnlocked: false, totalCount: totalCount);
    }

    final now = ref.read(appClockProvider).now();
    final start = now.subtract(Duration(days: period.days));

    // Weekly delta: this week avg vs last week avg
    final thisWeekStart = now.subtract(const Duration(days: 7));
    final lastWeekStart = now.subtract(const Duration(days: 14));
    final lastWeekEnd = now.subtract(const Duration(days: 8));

    final results = await Future.wait([
      repo.getAverageEmotion(start, now), // 0
      repo.getCurrentStreakWithGrace(), // 1 (replaces getCurrentStreak)
      repo.getEmotionTrend(start, now), // 2
      repo.getEmotionByDayOfWeek(start, now), // 3
      repo.getKeywordFrequency(start, now), // 4
      repo.getGratitudeKeywords(start, now), // 5
      repo.getAverageEmotionOrNull(thisWeekStart, now), // 6
      repo.getAverageEmotionOrNull(lastWeekStart, lastWeekEnd), // 7
      repo.getMonthlySummary(now.year, now.month), // 8
    ]);

    final streakResult = results[1] as ({int count, bool usedGraceDay});
    final currentStreak = streakResult.count;

    // Pass streak to avoid redundant DB query inside getWeeklyRetrospective
    final weeklyRetro = await repo.getWeeklyRetrospective(
      currentStreak: currentStreak,
    );

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

    final monthlyRaw =
        results[8]
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
    // AsyncLoading 으로 전환하지 않고 새 데이터 준비 완료 시 교체한다.
    // 전환 동안 이전 데이터가 그대로 노출되어 전체 화면 로딩 스피너를 방지한다.
    state = await AsyncValue.guard(() => _loadData(period));
  }
}

final insightsControllerProvider =
    AsyncNotifierProvider<InsightsController, InsightsState>(
      InsightsController.new,
      isAutoDispose: true,
    );
