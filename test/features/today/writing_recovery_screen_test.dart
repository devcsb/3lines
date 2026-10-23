import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/app/router.dart';
import 'package:three_lines/core/constants/default_prompts.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/journal_draft.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/today/today_controller.dart';
import 'package:three_lines/features/settings/settings_controller.dart';

import '../../helpers/fake_photo_service.dart';

import '../../helpers/ui_render_fonts.dart';

class _Clock extends AppClock {
  @override
  DateTime now() => DateTime(2026, 10, 11, 9);
}

void main() {
  late AppDatabase db;
  late EntryRepository repository;
  late ProviderContainer container;

  setUpAll(() async {
    await loadUiRenderFonts();
    await initializeDateFormatting('ko_KR');
  });
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = _Clock();
    repository = EntryRepository(db, clock: clock);
    container = ProviderContainer(
      overrides: [
        initialOnboardingDoneProvider.overrideWithValue(true),
        onboardingDoneProvider.overrideWith((ref) async => true),
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(repository),
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
        photoServiceProvider.overrideWithValue(FakePhotoService()),
      ],
    );
  });
  tearDown(() async {
    container.read(routerProvider).dispose();
    container.dispose();
    await db.close();
  });

  Future<void> show(
    WidgetTester tester, {
    String answer = '',
    String? question,
    double textScale = 1,
    bool accessibleNavigation = false,
    bool seedDraft = true,
  }) async {
    await tester.runAsync(() async {
      if (seedDraft) {
        await repository.storeDraft(
          JournalDraft(
            date: '2026-10-11',
            revision: 1,
            emotion: 3,
            prompts: [
              question ?? defaultPromptQuestions[0],
              defaultPromptQuestions[1],
              defaultPromptQuestions[2],
            ],
            answers: [answer, '', ''],
          ),
          epoch: 0,
        );
      }
      container.listen(todayControllerProvider, (_, _) {});
      await container.read(todayControllerProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(routerProvider),
          theme: uiRenderTheme(AppTheme.light()),
          locale: const Locale('ko', 'KR'),
          supportedLocales: const [Locale('ko', 'KR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              accessibleNavigation: accessibleNavigation,
              disableAnimations: accessibleNavigation,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('빈 Today를 연 뒤 오늘 장문을 가져오고 수정해도 220자를 보존한다', (tester) async {
    await show(tester, seedDraft: false);
    final controller = container.read(todayControllerProvider.notifier);
    final session = container.read(todayControllerProvider).value!.session;
    expect(controller.answerLimit(0), 200);
    final imported = List.filled(230, '가').join();
    final reduced = List.filled(220, '가').join();
    await tester.runAsync(() async {
      final subscription = container.listen(
        settingsControllerProvider,
        (_, _) {},
      );
      try {
        await container.read(settingsControllerProvider.future);
        final settings = container.read(settingsControllerProvider.notifier);
        final preview = await settings.previewImport(
          jsonEncode([
            DailyEntry(
              date: '2026-10-11',
              emotion: 3,
              prompt1: defaultPromptQuestions[0],
              prompt2: defaultPromptQuestions[1],
              prompt3: defaultPromptQuestions[2],
              answer1: imported,
            ).toJson(),
          ]),
        );
        final result = await settings.applyImport(preview);
        expect(result.changedCount, 1);
      } finally {
        subscription.close();
      }
    });
    await tester.pumpAndSettle();
    expect(container.read(todayControllerProvider).value!.session, session);
    expect(container.read(todayControllerProvider).value!.answer1, imported);
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField).first, reduced);
      await repository.listDrafts();
    });
    await tester.pump();
    expect(container.read(todayControllerProvider).value!.answer1, reduced);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      reduced,
    );
    expect(controller.answerLimit(0), 230);
    await tester.runAsync(() async {
      controller.setAnswer(0, List.filled(231, '가').join());
      await repository.listDrafts();
    });
    expect(container.read(todayControllerProvider).value!.answer1, reduced);
    expect(controller.answerLimit(0), 230);
    expect(
      (await tester.runAsync(repository.listDrafts))!.single.answers[0],
      reduced,
    );
  });

  Future<void> addExample(WidgetTester tester) async {
    final suggestion = find.text('맑은 날씨').first;
    await tester.ensureVisible(suggestion);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(suggestion);
      await repository.listDrafts();
    });
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  }

  Future<void> undo(WidgetTester tester) async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    final action = find.text('되돌리기').hitTestable();
    expect(action, findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(action);
      await repository.listDrafts();
    });
    await tester.pump();
  }

  testWidgets('빈 답변에 예시를 넣어도 되돌리기로 원래 빈값을 복구한다', (tester) async {
    await show(tester);
    await addExample(tester);
    expect(container.read(todayControllerProvider).value!.answer1, '맑은 날씨');
    expect(find.text('되돌리기'), findsOneWidget);
    await undo(tester);
    expect(container.read(todayControllerProvider).value!.answer1, '');
  });

  for (final size in [
    const Size(375, 812),
    const Size(320, 640),
    const Size(640, 320),
  ]) {
    testWidgets('접근성 탐색 ${size.width}x${size.height}에서 예시 알림을 닫고 글을 저장한다', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, textScale: 2, accessibleNavigation: true);
      await addExample(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('되돌리기'), findsOneWidget);
      final close = find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.widgetWithIcon(IconButton, Icons.close),
          )
          .hitTestable();
      expect(close, findsOneWidget);
      expect(tester.widget<IconButton>(close).tooltip, '닫기');
      expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(container.read(todayControllerProvider).value!.answer1, '맑은 날씨');
      await tester.runAsync(() async {
        final saved = Completer<void>();
        final subscription = container.listen(todayControllerProvider, (
          _,
          next,
        ) {
          if (next.value?.isCompleted == true && !saved.isCompleted) {
            saved.complete();
          }
        });
        try {
          await tester.tap(find.text('기록 완료').hitTestable());
          await saved.future.timeout(const Duration(seconds: 3));
        } finally {
          subscription.close();
        }
      });
      await tester.pumpAndSettle();
      final entry = await tester.runAsync(
        () => repository.getEntryByDate('2026-10-11'),
      );
      expect(entry?.answer1, '맑은 날씨');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('예시 뒤 직접 편집한 글은 늦은 되돌리기가 덮지 않는다', (tester) async {
    await show(tester, answer: '처음 글');
    await addExample(tester);
    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField).first, '직접 고친 글');
      await repository.listDrafts();
    });
    await tester.pump();
    await undo(tester);
    expect(container.read(todayControllerProvider).value!.answer1, '직접 고친 글');
  });

  testWidgets('199 grapheme 답변에 예시를 추가하면 그대로 유지하고 길이 안내를 보인다', (tester) async {
    final answer = List.filled(199, '👩‍👩‍👧‍👦').join();
    await show(tester, answer: answer);
    await addExample(tester);
    expect(container.read(todayControllerProvider).value!.answer1, answer);
    expect(find.textContaining('줄여'), findsWidgets);
  });

  testWidgets('자유 질문에는 관련 없는 예시를 보여주지 않는다', (tester) async {
    await show(tester, question: '오늘 먹고 싶은 저녁은?');
    expect(find.text('자유 질문'), findsOneWidget);
    expect(find.text('맑은 날씨'), findsNothing);
  });

  testWidgets('날짜를 전환한 뒤 이전 예시 되돌리기는 새 초안을 바꾸지 않는다', (tester) async {
    await show(tester, answer: '오늘 원래 글');
    await addExample(tester);
    await tester.runAsync(() async {
      await container
          .read(todayControllerProvider.notifier)
          .selectDate('2026-10-10');
      container.read(todayControllerProvider.notifier).setAnswer(0, '어제의 새 글');
      await repository.listDrafts();
    });
    await tester.pump();
    await undo(tester);
    expect(container.read(todayControllerProvider).value!.answer1, '어제의 새 글');
  });

  testWidgets('320px 200% 글씨와 키보드에서도 세 답변에 포커스하고 다음 입력으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await show(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.ensureVisible(fields.at(0));
    await tester.showKeyboard(fields.at(0));
    await tester.runAsync(() async {
      await tester.enterText(fields.at(0), '첫 입력');
      await repository.listDrafts();
    });
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(0)).focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(1)).focusNode!.hasFocus, isTrue);
    for (var index = 1; index < 3; index++) {
      await tester.ensureVisible(fields.at(index));
      await tester.showKeyboard(fields.at(index));
      await tester.runAsync(() async {
        await tester.enterText(
          fields.at(index),
          index == 1 ? '두 번째 입력' : '마지막 입력',
        );
        await repository.listDrafts();
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(fields.at(index)).focusNode!.hasFocus,
        isTrue,
      );
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText).at(index),
      );
      final caret = editable.renderEditable.getLocalRectForCaret(
        TextPosition(offset: editable.widget.controller.selection.extentOffset),
      );
      final caretCenter = editable.renderEditable.localToGlobal(caret.center);
      expect(caretCenter.dy, inInclusiveRange(0, 420));
      expect(tester.takeException(), isNull);
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    final current = container.read(todayControllerProvider).value!;
    expect(current.answer1, '첫 입력');
    expect(current.answer2, '두 번째 입력');
    expect(current.answer3, '마지막 입력');
  });
}
