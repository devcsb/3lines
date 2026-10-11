import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/services/biometric_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with WidgetsBindingObserver {
  bool _authenticating = false;
  // 사용자가 인증을 취소한 경우 true. lifecycle resumed 이벤트로 자동 재시도 방지.
  bool _userCancelled = false;

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
    // 인증 중이거나 사용자가 취소한 경우 lifecycle 이벤트로 자동 재시도하지 않음
    if (state == AppLifecycleState.resumed &&
        !_authenticating &&
        !_userCancelled) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (!mounted || _authenticating) return;
    setState(() {
      _authenticating = true;
      _userCancelled = false;
    });
    try {
      final bioService = ref.read(biometricServiceProvider);
      final success = await bioService.authenticate();
      if (success && mounted) {
        ref.read(biometricLockStateProvider.notifier).state = false;
      } else if (!success && mounted) {
        // 인증 실패 또는 취소: 사용자가 명시적으로 버튼을 탭할 때까지 자동 재시도 안 함
        setState(() {
          _userCancelled = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _userCancelled = true);
    } finally {
      if (mounted) {
        setState(() {
          _authenticating = false;
        });
      } else {
        _authenticating = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Lock icon in circle
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 36,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('3Lines', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          '잠금을 해제해주세요',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (_userCancelled) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: const Text(
                              '기기 인증을 완료하지 못했어요. 기기 잠금 상태를 확인한 뒤 다시 시도해주세요.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 36),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _authenticating ? null : _authenticate,
                          icon: const Icon(Icons.fingerprint_rounded, size: 20),
                          label: const Text('잠금 해제'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the app is currently locked. Starts as true so that the home screen
/// is never exposed before biometricLockEnabledProvider resolves.
/// Set to false after successful authentication or when biometric lock is disabled.
final biometricLockStateProvider = StateProvider<bool>((ref) => true);
