import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/completion_animation.dart';

void main() {
  Widget buildApp({VoidCallback? onComplete, int streak = 0}) {
    return MaterialApp(
      home: Scaffold(
        body: CompletionAnimation(
          onComplete: onComplete,
          streak: streak,
        ),
      ),
    );
  }

  // Helper to drain all pending timers so tests don't leave them behind
  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('renders CustomPaint for checkmark and particles',
      (tester) async {
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
    await tester.pumpWidget(
        buildApp(onComplete: () => completed = true));

    // Full sequence: checkmark 800ms, text delay 400ms, hold 1800ms
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });
}
