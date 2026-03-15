import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/insights/insights_controller.dart';

void main() {
  group('InsightsState', () {
    test('default values', () {
      const state = InsightsState();
      expect(state.isUnlocked, isFalse);
      expect(state.totalCount, 0);
      expect(state.requiredCount, 7);
      expect(state.averageEmotion, 0.0);
      expect(state.currentStreak, 0);
      expect(state.bestDayOfWeek, isEmpty);
      expect(state.emotionTrend, isEmpty);
      expect(state.dayOfWeekEmotions, isEmpty);
      expect(state.keywords, isEmpty);
      expect(state.gratitudeKeywords, isEmpty);
      expect(state.period, InsightsPeriod.week1);
    });

    test('copyWith preserves unspecified fields', () {
      const original = InsightsState(
        isUnlocked: true,
        totalCount: 15,
        averageEmotion: 3.5,
        currentStreak: 7,
        bestDayOfWeek: '월요일',
      );
      final copied = original.copyWith(totalCount: 20);
      expect(copied.isUnlocked, isTrue);
      expect(copied.totalCount, 20);
      expect(copied.averageEmotion, 3.5);
      expect(copied.currentStreak, 7);
      expect(copied.bestDayOfWeek, '월요일');
    });

    test('copyWith can update all fields', () {
      const original = InsightsState();
      final copied = original.copyWith(
        isUnlocked: true,
        totalCount: 10,
        averageEmotion: 4.2,
        currentStreak: 5,
        bestDayOfWeek: '금요일',
        period: InsightsPeriod.month3,
      );
      expect(copied.isUnlocked, isTrue);
      expect(copied.totalCount, 10);
      expect(copied.averageEmotion, 4.2);
      expect(copied.currentStreak, 5);
      expect(copied.bestDayOfWeek, '금요일');
      expect(copied.period, InsightsPeriod.month3);
    });
  });
}
