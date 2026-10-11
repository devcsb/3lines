import 'dart:convert';

import 'daily_entry.dart';
import 'entry_import.dart';

class DraftConflict implements Exception {
  const DraftConflict();
}

class StaleDraft implements Exception {
  const StaleDraft();
}

/// Recovery token for one unreadable row. Raw content is never in the message.
class CorruptDraft extends FormatException {
  CorruptDraft({
    required this.date,
    required this.key,
    required this.rawPayload,
    required this.epoch,
  }) : super('보관 초안을 읽을 수 없어요 ($date)');
  final String date;
  final String key;
  final String rawPayload;
  final int epoch;
}

/// Private storage format, separate from the completed-entry JSON export.
class JournalDraft {
  JournalDraft({
    required this.date,
    required this.revision,
    required List<String> prompts,
    required List<String> answers,
    this.emotion,
    this.photoPath,
    this.baseline,
  }) : prompts = List.unmodifiable(prompts),
       answers = List.unmodifiable(answers) {
    if (!isImportDateValid(date, DateTime(9999, 12, 31)) ||
        revision < 1 ||
        prompts.length != 3 ||
        answers.length != 3 ||
        (emotion != null && (emotion! < 1 || emotion! > 5)) ||
        (baseline != null && baseline!.date != date)) {
      throw const FormatException('초안 형식 오류');
    }
  }
  final String date;
  final int revision;
  final List<String> prompts;
  final List<String> answers;
  final int? emotion;
  final String? photoPath;
  final DailyEntry? baseline;

  String encode() => jsonEncode({
    'version': 1,
    'date': date,
    'revision': revision,
    'emotion': emotion,
    'prompts': prompts,
    'answers': answers,
    'photo': photoPath,
    'baseline': baseline == null
        ? null
        : {
            'id': baseline!.id,
            'date': baseline!.date,
            'emotion': baseline!.emotion,
            'prompts': [
              baseline!.prompt1,
              baseline!.prompt2,
              baseline!.prompt3,
            ],
            'answers': [
              baseline!.answer1,
              baseline!.answer2,
              baseline!.answer3,
            ],
            'photo': baseline!.photoPath,
            'created': baseline!.createdAt.toIso8601String(),
            'updated': baseline!.updatedAt.toIso8601String(),
          },
  });

  static JournalDraft decode(String payload, {required String date}) {
    try {
      final value = jsonDecode(payload) as Map<String, dynamic>;
      if (value['version'] is! int ||
          !value.containsKey('emotion') ||
          !value.containsKey('photo') ||
          !value.containsKey('baseline') ||
          value['version'] != 1 ||
          value['date'] != date ||
          value['revision'] is! int ||
          (value['emotion'] != null && value['emotion'] is! int) ||
          (value['photo'] != null && value['photo'] is! String)) {
        throw const FormatException('초안 형식 오류');
      }
      DailyEntry? baseline;
      if (value['baseline'] != null) {
        final b = value['baseline'] as Map<String, dynamic>;
        final p = List<String>.from(b['prompts'] as List);
        final a = List<String>.from(b['answers'] as List);
        if (p.length != 3 ||
            a.length != 3 ||
            b['id'] is! int ||
            b['date'] != date ||
            b['emotion'] is! int ||
            b['emotion'] < 1 ||
            b['emotion'] > 5 ||
            !b.containsKey('photo') ||
            (b['photo'] != null && b['photo'] is! String)) {
          throw const FormatException('원본 형식 오류');
        }
        baseline = DailyEntry(
          id: b['id'],
          date: b['date'],
          emotion: b['emotion'],
          prompt1: p[0],
          prompt2: p[1],
          prompt3: p[2],
          answer1: a[0],
          answer2: a[1],
          answer3: a[2],
          photoPath: b['photo'],
          createdAt: DateTime.parse(b['created'] as String),
          updatedAt: DateTime.parse(b['updated'] as String),
        );
      }
      return JournalDraft(
        date: date,
        revision: value['revision'] as int,
        prompts: List<String>.from(value['prompts'] as List),
        answers: List<String>.from(value['answers'] as List),
        emotion: value['emotion'] as int?,
        photoPath: value['photo'] as String?,
        baseline: baseline,
      );
    } catch (_) {
      throw FormatException('보관 초안을 읽을 수 없어요 ($date)');
    }
  }
}
