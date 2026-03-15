import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart' as du;
import '../../../data/models/daily_entry.dart';

class EntryDetailSheet extends StatelessWidget {
  final DailyEntry entry;

  const EntryDetailSheet({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Date + emotion
          Row(
            children: [
              Text(
                du.formatDateString(entry.date),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Text(
                AppColors.emotionEmojis[entry.emotion] ?? '',
                style: const TextStyle(fontSize: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQA(theme, entry.prompt1, entry.answer1),
          const SizedBox(height: 12),
          _buildQA(theme, entry.prompt2, entry.answer2),
          const SizedBox(height: 12),
          _buildQA(theme, entry.prompt3, entry.answer3),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQA(ThemeData theme, String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer.isEmpty ? '-' : answer,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
