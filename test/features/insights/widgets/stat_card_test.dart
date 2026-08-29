import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/insights/widgets/stat_card.dart';

void main() {
  Widget buildApp({
    String title = '평균 감정',
    String value = '4.2',
    IconData icon = Icons.favorite_rounded,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StatCard(title: title, value: value, icon: icon),
      ),
    );
  }

  testWidgets('displays title and value', (tester) async {
    await tester.pumpWidget(buildApp(title: '현재 스트릭', value: '12일'));
    await tester.pumpAndSettle(); // wait for count-up animation
    expect(find.text('현재 스트릭'), findsOneWidget);
    expect(find.text('12일'), findsOneWidget);
  });

  testWidgets('displays icon', (tester) async {
    await tester.pumpWidget(
      buildApp(icon: Icons.local_fire_department_rounded),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
  });

  testWidgets('renders as a Container with border', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('reduce-motion에서는 숫자가 즉시 최종 값으로 표시된다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: buildApp(title: '현재 스트릭', value: '12일'),
      ),
    );

    expect(find.text('12일'), findsOneWidget);
  });
}
