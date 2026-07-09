import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/prompt_card.dart';

void main() {
  Widget buildApp({
    int index = 0,
    String question = '오늘 감사한 작은 것 하나는?',
    String answer = '',
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PromptCard(
            index: index,
            question: question,
            answer: answer,
            readOnly: readOnly,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('displays question text', (tester) async {
    await tester.pumpWidget(buildApp(question: '테스트 질문입니다'));
    expect(find.text('테스트 질문입니다'), findsOneWidget);
  });

  testWidgets('shows category chip for gratitude (index 0)', (tester) async {
    await tester.pumpWidget(buildApp(index: 0));
    expect(find.text('감사'), findsOneWidget);
  });

  testWidgets('shows category chip for acceptance (index 1)', (tester) async {
    await tester.pumpWidget(buildApp(index: 1));
    expect(find.text('수용'), findsOneWidget);
  });

  testWidgets('shows category chip for intention (index 2)', (tester) async {
    await tester.pumpWidget(buildApp(index: 2));
    expect(find.text('의도'), findsOneWidget);
  });

  testWidgets('shows TextField in edit mode', (tester) async {
    await tester.pumpWidget(buildApp(readOnly: false));
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('does not show TextField in read-only mode', (tester) async {
    await tester.pumpWidget(buildApp(readOnly: true, answer: '답변'));
    expect(find.byType(TextField), findsNothing);
    expect(find.text('답변'), findsOneWidget);
  });

  testWidgets('shows dash for empty answer in read-only mode', (tester) async {
    await tester.pumpWidget(buildApp(readOnly: true, answer: ''));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('calls onChanged when text is entered', (tester) async {
    String? changed;
    await tester.pumpWidget(buildApp(onChanged: (v) => changed = v));

    await tester.enterText(find.byType(TextField), '감사합니다');
    expect(changed, '감사합니다');
  });

  testWidgets('enforces 200 character max length', (tester) async {
    await tester.pumpWidget(buildApp());
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.maxLength, 200);
  });

  testWidgets('keeps two visible lines and expands to four lines', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.minLines, 2);
    expect(textField.maxLines, 4);
  });
}
