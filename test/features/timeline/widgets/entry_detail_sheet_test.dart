import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/features/timeline/widgets/entry_detail_sheet.dart';

void main() {
  late AppDatabase db;
  late EntryRepository repo;

  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp(DailyEntry entry) {
    return ProviderScope(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EntryDetailSheet(entry: entry),
        ),
      ),
    );
  }

  final testEntry = DailyEntry(
    id: 1,
    date: '2026-03-14',
    emotion: 4,
    prompt1: '오늘 감사한 것은?',
    answer1: '맑은 날씨',
    prompt2: '불편한 감정은?',
    answer2: '약간의 긴장',
    prompt3: '내일의 목표는?',
    answer3: '침착하게',
  );

  testWidgets('displays date in Korean format', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildApp(testEntry));
      await tester.pump();
    });
    expect(find.textContaining('2026년 3월 14일'), findsOneWidget);
  });

  testWidgets('displays emotion label', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildApp(testEntry));
      await tester.pump();
    });
    expect(find.text('평온'), findsOneWidget);
  });

  testWidgets('displays all three Q&A pairs', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildApp(testEntry));
      await tester.pump();
    });
    expect(find.text('오늘 감사한 것은?'), findsOneWidget);
    expect(find.text('맑은 날씨'), findsOneWidget);
    expect(find.text('불편한 감정은?'), findsOneWidget);
    expect(find.text('약간의 긴장'), findsOneWidget);
    expect(find.text('내일의 목표는?'), findsOneWidget);
    expect(find.text('침착하게'), findsOneWidget);
  });

  testWidgets('스와이프로 이전 날로 이동 후 삭제하면 현재 표시된 기록이 삭제된다 (회귀)',
      (tester) async {
    DailyEntry? deleted;
    // id 없이 저장(autoincrement) — fixture testEntry(id:1)와 충돌 방지.
    final mar14 = DailyEntry(
      date: '2026-03-14',
      emotion: 4,
      prompt1: '오늘 감사한 것은?',
      answer1: '당일 기록',
      prompt2: 'Q2',
      answer2: '',
      prompt3: 'Q3',
      answer3: '',
    );
    await tester.runAsync(() async {
      await repo.saveEntry(
        DailyEntry(
          date: '2026-03-13',
          emotion: 2,
          prompt1: 'Q1',
          answer1: '전날 기록',
          prompt2: 'Q2',
          answer2: '',
          prompt3: 'Q3',
          answer3: '',
        ),
      );
      await repo.saveEntry(mar14);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [entryRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: EntryDetailSheet(
                entry: mar14,
                onDelete: (e) => deleted = e,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // _loadAdjacent
      // 오른쪽으로 드래그 → 이전 페이지(2026-03-13)
      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // 삭제 아이콘 → 확인 다이얼로그 → 삭제
      await tester.tap(find.byTooltip('삭제'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pump();
    });
    // 원본(3-14)이 아니라 스와이프해서 보고 있던 3-13 이 삭제돼야 한다.
    expect(deleted?.date, '2026-03-13');
  });

  testWidgets('shows em dash for empty answers', (tester) async {
    final emptyEntry = DailyEntry(
      date: '2026-03-14',
      emotion: 3,
      prompt1: 'Q1',
      answer1: '',
      prompt2: 'Q2',
      answer2: '',
      prompt3: 'Q3',
      answer3: '',
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(buildApp(emptyEntry));
      await tester.pump();
    });
    expect(find.text('—'), findsNWidgets(3));
  });
}
