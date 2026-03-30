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
              Icon(Icons.auto_awesome_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                '주간 회고',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            retrospective.summaryText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          if (retrospective.bestDay != null ||
              retrospective.worstDay != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (retrospective.bestDay != null)
                  Expanded(
                    child: _DayHighlight(
                      label: '최고의 날',
                      date: retrospective.bestDay!.date,
                      emotion: retrospective.bestDay!.emotion,
                    ),
                  ),
                if (retrospective.bestDay != null &&
                    retrospective.worstDay != null)
                  Container(
                    width: 1,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.3),
                  ),
                if (retrospective.worstDay != null)
                  Expanded(
                    child: _DayHighlight(
                      label: '힘들었던 날',
                      date: retrospective.worstDay!.date,
                      emotion: retrospective.worstDay!.emotion,
                    ),
                  ),
              ],
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
    final color =
        AppColors.emotionColors[emotion] ?? theme.colorScheme.outline;
    final emotionLabel = AppColors.emotionLabels[emotion] ?? '';

    // Parse yyyy-MM-dd to get month/day
    final parsed = DateTime.tryParse(date);
    final dateLabel =
        parsed != null ? '${parsed.month}/${parsed.day}' : date;

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$dateLabel $emotionLabel',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
