import 'dart:async';
import 'dart:convert';
import 'package:three_lines/data/models/journal_draft.dart';
import 'package:three_lines/data/models/entry_import.dart';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
  tearDown(() => db.close());
  Future<ImportResult> importBackup(List<Map<String, dynamic>> rows) async {
    final preview = await repo.previewImport(jsonEncode(rows));
    return repo.applyImport(preview, policy: ConflictPolicy.replacePreviewed);
  }

  test('책갈피는 내용과 시각을 바꾸지 않고 일반 수정 뒤에도 유지된다', () async {
    final written = DateTime.utc(2025, 1, 1);
    await repo.saveEntry(
      DailyEntry(
        date: '2025-01-01',
        emotion: 2,
        answer1: '원문',
        createdAt: written,
        updatedAt: written,
      ),
      preserveTimestamps: true,
    );
    expect(await repo.setBookmarked('2025-01-01', true), isTrue);
    var entry = (await repo.getEntryByDate('2025-01-01'))!;
    expect(entry.answer1, '원문');
    expect(entry.updatedAt.toUtc(), written);
    expect(entry.isBookmarked, isTrue);
    expect(entry.copyWith(answer1: '복사').isBookmarked, isTrue);
    expect(entry == entry.copyWith(isBookmarked: false), isFalse);
    await repo.saveEntry(
      DailyEntry(date: '2025-01-01', emotion: 3, answer1: '수정'),
    );
    entry = (await repo.getEntryByDate('2025-01-01'))!;
    expect(entry.isBookmarked, isTrue);
    expect(entry.answer1, '수정');
    expect((await repo.searchEntries('수정')).single.isBookmarked, isTrue);
  });

  test('모든 날짜의 책갈피를 최신순으로 읽고 삭제한 기록은 다시 생성하지 않는다', () async {
    for (final date in ['2020-01-01', '2026-11-06', '2024-05-01']) {
      await repo.saveEntry(DailyEntry(date: date, emotion: 1));
      await repo.setBookmarked(date, true);
    }
    expect((await repo.watchBookmarkedEntries().first).map((e) => e.date), [
      '2026-11-06',
      '2024-05-01',
      '2020-01-01',
    ]);
    await repo.deleteEntry('2024-05-01');
    expect(await repo.setBookmarked('2024-05-01', true), isFalse);
    expect((await repo.watchBookmarkedEntries().first).length, 2);
    await repo.deleteAllEntries();
    expect(await repo.watchBookmarkedEntries().first, isEmpty);
  });

  test('감정만 기록한 책갈피도 JSON으로 왕복하고 오래된 백업은 기존 표시를 지우지 않는다', () async {
    await repo.saveEntry(DailyEntry(date: '2026-11-06', emotion: 2));
    await repo.setBookmarked('2026-11-06', true);
    final backup = await repo.exportAllEntries();
    expect(backup.single['is_bookmarked'], isTrue);
    await repo.deleteAllEntries();
    await importBackup(backup);
    final entry = (await repo.getEntryByDate('2026-11-06'))!;
    expect(entry.hasAnswers, isFalse);
    expect(entry.isBookmarked, isTrue);
    expect(entry.emotion, 2);
    final legacy = Map<String, dynamic>.from(backup.single)
      ..remove('is_bookmarked');
    await importBackup([legacy]);
    expect((await repo.getEntryByDate('2026-11-06'))!.isBookmarked, isTrue);
    await importBackup([
      {...legacy, 'date': '2026-11-05'},
    ]);
    expect((await repo.getEntryByDate('2026-11-05'))!.isBookmarked, isFalse);
    await importBackup([
      {...legacy, 'is_bookmarked': false},
    ]);
    expect((await repo.getEntryByDate('2026-11-06'))!.isBookmarked, isFalse);
    final invalid = await importBackup([
      {...legacy, 'is_bookmarked': 'true'},
    ]);
    expect(invalid.invalid, 1);
    expect(invalid.changedCount, 0);
  });

  test('책갈피가 바뀌어도 재로딩한 수정 초안을 저장하고 현재 표시를 보존한다', () async {
    await repo.saveEntry(
      DailyEntry(date: '2026-11-06', emotion: 3, answer1: '원문'),
    );
    await repo.setBookmarked('2026-11-06', true);
    final baseline = (await repo.getEntryByDate('2026-11-06'))!;
    final draft = JournalDraft(
      date: baseline.date,
      revision: 1,
      emotion: 2,
      prompts: [baseline.prompt1, baseline.prompt2, baseline.prompt3],
      answers: ['수정한 이야기', '', ''],
      baseline: baseline,
    );
    await repo.storeDraft(draft, epoch: repo.journalEpoch);
    final reloaded = (await repo.loadDraft(baseline.date))!;
    expect(reloaded.baseline!.isBookmarked, isTrue);
    await repo.setBookmarked(baseline.date, false);
    final saved = await repo.commitDraft(reloaded, epoch: repo.journalEpoch);
    expect(saved.answer1, '수정한 이야기');
    expect(saved.isBookmarked, isFalse);
  });

  test('스트림은 책갈피 추가와 해제를 반영한다', () async {
    await repo.saveEntry(DailyEntry(date: '2026-11-06', emotion: 3));
    final stream = StreamIterator(repo.watchIsBookmarked('2026-11-06'));
    await stream.moveNext();
    expect(stream.current, isFalse);
    await repo.setBookmarked('2026-11-06', true);
    await stream.moveNext();
    expect(stream.current, isTrue);
    await repo.setBookmarked('2026-11-06', false);
    await stream.moveNext();
    expect(stream.current, isFalse);
    await stream.cancel();
  });
}
