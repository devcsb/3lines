import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/biometric_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with WidgetsBindingObserver {
  bool _authenticating = false;

  /// 사용자가 실제로 앱을 백그라운드로 보냈는지 추적한다.
  /// 생체인증 시스템 다이얼로그로 인한 lifecycle 전환과 구분하기 위해 사용한다.
  bool _didGoToBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 인증 다이얼로그가 떠 있는 동안의 paused는 무시하고,
      // 사용자가 직접 앱을 백그라운드로 보낸 경우만 기록한다.
      if (!_authenticating) {
        _didGoToBackground = true;
      }
    }
    if (state == AppLifecycleState.resumed && _didGoToBackground) {
      _didGoToBackground = false;
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    try {
      final bioService = ref.read(biometricServiceProvider);
      final success = await bioService.authenticate();
      if (success && mounted) {
        ref.read(biometricLockStateProvider.notifier).state = false;
      }
    } finally {
      _authenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon in circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline_rounded,
                  size: 36,
                  color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text('3Lines',
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('잠금을 해제해주세요',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                )),
            const SizedBox(height: 36),
            FilledButton.icon(
              onPressed: _authenticate,
              icon: const Icon(Icons.fingerprint_rounded, size: 20),
              label: const Text('잠금 해제'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether the app is currently locked. Set to true on app start when biometric
/// lock is enabled; set to false after successful authentication.
final biometricLockStateProvider = StateProvider<bool>((ref) => false);
