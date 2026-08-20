import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:three_lines/app.dart';
import 'package:three_lines/core/services/biometric_service.dart';
import 'package:three_lines/core/services/journal_side_effects.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/services/widget_sync_service.dart';
import 'package:three_lines/data/database/app_database.dart';
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

/// 디바이스/에뮬레이터에서 실행하는 부팅 스모크.
///   flutter test integration_test/app_test.dart -d DEVICE_ID
/// (모바일 에뮬레이터/flutter drive 권장. macOS 데스크톱 라이브 바인딩은
/// pending-frame 불변식 quirk가 있어 부적합. 풀 e2e는 host에서 검증되는
/// test/integration/app_flow_test.dart 참조.)
/// 인메모리 DB + fake 서비스로 실제 ThreeLinesApp이 모든 업그레이드된 의존성
/// (riverpod 3, drift 2.34 네이티브 sqlite, fln 22 등)으로 실제 플랫폼에서
/// 부팅·렌더되는지 검증한다. 풀 작성 플로우는 test/integration/app_flow_test.dart 참조.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('온보딩 완료 상태에서 앱이 TodayScreen으로 부팅된다', (tester) async {
    // UI 폰트(Noto Sans)는 번들이라 런타임 fetch 가드가 필요 없다.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await SettingsRepository(db).setSetting('onboarding_done', 'true');
    addTearDown(() async => db.close());

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
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 신규 사용자(기록 0건, 스트릭 0)는 반복 애니메이션이 없어 settle된다.
    expect(find.text('오늘의 감정'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
