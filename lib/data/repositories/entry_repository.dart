import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' as du;
import '../../core/utils/text_analysis.dart';
import '../database/app_database.dart';
import '../models/daily_entry.dart';

class EntryRepository {
  final AppDatabase _db;

  EntryRepository(this._db);

  Future<DailyEntry?> getTodayEntry() => getEntryByDate(du.getTodayString());

  Future<DailyEntry?> getEntryByDate(String date) async {
    final query = _db.select(_db.entries)
      ..where((t) => t.date.equals(date));
    final result = await query.getSingleOrNull();
    return result != null ? DailyEntry.fromEntry(result) : null;
  }

  Future<void> saveEntry(DailyEntry entry) async {
    final companion = entry.toCompanion();
    await _db.into(_db.entries).insert(
      companion,
      onConflict: DoUpdate(
        (old) => companion,
        target: [_db.entries.date],
      ),
    );
  }

  Future<Map<String, int>> getEmotionMap(
      DateTime start, DateTime end) async {
    final startStr = du.dateToString(start);
    final endStr = du.dateToString(end);
    final query = _db.select(_db.entries)
      ..where((t) =>
          t.date.isBiggerOrEqualValue(startStr) &
          t.date.isSmallerOrEqualValue(endStr));
    final results = await query.get();
    return {for (final r in results) r.date: r.emotion};
  }

  Future<int> getCurrentStreak() async {
    final allEntries = await (_db.select(_db.entries)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();

    if (allEntries.isEmpty) return 0;

    int streak = 0;
    var checkDate = DateTime.now();

    // If today is not recorded, start checking from yesterday
    if (allEntries.first.date != du.dateToString(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    final dateSet = {for (final e in allEntries) e.date};

    while (dateSet.contains(du.dateToString(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Future<int> getLongestStreak() async {
    final allEntries = await (_db.select(_db.entries)
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

  Future<int> getTotalCount() async {
    final count = _db.entries.id.count();
    final query = _db.selectOnly(_db.entries)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
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

  Future<double> getAverageEmotion(int days) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
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

  Future<Map<int, double>> getEmotionByDayOfWeek() async {
    final allEntries = await _db.select(_db.entries).get();
    final dayEmotions = <int, List<int>>{};

    for (final entry in allEntries) {
      final weekday = DateTime.parse(entry.date).weekday;
      dayEmotions.putIfAbsent(weekday, () => []).add(entry.emotion);
    }

    return dayEmotions.map((key, values) =>
        MapEntry(key, values.reduce((a, b) => a + b) / values.length));
  }

  Future<Map<String, int>> getKeywordFrequency({int limit = 10}) async {
    final allEntries = await _db.select(_db.entries).get();
    final texts = <String>[];
    for (final e in allEntries) {
      texts.addAll([e.answer1, e.answer2, e.answer3]);
    }
    return extractKeywords(texts, limit: limit);
  }

  Future<Map<String, int>> getGratitudeKeywords({int limit = 5}) async {
    final allEntries = await _db.select(_db.entries).get();
    final texts = allEntries.map((e) => e.answer1).toList();
    return extractKeywords(texts, limit: limit);
  }

  Future<List<Map<String, dynamic>>> exportAllEntries() async {
    final allEntries = await (_db.select(_db.entries)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    return allEntries.map((e) => DailyEntry.fromEntry(e).toJson()).toList();
  }

  Future<void> deleteAllEntries() async {
    await _db.delete(_db.entries).go();
  }
}

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return EntryRepository(ref.watch(appDatabaseProvider));
});
