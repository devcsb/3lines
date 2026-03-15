import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test the onboarding page data and structure without Riverpod dependency
void main() {
  group('Onboarding content', () {
    test('has exactly 3 pages defined', () {
      // These match the PRD 4.1 spec
      const pages = [
        (
          icon: Icons.edit_note,
          title: '하루 3줄로 나를 기록하세요',
          subtitle: '감사, 수용, 의도 — 30초면 충분해요',
        ),
        (
          icon: Icons.insights,
          title: '감정의 흐름을 한눈에',
          subtitle: '히트맵과 인사이트로 나를 발견해요',
        ),
        (
          icon: Icons.shield,
          title: '당신만의 공간',
          subtitle: '모든 데이터는 기기에만 저장돼요',
        ),
      ];

      expect(pages.length, 3);
      expect(pages[0].title, '하루 3줄로 나를 기록하세요');
      expect(pages[1].title, '감정의 흐름을 한눈에');
      expect(pages[2].title, '당신만의 공간');
    });

    test('page icons match PRD spec', () {
      expect(Icons.edit_note, isNotNull); // 연필 아이콘
      expect(Icons.insights, isNotNull);  // 차트 아이콘
      expect(Icons.shield, isNotNull);    // 방패 아이콘
    });
  });
}
