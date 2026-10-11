import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/models/journal_draft.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/today/today_controller.dart';
import 'package:three_lines/features/today/today_screen.dart';
import 'package:three_lines/features/today/widgets/animated_save_button.dart';
import 'package:three_lines/features/today/widgets/completion_animation.dart';
import 'package:three_lines/features/today/widgets/prompt_card.dart';
import '../../helpers/fake_photo_service.dart';

class Clock extends AppClock {
  DateTime value = DateTime(2026, 10, 12, 9);
  @override
  DateTime now() => value;
}

class DelayedRepository extends EntryRepository {
  DelayedRepository(super.db, {required super.clock});
  final entered = Completer<void>();
  final release = Completer<void>();
  Completer<void>? queryEntered;
  Completer<void>? queryRelease;
  @override
  Future<DailyEntry?> getEntryByDate(String date) async {
    if (queryEntered != null && !queryEntered!.isCompleted) {
      queryEntered!.complete();
    }
    await queryRelease?.future;
    return super.getEntryByDate(date);
  }

  @override
  Future<void> saveEntry(
    DailyEntry entry, {
    bool preserveTimestamps = false,
  }) async {
    entered.complete();
    await release.future;
    await super.saveEntry(entry, preserveTimestamps: preserveTimestamps);
  }
}

