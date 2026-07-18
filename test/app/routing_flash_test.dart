import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/app.dart';
import 'package:three_lines/core/services/biometric_service.dart';
import 'package:three_lines/core/services/notification_service.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/lock/lock_screen.dart';
import 'package:three_lines/features/onboarding/onboarding_screen.dart';

import '../helpers/fake_biometric_service.dart';
import '../helpers/fake_notification_service.dart';
import '../helpers/fake_photo_service.dart';

/// 콜드스타트 첫 프레임에 FutureProvider 들이 AsyncLoading 인 동안
/// bootstrap 이 seed 한 초기값(initial*Provider)으로 올바르게 라우팅되어
/// 복귀 사용자가 온보딩/락 화면 flash 를 겪지 않는지 검증한다.
void main() {
  testWidgets('로딩 중이어도 온보딩 완료 초기값이 true 면 온보딩 화면이 안 뜬다',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await SettingsRepository(db).setSetting('onboarding_done', 'true');
    addTearDown(() async => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(FakeNotificationService()),
          photoServiceProvider.overrideWithValue(FakePhotoService()),
          biometricServiceProvider.overrideWithValue(FakeBiometricService()),
          // FutureProvider 들을 영구 로딩으로 만들어 콜드스타트 첫 프레임 window 재현
          onboardingDoneProvider.overrideWith((ref) => Completer<bool>().future),
          biometricLockEnabledProvider
              .overrideWith((ref) => Completer<bool>().future),
          // bootstrap 이 미리 읽어 seed 하는 초기값
          initialOnboardingDoneProvider.overrideWithValue(true),
          initialBiometricEnabledProvider.overrideWithValue(false),
        ],
        child: const ThreeLinesApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 온보딩이 아니라 메인 셸(하단 네비 존재)로 라우팅돼야 한다.
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('타임라인'), findsOneWidget);
  });

  testWidgets('락 사용자는 로딩 중에도 초기값 true 로 잠금 화면으로 라우팅된다',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await SettingsRepository(db).setSetting('onboarding_done', 'true');
    await SettingsRepository(db).setSetting('biometric_lock_enabled', 'true');
    addTearDown(() async => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(FakeNotificationService()),
          photoServiceProvider.overrideWithValue(FakePhotoService()),
          // 자동 인증 성공으로 락이 즉시 풀리지 않도록 인증 실패로 고정
          biometricServiceProvider
              .overrideWithValue(FakeBiometricService()..authResult = false),
          onboardingDoneProvider.overrideWith((ref) => Completer<bool>().future),
          biometricLockEnabledProvider
              .overrideWith((ref) => Completer<bool>().future),
          initialOnboardingDoneProvider.overrideWithValue(true),
          initialBiometricEnabledProvider.overrideWithValue(true),
        ],
        child: const ThreeLinesApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 잠금 상태(초기값 true + lockState 기본 true)라 잠금 화면으로 라우팅되고
    // 메인 셸/온보딩은 노출되지 않는다.
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('타임라인'), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
