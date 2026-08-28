import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
import 'package:three_lines/features/today/today_controller.dart';
import 'package:three_lines/features/today/today_screen.dart';
import 'package:three_lines/features/today/today_state.dart';

final class _CompletedTodayController extends TodayController {
  @override
  Future<TodayState> build() async {
    return TodayState(
      isCompleted: true,
      emotion: 4,
      answer1: '오늘의 기록',
      prompts: const ['질문 1', '질문 2', '질문 3'],
      currentStreak: 2,
      recentEmotions: [(date: DateTime(2026, 8, 29), emotion: 4)],
    );
  }
}

final class _FixedTodayClock extends AppClock {
  const _FixedTodayClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  testWidgets('reduce-motion에서는 완료 상태 배지가 즉시 표시된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayControllerProvider.overrideWith(_CompletedTodayController.new),
        ],
        child: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: TodayScreen()),
        ),
      ),
    );
    await tester.pump();

    final badge = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(const ValueKey<String>('read-mode-badge')),
    );
    expect(badge.duration, Duration.zero);
  });

  testWidgets('표시 날짜는 기록 조회와 같은 AppClock 기준을 사용한다', (tester) async {
    final fixedNow = DateTime(2024, 1, 2, 9);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appClockProvider.overrideWithValue(_FixedTodayClock(fixedNow)),
          todayControllerProvider.overrideWith(_CompletedTodayController.new),
        ],
        child: const MaterialApp(home: TodayScreen()),
      ),
    );
    await tester.pump();

    expect(find.text(du.formatKoreanDate(fixedNow)), findsOneWidget);
  });
}
