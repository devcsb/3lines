import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
import 'package:three_lines/features/timeline/widgets/heatmap_grid.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
    if (Platform.environment['TZ'] == 'America/Los_Angeles') {
      expect(DateTime(2026, 1, 15).timeZoneOffset, const Duration(hours: -8));
      expect(DateTime(2026, 7, 15).timeZoneOffset, const Duration(hours: -7));
    }
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

  testWidgets('주입한 끝 날짜 기준 84개 날짜만 탐색한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeatmapGrid(
            startDate: DateTime(2026, 7, 20),
            endDate: DateTime(2026, 10, 11),
            emotionMap: const {'2026-07-20': 4, '2026-10-11': 2},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cells = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.contains('기록 없음') == true ||
              widget.properties.label?.contains('감정 ') == true),
    );
    expect(cells, findsNWidgets(84));
    expect(find.byTooltip('10/12 기록 없음'), findsNothing);
    expect(find.byTooltip('7/19 기록 없음'), findsNothing);
  });

  // TZ=America/Los_Angeles로도 실행해 VM의 실제 DST 날짜 연산을 검증한다.
  // 기대 날짜는 DST가 없는 UTC 달력으로 생성해 production local 계산과 분리한다.
  final dstCases = [
    (
      name: '봄 DST',
      start: DateTime(2025, 12, 22),
      end: DateTime(2026, 3, 15),
      utcStart: DateTime.utc(2025, 12, 22),
      last: '2026-03-15',
    ),
    (
      name: '가을 DST',
      start: DateTime(2026, 8, 17),
      end: DateTime(2026, 11, 8),
      utcStart: DateTime.utc(2026, 8, 17),
      last: '2026-11-08',
    ),
  ];
  for (final fixture in dstCases) {
    testWidgets('${fixture.name} 앞뒤 84개 달력 날짜는 빠짐과 중복 없이 탐색한다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeatmapGrid(
              startDate: fixture.start,
              endDate: fixture.end,
              emotionMap: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((widget) => widget.properties.label)
          .whereType<String>()
          .where((label) => label.endsWith(', 기록 없음'));
      final dates = labels.map((label) {
        final match = RegExp(r'^(\d+)년 (\d+)월 (\d+)일').firstMatch(label)!;
        return '${match[1]}-${match[2]!.padLeft(2, '0')}-${match[3]!.padLeft(2, '0')}';
      }).toList();
      final expected = List.generate(
        84,
        (offset) => fixture.utcStart
            .add(Duration(days: offset))
            .toIso8601String()
            .substring(0, 10),
      );
      expect(expected.last, fixture.last);
      expect(dates.length, 84);
      expect(dates.toSet().length, 84);
      expect(dates, expected);
      expect(tester.takeException(), isNull);
    });
  }

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
