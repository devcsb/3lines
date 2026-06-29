import 'package:flutter/material.dart';

/// Rotating daily micro-inspiration below the greeting.
/// Uses date-based indexing so the same quote appears all day.
class DailyQuote extends StatelessWidget {
  const DailyQuote({super.key});

  static const _quotes = [
    '작은 기록이 큰 변화의 씨앗이 돼요',
    '오늘의 나에게 30초만 선물하세요',
    '기록은 과거가 아닌, 미래를 위한 거예요',
    '감정을 마주하는 것 자체가 용기예요',
    '어제보다 오늘, 한 줄 더 나를 알게 돼요',
    '완벽할 필요 없어요. 솔직하면 충분해요',
    '당신의 하루는 기록될 가치가 있어요',
    '지금 이 순간의 감정도 지나가요',
    '조용히 적는 한 줄이 마음을 정리해요',
    '감사는 발견하는 순간 커지는 감정이에요',
    '나를 돌보는 가장 쉬운 방법, 기록',
    '오늘 하루, 어떤 감정이든 괜찮아요',
    '글로 쓰면 마음이 가벼워져요',
    '매일 3줄, 나를 이해하는 시간',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    // Rotate based on day-of-year so it changes daily but stays stable all day
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final quote = _quotes[dayOfYear % _quotes.length];

    return Text(
      quote,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        fontStyle: FontStyle.italic,
        height: 1.4,
      ),
    );
  }
}
