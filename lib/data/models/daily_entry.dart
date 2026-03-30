import '../../core/utils/date_utils.dart' as du;

class DailyEntry {
  final int? id;
  final String date;
  final int emotion;
  final String prompt1;
  final String answer1;
  final String prompt2;
  final String answer2;
  final String prompt3;
  final String answer3;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photoPath;

  DailyEntry({
    this.id,
    required this.date,
    required this.emotion,
    this.prompt1 = '',
    this.answer1 = '',
    this.prompt2 = '',
    this.answer2 = '',
    this.prompt3 = '',
    this.answer3 = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.photoPath,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  DailyEntry copyWith({
    int? id,
    String? date,
    int? emotion,
    String? prompt1,
    String? answer1,
    String? prompt2,
    String? answer2,
    String? prompt3,
    String? answer3,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? Function()? photoPath,
  }) {
    return DailyEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      emotion: emotion ?? this.emotion,
      prompt1: prompt1 ?? this.prompt1,
      answer1: answer1 ?? this.answer1,
      prompt2: prompt2 ?? this.prompt2,
      answer2: answer2 ?? this.answer2,
      prompt3: prompt3 ?? this.prompt3,
      answer3: answer3 ?? this.answer3,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoPath: photoPath != null ? photoPath() : this.photoPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          emotion == other.emotion &&
          prompt1 == other.prompt1 &&
          answer1 == other.answer1 &&
          prompt2 == other.prompt2 &&
          answer2 == other.answer2 &&
          prompt3 == other.prompt3 &&
          answer3 == other.answer3 &&
          photoPath == other.photoPath;

  @override
  int get hashCode => Object.hash(
        id, date, emotion, prompt1, answer1, prompt2, answer2, prompt3, answer3, photoPath);

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'emotion': emotion,
      'photo_path': photoPath,
      'prompts': [
        {'category': 'gratitude', 'question': prompt1, 'answer': answer1},
        {'category': 'acceptance', 'question': prompt2, 'answer': answer2},
        {'category': 'intention', 'question': prompt3, 'answer': answer3},
      ],
      'created_at': du.formatWithTimezone(createdAt),
    };
  }
}
