import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/features/bookmarks/bookmark_button.dart';
import 'package:three_lines/features/bookmarks/bookmarks_screen.dart';

class _ControlledRepository extends EntryRepository {
  _ControlledRepository(super.db);
  int calls = 0;
  bool failNext = false;
  Completer<void>? pending;

  @override
  Future<bool> setBookmarked(String date, bool value) async {
    calls++;
    await pending?.future;
    if (failNext) {
      failNext = false;
      throw StateError('simulated write failure');
    }
    return super.setBookmarked(date, value);
  }
}

void main() {
  late AppDatabase db;
  late _ControlledRepository repo;
  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _ControlledRepository(db);
  });
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entryRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('실패를 알리고 선택 상태를 유지하며 다시 시도할 수 있다', (tester) async {
    await repo.saveEntry(DailyEntry(date: '2026-01-01', emotion: 1));
    repo.failNext = true;
    await pump(
      tester,
      const Scaffold(body: BookmarkButton(date: '2026-01-01')),
    );
    await tester.tap(find.text('책갈피에 담기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('책갈피를 바꾸지 못했어요'), findsOneWidget);
    expect(find.text('책갈피에 담기'), findsOneWidget);
    expect((await repo.getEntryByDate('2026-01-01'))!.isBookmarked, isFalse);
    await tester.tap(find.text('책갈피에 담기'));
    await tester.pumpAndSettle();
    expect(find.text('책갈피 해제'), findsOneWidget);
    expect(find.textContaining('책갈피를 바꾸지 못했어요'), findsNothing);
    expect((await repo.getEntryByDate('2026-01-01'))!.isBookmarked, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('저장 중 중복 탭은 DB 쓰기를 반복하지 않는다', (tester) async {
    await repo.saveEntry(DailyEntry(date: '2026-01-01', emotion: 2));
    repo.pending = Completer<void>();
    await pump(
      tester,
      const Scaffold(body: BookmarkButton(date: '2026-01-01')),
    );
    await tester.tap(find.text('책갈피에 담기'));
    await tester.tap(find.text('책갈피에 담기'));
    await tester.pump();
    expect(repo.calls, 1);
    expect(find.text('책갈피 반영 중'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('책갈피 해제'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  for (final dark in [false, true]) {
    testWidgets('320px 200% 글자에서 책갈피 목록과 마음만 기록한 상세를 읽는다 dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await repo.saveEntry(
        DailyEntry(date: '2026-01-01', emotion: 1, isBookmarked: true),
      );
      await pump(tester, const BookmarksScreen(), dark: dark, scale: 2);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('마음만 남긴 기록'));
      await tester.tap(find.text('마음만 남긴 기록'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('마음만 남긴 기록이에요.'));
      expect(find.text('마음만 남긴 기록이에요.').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  }

  testWidgets('320px 200% 글자에서 빈 책갈피 안내를 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, const BookmarksScreen(), scale: 2);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.textContaining('내가 고른 기록만 여기에 모여요.'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
