import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/daily_entry.dart';
import '../theme/app_colors.dart';

/// Generates a monthly PDF journal report.
class PdfReportService {
  /// Builds a PDF document for the given month's entries and summary data.
  ///
  /// ponytail: 현재 PDF에 한글 글리프 폰트가 임베딩돼 있지 않아 한국어 텍스트가
  /// 깨진다(테스트 실행 시 "Unable to find a font to draw" 경고로 확인됨).
  /// printing의 PdfGoogleFonts에는 Noto Sans KR(CJK)이 없으므로, 오프라인 앱
  /// 원칙에 맞게 NotoSansKR TTF를 assets로 번들한 뒤 pw.Font.ttf로 로드해
  /// pw.Document(theme: ThemeData.withFont(...))에 적용해야 한다(폰트 에셋 추가 필요).
  Future<Uint8List> generateMonthlyReport({
    required int year,
    required int month,
    required List<DailyEntry> entries,
    required double averageEmotion,
    required String topKeyword,
  }) async {
    final doc = pw.Document();
    final monthLabel = '$year년 $month월';
    final daysInMonth = DateTime(year, month + 1, 0).day;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(monthLabel, context),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary section
          _buildSummarySection(
            entryCount: entries.length,
            daysInMonth: daysInMonth,
            averageEmotion: averageEmotion,
            topKeyword: topKeyword,
          ),
          pw.SizedBox(height: 16),

          // Emotion distribution
          _buildEmotionDistribution(entries),
          pw.SizedBox(height: 24),

          // Daily entries
          _buildEntriesSection(entries),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader(String monthLabel, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Three Lines',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF5B8A6A),
            ),
          ),
          pw.Text(
            '$monthLabel 리포트',
            style: const pw.TextStyle(
              fontSize: 14,
              color: PdfColor.fromInt(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
        '${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(
          fontSize: 10,
          color: PdfColor.fromInt(0xFFAAAAAA),
        ),
      ),
    );
  }

  pw.Widget _buildSummarySection({
    required int entryCount,
    required int daysInMonth,
    required double averageEmotion,
    required String topKeyword,
  }) {
    final completionRate = daysInMonth > 0
        ? (entryCount / daysInMonth * 100).round()
        : 0;
    final emotionLabel =
        AppColors.emotionLabels[averageEmotion.round()] ?? '';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF5F3EF),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('기록 일수', '$entryCount / $daysInMonth일'),
          _summaryItem('달성률', '$completionRate%'),
          _summaryItem(
            '평균 감정',
            '${averageEmotion.toStringAsFixed(1)} $emotionLabel',
          ),
          if (topKeyword.isNotEmpty)
            _summaryItem('핵심 키워드', topKeyword),
        ],
      ),
    );
  }

  pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColor.fromInt(0xFF999999),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF333333),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildEmotionDistribution(List<DailyEntry> entries) {
    // Count each emotion level
    final counts = <int, int>{};
    for (final e in entries) {
      counts[e.emotion] = (counts[e.emotion] ?? 0) + 1;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE0DDD6)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '감정 분포',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF666666),
            ),
          ),
          pw.SizedBox(height: 10),
          ...List.generate(5, (i) {
            final level = 5 - i; // 5 → 1
            final count = counts[level] ?? 0;
            final label =
                AppColors.emotionLabels[level] ?? '$level';
            final ratio =
                entries.isNotEmpty ? count / entries.length : 0.0;
            final color = _emotionPdfColor(level);

            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text(
                      label,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColor.fromInt(0xFF666666),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.LayoutBuilder(
                      builder: (context, constraints) {
                        final barWidth =
                            (constraints?.maxWidth ?? 200) * ratio;
                        return pw.Stack(
                          children: [
                            pw.Container(
                              height: 12,
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFFEEECE6),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                            ),
                            pw.Container(
                              height: 12,
                              width: barWidth,
                              decoration: pw.BoxDecoration(
                                color: color,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                    width: 24,
                    child: pw.Text(
                      '$count',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColor.fromInt(0xFF888888),
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _buildEntriesSection(List<DailyEntry> entries) {
    if (entries.isEmpty) {
      return pw.Text(
        '이 달에 기록이 없습니다.',
        style: const pw.TextStyle(
          fontSize: 11,
          color: PdfColor.fromInt(0xFF999999),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '일별 기록',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF444444),
          ),
        ),
        pw.SizedBox(height: 12),
        ...entries.map(_buildEntryCard),
      ],
    );
  }

  pw.Widget _buildEntryCard(DailyEntry entry) {
    final parsed = DateTime.tryParse(entry.date);
    final dateLabel = parsed != null
        ? '${parsed.month}/${parsed.day} (${_weekdayLabel(parsed.weekday)})'
        : entry.date;
    final emotionLabel =
        AppColors.emotionLabels[entry.emotion] ?? '';
    final color = _emotionPdfColor(entry.emotion);

    final prompts = <(String, String)>[
      if (entry.answer1.isNotEmpty) (entry.prompt1, entry.answer1),
      if (entry.answer2.isNotEmpty) (entry.prompt2, entry.answer2),
      if (entry.answer3.isNotEmpty) (entry.prompt3, entry.answer3),
    ];

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE0DDD6)),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Date + emotion row
          pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: color,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                dateLabel,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF444444),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                emotionLabel,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: color,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          // Answers
          ...prompts.map((pa) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      pa.$1,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColor.fromInt(0xFFAAAAAA),
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      pa.$2,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColor.fromInt(0xFF333333),
                        lineSpacing: 2,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  PdfColor _emotionPdfColor(int emotion) {
    final flutterColor = AppColors.emotionColors[emotion];
    if (flutterColor != null) {
      return PdfColor.fromInt(flutterColor.toARGB32());
    }
    return const PdfColor.fromInt(0xFF888888);
  }

  String _weekdayLabel(int weekday) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[(weekday - 1).clamp(0, 6)];
  }
}

final pdfReportServiceProvider = Provider<PdfReportService>((ref) {
  return PdfReportService();
});
