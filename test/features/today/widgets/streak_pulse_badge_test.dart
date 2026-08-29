import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/streak_pulse_badge.dart';

void main() {
  testWidgets('renders streak text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StreakPulseBadge(streak: 3, usedGraceDay: true)),
      ),
    );
    await tester.pump();
    expect(find.textContaining('3일'), findsOneWidget);
    // 유예일 아이콘
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
  });

  testWidgets('reduce-motion에서는 pulse가 시작되지 않아 tree가 settle된다', (
    tester,
  ) async {
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
    // reduced-motion에서는 강조 ticker가 시작되지 않아 pumpAndSettle이 완료된다.
    await tester.pumpAndSettle();
    expect(find.textContaining('5일'), findsOneWidget);
  });

  testWidgets('정상 모드에서도 진입 펄스는 한 번만 재생된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StreakPulseBadge(streak: 5, usedGraceDay: false)),
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
