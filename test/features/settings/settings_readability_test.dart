import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/constants/default_prompts.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/core/theme/theme_notifier.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/settings/settings_controller.dart';
import 'package:three_lines/features/settings/settings_screen.dart';
import 'package:three_lines/features/settings/settings_state.dart';

import '../../helpers/ui_readability.dart';
import '../../helpers/ui_render_fonts.dart';

class _SettingsFixture extends SettingsController {
  @override
  Future<SettingsState> build() async => const SettingsState(
    prompts: defaultPromptQuestions,
    appVersion: '1.0.0',
    reminderEnabled: true,
  );
}

class _AccentFixture extends AccentThemeNotifier {
  int activations = 0;
  @override
  Future<String> build() async => 'sage';
  @override
  Future<void> setAccent(String accent) async {
    activations++;
    state = AsyncData(accent);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiRenderFonts);
  for (final dark in [false, true]) {
    testWidgets('전체 설정 dark=$dark 320px 200% 섹션과 마지막 안내 도달', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = EntryRepository(db);
      final boundary = GlobalKey();
      final accent = _AccentFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsControllerProvider.overrideWith(_SettingsFixture.new),
            accentThemeProvider.overrideWith(() => accent),
            settingsRepositoryProvider.overrideWithValue(
              SettingsRepository(db),
            ),
            entryRepositoryProvider.overrideWithValue(repository),
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
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(repository.getTotalCount);
      await tester.pumpAndSettle();
      // Inspect each section in the full lazy ListView, not isolated widgets.
      for (final label in [
        '질문 설정',
        '알림',
        '보안',
        '외관',
        '홈 화면 위젯',
        '데이터',
        '오픈소스 라이선스',
      ]) {
        await tester.scrollUntilVisible(find.text(label), 160);
        await tester.pumpAndSettle();
        if (label == '외관') {
          final selected = find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == '기본 (Sage) 테마',
          );
          final native = find.descendant(
            of: selected,
            matching: find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton || widget is ChoiceChip,
            ),
          );
          expect(native, findsOneWidget);
          await tester.ensureVisible(native);
          await tester.pump();
          expect(tester.getSize(native).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(native).height, greaterThanOrEqualTo(48));
          final label = find
              .descendant(of: native, matching: find.byType(Text))
              .first;
          Focus.of(tester.element(label)).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(accent.activations, 1);
          await captureUi(
            tester,
            boundary,
            'settings-appearance-${dark ? 'dark' : 'light'}-320x640-200pct',
          );
        }
        expect(tester.takeException(), isNull, reason: label);
        expectReadableText(tester);
        expectReadableIcons(tester);
      }
      expect(
        tester.getRect(find.text('오픈소스 라이선스')).bottom,
        lessThanOrEqualTo(640),
      );
      await captureUi(
        tester,
        boundary,
        'settings-full-${dark ? 'dark' : 'light'}-320x640-200pct',
      );
    });
  }
}
