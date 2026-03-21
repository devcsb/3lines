import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' as du;
import '../../core/utils/text_analysis.dart';
import '../database/app_database.dart';
import '../models/daily_entry.dart';

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

  Future<void> saveEntry(DailyEntry entry) async {
    final companion = _toCompanion(entry);
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
        ),
        target: [_db.entries.date],
      ),
    );
  }

  Future<void> deleteAllEntries() async {
    await _db.delete(_db.entries).go();
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

    Expression<bool> likeEscaped(GeneratedColumn<String> col) {
      return CustomExpression<bool>(
        "${col.name} LIKE ? ESCAPE '\\'",
        precedence: Precedence.comparisonEq,
        watchedTables: [_db.entries],
      ).dartCast<bool>();
    }

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

  Future<int> getCurrentStreak() async {
    // Only query the last 400 days instead of full table scan
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 400));
    final cutoffStr = du.dateToString(cutoff);

    final recentEntries = await (_db.select(_db.entries)
          ..where((t) => t.date.isBiggerOrEqualValue(cutoffStr))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();

    if (recentEntries.isEmpty) return 0;

    int streak = 0;
    var checkDate = now;

    if (recentEntries.first.date != du.dateToString(checkDate)) {
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
    }

    final dateSet = {for (final e in recentEntries) e.date};

    while (dateSet.contains(du.dateToString(checkDate))) {
      streak++;
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
    }

    return streak;
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

    for (int i = 1; i < allEntries.length; i++) {
      final prev = DateTime.parse(allEntries[i - 1].date);
      final curr = DateTime.parse(allEntries[i].date);
      final diff = curr.difference(prev).inDays;

      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }

    return longest;
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
        MapEntry(key, values.reduce((a, b) => a + b) / values.length));
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
        final date = json['date'] as String?;
        final emotionRaw = json['emotion'];
        final emotion = emotionRaw is num ? emotionRaw.toInt() : null;
        final prompts = json['prompts'] as List<dynamic>?;
        if (date == null || emotion == null || prompts == null) {
          skipped++;
          continue;
        }

        String field(int i, String key) {
          if (i < prompts.length) {
            final p = prompts[i] as Map<String, dynamic>;
            return (p[key] as String?) ?? '';
          }
          return '';
        }

        final entry = DailyEntry(
          date: date,
          emotion: emotion.clamp(1, 5),
          prompt1: field(0, 'question'),
          answer1: field(0, 'answer'),
          prompt2: field(1, 'question'),
          answer2: field(1, 'answer'),
          prompt3: field(2, 'question'),
          answer3: field(2, 'answer'),
        );
        try {
          await saveEntry(entry);
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
          t.date.isSmallerOrEqualValue(endStr));
    return query.get();
  }
}

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return EntryRepository(ref.watch(appDatabaseProvider));
});
