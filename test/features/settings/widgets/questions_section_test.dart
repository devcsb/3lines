import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/constants/default_prompts.dart';
import 'package:three_lines/core/settings/settings_keys.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/settings/settings_controller.dart';
import 'package:three_lines/features/settings/widgets/questions_section.dart';

class _ControlledSettings extends SettingsRepository {
  _ControlledSettings(super.db);
  Completer<void>? pending;
  bool failing = false;
  int? failAt;
  int writes = 0;
  final completedWrites = <Completer<void>>[];

  @override
  Future<void> setSetting(String key, String value) async {
    writes++;
    final completed = Completer<void>();
    completedWrites.add(completed);
    try {
      if (pending != null) await pending!.future;
      if (failing || writes == failAt) {
        throw StateError('temporary write failure');
      }
      await super.setSetting(key, value);
    } finally {
      completed.complete();
    }
  }
}

void main() {
  late AppDatabase db;
  late _ControlledSettings repository;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = _ControlledSettings(db);
    container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
    late VoidCallback closeSubscription;
    await tester.runAsync(() async {
      final subscription = container.listen(
        settingsControllerProvider,
        (_, _) {},
      );
      closeSubscription = subscription.close;
      await container.read(settingsControllerProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuestionsSection(prompts: defaultPromptQuestions),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('질문 1'));
    await tester.pumpAndSettle();
    closeSubscription();
    await tester.pump();
    await tester.pump();
  }

  Future<void> waitForWrites(WidgetTester tester, int count) async {
    await tester.runAsync(() async {
      // 각 실제 DB write와 후속 controller continuation을 관찰한다.
      for (var index = 0; index < count; index++) {
        for (var turn = 0; repository.completedWrites.length <= index; turn++) {
          if (turn == 20) throw StateError('write $index did not start');
          await repository.getPrompts().timeout(const Duration(seconds: 3));
        }
        await repository.completedWrites[index].future.timeout(
          const Duration(seconds: 3),
        );
      }
      await repository.getPrompts().timeout(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  }

  testWidgets('공백 저장은 dialog와 입력을 유지하고 기존 질문을 바꾸지 않는다', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.errorText,
      isNotNull,
    );
    expect(repository.writes, 0);
    expect(
      container.read(settingsControllerProvider).value!.prompts.first,
      defaultPromptQuestions.first,
    );
  });

  testWidgets('느린 저장은 완료 전 dialog를 유지하고 중복 제출을 막는다', (tester) async {
    await open(tester);
    repository.pending = Completer<void>();
    await tester.enterText(find.byType(TextFormField), '새 질문');
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(repository.writes, 1);
    await tester.pump();
    repository.pending!.complete();
    await waitForWrites(tester, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      expect(
        await repository.getSetting(SettingKeys.prompt1, defaultValue: ''),
        '새 질문',
      );
    });
  });

  testWidgets('저장 실패는 입력과 오류를 남기고 같은 입력으로 재시도한다', (tester) async {
    await open(tester);
    repository.failing = true;
    await tester.enterText(find.byType(TextFormField), '실패 후 유지할 질문');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '실패 후 유지할 질문',
    );
    expect(find.textContaining('다시'), findsWidgets);
    repository.failing = false;
    await tester.tap(find.text('저장'));
    await waitForWrites(tester, 2);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.runAsync(() async {
      expect((await repository.getPrompts()).first, '실패 후 유지할 질문');
    });
  });

  testWidgets('초기화 실패는 질문을 유지하고 dialog에서 재시도한다', (tester) async {
    await open(tester);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    repository.failAt = 2;
    await tester.tap(find.text('기본값으로 초기화'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('초기화')));
    await waitForWrites(tester, 2);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('그대로 유지'), findsWidgets);
    expect(find.textContaining('다시'), findsWidgets);
    repository.failAt = null;
    await tester.runAsync(() => tester.tap(find.text('초기화')));
    await waitForWrites(tester, 5);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.runAsync(() async {
      expect(await repository.getPrompts(), defaultPromptQuestions);
    });
  });

  testWidgets('dialog 밖 listener가 없어도 느린 저장 중 provider 수명을 유지한다', (
    tester,
  ) async {
    await open(tester);
    repository.pending = Completer<void>();
    await tester.enterText(find.byType(TextFormField), '수명이 유지되는 새 질문');
    await tester.tap(find.text('저장'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    repository.pending!.complete();
    await waitForWrites(tester, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      expect((await repository.getPrompts()).first, '수명이 유지되는 새 질문');
    });
  });

  testWidgets('사용자 지정 세 질문 초기화 두 번째 실패 후 취소해도 DB와 화면을 유지한다', (tester) async {
    const custom = ['내가 정한 첫 질문', '내가 정한 두 번째 질문', '내가 정한 세 번째 질문'];
    late VoidCallback closeSubscription;
    await tester.runAsync(() async {
      for (var index = 0; index < 3; index++) {
        await repository.setSetting(
          SettingKeys.promptKeys[index],
          custom[index],
        );
      }
      final subscription = container.listen(
        settingsControllerProvider,
        (_, _) {},
      );
      closeSubscription = subscription.close;
      await container.read(settingsControllerProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) {
                final settings = ref.watch(settingsControllerProvider);
                return settings.when(
                  data: (state) => SingleChildScrollView(
                    child: QuestionsSection(prompts: state.prompts),
                  ),
                  loading: () => const SizedBox(),
                  error: (error, stack) => Text('$error'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    closeSubscription();
    await tester.runAsync(
      () => db.customStatement(
        "CREATE TRIGGER block_prompt_reset BEFORE UPDATE ON settings WHEN NEW.key = 'prompt_2' BEGIN SELECT RAISE(ABORT, 'blocked second prompt'); END",
      ),
    );
    await tester.tap(find.text('기본값으로 초기화'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('초기화')));
    await waitForWrites(tester, 5);
    expect(find.textContaining('다시'), findsWidgets);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    for (final question in custom) {
      expect(find.text(question), findsOneWidget);
    }
    await tester.runAsync(() async {
      expect(await repository.getPrompts(), custom);
      await db.customStatement('DROP TRIGGER block_prompt_reset');
    });
    await tester.tap(find.text('기본값으로 초기화'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('초기화')));
    await waitForWrites(tester, 8);
    expect(find.byType(AlertDialog), findsNothing);
    for (final question in defaultPromptQuestions) {
      expect(find.text(question), findsOneWidget);
    }
    await tester.runAsync(() async {
      expect(await repository.getPrompts(), defaultPromptQuestions);
    });
  });
}
