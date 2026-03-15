import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daily_entry.dart';
import 'timeline_controller.dart';
import 'widgets/entry_detail_sheet.dart';
import 'widgets/heatmap_grid.dart';
import 'widgets/streak_badge.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(timelineControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('데이터를 불러올 수 없어요'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(timelineControllerProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (state) {
          if (state.emotionMap.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view,
                      size: 64,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('첫 기록을 시작해보세요',
                      style: theme.textTheme.bodyLarge),
                ],
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text('타임라인', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  StreakBadge(
                    currentStreak: state.currentStreak,
                    longestStreak: state.longestStreak,
                  ),
                  const SizedBox(height: 24),
                  // Period toggle
                  Semantics(
                    label: '타임라인 기간 선택',
                    child: SegmentedButton<TimelinePeriod>(
                    segments: const [
                      ButtonSegment(
                        value: TimelinePeriod.weeks12,
                        label: Text('12주'),
                      ),
                      ButtonSegment(
                        value: TimelinePeriod.months6,
                        label: Text('6개월'),
                      ),
                      ButtonSegment(
                        value: TimelinePeriod.year1,
                        label: Text('1년'),
                      ),
                    ],
                    selected: {state.period},
                    onSelectionChanged: (selection) {
                      ref
                          .read(timelineControllerProvider.notifier)
                          .setPeriod(selection.first);
                    },
                  ),
                  ),
                  const SizedBox(height: 24),
                  HeatmapGrid(
                    emotionMap: state.emotionMap,
                    startDate: state.startDate,
                    onCellTap: (dateStr) async {
                      final entry = await ref
                          .read(timelineControllerProvider.notifier)
                          .getEntryByDate(dateStr);
                      if (entry != null && context.mounted) {
                        _showEntryDetail(context, entry);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEntryDetail(BuildContext context, DailyEntry entry) {
    showModalBottomSheet(
      context: context,
      builder: (_) => EntryDetailSheet(entry: entry),
      isScrollControlled: true,
    );
  }
}
