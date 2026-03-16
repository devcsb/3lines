import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/insights/widgets/day_of_week_chart.dart';

void main() {
  Widget buildChart(Map<int, double> data) {
    return MaterialApp(
      home: Scaffold(
        body: DayOfWeekChart(data: data),
      ),
    );
  }

  testWidgets('renders BarChart widget', (tester) async {
    await tester.pumpWidget(buildChart({}));
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('always renders 7 bar groups (one per day)', (tester) async {
    await tester.pumpWidget(buildChart({1: 3.0, 3: 4.5}));
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.length, 7);
  });

  testWidgets('missing days have zero-height bars', (tester) async {
    await tester.pumpWidget(buildChart({2: 4.0}));
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    // Day index 0 (Monday, weekday 1) not in data → toY should be 0
    expect(chart.data.barGroups[0].barRods[0].toY, 0.0);
    // Day index 1 (Tuesday, weekday 2) is in data → toY should be 4.0
    expect(chart.data.barGroups[1].barRods[0].toY, 4.0);
  });

  testWidgets('maxY is set to 5.5', (tester) async {
    await tester.pumpWidget(buildChart({1: 5.0}));
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.maxY, 5.5);
  });
}