void main() {
  late AppDatabase db;
  late DelayedRepository repo;
  late ProviderContainer container;
  late Clock clock;
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = Clock();
    repo = DelayedRepository(db, clock: clock);
    await repo.storeDraft(
      JournalDraft(
        date: '2026-10-11',
        revision: 1,
        emotion: 3,
        prompts: ['a', 'b', 'c'],
        answers: ['어제 입력', '', ''],
      ),
      epoch: 0,
    );
    container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(repo),
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
        photoServiceProvider.overrideWithValue(FakePhotoService()),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> show(WidgetTester tester) async {
    await tester.runAsync(() async {
      container.listen(todayControllerProvider, (_, _) {});
      await container.read(todayControllerProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TodayScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('복구 날짜와 오늘 작성 버튼, 보관 초안 왕복이 화면에 연결된다', (tester) async {
    await show(tester);
    expect(
      find.text(du.formatKoreanDate(DateTime(2026, 10, 11))),
      findsOneWidget,
    );
    expect(find.text('초안 보관됨'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('오늘 작성하기'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(
      container.read(todayControllerProvider).value!.draftDate,
      '2026-10-12',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('2026-10-11 보관 초안'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(container.read(todayControllerProvider).value!.answer1, '어제 입력');
  });
  testWidgets('managed reload 동안 이전 입력 대신 loading 화면을 표시한다', (tester) async {
    await show(tester);
    repo.queryEntered = Completer();
    repo.queryRelease = Completer();
    await tester.runAsync(() async {
      container.invalidate(todayControllerProvider);
      container.read(todayControllerProvider.notifier);
      await repo.queryEntered!.future;
    });
    await tester.pump();
    final loading = find
        .byType(CircularProgressIndicator)
        .evaluate()
        .isNotEmpty;
    final inputCount = find.byType(PromptCard).evaluate().length;
    var loaded = false;
    unawaited(
      container.read(todayControllerProvider.future).then((_) => loaded = true),
    );
    repo.queryRelease!.complete();
    for (var i = 0; i < 30 && !loaded; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(loaded, isTrue);
    expect(loading, isTrue);
    expect(inputCount, 0);
  });
  testWidgets('날짜 조회 중 화면 입력과 저장 및 날짜 버튼을 잠근다', (tester) async {
    await show(tester);
    repo.queryEntered = Completer();
    repo.queryRelease = Completer();
    late Future<void> switching;
    await tester.runAsync(() async {
      switching = container.read(todayControllerProvider.notifier).startToday();
    });
    for (var i = 0; i < 30 && !repo.queryEntered!.isCompleted; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(repo.queryEntered!.isCompleted, isTrue);
    await tester.pump();
    expect(
      tester
          .widget<AnimatedSaveButton>(find.byType(AnimatedSaveButton))
          .canSave,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '오늘 작성하기'))
          .onPressed,
      isNull,
    );
    for (final card in tester.widgetList<PromptCard>(find.byType(PromptCard))) {
      expect(card.readOnly, isTrue);
      expect(card.onChanged, isNull);
    }
    var finished = false;
    unawaited(switching.then((_) => finished = true));
    repo.queryRelease!.complete();
    for (var i = 0; i < 30 && !finished; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(finished, isTrue);
    await tester.pumpAndSettle();
    expect(
      container.read(todayControllerProvider).value!.draftDate,
      '2026-10-12',
    );
  });
  testWidgets('늦은 어제 저장의 완료 화면은 전환한 오늘에 나타나지 않는다', (tester) async {
    await show(tester);
    await tester.runAsync(() async {
      tester
          .widget<AnimatedSaveButton>(find.byType(AnimatedSaveButton))
          .onPressed!();
      await repo.entered.future;
    });
    await tester.runAsync(() async {
      final switching = container
          .read(todayControllerProvider.notifier)
          .resetAfterDelete();
      repo.release.complete();
      await switching;
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(
      container.read(todayControllerProvider).value!.draftDate,
      '2026-10-12',
    );
    expect(find.byType(CompletionAnimation), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('저장 중 날짜 버튼은 잠기고 완료 뒤 정상 전환한다', (tester) async {
    await show(tester);
    late Future<bool> saving;
    await tester.runAsync(() async {
      saving = container.read(todayControllerProvider.notifier).save();
      await repo.entered.future;
    });
    await tester.pump();
    final todayButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '오늘 작성하기'),
    );
    final draftButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '2026-10-11 보관 초안'),
    );
    final todayEnabled = todayButton.onPressed != null;
    final draftEnabled = draftButton.onPressed != null;
    await tester.runAsync(() async {
      repo.release.complete();
      expect(await saving, isTrue);
      await container.read(todayControllerProvider.notifier).startToday();
    });
    await tester.pumpAndSettle();
    expect(todayEnabled, isFalse);
    expect(draftEnabled, isFalse);
    expect(
      container.read(todayControllerProvider).value!.draftDate,
      '2026-10-12',
    );
  });
  testWidgets('충돌 입력은 복사하고 폐기 확인 뒤에만 최신 기록을 다시 연다', (tester) async {
    final writer = EntryRepository(db, clock: Clock());
    await tester.runAsync(() async {
      await writer.saveEntry(
        DailyEntry(date: '2026-10-12', emotion: 3, answer1: '원본'),
      );
      final baseline = await writer.getEntryByDate('2026-10-12');
      await repo.storeDraft(
        JournalDraft(
          date: '2026-10-12',
          revision: 1,
          emotion: 4,
          prompts: ['a', 'b', 'c'],
          answers: ['내 수정', '', ''],
          baseline: baseline,
        ),
        epoch: 0,
      );
      await writer.saveEntry(
        DailyEntry(date: '2026-10-12', emotion: 2, answer1: '외부 수정'),
      );
    });
    await show(tester);
    await tester.runAsync(() async {
      expect(
        await container.read(todayControllerProvider.notifier).save(),
        isFalse,
      );
    });
    await tester.pumpAndSettle();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('입력 내용 복사'));
    await tester.pump();
    expect(copied, contains('내 수정'));
    await tester.runAsync(() async {
      await tester.tap(find.text('저장된 기록 다시 열기'));
    });
    await tester.pumpAndSettle();
    expect(find.text('현재 초안을 폐기할까요?'), findsOneWidget);
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect((await repo.loadDraft('2026-10-12'))!.answers[0], '내 수정');
    });
    await tester.runAsync(() async {
      await tester.tap(find.text('저장된 기록 다시 열기'));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('폐기하고 다시 열기'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(container.read(todayControllerProvider).value!.answer1, '외부 수정');
    await tester.runAsync(() async {
      expect(await repo.loadDraft('2026-10-12'), isNull);
    });
  });
  testWidgets('손상 초안 오류 화면은 날짜를 알리고 확인 취소 후 명시 폐기만 한다', (tester) async {
    final writer = EntryRepository(db, clock: Clock());
    late Directory photoDirectory;
    late File preservedPhoto;
    await tester.runAsync(() async {
      photoDirectory = await Directory.systemTemp.createTemp(
        'draft-recovery-ui-',
      );
      preservedPhoto = await File(
        '${photoDirectory.path}/photo.jpg',
      ).writeAsString('fixture');
      await writer.saveEntry(
        DailyEntry(
          date: '2026-10-10',
          emotion: 3,
          answer1: '유효 완료',
          photoPath: preservedPhoto.path,
        ),
      );
      await db.customStatement(
        "INSERT INTO settings(key,value) VALUES ('draft_v1:2026-10-09','RAW_PRIVATE_MARKER')",
      );
      await db.customStatement(
        "INSERT INTO settings(key,value) VALUES ('draft_v1:2026-10-08','SECOND_PRIVATE_MARKER')",
      );
    });
    addTearDown(() => photoDirectory.delete(recursive: true));
    await tester.runAsync(() async {
      container.listen(todayControllerProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TodayScreen()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('2026-10-08'), findsOneWidget);
    expect(find.textContaining('RAW_PRIVATE_MARKER'), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.text('읽지 못한 초안 폐기'));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect(
        (await db
                .customSelect(
                  "SELECT COUNT(*) AS count FROM settings WHERE key IN ('draft_v1:2026-10-08','draft_v1:2026-10-09')",
                )
                .getSingle())
            .read<int>('count'),
        2,
      );
      expect(
        (await db
                .customSelect(
                  "SELECT value FROM settings WHERE key='draft_v1:2026-10-09'",
                )
                .getSingle())
            .read<String>('value'),
        'RAW_PRIVATE_MARKER',
      );
      expect(await preservedPhoto.exists(), isTrue);
    });
    await tester.runAsync(() async {
      await tester.tap(find.text('읽지 못한 초안 폐기'));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('이 초안만 폐기'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump(const Duration(milliseconds: 300));
    // One confirmed discard must reveal the remaining error, not stay loading.
    expect(find.textContaining('2026-10-09'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.textContaining('SECOND_PRIVATE_MARKER'), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.text('읽지 못한 초안 폐기'));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('이 초안만 폐기'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect((await writer.getEntryByDate('2026-10-10'))!.answer1, '유효 완료');
      expect((await repo.loadDraft('2026-10-11'))!.answers[0], '어제 입력');
      expect(await preservedPhoto.exists(), isTrue);
    });
    expect(container.read(todayControllerProvider).value!.answer1, '어제 입력');
    await tester.runAsync(() async {
      container.read(todayControllerProvider.notifier).setAnswer(0, '다시 입력');
      expect((await repo.loadDraft('2026-10-11'))!.answers[0], '다시 입력');
    });
  });
}
