import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/weekly_retrospective.dart';

/// Displays a local weekly retrospective summary card.
class WeeklyRetrospectiveCard extends StatelessWidget {
  final WeeklyRetrospective retrospective;

  const WeeklyRetrospectiveCard({super.key, required this.retrospective});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '주간 회고',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            retrospective.summaryText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          if (retrospective.bestDay != null ||
              retrospective.worstDay != null) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 360 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 20
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    if (retrospective.bestDay != null)
                      _DayHighlight(
                        label: '기록 중 가장 높은 감정',
                        date: retrospective.bestDay!.date,
                        emotion: retrospective.bestDay!.emotion,
                      ),
                    if (retrospective.worstDay != null)
                      _DayHighlight(
                        label: '기록 중 가장 낮은 감정',
                        date: retrospective.worstDay!.date,
                        emotion: retrospective.worstDay!.emotion,
                      ),
                  ].map((item) => SizedBox(width: width, child: item)).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DayHighlight extends StatelessWidget {
  final String label;
  final String date;
  final int emotion;

  const _DayHighlight({
    required this.label,
    required this.date,
    required this.emotion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.emotionColors[emotion] ?? theme.colorScheme.outline;
    final emotionLabel = AppColors.emotionLabels[emotion] ?? '';

    // Parse yyyy-MM-dd to get month/day
    final parsed = DateTime.tryParse(date);
    final dateLabel = parsed != null ? '${parsed.month}/${parsed.day}' : date;

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Text(
              '$dateLabel $emotionLabel',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
