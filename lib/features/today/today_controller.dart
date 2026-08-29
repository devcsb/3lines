import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/journal_changes.dart';
import '../../core/services/photo_service.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/time/app_clock.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../data/models/daily_entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'today_state.dart';

class TodayController extends AsyncNotifier<TodayState> {
  static const _milestones = [7, 30, 100, 365];

  Timer? _midnightTimer;
  String _scheduledDate = '';

  @override
  Future<TodayState> build() async {
    ref.onDispose(() {
      _midnightTimer?.cancel();
    });

    final entryRepo = ref.watch(entryRepositoryProvider);
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    final clock = ref.watch(appClockProvider);
    _scheduledDate = clock.todayString();
    _scheduleMidnightRefresh();

    final now = clock.now();
    final results = await Future.wait([
      settingsRepo.getRotatingPrompts(),
      entryRepo.getTodayEntry(),
      entryRepo.getCurrentStreakWithGrace(),
      entryRepo.getOneYearAgoEntry(),
      entryRepo.getEmotionTrend(now.subtract(const Duration(days: 6)), now),
      entryRepo.getSixMonthsAgoEntry(),
      entryRepo.getOneMonthAgoEntry(),
    ]);

    final prompts = results[0] as List<String>;
    final todayEntry = results[1] as DailyEntry?;
    final streakResult = results[2] as ({int count, bool usedGraceDay});
    final oneYearAgo = results[3] as DailyEntry?;
    final recentTrend = results[4] as List<({DateTime date, int emotion})>;
    final sixMonthsAgo = results[5] as DailyEntry?;
    final oneMonthAgo = results[6] as DailyEntry?;

    if (todayEntry != null) {
      return TodayState(
        emotion: todayEntry.emotion,
        answer1: todayEntry.answer1,
        answer2: todayEntry.answer2,
        answer3: todayEntry.answer3,
        // A saved entry keeps the questions that were shown when it was
        // written.  Settings changes apply to future entries; replacing these
        // snapshots would make an existing answer appear under a different
        // question when the user revisits Today.
        prompts: [
          todayEntry.prompt1.trim().isNotEmpty
              ? todayEntry.prompt1
              : prompts[0],
          todayEntry.prompt2.trim().isNotEmpty
              ? todayEntry.prompt2
              : prompts[1],
          todayEntry.prompt3.trim().isNotEmpty
              ? todayEntry.prompt3
              : prompts[2],
        ],
        isCompleted: true,
        currentStreak: streakResult.count,
        usedGraceDay: streakResult.usedGraceDay,
        existingEntry: todayEntry,
        oneYearAgoEntry: oneYearAgo,
        sixMonthsAgoEntry: sixMonthsAgo,
        oneMonthAgoEntry: oneMonthAgo,
        photoPath: todayEntry.photoPath,
        recentEmotions: recentTrend,
      );
    }

    return TodayState(
      prompts: prompts,
      currentStreak: streakResult.count,
      usedGraceDay: streakResult.usedGraceDay,
      oneYearAgoEntry: oneYearAgo,
      sixMonthsAgoEntry: sixMonthsAgo,
      oneMonthAgoEntry: oneMonthAgo,
      recentEmotions: recentTrend,
    );
  }

  void setEmotion(int value) {
    final current = state.value;
    if (current == null ||
        current.isSaving ||
        current.isCancelling ||
        (current.isCompleted && !current.isEditing) ||
        value < 1 ||
        value > 5) {
      return;
    }
    state = AsyncData(current.copyWith(emotion: () => value));
  }

  void setAnswer(int index, String value) {
    final current = state.value;
    if (current == null ||
        current.isSaving ||
        current.isCancelling ||
        (current.isCompleted && !current.isEditing)) {
      return;
    }
    switch (index) {
      case 0:
        state = AsyncData(current.copyWith(answer1: value));
      case 1:
        state = AsyncData(current.copyWith(answer2: value));
      case 2:
        state = AsyncData(current.copyWith(answer3: value));
    }
  }

