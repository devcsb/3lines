import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/features/today/widgets/emotion_picker.dart';

import '../../../helpers/ui_readability.dart';
import '../../../helpers/ui_render_fonts.dart';

const _labels = ['힘듦', '불안', '보통', '평온', '감사'];
const _icons = [
  Icons.sentiment_very_dissatisfied_rounded,
  Icons.sentiment_dissatisfied_rounded,
  Icons.sentiment_neutral_rounded,
  Icons.sentiment_satisfied_alt_rounded,
  Icons.sentiment_very_satisfied_rounded,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiRenderFonts);

  Future<void> mount(
    WidgetTester tester,
    Widget child,
    ThemeData theme, {
    Size size = const Size(320, 640),
    double scale = 1,
    GlobalKey? boundary,
  }) async {
    await tester.pumpWidget(const SizedBox());
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
      final theme = dark
          ? AppTheme.darkForAccent(accent)
          : AppTheme.lightForAccent(accent);
      testWidgets('감정 $accent dark=$dark 선택1~5 아이콘 fill 대비', (tester) async {
        for (var value = 1; value <= 5; value++) {
          await mount(
            tester,
            EmotionPicker(selectedEmotion: value, onSelected: (_) {}),
            theme,
          );
          final iconFinder = find.byIcon(_icons[value - 1]);
          final icon = tester.widget<Icon>(iconFinder);
          final decoration =
              tester
                      .widget<AnimatedContainer>(
                        find
                            .ancestor(
                              of: iconFinder,
                              matching: find.byType(AnimatedContainer),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          final background = Color.alphaBlend(
            decoration.color!,
            theme.colorScheme.surface,
          );
          final foreground = Color.alphaBlend(icon.color!, background);
          final luminances = [
            foreground.computeLuminance(),
            background.computeLuminance(),
          ]..sort();
          expect(
            (luminances.last + .05) / (luminances.first + .05),
            greaterThanOrEqualTo(3),
            reason: '선택 감정$value 실제 fill 위의 icon',
          );
          final markerFinder = find.byIcon(Icons.check_rounded);
          expect(markerFinder, findsOneWidget);
          final marker = tester.widget<Icon>(markerFinder);
          final markerDecoration =
              tester
                      .widget<DecoratedBox>(
                        find
                            .ancestor(
                              of: markerFinder,
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          final markerLuminances = [
            marker.color!.computeLuminance(),
            markerDecoration.color!.computeLuminance(),
          ]..sort();
          expect(
            (markerLuminances.last + .05) / (markerLuminances.first + .05),
            greaterThanOrEqualTo(3),
          );
        }
      });
      testWidgets('감정 $accent dark=$dark 모든 안내와 비선택 아이콘 대비', (tester) async {
        await mount(tester, EmotionPicker(onSelected: (_) {}), theme);
        expectReadableText(tester);
        expectReadableIcons(tester);
      });
    }
  }

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('감정 $size 200% native48dp와 색외 선택 표시 및 라벨 도달', (tester) async {
      var selected = 3;
      final boundary = GlobalKey();
      await mount(
        tester,
        EmotionPicker(onSelected: (_) {}),
        AppTheme.light(),
        size: size,
      );
      for (final label in _labels) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        );
        expect(button, findsOneWidget);
        expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) => EmotionPicker(
            selectedEmotion: selected,
            onSelected: (value) => setState(() => selected = value),
          ),
        ),
        AppTheme.light(),
        size: size,
        scale: 2,
        boundary: boundary,
      );
      expect(tester.takeException(), isNull);
      for (var index = 0; index < _labels.length; index++) {
        final label = find.text(_labels[index]);
        final button = find.ancestor(
          of: label,
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        );
        expect(button, findsOneWidget);
        await tester.ensureVisible(button);
        expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(
          paragraph.getMaxIntrinsicHeight(tester.getSize(label).width),
          lessThanOrEqualTo(tester.getSize(label).height),
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(selected, index + 1);
        final node = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label?.startsWith(
                    '감정 선택: 5단계 중 ${index + 1}',
                  ) ==
                  true,
        );
        expect(tester.widget<Semantics>(node).properties.selected, isTrue);
        expect(
          find.descendant(
            of: button,
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await captureUi(
        tester,
        boundary,
        'emotion-${size.width.toInt()}x${size.height.toInt()}-200pct',
      );
    });
  }
}
