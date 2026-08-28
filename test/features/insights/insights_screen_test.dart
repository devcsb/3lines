import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/insights/insights_controller.dart';
import 'package:three_lines/features/insights/insights_screen.dart';
import 'package:three_lines/features/insights/insights_state.dart';

final class _GateInsightsController extends InsightsController {
  _GateInsightsController(this.gate);

  final Completer<void> gate;
  var buildCount = 0;

  @override
  Future<InsightsState> build() async {
    buildCount++;
    if (buildCount > 1) await gate.future;
    return InsightsState(
      isUnlocked: true,
      totalCount: 7,
      averageEmotion: 4,
      currentStreak: 1,
      bestDayOfWeek: '월요일',
      emotionTrend: [(date: DateTime(2026, 8, 26), emotion: 4)],
    );
  }
}

void main() {
  testWidgets('인사이트 새로고침은 데이터 Future 완료까지 기다린다', (tester) async {
    final gate = Completer<void>();
    final controller = _GateInsightsController(gate);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [insightsControllerProvider.overrideWith(() => controller)],
        child: const MaterialApp(home: InsightsScreen()),
      ),
    );
    await tester.pump();

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final refresh = indicator.onRefresh();
    var completed = false;
    unawaited(refresh.whenComplete(() => completed = true));
    await tester.pump();

    expect(controller.buildCount, 2);
    expect(completed, isFalse);

    gate.complete();
    await refresh;
    expect(completed, isTrue);
  });

  testWidgets('인사이트 기간 선택은 라벨과 48dp 조작 영역을 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = _GateInsightsController(Completer<void>());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [insightsControllerProvider.overrideWith(() => controller)],
        child: const MaterialApp(home: InsightsScreen()),
      ),
    );
    await tester.pump();

    final target = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == '인사이트 기간: 1주, 선택됨',
    );
    expect(target, findsOneWidget);
    final rect = tester.getRect(target);
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));

    semantics.dispose();
  });

  testWidgets('reduce-motion에서는 기간 칩 전환이 즉시 끝난다', (tester) async {
    final controller = _GateInsightsController(Completer<void>());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [insightsControllerProvider.overrideWith(() => controller)],
        child: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: InsightsScreen()),
        ),
      ),
    );
    await tester.pump();

    final target = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == '인사이트 기간: 1주, 선택됨',
    );
    final chip = tester.widget<AnimatedContainer>(
      find.descendant(of: target, matching: find.byType(AnimatedContainer)),
    );
    expect(chip.duration, Duration.zero);
  });

  testWidgets('reduce-motion에서는 인사이트 해금 배너가 최종 위치에 표시된다', (tester) async {
    final controller = _GateInsightsController(Completer<void>());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [insightsControllerProvider.overrideWith(() => controller)],
        child: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: InsightsScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('인사이트가 열렸어요!'), findsOneWidget);
    final bannerTransform = tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.text('인사이트가 열렸어요!'),
            matching: find.byType(Transform),
          ),
        )
        .first;
    expect(bannerTransform.transform.getTranslation().y, 0.0);
  });
}
