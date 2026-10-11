import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/app/bootstrap.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/models/journal_draft.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';

class DelayedSaveRepository extends EntryRepository {
  DelayedSaveRepository(super.db);
  Completer<void>? entered;
  Completer<void>? release;
  @override
  Future<void> saveEntry(
    DailyEntry entry, {
    bool preserveTimestamps = false,
  }) async {
    entered?.complete();
    await release?.future;
    await super.saveEntry(entry, preserveTimestamps: preserveTimestamps);
  }
}

void main() {
  late AppDatabase db;
  late EntryRepository repo;
  JournalDraft draft({
    int revision = 1,
    String date = '2026-10-11',
    String? photo,
    DailyEntry? baseline,
  }) => JournalDraft(
    date: date,
    revision: revision,
    prompts: ['질문1', '질문2', '질문3'],
    answers: ['입력', '', ''],
    emotion: 4,
    photoPath: photo,
    baseline: baseline,
  );
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
  });
  tearDown(() async {
    await db.close();
  });

  test('load는 요청된 store를 기다리고 오래된 revision 폐기를 차단한다', () async {
    final first = repo.storeDraft(draft(), epoch: 0);
    final next = repo.storeDraft(draft(revision: 2), epoch: 0);
    expect((await repo.loadDraft('2026-10-11'))!.revision, 2);
    await first;
    await next;
    await expectLater(
      repo.discardDraft('2026-10-11', revision: 1, epoch: 0),
      throwsA(isA<StaleDraft>()),
    );
    expect((await repo.loadDraft('2026-10-11'))!.revision, 2);
  });
  test('사진 참조 조회는 앞서 요청한 commit의 새 기록을 포함한다', () async {
    await repo.storeDraft(draft(photo: '/new.jpg'), epoch: 0);
    final saving = repo.commitDraft(draft(photo: '/new.jpg'), epoch: 0);
    final references = repo.getAllPhotoPaths();
    await saving;
    expect(await references, contains('/new.jpg'));
  });
  test('같은 DB의 다른 repository commit도 사진 snapshot에서 누락되지 않는다', () async {
    final writer = DelayedSaveRepository(db);
    await writer.storeDraft(draft(photo: '/shared.jpg'), epoch: 0);
    writer.entered = Completer();
    writer.release = Completer();
    final committing = writer.commitDraft(
      draft(photo: '/shared.jpg'),
      epoch: 0,
    );
    await writer.entered!.future;
    final references = repo.getAllPhotoPaths();
    writer.release!.complete();
    await committing;
    expect(await references, contains('/shared.jpg'));
    expect(await writer.listDrafts(), isEmpty);
  });
  test('timestamp만 변경한 원본도 충돌로 남기고 기록을 덮지 않는다', () async {
    await repo.saveEntry(
      DailyEntry(date: '2026-10-11', emotion: 2, answer1: '원본'),
    );
    final original = (await repo.getEntryByDate('2026-10-11'))!;
    final editing = draft(baseline: original);
    await repo.storeDraft(editing, epoch: 0);
    await repo.saveEntry(
      original.copyWith(
        updatedAt: original.updatedAt.add(const Duration(seconds: 2)),
      ),
      preserveTimestamps: true,
    );
    await expectLater(
      repo.commitDraft(editing, epoch: 0),
      throwsA(isA<DraftConflict>()),
    );
    expect((await repo.loadDraft('2026-10-11'))!.answers[0], '입력');
    expect((await repo.getEntryByDate('2026-10-11'))!.answer1, '원본');
  });
  test('초안 삭제 SQL 실패는 기록 저장까지 rollback하고 queue 재시도를 허용한다', () async {
    await repo.storeDraft(draft(), epoch: 0);
    await db.customStatement(
      "CREATE TRIGGER fail_discard BEFORE DELETE ON settings BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(repo.commitDraft(draft(), epoch: 0), throwsA(anything));
    expect(await repo.getEntryByDate('2026-10-11'), isNull);
    expect((await repo.loadDraft('2026-10-11'))!.revision, 1);
    await db.customStatement('DROP TRIGGER fail_discard');
    expect((await repo.commitDraft(draft(), epoch: 0)).answer1, '입력');
    expect(await repo.loadDraft('2026-10-11'), isNull);
  });
  test('전체삭제 뒤 enqueue된 옛 epoch write는 초안을 부활시키지 않는다', () async {
    await repo.storeDraft(draft(), epoch: 0);
    final deleting = repo.deleteAllEntries();
    final late = repo.storeDraft(draft(revision: 2), epoch: 0);
    await expectLater(late, throwsA(isA<StaleDraft>()));
    await deleting;
    expect(await repo.listDrafts(), isEmpty);
    expect(repo.journalEpoch, 1);
    await repo.storeDraft(draft(), epoch: 1);
    expect((await repo.listDrafts()).length, 1);
  });
  test('전체삭제 DB 실패는 epoch와 초안을 보존한다', () async {
    await repo.storeDraft(draft(), epoch: 0);
    await db.customStatement(
      "INSERT INTO settings(key,value) VALUES ('theme_mode','dark')",
    );
    await db.customStatement(
      "CREATE TRIGGER fail_delete BEFORE DELETE ON settings BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(repo.deleteAllEntries(), throwsA(anything));
    expect(repo.journalEpoch, 0);
    await db.customStatement('DROP TRIGGER fail_delete');
    await repo.storeDraft(draft(revision: 2), epoch: 0);
    await repo.deleteAllEntries();
    expect(
      (await db
              .customSelect("SELECT value FROM settings WHERE key='theme_mode'")
              .getSingle())
          .read<String>('value'),
      'dark',
    );
  });
  test('지연 commit 뒤 전체삭제는 저장 기록과 초안을 함께 지운다', () async {
    final delayed = DelayedSaveRepository(db);
    await delayed.storeDraft(draft(), epoch: 0);
    delayed.entered = Completer();
    delayed.release = Completer();
    final saving = delayed.commitDraft(draft(), epoch: 0);
    await delayed.entered!.future;
    final deleting = delayed.deleteAllEntries();
    delayed.release!.complete();
    await saving;
    await deleting;
    expect(await delayed.getTotalCount(), 0);
    expect(await delayed.listDrafts(), isEmpty);
  });
  test('복수 날짜 current와 baseline 사진을 startup와 명시 정리가 보존한다', () async {
    final dir = await Directory.systemTemp.createTemp('three-lines-drafts-');
    try {
      final photos = await Directory('${dir.path}/photos').create();
      final current = await File(
        '${photos.path}/photo_1.jpg',
      ).writeAsString('current');
      final baselinePhoto = await File(
        '${photos.path}/photo_2.jpg',
      ).writeAsString('baseline');
      final unused = await File(
        '${photos.path}/photo_3.jpg',
      ).writeAsString('unused');
      await repo.saveEntry(
        DailyEntry(
          date: '2026-10-10',
          emotion: 3,
          answer1: '원본',
          photoPath: baselinePhoto.path,
        ),
      );
      final baseline = await repo.getEntryByDate('2026-10-10');
      await repo.storeDraft(
        draft(date: '2026-10-10', photo: current.path, baseline: baseline),
        epoch: 0,
      );
      await repo.storeDraft(draft(photo: current.path), epoch: 0);
      await repo.deleteEntry('2026-10-10');
      final service = PhotoService(documentsDirectoryProvider: () async => dir);
      await cleanupStartupPhotos(service, repo.getAllPhotoPaths);
      expect(await current.exists(), isTrue);
      expect(await baselinePhoto.exists(), isTrue);
      expect(await unused.exists(), isFalse);
      await repo.discardDraft('2026-10-10', revision: 1, epoch: 0);
      await service.deleteUnreferencedPhoto(
        current.path,
        readReferences: repo.getAllPhotoPaths,
      );
      expect(await current.exists(), isTrue);
      await db.customStatement(
        "INSERT INTO settings(key,value) VALUES ('draft_v1:2026-10-09','broken')",
      );
      final uncertain = await File(
        '${photos.path}/photo_4.jpg',
      ).writeAsString('uncertain');
      await expectLater(repo.getAllPhotoPaths(), throwsFormatException);
      await cleanupStartupPhotos(service, repo.getAllPhotoPaths);
      await service.deleteUnreferencedPhoto(
        uncertain.path,
        readReferences: repo.getAllPhotoPaths,
      );
      expect(await uncertain.exists(), isTrue);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
