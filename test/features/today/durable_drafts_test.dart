import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/models/journal_draft.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/today/today_controller.dart';
import 'package:three_lines/features/today/today_state.dart';
import 'package:three_lines/features/settings/settings_controller.dart';
import 'package:three_lines/features/timeline/timeline_controller.dart';
import '../../helpers/fake_photo_service.dart';

class MutableClock extends AppClock {
  DateTime value = DateTime(2026, 10, 11, 23, 59);
  @override
  DateTime now() => value;
}

class GateRepository extends EntryRepository {
  GateRepository(super.db, {required super.clock});
  Completer<void>? saveStarted;
  Completer<void>? saveRelease;
  Completer<void>? storeStarted;
  Completer<void>? storeRelease;
  Completer<void>? queryStarted;
  Completer<void>? queryRelease;
  Completer<void>? metadataStarted;
  Completer<void>? metadataRelease;
  bool failMetadata = false;
  @override
  Future<({int count, bool usedGraceDay})> getCurrentStreakWithGrace() async {
    if (metadataStarted != null && !metadataStarted!.isCompleted)
      metadataStarted!.complete();
    await metadataRelease?.future;
    if (failMetadata) throw StateError('test metadata failure');
    return super.getCurrentStreakWithGrace();
  }

  @override
  Future<DailyEntry?> getEntryByDate(String date) async {
    if (queryStarted != null && !queryStarted!.isCompleted)
      queryStarted!.complete();
    await queryRelease?.future;
    return super.getEntryByDate(date);
  }

  @override
  Future<void> saveEntry(
    DailyEntry entry, {
    bool preserveTimestamps = false,
  }) async {
    saveStarted?.complete();
    await saveRelease?.future;
    await super.saveEntry(entry, preserveTimestamps: preserveTimestamps);
  }

  @override
  Future<void> storeDraft(JournalDraft draft, {required int epoch}) async {
    storeStarted?.complete();
    await storeRelease?.future;
    await super.storeDraft(draft, epoch: epoch);
  }
}

