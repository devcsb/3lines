import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../data/models/daily_entry.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import 'timeline_controller.dart';
import 'widgets/entry_detail_sheet.dart';
import 'widgets/heatmap_grid.dart';
import 'widgets/streak_badge.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _loadingEntry = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          if (state.emotionMap.isEmpty && !state.isSearching) {
            return Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.grid_view_rounded,
                          size: 28,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3)),
                    ),
                    const SizedBox(height: 16),
                    Text('첫 기록을 시작해보세요',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        )),
                  ],
                ),
              ),
            );
          }

          return SafeArea(
            child: RefreshIndicator(
            onRefresh: () async {
              HapticService.light();
              ref.invalidate(timelineControllerProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('타임라인', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  // Search bar
                  SearchBar(
                    controller: _searchController,
                    hintText: '기록 검색...',
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.search_rounded,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4)),
                    ),
                    trailing: [
                      if (state.isSearching)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(timelineControllerProvider.notifier)
                                .clearSearch();
                          },
                        ),
                    ],
                    onChanged: (query) {
                      _debounceTimer?.cancel();
                      if (query.trim().isEmpty) {
                        ref
                            .read(timelineControllerProvider.notifier)
                            .clearSearch();
                        return;
                      }
                      _debounceTimer = Timer(
                          const Duration(milliseconds: 300), () {
                        ref
                            .read(timelineControllerProvider.notifier)
                            .search(query.trim());
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (state.isSearching)
                    _buildSearchResults(theme, state)
                  else ...[
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
                    Stack(
                      children: [
                        HeatmapGrid(
                          emotionMap: state.emotionMap,
                          startDate: state.startDate,
                          onCellTap: (dateStr) async {
                            if (_loadingEntry) return;
                            setState(() => _loadingEntry = true);
                            final entry = await ref
                                .read(timelineControllerProvider.notifier)
                                .getEntryByDate(dateStr);
                            if (!mounted) return;
                            setState(() => _loadingEntry = false);
                            if (entry != null) {
                              _showEntryDetail(entry);
                            }
                          },
                        ),
                        if (_loadingEntry)
                          Positioned.fill(
                            child: Container(
                              color: theme.colorScheme.surface
                                  .withValues(alpha: 0.6),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme, TimelineState state) {
    if (state.searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            "'${state.searchQuery}'에 대한 결과가 없어요",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${state.searchResults.length}개의 결과',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(state.searchResults.length, (i) {
          final entry = state.searchResults[i];
          final emotionColor =
              AppColors.emotionColors[entry.emotion] ?? theme.colorScheme.outline;
          return StaggeredFadeIn(
            index: i,
            child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showEntryDetail(entry),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    // Emotion dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: emotionColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            du.formatDateString(entry.date),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [entry.answer1, entry.answer2, entry.answer3]
                                .where((a) => a.isNotEmpty)
                                .join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
          ),
          );
        }),
      ],
    );
  }

  void _showEntryDetail(DailyEntry entry) {
    HapticService.light();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => EntryDetailSheet(
        entry: entry,
        onDelete: () async {
          Navigator.of(ctx).pop();
          await ref
              .read(timelineControllerProvider.notifier)
              .deleteEntry(entry.date);
        },
      ),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}
