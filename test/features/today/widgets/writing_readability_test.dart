import 'dart:async';

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

  Future<void> resolvePhoto(WidgetTester tester) async {
    // The initial load began in fake time; restart it in the real IO zone.
    await tester.runAsync(() async {
      final provider = tester.widget<Image>(find.byType(Image)).image;
      await provider.evict();
      final stream = provider.resolve(const ImageConfiguration());
      final done = Completer<void>();
      final listener = ImageStreamListener((info, _) {
        info.dispose();
        done.complete();
      }, onError: (Object _, StackTrace? _) => done.complete());
      stream.addListener(listener);
      try {
        await done.future;
      } finally {
        stream.removeListener(listener);
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('사진 실패 안내 320px 200% 제거 버튼과 겹치지 않고 읽힌다', (tester) async {
    for (final readOnly in [false, true]) {
      final boundary = GlobalKey();
      await mount(
        tester,
        PhotoAttachment(
          photoPath: '/tmp/r6-missing-photo.png',
          readOnly: readOnly,
          onRemove: () {},
        ),
        AppTheme.dark(),
        scale: 2,
        boundary: boundary,
      );
      await resolvePhoto(tester);
      expectReadableText(tester);
      final text = find.text('사진을 불러올 수 없어요');
      expect(text, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      await captureUi(
        tester,
        boundary,
        'writing-photo-error-${readOnly ? 'readonly' : 'removable'}-320x640-200pct',
      );
      if (readOnly) {
        expect(find.byType(IconButton), findsNothing);
        expect(paragraph.size.width, 256);
      } else {
        final remove = tester.getRect(find.byType(IconButton));
        final content = tester.widget<Text>(text).data!;
        for (final box in paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: content.length),
        )) {
          final glyphs = Rect.fromPoints(
            paragraph.localToGlobal(Offset(box.left, box.top)),
            paragraph.localToGlobal(Offset(box.right, box.bottom)),
          );
          expect(
            glyphs.overlaps(remove),
            isFalse,
            reason: 'glyphs=$glyphs remove=$remove',
          );
        }
      }
      expect(
        paragraph.computeMaxIntrinsicHeight(paragraph.size.width),
        lessThanOrEqualTo(paragraph.size.height),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('사진 제거 native48dp를 큰 글씨 화면에서도 유지한다', (tester) async {
    var removed = false;
    await mount(
      tester,
      PhotoAttachment(
        photoPath: 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
        onRemove: () => removed = true,
      ),
      AppTheme.light(),
      scale: 2,
    );
    await resolvePhoto(tester);
    expect(find.text('사진을 불러올 수 없어요'), findsNothing);
    expect(tester.getSize(find.byType(Image)).height, 180);
    final target = find.byType(IconButton);
    expect(target, findsOneWidget);
    expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    await tester.tap(target);
    expect(removed, isTrue);
  });
}
