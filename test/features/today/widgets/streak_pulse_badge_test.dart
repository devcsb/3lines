import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/streak_pulse_badge.dart';

void main() {
  testWidgets('renders streak text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreakPulseBadge(streak: 3, usedGraceDay: true),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('3일'), findsOneWidget);
    // 유예일 아이콘
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
  });

  testWidgets('reduce-motion stops the infinite pulse so the tree settles',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Scaffold(
              body: StreakPulseBadge(streak: 5, usedGraceDay: false),
            ),
          ),
        ),
      ),
    );
    // 무한 repeat 애니메이션이 멈췄을 때만 pumpAndSettle 이 완료된다.
    await tester.pumpAndSettle();
    expect(find.textContaining('5일'), findsOneWidget);
  });
}
