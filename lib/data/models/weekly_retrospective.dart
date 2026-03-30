import '../../core/theme/app_colors.dart';

/// Local weekly retrospective summary generated from the past 7 days of entries.
class WeeklyRetrospective {
  final int entryCount;
  final double averageEmotion;
  final String trendDescription;
  final String topKeyword;
  final int currentStreak;
  final ({String date, int emotion})? bestDay;
  final ({String date, int emotion})? worstDay;

  const WeeklyRetrospective({
    required this.entryCount,
    required this.averageEmotion,
    required this.trendDescription,
    required this.topKeyword,
    required this.currentStreak,
    this.bestDay,
    this.worstDay,
  });

  String get summaryText {
    final buffer = StringBuffer();
    buffer.write('지난 7일간 $entryCount일 기록했어요. ');

    final emotionLabel =
        AppColors.emotionLabels[averageEmotion.round().clamp(1, 5)] ?? '';
    buffer.write('감정 평균은 ${averageEmotion.toStringAsFixed(1)} ($emotionLabel)이고, ');
    buffer.write('$trendDescription. ');

    if (topKeyword.isNotEmpty) {
      buffer.write('가장 많이 쓴 키워드는 "$topKeyword"예요. ');
    }

    if (currentStreak > 0) {
      buffer.write('$currentStreak일 연속 기록 중이에요!');
    }

    return buffer.toString().trimRight();
  }
}
