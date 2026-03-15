import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' as du;
import '../../data/models/daily_entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../insights/insights_controller.dart';
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
  final DailyEntry? existingEntry;
  final bool isSaving;

  const TodayState({
    this.emotion,
    this.answer1 = '',
    this.answer2 = '',
    this.answer3 = '',
    this.prompts = const ['', '', ''],
    this.isCompleted = false,
    this.isEditing = false,
    this.currentStreak = 0,
    this.existingEntry,
    this.isSaving = false,
  });

  bool get canSave => emotion != null && (answer1.isNotEmpty || answer2.isNotEmpty || answer3.isNotEmpty);

  TodayState copyWith({
    int? emotion,
    String? answer1,
    String? answer2,
    String? answer3,
    List<String>? prompts,
    bool? isCompleted,
    bool? isEditing,
    int? currentStreak,
    DailyEntry? existingEntry,
    bool? isSaving,
  }) {
    return TodayState(
      emotion: emotion ?? this.emotion,
      answer1: answer1 ?? this.answer1,
      answer2: answer2 ?? this.answer2,
      answer3: answer3 ?? this.answer3,
      prompts: prompts ?? this.prompts,
      isCompleted: isCompleted ?? this.isCompleted,
      isEditing: isEditing ?? this.isEditing,
      currentStreak: currentStreak ?? this.currentStreak,
      existingEntry: existingEntry ?? this.existingEntry,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class TodayController extends AsyncNotifier<TodayState> {
  @override
  Future<TodayState> build() async {
    final entryRepo = ref.read(entryRepositoryProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);

    final prompts = await settingsRepo.getPrompts();
    final todayEntry = await entryRepo.getTodayEntry();
    final streak = await entryRepo.getCurrentStreak();

    if (todayEntry != null) {
      return TodayState(
        emotion: todayEntry.emotion,
        answer1: todayEntry.answer1,
        answer2: todayEntry.answer2,
        answer3: todayEntry.answer3,
        prompts: prompts,
        isCompleted: true,
        currentStreak: streak,
        existingEntry: todayEntry,
      );
    }

    return TodayState(
      prompts: prompts,
      currentStreak: streak,
    );
  }

  void setEmotion(int value) {
    final current = state.valueOrNull;
    if (current == null || value < 1 || value > 5) return;
    state = AsyncData(current.copyWith(emotion: value));
  }

  void setAnswer(int index, String value) {
    final current = state.valueOrNull;
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
    final current = state.valueOrNull;
    if (current == null || !current.canSave || current.isSaving) return false;

    state = AsyncData(current.copyWith(isSaving: true));

    try {
      final entryRepo = ref.read(entryRepositoryProvider);

      final entry = DailyEntry(
        id: current.existingEntry?.id,
        date: du.getTodayString(),
        emotion: current.emotion!,
        prompt1: current.prompts[0],
        answer1: current.answer1,
        prompt2: current.prompts[1],
        answer2: current.answer2,
        prompt3: current.prompts[2],
        answer3: current.answer3,
      );

      await entryRepo.saveEntry(entry);
      final streak = await entryRepo.getCurrentStreak();
      final saved = await entryRepo.getTodayEntry();

      state = AsyncData(current.copyWith(
        isCompleted: true,
        isEditing: false,
        isSaving: false,
        currentStreak: streak,
        existingEntry: saved,
      ));

      // Invalidate dependent screens so they reload fresh data
      ref.invalidate(timelineControllerProvider);
      ref.invalidate(insightsControllerProvider);
      return true;
    } catch (_) {
      state = AsyncData(current.copyWith(isSaving: false));
      return false;
    }
  }

  void toggleEdit() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(isEditing: !current.isEditing));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }
}

final todayControllerProvider =
    AsyncNotifierProvider<TodayController, TodayState>(TodayController.new);
