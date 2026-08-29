import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
import 'package:three_lines/features/timeline/widgets/heatmap_grid.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  testWidgets('히트맵은 플랫폼 탭 타깃·라벨 가이드를 만족한다', (tester) async {
    final semantics = tester.ensureSemantics();
    final today = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeatmapGrid(
            startDate: today,
            emotionMap: {du.dateToString(today): 4},
            onCellTap: (_) {},
          ),
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('기록이 있는 히트맵 셀은 스크린 리더 탭 동작을 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();
    final today = DateTime.now();
    final label = '${du.formatKoreanDate(today)}, 감정 4점';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeatmapGrid(
            startDate: today,
            emotionMap: {du.dateToString(today): 4},
            onCellTap: (_) {},
          ),
        ),
      ),
    );

    final target = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == label &&
          widget.properties.onTap != null,
    );
    expect(target, findsOneWidget);

    semantics.dispose();
  });
}
