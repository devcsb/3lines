import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/prompt_card.dart';

void main() {
  Widget buildApp({
    int index = 0,
    String? question,
    String answer = '',
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PromptCard(
            index: index,
            question:
                question ??
                const [
                  '지금 꺼내놓고 싶은 이야기가 있나요?',
                  '지금 내 마음에 머물러 있는 것은?',
                  '지금 나에게 필요한 것이 있다면?',
                ][index.clamp(0, 2)],
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
    expect(find.text('꺼내놓기'), findsOneWidget);
  });

  testWidgets('shows category chip for acceptance (index 1)', (tester) async {
    await tester.pumpWidget(
      buildApp(index: 1, question: '지금 내 마음에 머물러 있는 것은?'),
    );
    expect(find.text('지금 마음'), findsOneWidget);
  });

  testWidgets('shows category chip for intention (index 2)', (tester) async {
    await tester.pumpWidget(buildApp(index: 2, question: '지금 나에게 필요한 것이 있다면?'));
    expect(find.text('나를 돌보기'), findsOneWidget);
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

  testWidgets('빈 답변을 빠뜨린 항목처럼 표시하지 않는다', (tester) async {
    await tester.pumpWidget(buildApp(readOnly: true, answer: ''));
    expect(find.text('비워둔 질문이에요'), findsOneWidget);
  });

  testWidgets('calls onChanged when text is entered', (tester) async {
    String? changed;
    await tester.pumpWidget(buildApp(onChanged: (v) => changed = v));

    await tester.enterText(find.byType(TextField), '감사합니다');
    expect(changed, '감사합니다');
  });

  testWidgets('200자가 넘는 여러 문단도 마지막 문장까지 입력할 수 있다', (tester) async {
    final story =
        '${List.filled(40, '오늘 하지 못한 말이 남아 있다.').join(' ')}\n\n여기까지 내 이야기를 남긴다.';
    String? changed;
    await tester.pumpWidget(buildApp(onChanged: (value) => changed = value));
    await tester.enterText(find.byType(TextField), story);
    expect(changed, story);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      story,
    );
  });

  testWidgets('문단을 나누는 키보드와 충분한 작성 공간을 제공한다', (tester) async {
    await tester.pumpWidget(buildApp());
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.minLines, 3);
    expect(textField.maxLines, 8);
    expect(textField.keyboardType, TextInputType.multiline);
    expect(textField.textInputAction, TextInputAction.newline);
  });

  testWidgets('reduce-motion에서는 답변 모드 전환이 즉시 끝난다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: buildApp(readOnly: true, answer: '기록'),
      ),
    );

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, Duration.zero);
  });
}
