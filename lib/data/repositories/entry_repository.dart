import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' as du;
import '../../core/time/app_clock.dart';
import '../../core/utils/text_analysis.dart';
import '../database/app_database.dart';
import '../models/daily_entry.dart';
import '../models/entry_import.dart';
import '../models/weekly_retrospective.dart';

class EntryRepository {
  final AppDatabase _db;
  final AppClock _clock;

  EntryRepository(this._db, {AppClock clock = const AppClock()})
    : _clock = clock;

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

  EntriesCompanion _toCompanion(
    DailyEntry entry, {
    bool preserveTimestamps = false,
  }) {
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
      updatedAt: Value(preserveTimestamps ? entry.updatedAt : _clock.now()),
      photoPath: Value(entry.photoPath),
    );
  }

  // -- CRUD --

  Future<DailyEntry?> getTodayEntry() => getEntryByDate(_clock.todayString());

  Future<DailyEntry?> getEntryByDate(String date) async {
    final query = _db.select(_db.entries)..where((t) => t.date.equals(date));
    final result = await query.getSingleOrNull();
    return result != null ? _fromEntry(result) : null;
  }

  Future<void> saveEntry(
    DailyEntry entry, {
    bool preserveTimestamps = false,
  }) async {
    final companion = _toCompanion(
      entry,
      preserveTimestamps: preserveTimestamps,
    );
    await _db
        .into(_db.entries)
        .insert(
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
    return results.map((e) => e.photoPath).whereType<String>().toList();
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
      "ORDER BY date DESC LIMIT 100",
      variables: [patternVar, patternVar, patternVar],
      readsFrom: {_db.entries},
    );
    final results = await dbQuery.get();
    return results
        .map(
          (row) => _fromEntry(
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
          ),
        )
        .toList();
  }

  // -- Queries --

  Future<int> getTotalCount() async {
    final count = _db.entries.id.count();
    final query = _db.selectOnly(_db.entries)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<Map<String, int>> getEmotionMap(DateTime start, DateTime end) async {
    // date/emotion 만 필요하므로 selectOnly 로 텍스트 컬럼 역직렬화를 피한다.
    final startStr = du.dateToString(start);
    final endStr = du.dateToString(end);
    final dateCol = _db.entries.date;
    final emotionCol = _db.entries.emotion;
    final rows =
        await (_db.selectOnly(_db.entries)
              ..addColumns([dateCol, emotionCol])
              ..where(
                _db.entries.date.isBiggerOrEqualValue(startStr) &
                    _db.entries.date.isSmallerOrEqualValue(endStr),
              ))
            .get();
    return {for (final r in rows) r.read(dateCol)!: r.read(emotionCol)!};
  }

  Future<List<({DateTime date, int emotion})>> getEmotionTrend(
    DateTime start,
    DateTime end,
  ) async {
    final startStr = du.dateToString(start);
    final endStr = du.dateToString(end);
    final dateCol = _db.entries.date;
    final emotionCol = _db.entries.emotion;
    final rows =
        await (_db.selectOnly(_db.entries)
              ..addColumns([dateCol, emotionCol])
              ..where(
                _db.entries.date.isBiggerOrEqualValue(startStr) &
                    _db.entries.date.isSmallerOrEqualValue(endStr),
              )
              ..orderBy([OrderingTerm.asc(dateCol)]))
            .get();
    return rows
        .map(
          (r) => (
            date: DateTime.parse(r.read(dateCol)!),
            emotion: r.read(emotionCol)!,
          ),
        )
        .toList();
  }

  Future<double> getAverageEmotion(DateTime start, DateTime end) async {
    final startStr = du.dateToString(start);
    final endStr = du.dateToString(end);

    final avg = _db.entries.emotion.avg();
    final query = _db.selectOnly(_db.entries)
      ..addColumns([avg])
      ..where(
        _db.entries.date.isBiggerOrEqualValue(startStr) &
            _db.entries.date.isSmallerOrEqualValue(endStr),
      );
    final result = await query.getSingle();
    return result.read(avg) ?? 0.0;
  }

  // -- Analytics (period-scoped) --

  /// Returns (streak, usedGraceDay). Grace day allows 1 missed day
  /// without breaking the streak.
  Future<({int count, bool usedGraceDay})> getCurrentStreakWithGrace() async {
    final now = _clock.now();
    final cutoff = now.subtract(const Duration(days: 400));
    final cutoffStr = du.dateToString(cutoff);

    // 스트릭 계산은 날짜 집합만 필요하다 → date 컬럼만 읽는다.
    final dateCol = _db.entries.date;
    final recentRows =
        await (_db.selectOnly(_db.entries)
              ..addColumns([dateCol])
              ..where(_db.entries.date.isBiggerOrEqualValue(cutoffStr))
              ..orderBy([OrderingTerm.desc(dateCol)]))
            .get();

    if (recentRows.isEmpty) return (count: 0, usedGraceDay: false);

    final dateSet = {for (final r in recentRows) r.read(dateCol)!};
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
        checkDate = DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day - 1,
        );
      } else if (!usedGraceDay && streak > 0) {
        // Allow one grace day (skip this gap, continue checking)
        usedGraceDay = true;
        checkDate = DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day - 1,
        );
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
    final cutoff = _clock.daysAgo(1095);
    final cutoffStr = du.dateToString(cutoff);
    // 최장 스트릭도 날짜 시퀀스만 필요하다 → date 컬럼만 읽는다.
    final dateCol = _db.entries.date;
    final rows =
        await (_db.selectOnly(_db.entries)
              ..addColumns([dateCol])
              ..where(_db.entries.date.isBiggerOrEqualValue(cutoffStr))
              ..orderBy([OrderingTerm.asc(dateCol)]))
            .get();

    if (rows.isEmpty) return 0;

    final dates = [for (final r in rows) r.read(dateCol)!];

    int longest = 1;
    int current = 1;
    bool graceUsed = false;

    for (int i = 1; i < dates.length; i++) {
      final prev = DateTime.parse(dates[i - 1]);
      final curr = DateTime.parse(dates[i]);
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
    final oneYearAgo = _clock.sameDateMonthsAgo(12);
    return getEntryByDate(du.dateToString(oneYearAgo));
  }

  /// Returns the entry from the same date 6 months ago, if it exists.
  Future<DailyEntry?> getSixMonthsAgoEntry() async {
    final sixMonthsAgo = _clock.sameDateMonthsAgo(6);
    return getEntryByDate(du.dateToString(sixMonthsAgo));
  }

  /// Returns the entry from the same date 1 month ago, if it exists.
  Future<DailyEntry?> getOneMonthAgoEntry() async {
    final oneMonthAgo = _clock.sameDateMonthsAgo(1);
    return getEntryByDate(du.dateToString(oneMonthAgo));
  }

  /// Returns average emotion for a date range.
  /// Used for weekly delta calculation.
  Future<double?> getAverageEmotionOrNull(DateTime start, DateTime end) async {
    final startStr = du.dateToString(start);
    final endStr = du.dateToString(end);
    final avg = _db.entries.emotion.avg();
    final count = _db.entries.id.count();
    final query = _db.selectOnly(_db.entries)
      ..addColumns([avg, count])
      ..where(
        _db.entries.date.isBiggerOrEqualValue(startStr) &
            _db.entries.date.isSmallerOrEqualValue(endStr),
      );
    final result = await query.getSingle();
    final n = result.read(count) ?? 0;
    if (n == 0) return null;
    return result.read(avg);
  }

  Future<Map<int, double>> getEmotionByDayOfWeek(
    DateTime start,
    DateTime end,
  ) async {
    final results = await _queryByDateRange(start, end);
    final dayEmotions = <int, List<int>>{};

    for (final entry in results) {
      final weekday = DateTime.parse(entry.date).weekday;
      dayEmotions.putIfAbsent(weekday, () => []).add(entry.emotion);
    }

    return dayEmotions.map(
      (key, values) =>
          MapEntry(key, values.fold(0, (a, b) => a + b) / values.length),
    );
  }

  Future<Map<String, int>> getKeywordFrequency(
    DateTime start,
    DateTime end, {
    int limit = 10,
  }) async {
    final results = await _queryByDateRange(start, end);
    final texts = <String>[];
    for (final e in results) {
      texts.addAll([e.answer1, e.answer2, e.answer3]);
    }
    return extractKeywords(texts, limit: limit);
  }

  Future<Map<String, int>> getGratitudeKeywords(
    DateTime start,
    DateTime end, {
    int limit = 5,
  }) async {
    final results = await _queryByDateRange(start, end);
    final texts = results.map((e) => e.answer1).toList();
    return extractKeywords(texts, limit: limit);
  }

  /// Generates a local weekly retrospective from the past 7 days.
  /// Returns null if fewer than 2 entries exist in the period.
  /// [currentStreak] avoids a redundant DB round-trip when the caller
  /// already has the value (e.g. InsightsController).
  Future<WeeklyRetrospective?> getWeeklyRetrospective({
    int? currentStreak,
  }) async {
    final now = _clock.now();
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
    final allEntries = await (_db.select(
      _db.entries,
    )..orderBy([(t) => OrderingTerm.asc(t.date)])).get();
    return allEntries.map((e) => _fromEntry(e).toJson()).toList();
  }

  Future<ImportPreview> previewImport(String jsonStr) async {
    final now = _clock.now();
    final parsed = parseImportJson(jsonStr, now: now);
    final conflicts = <String, DailyEntry>{};
    for (final candidate in parsed.candidates) {
      final current = await getEntryByDate(candidate.date);
      if (current != null) conflicts[candidate.date] = current;
    }
    return ImportPreview(parsed: parsed, conflicts: conflicts);
  }

  Future<ImportResult> applyImport(
    ImportPreview preview, {
    ConflictPolicy policy = ConflictPolicy.preserve,
  }) => _db.transaction(() async {
    final now = _clock.now();
    var inserted = 0, replaced = 0, skipped = 0, changed = 0;
    var invalid = preview.parsed.invalid;
    for (final candidate in preview.parsed.candidates) {
      if (!isImportDateValid(candidate.date, now)) {
        invalid++;
        continue;
      }
      final current = await getEntryByDate(candidate.date);
      if (current == null) {
        await _db
            .into(_db.entries)
            .insert(
              _toCompanion(candidate.toEntry(now), preserveTimestamps: true),
            );
        inserted++;
      } else if (policy == ConflictPolicy.preserve ||
          !preview.conflicts.containsKey(candidate.date)) {
        skipped++;
      } else if (!sameImportSnapshot(
        current,
        preview.conflicts[candidate.date]!,
      )) {
        changed++;
      } else {
        final replacement = candidate.toEntry(now, replacing: current);
        await (_db.update(_db.entries)..where((t) => t.id.equals(current.id!)))
            .write(_toCompanion(replacement, preserveTimestamps: true));
        replaced++;
      }
    }
    return ImportResult(
      inserted: inserted,
      replaced: replaced,
      conflictSkipped: skipped,
      changedSincePreview: changed,
      invalid: invalid,
      duplicate: preview.parsed.duplicate,
    );
  });

  // -- Private helpers --

  Future<List<Entry>> _queryByDateRange(DateTime start, DateTime end) async {
    final startStr = du.dateToString(start);
    final endStr = du.dateToString(end);
    final query = _db.select(_db.entries)
      ..where(
        (t) =>
            t.date.isBiggerOrEqualValue(startStr) &
            t.date.isSmallerOrEqualValue(endStr),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }
}

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return EntryRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(appClockProvider),
  );
});
