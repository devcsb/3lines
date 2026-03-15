import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import 'insights_controller.dart';
import 'widgets/day_of_week_chart.dart';
import 'widgets/emotion_trend_chart.dart';
import 'widgets/keyword_cloud.dart';
import 'widgets/stat_card.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(insightsControllerProvider);
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
                    ref.invalidate(insightsControllerProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (state) {
          if (!state.isUnlocked) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights,
                        size: 64,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('7일 이상 기록하면\n인사이트가 열려요',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    Text(
                      '${state.totalCount}/${state.requiredCount}일 완료',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (state.totalCount / state.requiredCount)
                          .clamp(0.0, 1.0),
                    ),
                  ],
                ),
              ),
            );
          }

          final avgEmoji = AppColors.emotionEmojis[
                  state.averageEmotion.round().clamp(1, 5)] ??
              '';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text('인사이트', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 16),

                  // Congratulation banner on first unlock
                  if (state.totalCount == state.requiredCount)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '인사이트가 열렸어요!',
                              style:
                                  theme.textTheme.titleMedium?.copyWith(
                                color:
                                    theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${state.requiredCount}일 기록을 축하해요',
                              style:
                                  theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Period selector
                  Semantics(
                    label: '인사이트 기간 선택',
                    child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('1주'),
                        selected:
                            state.period == InsightsPeriod.week1,
                        onSelected: (_) => ref
                            .read(insightsControllerProvider.notifier)
                            .setPeriod(InsightsPeriod.week1),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('1개월'),
                        selected:
                            state.period == InsightsPeriod.month1,
                        onSelected: (_) => ref
                            .read(insightsControllerProvider.notifier)
                            .setPeriod(InsightsPeriod.month1),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('3개월'),
                        selected:
                            state.period == InsightsPeriod.month3,
                        onSelected: (_) => ref
                            .read(insightsControllerProvider.notifier)
                            .setPeriod(InsightsPeriod.month3),
                      ),
                    ],
                  ),
                  ),

                  const SizedBox(height: 24),

                  // Emotion trend chart
                  StaggeredFadeIn(
                    index: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('감정 추이',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        EmotionTrendChart(data: state.emotionTrend),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stats grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.3,
                    children: [
                      StaggeredFadeIn(
                        index: 1,
                        child: StatCard(
                          title: '평균 감정',
                          value:
                              '$avgEmoji ${state.averageEmotion.toStringAsFixed(1)}',
                          icon: Icons.emoji_emotions,
                        ),
                      ),
                      StaggeredFadeIn(
                        index: 2,
                        child: StatCard(
                          title: '현재 스트릭',
                          value: '${state.currentStreak}일',
                          icon: Icons.local_fire_department,
                        ),
                      ),
                      StaggeredFadeIn(
                        index: 3,
                        child: StatCard(
                          title: '총 기록',
                          value: '${state.totalCount}개',
                          icon: Icons.note_alt,
                        ),
                      ),
                      StaggeredFadeIn(
                        index: 4,
                        child: StatCard(
                          title: '최고의 요일',
                          value: state.bestDayOfWeek,
                          icon: Icons.calendar_today,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Day of week chart
                  StaggeredFadeIn(
                    index: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('요일별 감정',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DayOfWeekChart(data: state.dayOfWeekEmotions),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Keywords
                  StaggeredFadeIn(
                    index: 6,
                    child: KeywordCloud(
                      keywords: state.keywords,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Gratitude keywords
                  StaggeredFadeIn(
                    index: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('감사 키워드 TOP 5',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (state.gratitudeKeywords.isEmpty)
                          Text(
                            '아직 분석할 키워드가 부족해요',
                            style:
                                theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          )
                        else
                          ...(state.gratitudeKeywords.entries.toList()
                                ..sort((a, b) =>
                                    b.value.compareTo(a.value)))
                              .asMap()
                              .entries
                              .map((e) {
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                child: Text('${e.key + 1}',
                                    style:
                                        const TextStyle(fontSize: 12)),
                              ),
                              title: Text(e.value.key),
                              trailing: Text('${e.value.value}회',
                                  style: theme.textTheme.bodySmall),
                            );
                          }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
