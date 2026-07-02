import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/timeline/timeline_state.dart';

void main() {
  group('TimelineState', () {
    test('default values', () {
      const state = TimelineState();
      expect(state.currentStreak, 0);
      expect(state.longestStreak, 0);
      expect(state.emotionMap, isEmpty);
      expect(state.period, TimelinePeriod.weeks12);
    });

    test('startDateFrom returns exact days ago for weeks12', () {
      const state = TimelineState(period: TimelinePeriod.weeks12);
      final now = DateTime(2026, 3, 10, 12);
      expect(state.startDateFrom(now), now.subtract(const Duration(days: 84)));
    });

    test('startDateFrom returns exact days ago for months6', () {
      const state = TimelineState(period: TimelinePeriod.months6);
      final now = DateTime(2026, 3, 10, 12);
      expect(state.startDateFrom(now), now.subtract(const Duration(days: 182)));
    });

    test('startDateFrom returns exact days ago for year1', () {
      const state = TimelineState(period: TimelinePeriod.year1);
      final now = DateTime(2026, 3, 10, 12);
      expect(state.startDateFrom(now), now.subtract(const Duration(days: 365)));
    });

    test('copyWith preserves unspecified fields', () {
      const original = TimelineState(
        currentStreak: 10,
        longestStreak: 20,
        period: TimelinePeriod.months6,
      );
      final copied = original.copyWith(currentStreak: 15);
      expect(copied.currentStreak, 15);
      expect(copied.longestStreak, 20);
      expect(copied.period, TimelinePeriod.months6);
    });
  });
}
