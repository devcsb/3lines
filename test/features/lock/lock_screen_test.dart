import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/biometric_service.dart';
import 'package:three_lines/features/lock/lock_screen.dart';

/// 테스트용 BiometricService 구현체
class FakeBiometricService extends BiometricService {
  bool authenticateResult = true;
  int authenticateCallCount = 0;

  @override
  Future<bool> authenticate() async {
    authenticateCallCount++;
    return authenticateResult;
  }

  @override
  Future<bool> isAvailable() async => true;
}

void main() {
  group('biometricLockStateProvider', () {
    test('기본 초기값은 false이다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(biometricLockStateProvider), false);
    });

    test('overrideWith로 초기값을 true로 설정할 수 있다', () {
      final container = ProviderContainer(
        overrides: [
          biometricLockStateProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(biometricLockStateProvider), true);
    });

    test('인증 성공 후 false로 전환된다', () {
      final container = ProviderContainer(
        overrides: [
          biometricLockStateProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(biometricLockStateProvider), true);
      container.read(biometricLockStateProvider.notifier).state = false;
      expect(container.read(biometricLockStateProvider), false);
    });
  });

  group('LockScreen 위젯', () {
    late FakeBiometricService fakeBioService;

    setUp(() {
      fakeBioService = FakeBiometricService();
    });

    Widget createTestWidget({bool initialLocked = true}) {
      return ProviderScope(
        overrides: [
          biometricServiceProvider.overrideWithValue(fakeBioService),
          biometricLockStateProvider.overrideWith((ref) => initialLocked),
        ],
        child: const MaterialApp(
          home: LockScreen(),
        ),
      );
    }

    testWidgets('잠금 화면 UI 요소가 올바르게 표시된다', (tester) async {
      fakeBioService.authenticateResult = false; // 자동 인증 방지
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('3Lines'), findsOneWidget);
      expect(find.text('잠금을 해제해주세요'), findsOneWidget);
      expect(find.text('잠금 해제'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
    });

    testWidgets('initState에서 자동으로 인증을 시도한다', (tester) async {
      fakeBioService.authenticateResult = false;
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(fakeBioService.authenticateCallCount, 1);
    });

    testWidgets('인증 성공 시 biometricLockStateProvider가 false로 변경된다',
        (tester) async {
      fakeBioService.authenticateResult = true;
      late ProviderContainer container;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container = ProviderContainer(
            overrides: [
              biometricServiceProvider.overrideWithValue(fakeBioService),
              biometricLockStateProvider.overrideWith((ref) => true),
            ],
          ),
          child: const MaterialApp(home: LockScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(biometricLockStateProvider), false);
      container.dispose();
    });

    testWidgets('인증 취소 후 "잠금 해제" 버튼으로 재시도할 수 있다',
        (tester) async {
      fakeBioService.authenticateResult = false; // 첫 번째 인증 실패(취소)
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(fakeBioService.authenticateCallCount, 1);

      // 사용자가 "잠금 해제" 버튼을 탭하여 재시도
      fakeBioService.authenticateResult = true;
      await tester.tap(find.text('잠금 해제'));
      await tester.pumpAndSettle();

      expect(fakeBioService.authenticateCallCount, 2);
    });

    testWidgets('인증 중 중복 호출이 방지된다', (tester) async {
      fakeBioService.authenticateResult = false;
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 첫 번째 인증 완료 후 카운트 확인
      expect(fakeBioService.authenticateCallCount, 1);

      // 빠르게 연속 탭해도 중복 호출되지 않아야 한다
      await tester.tap(find.text('잠금 해제'));
      await tester.tap(find.text('잠금 해제'));
      await tester.pumpAndSettle();

      // 첫 번째(initState) + 버튼 탭 1회 = 2회 (중복 방지)
      expect(fakeBioService.authenticateCallCount, 2);
    });
  });
}
