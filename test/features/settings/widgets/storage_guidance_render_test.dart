import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/settings/widgets/data_section.dart';
import 'package:three_lines/features/settings/widgets/info_section.dart';
import 'package:three_lines/features/settings/widgets/security_section.dart';

import '../../../helpers/ui_render_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiRenderFonts);
  for (final dark in [false, true]) {
    testWidgets('한글 보관 안내 dark=$dark 320x640 200% 렌더', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PackageInfo.setMockInitialValues(
        appName: '3Lines',
        packageName: 'test.3lines',
        version: '1.0',
        buildNumber: '1',
        buildSignature: 'test',
      );
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = EntryRepository(db);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryRepositoryProvider.overrideWithValue(repo),
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
              child: const Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        DataSection(),
                        SecuritySection(biometricLockEnabled: false),
                        InfoSection(appVersion: '1.0'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(repo.getTotalCount);
      await tester.pumpAndSettle();
      for (final (name, label) in [
        ('data', '텍스트 기록 내보내기 (JSON)'),
        ('security', '앱 잠금'),
        ('info', '3Lines는 기록을 자체 서버로 전송하지 않아요. 운영체제 설정에 따라 앱 데이터가 백업될 수 있어요'),
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (Platform.environment['THREE_LINES_RENDER_UI'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/3lines-storage-${dark ? 'dark' : 'light'}-$name-200pct.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    });
  }
}
