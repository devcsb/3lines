import 'package:drift/native.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:three_lines/app.dart';
import 'package:three_lines/core/services/biometric_service.dart';
import 'package:three_lines/core/services/journal_side_effects.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/services/widget_sync_service.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';

import '../test/helpers/fake_biometric_service.dart';
import '../test/helpers/fake_photo_service.dart';
import '../test/helpers/fake_widget_sync.dart';

final class NoOpJournalSideEffects implements JournalSideEffects {
  @override
  Future<void> onLaunch() async {}

  @override
  Future<void> onJournalChanged() async {}
}

/// 다크모드/온보딩/빈상태/편집모드 등 부가 화면 상태 스크린샷.
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshot_states.dart -d DEVICE_ID
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> convert() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await binding.convertFlutterSurfaceToImage();
    }
  }

  Future<void> seed(EntryRepository entries, {int days = 30}) async {
    const a1 = [
      '따뜻한 커피 한 잔',
      '가족과의 저녁 식사',
      '맑은 가을 날씨',
      '오래된 좋은 책',
      '저녁 산책',
      '친구의 응원',
    ];
    const a2 = ['조급함을 내려놓았다', '작은 실수를 받아들였다', '쉬어가도 괜찮다', '불안을 마주했다'];
    const a3 = ['일찍 일어나기', '가벼운 운동 30분', '감사 일기 한 줄', '고마운 사람에게 연락'];
    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      if (i % 7 == 5) continue;
      final d = now.subtract(Duration(days: i));
      await entries.saveEntry(
        DailyEntry(
          date: du.dateToString(d),
          emotion: 1 + ((i * 3 + 2) % 5),
          prompt1: '오늘 감사한 작은 것 하나는?',
          answer1: a1[i % a1.length],
          prompt2: '오늘 받아들인 것은?',
          answer2: a2[i % a2.length],
          prompt3: '내일의 작은 다짐은?',
          answer3: a3[i % a3.length],
        ),
      );
    }
  }

  Widget appWith(AppDatabase db) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      journalSideEffectsProvider.overrideWithValue(NoOpJournalSideEffects()),
      widgetSyncServiceProvider.overrideWithValue(FakeWidgetSync()),
      photoServiceProvider.overrideWithValue(FakePhotoService()),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
    ],
    child: const ThreeLinesApp(),
  );

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('다크모드 화면', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await SettingsRepository(db).setSetting('onboarding_done', 'true');
    await SettingsRepository(db).setSetting('theme_mode', 'dark');
    await seed(EntryRepository(db), days: 40);

    await tester.pumpWidget(appWith(db));
    await settle(tester, frames: 18);
    await convert();

    await binding.takeScreenshot('dark_01_today');
    await tester.tap(find.text('타임라인'));
    await settle(tester);
    await binding.takeScreenshot('dark_02_timeline');
    await tester.tap(find.text('인사이트'));
    await settle(tester);
    await binding.takeScreenshot('dark_03_insights');
    await tester.tap(find.text('설정'));
    await settle(tester);
    await binding.takeScreenshot('dark_04_settings');
    await teardown(tester);
  });

  testWidgets('온보딩', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    // onboarding_done 미설정 → 온보딩으로 라우팅
    await tester.pumpWidget(appWith(db));
    await settle(tester, frames: 18);
    await convert();
    await binding.takeScreenshot('onboarding_01');
    await teardown(tester);
  });

  testWidgets('빈 상태', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await SettingsRepository(db).setSetting('onboarding_done', 'true');
    await tester.pumpWidget(appWith(db));
    await settle(tester, frames: 16);
    await convert();
    await binding.takeScreenshot('empty_01_today');
    await tester.tap(find.text('타임라인'));
    await settle(tester);
    await binding.takeScreenshot('empty_02_timeline');
    await tester.tap(find.text('인사이트'));
    await settle(tester);
    await binding.takeScreenshot('empty_03_insights_locked');
    await teardown(tester);
  });

  testWidgets('편집 모드', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await SettingsRepository(db).setSetting('onboarding_done', 'true');
    await seed(EntryRepository(db), days: 5); // today 포함 → read mode
    await tester.pumpWidget(appWith(db));
    await settle(tester, frames: 18);
    await convert();
    final editBtn = find.text('수정하기');
    if (editBtn.evaluate().isNotEmpty) {
      await tester.tap(editBtn);
      await settle(tester);
    }
    await binding.takeScreenshot('edit_01_today');
    await teardown(tester);
  });
}
