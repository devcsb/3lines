import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/data/models/daily_entry.dart';
import '../../../lib/data/models/entry_import.dart';
import '../../helpers/import_fixtures.dart';

void main() {
  group('parseImportJson', () {
    test('무효 첫 항목은 날짜를 선점하지 않고 뒤 유효 항목만 중복이다', () {
      final parsed = parseImportJson(
        jsonEncode([
          importRecord('2026-09-29', emotion: 1.2),
          importRecord('2026-09-29', emotion: 5.0),
          importRecord('2026-09-29'),
          7,
        ]),
        now: DateTime(2026, 9, 30),
      );
      expect(parsed.candidates, hasLength(1));
      expect(parsed.candidates.single.emotion, 5);
      expect((parsed.invalid, parsed.duplicate, parsed.inputCount), (2, 1, 4));
      expect(() => parsed.candidates.clear(), throwsUnsupportedError);
      expect(() => parsed.entries.clear(), throwsUnsupportedError);
      final first = parsed.entries.first as Map;
      expect(() => first['date'] = '2000-01-01', throwsUnsupportedError);
      expect(() => (first['prompts'] as List).clear(), throwsUnsupportedError);
    });

    test('envelope 오류는 목록 분류와 구분한다', () {
      for (final bad in [
        '',
        'null',
        '{}',
        '{"entries":{}}',
        '{"app":7,"entries":[]}',
        '{"app":"other","entries":[]}',
        '{"version":1,"entries":[]}',
      ]) {
        expect(
          () => parseImportJson(bad, now: DateTime(2026, 9, 30)),
          throwsFormatException,
        );
      }
      for (final ok in [
        '[]',
        '{"entries":[]}',
        '{"app":"3Lines","version":"x","entries":[]}',
      ]) {
        expect(parseImportJson(ok, now: DateTime(2026, 9, 30)).inputCount, 0);
      }
    });

    test('날짜, 감정, 세 prompt와 timestamp를 엄격하게 분류한다', () {
      final bad = <Object?>[
        for (final date in ['2026-2-01', '2026-02-30', '2026-10-01'])
          importRecord(date),
        for (final emotion in [0, 6, 2.5, '3'])
          importRecord('2026-09-29', emotion: emotion),
        {...importRecord('2026-09-29'), 'prompts': []},
        {
          ...importRecord('2026-09-29'),
          'prompts': [1, 2, 3],
        },
        importRecord('2026-09-29', answer: ' \n '),
        {...importRecord('2026-09-29'), 'created_at': 4},
        {...importRecord('2026-09-29'), 'updated_at': 'broken'},
      ];
      final parsed = parseImportJson(
        jsonEncode(bad),
        now: DateTime(2026, 9, 30),
      );
      expect(parsed.invalid, bad.length);
      expect(parsed.candidates, isEmpty);

      final valid = parseImportJson(
        jsonEncode([
          {
            ...importRecord('2024-02-29'),
            'created_at': null,
            'updated_at': '2026-09-29T09:00:00+09:00',
            'photo_path': {'evil': true},
          },
        ]),
        now: DateTime(2026, 9, 30),
      ).candidates.single;
      expect(valid.createdAt, isNull);
      expect(valid.updatedAt, DateTime.parse('2026-09-29T09:00:00+09:00'));
      expect(valid.toEntry(DateTime(2026, 9, 30)).photoPath, isNull);
    });

    test('입력과 envelope의 재귀 스냅샷을 보존한다', () {
      final parsed = parseImportJson(
        '{"app":"3Lines","version":"x","entries":'
        '[{"date":"2026-09-29","nested":{"values":[1,2]}}]}',
        now: DateTime(2026, 9, 30),
      );
      final raw = parsed.entries.single as Map;
      expect(() => (raw['nested'] as Map)['x'] = 1, throwsUnsupportedError);
      expect(
        () => ((raw['nested'] as Map)['values'] as List).add(3),
        throwsUnsupportedError,
      );
    });
  });

  test('교체 후보는 로컬 생성시각과 사진을 유지하고 전체 snapshot을 비교한다', () {
    final old = DailyEntry(
      id: 10,
      date: '2026-09-29',
      emotion: 2,
      prompt1: '옛 질문',
      answer1: '옛 답변',
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 29),
      photoPath: '/local/photo_1.jpg',
    );
    final candidate = parseImportJson(
      jsonEncode([importRecord('2026-09-29', emotion: 5)]),
      now: DateTime(2026, 9, 30),
    ).candidates.single;
    final replacement = candidate.toEntry(
      DateTime(2026, 9, 30),
      replacing: old,
    );

    expect(replacement.id, old.id);
    expect(replacement.createdAt, old.createdAt);
    expect(replacement.photoPath, old.photoPath);
    expect(replacement.updatedAt, DateTime(2026, 9, 30));
    expect(replacement.emotion, 5);
    expect(sameImportSnapshot(old, old.copyWith()), isTrue);
    expect(
      sameImportSnapshot(old, old.copyWith(updatedAt: DateTime(2026, 9, 28))),
      isFalse,
    );
  });
}
