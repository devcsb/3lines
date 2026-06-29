import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_notifier.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../data/models/daily_entry.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/photo_service.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../insights/insights_controller.dart';
import '../settings/settings_controller.dart';
import '../timeline/timeline_controller.dart';

class TodayState {
  final int? emotion;
  final String answer1;
  final String answer2;
  final String answer3;
  final List<String> prompts;
  final bool isCompleted;
  final bool isEditing;
  final int currentStreak;
  final bool usedGraceDay;
  final DailyEntry? existingEntry;
  final bool isSaving;
  final DailyEntry? oneYearAgoEntry;
  final DailyEntry? sixMonthsAgoEntry;
  final DailyEntry? oneMonthAgoEntry;
  final int? milestone; // non-null when a milestone is reached (7, 30, 100, 365)
  final String? photoPath;
  final List<({DateTime date, int emotion})> recentEmotions;

  const TodayState({
    this.emotion,
    this.answer1 = '',
    this.answer2 = '',
    this.answer3 = '',
    this.prompts = const ['', '', ''],
    this.isCompleted = false,
    this.isEditing = false,
    this.currentStreak = 0,
    this.usedGraceDay = false,
    this.existingEntry,
    this.isSaving = false,
    this.oneYearAgoEntry,
    this.sixMonthsAgoEntry,
    this.oneMonthAgoEntry,
    this.milestone,
    this.photoPath,
    this.recentEmotions = const [],
  });

  bool get canSave => emotion != null && (answer1.isNotEmpty || answer2.isNotEmpty || answer3.isNotEmpty);

  TodayState copyWith({
    int? Function()? emotion,
    String? answer1,
    String? answer2,
    String? answer3,
    List<String>? prompts,
    bool? isCompleted,
    bool? isEditing,
    int? currentStreak,
    bool? usedGraceDay,
    DailyEntry? Function()? existingEntry,
    bool? isSaving,
    DailyEntry? Function()? oneYearAgoEntry,
    DailyEntry? Function()? sixMonthsAgoEntry,
    DailyEntry? Function()? oneMonthAgoEntry,
    int? Function()? milestone,
    String? Function()? photoPath,
    List<({DateTime date, int emotion})>? recentEmotions,
  }) {
    return TodayState(
      emotion: emotion != null ? emotion() : this.emotion,
      answer1: answer1 ?? this.answer1,
      answer2: answer2 ?? this.answer2,
      answer3: answer3 ?? this.answer3,
      prompts: prompts ?? this.prompts,
      isCompleted: isCompleted ?? this.isCompleted,
      isEditing: isEditing ?? this.isEditing,
      currentStreak: currentStreak ?? this.currentStreak,
      usedGraceDay: usedGraceDay ?? this.usedGraceDay,
      existingEntry: existingEntry != null ? existingEntry() : this.existingEntry,
      isSaving: isSaving ?? this.isSaving,
      oneYearAgoEntry: oneYearAgoEntry != null ? oneYearAgoEntry() : this.oneYearAgoEntry,
      sixMonthsAgoEntry: sixMonthsAgoEntry != null ? sixMonthsAgoEntry() : this.sixMonthsAgoEntry,
      oneMonthAgoEntry: oneMonthAgoEntry != null ? oneMonthAgoEntry() : this.oneMonthAgoEntry,
      milestone: milestone != null ? milestone() : this.milestone,
      photoPath: photoPath != null ? photoPath() : this.photoPath,
      recentEmotions: recentEmotions ?? this.recentEmotions,
    );
  }
}

class TodayController extends AsyncNotifier<TodayState> {
  static const _milestones = [7, 30, 100, 365];

  Timer? _midnightTimer;
  String _scheduledDate = du.getTodayString();

