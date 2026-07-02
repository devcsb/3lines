import '../../data/models/weekly_retrospective.dart';

enum InsightsPeriod {
  week1(7),
  month1(30),
  month3(90);

  final int days;
  const InsightsPeriod(this.days);
}

class MonthlySummary {
  final String monthLabel;
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
  final double? weeklyDelta;
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
      monthlySummary: monthlySummary != null
          ? monthlySummary()
          : this.monthlySummary,
      weeklyRetrospective: weeklyRetrospective != null
          ? weeklyRetrospective()
          : this.weeklyRetrospective,
    );
  }
}
