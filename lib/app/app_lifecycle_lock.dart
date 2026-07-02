import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/lock/lock_screen.dart';
import 'router.dart';

class AppLifecycleLock extends ConsumerStatefulWidget {
  const AppLifecycleLock({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleLock> createState() => _AppLifecycleLockState();
}

class _AppLifecycleLockState extends ConsumerState<AppLifecycleLock>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }

    final lockEnabled = ref.read(biometricLockEnabledProvider).value ?? false;
    if (lockEnabled) {
      ref.read(biometricLockStateProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
