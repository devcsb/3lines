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
}
