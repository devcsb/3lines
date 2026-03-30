import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/daily_entry.dart';

/// Shows past entries (1 month, 6 months, 1 year ago) as reflection cards.
class OneYearAgoCard extends StatelessWidget {
  final DailyEntry? entry;
  final DailyEntry? sixMonthsAgoEntry;
  final DailyEntry? oneMonthAgoEntry;

  const OneYearAgoCard({
    super.key,
    this.entry,
    this.sixMonthsAgoEntry,
    this.oneMonthAgoEntry,
  });

  @override
  Widget build(BuildContext context) {
    // Collect all available past entries
    final pastEntries = <({String label, DailyEntry entry})>[
      if (oneMonthAgoEntry != null)
        (label: '1개월 전', entry: oneMonthAgoEntry!),
      if (sixMonthsAgoEntry != null)
        (label: '6개월 전', entry: sixMonthsAgoEntry!),
      if (entry != null) (label: '1년 전', entry: entry!),
    ];

    return Column(
      children: pastEntries
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PastEntryCard(
                  label: item.label,
                  entry: item.entry,
                ),
              ))
          .toList(),
    );
  }
}

class _PastEntryCard extends StatelessWidget {
  final String label;
  final DailyEntry entry;

  const _PastEntryCard({required this.label, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emotionColor =
        AppColors.emotionColors[entry.emotion] ?? theme.colorScheme.outline;
    final emotionLabel = AppColors.emotionLabels[entry.emotion] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 16,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Emotion badge with color dot
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: emotionColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: emotionColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      emotionLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: emotionColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._buildAnswerPreviews(theme),
        ],
      ),
    );
  }

  List<Widget> _buildAnswerPreviews(ThemeData theme) {
    final answers = [entry.answer1, entry.answer2, entry.answer3]
        .where((a) => a.isNotEmpty)
        .take(2);

    return answers
        .map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                a,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ))
        .toList();
  }
}
