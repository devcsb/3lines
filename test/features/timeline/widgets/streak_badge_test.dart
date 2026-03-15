import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/timeline/widgets/streak_badge.dart';

void main() {
  Widget buildApp({int currentStreak = 0, int longestStreak = 0}) {
    return MaterialApp(
      home: Scaffold(
        body: StreakBadge(
          currentStreak: currentStreak,
          longestStreak: longestStreak,
        ),
      ),
    );
  }

  testWidgets('shows current streak label', (tester) async {
    await tester.pumpWidget(buildApp(currentStreak: 5, longestStreak: 10));
    expect(find.text('현재 연속'), findsOneWidget);
  });

  testWidgets('animates streak count from 0 to target', (tester) async {
    await tester.pumpWidget(buildApp(currentStreak: 10, longestStreak: 20));

    // Initially should show 0 (animation start)
    expect(find.text('0일'), findsOneWidget);

    // After animation completes
    await tester.pumpAndSettle();
    expect(find.text('10일'), findsOneWidget);
    expect(find.textContaining('최장 20일'), findsOneWidget);
  });

  testWidgets('shows zero streaks correctly', (tester) async {
    await tester.pumpWidget(buildApp(currentStreak: 0, longestStreak: 0));
    await tester.pumpAndSettle();
    expect(find.text('0일'), findsOneWidget);
    expect(find.textContaining('최장 0일'), findsOneWidget);
  });

  testWidgets('re-animates when streak values change', (tester) async {
    await tester.pumpWidget(buildApp(currentStreak: 5, longestStreak: 10));
    await tester.pumpAndSettle();
    expect(find.text('5일'), findsOneWidget);

    // Update with new values
    await tester.pumpWidget(buildApp(currentStreak: 15, longestStreak: 20));
    // Animation restarts from 0
    expect(find.text('0일'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('15일'), findsOneWidget);
  });
}
