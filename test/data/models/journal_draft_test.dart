import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/data/models/journal_draft.dart';
import 'package:three_lines/data/models/daily_entry.dart';

void main() {
  test('필수 nullable key 누락은 null로 조용히 해석하지 않는다', () {
    final draft = JournalDraft(
      date: '2026-10-11',
      revision: 1,
      prompts: ['a', 'b', 'c'],
      answers: ['입력', '', ''],
      baseline: DailyEntry(id: 1, date: '2026-10-11', emotion: 3),
    );
    for (final key in ['emotion', 'photo', 'baseline', 'baseline.photo']) {
      final payload = jsonDecode(draft.encode()) as Map<String, dynamic>;
      if (key == 'baseline.photo') {
        (payload['baseline'] as Map).remove('photo');
      } else {
        payload.remove(key);
      }
      expect(
        () => JournalDraft.decode(jsonEncode(payload), date: draft.date),
        throwsFormatException,
      );
    }
  });
  test('손상 초안은 버전 날짜 배열 감정 revision과 사진 타입을 거절한다', () {
    final valid = <String, dynamic>{
      'version': 1,
      'date': '2026-10-11',
      'revision': 1,
      'prompts': ['a', 'b', 'c'],
      'answers': ['', '', ''],
      'emotion': null,
      'photo': null,
      'baseline': null,
    };
    for (final broken in <Map<String, dynamic>>[
      {...valid, 'version': 1.0},
      {...valid, 'date': '2026-02-30'},
      {
        ...valid,
        'prompts': ['a', 'b'],
      },
      {
        ...valid,
        'answers': [1, '', ''],
      },
      {...valid, 'emotion': 0},
      {...valid, 'revision': 0},
      {...valid, 'photo': false},
      {
        ...valid,
        'baseline': {'id': 1, 'date': '2026-10-11'},
      },
    ]) {
      expect(
        () => JournalDraft.decode(jsonEncode(broken), date: '2026-10-11'),
        throwsFormatException,
      );
    }
  });
  test('입력 목록이 변경돼도 보관 snapshot은 바뀌지 않는다', () {
    final prompts = ['a', 'b', 'c'];
    final answers = ['첫 입력', '', ''];
    final draft = JournalDraft(
      date: '2026-10-11',
      revision: 1,
      prompts: prompts,
      answers: answers,
    );
    prompts[0] = '변경';
    answers[0] = '변경';
    expect(
      JournalDraft.decode(draft.encode(), date: '2026-10-11').answers[0],
      '첫 입력',
    );
    expect(draft.prompts[0], 'a');
    expect(() => draft.answers[0] = '변경', throwsUnsupportedError);
  });
}
