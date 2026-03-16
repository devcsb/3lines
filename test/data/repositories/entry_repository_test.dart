import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';

void main() {
  late AppDatabase db;
  late EntryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  DailyEntry makeEntry(String date, {int emotion = 3, String answer1 = 'test'}) {
    return DailyEntry(
      date: date,
      emotion: emotion,
      prompt1: '질문1',
      answer1: answer1,
      prompt2: '질문2',
      answer2: '',
      prompt3: '질문3',
      answer3: '',
    );
  }

  group('getTodayEntry', () {
    test('returns null when no entry exists', () async {
      final result = await repo.getTodayEntry();
      expect(result, isNull);
    });

    test('returns entry when it exists for today', () async {
      final entry = makeEntry(du.getTodayString(), emotion: 4);
      await repo.saveEntry(entry);
      final result = await repo.getTodayEntry();
      expect(result, isNotNull);
      expect(result!.emotion, 4);
    });
  });

  group('getEntryByDate', () {
    test('returns null for missing date', () async {
      final result = await repo.getEntryByDate('2026-01-01');
      expect(result, isNull);
    });

    test('returns correct entry for date', () async {
      await repo.saveEntry(makeEntry('2026-03-10', emotion: 5));
      await repo.saveEntry(makeEntry('2026-03-11', emotion: 2));
      final result = await repo.getEntryByDate('2026-03-10');
      expect(result!.emotion, 5);
    });
  });

  group('saveEntry', () {
    test('creates new entry', () async {
      await repo.saveEntry(makeEntry('2026-03-14'));
      final result = await repo.getEntryByDate('2026-03-14');
      expect(result, isNotNull);
    });

    test('updates existing entry (upsert by date)', () async {
      await repo.saveEntry(makeEntry('2026-03-14', emotion: 3));
      await repo.saveEntry(makeEntry('2026-03-14', emotion: 5));
      final result = await repo.getEntryByDate('2026-03-14');
      expect(result!.emotion, 5);
    });
  });

  group('getCurrentStreak', () {
    test('returns 0 for empty database', () async {
      expect(await repo.getCurrentStreak(), 0);
    });

    test('returns 1 for only today', () async {
      await repo.saveEntry(makeEntry(du.getTodayString()));
      expect(await repo.getCurrentStreak(), 1);
    });

    test('counts consecutive days correctly', () async {
      final today = DateTime.now();
      for (int i = 0; i < 5; i++) {
        final date = today.subtract(Duration(days: i));
        await repo.saveEntry(makeEntry(du.dateToString(date)));
      }
      expect(await repo.getCurrentStreak(), 5);
    });

    test('breaks streak on gap', () async {
      final today = DateTime.now();
      await repo.saveEntry(makeEntry(du.dateToString(today)));
      await repo.saveEntry(
          makeEntry(du.dateToString(today.subtract(const Duration(days: 1)))));
      // Gap at day -2
      await repo.saveEntry(
          makeEntry(du.dateToString(today.subtract(const Duration(days: 3)))));
      expect(await repo.getCurrentStreak(), 2);
    });
  });

  group('getLongestStreak', () {
    test('returns 0 for empty database', () async {
      expect(await repo.getLongestStreak(), 0);
    });

    test('returns correct longest streak', () async {
      // Streak 1: 3 days
      await repo.saveEntry(makeEntry('2026-03-01'));
      await repo.saveEntry(makeEntry('2026-03-02'));
      await repo.saveEntry(makeEntry('2026-03-03'));
      // Gap
      // Streak 2: 5 days
      await repo.saveEntry(makeEntry('2026-03-05'));
      await repo.saveEntry(makeEntry('2026-03-06'));
      await repo.saveEntry(makeEntry('2026-03-07'));
      await repo.saveEntry(makeEntry('2026-03-08'));
      await repo.saveEntry(makeEntry('2026-03-09'));
      expect(await repo.getLongestStreak(), 5);
    });

    test('returns 1 for single entry', () async {
      await repo.saveEntry(makeEntry('2026-03-01'));
      expect(await repo.getLongestStreak(), 1);
    });
  });

  group('getEmotionMap', () {
    test('returns empty map for empty period', () async {
      final result = await repo.getEmotionMap(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 10),
      );
      expect(result, isEmpty);
    });

    test('returns correct emotion mapping', () async {
      await repo.saveEntry(makeEntry('2026-03-05', emotion: 4));
      await repo.saveEntry(makeEntry('2026-03-07', emotion: 2));
      final result = await repo.getEmotionMap(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 10),
      );
      expect(result['2026-03-05'], 4);
      expect(result['2026-03-07'], 2);
      expect(result.containsKey('2026-03-06'), isFalse);
    });

    test('respects date boundaries', () async {
      await repo.saveEntry(makeEntry('2026-02-28', emotion: 1));
      await repo.saveEntry(makeEntry('2026-03-01', emotion: 3));
      final result = await repo.getEmotionMap(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );
      expect(result.containsKey('2026-02-28'), isFalse);
      expect(result['2026-03-01'], 3);
    });
  });

  group('getTotalCount', () {
    test('returns 0 for empty database', () async {
      expect(await repo.getTotalCount(), 0);
    });

    test('returns correct count', () async {
      await repo.saveEntry(makeEntry('2026-03-01'));
      await repo.saveEntry(makeEntry('2026-03-02'));
      await repo.saveEntry(makeEntry('2026-03-03'));
      expect(await repo.getTotalCount(), 3);
    });
  });

  group('getEmotionTrend', () {
    test('returns empty list for empty period', () async {
      final result = await repo.getEmotionTrend(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 10),
      );
      expect(result, isEmpty);
    });

    test('returns entries in date order', () async {
      await repo.saveEntry(makeEntry('2026-03-05', emotion: 4));
      await repo.saveEntry(makeEntry('2026-03-03', emotion: 2));
      await repo.saveEntry(makeEntry('2026-03-07', emotion: 5));
      final result = await repo.getEmotionTrend(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 10),
      );
      expect(result.length, 3);
      expect(result[0].emotion, 2); // Mar 3
      expect(result[1].emotion, 4); // Mar 5
      expect(result[2].emotion, 5); // Mar 7
    });

    test('respects date boundaries', () async {
      await repo.saveEntry(makeEntry('2026-02-28', emotion: 1));
      await repo.saveEntry(makeEntry('2026-03-01', emotion: 3));
      await repo.saveEntry(makeEntry('2026-03-15', emotion: 5));
      final result = await repo.getEmotionTrend(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 10),
      );
      expect(result.length, 1);
      expect(result[0].emotion, 3);
    });
  });

  group('getKeywordFrequency', () {
    test('returns empty for no entries', () async {
      final result = await repo.getKeywordFrequency();
      expect(result, isEmpty);
    });

    test('returns empty for entries with empty answers', () async {
      await repo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 3,
      ));
      final result = await repo.getKeywordFrequency();
      expect(result, isEmpty);
    });

    test('extracts keywords from answers', () async {
      await repo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 4,
        answer1: '가족과 저녁 식사',
        answer2: '오늘 가족 모임',
        answer3: '내일도 가족과 함께',
      ));
      final result = await repo.getKeywordFrequency();
      expect(result, isNotEmpty);
      // '가족' appears in all 3 answers
      expect(result.containsKey('가족'), isTrue);
    });
  });

  group('getGratitudeKeywords', () {
    test('extracts from first answer only', () async {
      await repo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 4,
        answer1: '가족과 저녁 식사',
        answer2: '운동을 시작했다',
        answer3: '내일 운동 계획',
      ));
      final result = await repo.getGratitudeKeywords();
      // Should only analyze answer1 (gratitude)
      expect(result, isNotEmpty);
    });
  });

  group('exportAllEntries', () {
    test('returns empty list for no entries', () async {
      final result = await repo.exportAllEntries();
      expect(result, isEmpty);
    });

    test('exports all entries in date order', () async {
      await repo.saveEntry(makeEntry('2026-03-03'));
      await repo.saveEntry(makeEntry('2026-03-01'));
      await repo.saveEntry(makeEntry('2026-03-02'));
      final result = await repo.exportAllEntries();
      expect(result.length, 3);
      expect(result[0]['date'], '2026-03-01');
      expect(result[2]['date'], '2026-03-03');
    });
  });

  group('getAverageEmotion', () {
    test('returns 0 for empty database', () async {
      final result = await repo.getAverageEmotion(7);
      expect(result, 0.0);
    });

    test('calculates correct average for exact day range', () async {
      final today = DateTime.now();
      // Create entries for exactly 3 days
      for (int i = 0; i < 3; i++) {
        final date = today.subtract(Duration(days: i));
        await repo.saveEntry(makeEntry(
          du.dateToString(date),
          emotion: (i + 3).clamp(1, 5), // emotions: 3, 4, 5
        ));
      }
      final result = await repo.getAverageEmotion(3);
      expect(result, closeTo(4.0, 0.1)); // avg of 3,4,5 = 4.0
    });
  });

  group('getEmotionByDayOfWeek', () {
    test('returns empty map for no entries', () async {
      final result = await repo.getEmotionByDayOfWeek();
      expect(result, isEmpty);
    });
  });

  group('importEntries', () {
    test('imports entries from valid JSON format', () async {
      final entries = [
        {
          'date': '2026-03-01',
          'emotion': 4,
          'prompts': [
            {'category': 'gratitude', 'question': '감사한 것', 'answer': '가족'},
            {'category': 'acceptance', 'question': '수용할 것', 'answer': '실수'},
            {'category': 'intention', 'question': '의도', 'answer': '운동'},
          ],
        },
        {
          'date': '2026-03-02',
          'emotion': 3,
          'prompts': [
            {'category': 'gratitude', 'question': '감사한 것', 'answer': '날씨'},
            {'category': 'acceptance', 'question': '수용할 것', 'answer': ''},
            {'category': 'intention', 'question': '의도', 'answer': '독서'},
          ],
        },
      ];
      final count = await repo.importEntries(entries);
      expect(count, 2);
      expect(await repo.getTotalCount(), 2);

      final entry = await repo.getEntryByDate('2026-03-01');
      expect(entry!.emotion, 4);
      expect(entry.answer1, '가족');
      expect(entry.prompt1, '감사한 것');
    });

    test('skips entries with missing required fields', () async {
      final entries = [
        {'date': '2026-03-01'}, // missing emotion and prompts
        {
          'date': '2026-03-02',
          'emotion': 3,
          'prompts': [
            {'category': 'gratitude', 'question': 'q', 'answer': 'a'},
          ],
        },
      ];
      final count = await repo.importEntries(entries);
      expect(count, 1);
    });

    test('overwrites existing entries on same date', () async {
      await repo.saveEntry(makeEntry('2026-03-01', emotion: 2));
      final entries = [
        {
          'date': '2026-03-01',
          'emotion': 5,
          'prompts': [
            {'category': 'gratitude', 'question': 'q', 'answer': 'new'},
            {'category': 'acceptance', 'question': 'q2', 'answer': ''},
            {'category': 'intention', 'question': 'q3', 'answer': ''},
          ],
        },
      ];
      await repo.importEntries(entries);
      final entry = await repo.getEntryByDate('2026-03-01');
      expect(entry!.emotion, 5);
      expect(entry.answer1, 'new');
    });

    test('clamps emotion values to valid range', () async {
      final entries = [
        {
          'date': '2026-03-01',
          'emotion': 10,
          'prompts': [
            {'category': 'gratitude', 'question': 'q', 'answer': 'a'},
          ],
        },
      ];
      await repo.importEntries(entries);
      final entry = await repo.getEntryByDate('2026-03-01');
      expect(entry!.emotion, 5); // clamped to max
    });
  });

  group('deleteAllEntries', () {
    test('deletes all entries', () async {
      await repo.saveEntry(makeEntry('2026-03-01'));
      await repo.saveEntry(makeEntry('2026-03-02'));
      await repo.deleteAllEntries();
      expect(await repo.getTotalCount(), 0);
    });
  });
}

