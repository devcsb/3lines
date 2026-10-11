import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/onboarding/onboarding_screen.dart';

import '../../helpers/ui_render_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiRenderFonts);
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final dark in [false, true]) {
      testWidgets('한글 온보딩 $size dark=$dark 200% reduced motion 렌더', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(
                SettingsRepository(db),
              ),
            ],
            child: MaterialApp(
              theme: uiRenderTheme(dark ? AppTheme.dark() : AppTheme.light()),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: RepaintBoundary(
                key: boundary,
                child: const OnboardingScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var page = 1; page <= 3; page++) {
          expect(tester.takeException(), isNull);
          expect(find.text('$page / 3'), findsOneWidget);
          // Verify the last line is scroll-reachable before capturing it.
          final subtitle = find.text(switch (page) {
            1 => '감정 하나와 답변 한 개부터 저장할 수 있어요',
            2 => '기록한 날의 감정을 히트맵과 통계로 돌아봐요',
            _ => '자체 서버로 기록을 전송하지 않아요. 앱 삭제나 기기 분실에 대비해 텍스트 기록을 내보내세요',
          });
          await tester.ensureVisible(subtitle);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(subtitle).bottom,
            lessThanOrEqualTo(size.height),
          );
          if (Platform.environment['THREE_LINES_RENDER_UI'] == '1') {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final filename =
                  '/tmp/3lines-onboarding-${size.width.toInt()}x${size.height.toInt()}-${dark ? 'dark' : 'light'}-page$page-200pct.png';
              await File(filename).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (page < 3) {
            await tester.tap(find.widgetWithText(OutlinedButton, '다음'));
            await tester.pumpAndSettle();
          }
        }
      });
    }
  }
}
