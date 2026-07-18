import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:three_lines/app.dart';
import 'package:three_lines/core/services/biometric_service.dart';
import 'package:three_lines/core/services/notification_service.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';

import '../test/helpers/fake_biometric_service.dart';
import '../test/helpers/fake_notification_service.dart';
import '../test/helpers/fake_photo_service.dart';

/// 시드된 데이터로 실제 기기(시뮬레이터)에서 각 화면을 렌더해 스크린샷을 남긴다.
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshot_tour.dart -d DEVICE_ID
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('화면 투어 스크린샷', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsRepository(db);
    final entries = EntryRepository(db);
    await settings.setSetting('onboarding_done', 'true');

    // 최근 40일 다양한 감정/답변 시드(일부 날짜는 비워 히트맵/추이에 gap 표현).
    const a1 = ['따뜻한 커피 한 잔', '가족과의 저녁 식사', '맑은 가을 날씨', '오래된 좋은 책', '저녁 산책', '친구의 응원 한마디'];
    const a2 = ['조급함을 조금 내려놓았다', '작은 실수를 받아들였다', '쉬어가도 괜찮다고 느꼈다', '불안한 마음을 마주했다'];
    const a3 = ['내일은 일찍 일어나기', '가벼운 운동 30분', '감사 일기 한 줄 더', '고마운 사람에게 연락'];
    final now = DateTime.now();
    for (var i = 0; i < 40; i++) {
      if (i % 7 == 5) continue; // gap
      final d = now.subtract(Duration(days: i));
      final emotion = 1 + ((i * 3 + 2) % 5);
      await entries.saveEntry(
        DailyEntry(
          date: du.dateToString(d),
          emotion: emotion,
          prompt1: '오늘 감사한 작은 것 하나는?',
          answer1: a1[i % a1.length],
          prompt2: '오늘 받아들인 것은 무엇인가요?',
          answer2: a2[i % a2.length],
          prompt3: '내일의 작은 다짐은?',
          answer3: a3[i % a3.length],
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(FakeNotificationService()),
          photoServiceProvider.overrideWithValue(FakePhotoService()),
          biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        ],
        child: const ThreeLinesApp(),
      ),
    );
    await settle(tester, frames: 18);
    await binding.convertFlutterSurfaceToImage();

    // 1) 오늘 (기록 완료 상태 — read mode)
    await settle(tester, frames: 4);
    await binding.takeScreenshot('01_today');

    // 2) 타임라인 (히트맵)
    await tester.tap(find.text('타임라인'));
    await settle(tester);
    await binding.takeScreenshot('02_timeline');

    // 3) 인사이트 (차트/통계)
    await tester.tap(find.text('인사이트'));
    await settle(tester);
    await binding.takeScreenshot('03_insights_top');

    // 인사이트 스크롤 하단
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await settle(tester);
    await binding.takeScreenshot('04_insights_scrolled');

    // 4) 설정
    await tester.tap(find.text('설정'));
    await settle(tester);
    await binding.takeScreenshot('05_settings');

    // 앱을 트리에서 제거해 provider/타이머(자정 타이머, 펄스 애니메이션)를
    // dispose 하고 남은 타이머를 소진해 클린하게 종료한다.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
