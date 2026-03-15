import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/utils/text_analysis.dart';

void main() {
  group('extractKeywords', () {
    test('returns empty map for empty input', () {
      final result = extractKeywords([]);
      expect(result, isEmpty);
    });

    test('returns empty map for empty strings', () {
      final result = extractKeywords(['', '   ', '']);
      expect(result, isEmpty);
    });

    test('filters out single character words', () {
      final result = extractKeywords(['나 는 좋 다']);
      expect(result, isEmpty);
    });

    test('filters out Korean stopwords', () {
      final result = extractKeywords(['오늘 정말 그리고 하지만 때문에']);
      expect(result, isEmpty);
    });

    test('extracts keywords from normal text', () {
      final result = extractKeywords([
        '맑은 날씨가 좋았다',
        '맑은 하늘이 예뻤다',
        '커피 마시며 산책했다',
      ]);
      expect(result.containsKey('맑은'), isTrue);
      expect(result['맑은'], 2);
    });

    test('respects limit parameter', () {
      final result = extractKeywords(
        ['사과 바나나 포도 딸기 수박 참외 키위 망고 복숭아 자두 체리 블루베리'],
        limit: 5,
      );
      expect(result.length, lessThanOrEqualTo(5));
    });

    test('sorts by frequency descending', () {
      final result = extractKeywords([
        '커피 커피 커피 산책 산책 날씨',
      ]);
      final entries = result.entries.toList();
      expect(entries.first.key, '커피');
      expect(entries.first.value, 3);
    });

    test('handles mixed Korean and English', () {
      final result = extractKeywords(['Flutter 개발 React 개발']);
      expect(result.containsKey('개발'), isTrue);
      expect(result['개발'], 2);
    });

    test('removes special characters', () {
      final result = extractKeywords(['감사합니다! 정말로... 좋은 하루!']);
      // Special chars are stripped, words remain
      expect(result.containsKey('감사합니다'), isTrue);
    });
  });
}
