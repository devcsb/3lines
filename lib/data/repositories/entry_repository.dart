import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' as du;
import '../../core/utils/text_analysis.dart';
import '../database/app_database.dart';
import '../models/daily_entry.dart';
import '../models/weekly_retrospective.dart';

class EntryRepository {
  final AppDatabase _db;

  EntryRepository(this._db);

  // -- Drift ↔ DailyEntry mapping (kept in repository layer) --

  DailyEntry _fromEntry(Entry entry) {
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
      photoPath: entry.photoPath,
    );
  }

  EntriesCompanion _toCompanion(DailyEntry entry, {bool preserveTimestamps = false}) {
    return EntriesCompanion(
      id: entry.id != null ? Value(entry.id!) : const Value.absent(),
      date: Value(entry.date),
      emotion: Value(entry.emotion),
      prompt1: Value(entry.prompt1),
      answer1: Value(entry.answer1),
      prompt2: Value(entry.prompt2),
      answer2: Value(entry.answer2),
      prompt3: Value(entry.prompt3),
      answer3: Value(entry.answer3),
      createdAt: Value(entry.createdAt),
      updatedAt: Value(preserveTimestamps ? entry.updatedAt : DateTime.now()),
      photoPath: Value(entry.photoPath),
    );
  }

  // -- CRUD --

  Future<DailyEntry?> getTodayEntry() => getEntryByDate(du.getTodayString());

  Future<DailyEntry?> getEntryByDate(String date) async {
    final query = _db.select(_db.entries)
      ..where((t) => t.date.equals(date));
    final result = await query.getSingleOrNull();
    return result != null ? _fromEntry(result) : null;
  }

  Future<void> saveEntry(DailyEntry entry, {bool preserveTimestamps = false}) async {
    final companion = _toCompanion(entry, preserveTimestamps: preserveTimestamps);
    await _db.into(_db.entries).insert(
      companion,
      onConflict: DoUpdate(
        (old) => EntriesCompanion(
          emotion: companion.emotion,
          prompt1: companion.prompt1,
          answer1: companion.answer1,
          prompt2: companion.prompt2,
          answer2: companion.answer2,
          prompt3: companion.prompt3,
          answer3: companion.answer3,
          updatedAt: companion.updatedAt,
          photoPath: companion.photoPath,
        ),
        target: [_db.entries.date],
      ),
    );
  }

  Future<void> deleteAllEntries() async {
    await _db.delete(_db.entries).go();
  }

  Future<void> deleteEntry(String date) async {
    await (_db.delete(_db.entries)..where((t) => t.date.equals(date))).go();
  }

  /// Returns all non-null photo paths stored in entries.
  Future<List<String>> getAllPhotoPaths() async {
    final query = _db.select(_db.entries)
      ..where((t) => t.photoPath.isNotNull());
    final results = await query.get();
    return results
        .map((e) => e.photoPath)
        .whereType<String>()
        .toList();
  }

  /// Returns the entry immediately before [currentDate], or null.
  Future<DailyEntry?> getPreviousEntry(String currentDate) async {
    final query = _db.select(_db.entries)
      ..where((t) => t.date.isSmallerThanValue(currentDate))
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result != null ? _fromEntry(result) : null;
  }

  /// Returns the entry immediately after [currentDate], or null.
  Future<DailyEntry?> getNextEntry(String currentDate) async {
    final query = _db.select(_db.entries)
      ..where((t) => t.date.isBiggerThanValue(currentDate))
      ..orderBy([(t) => OrderingTerm.asc(t.date)])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result != null ? _fromEntry(result) : null;
  }

  // -- Search --

  Future<List<DailyEntry>> searchEntries(String query) async {
    if (query.trim().isEmpty) return [];
    final escaped = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final pattern = '%$escaped%';
    final patternVar = Variable<String>(pattern);

    final dbQuery = _db.customSelect(
      "SELECT * FROM entries WHERE "
      "answer1 LIKE ? ESCAPE '\\' OR "
      "answer2 LIKE ? ESCAPE '\\' OR "
      "answer3 LIKE ? ESCAPE '\\' "
      "ORDER BY date DESC",
      variables: [patternVar, patternVar, patternVar],
      readsFrom: {_db.entries},
    );
    final results = await dbQuery.get();
    return results.map((row) => _fromEntry(
      Entry(
        id: row.read<int>('id'),
        date: row.read<String>('date'),
        emotion: row.read<int>('emotion'),
        prompt1: row.read<String>('prompt1'),
        answer1: row.read<String>('answer1'),
        prompt2: row.read<String>('prompt2'),
        answer2: row.read<String>('answer2'),
        prompt3: row.read<String>('prompt3'),
        answer3: row.read<String>('answer3'),
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
        photoPath: row.readNullable<String>('photo_path'),
      ),
    )).toList();
  }

  // -- Queries --

  Future<int> getTotalCount() async {
    final count = _db.entries.id.count();
    final query = _db.selectOnly(_db.entries)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<Map<String, int>> getEmotionMap(
      DateTime start, DateTime end) async {
    final results = await _queryByDateRange(start, end);
    return {for (final r in results) r.date: r.emotion};
  }

  Future<List<({DateTime date, int emotion})>> getEmotionTrend(
      DateTime start, DateTime end) async {
    final startStr = du.dateToString(start);
    final endStr = du.dateToString(end);
    final query = _db.select(_db.entries)
      ..where((t) =>
          t.date.isBiggerOrEqualValue(startStr) &
          t.date.isSmallerOrEqualValue(endStr))
      ..orderBy([(t) => OrderingTerm.asc(t.date)]);
    final results = await query.get();
    return results
        .map((r) => (date: DateTime.parse(r.date), emotion: r.emotion))
        .toList();
  }

  Future<double> getAverageEmotion(DateTime start, DateTime end) async {
    final startStr = du.dateToString(start);
    final endStr = du.dateToString(end);

    final avg = _db.entries.emotion.avg();
    final query = _db.selectOnly(_db.entries)
      ..addColumns([avg])
      ..where(_db.entries.date.isBiggerOrEqualValue(startStr) &
          _db.entries.date.isSmallerOrEqualValue(endStr));
    final result = await query.getSingle();
    return result.read(avg) ?? 0.0;
  }

  // -- Analytics (period-scoped) --

  /// Returns (streak, usedGraceDay). Grace day allows 1 missed day
  /// without breaking the streak.
  Future<({int count, bool usedGraceDay})> getCurrentStreakWithGrace() async {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 400));
    final cutoffStr = du.dateToString(cutoff);

    final recentEntries = await (_db.select(_db.entries)
          ..where((t) => t.date.isBiggerOrEqualValue(cutoffStr))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();

    if (recentEntries.isEmpty) return (count: 0, usedGraceDay: false);

    final dateSet = {for (final e in recentEntries) e.date};
    int streak = 0;
    bool usedGraceDay = false;
    var checkDate = now;

    // If today not written, start from yesterday
    if (!dateSet.contains(du.dateToString(checkDate))) {
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
    }

    // Cap iterations to prevent runaway loops (400 days of data + 1 grace)
    const maxIterations = 402;
    for (var i = 0; i < maxIterations; i++) {
      final dateStr = du.dateToString(checkDate);
      if (dateSet.contains(dateStr)) {
        streak++;
        checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
      } else if (!usedGraceDay && streak > 0) {
        // Allow one grace day (skip this gap, continue checking)
        usedGraceDay = true;
        checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
      } else {
        break;
      }
    }

    return (count: streak, usedGraceDay: usedGraceDay);
  }

  Future<int> getCurrentStreak() async {
    final result = await getCurrentStreakWithGrace();
    return result.count;
  }

  Future<int> getLongestStreak() async {
    // Bound to last 3 years for performance
    final cutoff = DateTime.now().subtract(const Duration(days: 1095));
    final cutoffStr = du.dateToString(cutoff);
    final allEntries = await (_db.select(_db.entries)
          ..where((t) => t.date.isBiggerOrEqualValue(cutoffStr))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();

    if (allEntries.isEmpty) return 0;

    int longest = 1;
    int current = 1;
    bool graceUsed = false;

    for (int i = 1; i < allEntries.length; i++) {
      final prev = DateTime.parse(allEntries[i - 1].date);
      final curr = DateTime.parse(allEntries[i].date);
      final diff = curr.difference(prev).inDays;

      if (diff == 1) {
        current++;
      } else if (diff == 2 && !graceUsed) {
        // Grace day: 스트릭당 1일 공백을 1회만 허용(현재 스트릭 로직과 일치).
        // 기존 코드는 횟수 제한이 없어 격일 기록도 무한 연속으로 셌다.
        current++;
        graceUsed = true;
      } else {
        current = 1;
        graceUsed = false;
      }
      if (current > longest) longest = current;
    }

    return longest;
  }

  /// Returns the entry from the same date one year ago, if it exists.
  Future<DailyEntry?> getOneYearAgoEntry() async {
    // subtractMonths(12)로 정확히 1년 전 같은 날짜를 구한다.
    // Duration(days: 365)는 윤년에 하루 어긋난다.
    final oneYearAgo = du.subtractMonths(DateTime.now(), 12);
    return getEntryByDate(du.dateToString(oneYearAgo));
  }

  /// Returns the entry from the same date 6 months ago, if it exists.
  Future<DailyEntry?> getSixMonthsAgoEntry() async {
    final sixMonthsAgo = du.subtractMonths(DateTime.now(), 6);
    return getEntryByDate(du.dateToString(sixMonthsAgo));
  }

  /// Returns the entry from the same date 1 month ago, if it exists.
  Future<DailyEntry?> getOneMonthAgoEntry() async {
    final oneMonthAgo = du.subtractMonths(DateTime.now(), 1);
    return getEntryByDate(du.dateToString(oneMonthAgo));
  }

  /// Returns average emotion for a date range.
  /// Used for weekly delta calculation.
  Future<double?> getAverageEmotionOrNull(
      DateTime start, DateTime end) async {
    final startStr = du.dateToString(start);
    final endStr = du.dateToString(end);
    final avg = _db.entries.emotion.avg();
    final count = _db.entries.id.count();
    final query = _db.selectOnly(_db.entries)
      ..addColumns([avg, count])
      ..where(_db.entries.date.isBiggerOrEqualValue(startStr) &
          _db.entries.date.isSmallerOrEqualValue(endStr));
    final result = await query.getSingle();
    final n = result.read(count) ?? 0;
    if (n == 0) return null;
    return result.read(avg);
  }

  Future<Map<int, double>> getEmotionByDayOfWeek(
      DateTime start, DateTime end) async {
    final results = await _queryByDateRange(start, end);
    final dayEmotions = <int, List<int>>{};

    for (final entry in results) {
      final weekday = DateTime.parse(entry.date).weekday;
      dayEmotions.putIfAbsent(weekday, () => []).add(entry.emotion);
    }

    return dayEmotions.map((key, values) =>
        MapEntry(key, values.fold(0, (a, b) => a + b) / values.length));
  }

  Future<Map<String, int>> getKeywordFrequency(
      DateTime start, DateTime end, {int limit = 10}) async {
    final results = await _queryByDateRange(start, end);
    final texts = <String>[];
    for (final e in results) {
      texts.addAll([e.answer1, e.answer2, e.answer3]);
    }
    return extractKeywords(texts, limit: limit);
  }

  Future<Map<String, int>> getGratitudeKeywords(
      DateTime start, DateTime end, {int limit = 5}) async {
    final results = await _queryByDateRange(start, end);
    final texts = results.map((e) => e.answer1).toList();
    return extractKeywords(texts, limit: limit);
  }

  /// Generates a local weekly retrospective from the past 7 days.
  /// Returns null if fewer than 2 entries exist in the period.
  /// [currentStreak] avoids a redundant DB round-trip when the caller
  /// already has the value (e.g. InsightsController).
  Future<WeeklyRetrospective?> getWeeklyRetrospective({int? currentStreak}) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    final entries = await _queryByDateRange(start, now);

    if (entries.length < 2) return null;

    // Average emotion
    final avgEmotion =
        entries.fold(0, (sum, e) => sum + e.emotion) / entries.length;

    // Best and worst day
    Entry best = entries.first;
    Entry worst = entries.first;
    for (final e in entries) {
      if (e.emotion > best.emotion) best = e;
      if (e.emotion < worst.emotion) worst = e;
    }

    // Trend: compare first half vs second half
    final mid = entries.length ~/ 2;
    final firstHalf = entries.sublist(0, mid);
    final secondHalf = entries.sublist(mid);
    final firstAvg =
        firstHalf.fold(0, (s, e) => s + e.emotion) / firstHalf.length;
    final secondAvg =
        secondHalf.fold(0, (s, e) => s + e.emotion) / secondHalf.length;
    final diff = secondAvg - firstAvg;

    String trendDescription;
    if (diff > 0.3) {
      trendDescription = '감정이 점점 좋아지는 추세예요';
    } else if (diff < -0.3) {
      trendDescription = '감정이 조금 내려가는 흐름이에요';
    } else {
      trendDescription = '감정이 안정적으로 유지되고 있어요';
    }

    // Top keyword
    final texts = <String>[];
    for (final e in entries) {
      texts.addAll([e.answer1, e.answer2, e.answer3]);
    }
    final keywords = extractKeywords(texts, limit: 1);
    final topKeyword = keywords.isNotEmpty ? keywords.keys.first : '';

    final streak = currentStreak ?? await getCurrentStreak();

    return WeeklyRetrospective(
      entryCount: entries.length,
      averageEmotion: avgEmotion,
      trendDescription: trendDescription,
      topKeyword: topKeyword,
      currentStreak: streak,
      bestDay: (date: best.date, emotion: best.emotion),
      worstDay: best.emotion != worst.emotion
          ? (date: worst.date, emotion: worst.emotion)
          : null,
    );
  }

  /// Returns a summary for the given month: average emotion, entry count,
  /// and top keyword.
  Future<({double averageEmotion, int entryCount, String topKeyword})>
      getMonthlySummary(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0); // last day of month

    final entries = await _queryByDateRange(start, end);
    if (entries.isEmpty) {
      return (averageEmotion: 0.0, entryCount: 0, topKeyword: '');
    }

    final avgEmotion =
        entries.fold(0, (sum, e) => sum + e.emotion) / entries.length;
    final texts = <String>[];
    for (final e in entries) {
      texts.addAll([e.answer1, e.answer2, e.answer3]);
    }
    final keywords = extractKeywords(texts, limit: 1);
    final topKeyword = keywords.isNotEmpty ? keywords.keys.first : '';

    return (
      averageEmotion: avgEmotion,
      entryCount: entries.length,
      topKeyword: topKeyword,
    );
  }

  /// Returns all entries for a given month, ordered by date ascending.
  Future<List<DailyEntry>> getMonthlyEntries(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0); // last day of month
    final entries = await _queryByDateRange(start, end);
    return entries.map(_fromEntry).toList();
  }

  // -- Export / Import --

  Future<List<Map<String, dynamic>>> exportAllEntries() async {
    final allEntries = await (_db.select(_db.entries)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    return allEntries.map((e) => _fromEntry(e).toJson()).toList();
  }

  Future<({int imported, int skipped})> importEntries(
      List<Map<String, dynamic>> entries) async {
    int imported = 0;
    int skipped = 0;
    await _db.transaction(() async {
      for (final json in entries) {
        // 항목 단위로 전부 감싸 손상 데이터 1건이 transaction 전체를
        // 중단시키지 않도록 한다(타입 캐스트 실패 포함).
        try {
          final date = json['date'] as String?;
          final emotionRaw = json['emotion'];
          final emotion = emotionRaw is num ? emotionRaw.toInt() : null;
          final prompts = json['prompts'] as List<dynamic>?;
          if (date == null || emotion == null || prompts == null) {
            skipped++;
            continue;
          }

          // prompts 항목이 Map 이 아니거나 값이 String 이 아니면 빈 문자열로 처리.
          String field(int i, String key) {
            if (i < prompts.length) {
              final p = prompts[i];
              if (p is Map) {
                final v = p[key];
                if (v is String) return v;
              }
            }
            return '';
          }

          // Preserve original timestamps if available
          final createdAtRaw = json['created_at'] as String?;
          final createdAt = createdAtRaw != null
              ? DateTime.tryParse(createdAtRaw)
              : null;
          final updatedAtRaw = json['updated_at'] as String?;
          final updatedAt = updatedAtRaw != null
              ? DateTime.tryParse(updatedAtRaw)
              : null;
          // Photo path is metadata-only on import (file may not exist)
          final photoPath = json['photo_path'] as String?;

          final entry = DailyEntry(
            date: date,
            emotion: emotion.clamp(1, 5),
            prompt1: field(0, 'question'),
            answer1: field(0, 'answer'),
            prompt2: field(1, 'question'),
            answer2: field(1, 'answer'),
            prompt3: field(2, 'question'),
            answer3: field(2, 'answer'),
            createdAt: createdAt,
            updatedAt: updatedAt,
            photoPath: photoPath,
          );
          await saveEntry(entry, preserveTimestamps: true);
          imported++;
        } catch (_) {
          skipped++;
        }
      }
    });
    return (imported: imported, skipped: skipped);
  }

  // -- Private helpers --

  Future<List<Entry>> _queryByDateRange(DateTime start, DateTime end) async {
    final startStr = du.dateToString(start);
    final endStr = du.dateToString(end);
    final query = _db.select(_db.entries)
      ..where((t) =>
          t.date.isBiggerOrEqualValue(startStr) &
          t.date.isSmallerOrEqualValue(endStr))
      ..orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }
}

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return EntryRepository(ref.watch(appDatabaseProvider));
});
