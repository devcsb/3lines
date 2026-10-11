import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/data/models/weekly_retrospective.dart';
import 'package:three_lines/features/insights/insights_controller.dart';
import 'package:three_lines/features/insights/insights_screen.dart';
import 'package:three_lines/features/insights/insights_state.dart';
import 'package:three_lines/features/insights/widgets/stat_card.dart';
import 'package:three_lines/features/insights/widgets/insights_locked_view.dart';
import 'package:three_lines/features/insights/widgets/emotion_trend_chart.dart';

import '../../helpers/ui_readability.dart';
import '../../helpers/ui_render_fonts.dart';

final class _UiInsights extends InsightsController {
  _UiInsights(this.initial);
  final InsightsState initial;
  @override
  Future<InsightsState> build() async => initial;
  @override
  Future<void> setPeriod(InsightsPeriod period) async {
    state = AsyncData(state.value!.copyWith(period: period));
  }
}

InsightsState _fixture({bool empty = false, double delta = .5}) =>
    InsightsState(
      isUnlocked: true,
      totalCount: 12,
      averageEmotion: empty ? null : 3.5,
      currentStreak: 1234,
      periodStart: DateTime(2026, 10, 5),
      periodEnd: DateTime(2026, 10, 11),
      thisWeekCount: empty ? 0 : 3,
      lastWeekCount: 3,
      weeklyDelta: empty ? null : delta,
      emotionTrend: empty
          ? []
          : [
              (date: DateTime(2026, 10, 10), emotion: 3),
              (date: DateTime(2026, 10, 11), emotion: 4),
            ],
      dayOfWeekEmotions: empty ? {} : {6: 3, 7: 4},
      keywords: empty ? {} : {'짧은기록': 10, '긴한글키워드도줄여버리지않고읽을수있어요': 1},
      gratitudeKeywords: empty ? {} : {'따뜻한식사': 2},
      monthlySummary: empty
          ? null
          : const MonthlySummary(
              monthLabel: '2026년 10월',
              averageEmotion: 3.5,
              entryCount: 12,
              topKeyword: '따뜻한식사',
            ),
      weeklyRetrospective: empty
          ? null
          : const WeeklyRetrospective(
              entryCount: 3,
              averageEmotion: 3.5,
              trendDescription: '기록한 날 기준 평균이에요',
              topKeyword: '식사',
              currentStreak: 1234,
              bestDay: (date: '2026-10-11', emotion: 4),
              worstDay: (date: '2026-10-10', emotion: 3),
            ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadUiRenderFonts();
    await initializeDateFormatting('ko_KR');
  });

  Future<void> mount(
    WidgetTester tester,
    InsightsState state,
    ThemeData theme, {
    Size size = const Size(320, 640),
    double scale = 1,
    GlobalKey? boundary,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsControllerProvider.overrideWith(() => _UiInsights(state)),
        ],
        child: MaterialApp(
          theme: uiRenderTheme(theme),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home: const InsightsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final accent in AppTheme.accentSeeds.keys) {
    for (final dark in [false, true]) {
      testWidgets('인사이트 $accent dark=$dark 정보 문구 합성 대비', (tester) async {
        final boundary = GlobalKey();
        await mount(
          tester,
          _fixture(delta: 0),
          dark
              ? AppTheme.darkForAccent(accent)
              : AppTheme.lightForAccent(accent),
          boundary: boundary,
        );
        expectReadableText(tester);
        expectReadableIcons(tester);
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        final bar = chart.data.lineBarsData.first;
        final spot = LineBarSpot(bar, 0, bar.spots.first);
        final tooltip = chart.data.lineTouchData.touchTooltipData;
        final item = tooltip.getTooltipItems([spot]).single!;
        final background = tooltip.getTooltipColor(spot);
        final foreground = Color.alphaBlend(item.textStyle.color!, background);
        final luminances = [
          foreground.computeLuminance(),
          background.computeLuminance(),
        ]..sort();
        expect(
          (luminances.last + .05) / (luminances.first + .05),
          greaterThanOrEqualTo(4.5),
        );
        await captureUi(
          tester,
          boundary,
          'insights-$accent-${dark ? 'dark' : 'light'}-100pct',
        );
      });
      testWidgets('인사이트 잠금 $accent dark=$dark 안내 대비', (tester) async {
        await mount(
          tester,
          _fixture().copyWith(isUnlocked: false, totalCount: 0),
          dark
              ? AppTheme.darkForAccent(accent)
              : AppTheme.lightForAccent(accent),
        );
        expectReadableText(tester);
        expectReadableIcons(tester);
      });
    }
  }

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('인사이트 잠금 $size 200% 작성 버튼 도달', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reachedToday = false;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: uiRenderTheme(AppTheme.light()),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home: Scaffold(
            body: InsightsLockedView(
              totalCount: 0,
              requiredCount: 7,
              onGoToToday: () => reachedToday = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.byType(FilledButton);
      await tester.ensureVisible(button);
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(reachedToday, isTrue);
      await captureUi(
        tester,
        boundary,
        'insights-locked-${size.width.toInt()}x${size.height.toInt()}-200pct',
      );
    });
    for (final empty in [false, true]) {
      testWidgets('인사이트 $size 200% empty=$empty 기간 선택과 전체 요약 도달', (
        tester,
      ) async {
        final boundary = GlobalKey();
        await mount(
          tester,
          _fixture(empty: empty),
          AppTheme.light(),
          size: size,
          scale: 2,
          boundary: boundary,
        );
        expect(tester.takeException(), isNull);
        await captureUi(
          tester,
          boundary,
          'insights-${size.width.toInt()}x${size.height.toInt()}-${empty ? 'empty' : 'populated'}-top-200pct',
        );
        for (final label in ['평균 감정', '현재 스트릭', '총 기록', '선택 기간 기록']) {
          final statLabel = find.descendant(
            of: find.byType(StatCard),
            matching: find.text(label),
          );
          await tester.ensureVisible(statLabel);
          expect(
            tester.getRect(statLabel).bottom,
            lessThanOrEqualTo(size.height),
          );
        }
        for (final label in ['1주', '1개월', '3개월']) {
          await tester.ensureVisible(find.text(label));
          final target = find
              .ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate(
                  (widget) => widget is ButtonStyleButton || widget is InkWell,
                ),
              )
              .first;
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
          await tester.tap(target);
          await tester.pumpAndSettle();
        }
        if (!empty) {
          for (final section in ['감정 추이', '2026년 10월 요약', '주간 회고']) {
            await tester.ensureVisible(find.text(section));
            await captureUi(
              tester,
              boundary,
              'insights-${size.width.toInt()}x${size.height.toInt()}-$section-200pct',
            );
          }
        }
        await tester.ensureVisible(find.text('월간 리포트 PDF'));
        expect(
          tester.getRect(find.text('월간 리포트 PDF')).bottom,
          lessThanOrEqualTo(size.height),
        );
        expect(tester.takeException(), isNull);
        await captureUi(
          tester,
          boundary,
          'insights-${size.width.toInt()}x${size.height.toInt()}-${empty ? 'empty' : 'populated'}-200pct',
        );
      });
    }
  }

  for (final emotion in [1, 2, 3, 4, 5]) {
    testWidgets('인사이트 단일 감정 $emotion 200% 숫자가 원 안에 맞는다', (tester) async {
      for (final dark in [false, true]) {
        final boundary = GlobalKey();
        await mount(
          tester,
          _fixture().copyWith(
            emotionTrend: [(date: DateTime(2026, 10, 11), emotion: emotion)],
          ),
          dark ? AppTheme.dark() : AppTheme.light(),
          scale: 2,
          boundary: boundary,
        );
        final number = find.descendant(
          of: find.byType(EmotionTrendChart),
          matching: find.text('$emotion'),
        );
        final circle = find
            .ancestor(of: number, matching: find.byType(Container))
            .first;
        expect(
          tester
              .renderObject<RenderParagraph>(number)
              .getMaxIntrinsicHeight(tester.getSize(number).width),
          lessThanOrEqualTo(tester.getSize(circle).height),
        );
        expectReadableText(tester);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(EmotionTrendChart));
        await captureUi(
          tester,
          boundary,
          'insights-single-$emotion-${dark ? 'dark' : 'light'}-200pct',
        );
      }
    });
  }

  for (final days in [7, 14, 30]) {
    for (final size in [const Size(320, 640), const Size(640, 320)]) {
      testWidgets('연속 날짜 $days일 $size 200% 축 라벨 겹침과 끝점 클리핑 없음', (tester) async {
        final boundary = GlobalKey();
        await mount(
          tester,
          _fixture().copyWith(
            emotionTrend: [
              for (var day = 1; day <= days; day++)
                (date: DateTime(2026, 10, day), emotion: 3),
            ],
          ),
          AppTheme.light(),
          size: size,
          scale: 2,
          boundary: boundary,
        );
        final chartFinder = find.byType(EmotionTrendChart);
        await tester.ensureVisible(chartFinder);
        await tester.pumpAndSettle();
        await captureUi(
          tester,
          boundary,
          'insights-dates-$days-${size.width.toInt()}x${size.height.toInt()}-200pct',
        );
        final labels = find.descendant(
          of: chartFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                RegExp(r'^10/\d+$').hasMatch(widget.data ?? ''),
          ),
        );
        final rectangles =
            labels
                .evaluate()
                .map((element) => tester.getRect(find.byWidget(element.widget)))
                .toList()
              ..sort((a, b) => a.left.compareTo(b.left));
        expect(rectangles.length, greaterThanOrEqualTo(2));
        expect(
          find.descendant(of: chartFinder, matching: find.text('10/1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: chartFinder, matching: find.text('10/$days')),
          findsOneWidget,
        );
        final chartBounds = tester.getRect(chartFinder);
        expect(rectangles.first.left, greaterThanOrEqualTo(chartBounds.left));
        expect(rectangles.last.right, lessThanOrEqualTo(chartBounds.right));
        for (var index = 1; index < rectangles.length; index++) {
          expect(
            rectangles[index - 1].right + 4,
            lessThanOrEqualTo(rectangles[index].left),
            reason: '$days일 날짜 라벨 ${index - 1}/$index 실제 렌더 겹침',
          );
        }
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(
          chart.data.lineBarsData.fold<int>(
            0,
            (count, bar) => count + bar.spots.length,
          ),
          days,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('월간 PDF는 기본 글씨에서도 48dp native 버튼이다', (tester) async {
    await mount(tester, _fixture(), AppTheme.light());
    final target = find.ancestor(
      of: find.text('월간 리포트 PDF'),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(target, findsOneWidget);
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
  });
}
