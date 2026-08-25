import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/app.dart';
import 'package:three_lines/core/services/biometric_service.dart';
import 'package:three_lines/core/services/journal_side_effects.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/services/widget_sync_service.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';

import '../helpers/fake_biometric_service.dart';
import '../helpers/fake_photo_service.dart';
import '../helpers/fake_widget_sync.dart';

final class _NoOpJournalSideEffects implements JournalSideEffects {
  @override
  Future<void> onLaunch() async {}

  @override
  Future<void> onJournalChanged() async {}
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SettingsRepository(db).setSetting('onboarding_done', 'true');
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('앱은 시스템 200% 텍스트 배율을 제한하지 않는다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            journalSideEffectsProvider.overrideWithValue(
              _NoOpJournalSideEffects(),
            ),
            widgetSyncServiceProvider.overrideWithValue(FakeWidgetSync()),
            photoServiceProvider.overrideWithValue(FakePhotoService()),
            biometricServiceProvider.overrideWithValue(FakeBiometricService()),
          ],
          child: const ThreeLinesApp(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final scales = tester
        .widgetList<MediaQuery>(find.byType(MediaQuery))
        .map((query) => query.data.textScaler.scale(10))
        .toList();
    expect(scales, isNotEmpty);
    expect(scales, contains(20.0));
    expect(scales.where((scale) => (scale - 13).abs() < 0.001), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
