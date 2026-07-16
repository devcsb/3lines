import '../../data/models/daily_entry.dart';

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
  final bool isCancelling;
  final DailyEntry? oneYearAgoEntry;
  final DailyEntry? sixMonthsAgoEntry;
  final DailyEntry? oneMonthAgoEntry;
  final int? milestone;
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
    this.isCancelling = false,
    this.oneYearAgoEntry,
    this.sixMonthsAgoEntry,
    this.oneMonthAgoEntry,
    this.milestone,
    this.photoPath,
    this.recentEmotions = const [],
  });

  bool get canSave => emotion != null && filledAnswerCount > 0;

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
      existingEntry: existingEntry != null
          ? existingEntry()
          : this.existingEntry,
      isSaving: isSaving ?? this.isSaving,
      isCancelling: isCancelling ?? this.isCancelling,
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