  /// Saves the current entry. Returns true on success, false on failure.
  Future<bool> save() async {
    final current = state.value;
    final emotion = current?.emotion;
    if (current == null ||
        emotion == null ||
        !current.canSave ||
        current.isSaving ||
        current.isCancelling ||
        (current.isCompleted && !current.isEditing)) {
      return false;
    }

    state = AsyncData(current.copyWith(isSaving: true));

    late final EntryRepository entryRepo;
    late final DailyEntry entry;
    try {
      entryRepo = ref.read(entryRepositoryProvider);

      entry = DailyEntry(
        id: current.existingEntry?.id,
        date: ref.read(appClockProvider).todayString(),
        emotion: emotion,
        prompt1: current.prompts[0],
        answer1: current.answer1,
        prompt2: current.prompts[1],
        answer2: current.answer2,
        prompt3: current.prompts[2],
        answer3: current.answer3,
        photoPath: current.photoPath,
      );

      await entryRepo.saveEntry(entry);
    } catch (e, stack) {
      developer.log('Failed to save entry', error: e, stackTrace: stack);
      state = AsyncData(current.copyWith(isSaving: false));
      return false;
    }

    // DB 저장이 성공한 후의 작업은 실패해도 이미 커밋된 기록을 되돌리지 않는다.
    final oldPhotoPath = current.existingEntry?.photoPath;
    if (oldPhotoPath != null && oldPhotoPath != current.photoPath) {
      try {
        final photoService = ref.read(photoServiceProvider);
        await photoService.deletePhoto(oldPhotoPath);
      } catch (e, stack) {
        developer.log(
          'Failed to delete replaced photo',
          error: e,
          stackTrace: stack,
        );
      }
    }

    var streakCount = current.currentStreak;
    var usedGraceDay = current.usedGraceDay;
    DailyEntry? saved = entry;
    int? milestone;
    try {
      final streakResult = await entryRepo.getCurrentStreakWithGrace();
      saved = await entryRepo.getTodayEntry() ?? entry;
      final totalCount = await entryRepo.getTotalCount();

      streakCount = streakResult.count;
      usedGraceDay = streakResult.usedGraceDay;
      for (final m in _milestones) {
        if (totalCount == m) {
          milestone = m;
          break;
        }
      }

      if (milestone != null) {
        final settingsRepo = ref.read(settingsRepositoryProvider);
        await settingsRepo.unlockMilestone(milestone);
        ref.invalidate(accentThemeProvider);
      }
    } catch (e, stack) {
      developer.log(
        'Failed to refresh post-save metadata',
        error: e,
        stackTrace: stack,
      );
    }

    state = AsyncData(
      current.copyWith(
        isCompleted: true,
        isEditing: false,
        isSaving: false,
        currentStreak: streakCount,
        usedGraceDay: usedGraceDay,
        existingEntry: () => saved,
        milestone: () => milestone,
      ),
    );

    ref.read(journalChangesProvider.notifier).markChanged();
    return true;
  }

  void toggleEdit() {
    final current = state.value;
    if (current == null || current.isSaving || current.isCancelling) return;
    state = AsyncData(current.copyWith(isEditing: !current.isEditing));
  }

  Future<void> cancelEdit() async {
    final current = state.value;
    final saved = current?.existingEntry;
    if (current == null ||
        saved == null ||
        !current.isEditing ||
        current.isSaving ||
        current.isCancelling) {
      return;
    }

    state = AsyncData(current.copyWith(isCancelling: true));

    final currentPhotoPath = current.photoPath;
    if (currentPhotoPath != null && currentPhotoPath != saved.photoPath) {
      final photoService = ref.read(photoServiceProvider);
      try {
        await photoService.deletePhoto(currentPhotoPath);
      } catch (e, stack) {
        developer.log(
          'Failed to discard unsaved photo',
          error: e,
          stackTrace: stack,
        );
      }
    }

    state = AsyncData(
      current.copyWith(
        emotion: () => saved.emotion,
        answer1: saved.answer1,
        answer2: saved.answer2,
        answer3: saved.answer3,
        photoPath: () => saved.photoPath,
        isEditing: false,
        isCancelling: false,
      ),
    );
  }

  Future<void> attachPhoto(String path) async {
    final current = state.value;
    if (current == null) return;
    if (current.isSaving ||
        current.isCancelling ||
        (current.isCompleted && !current.isEditing)) {
      await _discardUnattachedPhoto(path);
      return;
    }

    // 기존에 선택한 미저장 사진이 있으면 디스크에서 정리한다.
    // (DB에 저장된 사진과 동일한 경우는 삭제하지 않는다.)
    final previousPath = current.photoPath;
    final savedPath = current.existingEntry?.photoPath;
    state = AsyncData(current.copyWith(photoPath: () => path));

    if (previousPath != null && previousPath != savedPath) {
      await _discardUnattachedPhoto(previousPath);
    }
  }

  Future<void> removePhoto() async {
    final current = state.value;
    if (current == null ||
        current.isSaving ||
        current.isCancelling ||
        (current.isCompleted && !current.isEditing) ||
        current.photoPath == null) {
      return;
    }

    state = AsyncData(current.copyWith(photoPath: () => null));

    // DB에 저장된 사진은 여기서 삭제하지 않는다. save()가 DB 트랜잭션
    // 성공 후 정리한다. 미저장 사진만 파일 정리를 시도한다.
    final savedPath = current.existingEntry?.photoPath;
    if (current.photoPath != savedPath) {
      try {
        final photoService = ref.read(photoServiceProvider);
        await photoService.deletePhoto(current.photoPath!);
      } catch (e, stack) {
        developer.log(
          'Failed to delete removed photo',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  Future<void> _discardUnattachedPhoto(String path) async {
    try {
      await ref.read(photoServiceProvider).deletePhoto(path);
    } catch (e, stack) {
      developer.log(
        'Failed to discard unattached photo',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  /// Called by the view when the app returns from background.
  /// Refreshes data if the day has rolled over while the app was suspended,
  /// then re-arms the midnight timer.
  void onAppResumed() {
    final today = ref.read(appClockProvider).todayString();
    if (today != _scheduledDate) {
      _scheduledDate = today;
      refresh();
    } else {
      _scheduleMidnightRefresh();
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final clock = ref.read(appClockProvider);
    final now = clock.now();
    final nextMidnight = clock.nextMidnight();
    final duration = nextMidnight.difference(now);

    _midnightTimer = Timer(duration, () {
      _scheduledDate = du.getTodayString();
      refresh();
    });
  }
}

final todayControllerProvider =
    AsyncNotifierProvider<TodayController, TodayState>(
      TodayController.new,
      isAutoDispose: true,
    );
