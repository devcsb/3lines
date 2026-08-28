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

  testWidgets('shows current and longest streak labels', (tester) async {
    await tester.pumpWidget(buildApp(currentStreak: 5, longestStreak: 10));
    expect(find.text('현재 연속'), findsOneWidget);
    expect(find.text('최장 기록'), findsOneWidget);
  });

  testWidgets('animates streak count from 0 to target', (tester) async {
    await tester.pumpWidget(buildApp(currentStreak: 10, longestStreak: 20));

    // Initially should show 0 (animation start) — two "0일" for current + longest
    expect(find.text('0일'), findsNWidgets(2));

    // After animation completes
    await tester.pumpAndSettle();
    expect(find.text('10일'), findsOneWidget);
    expect(find.text('20일'), findsOneWidget);
  });

  testWidgets('shows zero streaks correctly', (tester) async {
    await tester.pumpWidget(buildApp(currentStreak: 0, longestStreak: 0));
    await tester.pumpAndSettle();
    expect(find.text('0일'), findsNWidgets(2));
  });

  testWidgets('re-animates when streak values change', (tester) async {
    await tester.pumpWidget(buildApp(currentStreak: 5, longestStreak: 10));
    await tester.pumpAndSettle();
    expect(find.text('5일'), findsOneWidget);

    // Update with new values
    await tester.pumpWidget(buildApp(currentStreak: 15, longestStreak: 20));
    // Animation restarts from 0
    expect(find.text('0일'), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.text('15일'), findsOneWidget);
  });

  testWidgets('reduce-motion에서는 두 스트릭 값이 즉시 표시된다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: buildApp(currentStreak: 10, longestStreak: 20),
      ),
    );

    expect(find.text('10일'), findsOneWidget);
    expect(find.text('20일'), findsOneWidget);
  });
}
