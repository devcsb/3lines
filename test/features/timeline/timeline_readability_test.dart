import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/features/timeline/timeline_controller.dart';
import 'package:three_lines/features/timeline/timeline_screen.dart';
import 'package:three_lines/features/timeline/timeline_state.dart';
import 'package:three_lines/features/timeline/widgets/entry_detail_sheet.dart';

import '../../helpers/ui_readability.dart';
import '../../helpers/ui_render_fonts.dart';

final class _UiTimeline extends TimelineController {
  _UiTimeline(this.initial);
  final TimelineState initial;
  @override
  Future<TimelineState> build() async => initial;
  @override
  Future<void> setPeriod(TimelinePeriod period) async {
    state = AsyncData(state.value!.copyWith(period: period));
  }
}

DailyEntry _entry({String date = '2026-10-11', int emotion = 3}) => DailyEntry(
  date: date,
  emotion: emotion,
  prompt1: '오늘 감사한 것은?',
  answer1: '고정 시험 기록',
  prompt2: '오늘 받아들이고 싶은 것은?',
  answer2: '',
  prompt3: '다음에 하고 싶은 일은?',
  answer3: '천천히 산책하기',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadUiRenderFonts();
    await initializeDateFormatting('ko_KR');
  });

  Future<void> mount(
    WidgetTester tester,
    TimelineState state,
    ThemeData theme, {
    Size size = const Size(320, 640),
    double scale = 1,
    GlobalKey? boundary,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timelineControllerProvider.overrideWith(() => _UiTimeline(state)),
        ],
        child: MaterialApp(
          theme: uiRenderTheme(theme),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home: const TimelineScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final accent in AppTheme.accentSeeds.keys) {
    for (final dark in [false, true]) {
      testWidgets('타임라인 $accent dark=$dark 안내와 검색 날짜 대비', (tester) async {
        final theme = dark
            ? AppTheme.darkForAccent(accent)
            : AppTheme.lightForAccent(accent);
        await mount(
          tester,
          const TimelineState(
            totalCount: 1,
            currentStreak: 1234,
            longestStreak: 1234,
          ),
          theme,
        );
        expectReadableText(tester);
        expectReadableIcons(tester);
        await mount(
          tester,
          TimelineState(
            totalCount: 1,
            searchQuery: '시험',
            searchResults: [_entry()],
          ),
          theme,
        );
        expectReadableText(tester);
      });
    }
  }

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('타임라인 $size 200% 기간 선택과 기간 공백 검색 도달', (tester) async {
      final boundary = GlobalKey();
      await mount(
        tester,
        const TimelineState(
          totalCount: 1,
          currentStreak: 1234,
          longestStreak: 1234,
        ),
        AppTheme.light(),
        size: size,
        scale: 2,
        boundary: boundary,
      );
      expect(tester.takeException(), isNull);
      for (final label in ['12주', '6개월', '1년']) {
        await tester.ensureVisible(find.text(label));
        final target = find
            .ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            )
            .first;
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('전체 기록 검색'));
      final search = find.widgetWithText(TextButton, '전체 기록 검색');
      expect(tester.getSize(search).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await captureUi(
        tester,
        boundary,
        'timeline-${size.width.toInt()}x${size.height.toInt()}-empty-period-200pct',
      );
    });
  }

  for (final dark in [false, true]) {
    testWidgets('상세 dark=$dark 감정/카테고리/빈답변 대비와 200% 이전다음', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = EntryRepository(db);
      for (final size in [const Size(320, 640), const Size(640, 320)]) {
        for (final accent in AppTheme.accentSeeds.keys) {
          tester.view.physicalSize = size;
          final boundary = GlobalKey();
          await tester.runAsync(() async {
            // Each matrix case starts a fresh page/scroll position.
            await tester.pumpWidget(const SizedBox());
            await repo.saveEntry(_entry(date: '2026-10-10', emotion: 2));
            await repo.saveEntry(_entry());
            await tester.pumpWidget(
              ProviderScope(
                overrides: [entryRepositoryProvider.overrideWithValue(repo)],
                child: MaterialApp(
                  theme: uiRenderTheme(
                    dark
                        ? AppTheme.darkForAccent(accent)
                        : AppTheme.lightForAccent(accent),
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(2),
                      disableAnimations: true,
                    ),
                    child: RepaintBoundary(key: boundary, child: child!),
                  ),
                  home: Scaffold(
                    body: EntryDetailSheet(entry: _entry(), onDelete: (_) {}),
                  ),
                ),
              ),
            );
            await tester.pump();
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectReadableText(tester);
          expectReadableIcons(tester);
          for (final tooltip in ['삭제', '이전 기록', '다음 기록']) {
            expect(
              tester.getSize(find.byTooltip(tooltip)).height,
              greaterThanOrEqualTo(48),
            );
          }
          await captureUi(
            tester,
            boundary,
            'detail-$accent-${size.width.toInt()}x${size.height.toInt()}-${dark ? 'dark' : 'light'}-top-200pct',
          );
          await tester.tap(find.byTooltip('이전 기록'));
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await tester.pumpAndSettle();
          expect(find.text('불안'), findsOneWidget);
          await tester.tap(find.byTooltip('다음 기록'));
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await tester.pumpAndSettle();
          expect(find.text('보통'), findsOneWidget);
          await tester.ensureVisible(find.text('천천히 산책하기'));
          expect(tester.takeException(), isNull);
          await captureUi(
            tester,
            boundary,
            'detail-$accent-${size.width.toInt()}x${size.height.toInt()}-${dark ? 'dark' : 'light'}-bottom-200pct',
          );
        }
      }
    });
  }
}
