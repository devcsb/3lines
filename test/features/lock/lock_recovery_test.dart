import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/biometric_service.dart';
import 'package:three_lines/features/lock/lock_screen.dart';

class _RecoverableAuthentication extends BiometricService {
  bool throws = false;
  bool succeeds = false;

  @override
  Future<bool> authenticate() async {
    if (throws) throw StateError('device authentication unavailable');
    return succeeds;
  }
}

void main() {
  testWidgets('기기 인증 예외에도 잠금을 유지하고 버튼으로 재시도한다', (tester) async {
    final service = _RecoverableAuthentication()..throws = true;
    final container = ProviderContainer(
      overrides: [biometricServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LockScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(container.read(biometricLockStateProvider), isTrue);
    expect(find.textContaining('다시'), findsWidgets);
    service
      ..throws = false
      ..succeeds = true;
    await tester.tap(find.text('잠금 해제'));
    await tester.pumpAndSettle();
    expect(container.read(biometricLockStateProvider), isFalse);
  });

  testWidgets('인증 취소 뒤 작은 화면과 200% 글씨에서도 재시도 안내와 버튼에 도달한다', (tester) async {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _RecoverableAuthentication();
    final container = ProviderContainer(
      overrides: [biometricServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const LockScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(container.read(biometricLockStateProvider), isTrue);
    expect(find.textContaining('다시'), findsWidgets);
    await tester.ensureVisible(find.text('잠금 해제'));
    service.succeeds = true;
    await tester.tap(find.text('잠금 해제'));
    await tester.pumpAndSettle();
    expect(container.read(biometricLockStateProvider), isFalse);
  });
}
