import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/app/app_lifecycle_lock.dart';
import 'package:three_lines/app/router.dart';
import 'package:three_lines/features/lock/lock_screen.dart';

void main() {
  testWidgets('biometric lock is armed when app moves to background', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        biometricLockEnabledProvider.overrideWith((_) async => true),
        biometricLockStateProvider.overrideWith((_) => false),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppLifecycleLock(child: SizedBox.shrink()),
      ),
    );
    await container.read(biometricLockEnabledProvider.future);
    await tester.pump();

    expect(container.read(biometricLockStateProvider), isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(container.read(biometricLockStateProvider), isTrue);
  });

  testWidgets('biometric lock stays unchanged when lock is disabled', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        biometricLockEnabledProvider.overrideWith((_) async => false),
        biometricLockStateProvider.overrideWith((_) => false),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppLifecycleLock(child: SizedBox.shrink()),
      ),
    );
    await container.read(biometricLockEnabledProvider.future);
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(container.read(biometricLockStateProvider), isFalse);
  });
}
