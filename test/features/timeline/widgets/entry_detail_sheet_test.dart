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
