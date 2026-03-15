import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/utils/date_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko');
  });
  group('getTodayString', () {
    test('returns formatted date string', () {
      final result = getTodayString();
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(result), isTrue);
    });
  });

  group('isSameDay', () {
    test('returns true for same day', () {
      final a = DateTime(2026, 3, 14, 10, 30);
      final b = DateTime(2026, 3, 14, 22, 45);
      expect(isSameDay(a, b), isTrue);
    });

    test('returns false for different days', () {
      final a = DateTime(2026, 3, 14);
      final b = DateTime(2026, 3, 15);
      expect(isSameDay(a, b), isFalse);
    });
  });

  group('dateToString', () {
    test('formats date correctly', () {
      expect(dateToString(DateTime(2026, 3, 14)), '2026-03-14');
      expect(dateToString(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('getDayOfWeekLabel', () {
    test('returns correct Korean labels', () {
      expect(getDayOfWeekLabel(1), '월');
      expect(getDayOfWeekLabel(2), '화');
      expect(getDayOfWeekLabel(3), '수');
      expect(getDayOfWeekLabel(4), '목');
      expect(getDayOfWeekLabel(5), '금');
      expect(getDayOfWeekLabel(6), '토');
      expect(getDayOfWeekLabel(7), '일');
    });
  });

  group('getGreeting', () {
    test('returns a valid Korean greeting', () {
      final result = getGreeting();
      expect(
        ['좋은 아침이에요', '좋은 오후예요', '좋은 저녁이에요'],
        contains(result),
      );
    });
  });

  group('formatKoreanDate', () {
    test('formats date in Korean', () {
      final result = formatKoreanDate(DateTime(2026, 3, 14));
      expect(result, contains('2026년'));
      expect(result, contains('3월'));
      expect(result, contains('14일'));
    });
  });

  group('formatDateString', () {
    test('converts date string to Korean format', () {
      final result = formatDateString('2026-03-14');
      expect(result, contains('2026년'));
      expect(result, contains('3월'));
      expect(result, contains('14일'));
    });
  });

  group('stringToDate', () {
    test('parses date string to DateTime', () {
      final result = stringToDate('2026-03-14');
      expect(result.year, 2026);
      expect(result.month, 3);
      expect(result.day, 14);
    });
  });
}
