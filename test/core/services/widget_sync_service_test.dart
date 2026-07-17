import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/widget_sync_service.dart';

void main() {
  group('WidgetSnapshot.buildStatusMessage', () {
    test('completed with emotion', () {
      expect(
        WidgetSnapshot.buildStatusMessage(
          isCompleted: true,
          streak: 3,
          emotion: 5,
        ),
        '오늘 기록 완료 · 감사',
      );
    });

    test('incomplete with streak', () {
      expect(
        WidgetSnapshot.buildStatusMessage(
          isCompleted: false,
          streak: 4,
          emotion: null,
        ),
        '오늘 아직이에요 · 스트릭 유지 중',
      );
    });

    test('incomplete without streak', () {
      expect(
        WidgetSnapshot.buildStatusMessage(
          isCompleted: false,
          streak: 0,
          emotion: null,
        ),
        '오늘 한 줄만 적어도 돼요',
      );
    });
  });

  group('WidgetSnapshot.buildStreakLabel', () {
    test('zero', () {
      expect(WidgetSnapshot.buildStreakLabel(0), '시작해볼까요');
    });

    test('positive', () {
      expect(WidgetSnapshot.buildStreakLabel(12), '12일');
    });
  });

  group('WidgetSnapshot.parseEmotionFromUri', () {
    test('parses valid emotion', () {
      final uri = Uri.parse('threelines://today?emotion=3');
      expect(WidgetSnapshot.parseEmotionFromUri(uri), 3);
    });

    test('rejects out of range', () {
      final uri = Uri.parse('threelines://today?emotion=9');
      expect(WidgetSnapshot.parseEmotionFromUri(uri), isNull);
    });

    test('rejects other schemes', () {
      final uri = Uri.parse('https://example.com/today?emotion=2');
      expect(WidgetSnapshot.parseEmotionFromUri(uri), isNull);
    });

    test('allows open without emotion', () {
      final uri = Uri.parse('threelines://today');
      expect(WidgetSnapshot.parseEmotionFromUri(uri), isNull);
    });
  });

  group('WidgetSnapshot.todayUri', () {
    test('builds without emotion', () {
      expect(
        WidgetSnapshot.todayUri().toString(),
        'threelines://today',
      );
    });

    test('builds with emotion', () {
      expect(
        WidgetSnapshot.todayUri(emotion: 4).toString(),
        'threelines://today?emotion=4',
      );
    });
  });
}
