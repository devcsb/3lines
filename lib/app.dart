import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_lifecycle_lock.dart';
import 'app/router.dart';
import 'app/widget_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';

export 'app/router.dart'
    show biometricLockEnabledProvider, onboardingDoneProvider, routerProvider;

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
        // 큰 글자 접근성 설정에서 고정 높이 위젯이 오버플로하지 않도록
        // 텍스트 배율 상한을 1.3으로 제한한다(접근성과 레이아웃 안정의 절충).
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: WidgetBootstrap(
            child: AppLifecycleLock(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
