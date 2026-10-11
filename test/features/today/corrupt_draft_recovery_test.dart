import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/app/bootstrap.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/models/journal_draft.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/settings/settings_controller.dart';

void main() {
  late AppDatabase db;
  late EntryRepository repo;
  late Directory dir;
  late File photo;
  late PhotoService service;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
    dir = await Directory.systemTemp.createTemp('three-lines-corrupt-');
    final photos = await Directory('${dir.path}/photos').create();
    photo = await File(
      '${photos.path}/photo_123.jpg',
    ).writeAsString('test photo');
    service = PhotoService(documentsDirectoryProvider: () async => dir);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  test('손상 회복 토큰은 외부 복구나 전체삭제 뒤 새 초안을 지우지 않는다', () async {
    await db.customStatement(
      "INSERT INTO settings(key,value) VALUES ('draft_v1:2026-10-11','broken')",
    );
    late CorruptDraft token;
    try {
      await repo.listDrafts();
      fail('손상 초안이 정상 초안으로 읽혔어요');
    } on CorruptDraft catch (error) {
      token = error;
    }
    final repaired = JournalDraft(
      date: '2026-10-11',
      revision: 1,
      prompts: ['a', 'b', 'c'],
      answers: ['복구', '', ''],
    );
    await db.customStatement('UPDATE settings SET value=? WHERE key=?', [
      repaired.encode(),
      'draft_v1:2026-10-11',
    ]);
    await expectLater(
      repo.discardCorruptDraft(token),
      throwsA(isA<StaleDraft>()),
    );
    expect((await repo.loadDraft('2026-10-11'))!.answers.first, '복구');
    await repo.deleteAllEntries();
    await repo.storeDraft(repaired, epoch: repo.journalEpoch);
    await expectLater(
      repo.discardCorruptDraft(token),
      throwsA(isA<StaleDraft>()),
    );
    expect((await repo.loadDraft('2026-10-11'))!.answers.first, '복구');
  });
  for (final key in ['emotion', 'photo', 'baseline', 'baseline.photo']) {
    test('nullable $key 누락이면 startup과 명시 정리는 실제 사진을 보존한다', () async {
      final draft = JournalDraft(
        date: '2026-10-11',
        revision: 1,
        prompts: ['a', 'b', 'c'],
        answers: ['입력', '', ''],
        baseline: DailyEntry(id: 1, date: '2026-10-11', emotion: 3),
      );
      final payload = jsonDecode(draft.encode()) as Map<String, dynamic>;
      if (key == 'baseline.photo') {
        (payload['baseline'] as Map).remove('photo');
      } else {
        payload.remove(key);
      }
      await db.customStatement('INSERT INTO settings(key,value) VALUES (?,?)', [
        'draft_v1:2026-10-11',
        jsonEncode(payload),
      ]);
      await expectLater(repo.getAllPhotoPaths(), throwsFormatException);
      await cleanupStartupPhotos(service, repo.getAllPhotoPaths);
      await service.deleteUnreferencedPhoto(
        photo.path,
        readReferences: repo.getAllPhotoPaths,
      );
      expect(await photo.exists(), isTrue);
    });
  }
  test('손상 초안이 있어도 명시 전체삭제는 DB를 지우고 알 수 없는 사진을 보존한다', () async {
    await repo.saveEntry(
      DailyEntry(
        date: '2026-10-11',
        emotion: 3,
        answer1: '기록',
        photoPath: photo.path,
      ),
    );
    await db.customStatement(
      "INSERT INTO settings(key,value) VALUES ('draft_v1:2026-10-10','broken')",
    );
    await db.customStatement(
      "INSERT INTO settings(key,value) VALUES ('theme_mode','dark')",
    );
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repo),
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
        photoServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsControllerProvider.future);
    expect(
      await container.read(settingsControllerProvider.notifier).deleteAllData(),
      isTrue,
    );
    expect(await repo.getTotalCount(), 0);
    expect(await repo.listDrafts(), isEmpty);
    expect(await photo.exists(), isTrue);
    expect(
      (await db
              .customSelect("SELECT value FROM settings WHERE key='theme_mode'")
              .getSingle())
          .read<String>('value'),
      'dark',
    );
  });
}
