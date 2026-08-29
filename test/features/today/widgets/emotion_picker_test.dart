import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/emotion_picker.dart';

void main() {
  Widget buildApp({
    int? selectedEmotion,
    ValueChanged<int>? onSelected,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EmotionPicker(
          selectedEmotion: selectedEmotion,
          onSelected: onSelected ?? (_) {},
          enabled: enabled,
        ),
      ),
    );
  }

  testWidgets('renders 5 emotion options', (tester) async {
    await tester.pumpWidget(buildApp());
    // 5 label texts (no emojis)
    expect(find.text('힘듦'), findsOneWidget);
    expect(find.text('불안'), findsOneWidget);
    expect(find.text('보통'), findsOneWidget);
    expect(find.text('평온'), findsOneWidget);
    expect(find.text('감사'), findsOneWidget);
  });

  testWidgets('renders section header', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('오늘의 감정'), findsOneWidget);
  });

  testWidgets('calls onSelected when tapped', (tester) async {
    int? selected;
    await tester.pumpWidget(buildApp(onSelected: (v) => selected = v));

    await tester.tap(find.text('감사'));
    await tester.pumpAndSettle();

    expect(selected, 5);
  });

  testWidgets('does not call onSelected when disabled', (tester) async {
    int? selected;
    await tester.pumpWidget(
      buildApp(onSelected: (v) => selected = v, enabled: false),
    );

    await tester.tap(find.text('감사'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });

  testWidgets('shows selected state visually', (tester) async {
    await tester.pumpWidget(buildApp(selectedEmotion: 3));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r'감정 선택: 5단계 중 3')), findsOneWidget);
  });

  testWidgets('provides accessibility labels for all emotions', (tester) async {
    await tester.pumpWidget(buildApp());
    for (var i = 1; i <= 5; i++) {
      expect(find.bySemanticsLabel(RegExp('감정 선택: 5단계 중 $i')), findsOneWidget);
    }
  });

  testWidgets('reduce-motion에서는 선택 피드백이 즉시 끝난다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: buildApp(),
      ),
    );

    await tester.tap(find.text('감사'));
    await tester.pump();

    final scales = tester
        .widgetList<AnimatedScale>(find.byType(AnimatedScale))
        .toList();
    expect(scales, isNotEmpty);
    expect(scales.every((scale) => scale.duration == Duration.zero), isTrue);
  });
}
