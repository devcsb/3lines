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

  @override
  Future<void> setSetting(String key, String value) async {
    writes++;
    if (pending != null) await pending!.future;
    if (failing || writes == failAt)
      throw StateError('temporary write failure');
    await super.setSetting(key, value);
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
    await tester.runAsync(() async {
      container.listen(settingsControllerProvider, (_, _) {});
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
    await tester.runAsync(() async {
      repository.pending!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
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
    await tester.runAsync(() async {
      await tester.tap(find.text('저장'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      container.read(settingsControllerProvider).value!.prompts.first,
      '실패 후 유지할 질문',
    );
  });

  testWidgets('초기화 부분 실패는 완료로 숨기지 않고 dialog에서 재시도한다', (tester) async {
    await open(tester);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    repository.failAt = 2;
    await tester.tap(find.text('기본값으로 초기화'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('초기화'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('일부'), findsWidgets);
    expect(find.textContaining('다시'), findsWidgets);
    repository.failAt = null;
    await tester.runAsync(() async {
      await tester.tap(find.text('초기화'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      container.read(settingsControllerProvider).value!.prompts,
      defaultPromptQuestions,
    );
  });
}
