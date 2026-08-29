import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
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
          startDate:
              startDate ?? DateTime.now().subtract(const Duration(days: 83)),
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

  testWidgets('recorded day has a 48dp semantic tap target', (tester) async {
    final semantics = tester.ensureSemantics();
    final today = DateTime.now();
    final dateStr = du.dateToString(today);

    await tester.pumpWidget(
      buildGrid(startDate: today, emotionMap: {dateStr: 4}, onCellTap: (_) {}),
    );

    final target = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label?.endsWith('감정 4점') == true,
    );
    expect(target, findsOneWidget);
    final rect = tester.getRect(target);
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));

    semantics.dispose();
  });

  testWidgets('reduce-motion에서는 셀 강조가 즉시 표시된다', (tester) async {
    final today = DateTime.now();
    final dateStr = du.dateToString(today);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: buildGrid(
          startDate: today,
          emotionMap: {dateStr: 4},
          onCellTap: (_) {},
        ),
      ),
    );

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.duration, Duration.zero);
  });
}
