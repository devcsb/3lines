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

  group('daysSinceEpoch', () {
    test('uses the local calendar date at midnight, not the UTC instant', () {
      final localJustAfterMidnight = DateTime(2026, 8, 28, 0, 30);
      final expected = DateTime.utc(
        2026,
        8,
        28,
      ).difference(DateTime.utc(2024, 1, 1)).inDays;

      expect(daysSinceEpoch(localJustAfterMidnight), expected);
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
    test('returns a non-empty Korean greeting', () {
      final result = getGreeting();
      expect(result, isNotEmpty);
      expect(result.length, greaterThan(3));
    });

    test('returns streak-aware greeting at milestones', () {
      expect(getGreeting(streak: 6), '내일이면 7일째예요');
      expect(getGreeting(streak: 29), '내일이면 한 달이에요');
      expect(getGreeting(streak: 50), '50일, 대단해요');
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

  group('subtractMonths', () {
    test('normal case: March 15 minus 1 month = Feb 15', () {
      final result = subtractMonths(DateTime(2026, 3, 15), 1);
      expect(result, DateTime(2026, 2, 15));
    });

    test('day clamp: March 31 minus 1 month = Feb 28 (not March 3)', () {
      // This is the critical bug — DateTime(2026, 2, 31) would overflow to March 3
      final result = subtractMonths(DateTime(2026, 3, 31), 1);
      expect(result.month, 2);
      expect(result.day, 28);
    });

    test('day clamp on leap year: March 31 minus 1 month = Feb 29', () {
      final result = subtractMonths(DateTime(2028, 3, 31), 1);
      expect(result, DateTime(2028, 2, 29));
    });

    test(
      'crosses year boundary: Jan 15 minus 1 month = Dec 15 previous year',
      () {
        final result = subtractMonths(DateTime(2026, 1, 15), 1);
        expect(result, DateTime(2025, 12, 15));
      },
    );

    test('6 months back: Sept 30 minus 6 months = March 30', () {
      final result = subtractMonths(DateTime(2026, 9, 30), 6);
      expect(result, DateTime(2026, 3, 30));
    });

    test('6 months back with clamp: Aug 31 minus 6 months = Feb 28', () {
      final result = subtractMonths(DateTime(2026, 8, 31), 6);
      expect(result.month, 2);
      expect(result.day, 28);
    });

    test('12개월(1년) 전 같은 날짜를 윤년과 무관하게 구한다', () {
      // getOneYearAgoEntry가 이 함수에 의존한다. Duration(365) 방식은
      // 사이에 윤일이 끼면 하루 어긋나므로 회귀를 방지한다.
      expect(subtractMonths(DateTime(2025, 3, 1), 12), DateTime(2024, 3, 1));
      expect(subtractMonths(DateTime(2026, 1, 15), 12), DateTime(2025, 1, 15));
    });

    test('윤년 2월 29일의 12개월 전은 2월 28일로 clamp된다', () {
      expect(subtractMonths(DateTime(2024, 2, 29), 12), DateTime(2023, 2, 28));
    });
  });
}
