import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/settings_repository.dart';
import '../features/insights/insights_screen.dart';
import '../features/lock/lock_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/today/today_screen.dart';
import '../shared/widgets/app_bottom_nav.dart';

final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.isOnboardingDone();
});

final biometricLockEnabledProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.isBiometricLockEnabled();
});

final _routerStateProvider = Provider<({bool onboardingDone, bool locked})>((
  ref,
) {
  final onboardingDone = ref.watch(onboardingDoneProvider).value ?? false;
  final lockEnabled = ref.watch(biometricLockEnabledProvider);
  final lockState = ref.watch(biometricLockStateProvider);

  if (lockEnabled is AsyncLoading) {
    return (onboardingDone: onboardingDone, locked: true);
  }

  final enabled = lockEnabled.value ?? false;
  return (onboardingDone: onboardingDone, locked: enabled && lockState);
});

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

  ref.listen(
    _routerStateProvider,
    (_, next) => notifier.update(next),
    fireImmediately: true,
  );

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (_, state) => _redirect(notifier, state),
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, _) => CustomTransitionPage(
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );
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
      GoRoute(path: '/lock', builder: (_, _) => const LockScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => ScaffoldWithNavBar(navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const TodayScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timeline',
                builder: (_, _) => const TimelineScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                builder: (_, _) => const InsightsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

String? _redirect(_RouterNotifier notifier, GoRouterState state) {
  final location = state.matchedLocation;

  if (!notifier.onboardingDone && location != '/onboarding') {
    return '/onboarding';
  }
  if (notifier.onboardingDone && location == '/onboarding') {
    return notifier.locked ? '/lock' : '/';
  }
  if (notifier.onboardingDone && notifier.locked && location != '/lock') {
    return '/lock';
  }
  if (notifier.onboardingDone && !notifier.locked && location == '/lock') {
    return '/';
  }
  return null;
}
