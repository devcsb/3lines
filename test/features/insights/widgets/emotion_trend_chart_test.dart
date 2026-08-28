import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/insights/widgets/emotion_trend_chart.dart';

void main() {
  Widget buildChart(List<({DateTime date, int emotion})> data) {
    return MaterialApp(
      home: Scaffold(body: EmotionTrendChart(data: data)),
    );
  }

  testWidgets('shows empty message when data is empty', (tester) async {
    await tester.pumpWidget(buildChart([]));
    expect(find.text('데이터가 없어요'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('renders LineChart with data', (tester) async {
    final data = [
      (date: DateTime(2025, 1, 1), emotion: 3),
      (date: DateTime(2025, 1, 2), emotion: 4),
      (date: DateTime(2025, 1, 3), emotion: 5),
    ];
    await tester.pumpWidget(buildChart(data));
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('consecutive days produce single line segment', (tester) async {
    final data = [
      (date: DateTime(2025, 1, 1), emotion: 3),
      (date: DateTime(2025, 1, 2), emotion: 4),
      (date: DateTime(2025, 1, 3), emotion: 5),
    ];
    await tester.pumpWidget(buildChart(data));

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final barData = lineChart.data.lineBarsData;
    // All consecutive → single segment
    expect(barData.length, 1);
    expect(barData[0].spots.length, 3);
  });

  testWidgets('gap in dates creates separate line segments', (tester) async {
    final data = [
      (date: DateTime(2025, 1, 1), emotion: 3),
      (date: DateTime(2025, 1, 2), emotion: 4),
      // Gap: Jan 3 missing
      (date: DateTime(2025, 1, 4), emotion: 2),
      (date: DateTime(2025, 1, 5), emotion: 5),
    ];
    await tester.pumpWidget(buildChart(data));

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final barData = lineChart.data.lineBarsData;
    // Gap between Jan 2 and Jan 4 → two segments
    expect(barData.length, 2);
    expect(barData[0].spots.length, 2); // Jan 1-2
    expect(barData[1].spots.length, 2); // Jan 4-5
  });

  testWidgets('spots use date-offset x-coordinates', (tester) async {
    final data = [
      (date: DateTime(2025, 1, 1), emotion: 3),
      // Gap: Jan 2 missing
      (date: DateTime(2025, 1, 3), emotion: 5),
    ];
    await tester.pumpWidget(buildChart(data));

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final barData = lineChart.data.lineBarsData;
    expect(barData.length, 2);
    // First spot at day 0, second at day 2 (not sequential index 1)
    expect(barData[0].spots[0].x, 0.0);
    expect(barData[1].spots[0].x, 2.0);
  });

  testWidgets('multiple gaps create multiple segments', (tester) async {
    final data = [
      (date: DateTime(2025, 1, 1), emotion: 3),
      // gap
      (date: DateTime(2025, 1, 5), emotion: 4),
      // gap
      (date: DateTime(2025, 1, 10), emotion: 2),
    ];
    await tester.pumpWidget(buildChart(data));

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final barData = lineChart.data.lineBarsData;
    // Each point isolated by gaps → 3 segments of 1 spot each
    expect(barData.length, 3);
  });

  testWidgets('single data point renders summary instead of chart', (
    tester,
  ) async {
    final data = [(date: DateTime(2025, 1, 1), emotion: 4)];
    await tester.pumpWidget(buildChart(data));
    // Single data point shows a summary card, not a LineChart
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('4'), findsOneWidget);
    expect(find.textContaining('평온'), findsOneWidget);
  });

  testWidgets('reduce-motion에서는 차트가 한 프레임에 표시된다', (tester) async {
    final data = [
      (date: DateTime(2025, 1, 1), emotion: 3),
      (date: DateTime(2025, 1, 2), emotion: 4),
    ];
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: buildChart(data),
      ),
    );

    final fade = tester
        .widgetList<FadeTransition>(
          find.descendant(
            of: find.byType(EmotionTrendChart),
            matching: find.byType(FadeTransition),
          ),
        )
        .first;
    expect(fade.opacity.value, 1.0);
  });
}
