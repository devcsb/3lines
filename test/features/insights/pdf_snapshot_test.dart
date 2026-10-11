import 'dart:typed_data';
import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/pdf_report_service.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/features/insights/insights_controller.dart';
import 'package:three_lines/features/insights/insights_screen.dart';
import 'package:three_lines/features/insights/insights_state.dart';

class _Clock extends AppClock {
  @override
  DateTime now() => DateTime(2020, 2, 29);
}

class _StaleController extends InsightsController {
  @override
  Future<InsightsState> build() async => const InsightsState(
    isUnlocked: true,
    totalCount: 9,
    monthlySummary: MonthlySummary(
      monthLabel: '2월',
      averageEmotion: 5,
      entryCount: 9,
      topKeyword: '오래된키워드',
    ),
  );
}

class _CapturePdf extends PdfReportService {
  int? year;
  int? month;
  List<DailyEntry>? entries;
  double? average;
  String? keyword;
  @override
  Future<Uint8List> generateMonthlyReport({
    required int year,
    required int month,
    required List<DailyEntry> entries,
    required double averageEmotion,
    required String topKeyword,
  }) async {
    this.year = year;
    this.month = month;
    this.entries = entries;
    average = averageEmotion;
    keyword = topKeyword;
    throw StateError('stop before platform share');
  }
}

class _CountingRepository extends EntryRepository {
  _CountingRepository(super.db);
  int reads = 0;
  Completer<void>? gate;
  Completer<void>? captured;
  @override
  Future<List<DailyEntry>> getMonthlyEntries(int year, int month) async {
    reads++;
    final entries = await super.getMonthlyEntries(year, month);
    captured?.complete();
    await gate?.future;
    return entries;
  }
}

void main() {
  testWidgets('PDF 본문과 평균 및 키워드는 주입 시계의 월별 단일 snapshot이다', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = _CountingRepository(db);
    final service = _CapturePdf();
    await repo.saveEntry(
      DailyEntry(date: '2020-02-29', emotion: 2, answer1: '가족 가족 가족'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsControllerProvider.overrideWith(_StaleController.new),
          entryRepositoryProvider.overrideWithValue(repo),
          appClockProvider.overrideWithValue(_Clock()),
          pdfReportServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: InsightsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('월간 리포트 PDF'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('월간 리포트 PDF'));
    await tester.pumpAndSettle();
    expect(service.year, 2020);
    expect(service.month, 2);
    expect(service.entries!.single.date, '2020-02-29');
    expect(service.average, 2);
    expect(service.keyword, '가족');
    expect(repo.reads, 1);
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
  testWidgets('월별 조회 뒤 기록 삭제가 완료되어도 PDF 요약과 본문은 같은 snapshot이다', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = _CountingRepository(db);
    final service = _CapturePdf();
    await repo.saveEntry(
      DailyEntry(
        date: '2020-02-28',
        emotion: 4,
        answer1: '가족 가족',
        photoPath: '/test/photo.jpg',
      ),
    );
    await repo.saveEntry(
      DailyEntry(date: '2020-02-29', emotion: 2, answer1: '가족'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsControllerProvider.overrideWith(_StaleController.new),
          entryRepositoryProvider.overrideWithValue(repo),
          appClockProvider.overrideWithValue(_Clock()),
          pdfReportServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: InsightsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('월간 리포트 PDF'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    repo.gate = Completer<void>();
    repo.captured = Completer<void>();
    await tester.tap(find.text('월간 리포트 PDF'));
    await tester.runAsync(() async {
      await repo.captured!.future;
      await repo.deleteEntry('2020-02-28');
      repo.gate!.complete();
    });
    await tester.pumpAndSettle();
    expect(service.entries!.length, 2);
    expect(service.entries!.first.photoPath, '/test/photo.jpg');
    expect(service.average, 3);
    expect(service.keyword, '가족');
    expect(repo.reads, 1);
    expect(await repo.getTotalCount(), 1);
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
