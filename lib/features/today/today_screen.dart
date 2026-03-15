import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' as du;
import '../../shared/widgets/staggered_fade_in.dart';
import 'today_controller.dart';
import 'widgets/completion_animation.dart';
import 'widgets/emotion_picker.dart';
import 'widgets/prompt_card.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with WidgetsBindingObserver {
  bool _showCompletionAnimation = false;
  String _currentDate = du.getTodayString();
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now);

    _midnightTimer = Timer(duration, () {
      if (mounted) {
        _currentDate = du.getTodayString();
        ref.read(todayControllerProvider.notifier).refresh();
        // Schedule the next midnight
        _scheduleMidnightRefresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final today = du.getTodayString();
      if (today != _currentDate) {
        _currentDate = today;
        ref.read(todayControllerProvider.notifier).refresh();
      }
      // Re-schedule in case timer drifted while backgrounded
      _scheduleMidnightRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(todayControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: asyncState.when(
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
            return Center(
              child: CompletionAnimation(
                onComplete: () {
                  setState(() => _showCompletionAnimation = false);
                },
              ),
            );
          }

          final isReadMode = state.isCompleted && !state.isEditing;

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting
                        Text(
                          du.getGreeting(),
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          du.formatKoreanDate(DateTime.now()),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),

                        // Streak badge
                        if (state.currentStreak > 0) ...[
                          const SizedBox(height: 8),
                          Semantics(
                            label: '${state.currentStreak}일 연속 기록 중',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${state.currentStreak}일 연속',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Completed badge
                        if (isReadMode) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text('오늘의 기록 완료',
                                    style: theme.textTheme.labelLarge),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Emotion picker
                        EmotionPicker(
                          selectedEmotion: state.emotion,
                          onSelected: (v) => ref
                              .read(todayControllerProvider.notifier)
                              .setEmotion(v),
                          enabled: !isReadMode,
                        ),

                        const SizedBox(height: 24),

                        // Prompt cards (staggered fade in per PRD)
                        ...List.generate(3, (index) {
                          final answer = switch (index) {
                            0 => state.answer1,
                            1 => state.answer2,
                            _ => state.answer3,
                          };
                          return StaggeredFadeIn(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PromptCard(
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
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Bottom button
                Padding(
                  padding: const EdgeInsets.all(16),
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
                      : Semantics(
                          button: true,
                          label: state.canSave
                              ? '오늘의 기록 저장하기'
                              : '감정을 선택하고 답변을 입력해주세요',
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                            onPressed: state.canSave && !state.isSaving
                                ? () async {
                                    final isFirstSave = !state.isCompleted;
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final success = await ref
                                        .read(
                                            todayControllerProvider.notifier)
                                        .save();
                                    if (!mounted) return;
                                    if (success && isFirstSave) {
                                      setState(() =>
                                          _showCompletionAnimation = true);
                                    } else if (!success) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('저장에 실패했어요. 다시 시도해주세요.')),
                                      );
                                    }
                                  }
                                : null,
                            child: state.isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('기록 완료'),
                          ),
                        ),
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
