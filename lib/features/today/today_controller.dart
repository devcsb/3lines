import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/journal_changes.dart';
import '../../core/services/photo_service.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/time/app_clock.dart';
import '../../data/models/daily_entry.dart';
import '../../data/models/journal_draft.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'today_state.dart';

class TodayController extends AsyncNotifier<TodayState> {
  static const _milestones = [7, 30, 100, 365];

  Timer? _midnightTimer;
  String _scheduledDate = '';
  static int _nextSession = 0;
  int _session = ++_nextSession;
  int _selectionRequest = 0;

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
      return _restoreDraft(
        TodayState(
          draftDate: _scheduledDate,
          session: _session = ++_nextSession,
          epoch: entryRepo.journalEpoch,
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
        ),
      );
    }

    return _restoreDraft(
      TodayState(
        draftDate: _scheduledDate,
        session: _session = ++_nextSession,
        epoch: entryRepo.journalEpoch,
        prompts: prompts,
        currentStreak: streakResult.count,
        usedGraceDay: streakResult.usedGraceDay,
        oneYearAgoEntry: oneYearAgo,
        sixMonthsAgoEntry: sixMonthsAgo,
        oneMonthAgoEntry: oneMonthAgo,
        recentEmotions: recentTrend,
      ),
    );
  }

  Future<TodayState> _restoreDraft(TodayState initial) async {
    final drafts = await ref.read(entryRepositoryProvider).listDrafts();
    final matching = drafts.where((d) => d.date == initial.draftDate);
    final draft = matching.isNotEmpty ? matching.first : drafts.firstOrNull;
    if (draft == null) return initial.copyWith(draftDates: const []);
    return _withDraft(
      initial,
      draft,
    ).copyWith(draftDates: drafts.map((d) => d.date).toList());
  }

  TodayState _withDraft(TodayState initial, JournalDraft draft) =>
      initial.copyWith(
        draftDate: draft.date,
        draftRevision: draft.revision,
        emotion: () => draft.emotion,
        answer1: draft.answers[0],
        answer2: draft.answers[1],
        answer3: draft.answers[2],
        prompts: draft.prompts,
        photoPath: () => draft.photoPath,
        existingEntry: () => draft.baseline,
        isCompleted: draft.baseline != null,
        isEditing: draft.baseline != null,
        storageStatus: DraftStorageStatus.stored,
      );

  JournalDraft _snapshot(TodayState current) => JournalDraft(
    date: current.draftDate,
    revision: current.draftRevision,
    prompts: current.prompts,
    answers: [current.answer1, current.answer2, current.answer3],
    emotion: current.emotion,
    photoPath: current.photoPath,
    baseline: current.existingEntry,
  );

  bool _matches(TodayState started) {
    if (!ref.mounted) return false;
    final live = state.value;
    return ref.mounted &&
        live != null &&
        live.session == started.session &&
        _session == started.session &&
        live.draftDate == started.draftDate &&
        live.draftRevision == started.draftRevision &&
        live.epoch == started.epoch &&
        ref.read(entryRepositoryProvider).journalEpoch == started.epoch;
  }

  void _changed(TodayState next) {
    final changed = next.copyWith(
      draftRevision: next.draftRevision + 1,
      storageStatus: DraftStorageStatus.storing,
      draftError: () => null,
    );
    state = AsyncData(changed);
    unawaited(_store(changed));
  }

  Future<bool> _store(TodayState started) async {
    // Writes retain the controller until the DB acknowledgement, even if the view closes.
    final retain = ref.keepAlive();
    try {
      await ref
          .read(entryRepositoryProvider)
          .storeDraft(_snapshot(started), epoch: started.epoch);
      if (_matches(started)) {
        state = AsyncData(
          state.value!.copyWith(
            storageStatus: DraftStorageStatus.stored,
            draftError: () => null,
            draftDates: {...state.value!.draftDates, started.draftDate}.toList()
              ..sort(),
          ),
        );
      }
      return true;
    } catch (e) {
      if (_matches(started)) {
        state = AsyncData(
          state.value!.copyWith(
            storageStatus: DraftStorageStatus.failed,
            draftError: () => '초안을 보관하지 못했어요. 입력은 그대로 남아 있어요.',
          ),
        );
      }
      return false;
    } finally {
      retain.close();
    }
  }

  Future<bool> retryDraftStorage() async {
    final current = state.value;
    if (current == null || current.draftRevision == 0) return false;
    state = AsyncData(
      current.copyWith(storageStatus: DraftStorageStatus.storing),
    );
    return _store(current);
  }

  /// Captured before launching a picker. Late results never attach to another session.
  TodayState? capturePhotoSession() => state.value;

  Future<void> selectDate(String date) async {
    final started = state.value;
    if (started == null) return;
    final request = _selectionRequest + 1;
    final retain = ref.keepAlive();
    try {
      await _selectDate(date);
    } catch (e, stack) {
      developer.log('Failed to open draft date', error: e, stackTrace: stack);
      if (ref.mounted &&
          request == _selectionRequest &&
          state.value?.session == started.session &&
          ref.read(entryRepositoryProvider).journalEpoch == started.epoch) {
        _session = started.session;
        state = AsyncData(
          state.value!.copyWith(
            draftError: () =>
                '초안 날짜를 불러오지 못했어요. 입력은 남아 있어요. 날짜 버튼으로 다시 시도해주세요.',
          ),
        );
      }
    } finally {
      retain.close();
    }
  }

  Future<void> _selectDate(String date) async {
    final current = state.value;
    if (current == null) return;
    final request = ++_selectionRequest;
    if (current.draftRevision > 0 &&
        !current.isSaving &&
        !current.isCancelling &&
        !(current.isCompleted && !current.isEditing)) {
      if (!await _store(current)) return;
    }
    final live = state.value;
    if (!ref.mounted ||
        request != _selectionRequest ||
        live == null ||
        live.session != current.session ||
        live.draftRevision != current.draftRevision ||
        ref.read(entryRepositoryProvider).journalEpoch != current.epoch)
      return;
    final session = _session = ++_nextSession;
    final repo = ref.read(entryRepositoryProvider);
    final epoch = repo.journalEpoch;
    final drafts = await repo.listDrafts();
    final draft = drafts.where((d) => d.date == date).firstOrNull;
    final saved = await repo.getEntryByDate(date);
    final prompts = saved == null
        ? await ref.read(settingsRepositoryProvider).getRotatingPrompts()
        : [saved.prompt1, saved.prompt2, saved.prompt3];
    if (!ref.mounted || session != _session || epoch != repo.journalEpoch)
      return;
    var next = TodayState(
      draftDate: date,
      session: session,
      epoch: epoch,
      prompts: prompts,
      emotion: saved?.emotion,
      answer1: saved?.answer1 ?? '',
      answer2: saved?.answer2 ?? '',
      answer3: saved?.answer3 ?? '',
      photoPath: saved?.photoPath,
      existingEntry: saved,
      isCompleted: saved != null,
      currentStreak: current.currentStreak,
      usedGraceDay: current.usedGraceDay,
      draftDates: drafts.map((d) => d.date).toList(),
    );
    if (draft != null) next = _withDraft(next, draft);
    state = AsyncData(next);
  }

  Future<void> startToday() =>
      selectDate(ref.read(appClockProvider).todayString());

  Future<bool> reopenSavedEntry() async {
    final current = state.value;
    if (current == null) return false;
    try {
      await ref
          .read(entryRepositoryProvider)
          .discardDraft(
            current.draftDate,
            revision: current.draftRevision,
            epoch: current.epoch,
          );
      if (!_matches(current)) return false;
      // Explicit confirmed discard is the only way to replace conflict input.
      state = AsyncData(current.copyWith(draftRevision: 0, isEditing: false));
      await selectDate(current.draftDate);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetAfterDelete() async {
    _session = ++_nextSession;
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
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
    _changed(current.copyWith(emotion: () => value));
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
        _changed(current.copyWith(answer1: value));
      case 1:
        _changed(current.copyWith(answer2: value));
      case 2:
        _changed(current.copyWith(answer3: value));
    }
  }

  /// Saves the current entry. Returns true on success, false on failure.
  Future<bool> save() async {
    final retain = ref.keepAlive();
    try {
      return await _save();
    } finally {
      retain.close();
    }
  }

  Future<bool> _save() async {
    var current = state.value;
    final emotion = current?.emotion;
    if (current == null ||
        emotion == null ||
        !current.canSave ||
        current.isSaving ||
        current.isCancelling ||
        (current.isCompleted && !current.isEditing)) {
      return false;
    }

    if (current.draftRevision == 0) {
      _changed(current);
      current = state.value!;
    }

    state = AsyncData(current.copyWith(isSaving: true));

    late final EntryRepository entryRepo;
    late final DailyEntry entry;
    try {
      entryRepo = ref.read(entryRepositoryProvider);

      if (!await _store(current)) {
        if (_matches(current))
          state = AsyncData(state.value!.copyWith(isSaving: false));
        return false;
      }
      entry = await entryRepo.commitDraft(
        _snapshot(current),
        epoch: current.epoch,
      );
    } catch (e, stack) {
      developer.log('Failed to save entry', error: e, stackTrace: stack);
      if (_matches(current))
        state = AsyncData(
          state.value!.copyWith(
            isSaving: false,
            hasConflict: e is DraftConflict,
            draftError: () => e is DraftConflict
                ? '저장된 기록이 바뀌었어요. 입력을 복사하거나 저장된 기록을 다시 열어주세요.'
                : '저장하지 못했어요. 입력은 그대로 남아 있어요.',
          ),
        );
      return false;
    }

    // DB 저장이 성공한 후의 작업은 실패해도 이미 커밋된 기록을 되돌리지 않는다.
    final oldPhotoPath = current.existingEntry?.photoPath;
    if (oldPhotoPath != null && oldPhotoPath != current.photoPath) {
      await ref
          .read(photoServiceProvider)
          .deleteUnreferencedPhoto(
            oldPhotoPath,
            readReferences: entryRepo.getAllPhotoPaths,
            retainedPaths: [if (current.photoPath != null) current.photoPath!],
          );
    }

    var streakCount = current.currentStreak;
    var usedGraceDay = current.usedGraceDay;
    DailyEntry? saved = entry;
    int? milestone;
    try {
      final streakResult = await entryRepo.getCurrentStreakWithGrace();
      saved = await entryRepo.getEntryByDate(current.draftDate) ?? entry;
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

    if (_matches(current))
      state = AsyncData(
        current.copyWith(
          isCompleted: true,
          isEditing: false,
          isSaving: false,
          currentStreak: streakCount,
          usedGraceDay: usedGraceDay,
          existingEntry: () => saved,
          milestone: () => milestone,
          draftRevision: 0,
          storageStatus: DraftStorageStatus.idle,
          draftError: () => null,
          hasConflict: false,
          draftDates: current.draftDates.where((d) => d != entry.date).toList(),
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

    try {
      await ref
          .read(entryRepositoryProvider)
          .discardDraft(
            current.draftDate,
            revision: current.draftRevision,
            epoch: current.epoch,
          );
    } catch (_) {
      if (_matches(current))
        state = AsyncData(
          current.copyWith(
            isCancelling: false,
            draftError: () => '초안을 취소하지 못했어요. 다시 시도해주세요.',
          ),
        );
      return;
    }

    final currentPhotoPath = current.photoPath;
    if (currentPhotoPath != null && currentPhotoPath != saved.photoPath) {
      await ref
          .read(photoServiceProvider)
          .deleteUnreferencedPhoto(
            currentPhotoPath,
            readReferences: ref.read(entryRepositoryProvider).getAllPhotoPaths,
            retainedPaths: [if (saved.photoPath != null) saved.photoPath!],
          );
    }

    if (_matches(current))
      state = AsyncData(
        current.copyWith(
          emotion: () => saved.emotion,
          answer1: saved.answer1,
          answer2: saved.answer2,
          answer3: saved.answer3,
          photoPath: () => saved.photoPath,
          isEditing: false,
          isCancelling: false,
          draftRevision: 0,
          storageStatus: DraftStorageStatus.idle,
          draftError: () => null,
          hasConflict: false,
        ),
      );
  }

  Future<void> attachPhoto(String path, {TodayState? started}) async {
    final current = state.value;
    if (current == null || (started != null && !_matches(started))) {
      await _discardUnattachedPhoto(path);
      return;
    }
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
    _changed(current.copyWith(photoPath: () => path));
    await _store(state.value!);

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

    _changed(current.copyWith(photoPath: () => null));
    await _store(state.value!);

    // DB에 저장된 사진은 여기서 삭제하지 않는다. save()가 DB 트랜잭션
    // 성공 후 정리한다. 미저장 사진만 파일 정리를 시도한다.
    final savedPath = current.existingEntry?.photoPath;
    if (current.photoPath != savedPath) {
      await ref
          .read(photoServiceProvider)
          .deleteUnreferencedPhoto(
            current.photoPath!,
            readReferences: ref.read(entryRepositoryProvider).getAllPhotoPaths,
            retainedPaths: [?savedPath],
          );
    }
  }

  Future<void> _discardUnattachedPhoto(String path) async {
    final current = state.value;
    final currentPath = current?.photoPath;
    final savedPath = current?.existingEntry?.photoPath;
    await ref
        .read(photoServiceProvider)
        .deleteUnreferencedPhoto(
          path,
          readReferences: ref.read(entryRepositoryProvider).getAllPhotoPaths,
          retainedPaths: [?currentPath, ?savedPath],
        );
  }

  Future<void> refresh() async {
    final current = state.value;
    if (current == null) return;
    _scheduleMidnightRefresh();
    try {
      final repo = ref.read(entryRepositoryProvider);
      final streak = await repo.getCurrentStreakWithGrace();
      final saved = await repo.getEntryByDate(current.draftDate);
      if (!_matches(current)) return;
      var next = current.copyWith(
        currentStreak: streak.count,
        usedGraceDay: streak.usedGraceDay,
      );
      if (!current.isDirty &&
          !current.isEditing &&
          !current.isSaving &&
          !current.isCancelling &&
          current.draftRevision == 0) {
        next = next.copyWith(
          existingEntry: () => saved,
          isCompleted: saved != null,
          emotion: () => saved?.emotion,
          answer1: saved?.answer1 ?? '',
          answer2: saved?.answer2 ?? '',
          answer3: saved?.answer3 ?? '',
          photoPath: () => saved?.photoPath,
          prompts: saved == null
              ? current.prompts
              : [saved.prompt1, saved.prompt2, saved.prompt3],
        );
      }
      state = AsyncData(next);
    } catch (e, stack) {
      developer.log(
        'Failed to refresh journal metadata',
        error: e,
        stackTrace: stack,
      );
    }
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
      _scheduledDate = ref.read(appClockProvider).todayString();
      refresh();
    });
  }
}

final todayControllerProvider =
    AsyncNotifierProvider<TodayController, TodayState>(
      TodayController.new,
      isAutoDispose: true,
    );
