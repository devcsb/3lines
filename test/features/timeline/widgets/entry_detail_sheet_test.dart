import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/features/timeline/widgets/entry_detail_sheet.dart';

class _AdjacentRepository extends EntryRepository {
  _AdjacentRepository(super.db);
  Completer<void>? gate;
  bool fails = false;
  @override
  Future<DailyEntry?> getPreviousEntry(String currentDate) async {
    final entry = await super.getPreviousEntry(currentDate);
    await gate?.future;
    if (fails) throw StateError('adjacent failed');
    return entry;
  }
}

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
      overrides: [entryRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(body: EntryDetailSheet(entry: entry)),
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

  testWidgets('단일 기록 양끝 스와이프에도 현재 본문을 유지한다', (tester) async {
    await tester.runAsync(() async {
      await repo.saveEntry(testEntry);
      await tester.pumpWidget(buildApp(testEntry));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    for (final offset in [const Offset(500, 0), const Offset(-500, 0)]) {
      await tester.drag(find.byType(PageView), offset);
      await tester.pumpAndSettle();
      expect(find.text('맑은 날씨').hitTestable(), findsOneWidget);
    }
  });

  testWidgets('인접 조회 지연 중 스와이프와 실패 뒤 재시도는 현재 기록을 보존한다', (tester) async {
    final delayed = _AdjacentRepository(db)..gate = Completer<void>();
    repo = delayed;
    await tester.runAsync(() async {
      await repo.saveEntry(testEntry);
      await repo.saveEntry(
        DailyEntry(
          date: '2026-03-13',
          emotion: 2,
          answer1: '복구한 전날',
          answer2: '',
          answer3: '',
        ),
      );
      await tester.pumpWidget(buildApp(testEntry));
      await tester.pump();
    });
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('맑은 날씨').hitTestable(), findsOneWidget);
    delayed.fails = true;
    delayed.gate!.complete();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('맑은 날씨').hitTestable(), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
    delayed.fails = false;
    delayed.gate = null;
    await tester.tap(find.text('다시 시도'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('이전 기록'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('복구한 전날').hitTestable(), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('첫 마지막 기록은 이전 다음 버튼으로 왕복한다', (tester) async {
    final older = DailyEntry(
      date: '2026-03-13',
      emotion: 2,
      answer1: '전날 기록',
      answer2: '',
      answer3: '',
    );
    await tester.runAsync(() async {
      await repo.saveEntry(testEntry);
      await repo.saveEntry(older);
      await tester.pumpWidget(buildApp(testEntry));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('이전 기록'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('전날 기록').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('다음 기록'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('맑은 날씨').hitTestable(), findsOneWidget);
  });

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

  testWidgets('스와이프로 이전 날로 이동 후 삭제하면 현재 표시된 기록이 삭제된다 (회귀)', (tester) async {
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
