import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../shared/widgets/staggered_fade_in.dart';
import 'today_controller.dart';
import '../../core/services/photo_service.dart';
import 'widgets/animated_save_button.dart';
import 'widgets/completion_animation.dart';
import 'widgets/daily_quote.dart';
import 'widgets/emotion_picker.dart';
import 'widgets/milestone_banner.dart';
import 'widgets/one_year_ago_card.dart';
import 'widgets/photo_attachment.dart';
import 'widgets/prompt_card.dart';
import 'widgets/prompt_suggestions.dart';
import 'widgets/streak_pulse_badge.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with WidgetsBindingObserver {
  bool _showCompletionAnimation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(todayControllerProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(todayControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: asyncState.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('데이터를 불러올 수 없어요',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(todayControllerProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (state) {
          if (_showCompletionAnimation) {
            return CompletionAnimation(
              streak: state.currentStreak,
              emotion: state.emotion ?? 3,
              onComplete: () {
                setState(() => _showCompletionAnimation = false);
              },
            );
          }

          final isReadMode = state.isCompleted && !state.isEditing;

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        // Date
                        Text(
                          du.formatKoreanDate(DateTime.now()),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Greeting
                        Text(
                          du.getGreeting(streak: state.currentStreak),
                          style: theme.textTheme.headlineSmall,
                        ),
                        if (!state.isCompleted) ...[
                          const SizedBox(height: 6),
                          const DailyQuote(),
                        ],

                        // Streak badge
                        if (state.currentStreak > 0) ...[
                          const SizedBox(height: 12),
                          StreakPulseBadge(
                            streak: state.currentStreak,
                            usedGraceDay: state.usedGraceDay,
                          ),
                        ],

                        // Milestone celebration
                        if (state.milestone != null) ...[
                          const SizedBox(height: 16),
                          MilestoneBanner(milestone: state.milestone!),
                        ],

                        // Completed badge + sparkline — animated entrance
                        if (isReadMode) ...[
                          TweenAnimationBuilder<double>(
                            key: const ValueKey('read-mode-badge'),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) => Opacity(
                              opacity: value.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, 18 * (1 - value)),
                                child: child,
                              ),
                            ),
                            child: Column(
                              children: [
                                if (state.milestone == null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle_rounded,
                                            color: theme.colorScheme.primary,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          '오늘의 기록 완료',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (state.recentEmotions.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _MiniSparkline(
                                      recentEmotions: state.recentEmotions),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Grace day encouragement (when streak > 0, not completed, grace day used)
                        if (!state.isCompleted &&
                            state.usedGraceDay &&
                            state.currentStreak > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '자리를 비웠어도 괜찮아요. 다시 돌아오신 것만으로 충분해요.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],

                        // Past reflection cards (1 month / 6 months / 1 year ago)
                        if (state.oneYearAgoEntry != null ||
                            state.sixMonthsAgoEntry != null ||
                            state.oneMonthAgoEntry != null) ...[
                          const SizedBox(height: 16),
                          OneYearAgoCard(
                            entry: state.oneYearAgoEntry,
                            sixMonthsAgoEntry: state.sixMonthsAgoEntry,
                            oneMonthAgoEntry: state.oneMonthAgoEntry,
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Emotion picker
                        EmotionPicker(
                          selectedEmotion: state.emotion,
                          onSelected: (v) => ref
                              .read(todayControllerProvider.notifier)
                              .setEmotion(v),
                          enabled: !isReadMode,
                        ),

                        const SizedBox(height: 20),

                        // Photo attachment
                        PhotoAttachment(
                          photoPath: state.photoPath,
                          readOnly: isReadMode,
                          onPickCamera: () async {
                            final path = await ref
                                .read(photoServiceProvider)
                                .pickFromCamera();
                            if (path != null) {
                              ref
                                  .read(todayControllerProvider.notifier)
                                  .attachPhoto(path);
                            }
                          },
                          onPickGallery: () async {
                            final path = await ref
                                .read(photoServiceProvider)
                                .pickFromGallery();
                            if (path != null) {
                              ref
                                  .read(todayControllerProvider.notifier)
                                  .attachPhoto(path);
                            }
                          },
                          onRemove: () => ref
                              .read(todayControllerProvider.notifier)
                              .removePhoto(),
                        ),

                        const SizedBox(height: 28),

                        // Prompt cards with suggestions
                        ...List.generate(3, (index) {
                          final answer = switch (index) {
                            0 => state.answer1,
                            1 => state.answer2,
                            _ => state.answer3,
                          };
                          return StaggeredFadeIn(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                children: [
                                  PromptCard(
                                    index: index,
                                    question: state.prompts[index],
                                    answer: answer,
                                    readOnly: isReadMode,
                                    onChanged: isReadMode
                                        ? null
                                        : (v) => ref
                                            .read(
                                                todayControllerProvider.notifier)
                                            .setAnswer(index, v),
                                  ),
                                  // Suggestion chips (edit mode)
                                  if (!isReadMode) ...[
                                    const SizedBox(height: 8),
                                    PromptSuggestions(
                                      promptIndex: index,
                                      onTap: (suggestion) {
                                        final prev = answer;
                                        final next = prev.isEmpty
                                            ? suggestion
                                            : '$prev $suggestion';
                                        ref
                                            .read(todayControllerProvider
                                                .notifier)
                                            .setAnswer(index, next);
                                        if (prev.isNotEmpty) {
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              SnackBar(
                                                content:
                                                    const Text('제안을 추가했어요'),
                                                duration: const Duration(
                                                    seconds: 3),
                                                action: SnackBarAction(
                                                  label: '되돌리기',
                                                  onPressed: () => ref
                                                      .read(
                                                          todayControllerProvider
                                                              .notifier)
                                                      .setAnswer(index, prev),
                                                ),
                                              ),
                                            );
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Bottom button
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20, 12, 20,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: isReadMode
                      ? Semantics(
                          button: true,
                          label: '오늘의 기록 수정하기',
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => ref
                                  .read(todayControllerProvider.notifier)
                                  .toggleEdit(),
                              child: const Text('수정하기'),
                            ),
                          ),
                        )
                      : AnimatedSaveButton(
                          emotionSelected: state.emotion != null,
                          filledCount: () {
                            final count = [
                              state.answer1,
                              state.answer2,
                              state.answer3,
                            ].where((a) => a.isNotEmpty).length;
                            // 감정 미선택 시 링이 100%로 오해되지 않도록 최대 2/3로 제한
                            return state.emotion != null ? count : count.clamp(0, 2);
                          }(),
                          canSave: state.canSave,
                          isSaving: state.isSaving,
                          onPressed: () async {
                            final isFirstSave = !state.isCompleted;
                            final messenger =
                                ScaffoldMessenger.of(context);
                            final success = await ref
                                .read(todayControllerProvider.notifier)
                                .save();
                            if (!mounted) return;
                            if (success) {
                              // 저장 완료 시 키보드를 닫아 완료 애니메이션이 가려지지 않게 함
                              FocusScope.of(context).unfocus();
                            }
                            if (success && isFirstSave) {
                              setState(
                                  () => _showCompletionAnimation = true);
                            } else if (!success) {
                              messenger.showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        '저장에 실패했어요. 다시 시도해주세요.')),
                              );
                            }
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List<({DateTime date, int emotion})> recentEmotions;

  const _MiniSparkline({required this.recentEmotions});

  static const _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최근 7일 감정',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: days.map((day) {
              final dateStr =
                  '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final emotionEntry = recentEmotions
                  .where((e) =>
                      '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}' ==
                      dateStr)
                  .firstOrNull;
              final emotion = emotionEntry?.emotion;
              final color = emotion != null
                  ? AppColors.emotionColors[emotion]!
                  : theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.4);
              final isToday = day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;

              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: emotion != null ? 28 : 22,
                    height: emotion != null ? 28 : 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(
                          alpha: emotion != null ? 0.85 : 0.25),
                      border: isToday
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: emotion != null
                        ? Center(
                            child: Text(
                              '$emotion',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dayLabels[day.weekday - 1],
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: isToday ? 0.7 : 0.35,
                      ),
                      fontWeight: isToday
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
