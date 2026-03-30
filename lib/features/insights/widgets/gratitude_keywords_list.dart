import 'package:flutter/material.dart';

class GratitudeKeywordsList extends StatelessWidget {
  const GratitudeKeywordsList({super.key, required this.keywords});

  final Map<String, int> keywords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (keywords.isEmpty) {
      return Text(
        '아직 분석할 키워드가 부족해요',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    final sorted = keywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sorted.asMap().entries.map((e) {
        final rank = e.key + 1;
        final keyword = e.value.key;
        final count = e.value.value;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              // Rank number
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  keyword,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '$count회',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