  @override
  Future<TodayState> build() async {
    ref.onDispose(() {
      _midnightTimer?.cancel();
    });

    _scheduleMidnightRefresh();

    final entryRepo = ref.watch(entryRepositoryProvider);
    final settingsRepo = ref.watch(settingsRepositoryProvider);

    final now = DateTime.now();
    final results = await Future.wait([
      settingsRepo.getRotatingPrompts(),
      entryRepo.getTodayEntry(),
      entryRepo.getCurrentStreakWithGrace(),
      entryRepo.getOneYearAgoEntry(),
      entryRepo.getEmotionTrend(
        now.subtract(const Duration(days: 6)),
        now,
      ),
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
        prompts: prompts,
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
    if (current == null || value < 1 || value > 5) return;
    state = AsyncData(current.copyWith(emotion: () => value));
  }

  void setAnswer(int index, String value) {
    final current = state.value;
    if (current == null) return;
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
    if (current == null || emotion == null || !current.canSave || current.isSaving) return false;

    state = AsyncData(current.copyWith(isSaving: true));

    try {
      final entryRepo = ref.read(entryRepositoryProvider);

      final entry = DailyEntry(
        id: current.existingEntry?.id,
        date: du.getTodayString(),
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

      // DB 저장이 성공한 후에 이전 사진 파일을 삭제한다.
      // 저장 전에 삭제하면 saveEntry() 실패 시 파일을 복구할 수 없다.
      final oldPhotoPath = current.existingEntry?.photoPath;
      if (oldPhotoPath != null && oldPhotoPath != current.photoPath) {
        final photoService = ref.read(photoServiceProvider);
        await photoService.deletePhoto(oldPhotoPath);
      }

      final streakResult = await entryRepo.getCurrentStreakWithGrace();
      final saved = await entryRepo.getTodayEntry();
      final totalCount = await entryRepo.getTotalCount();

      // Check if this save hits a milestone
      int? milestone;
      for (final m in _milestones) {
        if (totalCount == m) {
          milestone = m;
          break;
        }
      }

      // Unlock milestone accent theme when a milestone is reached
      if (milestone != null) {
        final settingsRepo = ref.read(settingsRepositoryProvider);
        await settingsRepo.unlockMilestone(milestone);
        // Refresh the accent theme provider so AppearanceSection updates
        ref.invalidate(accentThemeProvider);
      }

      state = AsyncData(current.copyWith(
        isCompleted: true,
        isEditing: false,
        isSaving: false,
        currentStreak: streakResult.count,
        usedGraceDay: streakResult.usedGraceDay,
        existingEntry: () => saved,
        milestone: () => milestone,
      ));

      // Reschedule reminder: cancel today's and ensure tomorrow's fires
      final settings = ref.read(settingsControllerProvider).value;
      if (settings != null && settings.reminderEnabled) {
        final notifService = ref.read(notificationServiceProvider);
        // Personalize tomorrow's notification with today's gratitude answer
        final todayAnswer = entry.answer1.trim();
        final notifBody = todayAnswer.isNotEmpty
            ? '어제의 감사: "${todayAnswer.length > 30 ? '${todayAnswer.substring(0, 30)}…' : todayAnswer}"'
            : null;
        await notifService.scheduleDailyReminder(
          hour: settings.reminderHour,
          minute: settings.reminderMinute,
          body: notifBody,
        );
        // Streak is safe now — cancel today's at-risk notification
        await notifService.cancelStreakAtRiskReminder();
      }

      // Invalidate dependent screens so they reload fresh data
      ref.invalidate(timelineControllerProvider);
      ref.invalidate(insightsControllerProvider);
      return true;
    } catch (e, stack) {
      developer.log('Failed to save entry', error: e, stackTrace: stack);
      state = AsyncData(current.copyWith(isSaving: false));
      return false;
    }
  }

  void toggleEdit() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(isEditing: !current.isEditing));
  }

  void attachPhoto(String path) {
    final current = state.value;
    if (current == null) return;

    // 기존에 선택한 미저장 사진이 있으면 디스크에서 정리한다.
    // (DB에 저장된 사진과 동일한 경우는 삭제하지 않는다.)
    final previousPath = current.photoPath;
    final savedPath = current.existingEntry?.photoPath;
    if (previousPath != null && previousPath != savedPath) {
      final photoService = ref.read(photoServiceProvider);
      photoService.deletePhoto(previousPath);
    }

    state = AsyncData(current.copyWith(photoPath: () => path));
  }

  Future<void> removePhoto() async {
    final current = state.value;
    if (current == null || current.photoPath == null) return;

    // DB에 저장된 사진은 여기서 삭제하지 않는다.
    // save() 호출 시 DB 트랜잭션 성공 후에 정리된다.
    // 미저장 사진(새로 첨부했지만 아직 save() 전인 사진)만 즉시 삭제하여
    // storage leak를 방지한다.
    final savedPath = current.existingEntry?.photoPath;
    if (current.photoPath != savedPath) {
      final photoService = ref.read(photoServiceProvider);
      await photoService.deletePhoto(current.photoPath!);
    }

    state = AsyncData(current.copyWith(photoPath: () => null));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  /// Called by the view when the app returns from background.
  /// Refreshes data if the day has rolled over while the app was suspended,
  /// then re-arms the midnight timer.
  void onAppResumed() {
    final today = du.getTodayString();
    if (today != _scheduledDate) {
      _scheduledDate = today;
      refresh();
    } else {
      _scheduleMidnightRefresh();
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now);

    _midnightTimer = Timer(duration, () {
      _scheduledDate = du.getTodayString();
      refresh();
    });
  }
}

final todayControllerProvider =
    AsyncNotifierProvider<TodayController, TodayState>(
        TodayController.new, isAutoDispose: true);
