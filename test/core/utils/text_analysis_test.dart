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
      expect(result.containsKey('감사'), isTrue);
    });
  });

  group('stemKorean', () {
    test('strips past tense endings', () {
      expect(stemKorean('산책했다'), '산책');
      expect(stemKorean('운동했다'), '운동');
      expect(stemKorean('감사했다'), '감사');
    });

    test('strips connective endings', () {
      expect(stemKorean('산책했고'), '산책');
      expect(stemKorean('감사하며'), '감사');
      expect(stemKorean('운동하면'), '운동');
    });

    test('strips modifier endings', () {
      expect(stemKorean('감사하는'), '감사');
      expect(stemKorean('행복한'), '행복');
    });

    test('does not strip if stem would be too short', () {
      // "좋았다" → stem "좋" is 1 char, keep original
      expect(stemKorean('좋았다'), '좋았다');
    });

    test('strips polite endings', () {
      expect(stemKorean('감사합니다'), '감사');
      expect(stemKorean('운동했어요'), '운동');
    });

    test('returns word unchanged if no suffix matches', () {
      expect(stemKorean('커피'), '커피');
      expect(stemKorean('산책'), '산책');
    });
  });

  group('extractKeywords with stemming', () {
    test('merges different conjugations into same stem', () {
      final result = extractKeywords([
        '산책했다',
        '산책하는 것이 좋다',
        '산책하며 생각했다',
      ]);
      expect(result.containsKey('산책'), isTrue);
      expect(result['산책'], 3);
    });

    test('filters out common verb forms via stopwords', () {
      final result = extractKeywords(['있었다 없었다 했었다 됐다']);
      expect(result, isEmpty);
    });

    test('handles realistic journal entries', () {
      final result = extractKeywords([
        '날씨가 좋아서 산책할 수 있었다',
        '친구가 맛있는 커피를 사줬다',
        '가족과 함께 저녁식사를 했다',
        '프로젝트가 순조롭게 진행되고 있다',
        '동료가 도움을 줘서 일이 잘 풀렸다',
      ]);
      // Should extract meaningful nouns, not grammar
      expect(result.containsKey('했다'), isFalse);
      expect(result.containsKey('있었다'), isFalse);
      expect(result.containsKey('있다'), isFalse);
    });

    test('extracts meaningful words from gratitude entries', () {
      final result = extractKeywords([
        '맛있는 커피를 마셨다',
        '커피 한잔의 여유가 좋았다',
        '오랜 친구를 만나서 이야기했다',
        '친구들과 즐거운 시간을 보냈다',
      ]);
      expect(result.containsKey('커피'), isTrue);
      expect(result['커피'], 2);
    });
  });

  group('stripParticle', () {
    test('일반 조사를 분리한다', () {
      expect(stripParticle('커피를'), '커피');
      expect(stripParticle('가족이'), '가족');
      expect(stripParticle('산책에'), '산책');
    });

    test('긴 조사를 짧은 조사보다 우선 분리한다', () {
      expect(stripParticle('학교에서는'), '학교');
      expect(stripParticle('친구에게서'), '친구');
    });

    test('분리하면 명사가 1자가 되는 경우 분리하지 않는다', () {
      // noun.length >= 2 가드. 과도한 분리로 의미 손실을 막는다.
      expect(stripParticle('집에'), '집에');
      expect(stripParticle('차를'), '차를');
    });

    test('조사로 끝나지 않으면 원형을 유지한다', () {
      expect(stripParticle('바나나'), '바나나');
      expect(stripParticle('사과'), '사과');
    });

    test('명사 끝 글자가 1자 조사와 같아도 오분리하지 않는다', () {
      // 바나나는 조사로 끝나지 않으므로 그대로, 바나나가는 가만 분리.
      expect(stripParticle('바나나'), '바나나');
      expect(stripParticle('바나나가'), '바나나');
    });

    test('extractKeywords에서 같은 명사의 다른 조사형이 병합된다', () {
      final result = extractKeywords([
        '산책을 했다',
        '산책은 즐겁다',
        '산책에 나섰다',
      ]);
      expect(result['산책'], 3);
    });
  });
}
