import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/timeline/timeline_controller.dart';

void main() {
  group('TimelineState', () {
    test('default values', () {
      const state = TimelineState();
      expect(state.currentStreak, 0);
      expect(state.longestStreak, 0);
      expect(state.emotionMap, isEmpty);
      expect(state.period, TimelinePeriod.weeks12);
    });

    test('startDate returns approximately correct days ago for weeks12', () {
      const state = TimelineState(period: TimelinePeriod.weeks12);
      final now = DateTime.now();
      final start = state.startDate;
      final diff = now.difference(start).inDays;
      // Subtract Duration(days: 84) then check inDays — can be 83 or 84
      // depending on time-of-day
      expect(diff, inInclusiveRange(83, 84));
    });

    test('startDate returns approximately correct days ago for months6', () {
      const state = TimelineState(period: TimelinePeriod.months6);
      final now = DateTime.now();
      final start = state.startDate;
      final diff = now.difference(start).inDays;
      expect(diff, inInclusiveRange(181, 182));
    });

    test('startDate returns approximately correct days ago for year1', () {
      const state = TimelineState(period: TimelinePeriod.year1);
      final now = DateTime.now();
      final start = state.startDate;
      final diff = now.difference(start).inDays;
      expect(diff, inInclusiveRange(364, 365));
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
