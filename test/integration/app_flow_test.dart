import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/app.dart';
import 'package:three_lines/core/services/biometric_service.dart';
import 'package:three_lines/core/services/journal_side_effects.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/services/widget_sync_service.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/timeline/widgets/entry_detail_sheet.dart';

import '../helpers/fake_biometric_service.dart';
import '../helpers/fake_photo_service.dart';
import '../helpers/fake_widget_sync.dart';

final class NoOpJournalSideEffects implements JournalSideEffects {
  @override
  Future<void> onLaunch() async {}

  @override
  Future<void> onJournalChanged() async {}
}

final class _FailOnceRepository extends EntryRepository {
  _FailOnceRepository(super.db);
  bool failNextSave = true;

  @override
  Future<void> saveEntry(
    DailyEntry entry, {
    bool preserveTimestamps = false,
  }) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('simulated storage failure');
    }
    await super.saveEntry(entry, preserveTimestamps: preserveTimestamps);
  }
}

/// 풀스택 플로우 테스트: 실제 ThreeLinesApp 위젯 트리를 인메모리 DB + fake로
/// 구동해 UI→controller→repository→DB 경로를 호스트(flutter test)에서 검증한다.
/// 반복 애니메이션(streak pulse 등)이 있어 pumpAndSettle 대신 bounded pump 사용.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SettingsRepository(db).setSetting('onboarding_done', 'true');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    EntryRepository? entryRepository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          if (entryRepository != null)
            entryRepositoryProvider.overrideWithValue(entryRepository),
          journalSideEffectsProvider.overrideWithValue(
            NoOpJournalSideEffects(),
          ),
          widgetSyncServiceProvider.overrideWithValue(FakeWidgetSync()),
          photoServiceProvider.overrideWithValue(FakePhotoService()),
          biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        ],
        child: const ThreeLinesApp(),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // ThreeLinesApp을 제거해 provider(특히 TodayController의 자정 Timer)를
  // dispose하고, 남은 fake 타이머를 모두 소진해 pending-timer 불변식을 만족시킨다.
  Future<void> teardownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('핵심 루프: 감정 선택→답변 작성→저장→전체 스택 영속', (tester) async {
    await pumpApp(tester);

    expect(find.text('오늘의 감정'), findsOneWidget);

    await tester.tap(find.text('평온'));
    await tester.pump(const Duration(milliseconds: 300));

    final fields = find.byType(TextField);
    expect(fields, findsWidgets);
    final examples = find.text('시작이 어렵다면 예시 보기').first;
    await tester.ensureVisible(examples);
    await tester.tap(examples);
    await tester.pumpAndSettle();
    await tester.enterText(fields.first, '오늘 감사한 일');
    await tester.pump(const Duration(milliseconds: 200));

    final saveBtn = find.widgetWithText(ElevatedButton, '이만큼 저장하기');
    expect(saveBtn, findsOneWidget);
    await tester.ensureVisible(saveBtn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(saveBtn);
    // 저장 완료 직후 전면 애니메이션 없이 수정할 수 있다.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('기록을 저장했어요'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '수정하기'), findsOneWidget);

    final saved = await EntryRepository(db).getTodayEntry();
    expect(saved, isNotNull);
    expect(saved!.emotion, 4);
    expect(saved.answer1, '오늘 감사한 일');

    await teardownApp(tester);
  });

  testWidgets('긴 이야기를 저장하고 수정 취소와 백업에서도 문단과 끝부분을 보존한다', (tester) async {
    final story =
        '${List.filled(40, '어디에도 하지 못한 이야기를 적어 본다.').join(' ')}\n\n마지막까지 남겨둔 내 이야기.';
    await pumpApp(tester);
    await tester.tap(find.text('힘듦'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, story);
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '이만큼 저장하기'));
    await tester.pumpAndSettle();
    final repo = EntryRepository(db);
    expect((await repo.getTodayEntry())!.answer1, story);
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      story,
    );
    await tester.enterText(find.byType(TextField).first, '잠깐 바꾼 문장');
    await tester.pump();
    await tester.tap(find.text('수정 취소'));
    await tester.pumpAndSettle();
    expect((await repo.getTodayEntry())!.answer1, story);
    final backup = await repo.exportAllEntries();
    final prompts = backup.single['prompts'] as List<Map<String, dynamic>>;
    expect(prompts.first['answer'], story);
    await teardownApp(tester);
  });

  testWidgets('글 없이 마음을 남긴 뒤 같은 기록에 글을 더할 수 있다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('힘듦'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '마음만 남기기'));
    await tester.pump(const Duration(milliseconds: 500));
    final repo = EntryRepository(db);
    final saved = await repo.getTodayEntry();
    expect(saved!.emotion, 1);
    expect(saved.answer1, isEmpty);
    expect(saved.answer2, isEmpty);
    expect(saved.answer3, isEmpty);
    expect(find.text('비워둔 질문이에요'), findsNothing);
    expect(find.text('마음만 남긴 기록이에요. 원하면 글을 더할 수 있어요.'), findsOneWidget);
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '조금 쉬고 나서 썼다');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '이만큼 저장하기'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(await repo.getTotalCount(), 1);
    expect((await repo.getTodayEntry())!.answer1, '조금 쉬고 나서 썼다');
    await teardownApp(tester);
  });

  testWidgets('오래된 책갈피를 열고 해제해도 오늘 작성 중인 내용은 유지된다', (tester) async {
    final repo = EntryRepository(db);
    await repo.saveEntry(
      DailyEntry(date: '2020-01-01', emotion: 2, answer1: '다시 읽고 싶은 말'),
    );
    await repo.setBookmarked('2020-01-01', true);
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, '지금 쓰는 초안');
    await tester.pump();
    await tester.tap(find.text('타임라인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('책갈피 모아보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 읽고 싶은 말'));
    await tester.pumpAndSettle();
    expect(find.text('스와이프로 탐색'), findsNothing);
    await tester.tap(find.text('책갈피 해제'));
    await tester.pumpAndSettle();
    expect((await repo.getEntryByDate('2020-01-01'))!.isBookmarked, isFalse);
    Navigator.of(tester.element(find.byType(EntryDetailSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.text('다시 읽고 싶은 기록이 생기면'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘'));
    await tester.pumpAndSettle();
    expect(find.text('지금 쓰는 초안'), findsOneWidget);
    expect(await repo.getTodayEntry(), isNull);
    await teardownApp(tester);
  });

  testWidgets('감정만 기록한 날도 오늘 화면에서 책갈피에 담고 모아볼 수 있다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('불안'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '마음만 남기기'));
    await tester.pumpAndSettle();
    final bookmark = find.text('책갈피에 담기');
    await tester.ensureVisible(bookmark);
    await tester.tap(bookmark);
    await tester.pumpAndSettle();
    expect((await EntryRepository(db).getTodayEntry())!.isBookmarked, isTrue);
    await tester.tap(find.text('타임라인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('책갈피 모아보기'));
    await tester.pumpAndSettle();
    expect(find.text('마음만 남긴 기록'), findsOneWidget);
    await tester.tap(find.text('마음만 남긴 기록'));
    await tester.pumpAndSettle();
    expect(find.text('마음만 남긴 기록이에요.'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    await teardownApp(tester);
  });

  testWidgets('마지막 질문을 저장한 뒤에도 고정 영역에서 성공을 확인한다', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    await tester.tap(find.text('힘듦'));
    await tester.pumpAndSettle();
    final lastField = find.byType(TextField).last;
    await tester.ensureVisible(lastField);
    await tester.enterText(lastField, '지금은 쉬고 싶다');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '이만큼 저장하기'));
    await tester.pump(const Duration(milliseconds: 500));
    final saved = await EntryRepository(db).getTodayEntry();
    expect(saved!.answer3, '지금은 쉬고 싶다');
    final status = find.text('기록을 저장했어요');
    expect(status.hitTestable(), findsOneWidget);
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(find.text('지금은 쉬고 싶다'), findsOneWidget);
    await teardownApp(tester);
  });

  testWidgets('저장 실패 후 답변과 감정을 유지하고 재시도할 수 있다', (tester) async {
    await pumpApp(tester, entryRepository: _FailOnceRepository(db));
    await tester.tap(find.text('불안'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '남겨두고 싶은 말');
    await tester.pump();
    final save = find.widgetWithText(ElevatedButton, '이만큼 저장하기');
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 500));
    expect(await EntryRepository(db).getTodayEntry(), isNull);
    expect(find.text('남겨두고 싶은 말'), findsOneWidget);
    expect(find.textContaining('아직 저장하지 못했어요'), findsOneWidget);
    expect(find.text('기록을 저장했어요'), findsNothing);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 500));
    final saved = await EntryRepository(db).getTodayEntry();
    expect(saved!.answer1, '남겨두고 싶은 말');
    expect(saved.emotion, 2);
    expect(find.text('기록을 저장했어요'), findsOneWidget);
    expect(find.textContaining('아직 저장하지 못했어요'), findsNothing);
    await teardownApp(tester);
  });

  testWidgets('사용자 지정 질문에는 관계없는 예시를 붙이지 않는다', (tester) async {
    await SettingsRepository(db).setSetting('prompt_1', '오늘 읽은 책은?');
    await pumpApp(tester);
    expect(find.text('오늘 읽은 책은?'), findsOneWidget);
    expect(find.text('시작이 어렵다면 예시 보기'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, '사용자 지정 답변');
    await tester.tap(find.text('평온'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '이만큼 저장하기'));
    await tester.pump(const Duration(milliseconds: 500));
    final saved = await EntryRepository(db).getTodayEntry();
    expect(saved!.prompt1, '오늘 읽은 책은?');
    expect(saved.answer1, '사용자 지정 답변');
    await teardownApp(tester);
  });

  testWidgets('작은 화면 큰 글자와 키보드에서도 저장 버튼에 접근할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('힘듦'));
    await tester.tap(find.text('힘듦'));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pump();
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '한 단어');
    await tester.pump();
    expect(tester.takeException(), isNull);
    final save = find.widgetWithText(ElevatedButton, '이만큼 저장하기');
    expect(save.hitTestable(), findsOneWidget);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 500));
    expect((await EntryRepository(db).getTodayEntry())!.answer1, '한 단어');
    await teardownApp(tester);
  });
}
