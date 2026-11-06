import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../data/models/daily_entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../timeline/widgets/entry_detail_sheet.dart';

final bookmarkedEntriesProvider = StreamProvider.autoDispose<List<DailyEntry>>(
  (ref) => ref.watch(entryRepositoryProvider).watchBookmarkedEntries(),
);

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(bookmarkedEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('책갈피')),
      body: SafeArea(
        top: false,
        child: entries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('책갈피를 불러오지 못했어요.'),
                  TextButton(
                    onPressed: () => ref.invalidate(bookmarkedEntriesProvider),
                    child: const Text('다시 불러오기'),
                  ),
                ],
              ),
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 32),
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '다시 읽고 싶은 기록이 생기면',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '오늘 저장한 기록이나 지난 기록에서\n‘책갈피에 담기’를 눌러 주세요.\n내가 고른 기록만 여기에 모여요.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: entries.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    '내가 다시 읽고 싶어 남겨둔 기록이에요.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                final entry = entries[index - 1];
                final preview = [
                  entry.answer1,
                  entry.answer2,
                  entry.answer3,
                ].where((answer) => answer.trim().isNotEmpty).join(' · ');
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(du.formatDateString(entry.date)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppColors.emotionLabels[entry.emotion] ?? ''),
                          const SizedBox(height: 4),
                          Text(
                            preview.isEmpty ? '마음만 남긴 기록' : preview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => FractionallySizedBox(
                        heightFactor: 0.85,
                        child: EntryDetailSheet(
                          entry: entry,
                          navigateAdjacent: false,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
