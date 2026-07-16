import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/animated_save_button.dart';

void main() {
  Widget buildApp({
    int filledCount = 0,
    bool canSave = false,
    bool isSaving = false,
    bool isCancelling = false,
    bool emotionSelected = false,
    String guidanceMessage = '오늘의 감정을 먼저 골라주세요',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AnimatedSaveButton(
          filledCount: filledCount,
          canSave: canSave,
          isSaving: isSaving,
          isCancelling: isCancelling,
          emotionSelected: emotionSelected,
          guidanceMessage: guidanceMessage,
        ),
      ),
    );
  }

  testWidgets('shows guidance and answer progress', (tester) async {
    await tester.pumpWidget(
      buildApp(
        filledCount: 2,
        canSave: true,
        emotionSelected: true,
        guidanceMessage: '저장할 준비가 됐어요',
      ),
    );

    expect(find.text('저장할 준비가 됐어요'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('disables save until requirements are met', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildApp());

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    final node = tester.getSemantics(find.bySemanticsLabel('감정 선택 필요'));
    expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
    semantics.dispose();
  });

  testWidgets('announces when a save is in progress', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      buildApp(canSave: true, emotionSelected: true, isSaving: true),
    );

    expect(find.bySemanticsLabel('오늘의 기록 저장 중'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('오늘의 기록 저장 중'));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    semantics.dispose();
  });

  testWidgets('announces when an edit cancellation is in progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(canSave: true, emotionSelected: true, isCancelling: true),
    );

    expect(find.bySemanticsLabel('수정 취소 중'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });
}
