import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/pdf_report_service.dart';
import 'package:three_lines/data/models/daily_entry.dart';

/// PDF 생성 경로는 기존에 테스트가 전혀 없었다(audit). 빈/단일/경계 입력에서
/// throw 없이 유효한 PDF 바이트(%PDF 헤더)를 반환하는지 검증한다.
void main() {
  // rootBundle로 번들 폰트(나눔명조)를 로드하려면 바인딩 초기화가 필요하다.
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = PdfReportService();

  DailyEntry entry(
    String date, {
    int emotion = 3,
    String a1 = '감사',
    String a2 = '',
    String a3 = '',
  }) {
    return DailyEntry(
      date: date,
      emotion: emotion,
      prompt1: '감사한 것',
      answer1: a1,
      prompt2: '수용할 것',
      answer2: a2,
      prompt3: '의도',
      answer3: a3,
    );
  }

  void expectValidPdf(List<int> bytes) {
    expect(bytes.length, greaterThan(4));
    // PDF 매직 넘버 "%PDF"
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  }

  group('generateMonthlyReport', () {
    test('빈 entries에서도 throw 없이 유효한 PDF를 반환한다', () async {
      final bytes = await service.generateMonthlyReport(
        year: 2026,
        month: 3,
        entries: [],
        averageEmotion: 0.0,
        topKeyword: '',
      );
      expectValidPdf(bytes);
    });

    test('단일 entry로 PDF를 생성한다', () async {
      final bytes = await service.generateMonthlyReport(
        year: 2026,
        month: 3,
        entries: [entry('2026-03-01', emotion: 4, a1: '커피')],
        averageEmotion: 4.0,
        topKeyword: '커피',
      );
      expectValidPdf(bytes);
    });

    test('답변이 모두 빈 entry에서도 throw하지 않는다', () async {
      final bytes = await service.generateMonthlyReport(
        year: 2026,
        month: 3,
        entries: [entry('2026-03-02', emotion: 2, a1: '', a2: '', a3: '')],
        averageEmotion: 2.0,
        topKeyword: '',
      );
      expectValidPdf(bytes);
    });

    test('emotion이 범위 밖(0, 6)이어도 fallback으로 처리해 throw하지 않는다', () async {
      final bytes = await service.generateMonthlyReport(
        year: 2026,
        month: 3,
        entries: [
          entry('2026-03-03', emotion: 0),
          entry('2026-03-04', emotion: 6),
        ],
        averageEmotion: 3.0,
        topKeyword: '테스트',
      );
      expectValidPdf(bytes);
    });

    test('한글 텍스트 렌더 시 번들 한글 폰트(나눔명조)가 임베딩된다', () async {
      // 폰트 에셋이 제거되거나 로드가 깨지면 한글이 다시 깨지므로 회귀를 가드한다.
      // PDF 폰트 디스크립터에 PostScript 폰트명이 ASCII로 들어간다.
      final bytes = await service.generateMonthlyReport(
        year: 2026,
        month: 3,
        entries: [entry('2026-03-01', emotion: 4, a1: '한글 감사 기록')],
        averageEmotion: 4.0,
        topKeyword: '감사',
      );
      final ascii = String.fromCharCodes(bytes);
      expect(ascii.contains('NanumMyeongjo'), isTrue,
          reason: '생성된 PDF에 나눔명조 폰트가 임베딩되어야 한다');
    });
  });
}
