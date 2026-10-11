import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/constants/default_prompts.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/features/today/widgets/photo_attachment.dart';
import 'package:three_lines/features/today/widgets/prompt_card.dart';
import 'package:three_lines/features/today/widgets/prompt_suggestions.dart';

import '../../../helpers/ui_readability.dart';
import '../../../helpers/ui_render_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiRenderFonts);

  Future<void> mount(
    WidgetTester tester,
    Widget child,
    ThemeData theme, {
    double scale = 1,
    GlobalKey? boundary,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final accent in AppTheme.accentSeeds.keys) {
    for (final dark in [false, true]) {
      testWidgets('입력 카드와 사진 $accent dark=$dark 개별 색 대비', (tester) async {
        await mount(
          tester,
          Column(
            children: [
              for (var index = 0; index < 3; index++)
                PromptCard(
                  index: index,
                  question: defaultPromptQuestions[index],
                ),
              PromptSuggestions(
                promptIndex: 0,
                question: defaultPromptQuestions.first,
                onTap: (_) {},
              ),
              PromptCard(
                index: 0,
                question: defaultPromptQuestions.first,
                readOnly: true,
              ),
              PhotoAttachment(onPickCamera: () {}, onPickGallery: () {}),
            ],
          ),
          dark
              ? AppTheme.darkForAccent(accent)
              : AppTheme.lightForAccent(accent),
        );
        // Focus reveals the counter, which does not inherit the common token.
        await tester.ensureVisible(find.byType(TextField).first);
        await tester.showKeyboard(find.byType(TextField).first);
        await tester.pumpAndSettle();
        expectReadableText(tester);
        expectReadableIcons(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('입력 질문과 사진 추가 320px 200% 마지막 조작 도달', (tester) async {
    final boundary = GlobalKey();
    await mount(
      tester,
      Column(
        children: [
          PromptCard(index: 2, question: defaultPromptQuestions.last),
          PromptSuggestions(
            promptIndex: 2,
            question: defaultPromptQuestions.last,
            onTap: (_) {},
          ),
          PhotoAttachment(onPickCamera: () {}, onPickGallery: () {}),
        ],
      ),
      AppTheme.light(),
      scale: 2,
      boundary: boundary,
    );
    await tester.ensureVisible(find.text('갤러리'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in ['카메라', '갤러리']) {
      final target = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      );
      expect(target, findsOneWidget);
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
    }
    await captureUi(tester, boundary, 'writing-photo-320x640-200pct');
  });

  testWidgets('사진 실패 안내 320px 200% 실제 errorBuilder 대비와 잘림', (tester) async {
    final boundary = GlobalKey();
    await mount(
      tester,
      Builder(
        builder: (context) {
          // Only a designated missing fixture path, never a user's photo.
          const photo = PhotoAttachment(photoPath: '/tmp/r6-missing-photo.png');
          return photo;
        },
      ),
      AppTheme.dark(),
      scale: 2,
      boundary: boundary,
    );
    final image = tester.widget<Image>(find.byType(Image));
    final context = tester.element(find.byType(Image));
    final error = image.errorBuilder!(context, StateError('fixture'), null);
    await mount(tester, error, AppTheme.dark(), scale: 2, boundary: boundary);
    expectReadableText(tester);
    final text = find.text('사진을 불러올 수 없어요');
    expect(text, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
    expect(
      paragraph.computeMaxIntrinsicHeight(paragraph.size.width),
      lessThanOrEqualTo(paragraph.size.height),
    );
    expect(tester.takeException(), isNull);
    await captureUi(tester, boundary, 'writing-photo-error-320x640-200pct');
  });

  testWidgets('사진 제거 native48dp를 큰 글씨 화면에서도 유지한다', (tester) async {
    await mount(
      tester,
      PhotoAttachment(photoPath: '/tmp/r6-missing-photo.png', onRemove: () {}),
      AppTheme.light(),
      scale: 2,
    );
    final target = find.byType(IconButton);
    expect(target, findsOneWidget);
    expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
  });
}
