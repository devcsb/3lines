import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/theme/app_theme.dart';

double contrast(Color foreground, Color background) {
  final composed = Color.alphaBlend(foreground, background);
  final a = composed.computeLuminance();
  final b = background.computeLuminance();
  return ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
}

void main() {
  for (final accent in AppTheme.accentSeeds.keys) {
    for (final dark in [false, true]) {
      test('$accent dark=$dark 안내와 조작 전경 대비', () {
        final theme = dark
            ? AppTheme.darkForAccent(accent)
            : AppTheme.lightForAccent(accent);
        final scheme = theme.colorScheme;
        final backgrounds = [
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.surfaceContainerHighest,
        ];
        for (final background in backgrounds) {
          expect(
            contrast(scheme.onSurfaceVariant, background),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(
          contrast(
            theme.inputDecorationTheme.hintStyle!.color!,
            scheme.surfaceContainerLow,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(
            theme.searchBarTheme.hintStyle!.resolve({})!.color!,
            scheme.surfaceContainerLow,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(
            theme.navigationBarTheme.labelTextStyle!.resolve({})!.color!,
            scheme.surface,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(
            theme.navigationBarTheme.iconTheme!.resolve({})!.color!,
            scheme.surface,
          ),
          greaterThanOrEqualTo(3),
        );
        expect(
          contrast(
            theme.segmentedButtonTheme.style!.foregroundColor!.resolve({})!,
            scheme.surface,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onSecondary, scheme.secondary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onTertiary, scheme.tertiary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          theme.segmentedButtonTheme.style!.minimumSize!.resolve({})!.height,
          greaterThanOrEqualTo(48),
        );
        expect(
          theme.textButtonTheme.style!.minimumSize!.resolve({})!.height,
          greaterThanOrEqualTo(48),
        );
      });
    }
  }
}
