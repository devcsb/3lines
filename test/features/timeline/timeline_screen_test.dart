import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/features/timeline/timeline_controller.dart';
import 'package:three_lines/features/timeline/timeline_screen.dart';
import 'package:three_lines/features/timeline/timeline_state.dart';

final class _GateTimelineController extends TimelineController {
  _GateTimelineController(this.gate);

  final Completer<void> gate;
  var buildCount = 0;

  @override
  Future<TimelineState> build() async {
    buildCount++;
    if (buildCount > 1) await gate.future;
    return TimelineState(
      currentStreak: 1,
      longestStreak: 1,
      emotionMap: {DateTime.now().toIso8601String().substring(0, 10): 4},
    );
  }
}

final class _EmptyTimelineController extends TimelineController {
  @override
  Future<TimelineState> build() async => const TimelineState();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  testWidgets('타임라인 새로고침은 데이터 Future 완료까지 기다린다', (tester) async {
    final gate = Completer<void>();
    final controller = _GateTimelineController(gate);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [timelineControllerProvider.overrideWith(() => controller)],
        child: const MaterialApp(home: TimelineScreen()),
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

  testWidgets('기록이 없는 타임라인은 오늘 기록 CTA를 제공한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timelineControllerProvider.overrideWith(
            () => _EmptyTimelineController(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/timeline',
            routes: [
              GoRoute(
                path: '/timeline',
                builder: (_, _) => const TimelineScreen(),
              ),
              GoRoute(
                path: '/',
                builder: (_, _) => const Text('today destination'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('첫 기록을 시작해보세요'), findsOneWidget);
    expect(find.text('오늘 기록하기'), findsOneWidget);
    await tester.tap(find.text('오늘 기록하기'));
    await tester.pumpAndSettle();
    expect(find.text('today destination'), findsOneWidget);
  });
}
