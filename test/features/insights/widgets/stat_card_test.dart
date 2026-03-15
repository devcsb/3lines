import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/insights/widgets/stat_card.dart';

void main() {
  Widget buildApp({
    String title = '평균 감정',
    String value = '🙂 4.2',
    IconData icon = Icons.emoji_emotions,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StatCard(title: title, value: value, icon: icon),
      ),
    );
  }

  testWidgets('displays title and value', (tester) async {
    await tester.pumpWidget(buildApp(title: '현재 스트릭', value: '12일'));
    expect(find.text('현재 스트릭'), findsOneWidget);
    expect(find.text('12일'), findsOneWidget);
  });

  testWidgets('displays icon', (tester) async {
    await tester.pumpWidget(buildApp(icon: Icons.local_fire_department));
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
  });

  testWidgets('renders as a Card', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byType(Card), findsOneWidget);
  });
}
