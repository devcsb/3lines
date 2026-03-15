import 'package:flutter/material.dart';

class KeywordCloud extends StatelessWidget {
  final Map<String, int> keywords;
  final String title;

  const KeywordCloud({
    super.key,
    required this.keywords,
    this.title = '자주 쓰는 단어',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (keywords.isEmpty) {
      return Text(
        '아직 분석할 키워드가 부족해요',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    final maxCount =
        keywords.values.reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: keywords.entries.map((entry) {
            final intensity = (entry.value / maxCount).clamp(0.3, 1.0);
            return Chip(
              label: Text(entry.key),
              labelStyle: TextStyle(
                fontSize: 12 + (intensity * 4),
                color: theme.colorScheme.primary
                    .withValues(alpha: intensity),
              ),
              backgroundColor: theme.colorScheme.primaryContainer
                  .withValues(alpha: intensity * 0.5),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }
}
