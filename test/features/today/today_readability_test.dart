import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/constants/default_prompts.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/data/models/journal_draft.dart';
import 'package:three_lines/features/today/today_controller.dart';
import 'package:three_lines/features/today/today_screen.dart';
import 'package:three_lines/features/today/today_state.dart';
import 'package:three_lines/features/today/widgets/animated_save_button.dart';

import '../../helpers/ui_readability.dart';
import '../../helpers/ui_render_fonts.dart';

class _Clock extends AppClock {
  @override
  DateTime now() => DateTime(2026, 10, 11, 9);
}

class _TodayFixture extends TodayController {
  _TodayFixture(this.fixture, this.error);
  final TodayState fixture;
  final Object? error;
  @override
  Future<TodayState> build() async {
    if (error != null) throw error!;
    return fixture;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadUiRenderFonts();
    await initializeDateFormatting('ko_KR');
  });
  const ready = TodayState(
    draftDate: '2026-10-11',
    emotion: 3,
    answer1: '마지막 저장 버튼까지 확인하는 고정 한글 시험 내용이에요',
    prompts: defaultPromptQuestions,
    storageStatus: DraftStorageStatus.stored,
    draftDates: ['2026-10-10', '2026-10-09'],
  );

  Future<void> mount(
    WidgetTester tester,
    TodayState fixture, {
    Object? error,
    bool dark = false,
    Size size = const Size(320, 640),
    GlobalKey? boundary,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appClockProvider.overrideWithValue(_Clock()),
          todayControllerProvider.overrideWith(
            () => _TodayFixture(fixture, error),
          ),
        ],
        child: MaterialApp(
          theme: uiRenderTheme(dark ? AppTheme.dark() : AppTheme.light()),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home: const TodayScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final status in [DraftStorageStatus.stored, DraftStorageStatus.failed]) {
    testWidgets('Today $status 320px 200% 보관 안내와 최종 저장 도달', (tester) async {
      final boundary = GlobalKey();
      await mount(
        tester,
        ready.copyWith(
          storageStatus: status,
          draftError: () => status == DraftStorageStatus.failed
              ? '초안을 보관하지 못했어요. 작성한 내용은 화면에 유지했으니 다시 시도해주세요.'
              : null,
        ),
        boundary: boundary,
      );
      for (final label in [
        '2026-10-09 보관 초안',
        status == DraftStorageStatus.stored ? '초안 보관됨' : '초안 보관 다시 시도',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        expect(tester.getRect(find.text(label)).bottom, lessThanOrEqualTo(640));
      }
      await tester.ensureVisible(find.byType(AnimatedSaveButton));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final button = find.descendant(
        of: find.byType(AnimatedSaveButton),
        matching: find.byType(ElevatedButton),
      );
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(640));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await captureUi(tester, boundary, 'today-$status-320x640-200pct');
    });
  }

  testWidgets('Today 충돌 320px 200% 복사와 다시 열기 조작 도달', (tester) async {
    final boundary = GlobalKey();
    await mount(
      tester,
      ready.copyWith(
        hasConflict: true,
        draftError: () => '저장된 기록이 바뀌었어요. 입력을 먼저 복사해주세요.',
      ),
      dark: true,
      boundary: boundary,
    );
    for (final label in ['입력 내용 복사', '저장된 기록 다시 열기']) {
      final target = find.ancestor(
        of: find.text(label),
        matching: find.byType(TextButton),
      );
      await tester.ensureVisible(target);
      await tester.pump();
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      expect(tester.getRect(target).bottom, lessThanOrEqualTo(640));
    }
    expect(tester.takeException(), isNull);
    await captureUi(tester, boundary, 'today-conflict-320x640-200pct');
  });

  for (final dark in [false, true]) {
    testWidgets('Today dark=$dark 날짜 안내는 개별 alpha를 포함해 읽힌다', (tester) async {
      await mount(tester, ready, dark: dark);
      // Only this screen's date override, not previously tested children.
      final date = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data?.contains('10월 11일') == true,
      );
      expect(date, findsOneWidget);
      final widget = tester.widget<Text>(date);
      final foreground = widget.style!.color!;
      final background =
          (dark ? AppTheme.dark() : AppTheme.light()).colorScheme.surface;
      final a = Color.alphaBlend(foreground, background).computeLuminance();
      final b = background.computeLuminance();
      expect(
        ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('Today 손상 초안 $size 200% 안전 안내와 마지막 복구 버튼 도달', (tester) async {
      final boundary = GlobalKey();
      await mount(
        tester,
        ready,
        size: size,
        error: CorruptDraft(
          date: '2026-10-11',
          key: 'fixture',
          rawPayload: '{}',
          epoch: 0,
        ),
        boundary: boundary,
      );
      final discard = find.text('읽지 못한 초안 폐기');
      await tester.ensureVisible(discard);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(discard);
      await tester.pumpAndSettle();
      final safety = find.text(
        '이 초안만 지워요. 저장된 기록과 다른 초안은 유지해요. 안전하게 확인할 수 없는 사진 파일은 남겨둬요.',
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: safety, matching: find.byType(RichText)),
      );
      expect(
        paragraph.computeMaxIntrinsicHeight(paragraph.size.width),
        lessThanOrEqualTo(paragraph.size.height),
      );
      await Scrollable.ensureVisible(tester.element(safety), alignment: 1);
      await tester.pumpAndSettle();
      final cancel = find.widgetWithText(TextButton, '돌아가기');
      await tester.ensureVisible(cancel);
      await tester.pump();
      expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(size.height));
      final text = tester.widget<Text>(safety).data!;
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: text.length - 1,
              extentOffset: text.length,
            ),
          )
          .last;
      expect(
        paragraph.localToGlobal(Offset(box.right, box.bottom)).dy,
        lessThanOrEqualTo(tester.getRect(cancel).top),
      );
      expect(tester.takeException(), isNull);
      await captureUi(
        tester,
        boundary,
        'today-corrupt-${size.width.toInt()}x${size.height.toInt()}-200pct',
      );
    });
  }
}
