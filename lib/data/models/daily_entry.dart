import 'package:drift/drift.dart';
import '../database/app_database.dart';

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
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory DailyEntry.fromEntry(Entry entry) {
    return DailyEntry(
      id: entry.id,
      date: entry.date,
      emotion: entry.emotion,
      prompt1: entry.prompt1,
      answer1: entry.answer1,
      prompt2: entry.prompt2,
      answer2: entry.answer2,
      prompt3: entry.prompt3,
      answer3: entry.answer3,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  EntriesCompanion toCompanion() {
    return EntriesCompanion(
      id: id != null ? Value(id!) : const Value.absent(),
      date: Value(date),
      emotion: Value(emotion),
      prompt1: Value(prompt1),
      answer1: Value(answer1),
      prompt2: Value(prompt2),
      answer2: Value(answer2),
      prompt3: Value(prompt3),
      answer3: Value(answer3),
      createdAt: Value(createdAt),
      updatedAt: Value(DateTime.now()),
    );
  }

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
    );
  }

  static String _formatWithTimezone(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final base = dt.toIso8601String().split('.').first;
    return '$base$sign$hours:$minutes';
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'emotion': emotion,
      'prompts': [
        {'category': 'gratitude', 'question': prompt1, 'answer': answer1},
        {'category': 'acceptance', 'question': prompt2, 'answer': answer2},
        {'category': 'intention', 'question': prompt3, 'answer': answer3},
      ],
      'created_at': _formatWithTimezone(createdAt),
    };
  }
}
