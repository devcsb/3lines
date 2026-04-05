import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'data/repositories/settings_repository.dart';
import 'features/insights/insights_screen.dart';
import 'features/lock/lock_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/timeline/timeline_screen.dart';
import 'features/today/today_screen.dart';
import 'shared/widgets/app_bottom_nav.dart';

final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.isOnboardingDone();
});

final biometricLockEnabledProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.isBiometricLockEnabled();
});

/// Listenable that notifies GoRouter when onboarding or lock status changes.
class _RouterNotifier extends ChangeNotifier {
  bool _onboardingDone = false;
  bool get onboardingDone => _onboardingDone;
  set onboardingDone(bool value) {
    if (_onboardingDone != value) {
      _onboardingDone = value;
      notifyListeners();
    }
  }

  bool _locked = false;
  bool get locked => _locked;
  set locked(bool value) {
    if (_locked != value) {
      _locked = value;
      notifyListeners();
    }
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier();
  ref.onDispose(() => notifier.dispose());

  // Listen (not watch) so the router is created once and refreshed via notifier
  ref.listen(onboardingDoneProvider, (_, next) {
    notifier.onboardingDone = next.valueOrNull ?? false;
  });

  ref.listen(biometricLockEnabledProvider, (_, next) {
    if (next is AsyncLoading) {
      // 로딩 중에는 잠금 상태 유지 (홈 화면 노출 방지)
      notifier.locked = true;
      return;
    }
    final enabled = next.valueOrNull ?? false;
    if (enabled) {
      // 앱 시작 시 잠금 복원은 biometricLockStateProvider 초기값(true)으로 처리하므로,
      // 여기서는 현재 잠금 상태만 라우터에 반영한다.
      // 설정에서 활성화한 직후에는 biometricLockStateProvider가 false이므로
      // 사용자가 즉시 잠금 화면으로 튕기지 않는다.
      notifier.locked = ref.read(biometricLockStateProvider);
    } else {
      // biometric lock이 비활성화된 경우 잠금 해제
      ref.read(biometricLockStateProvider.notifier).state = false;
      notifier.locked = false;
    }
  });

  ref.listen(biometricLockStateProvider, (_, locked) {
    notifier.locked = locked;
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      if (!notifier.onboardingDone && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }
      if (notifier.onboardingDone && state.matchedLocation == '/onboarding') {
        return notifier.locked ? '/lock' : '/';
      }
      if (notifier.onboardingDone && notifier.locked && state.matchedLocation != '/lock') {
        return '/lock';
      }
      if (notifier.onboardingDone && !notifier.locked && state.matchedLocation == '/lock') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, __) => CustomTransitionPage(
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved =
                CurvedAnimation(parent: animation, curve: Curves.easeInOut);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: '/lock',
        builder: (_, __) => const LockScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            ScaffoldWithNavBar(navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/', builder: (_, __) => const TodayScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/timeline',
                builder: (_, __) => const TimelineScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/insights',
                builder: (_, __) => const InsightsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
});

class ThreeLinesApp extends ConsumerWidget {
  const ThreeLinesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeAsync = ref.watch(themeNotifierProvider);
    final mode = themeAsync.valueOrNull ?? ThemeMode.system;
    final accent = ref.watch(accentThemeProvider).valueOrNull ?? 'sage';

    return MaterialApp.router(
      title: '3Lines',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightForAccent(accent),
      darkTheme: AppTheme.darkForAccent(accent),
      themeMode: mode,
      routerConfig: router,
      locale: const Locale('ko', 'KR'),
    );
  }
}
