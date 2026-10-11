import 'package:flutter/material.dart';

/// Rotating daily micro-inspiration below the greeting.
/// Uses date-based indexing so the same quote appears all day.
class DailyQuote extends StatelessWidget {
  const DailyQuote({super.key});

  static const _quotes = [
    '오늘 기억하고 싶은 일을 한 줄 남겨보세요',
    '감정 하나와 답변 한 개부터 시작할 수 있어요',
    '짧은 문장도 하나의 기록이에요',
    '지금 어떤 감정인지 골라보세요',
    '질문 하나에만 답해도 저장할 수 있어요',
    '완성된 문장이 아니어도 괜찮아요',
    '오늘의 작은 장면을 남겨보세요',
    '쉬었다 돌아와도 다시 기록할 수 있어요',
    '쓰고 싶은 만큼만 짧게 적어보세요',
    '오늘 감사했던 일이 있다면 남겨보세요',
    '사진 없이 글만 남겨도 괜찮아요',
    '오늘 하루, 어떤 감정이든 괜찮아요',
    '떠오르는 말부터 한 줄 적어보세요',
    '이전 기록은 타임라인에서 찾아볼 수 있어요',
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
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
        height: 1.4,
      ),
    );
  }
}
