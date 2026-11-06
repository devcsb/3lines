import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:three_lines/core/constants/default_prompts.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/features/onboarding/onboarding_screen.dart';
import 'package:three_lines/features/today/today_controller.dart';
import 'package:three_lines/features/today/today_screen.dart';
import 'package:three_lines/features/today/today_state.dart';
import 'package:three_lines/features/today/widgets/emotion_picker.dart';
import 'package:three_lines/features/today/widgets/prompt_suggestions.dart';

final class _WritingController extends TodayController {
  @override
  Future<TodayState> build() async =>
      const TodayState(prompts: defaultPromptQuestions);
}

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  test('기록 화면의 일반 텍스트와 선택된 감정은 양쪽 테마에서 4.5:1 대비를 갖는다', () {
    double contrast(Color a, Color b) {
      final first = a.computeLuminance();
      final second = b.computeLuminance();
      return first > second
          ? (first + 0.05) / (second + 0.05)
          : (second + 0.05) / (first + 0.05);
    }

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final colors = theme.colorScheme;
      for (final pair in [
        (colors.onSurfaceVariant, colors.surface),
        (colors.onSurfaceVariant, colors.surfaceContainerLow),
        (colors.onSurfaceVariant, colors.surfaceContainerLowest),
        (colors.onPrimaryContainer, colors.primaryContainer),
        (colors.onPrimary, colors.primary),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    }
  });

  for (final dark in [false, true]) {
    for (final size in [const Size(320, 568), const Size(740, 360)]) {
      testWidgets('큰 글자 Today 레이아웃 dark=$dark size=$size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todayControllerProvider.overrideWith(_WritingController.new),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: const TodayScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(TextField).last);
        await tester.enterText(find.byType(TextField).last, '오늘은 쉬고 싶다');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('오늘은 쉬고 싶다'), findsOneWidget);
        // Camera/gallery remain available after the writing fields.
        await tester.ensureVisible(find.text('카메라'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('온보딩은 작은 화면 200% 글자에서 세로로 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('짧아도, 길어도, 정리되지 않은 이야기여도 괜찮아요'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('감정 선택은 의미 있는 버튼과 48px 터치 영역을 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: EmotionPicker(onSelected: (value) => selected = value),
        ),
      ),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('감정 선택: 5단계 중 1 (힘듦)'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.text('힘듦'));
    expect(selected, 1);
    await tester.pump(const Duration(milliseconds: 300));
    semantics.dispose();
  });

  testWidgets('예시는 직접 펼쳐 선택하고 다시 접을 수 있다', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PromptSuggestions(
            promptIndex: 1,
            onTap: (value) => selected = value,
          ),
        ),
      ),
    );
    expect(find.text('지금은 지쳐 있다'), findsNothing);
    await tester.tap(find.text('시작이 어렵다면 예시 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지금은 지쳐 있다'));
    expect(selected, '지금은 지쳐 있다');
    await tester.tap(find.text('예시 접기'));
    await tester.pumpAndSettle();
    expect(find.text('지금은 지쳐 있다'), findsNothing);
  });
}
