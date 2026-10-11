import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Use the app's Latin font and a real Korean fallback, not the Ahem test font.
Future<void> loadUiRenderFonts() async {
  final latin = FontLoader('NotoSans')
    ..addFont(rootBundle.load('assets/fonts/NotoSans-Variable.ttf'));
  final korean = FontLoader('UiRenderKorean');
  final host = File('/System/Library/Fonts/AppleSDGothicNeo.ttc');
  korean.addFont(
    host.existsSync()
        ? host.readAsBytes().then((bytes) => ByteData.sublistView(bytes))
        : rootBundle.load('assets/fonts/NanumMyeongjo-Regular.ttf'),
  );
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([latin.load(), korean.load(), icons.load()]);
}

ThemeData uiRenderTheme(ThemeData theme) {
  ButtonStyle korean(ButtonStyle style) => style.copyWith(
    textStyle: WidgetStatePropertyAll(
      style.textStyle!
          .resolve({})!
          .copyWith(fontFamilyFallback: const ['UiRenderKorean']),
    ),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(
      fontFamilyFallback: const ['UiRenderKorean'],
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: korean(theme.elevatedButtonTheme.style!),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: korean(theme.outlinedButtonTheme.style!),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: korean(theme.filledButtonTheme.style!),
    ),
    textButtonTheme: TextButtonThemeData(
      style: korean(theme.textButtonTheme.style!),
    ),
  );
}
