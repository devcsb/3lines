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

/// 라우터가 의존하는 두 가지 상태(온보딩 완료, 잠금 여부)를 single source 로 합친다.
/// 잠금 설정이 로딩 중이거나 활성화 + 잠금 상태일 때만 라우터가 잠금 화면으로 보낸다.
/// 잠금 비활성화 시 lockState 의 강제 해제는 SettingsController.setBiometricLockEnabled 가 담당한다.
final _routerStateProvider =
    Provider<({bool onboardingDone, bool locked})>((ref) {
  final onboardingDone = ref.watch(onboardingDoneProvider).value ?? false;
  final lockEnabled = ref.watch(biometricLockEnabledProvider);
  final lockState = ref.watch(biometricLockStateProvider);

  // 설정 로딩 중에는 보안상 잠금 유지 (홈 화면이 순간 노출되는 것을 방지)
  if (lockEnabled is AsyncLoading) {
    return (onboardingDone: onboardingDone, locked: true);
  }
  final enabled = lockEnabled.value ?? false;
  return (
    onboardingDone: onboardingDone,
    locked: enabled && lockState,
  );
});

/// GoRouter 의 redirect 가 사용하는 ChangeNotifier.
/// _routerStateProvider 가 바뀔 때만 notifyListeners 를 호출한다.
class _RouterNotifier extends ChangeNotifier {
  bool onboardingDone = false;
  bool locked = false;

  void update(({bool onboardingDone, bool locked}) state) {
    if (state.onboardingDone == onboardingDone && state.locked == locked) {
      return;
    }
    onboardingDone = state.onboardingDone;
    locked = state.locked;
    notifyListeners();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier();
  ref.onDispose(notifier.dispose);

  // 단일 derived provider 만 구독하므로 흐름이 일직선으로 단순해진다.
  ref.listen(_routerStateProvider, (_, next) => notifier.update(next),
      fireImmediately: true);

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
        pageBuilder: (_, _) => CustomTransitionPage(
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
        builder: (_, _) => const LockScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            ScaffoldWithNavBar(navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/', builder: (_, _) => const TodayScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/timeline',
                builder: (_, _) => const TimelineScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/insights',
                builder: (_, _) => const InsightsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen()),
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
    final mode = themeAsync.value ?? ThemeMode.system;
    final accent = ref.watch(accentThemeProvider).value ?? 'sage';

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
