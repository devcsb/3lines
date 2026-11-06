import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'today_state.dart';
import '../../data/models/journal_draft.dart';
import '../../data/repositories/entry_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/default_prompts.dart';
import '../../core/theme/app_motion.dart';
import '../../core/time/app_clock.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../shared/widgets/staggered_fade_in.dart';
import 'today_controller.dart';
import '../bookmarks/bookmark_button.dart';
import '../../core/services/photo_service.dart';
import 'widgets/animated_save_button.dart';
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
  int _exampleAction = 0;
  Future<void> _pickPhoto({required bool camera, TodayState? retryFor}) async {
    final controller = ref.read(todayControllerProvider.notifier);
    final started = controller.capturePhotoSession();
    if (started == null ||
        started.isSaving ||
        started.isCancelling ||
        started.isSwitchingDate ||
        (started.isCompleted && !started.isEditing)) {
      return;
    }
    if (retryFor != null &&
        (started.session != retryFor.session ||
            started.draftDate != retryFor.draftDate ||
            started.epoch != retryFor.epoch)) {
      return;
    }
    final photos = ref.read(photoServiceProvider);
    final entries = ref.read(entryRepositoryProvider);
    final result = camera
        ? await photos.pickFromCameraResult()
        : await photos.pickFromGalleryResult();
    if (result.status == PhotoPickStatus.selected && result.path != null) {
      if (!mounted) {
        await photos.deleteUnreferencedPhoto(
          result.path!,
          readReferences: entries.getAllPhotoPaths,
        );
        return;
      }
      await ref
          .read(todayControllerProvider.notifier)
          .attachPhoto(result.path!, started: started);
      return;
    }
    if (!mounted) return;
    final active = ref
        .read(todayControllerProvider.notifier)
        .capturePhotoSession();
    if (active == null ||
        active.session != started.session ||
        active.draftDate != started.draftDate ||
        active.epoch != started.epoch ||
        active.draftRevision != started.draftRevision ||
        entries.journalEpoch != started.epoch) {
      return;
    }
    if (result.status == PhotoPickStatus.cancelled) {
      // A cancelled picker must not close an unrelated Undo notice.
      return;
    }
    final message = switch (result.status) {
      PhotoPickStatus.permissionDenied =>
        '사진을 선택하지 못했어요. 기기 설정에서 사진이나 카메라 권한을 확인하고 다시 시도해주세요. 글과 기존 사진은 유지했어요.',
      PhotoPickStatus.copyFailed =>
        '사진을 보관하지 못했어요. 글과 기존 사진은 유지했어요. 다시 시도해주세요.',
      _ => '사진을 선택하지 못했어요. 글과 기존 사진은 유지했어요. 다시 시도해주세요.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          showCloseIcon: true,
          action: SnackBarAction(
            label: '다시 시도',
            onPressed: () {
              // SnackBarAction closes this notice itself before retrying.
              _pickPhoto(camera: camera, retryFor: started);
            },
          ),
        ),
      );
  }

  bool _showReflection = false;
  bool _saveFailed = false;
  final _answerFocusNodes = List.generate(3, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final node in _answerFocusNodes) {
      node.dispose();
    }
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
    final now = ref.read(appClockProvider).now();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: asyncState.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('데이터를 불러올 수 없어요', style: theme.textTheme.bodyLarge),
              if (error is CorruptDraft) ...[
                Text(
                  '${RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(error.date) ? error.date : '날짜 확인 불가'} 초안을 읽지 못했어요',
                ),
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        scrollable: true,
                        title: const Text('읽지 못한 초안을 폐기할까요?'),
                        content: const Text(
                          '이 초안만 지워요. 저장된 기록과 다른 초안은 유지해요. 안전하게 확인할 수 없는 사진 파일은 남겨둬요.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('돌아가기'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('이 초안만 폐기'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      final success = await ref
                          .read(todayControllerProvider.notifier)
                          .discardCorruptDraft(error);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('초안이 바뀌었거나 폐기하지 못했어요. 다시 불러와주세요.'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('읽지 못한 초안 폐기'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(todayControllerProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (state) {
          final isReadMode = state.isCompleted && !state.isEditing;
          final isInteractionLocked =
              isReadMode ||
              state.isSaving ||
              state.isCancelling ||
              state.isSwitchingDate;

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      MediaQuery.sizeOf(context).width > 640
                          ? (MediaQuery.sizeOf(context).width - 600) / 2
                          : 20,
                      16,
                      MediaQuery.sizeOf(context).width > 640
                          ? (MediaQuery.sizeOf(context).width - 600) / 2
                          : 20,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          du.formatKoreanDate(
                            DateTime.tryParse(state.draftDate) ?? now,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (state.draftDate !=
                            ref.read(appClockProvider).todayString())
                          TextButton(
                            onPressed:
                                state.isSwitchingDate ||
                                    state.isSaving ||
                                    state.isCancelling
                                ? null
                                : () => ref
                                      .read(todayControllerProvider.notifier)
                                      .startToday(),
                            child: const Text('오늘 작성하기'),
                          ),
                        if (state.draftDates.isNotEmpty)
                          Wrap(
                            children: [
                              for (final date in state.draftDates)
                                TextButton(
                                  onPressed:
                                      state.isSwitchingDate ||
                                          state.isSaving ||
                                          state.isCancelling
                                      ? null
                                      : () => ref
                                            .read(
                                              todayControllerProvider.notifier,
                                            )
                                            .selectDate(date),
                                  child: Text('$date 보관 초안'),
                                ),
                            ],
                          ),
                        if (state.storageStatus == DraftStorageStatus.storing)
                          const Text('초안 보관 중…'),
                        if (state.storageStatus == DraftStorageStatus.stored)
                          const Text('초안 보관됨'),
                        if (state.draftError != null) ...[
                          Text(state.draftError!),
                          if (state.storageStatus == DraftStorageStatus.failed)
                            TextButton(
                              onPressed: isInteractionLocked
                                  ? null
                                  : () => ref
                                        .read(todayControllerProvider.notifier)
                                        .retryDraftStorage(),
                              child: const Text('초안 보관 다시 시도'),
                            ),
                        ],
                        if (state.hasConflict) ...[
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text:
                                      '${state.draftDate}\n${state.answer1}\n${state.answer2}\n${state.answer3}',
                                ),
                              );
                            },
                            child: const Text('입력 내용 복사'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('현재 초안을 폐기할까요?'),
                                  content: const Text(
                                    '필요한 입력을 먼저 복사해주세요. 저장된 기록을 다시 엽니다.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('돌아가기'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('폐기하고 다시 열기'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && mounted) {
                                await ref
                                    .read(todayControllerProvider.notifier)
                                    .reopenSavedEntry();
                              }
                            },
                            child: const Text('저장된 기록 다시 열기'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          isReadMode ? '오늘 남겨둔 마음' : '여기에 꺼내놓아도 괜찮아요',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isReadMode
                              ? '다시 쓰고 싶을 때 언제든 수정할 수 있어요.'
                              : '말하지 못했던 이야기, 정리되지 않은 마음도 괜찮아요.\n짧게 적어도, 길게 이어가도 좋아요.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isReadMode) ...[
                          if (state.existingEntry != null) ...[
                            const SizedBox(height: 16),
                            BookmarkButton(
                              key: ValueKey(state.existingEntry!.date),
                              date: state.existingEntry!.date,
                            ),
                          ],
                          const SizedBox(height: 20),
                          TweenAnimationBuilder<double>(
                            key: const ValueKey('read-mode-badge'),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: AppMotion.durationFor(
                              context,
                              AppMotion.micro,
                            ),
                            builder: (context, value, child) =>
                                Opacity(opacity: value, child: child),
                            child: Semantics(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '오늘의 기록',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),

                        // Emotion picker
                        EmotionPicker(
                          selectedEmotion: state.emotion,
                          onSelected: (v) => ref
                              .read(todayControllerProvider.notifier)
                              .setEmotion(v),
                          enabled: !isInteractionLocked,
                        ),

                        const SizedBox(height: 20),

                        if (!isReadMode) ...[
                          Text(
                            '질문은 시작을 도울 뿐이에요. 하고 싶은 이야기를 적어주세요.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (isReadMode && state.filledAnswerCount == 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              '마음만 남긴 기록이에요. 원하면 글을 더할 수 있어요.',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        // Prompt cards with suggestions
                        ...List.generate(
                          isReadMode && state.filledAnswerCount == 0 ? 0 : 3,
                          (index) {
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
                                      key: ValueKey(
                                        'answer-${state.session}-${state.draftDate}-${state.epoch}-$index',
                                      ),
                                      index: index,
                                      focusNode: _answerFocusNodes[index],
                                      question: state.prompts[index],
                                      answer: answer,
                                      readOnly: isInteractionLocked,
                                      onChanged: isInteractionLocked
                                          ? null
                                          : (v) => ref
                                                .read(
                                                  todayControllerProvider
                                                      .notifier,
                                                )
                                                .setAnswer(index, v),
                                    ),
                                    // Suggestion chips (edit mode)
                                    if (!isInteractionLocked &&
                                        isBuiltInPrompt(
                                          index,
                                          state.prompts[index],
                                        )) ...[
                                      const SizedBox(height: 8),
                                      PromptSuggestions(
                                        promptIndex: index,
                                        onTap: (suggestion) {
                                          final action = ++_exampleAction;
                                          final controller = ref.read(
                                            todayControllerProvider.notifier,
                                          );
                                          final before = controller
                                              .capturePhotoSession();
                                          if (before == null) return;
                                          final prev = [
                                            before.answer1,
                                            before.answer2,
                                            before.answer3,
                                          ][index];
                                          final next = prev.trim().isEmpty
                                              ? suggestion
                                              : '$prev $suggestion';
                                          controller.setAnswer(index, next);
                                          final inserted = controller
                                              .capturePhotoSession();
                                          if (inserted != null &&
                                              inserted.draftRevision ==
                                                  before.draftRevision + 1) {
                                            ScaffoldMessenger.of(context)
                                              ..hideCurrentSnackBar()
                                              ..showSnackBar(
                                                SnackBar(
                                                  showCloseIcon: true,
                                                  content: const Text(
                                                    '제안을 추가했어요',
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 3,
                                                  ),
                                                  action: SnackBarAction(
                                                    label: '되돌리기',
                                                    onPressed: () {
                                                      if (mounted &&
                                                          action ==
                                                              _exampleAction) {
                                                        controller.undoExample(
                                                          index,
                                                          prev,
                                                          inserted,
                                                        );
                                                      }
                                                    },
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
                          },
                        ),
                        const SizedBox(height: 8),
                        // Photo attachment
                        PhotoAttachment(
                          photoPath: state.photoPath,
                          readOnly: isInteractionLocked,
                          onPickCamera: () => _pickPhoto(camera: true),
                          onPickGallery: () => _pickPhoto(camera: false),
                          onRemove: () => ref
                              .read(todayControllerProvider.notifier)
                              .removePhoto(),
                        ),

                        const SizedBox(height: 28),

                        if (state.currentStreak > 0 ||
                            state.milestone != null ||
                            state.recentEmotions.isNotEmpty ||
                            state.oneYearAgoEntry != null ||
                            state.sixMonthsAgoEntry != null ||
                            state.oneMonthAgoEntry != null) ...[
                          const Divider(),
                          Semantics(
                            expanded: _showReflection,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                () => _showReflection = !_showReflection,
                              ),
                              icon: Icon(
                                _showReflection
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              label: const Text('지난 기록 돌아보기'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                            ),
                          ),
                          if (_showReflection) ...[
                            Text(
                              '돌아보고 싶은 날에만 천천히 살펴보세요.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (state.currentStreak > 0)
                              StreakPulseBadge(
                                streak: state.currentStreak,
                                usedGraceDay: state.usedGraceDay,
                              ),
                            if (state.milestone != null) ...[
                              const SizedBox(height: 16),
                              MilestoneBanner(milestone: state.milestone!),
                            ],
                            if (state.recentEmotions.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _MiniSparkline(
                                recentEmotions: state.recentEmotions,
                                now: now,
                              ),
                            ],
                            const SizedBox(height: 16),
                            OneYearAgoCard(
                              entry: state.oneYearAgoEntry,
                              sixMonthsAgoEntry: state.sixMonthsAgoEntry,
                              oneMonthAgoEntry: state.oneMonthAgoEntry,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: isReadMode
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    '기록을 저장했어요',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => ref
                                      .read(todayControllerProvider.notifier)
                                      .toggleEdit(),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text(
                                    '수정하기',
                                    semanticsLabel: '오늘의 기록 수정하기',
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                AnimatedSaveButton(
                                  emotionSelected: state.emotion != null,
                                  filledCount: state.filledAnswerCount,
                                  canSave:
                                      state.canSave &&
                                      !state.isCancelling &&
                                      !state.isSwitchingDate,
                                  isSaving: state.isSaving,
                                  isCancelling: state.isCancelling,
                                  guidanceMessage: state.isCancelling
                                      ? '변경을 취소하고 있어요'
                                      : _saveFailed
                                      ? '아직 저장하지 못했어요. 내용은 화면에 남아 있어요. 다시 눌러 주세요.'
                                      : state.saveGuidanceMessage,
                                  onPressed: () async {
                                    setState(() => _saveFailed = false);
                                    final success = await ref
                                        .read(todayControllerProvider.notifier)
                                        .save();
                                    if (!context.mounted) return;
                                    final live = ref
                                        .read(todayControllerProvider)
                                        .value;
                                    if (live?.session != state.session ||
                                        live?.draftDate != state.draftDate) {
                                      return;
                                    }
                                    if (success) {
                                      FocusScope.of(context).unfocus();
                                    }
                                    if (!success) {
                                      setState(() => _saveFailed = true);
                                    }
                                  },
                                ),
                                if (state.isCompleted && state.isEditing) ...[
                                  const SizedBox(height: 4),
                                  TextButton.icon(
                                    onPressed:
                                        state.isSaving || state.isCancelling
                                        ? null
                                        : () async {
                                            setState(() => _saveFailed = false);
                                            FocusScope.of(context).unfocus();
                                            await ref
                                                .read(
                                                  todayControllerProvider
                                                      .notifier,
                                                )
                                                .cancelEdit();
                                          },
                                    icon: const Icon(Icons.close),
                                    label: const Text('수정 취소'),
                                  ),
                                ],
                              ],
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

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.recentEmotions, required this.now});

  final List<({DateTime date, int emotion})> recentEmotions;
  final DateTime now;

  static const _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                  .where(
                    (e) =>
                        '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}' ==
                        dateStr,
                  )
                  .firstOrNull;
              final emotion = emotionEntry?.emotion;
              final color = emotion != null
                  ? AppColors.emotionColors[emotion]!
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4);
              final isToday =
                  day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;

              final semanticLabel = emotion != null
                  ? '${day.month}월 ${day.day}일, ${AppColors.emotionLabels[emotion]} $emotion점'
                  : '${day.month}월 ${day.day}일, 기록 없음';

              return Semantics(
                container: true,
                excludeSemantics: true,
                label: semanticLabel,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.durationFor(
                        context,
                        AppMotion.standard,
                      ),
                      curve: AppMotion.standardCurve,
                      width: emotion != null ? 28 : 22,
                      height: emotion != null ? 28 : 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(
                          alpha: emotion != null ? 0.85 : 0.25,
                        ),
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
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
