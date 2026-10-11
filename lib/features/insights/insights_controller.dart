import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/journal_changes.dart';
import '../../core/time/app_clock.dart';
import '../../data/repositories/entry_repository.dart';
import 'insights_state.dart';

class InsightsController extends AsyncNotifier<InsightsState> {
  InsightsPeriod _period = InsightsPeriod.week1;
  int _generation = 0;
  @override
  Future<InsightsState> build() async {
    // Watch to rebuild when the repository changes (e.g. database reconnect)
    ref.watch(entryRepositoryProvider);
    ref.watch(journalChangesProvider);
    _generation++;
    // build Future도 수동 기간 변경보다 늦게 끝날 수 있다.
    // 옛 snapshot/오류는 버리고 현재 선택 세대가 끝날 때까지 다시 조회한다.
    while (true) {
      final generation = _generation;
      try {
        final loaded = await _loadData(_period);
        if (!ref.mounted || generation == _generation) return loaded;
      } catch (_) {
        if (!ref.mounted || generation == _generation) rethrow;
      }
    }
  }

  Future<InsightsState> _loadData(InsightsPeriod period) async {
    final repo = ref.read(entryRepositoryProvider);
    final totalCount = await repo.getTotalCount();

    if (totalCount == 0) {
      return InsightsState(
        isUnlocked: false,
        totalCount: totalCount,
        period: period,
      );
    }

    final now = ref.read(appClockProvider).now();
    final start = DateTime(now.year, now.month, now.day - period.days + 1);

    // Weekly delta: this week avg vs last week avg
    final thisWeekStart = DateTime(now.year, now.month, now.day - 6);
    final lastWeekStart = DateTime(now.year, now.month, now.day - 13);
    final lastWeekEnd = DateTime(now.year, now.month, now.day - 7);

    final results = await Future.wait([
      repo.getAverageEmotionOrNull(start, now), // 0
      repo.getCurrentStreakWithGrace(), // 1 (replaces getCurrentStreak)
      repo.getEmotionTrend(start, now), // 2
      repo.getEmotionByDayOfWeek(start, now), // 3
      repo.getKeywordFrequency(start, now), // 4
      repo.getGratitudeKeywords(start, now), // 5
      repo.getAverageEmotionOrNull(thisWeekStart, now), // 6
      repo.getAverageEmotionOrNull(lastWeekStart, lastWeekEnd), // 7
      repo.getMonthlySummary(now.year, now.month), // 8
      repo.getEmotionMap(thisWeekStart, now), // 9
      repo.getEmotionMap(lastWeekStart, lastWeekEnd), // 10
    ]);

    final streakResult = results[1] as ({int count, bool usedGraceDay});
    final currentStreak = streakResult.count;

    // Pass streak to avoid redundant DB query inside getWeeklyRetrospective
    final weeklyRetro = await repo.getWeeklyRetrospective(
      currentStreak: currentStreak,
    );

    final dayOfWeek = results[3] as Map<int, double>;

    final thisWeekAvg = results[6] as double?;
    final lastWeekAvg = results[7] as double?;
    final thisWeekCount = (results[9] as Map<String, int>).length;
    final lastWeekCount = (results[10] as Map<String, int>).length;
    final weeklyDelta =
        (thisWeekAvg != null &&
            lastWeekAvg != null &&
            thisWeekCount >= 3 &&
            lastWeekCount >= 3)
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
      averageEmotion: results[0] as double?,
      thisWeekCount: thisWeekCount,
      lastWeekCount: lastWeekCount,
      periodStart: start,
      periodEnd: now,
      currentStreak: currentStreak,
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
    _period = period;
    final generation = ++_generation;
    final result = await AsyncValue.guard(() => _loadData(period));
    if (ref.mounted && generation == _generation) state = result;
  }
}

final insightsControllerProvider =
    AsyncNotifierProvider<InsightsController, InsightsState>(
      InsightsController.new,
      isAutoDispose: true,
    );
