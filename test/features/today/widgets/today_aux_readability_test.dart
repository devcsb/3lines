import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/features/today/widgets/animated_save_button.dart';
import 'package:three_lines/features/today/widgets/completion_animation.dart';
import 'package:three_lines/features/today/widgets/milestone_banner.dart';
import 'package:three_lines/features/today/widgets/one_year_ago_card.dart';
import 'package:three_lines/features/today/widgets/streak_pulse_badge.dart';

import '../../../helpers/ui_readability.dart';
import '../../../helpers/ui_render_fonts.dart';

DailyEntry _entry(int emotion) => DailyEntry(
  date: '2025-10-11',
  emotion: emotion,
  answer1: '지난 기록을 돌아보는 고정 한글 시험 내용이에요',
  answer2: '따뜻한 식사를 했어요',
);

Widget _past() => OneYearAgoCard(
  entry: _entry(5),
  sixMonthsAgoEntry: _entry(3),
  oneMonthAgoEntry: _entry(1),
);
Widget _save({int count = 0, bool canSave = false, VoidCallback? onPressed}) =>
    AnimatedSaveButton(
      filledCount: count,
      canSave: canSave,
      isSaving: false,
      emotionSelected: true,
      guidanceMessage: canSave
          ? '감정과 한 줄 이상을 작성해 저장할 수 있어요'
          : '감정과 답변 한 개부터 저장할 수 있어요',
      onPressed: onPressed,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiRenderFonts);

  Future<void> mount(
    WidgetTester tester,
    Widget child,
    ThemeData theme, {
    Size size = const Size(320, 640),
    double scale = 1,
    bool completion = false,
    GlobalKey? boundary,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: uiRenderTheme(theme),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: boundary, child: child!),
        ),
        home: Scaffold(
          // The actual app shell also reserves an 80dp NavigationBar.
          bottomNavigationBar: completion ? const SizedBox(height: 80) : null,
          body: completion
              ? child
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> drainCompletion(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  for (final accent in AppTheme.accentSeeds.keys) {
    for (final dark in [false, true]) {
      final theme = dark
          ? AppTheme.darkForAccent(accent)
          : AppTheme.lightForAccent(accent);
      final widgets = <String, Widget>{
        '과거 기록': _past(),
        '연속 기록': const StreakPulseBadge(streak: 1234, usedGraceDay: true),
        '달성 배너': MilestoneBanner(milestone: 365, onDismiss: () {}),
        '저장 진행': _save(),
      };
      for (final item in widgets.entries) {
        testWidgets('${item.key} $accent dark=$dark 실제 합성 대비', (tester) async {
          await mount(tester, item.value, theme);
          expectReadableText(tester);
          expectReadableIcons(tester);
        });
      }
      testWidgets('완료 안내 $accent dark=$dark 감정별 문자 대비', (tester) async {
        try {
          for (final emotion in [1, 2, 3, 4, 5]) {
            await mount(
              tester,
              CompletionAnimation(emotion: emotion, streak: 1234),
              theme,
              completion: true,
            );
            expectReadableText(tester);
          }
        } finally {
          await drainCompletion(tester);
        }
      });
    }
  }

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('보조 카드 $size 200% 제목과 연속기록 읽기', (tester) async {
      final boundary = GlobalKey();
      await mount(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StreakPulseBadge(streak: 1234, usedGraceDay: true),
            const SizedBox(height: 16),
            _past(),
          ],
        ),
        AppTheme.light(),
        size: size,
        scale: 2,
        boundary: boundary,
      );
      expect(tester.takeException(), isNull);
      for (final label in ['1234일 연속 기록 중', '1개월 전', '6개월 전', '1년 전']) {
        await tester.ensureVisible(find.text(label));
        expect(
          tester.getRect(find.text(label)).bottom,
          lessThanOrEqualTo(size.height),
        );
      }
      await captureUi(
        tester,
        boundary,
        'today-past-${size.width.toInt()}x${size.height.toInt()}-200pct',
      );
    });
    testWidgets('달성 배너 $size 200% 확인 native48dp', (tester) async {
      var dismissed = false;
      final boundary = GlobalKey();
      await mount(
        tester,
        MilestoneBanner(milestone: 365, onDismiss: () => dismissed = true),
        AppTheme.light(),
        size: size,
        scale: 2,
        boundary: boundary,
      );
      final button = find.ancestor(
        of: find.text('확인'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(dismissed, isTrue);
      expect(tester.takeException(), isNull);
      await captureUi(
        tester,
        boundary,
        'today-milestone-${size.width.toInt()}x${size.height.toInt()}-200pct',
      );
    });
    testWidgets('저장 버튼 $size 200% 48dp와 완료 행동 도달', (tester) async {
      var saved = false;
      final boundary = GlobalKey();
      await mount(
        tester,
        _save(count: 1, canSave: true, onPressed: () => saved = true),
        AppTheme.light(),
        size: size,
        scale: 2,
        boundary: boundary,
      );
      final button = find.byType(ElevatedButton);
      await tester.ensureVisible(button);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(saved, isTrue);
      expect(tester.takeException(), isNull);
      await captureUi(
        tester,
        boundary,
        'today-save-${size.width.toInt()}x${size.height.toInt()}-200pct',
      );
    });
    testWidgets('완료 화면 $size 200% 마지막 문구가 닫기 뒤에 숨지 않는다', (tester) async {
      try {
        var dismissed = false;
        final boundary = GlobalKey();
        await mount(
          tester,
          CompletionAnimation(
            emotion: 2,
            streak: 1234,
            onComplete: () => dismissed = true,
          ),
          AppTheme.light(),
          size: size,
          scale: 2,
          completion: true,
          boundary: boundary,
        );
        expect(tester.takeException(), isNull);
        final button = find.byType(TextButton);
        final lastText = find.text('1234일 연속 기록 중');
        await tester.ensureVisible(lastText);
        expect(
          tester.getRect(lastText).bottom,
          lessThanOrEqualTo(tester.getRect(button).top),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        await captureUi(
          tester,
          boundary,
          'today-completion-${size.width.toInt()}x${size.height.toInt()}-200pct',
        );
        await tester.tap(button);
        expect(dismissed, isTrue);
      } finally {
        await drainCompletion(tester);
      }
    });
  }
}
