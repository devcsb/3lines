import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/features/timeline/timeline_screen.dart';
import 'package:three_lines/features/timeline/timeline_controller.dart';
import 'package:three_lines/features/timeline/widgets/entry_detail_sheet.dart';

import 'timeline_intent_test.dart' show MutableClock, DelayedSearchRepository;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
    // Widget tests의 Ahem 대신 실제 한국어 글리프와 앱 색상으로 시각 QA한다.
    // macOS에서는 실제 플랫폼 fallback, 다른 host에서는 기존 PDF 번들 폰트.
    final korean = File('/System/Library/Fonts/AppleSDGothicNeo.ttc');
    final koreanBytes = await korean.exists()
        ? ByteData.sublistView(await korean.readAsBytes())
        : await rootBundle.load('assets/fonts/NanumMyeongjo-Regular.ttf');
    await (FontLoader('NotoSans')..addFont(Future.value(koreanBytes))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> capture(
    WidgetTester tester,
    GlobalKey boundary,
    String path,
  ) async {
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('오래된 기록만 있어도 320px 200%에서 검색과 상세에 도달한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = MutableClock();
    final repo = EntryRepository(db, clock: clock);
    final boundary = GlobalKey();
    addTearDown(db.close);
    await tester.runAsync(() async {
      await repo.saveEntry(
        DailyEntry(
          date: '2026-03-01',
          emotion: 4,
          prompt1: '오늘 감사한 것은?',
          answer1: '오래된 여행 기록',
          answer2: '',
          answer3: '',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryRepositoryProvider.overrideWithValue(repo),
            appClockProvider.overrideWithValue(clock),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: const TimelineScreen(),
          ),
        ),
      );
      await tester.pump();
      await ProviderScope.containerOf(
        tester.element(find.byType(TimelineScreen)),
      ).read(timelineControllerProvider.future);
    });
    await tester.pumpAndSettle();
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('첫 기록을 시작해보세요'), findsNothing);
    await tester.ensureVisible(find.text('이 기간에는 기록이 없어요'));
    expect(find.text('이 기간에는 기록이 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await capture(
      tester,
      boundary,
      '/tmp/3lines-timeline-empty-period-200pct.png',
    );
    await tester.ensureVisible(find.byType(SearchBar));
    await tester.enterText(find.byType(SearchBar), '여행');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('오래된 여행 기록'));
    await tester.tap(find.text('오래된 여행 기록'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.byType(EntryDetailSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EntryDetailSheet),
        matching: find.textContaining('2026년 3월 1일'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await capture(tester, boundary, '/tmp/3lines-timeline-200pct.png');
  });

  for (final waitForDebounce in [false, true]) {
    testWidgets(
      '검색 clear는 ${waitForDebounce ? '실행 중 요청' : '대기 debounce'}를 무효화한다',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final clock = MutableClock();
        final repo = DelayedSearchRepository(db, clock: clock);
        addTearDown(db.close);
        late ProviderContainer container;
        await tester.runAsync(() async {
          await repo.saveEntry(
            DailyEntry(
              date: '2026-03-01',
              emotion: 4,
              answer1: '여행 기록',
              answer2: '',
              answer3: '',
            ),
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                entryRepositoryProvider.overrideWithValue(repo),
                appClockProvider.overrideWithValue(clock),
              ],
              child: const MaterialApp(home: TimelineScreen()),
            ),
          );
          await tester.pump();
          container = ProviderScope.containerOf(
            tester.element(find.byType(TimelineScreen)),
          );
          await container.read(timelineControllerProvider.future);
        });
        await tester.pumpAndSettle();
        repo.gates['여행'] = Completer<void>();
        await tester.enterText(find.byType(SearchBar), '여행');
        await tester.pump(
          waitForDebounce
              ? const Duration(milliseconds: 301)
              : const Duration(milliseconds: 50),
        );
        await tester.tap(find.byTooltip('검색 지우기'));
        repo.gates['여행']!.complete();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        final state = container.read(timelineControllerProvider).value!;
        expect(state.isSearching, false);
        expect(state.searchResults, isEmpty);
        expect(
          tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
          '',
        );
        expect(find.text('여행 기록'), findsNothing);
      },
    );
  }

  testWidgets('검색 오류는 입력과 기간을 보존하고 다시 시도한다', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = MutableClock();
    final repo = DelayedSearchRepository(db, clock: clock);
    addTearDown(db.close);
    await tester.runAsync(() async {
      await repo.saveEntry(
        DailyEntry(
          date: '2026-03-01',
          emotion: 4,
          answer1: '여행 기록',
          answer2: '',
          answer3: '',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryRepositoryProvider.overrideWithValue(repo),
            appClockProvider.overrideWithValue(clock),
          ],
          child: const MaterialApp(home: TimelineScreen()),
        ),
      );
      await tester.pump();
      await ProviderScope.containerOf(
        tester.element(find.byType(TimelineScreen)),
      ).read(timelineControllerProvider.future);
    });
    await tester.pumpAndSettle();
    repo.searchFails = true;
    await tester.enterText(find.byType(SearchBar), '여행');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('기록을 불러올 수 없어요'), findsOneWidget);
    expect(find.text('12주'), findsOneWidget);
    expect(
      tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
      '여행',
    );
    repo.searchFails = false;
    await tester.tap(find.text('다시 시도'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('여행 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
