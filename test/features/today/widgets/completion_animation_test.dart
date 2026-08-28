import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/completion_animation.dart';

void main() {
  Widget buildApp({VoidCallback? onComplete, int streak = 0, int emotion = 3}) {
    return MaterialApp(
      home: Scaffold(
        body: CompletionAnimation(
          onComplete: onComplete,
          streak: streak,
          emotion: emotion,
        ),
      ),
    );
  }

  // Helper to drain all pending timers so tests don't leave them behind
  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('renders CustomPaint for checkmark and particles', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CustomPaint), findsWidgets);
    await drainTimers(tester);
  });

  testWidgets('shows streak badge when streak > 0', (tester) async {
    await tester.pumpWidget(buildApp(streak: 5));
    // Pump past the text animation delay (400ms) + frames
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('5일 연속'), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('calls onComplete after animation sequence', (tester) async {
    bool completed = false;
    await tester.pumpWidget(buildApp(onComplete: () => completed = true));

    // Full sequence includes the text delay and automatic hold.
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('완료 화면은 즉시 접근 가능한 닫기 버튼과 route semantics를 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();
    var completed = false;
    await tester.pumpWidget(buildApp(onComplete: () => completed = true));
    await tester.pump();

    expect(find.bySemanticsLabel('기록 저장 완료'), findsOneWidget);
    expect(find.bySemanticsLabel('완료 화면 닫기'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    expect(completed, isTrue);
    semantics.dispose();
    await drainTimers(tester);
  });

  testWidgets('완료 문구가 저널 원문이나 효능 보장을 노출하지 않는다', (tester) async {
    await tester.pumpWidget(buildApp(emotion: 5));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('감사를 기록하는 사람이 행복해진대요'), findsNothing);
    expect(find.textContaining('행복해진대요'), findsNothing);
    expect(find.text('오늘의 감정을 차분히 남겼어요'), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('닫기와 자동 종료가 중복 callback을 만들지 않는다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(buildApp(onComplete: () => calls++));
    await tester.pump();
    await tester.tap(find.text('닫기'));
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 1);
  });
}
