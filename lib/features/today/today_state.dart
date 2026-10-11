import '../../data/models/daily_entry.dart';

enum DraftStorageStatus { idle, storing, stored, failed }

class TodayState {
  final String draftDate;
  final int draftRevision;
  final int session;
  final int epoch;
  final List<String> draftDates;
  final DraftStorageStatus storageStatus;
  final String? draftError;
  final bool hasConflict;
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
  final bool isCancelling;
  final bool isSwitchingDate;
  final DailyEntry? oneYearAgoEntry;
  final DailyEntry? sixMonthsAgoEntry;
  final DailyEntry? oneMonthAgoEntry;
  final int? milestone;
  final String? photoPath;
  final List<({DateTime date, int emotion})> recentEmotions;

  const TodayState({
    this.draftDate = '',
    this.draftRevision = 0,
    this.session = 0,
    this.epoch = 0,
    this.draftDates = const [],
    this.storageStatus = DraftStorageStatus.idle,
    this.draftError,
    this.hasConflict = false,
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
    this.isCancelling = false,
    this.isSwitchingDate = false,
    this.oneYearAgoEntry,
    this.sixMonthsAgoEntry,
    this.oneMonthAgoEntry,
    this.milestone,
    this.photoPath,
    this.recentEmotions = const [],
  });

  bool get canSave => emotion != null && filledAnswerCount > 0;

  bool get isDirty {
    final saved = existingEntry;
    if (saved == null) {
      return emotion != null ||
          photoPath != null ||
          [answer1, answer2, answer3].any((a) => a.isNotEmpty);
    }
    return emotion != saved.emotion ||
        photoPath != saved.photoPath ||
        answer1 != saved.answer1 ||
        answer2 != saved.answer2 ||
        answer3 != saved.answer3;
  }

  int get filledAnswerCount => [
    answer1,
    answer2,
    answer3,
  ].where((answer) => answer.trim().isNotEmpty).length;

  String get saveGuidanceMessage {
    if (emotion == null) return '오늘의 감정을 먼저 골라주세요';
    if (filledAnswerCount == 0) return '한 줄만 적어도 저장할 수 있어요';
    return '저장할 준비가 됐어요';
  }

  TodayState copyWith({
    String? draftDate,
    int? draftRevision,
    int? session,
    int? epoch,
    List<String>? draftDates,
    DraftStorageStatus? storageStatus,
    String? Function()? draftError,
    bool? hasConflict,
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
    bool? isCancelling,
    bool? isSwitchingDate,
    DailyEntry? Function()? oneYearAgoEntry,
    DailyEntry? Function()? sixMonthsAgoEntry,
    DailyEntry? Function()? oneMonthAgoEntry,
    int? Function()? milestone,
    String? Function()? photoPath,
    List<({DateTime date, int emotion})>? recentEmotions,
  }) {
    return TodayState(
      draftDate: draftDate ?? this.draftDate,
      draftRevision: draftRevision ?? this.draftRevision,
      session: session ?? this.session,
      epoch: epoch ?? this.epoch,
      draftDates: draftDates ?? this.draftDates,
      storageStatus: storageStatus ?? this.storageStatus,
      draftError: draftError != null ? draftError() : this.draftError,
      hasConflict: hasConflict ?? this.hasConflict,
      emotion: emotion != null ? emotion() : this.emotion,
      answer1: answer1 ?? this.answer1,
      answer2: answer2 ?? this.answer2,
      answer3: answer3 ?? this.answer3,
      prompts: prompts ?? this.prompts,
      isCompleted: isCompleted ?? this.isCompleted,
      isEditing: isEditing ?? this.isEditing,
      currentStreak: currentStreak ?? this.currentStreak,
      usedGraceDay: usedGraceDay ?? this.usedGraceDay,
      existingEntry: existingEntry != null
          ? existingEntry()
          : this.existingEntry,
      isSaving: isSaving ?? this.isSaving,
      isCancelling: isCancelling ?? this.isCancelling,
      isSwitchingDate: isSwitchingDate ?? this.isSwitchingDate,
      oneYearAgoEntry: oneYearAgoEntry != null
          ? oneYearAgoEntry()
          : this.oneYearAgoEntry,
      sixMonthsAgoEntry: sixMonthsAgoEntry != null
          ? sixMonthsAgoEntry()
          : this.sixMonthsAgoEntry,
      oneMonthAgoEntry: oneMonthAgoEntry != null
          ? oneMonthAgoEntry()
          : this.oneMonthAgoEntry,
      milestone: milestone != null ? milestone() : this.milestone,
      photoPath: photoPath != null ? photoPath() : this.photoPath,
      recentEmotions: recentEmotions ?? this.recentEmotions,
    );
  }
}
