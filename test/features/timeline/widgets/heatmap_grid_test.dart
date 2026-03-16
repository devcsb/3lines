import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/features/timeline/widgets/heatmap_grid.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  Widget buildGrid({
    Map<String, int> emotionMap = const {},
    DateTime? startDate,
    ValueChanged<String>? onCellTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HeatmapGrid(
          emotionMap: emotionMap,
          startDate: startDate ??
              DateTime.now().subtract(const Duration(days: 83)),
          onCellTap: onCellTap,
        ),
      ),
    );
  }

  testWidgets('renders without error with empty map', (tester) async {
    await tester.pumpWidget(buildGrid());
    expect(find.byType(HeatmapGrid), findsOneWidget);
  });

  testWidgets('renders with emotion data', (tester) async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await tester.pumpWidget(buildGrid(emotionMap: {dateStr: 4}));
    expect(find.byType(HeatmapGrid), findsOneWidget);
  });

  testWidgets('shows day labels', (tester) async {
    await tester.pumpWidget(buildGrid());
    expect(find.text('월'), findsOneWidget);
    expect(find.text('수'), findsOneWidget);
    expect(find.text('금'), findsOneWidget);
  });

  testWidgets('shows legend labels', (tester) async {
    await tester.pumpWidget(buildGrid());
    expect(find.text('적음 '), findsOneWidget);
    expect(find.text(' 많음'), findsOneWidget);
  });

  testWidgets('contains horizontal ScrollView', (tester) async {
    await tester.pumpWidget(buildGrid());
    final scrollViews = find.byType(SingleChildScrollView);
    expect(scrollViews, findsWidgets);
  });
}