void main() {
  late AppDatabase db;
  late MutableClock clock;
  late EntryRepository entries;
  late SettingsRepository settings;
  late ProviderContainer container;
  ProviderContainer open() {
    final opened = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(entries),
        settingsRepositoryProvider.overrideWithValue(settings),
        photoServiceProvider.overrideWithValue(FakePhotoService()),
      ],
    );
    opened.listen(todayControllerProvider, (_, _) {});
    return opened;
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = MutableClock();
    entries = EntryRepository(db, clock: clock);
    settings = SettingsRepository(db);
    container = open();
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('새 provider 수명에서 감정만 있는 초안을 복구한다', () async {
    await container.read(todayControllerProvider.future);
    container.read(todayControllerProvider.notifier).setEmotion(4);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    container.dispose();
    container = open();
    expect((await container.read(todayControllerProvider.future)).emotion, 4);
  });
  test('자정 refresh와 저장은 작성하던 어제 날짜를 보존한다', () async {
    await container.read(todayControllerProvider.future);
    final controller = container.read(todayControllerProvider.notifier);
    controller.setEmotion(3);
    controller.setAnswer(0, '어제 입력');
    clock.value = DateTime(2026, 10, 12, 0, 1);
    await controller.refresh();
    expect(container.read(todayControllerProvider).value!.answer1, '어제 입력');
    expect(await controller.save(), isTrue);
    expect((await entries.getEntryByDate('2026-10-11'))!.answer1, '어제 입력');
    expect(await entries.getEntryByDate('2026-10-12'), isNull);
  });

  test('오늘 기록이 있어도 어제 초안은 날짜와 id를 섞지 않고 왕복한다', () async {
    await container.read(todayControllerProvider.future);
    final c = container.read(todayControllerProvider.notifier);
    c.setEmotion(4);
    c.setAnswer(0, '어제 초안');
    clock.value = DateTime(2026, 10, 12);
    await entries.saveEntry(
      DailyEntry(date: '2026-10-12', emotion: 2, answer1: '오늘 완료'),
    );
    final today = await entries.getEntryByDate('2026-10-12');
    await c.startToday();
    expect(container.read(todayControllerProvider).value!.answer1, '오늘 완료');
    await c.selectDate('2026-10-11');
    expect(container.read(todayControllerProvider).value!.answer1, '어제 초안');
    expect(await c.save(), isTrue);
    expect((await entries.getEntryByDate('2026-10-11'))!.id, isNot(today!.id));
    expect((await entries.getEntryByDate('2026-10-12'))!.answer1, '오늘 완료');
  });
  test('질문 변경과 가져오기와 다른 날짜 삭제는 현재 질문과 초안을 유지한다', () async {
    final initial = await container.read(todayControllerProvider.future);
    final c = container.read(todayControllerProvider.notifier);
    c.setEmotion(4);
    c.setAnswer(0, '초안');
    await container.read(settingsControllerProvider.future);
    await container
        .read(settingsControllerProvider.notifier)
        .updatePrompt(0, '새 질문');
    final preview = await entries.previewImport(
      '[{"date":"2026-10-10","emotion":2,"prompts":[{"question":"a","answer":"import"},{"question":"b","answer":""},{"question":"c","answer":""}]}]',
    );
    await container
        .read(settingsControllerProvider.notifier)
        .applyImport(preview);
    await container.read(timelineControllerProvider.future);
    await container
        .read(timelineControllerProvider.notifier)
        .deleteEntry('2026-10-10');
    expect(container.read(todayControllerProvider).value!.answer1, '초안');
    expect(
      container.read(todayControllerProvider).value!.prompts,
      initial.prompts,
    );
    clock.value = DateTime(2026, 10, 12);
    await c.startToday();
    expect(container.read(todayControllerProvider).value!.prompts[0], '새 질문');
  });
  test('보관 SQL 실패는 입력을 유지하고 최신 revision 재시도로 DB ack를 표시한다', () async {
    await container.read(todayControllerProvider.future);
    await db.customStatement(
      "CREATE TRIGGER fail_store BEFORE INSERT ON settings BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    final c = container.read(todayControllerProvider.notifier);
    c.setEmotion(5);
    await entries.listDrafts();
    await Future<void>.delayed(Duration.zero);
    final failed = container.read(todayControllerProvider).value!;
    expect(failed.emotion, 5);
    expect(failed.storageStatus, DraftStorageStatus.failed);
    expect(await entries.listDrafts(), isEmpty);
    await db.customStatement('DROP TRIGGER fail_store');
    expect(await c.retryDraftStorage(), isTrue);
    expect(
      container.read(todayControllerProvider).value!.storageStatus,
      DraftStorageStatus.stored,
    );
    expect((await entries.loadDraft('2026-10-11'))!.emotion, 5);
  });
  test('원본 변경 충돌 뒤 재열기는 새 DB 내용을 읽고 입력 폐기를 좁힌다', () async {
    await entries.saveEntry(
      DailyEntry(date: '2026-10-11', emotion: 2, answer1: '원본'),
    );
    container.dispose();
    container = open();
    await container.read(todayControllerProvider.future);
    final c = container.read(todayControllerProvider.notifier);
    c.toggleEdit();
    c.setAnswer(0, '내 수정');
    await entries.saveEntry(
      DailyEntry(date: '2026-10-11', emotion: 4, answer1: '외부 수정'),
    );
    expect(await c.save(), isFalse);
    expect(container.read(todayControllerProvider).value!.answer1, '내 수정');
    expect(container.read(todayControllerProvider).value!.hasConflict, isTrue);
    expect(await c.reopenSavedEntry(), isTrue);
    expect(container.read(todayControllerProvider).value!.answer1, '외부 수정');
    expect(await entries.loadDraft('2026-10-11'), isNull);
  });
  test('초안만 있는 전체삭제와 이전 picker는 입력을 부활시키지 않는다', () async {
    await container.read(todayControllerProvider.future);
    final c = container.read(todayControllerProvider.notifier);
    c.setEmotion(3);
    final before = c.capturePhotoSession();
    await container.read(settingsControllerProvider.future);
    expect(
      await container.read(settingsControllerProvider.notifier).deleteAllData(),
      isTrue,
    );
    await c.attachPhoto('/late.jpg', started: before);
    expect(await entries.listDrafts(), isEmpty);
    expect(container.read(todayControllerProvider).value!.emotion, isNull);
    expect(container.read(todayControllerProvider).value!.photoPath, isNull);
  });
  test('사진만 있는 초안은 restart와 다른 날짜에서 다시 찾는다', () async {
    await container.read(todayControllerProvider.future);
    final c = container.read(todayControllerProvider.notifier);
    await c.attachPhoto('/photo.jpg');
    clock.value = DateTime(2026, 10, 12);
    await c.startToday();
    container.dispose();
    container = open();
    expect(
      (await container.read(todayControllerProvider.future)).photoPath,
      '/photo.jpg',
    );
  });
  test('지연된 저장 완료는 전환한 오늘 입력을 덮지 않는다', () async {
    container.dispose();
    final gate = GateRepository(db, clock: clock);
    entries = gate;
    container = open();
    await container.read(todayControllerProvider.future);
    final c = container.read(todayControllerProvider.notifier);
    c.setEmotion(4);
    c.setAnswer(0, '어제 저장');
    await entries.listDrafts();
    gate.saveStarted = Completer();
    gate.saveRelease = Completer();
    final saving = c.save();
    await gate.saveStarted!.future;
    clock.value = DateTime(2026, 10, 12);
    // Select is requested while the transaction is in flight; its DB read waits.
    final switching = c.startToday();
    gate.saveRelease!.complete();
    await switching;
    c.setAnswer(0, '오늘 입력');
    expect(await saving, isTrue);
    expect(
      container.read(todayControllerProvider).value!.draftDate,
      '2026-10-12',
    );
    expect(container.read(todayControllerProvider).value!.answer1, '오늘 입력');
    expect((await entries.getEntryByDate('2026-10-11'))!.answer1, '어제 저장');
  });
  test('enqueue 전 지연 auto-store도 전체삭제 epoch 뒤에는 부활하지 않는다', () async {
    container.dispose();
    final gate = GateRepository(db, clock: clock);
    entries = gate;
    container = open();
    await container.read(todayControllerProvider.future);
    gate.storeStarted = Completer();
    gate.storeRelease = Completer();
    final c = container.read(todayControllerProvider.notifier);
    c.setEmotion(4);
    await gate.storeStarted!.future;
    await container.read(settingsControllerProvider.future);
    expect(
      await container.read(settingsControllerProvider.notifier).deleteAllData(),
      isTrue,
    );
    gate.storeRelease!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(await entries.listDrafts(), isEmpty);
    expect(container.read(todayControllerProvider).value!.emotion, isNull);
    gate.storeStarted = null;
    gate.storeRelease = null;
    c.setEmotion(2);
    await entries.listDrafts();
    expect((await entries.loadDraft('2026-10-11'))!.emotion, 2);
  });
  test('전체삭제 SQL 실패는 live 입력과 영속 초안을 그대로 둔다', () async {
    await container.read(todayControllerProvider.future);
    final c = container.read(todayControllerProvider.notifier);
    await c.attachPhoto('/retained.jpg');
    c.setEmotion(4);
    await entries.listDrafts();
    await db.customStatement(
      "CREATE TRIGGER fail_delete BEFORE DELETE ON settings BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await container.read(settingsControllerProvider.future);
    expect(
      await container.read(settingsControllerProvider.notifier).deleteAllData(),
      isFalse,
    );
    expect(container.read(todayControllerProvider).value!.emotion, 4);
    expect(
      container.read(todayControllerProvider).value!.photoPath,
      '/retained.jpg',
    );
    expect((await entries.loadDraft('2026-10-11'))!.photoPath, '/retained.jpg');
    expect(entries.journalEpoch, 0);
  });
  test('지연된 사진 취소 응답은 전환한 오늘 입력을 되돌리지 않는다', () async {
    final photo = FakePhotoService();
    await entries.saveEntry(
      DailyEntry(
        date: '2026-10-11',
        emotion: 3,
        answer1: '원본',
        photoPath: '/saved.jpg',
      ),
    );
    container.dispose();
    container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(entries),
        settingsRepositoryProvider.overrideWithValue(settings),
        photoServiceProvider.overrideWithValue(photo),
      ],
    );
    container.listen(todayControllerProvider, (_, _) {});
    await container.read(todayControllerProvider.future);
    final c = container.read(todayControllerProvider.notifier);
    c.toggleEdit();
    c.setAnswer(0, '수정');
    await c.attachPhoto('/unsaved.jpg');
    photo.deleteStarted = Completer();
    photo.deleteGate = Completer();
    final cancelling = c.cancelEdit();
    await photo.deleteStarted!.future;
    clock.value = DateTime(2026, 10, 12);
    await c.startToday();
    c.setAnswer(0, '오늘 입력');
    photo.deleteGate!.complete();
    await cancelling;
    expect(
      container.read(todayControllerProvider).value!.draftDate,
      '2026-10-12',
    );
    expect(container.read(todayControllerProvider).value!.answer1, '오늘 입력');
    expect((await entries.getEntryByDate('2026-10-11'))!.answer1, '원본');
    expect(await entries.loadDraft('2026-10-11'), isNull);
  });
  test('날짜 전환 조회 실패는 입력과 날짜를 남기고 같은 버튼으로 재시도한다', () async {
    await container.read(todayControllerProvider.future);
    final c = container.read(todayControllerProvider.notifier);
    c.setAnswer(0, '보존할 입력');
    await entries.listDrafts();
    await db.customStatement(
      "INSERT INTO settings(key,value) VALUES ('draft_v1:2026-10-09','broken')",
    );
    clock.value = DateTime(2026, 10, 12);
    await c.startToday();
    expect(
      container.read(todayControllerProvider).value!.draftDate,
      '2026-10-11',
    );
    expect(container.read(todayControllerProvider).value!.answer1, '보존할 입력');
    expect(
      container.read(todayControllerProvider).value!.draftError,
      isNotNull,
    );
    await db.customStatement(
      "DELETE FROM settings WHERE key='draft_v1:2026-10-09'",
    );
    await c.startToday();
    expect(
      container.read(todayControllerProvider).value!.draftDate,
      '2026-10-12',
    );
    expect((await entries.loadDraft('2026-10-11'))!.answers[0], '보존할 입력');
  });
  test('날짜 조회 중 controller 입력을 잠그고 snapshot을 되돌리지 않는다', () async {
    container.dispose();
    final gate = GateRepository(db, clock: clock);
    entries = gate;
    container = open();
    await container.read(todayControllerProvider.future);
    final c = container.read(todayControllerProvider.notifier);
    c.setAnswer(0, '목록 snapshot');
    await entries.listDrafts();
    gate.queryStarted = Completer();
    gate.queryRelease = Completer();
    final switching = c.selectDate('2026-10-11');
    await gate.queryStarted!.future;
    c.setAnswer(0, '조회 중 변경');
    expect(
      container.read(todayControllerProvider).value!.answer1,
      '목록 snapshot',
    );
    expect(await c.retryDraftStorage(), isFalse);
    gate.queryRelease!.complete();
    await switching;
    expect(
      container.read(todayControllerProvider).value!.answer1,
      '목록 snapshot',
    );
  });
  test('취소 중 보관 재시도는 폐기한 초안을 restart에서 부활시키지 않는다', () async {
    final photo = FakePhotoService();
    await entries.saveEntry(
      DailyEntry(
        date: '2026-10-11',
        emotion: 3,
        answer1: '원본',
        photoPath: '/saved.jpg',
      ),
    );
    container.dispose();
    container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(entries),
        settingsRepositoryProvider.overrideWithValue(settings),
        photoServiceProvider.overrideWithValue(photo),
      ],
    );
    container.listen(todayControllerProvider, (_, _) {});
    await container.read(todayControllerProvider.future);
    await db.customStatement(
      "CREATE TRIGGER fail_store BEFORE INSERT ON settings BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    final c = container.read(todayControllerProvider.notifier);
    c.toggleEdit();
    await c.attachPhoto('/new.jpg');
    expect(
      container.read(todayControllerProvider).value!.storageStatus,
      DraftStorageStatus.failed,
    );
    await db.customStatement('DROP TRIGGER fail_store');
    photo.deleteStarted = Completer();
    photo.deleteGate = Completer();
    final cancelling = c.cancelEdit();
    await photo.deleteStarted!.future;
    expect(await c.retryDraftStorage(), isFalse);
    photo.deleteGate!.complete();
    await cancelling;
    expect(await entries.listDrafts(), isEmpty);
    container.dispose();
    container = open();
    expect(
      (await container.read(todayControllerProvider.future)).isEditing,
      isFalse,
    );
  });
  test('Today 미구독 전체삭제는 provider dispose에도 DB 성공과 후처리를 유지한다', () async {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(entries),
        settingsRepositoryProvider.overrideWithValue(settings),
        photoServiceProvider.overrideWithValue(FakePhotoService()),
      ],
    );
    await entries.saveEntry(
      DailyEntry(date: '2026-10-11', emotion: 3, answer1: '삭제할 기록'),
    );
    await container.read(settingsControllerProvider.future);
    final deleting = container
        .read(settingsControllerProvider.notifier)
        .deleteAllData();
    await container.pump();
    expect(await deleting, isTrue);
    expect(await entries.getTotalCount(), 0);
  });
  test('미구독 reset API는 느린 metadata 중 자기 수명을 유지한다', () async {
    container.dispose();
    final gate = GateRepository(db, clock: clock);
    entries = gate;
    container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(entries),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    gate.metadataStarted = Completer();
    gate.metadataRelease = Completer();
    final resetting = container
        .read(todayControllerProvider.notifier)
        .resetAfterDelete();
    await gate.metadataStarted!.future;
    await container.pump();
    gate.metadataRelease!.complete();
    await resetting;
  });
  test('container 자체가 종료돼도 진행 중 reset은 UI 쓰기 없이 종료한다', () async {
    container.dispose();
    final gate = GateRepository(db, clock: clock);
    container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(gate),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    gate.metadataStarted = Completer();
    gate.metadataRelease = Completer();
    final resetting = container
        .read(todayControllerProvider.notifier)
        .resetAfterDelete();
    await gate.metadataStarted!.future;
    container.dispose();
    gate.metadataRelease!.complete();
    await resetting;
    container = open();
  });
  test('DB 삭제 뒤 metadata 실패는 삭제 성공과 사진 후처리를 되돌리지 않는다', () async {
    container.dispose();
    final gate = GateRepository(db, clock: clock);
    entries = gate;
    final photos = FakePhotoService();
    container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(gate),
        settingsRepositoryProvider.overrideWithValue(settings),
        photoServiceProvider.overrideWithValue(photos),
      ],
    );
    await gate.saveEntry(
      DailyEntry(date: '2026-10-11', emotion: 3, photoPath: '/old/photo.jpg'),
    );
    await container.read(settingsControllerProvider.future);
    gate.failMetadata = true;
    expect(
      await container.read(settingsControllerProvider.notifier).deleteAllData(),
      isTrue,
    );
    expect(await gate.getTotalCount(), 0);
    expect(photos.deletedPaths, contains('/old/photo.jpg'));
  });
  test('날짜 왕복과 refresh는 현재 시계의 회고와 최근 감정을 갱신한다', () async {
    await entries.saveEntry(
      DailyEntry(date: '2025-10-11', emotion: 4, answer1: '일년 전'),
    );
    await entries.saveEntry(
      DailyEntry(date: '2026-04-11', emotion: 3, answer1: '반년 전'),
    );
    await entries.saveEntry(
      DailyEntry(date: '2026-09-11', emotion: 2, answer1: '한달 전'),
    );
    container.dispose();
    container = open();
    final initial = await container.read(todayControllerProvider.future);
    expect(initial.oneYearAgoEntry!.answer1, '일년 전');
    final c = container.read(todayControllerProvider.notifier);
    c.setAnswer(0, '내 입력');
    await c.selectDate('2026-10-10');
    await c.selectDate('2026-10-11');
    var live = container.read(todayControllerProvider).value!;
    expect(live.oneYearAgoEntry?.answer1, '일년 전');
    expect(live.sixMonthsAgoEntry?.answer1, '반년 전');
    expect(live.oneMonthAgoEntry?.answer1, '한달 전');
    await entries.saveEntry(
      DailyEntry(date: '2025-10-11', emotion: 5, answer1: '바뀐 일년 전'),
    );
    await entries.saveEntry(
      DailyEntry(date: '2026-10-10', emotion: 5, answer1: '어제'),
    );
    await c.refresh();
    live = container.read(todayControllerProvider).value!;
    expect(live.oneYearAgoEntry?.answer1, '바뀐 일년 전');
    expect(live.recentEmotions.map((e) => e.emotion), contains(5));
    expect(live.answer1, '내 입력');
    await entries.deleteEntry('2025-10-11');
    await c.refresh();
    expect(
      container.read(todayControllerProvider).value!.oneYearAgoEntry,
      isNull,
    );
    clock.value = DateTime(2026, 10, 12);
    await entries.saveEntry(
      DailyEntry(date: '2025-10-12', emotion: 3, answer1: '새 날짜 회고'),
    );
    await c.refresh();
    expect(
      container.read(todayControllerProvider).value!.oneYearAgoEntry?.answer1,
      '새 날짜 회고',
    );
    expect(
      container.read(todayControllerProvider).value!.draftDate,
      '2026-10-11',
    );
  });
}
