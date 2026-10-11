import 'dart:async';
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
import '../../helpers/fake_photo_service.dart';

class Clock extends AppClock {
  @override
  DateTime now() => DateTime(2026, 10, 12, 9);
}

class DelayedRepository extends EntryRepository {
  DelayedRepository(super.db, {required super.clock});
  final entered = Completer<void>();
  final release = Completer<void>();
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
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = Clock();
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
          .startToday();
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
        if (call.method == 'Clipboard.setData')
          copied = (call.arguments as Map)['text'] as String;
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
}
