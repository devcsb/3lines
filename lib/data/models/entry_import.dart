import 'dart:convert';

import 'daily_entry.dart';

enum ConflictPolicy { preserve, replacePreviewed }

class ImportPrompt {
  const ImportPrompt({required this.question, required this.answer});

  final String question;
  final String answer;
}

class ImportCandidate {
  ImportCandidate({
    required this.date,
    required this.emotion,
    required List<ImportPrompt> prompts,
    this.createdAt,
    this.updatedAt,
  }) : prompts = List<ImportPrompt>.unmodifiable(prompts);

  final String date;
  final int emotion;
  final List<ImportPrompt> prompts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DailyEntry toEntry(DateTime now, {DailyEntry? replacing}) => DailyEntry(
    id: replacing?.id,
    date: date,
    emotion: emotion,
    prompt1: prompts[0].question,
    answer1: prompts[0].answer,
    prompt2: prompts[1].question,
    answer2: prompts[1].answer,
    prompt3: prompts[2].question,
    answer3: prompts[2].answer,
    createdAt: replacing?.createdAt ?? createdAt ?? now,
    updatedAt: updatedAt ?? now,
    photoPath: replacing?.photoPath,
  );
}

class ParsedImport {
  ParsedImport({
    required List<Object?> entries,
    required List<ImportCandidate> candidates,
    required this.invalid,
    required this.duplicate,
  }) : entries = List<Object?>.unmodifiable(entries.map(_freeze)),
       candidates = List<ImportCandidate>.unmodifiable(candidates);

  final List<Object?> entries;
  final List<ImportCandidate> candidates;
  final int invalid;
  final int duplicate;

  int get inputCount => entries.length;
}

class ImportPreview {
  ImportPreview({
    required this.parsed,
    required Map<String, DailyEntry> conflicts,
  }) : conflicts = Map<String, DailyEntry>.unmodifiable(conflicts);

  final ParsedImport parsed;
  final Map<String, DailyEntry> conflicts;

  int get newCount => parsed.candidates
      .where((candidate) => !conflicts.containsKey(candidate.date))
      .length;
  int get conflictCount => conflicts.length;
}

class ImportResult {
  const ImportResult({
    required this.inserted,
    required this.replaced,
    required this.conflictSkipped,
    required this.changedSincePreview,
    required this.invalid,
    required this.duplicate,
  });

  final int inserted;
  final int replaced;
  final int conflictSkipped;
  final int changedSincePreview;
  final int invalid;
  final int duplicate;

  int get total =>
      inserted +
      replaced +
      conflictSkipped +
      changedSincePreview +
      invalid +
      duplicate;
  int get changedCount => inserted + replaced;
}

Object? _freeze(Object? value) {
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, item) => MapEntry(key as String, _freeze(item))),
    );
  }
  return value;
}

bool isImportDateValid(String date, DateTime now) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) return false;
  final year = int.parse(date.substring(0, 4));
  final month = int.parse(date.substring(5, 7));
  final day = int.parse(date.substring(8, 10));
  final value = DateTime.utc(year, month, day);
  final localNow = now.toLocal();
  return value.year == year &&
      value.month == month &&
      value.day == day &&
      !value.isAfter(DateTime.utc(localNow.year, localNow.month, localNow.day));
}

DateTime? _timestamp(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('시각 형식 오류');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException('시각 형식 오류');
  return parsed;
}

ImportCandidate? _candidate(Object? value, DateTime now) {
  if (value is! Map) return null;
  final date = value['date'];
  final emotion = value['emotion'];
  final prompts = value['prompts'];
  if (date is! String ||
      !isImportDateValid(date, now) ||
      emotion is! num ||
      !emotion.isFinite ||
      emotion != emotion.truncateToDouble() ||
      emotion < 1 ||
      emotion > 5 ||
      prompts is! List ||
      prompts.length != 3) {
    return null;
  }
  final parsedPrompts = <ImportPrompt>[];
  for (final prompt in prompts) {
    if (prompt is! Map ||
        prompt['question'] is! String ||
        prompt['answer'] is! String) {
      return null;
    }
    parsedPrompts.add(
      ImportPrompt(
        question: prompt['question'] as String,
        answer: prompt['answer'] as String,
      ),
    );
  }
  if (parsedPrompts.every((prompt) => prompt.answer.trim().isEmpty)) {
    return null;
  }
  try {
    return ImportCandidate(
      date: date,
      emotion: emotion.toInt(),
      prompts: parsedPrompts,
      createdAt: _timestamp(value['created_at']),
      updatedAt: _timestamp(value['updated_at']),
    );
  } on FormatException {
    return null;
  }
}

ParsedImport parseImportJson(String jsonStr, {required DateTime now}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonStr);
  } on FormatException {
    throw const FormatException('JSON 형식 오류');
  }
  final List<dynamic> entries;
  if (decoded is List) {
    entries = decoded;
  } else if (decoded is Map &&
      decoded['entries'] is List &&
      (!decoded.containsKey('app') || decoded['app'] == '3Lines') &&
      (!decoded.containsKey('version') || decoded['version'] is String)) {
    entries = decoded['entries'] as List;
  } else {
    throw const FormatException('가져오기 형식 오류');
  }

  final seen = <String>{};
  final candidates = <ImportCandidate>[];
  var invalid = 0;
  var duplicate = 0;
  for (final entry in entries) {
    final candidate = _candidate(entry, now);
    if (candidate == null) {
      invalid++;
    } else if (!seen.add(candidate.date)) {
      duplicate++;
    } else {
      candidates.add(candidate);
    }
  }
  return ParsedImport(
    entries: entries,
    candidates: candidates,
    invalid: invalid,
    duplicate: duplicate,
  );
}

bool sameImportSnapshot(DailyEntry a, DailyEntry b) =>
    a.id == b.id &&
    a.date == b.date &&
    a.emotion == b.emotion &&
    a.prompt1 == b.prompt1 &&
    a.answer1 == b.answer1 &&
    a.prompt2 == b.prompt2 &&
    a.answer2 == b.answer2 &&
    a.prompt3 == b.prompt3 &&
    a.answer3 == b.answer3 &&
    a.photoPath == b.photoPath &&
    a.createdAt == b.createdAt &&
    a.updatedAt == b.updatedAt;
