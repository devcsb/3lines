import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/default_prompts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart' as du;
import '../../../data/models/daily_entry.dart';
import '../../../data/repositories/entry_repository.dart';

class EntryDetailSheet extends ConsumerStatefulWidget {
  final DailyEntry entry;
  // 스와이프로 다른 날로 이동할 수 있으므로 삭제 콜백은 삭제 시점에 화면에
  // 표시 중인 entry 를 인자로 받는다(원본 entry 를 캡처하면 엉뚱한 날이 삭제됨).
  final ValueChanged<DailyEntry>? onDelete;

  const EntryDetailSheet({super.key, required this.entry, this.onDelete});

  @override
  ConsumerState<EntryDetailSheet> createState() => _EntryDetailSheetState();
}

class _EntryDetailSheetState extends ConsumerState<EntryDetailSheet> {
  late PageController _pageController;
  // 3-slot window: [prevEntry, currentEntry, nextEntry]
  late List<DailyEntry?> _window;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _window = [null, widget.entry, null];
    _pageController = PageController(initialPage: 1);
    _loadAdjacent(widget.entry.date);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAdjacent(String date) async {
    final repo = ref.read(entryRepositoryProvider);
    final results = await Future.wait([
      repo.getPreviousEntry(date),
      repo.getNextEntry(date),
    ]);
    if (!mounted) return;
    setState(() {
      _window = [results[0], _window[1], results[1]];
    });
  }

  Future<void> _onPageChanged(int index) async {
    if (_navigating) return;
    if (index == 1) return; // centre — no action needed

    final newCurrent = _window[index];
    if (newCurrent == null) return;

    _navigating = true;
    // Silently jump back to centre slot and shift the window
    _pageController.jumpToPage(1);
    setState(() {
      _window = [null, newCurrent, null];
    });

    await _loadAdjacent(newCurrent.date);
    _navigating = false;
  }

  @override
  Widget build(BuildContext context) {
    final hasPrev = _window[0] != null;
    final hasNext = _window[2] != null;

    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: 3,
      itemBuilder: (context, index) {
        final entry = _window[index];
        if (entry == null) {
          return const SizedBox.shrink();
        }
        final isCurrent = index == 1;
        return _EntryDetailContent(
          entry: entry,
          onDelete: isCurrent ? widget.onDelete : null,
          hasPrev: isCurrent && hasPrev,
          hasNext: isCurrent && hasNext,
        );
      },
    );
  }
}

class _EntryDetailContent extends StatelessWidget {
  final DailyEntry entry;
  final ValueChanged<DailyEntry>? onDelete;
  final bool hasPrev;
  final bool hasNext;

  const _EntryDetailContent({
    required this.entry,
    this.onDelete,
    this.hasPrev = false,
    this.hasNext = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final emotionColor =
        AppColors.emotionColors[entry.emotion] ?? theme.colorScheme.outline;
    final emotionLabel = AppColors.emotionLabels[entry.emotion] ?? '';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: emotionColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Date + emotion badge + delete row
          Row(
            children: [
              Expanded(
                child: Text(
                  du.formatDateString(entry.date),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: emotionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: emotionColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: emotionColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      emotionLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: emotionColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    size: 20,
                  ),
                  tooltip: '삭제',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ],
          ),

          // Swipe hint
          if (hasPrev || hasNext) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasPrev)
                  Icon(Icons.chevron_left_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6)),
                Text(
                  '스와이프로 탐색',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                if (hasNext)
                  Icon(Icons.chevron_right_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6)),
              ],
            ),
          ],

          // Photo
          if (entry.photoPath != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(entry.photoPath!),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Q&A cards
          _buildQACard(
            theme,
            category: PromptCategory.gratitude,
            question: entry.prompt1,
            answer: entry.answer1,
          ),
          const SizedBox(height: 10),
          _buildQACard(
            theme,
            category: PromptCategory.acceptance,
            question: entry.prompt2,
            answer: entry.answer2,
          ),
          const SizedBox(height: 10),
          _buildQACard(
            theme,
            category: PromptCategory.intention,
            question: entry.prompt3,
            answer: entry.answer3,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 날의 기록을 삭제할까요?\n삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onDelete!(entry);
            },
            child: Text(
              '삭제',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _accentColors = {
    PromptCategory.gratitude: Color(0xFF5B8A6A),
    PromptCategory.acceptance: Color(0xFFC49A6A),
    PromptCategory.intention: Color(0xFF6B8A8A),
  };

  Widget _buildQACard(
    ThemeData theme, {
    required PromptCategory category,
    required String question,
    required String answer,
  }) {
    final accent = _accentColors[category] ?? theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer.isEmpty ? '—' : answer,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(
                alpha: answer.isEmpty ? 0.25 : 0.8,
              ),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
