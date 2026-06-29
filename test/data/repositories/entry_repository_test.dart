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

  // Wide date range for tests that don't care about filtering
  final allStart = DateTime(2020, 1, 1);
  final allEnd = DateTime(2030, 12, 31);

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

    test('grace day bridges a single-day gap', () async {
      final today = DateTime.now();
      await repo.saveEntry(makeEntry(du.dateToString(today)));
      await repo.saveEntry(
          makeEntry(du.dateToString(today.subtract(const Duration(days: 1)))));
      // Gap at day -2, entry at day -3
      await repo.saveEntry(
          makeEntry(du.dateToString(today.subtract(const Duration(days: 3)))));
      // Grace day bridges the gap: streak = 3
      expect(await repo.getCurrentStreak(), 3);
    });

    test('breaks streak on two-day gap', () async {
      final today = DateTime.now();
      await repo.saveEntry(makeEntry(du.dateToString(today)));
      await repo.saveEntry(
          makeEntry(du.dateToString(today.subtract(const Duration(days: 1)))));
      // Two-day gap (days -2 and -3 missing), entry at day -4
      await repo.saveEntry(
          makeEntry(du.dateToString(today.subtract(const Duration(days: 4)))));
      expect(await repo.getCurrentStreak(), 2);
    });
  });

  group('getCurrentStreakWithGrace', () {
    test('returns count=0 and usedGraceDay=false for empty database', () async {
      final result = await repo.getCurrentStreakWithGrace();
      expect(result.count, 0);
      expect(result.usedGraceDay, isFalse);
    });

    test('returns correct count for consecutive streak', () async {
      final today = DateTime.now();
      for (int i = 0; i < 3; i++) {
        await repo.saveEntry(makeEntry(
            du.dateToString(today.subtract(Duration(days: i)))));
      }
      final result = await repo.getCurrentStreakWithGrace();
      // Grace day is consumed at the natural end-of-history boundary,
      // so usedGraceDay is true even for a gap-free streak.
      expect(result.count, 3);
      expect(result.usedGraceDay, isTrue);
    });

    test('returns usedGraceDay=true when one day gap is bridged', () async {
      final today = DateTime.now();
      await repo.saveEntry(makeEntry(du.dateToString(today)));
      await repo.saveEntry(
          makeEntry(du.dateToString(today.subtract(const Duration(days: 1)))));
      // gap at day -2
      await repo.saveEntry(
          makeEntry(du.dateToString(today.subtract(const Duration(days: 3)))));

      final result = await repo.getCurrentStreakWithGrace();
      expect(result.count, 3);
      expect(result.usedGraceDay, isTrue);
    });

    test('returns count=1 for single entry today', () async {
      final today = DateTime.now();
      await repo.saveEntry(makeEntry(du.dateToString(today)));

      final result = await repo.getCurrentStreakWithGrace();
      expect(result.count, 1);
      // Grace consumed at trailing end of single-day streak
      expect(result.usedGraceDay, isTrue);
    });

    test('breaks on two-day gap even with grace day already used', () async {
      final today = DateTime.now();
      await repo.saveEntry(makeEntry(du.dateToString(today)));
      // gap day -1 (grace used here)
      await repo.saveEntry(
          makeEntry(du.dateToString(today.subtract(const Duration(days: 2)))));
      // two-day gap (days -3 and -4 missing) — grace already used
      await repo.saveEntry(
          makeEntry(du.dateToString(today.subtract(const Duration(days: 5)))));

      final result = await repo.getCurrentStreakWithGrace();
      // Streak is 1 (today) + grace + 1 (day-2) = count 2, then breaks
      expect(result.count, 2);
      expect(result.usedGraceDay, isTrue);
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
      // 2-day gap (03-04, 03-05 missing) — too large for grace day
      // Streak 2: 5 days
      await repo.saveEntry(makeEntry('2026-03-06'));
      await repo.saveEntry(makeEntry('2026-03-07'));
      await repo.saveEntry(makeEntry('2026-03-08'));
      await repo.saveEntry(makeEntry('2026-03-09'));
      await repo.saveEntry(makeEntry('2026-03-10'));
      expect(await repo.getLongestStreak(), 5);
    });

    test('returns 1 for single entry', () async {
      await repo.saveEntry(makeEntry('2026-03-01'));
      expect(await repo.getLongestStreak(), 1);
    });

    test('grace day는 스트릭당 1회만 허용 (격일 기록은 무한 연속이 아님)', () async {
      // 03-01, 03-03, 03-05: 각각 1일 공백. grace는 1회만 적용되어야 하므로
      // 두 번째 공백에서 끊겨 최장 2가 된다(무제한 grace 회귀 방지).
      await repo.saveEntry(makeEntry('2026-03-01'));
      await repo.saveEntry(makeEntry('2026-03-03'));
      await repo.saveEntry(makeEntry('2026-03-05'));
      expect(await repo.getLongestStreak(), 2);
    });

    test('연속 기록 후 1일 공백은 grace로 이어진다', () async {
      // 03-01,03-02 연속 → 03-04 1일 공백(grace) = 최장 3
      await repo.saveEntry(makeEntry('2026-03-01'));
      await repo.saveEntry(makeEntry('2026-03-02'));
      await repo.saveEntry(makeEntry('2026-03-04'));
      expect(await repo.getLongestStreak(), 3);
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

  group('getAverageEmotion', () {
    test('returns 0 for empty database', () async {
      final result = await repo.getAverageEmotion(allStart, allEnd);
      expect(result, 0.0);
    });

    test('calculates correct average for exact day range', () async {
      final today = DateTime.now();
      for (int i = 0; i < 3; i++) {
        final date = today.subtract(Duration(days: i));
        await repo.saveEntry(makeEntry(
          du.dateToString(date),
          emotion: (i + 3).clamp(1, 5), // emotions: 3, 4, 5
        ));
      }
      final start = today.subtract(const Duration(days: 2));
      final result = await repo.getAverageEmotion(start, today);
      expect(result, closeTo(4.0, 0.1)); // avg of 3,4,5 = 4.0
    });
  });

  group('getEmotionByDayOfWeek', () {
    test('returns empty map for no entries', () async {
      final result = await repo.getEmotionByDayOfWeek(allStart, allEnd);
      expect(result, isEmpty);
    });

    test('respects date range', () async {
      await repo.saveEntry(makeEntry('2026-02-15', emotion: 1)); // outside range
      await repo.saveEntry(makeEntry('2026-03-10', emotion: 4)); // inside range
      final result = await repo.getEmotionByDayOfWeek(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );
      // Only the March entry should be included
      expect(result.length, 1);
    });
  });

  group('getKeywordFrequency', () {
    test('returns empty for no entries', () async {
      final result = await repo.getKeywordFrequency(allStart, allEnd);
      expect(result, isEmpty);
    });

    test('returns empty for entries with empty answers', () async {
      await repo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 3,
      ));
      final result = await repo.getKeywordFrequency(allStart, allEnd);
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
      final result = await repo.getKeywordFrequency(allStart, allEnd);
      expect(result, isNotEmpty);
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
      final result = await repo.getGratitudeKeywords(allStart, allEnd);
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
      final result = await repo.importEntries(entries);
      expect(result.imported, 2);
      expect(result.skipped, 0);
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
      final result = await repo.importEntries(entries);
      expect(result.imported, 1);
      expect(result.skipped, 1);
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

    test('손상된 prompts(비-Map) 항목이 있어도 다음 정상 항목은 import된다', () async {
      // 회귀 방지: 과거엔 prompts[i] as Map의 ClassCastError가 try-catch 밖에서
      // 발생해 transaction 전체가 중단되며 정상 항목까지 누락됐다.
      final entries = [
        {
          'date': '2026-03-01',
          'emotion': 3,
          'prompts': ['not-a-map', 123, null],
        },
        {
          'date': '2026-03-02',
          'emotion': 4,
          'prompts': [
            {'question': 'q', 'answer': '정상'},
          ],
        },
      ];
      await repo.importEntries(entries);
      final ok = await repo.getEntryByDate('2026-03-02');
      expect(ok, isNotNull);
      expect(ok!.answer1, '정상');
    });

    test('깨진 created_at/updated_at 문자열도 throw 없이 import된다', () async {
      final entries = [
        {
          'date': '2026-03-03',
          'emotion': 2,
          'prompts': [
            {'question': 'q', 'answer': 'a'},
          ],
          'created_at': 'not-a-date',
          'updated_at': '!!!',
        },
      ];
      final result = await repo.importEntries(entries);
      expect(result.imported, 1);
      expect(await repo.getEntryByDate('2026-03-03'), isNotNull);
    });

    test('emotion이 숫자가 아니면 해당 항목만 skip되고 나머지는 import된다', () async {
      final entries = [
        {
          'date': '2026-03-04',
          'emotion': 'oops',
          'prompts': [
            {'question': 'q', 'answer': 'a'},
          ],
        },
        {
          'date': '2026-03-05',
          'emotion': 4,
          'prompts': [
            {'question': 'q', 'answer': 'ok'},
          ],
        },
      ];
      final result = await repo.importEntries(entries);
      expect(result.skipped, 1);
      expect(result.imported, 1);
      expect(await repo.getEntryByDate('2026-03-05'), isNotNull);
    });
  });

  group('export/import round-trip', () {
    test('exported data can be re-imported faithfully', () async {
      await repo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 4,
        prompt1: '감사한 것은?',
        answer1: '가족과 저녁',
        prompt2: '수용할 것은?',
        answer2: '실수를 인정',
        prompt3: '내일의 의도는?',
        answer3: '일찍 일어나기',
      ));
      await repo.saveEntry(DailyEntry(
        date: '2026-03-02',
        emotion: 2,
        prompt1: '감사한 것은?',
        answer1: '좋은 날씨',
        prompt2: '수용할 것은?',
        answer2: '',
        prompt3: '내일의 의도는?',
        answer3: '운동하기',
      ));

      final exported = await repo.exportAllEntries();
      expect(exported.length, 2);

      await repo.deleteAllEntries();
      expect(await repo.getTotalCount(), 0);

      final result = await repo.importEntries(exported);
      expect(result.imported, 2);
      expect(await repo.getTotalCount(), 2);

      final entry1 = await repo.getEntryByDate('2026-03-01');
      expect(entry1!.emotion, 4);
      expect(entry1.answer1, '가족과 저녁');
      expect(entry1.answer2, '실수를 인정');
      expect(entry1.answer3, '일찍 일어나기');
      expect(entry1.prompt1, '감사한 것은?');

      final entry2 = await repo.getEntryByDate('2026-03-02');
      expect(entry2!.emotion, 2);
      expect(entry2.answer1, '좋은 날씨');
      expect(entry2.answer2, '');
    });
  });

  group('searchEntries', () {
    test('returns empty list when no matches', () async {
      await repo.saveEntry(makeEntry('2026-03-01', answer1: '오늘 운동했다'));
      final result = await repo.searchEntries('여행');
      expect(result, isEmpty);
    });

    test('finds matches in answer1', () async {
      await repo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 4,
        answer1: '가족과 여행',
        answer2: '',
        answer3: '',
      ));
      final result = await repo.searchEntries('여행');
      expect(result.length, 1);
      expect(result.first.date, '2026-03-01');
    });

    test('finds matches in answer2 and answer3', () async {
      await repo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 3,
        answer1: '',
        answer2: '프로젝트 완료',
        answer3: '',
      ));
      await repo.saveEntry(DailyEntry(
        date: '2026-03-02',
        emotion: 4,
        answer1: '',
        answer2: '',
        answer3: '프로젝트 시작',
      ));
      final result = await repo.searchEntries('프로젝트');
      expect(result.length, 2);
    });

    test('returns results in descending date order', () async {
      await repo.saveEntry(makeEntry('2026-03-01', answer1: '운동'));
      await repo.saveEntry(makeEntry('2026-03-05', answer1: '운동'));
      await repo.saveEntry(makeEntry('2026-03-03', answer1: '운동'));
      final result = await repo.searchEntries('운동');
      expect(result.length, 3);
      expect(result[0].date, '2026-03-05');
      expect(result[1].date, '2026-03-03');
      expect(result[2].date, '2026-03-01');
    });

    test('handles special characters in query', () async {
      await repo.saveEntry(makeEntry('2026-03-01', answer1: '100% 완료'));
      final result = await repo.searchEntries('100%');
      expect(result.length, 1);
    });
  });

  group('deleteEntry', () {
    test('removes entry from database', () async {
      await repo.saveEntry(makeEntry('2026-03-01'));
      await repo.deleteEntry('2026-03-01');
      expect(await repo.getEntryByDate('2026-03-01'), isNull);
    });

    test('does nothing for non-existent date', () async {
      await repo.deleteEntry('2099-01-01');
      expect(await repo.getTotalCount(), 0);
    });

    test('only removes the targeted date', () async {
      await repo.saveEntry(makeEntry('2026-03-01'));
      await repo.saveEntry(makeEntry('2026-03-02'));
      await repo.deleteEntry('2026-03-01');
      expect(await repo.getEntryByDate('2026-03-01'), isNull);
      expect(await repo.getEntryByDate('2026-03-02'), isNotNull);
    });
  });

  group('getAllPhotoPaths', () {
    test('returns empty list when no entries have photos', () async {
      await repo.saveEntry(makeEntry('2026-03-01'));
      final paths = await repo.getAllPhotoPaths();
      expect(paths, isEmpty);
    });

    test('returns paths only for entries with photos', () async {
      await repo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 3,
        photoPath: '/photos/photo1.jpg',
      ));
      await repo.saveEntry(makeEntry('2026-03-02')); // no photo
      await repo.saveEntry(DailyEntry(
        date: '2026-03-03',
        emotion: 4,
        photoPath: '/photos/photo2.jpg',
      ));
      final paths = await repo.getAllPhotoPaths();
      expect(paths.length, 2);
      expect(paths, containsAll(['/photos/photo1.jpg', '/photos/photo2.jpg']));
    });

    test('returns empty list for empty database', () async {
      expect(await repo.getAllPhotoPaths(), isEmpty);
    });
  });

  group('getPreviousEntry', () {
    test('returns null when no previous entry exists', () async {
      await repo.saveEntry(makeEntry('2026-03-01'));
      expect(await repo.getPreviousEntry('2026-03-01'), isNull);
    });

    test('returns the closest entry before the given date', () async {
      await repo.saveEntry(makeEntry('2026-03-01', emotion: 1));
      await repo.saveEntry(makeEntry('2026-03-03', emotion: 3));
      await repo.saveEntry(makeEntry('2026-03-05', emotion: 5));
      final result = await repo.getPreviousEntry('2026-03-05');
      expect(result?.date, '2026-03-03');
      expect(result?.emotion, 3);
    });

    test('skips non-adjacent dates correctly', () async {
      await repo.saveEntry(makeEntry('2026-03-01', emotion: 2));
      await repo.saveEntry(makeEntry('2026-03-10', emotion: 4));
      final result = await repo.getPreviousEntry('2026-03-10');
      expect(result?.date, '2026-03-01');
    });
  });

  group('getNextEntry', () {
    test('returns null when no next entry exists', () async {
      await repo.saveEntry(makeEntry('2026-03-05'));
      expect(await repo.getNextEntry('2026-03-05'), isNull);
    });

    test('returns the closest entry after the given date', () async {
      await repo.saveEntry(makeEntry('2026-03-01', emotion: 1));
      await repo.saveEntry(makeEntry('2026-03-03', emotion: 3));
      await repo.saveEntry(makeEntry('2026-03-05', emotion: 5));
      final result = await repo.getNextEntry('2026-03-01');
      expect(result?.date, '2026-03-03');
      expect(result?.emotion, 3);
    });

    test('skips non-adjacent dates correctly', () async {
      await repo.saveEntry(makeEntry('2026-03-01', emotion: 2));
      await repo.saveEntry(makeEntry('2026-03-10', emotion: 4));
      final result = await repo.getNextEntry('2026-03-01');
      expect(result?.date, '2026-03-10');
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

  group('getWeeklyRetrospective', () {
    test('returns null for empty database', () async {
      expect(await repo.getWeeklyRetrospective(), isNull);
    });

    test('returns null for single entry', () async {
      final today = DateTime.now();
      await repo.saveEntry(makeEntry(
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        emotion: 4,
      ));
      expect(await repo.getWeeklyRetrospective(), isNull);
    });

    test('returns valid retrospective for 3+ recent entries', () async {
      final now = DateTime.now();
      for (int i = 0; i < 4; i++) {
        final d = now.subtract(Duration(days: i));
        final dateStr =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        await repo.saveEntry(makeEntry(dateStr,
            emotion: i == 0 ? 5 : 3, answer1: '산책이 좋았다'));
      }
      final retro = await repo.getWeeklyRetrospective();
      expect(retro, isNotNull);
      expect(retro!.entryCount, 4);
      expect(retro.averageEmotion, greaterThan(0));
      expect(retro.bestDay, isNotNull);
      expect(retro.summaryText, contains('지난 7일간'));
    });

    test('detects rising trend', () async {
      final now = DateTime.now();
      // Older entries: low emotion, newer entries: high emotion
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final dateStr =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        await repo.saveEntry(makeEntry(dateStr,
            emotion: i > 3 ? 1 : 5));
      }
      final retro = await repo.getWeeklyRetrospective();
      expect(retro, isNotNull);
      expect(retro!.trendDescription, contains('좋아지는'));
    });
  });

  group('getMonthlySummary', () {
    test('returns zeros for empty month', () async {
      final result = await repo.getMonthlySummary(2026, 3);
      expect(result.averageEmotion, 0.0);
      expect(result.entryCount, 0);
      expect(result.topKeyword, '');
    });

    test('returns correct summary for month with entries', () async {
      await repo.saveEntry(makeEntry('2026-03-01',
          emotion: 4, answer1: '맑은 날씨가 좋았다'));
      await repo.saveEntry(makeEntry('2026-03-02',
          emotion: 2, answer1: '맑은 하늘이 예뻤다'));
      await repo.saveEntry(makeEntry('2026-03-03',
          emotion: 3, answer1: '산책이 즐거웠다'));

      final result = await repo.getMonthlySummary(2026, 3);
      expect(result.entryCount, 3);
      expect(result.averageEmotion, 3.0);
      expect(result.topKeyword, isNotEmpty);
    });

    test('only includes entries from the specified month', () async {
      await repo.saveEntry(makeEntry('2026-02-28', emotion: 5));
      await repo.saveEntry(makeEntry('2026-03-01', emotion: 3));
      await repo.saveEntry(makeEntry('2026-04-01', emotion: 1));

      final result = await repo.getMonthlySummary(2026, 3);
      expect(result.entryCount, 1);
      expect(result.averageEmotion, 3.0);
    });
  });
}
