import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';

void main() {
  group('DailyEntry.fromEntry', () {
    test('preserves all fields from Entry', () {
      final now = DateTime(2026, 3, 14, 21, 30);
      final entry = Entry(
        id: 42,
        date: '2026-03-14',
        emotion: 4,
        prompt1: '감사 질문',
        answer1: '맑은 날씨',
        prompt2: '수용 질문',
        answer2: '긴장했다',
        prompt3: '의도 질문',
        answer3: '침착한 사람',
        createdAt: now,
        updatedAt: now,
      );

      final daily = DailyEntry.fromEntry(entry);

      expect(daily.id, 42);
      expect(daily.date, '2026-03-14');
      expect(daily.emotion, 4);
      expect(daily.prompt1, '감사 질문');
      expect(daily.answer1, '맑은 날씨');
      expect(daily.prompt2, '수용 질문');
      expect(daily.answer2, '긴장했다');
      expect(daily.prompt3, '의도 질문');
      expect(daily.answer3, '침착한 사람');
      expect(daily.createdAt, now);
      expect(daily.updatedAt, now);
    });
  });

  group('DailyEntry.toJson', () {
    test('produces correct JSON structure per PRD 4.5', () {
      final entry = DailyEntry(
        date: '2026-03-14',
        emotion: 4,
        prompt1: '감사 질문',
        answer1: '맑은 날씨',
        prompt2: '수용 질문',
        answer2: '긴장했다',
        prompt3: '의도 질문',
        answer3: '침착한 사람',
        createdAt: DateTime(2026, 3, 14, 21, 30),
      );

      final json = entry.toJson();

      expect(json['date'], '2026-03-14');
      expect(json['emotion'], 4);
      expect(json['prompts'], isA<List>());
      expect((json['prompts'] as List).length, 3);

      final p1 = (json['prompts'] as List)[0] as Map;
      expect(p1['category'], 'gratitude');
      expect(p1['question'], '감사 질문');
      expect(p1['answer'], '맑은 날씨');

      final p2 = (json['prompts'] as List)[1] as Map;
      expect(p2['category'], 'acceptance');

      final p3 = (json['prompts'] as List)[2] as Map;
      expect(p3['category'], 'intention');
    });

    test('created_at includes timezone offset', () {
      final entry = DailyEntry(
        date: '2026-03-14',
        emotion: 3,
        createdAt: DateTime(2026, 3, 14, 21, 30),
      );

      final json = entry.toJson();
      final createdAt = json['created_at'] as String;

      expect(
        RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}')
            .hasMatch(createdAt),
        isTrue,
        reason: 'created_at should include timezone offset: $createdAt',
      );
    });
  });

  group('DailyEntry.copyWith', () {
    test('copies with new values', () {
      final entry = DailyEntry(
        date: '2026-03-14',
        emotion: 3,
        answer1: 'original',
      );

      final copy = entry.copyWith(emotion: 5, answer1: 'modified');
      expect(copy.emotion, 5);
      expect(copy.answer1, 'modified');
      expect(copy.date, '2026-03-14');
    });

    test('preserves unchanged values', () {
      final entry = DailyEntry(
        date: '2026-03-14',
        emotion: 3,
        prompt1: 'q1',
        answer1: 'a1',
        prompt2: 'q2',
        answer2: 'a2',
        prompt3: 'q3',
        answer3: 'a3',
      );

      final copy = entry.copyWith(emotion: 5);
      expect(copy.prompt1, 'q1');
      expect(copy.answer1, 'a1');
      expect(copy.prompt2, 'q2');
      expect(copy.answer2, 'a2');
      expect(copy.prompt3, 'q3');
      expect(copy.answer3, 'a3');
    });
  });

  group('DailyEntry.toCompanion', () {
    test('creates companion with correct fields', () {
      final entry = DailyEntry(
        date: '2026-03-14',
        emotion: 4,
        prompt1: 'q1',
        answer1: 'a1',
      );

      final companion = entry.toCompanion();
      expect(companion.date.value, '2026-03-14');
      expect(companion.emotion.value, 4);
      expect(companion.prompt1.value, 'q1');
      expect(companion.answer1.value, 'a1');
    });
  });
}
