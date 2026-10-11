import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

List<Color> _backgrounds(Element element, Color surface) {
  final layers = <List<Color>>[];
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
      final decoration = widget.decoration as BoxDecoration;
      if (decoration.gradient != null) {
        layers.add(decoration.gradient!.colors);
      } else if (decoration.color != null) {
        layers.add([decoration.color!]);
      }
    } else if (widget is Material && widget.color != null) {
      layers.add([widget.color!]);
    } else if (widget is ColoredBox) {
      layers.add([widget.color]);
    }
    return true;
  });
  var results = [surface];
  for (final layer in layers.reversed) {
    results = [
      for (final base in results)
        for (final color in layer) Color.alphaBlend(color, base),
    ];
  }
  return results;
}

double _contrast(Color foreground, Color background) {
  final luminance = Color.alphaBlend(foreground, background).computeLuminance();
  final base = background.computeLuminance();
  return ((luminance > base ? luminance : base) + .05) /
      ((luminance > base ? base : luminance) + .05);
}

/// Checks the actual rendered paragraphs, including each composed gradient end.
void expectReadableText(WidgetTester tester) {
  for (final element in find.byType(Text).evaluate()) {
    final text = element.widget as Text;
    if (text.data == null || text.data!.isEmpty) continue;
    var disabled = false;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is ButtonStyleButton && widget.onPressed == null) {
        disabled = true;
      }
      return true;
    });
    if (disabled) continue;
    final richText = find.descendant(
      of: find.byWidget(text),
      matching: find.byType(RichText),
    );
    if (richText.evaluate().isEmpty) continue;
    final paragraph = tester.renderObject<RenderParagraph>(richText.first);
    final foreground = paragraph.text.style?.color;
    if (foreground == null) continue;
    final surface = Theme.of(element).colorScheme.surface;
    for (final background in _backgrounds(element, surface)) {
      expect(
        _contrast(foreground, background),
        greaterThanOrEqualTo(4.5),
        reason: '"${text.data}" foreground=$foreground background=$background',
      );
    }
  }
}

void expectReadableIcons(WidgetTester tester) {
  for (final element in find.byType(Icon).evaluate()) {
    var excluded = false;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is ExcludeSemantics && widget.excluding) excluded = true;
      if (widget is IconButton && widget.onPressed == null) excluded = true;
      return true;
    });
    if (excluded) continue;
    final icon = element.widget as Icon;
    final foreground = icon.color ?? IconTheme.of(element).color;
    if (foreground == null) continue;
    for (final background in _backgrounds(
      element,
      Theme.of(element).colorScheme.surface,
    )) {
      expect(
        _contrast(foreground, background),
        greaterThanOrEqualTo(3),
        reason: '${icon.icon} foreground=$foreground background=$background',
      );
    }
  }
}

Future<void> captureUi(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  if (Platform.environment['THREE_LINES_RENDER_UI'] != '1') return;
  // ensureVisible changes the scroll offset before the next paint.
  await tester.pump();
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/tmp/3lines-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
