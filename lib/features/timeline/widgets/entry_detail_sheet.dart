import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/default_prompts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
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
  bool _adjacentFailed = false;

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
    setState(() {
      _navigating = true;
      _adjacentFailed = false;
    });
    final repo = ref.read(entryRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.getPreviousEntry(date),
        repo.getNextEntry(date),
      ]);
      if (!mounted) return;
      setState(() {
        _window = [results[0], _window[1], results[1]];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _adjacentFailed = true);
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  Future<void> _onPageChanged(int index) async {
    if (index == 1) return; // centre — no action needed

    // 끝이나 조회 중에도 빈 slot에 머물지 않는다.
    _pageController.jumpToPage(1);
    if (_navigating) return;

    final newCurrent = _window[index];
    if (newCurrent == null) return;

    _navigating = true;
    // Silently jump back to centre slot and shift the window
    setState(() {
      _window = [null, newCurrent, null];
    });

    await _loadAdjacent(newCurrent.date);
    _navigating = false;
  }

  void _move(int index) {
    if (_navigating || _window[index] == null) return;
    if (AppMotion.reduceMotion(context)) {
      _pageController.jumpToPage(index);
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
          onPrevious: isCurrent && hasPrev && !_navigating
              ? () => _move(0)
              : null,
          onNext: isCurrent && hasNext && !_navigating ? () => _move(2) : null,
          adjacentLoading: isCurrent && _navigating,
          onRetry: isCurrent && _adjacentFailed
              ? () => _loadAdjacent(_window[1]!.date)
              : null,
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
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onRetry;
  final bool adjacentLoading;

  const _EntryDetailContent({
    required this.entry,
    this.onDelete,
    this.hasPrev = false,
    this.hasNext = false,
    this.onPrevious,
    this.onNext,
    this.onRetry,
    this.adjacentLoading = false,
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
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                du.formatDateString(entry.date),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
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
                        color: theme.colorScheme.onSurfaceVariant,
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
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  tooltip: '삭제',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: '이전 기록',
                onPressed: onPrevious,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              if (adjacentLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: '인접 기록 조회 중',
                  ),
                ),
              IconButton(
                tooltip: '다음 기록',
                onPressed: onNext,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const Text('다른 기록을 불러올 수 없어요. 현재 기록은 그대로예요.'),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],

          // Swipe hint
          if (hasPrev || hasNext) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasPrev)
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                Text(
                  '스와이프로 탐색',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (hasNext)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer.isEmpty ? '—' : answer,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: answer.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
