import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/completion_animation.dart';

void main() {
  Widget buildApp({VoidCallback? onComplete}) {
    return MaterialApp(
      home: Scaffold(
        body: CompletionAnimation(onComplete: onComplete),
      ),
    );
  }

  testWidgets('renders CustomPaint for checkmark', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('calls onComplete after animation finishes', (tester) async {
    bool completed = false;
    await tester.pumpWidget(buildApp(onComplete: () => completed = true));

    // The controller runs 600ms with elasticOut, then Future.delayed(300ms)
    // pumpAndSettle will advance all animation frames
    await tester.pumpAndSettle();
    // Then pump the 300ms Future.delayed
    await tester.pump(const Duration(milliseconds: 350));

    expect(completed, isTrue);
  });
}
