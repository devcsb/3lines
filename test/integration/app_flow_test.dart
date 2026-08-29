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
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';

import '../helpers/fake_biometric_service.dart';
import '../helpers/fake_photo_service.dart';
import '../helpers/fake_widget_sync.dart';

final class NoOpJournalSideEffects implements JournalSideEffects {
  @override
  Future<void> onLaunch() async {}

  @override
  Future<void> onJournalChanged() async {}
}

/// 풀스택 플로우 테스트: 실제 ThreeLinesApp 위젯 트리를 인메모리 DB + fake로
/// 구동해 UI→controller→repository→DB 경로를 호스트(flutter test)에서 검증한다.
/// 반복 애니메이션(streak pulse 등)이 있어 pumpAndSettle 대신 bounded pump 사용.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await SettingsRepository(db).setSetting('onboarding_done', 'true');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          journalSideEffectsProvider.overrideWithValue(
            NoOpJournalSideEffects(),
          ),
          widgetSyncServiceProvider.overrideWithValue(FakeWidgetSync()),
          photoServiceProvider.overrideWithValue(FakePhotoService()),
          biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        ],
        child: const ThreeLinesApp(),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // ThreeLinesApp을 제거해 provider(특히 TodayController의 자정 Timer)를
  // dispose하고, 남은 fake 타이머를 모두 소진해 pending-timer 불변식을 만족시킨다.
  Future<void> teardownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('핵심 루프: 감정 선택→답변 작성→저장→전체 스택 영속', (tester) async {
    await pumpApp(tester);

    expect(find.text('오늘의 감정'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.sentiment_satisfied_alt_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    final fields = find.byType(TextField);
    expect(fields, findsWidgets);
    await tester.enterText(fields.first, '오늘 감사한 일');
    await tester.pump(const Duration(milliseconds: 200));

    final saveBtn = find.widgetWithText(ElevatedButton, '기록 완료');
    expect(saveBtn, findsOneWidget);
    await tester.ensureVisible(saveBtn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(saveBtn);
    // 저장(async) 완료 + 완료 애니메이션 타이머(400ms+2500ms) 소진까지 advance.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 4));

    final saved = await EntryRepository(db).getTodayEntry();
    expect(saved, isNotNull);
    expect(saved!.emotion, 4);
    expect(saved.answer1, '오늘 감사한 일');

    await teardownApp(tester);
  });
}
