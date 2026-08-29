import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_lifecycle_lock.dart';
import 'app/router.dart';
import 'app/widget_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';

export 'app/router.dart'
    show
        biometricLockEnabledProvider,
        initialBiometricEnabledProvider,
        initialOnboardingDoneProvider,
        onboardingDoneProvider,
        routerProvider;

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
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // 플랫폼이 제공하는 텍스트 배율을 그대로 전달한다. 큰 글자에서
        // 오버플로가 생기는 화면은 각 화면의 스크롤·가변 레이아웃으로
        // 처리해야 하며, 시스템 접근성 설정을 루트에서 잘라서는 안 된다.
        return WidgetBootstrap(
          child: AppLifecycleLock(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
