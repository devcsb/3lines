import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:three_lines/core/settings/settings_keys.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/onboarding/onboarding_screen.dart';

import '../../helpers/ui_render_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiRenderFonts);
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final scale in [1.0, 2.0]) {
      for (final reduced in [false, true]) {
        testWidgets('$size ${scale}x reduced=$reduced 각 페이지와 시작 도달', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          final settings = SettingsRepository(db);
          final router = GoRouter(
            initialLocation: '/onboarding',
            routes: [
              GoRoute(
                path: '/onboarding',
                builder: (_, _) => const OnboardingScreen(),
              ),
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('기록 시작')),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                settingsRepositoryProvider.overrideWithValue(settings),
              ],
              child: MaterialApp.router(
                theme: uiRenderTheme(AppTheme.light()),
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: reduced,
                  ),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (var page = 1; page <= 3; page++) {
            expect(find.text('$page / 3'), findsOneWidget);
            expect(tester.takeException(), isNull);
            final action = page == 3
                ? find.widgetWithText(ElevatedButton, '시작하기')
                : find.widgetWithText(OutlinedButton, '다음');
            expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
            if (page == 1) {
              expect(find.text('감정 하나와 답변 한 개부터 저장할 수 있어요'), findsOneWidget);
              expect(
                tester.getSize(find.widgetWithText(TextButton, '건너뛰기')).height,
                greaterThanOrEqualTo(48),
              );
            }
            if (reduced) {
              expect(
                tester
                    .widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
                    .duration,
                Duration.zero,
              );
            }
            await tester.ensureVisible(action);
            await tester.tap(action);
            if (page == 3) {
              await tester.runAsync(() async {
                await settings.getSetting(
                  SettingKeys.onboardingDone,
                  defaultValue: 'false',
                );
              });
            }
            await tester.pumpAndSettle();
          }
          expect(find.text('기록 시작'), findsOneWidget);
          expect(
            await settings.getSetting(
              SettingKeys.onboardingDone,
              defaultValue: 'false',
            ),
            'true',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
