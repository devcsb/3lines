import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/prompt_card.dart';
import 'package:three_lines/features/today/widgets/prompt_suggestions.dart';

void main() {
  Widget card({
    String answer = '',
    String question = '오늘 감사한 작은 것 하나는?',
    ValueChanged<String>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PromptCard(
            index: 0,
            question: question,
            answer: answer,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('가져온 230자 답변은 편집으로 줄여도 200자로 잘리지 않는다', (tester) async {
    final original = List.filled(230, '가').join();
    final reduced = List.filled(220, '가').join();
    String? changed;
    await tester.pumpWidget(
      card(answer: original, onChanged: (value) => changed = value),
    );
    await tester.enterText(find.byType(TextField), reduced);
    expect(changed, reduced);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      reduced,
    );
  });

  testWidgets('200자 답변의 ZWJ 이모지는 한 글자로 유지하고 추가 붙여넣기는 막는다', (tester) async {
    final allowed = '${List.filled(199, '가').join()}👩‍👩‍👧‍👦';
    String? changed;
    await tester.pumpWidget(card(onChanged: (value) => changed = value));
    await tester.enterText(find.byType(TextField), '$allowed나');
    expect(changed, allowed);
  });

  testWidgets('한글 조합 중 값은 유지하고 조합 완료 뒤 200자 경계를 적용한다', (tester) async {
    await tester.pumpWidget(card());
    await tester.showKeyboard(find.byType(TextField));
    final input = '${List.filled(199, '가').join()}나';
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: input,
        selection: TextSelection.collapsed(offset: input.length),
        composing: const TextRange(start: 199, end: 200),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      input,
    );
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '$input\uB2E4',
        selection: const TextSelection.collapsed(offset: 201),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      input,
    );
  });

  testWidgets('자유 질문은 감사 카테고리를 강제하지 않는다', (tester) async {
    await tester.pumpWidget(card(question: '오늘 먹고 싶은 저녁은?'));
    expect(find.text('자유 질문'), findsOneWidget);
    expect(find.text('감사'), findsNothing);
  });

  testWidgets('예시는 native 버튼이며 구체적인 답변 추가 이름과 48dp 영역을 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();
    String? added;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PromptSuggestions(
            promptIndex: 0,
            question: '오늘 감사한 작은 것 하나는?',
            onTap: (value) => added = value,
          ),
        ),
      ),
    );
    final button = find.widgetWithText(TextButton, '맑은 날씨');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel("답변에 '맑은 날씨' 추가"), findsOneWidget);
    await tester.tap(button);
    expect(added, '맑은 날씨');
    semantics.dispose();
  });
}
