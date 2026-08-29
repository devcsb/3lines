import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart'
    show FlutterError, LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/services/photo_service.dart';
import '../data/database/app_database.dart';
import '../data/repositories/entry_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../features/lock/lock_screen.dart';
import '../app.dart';

const appLogName = '3lines';

Future<void> bootstrapAndRun() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorLogging();
  _registerBundledLicenses();

  await initializeDateFormatting('ko', null);

  final db = AppDatabase();
  final settingsRepo = SettingsRepository(db);
  // 라우터 첫 프레임 flash 방지를 위해 락 사용 여부와 온보딩 완료 여부를 미리
  // 읽어 seed 한다(둘 다 단일 settings SELECT 라 저렴).
  final (biometricEnabled, onboardingDone) = await (
    settingsRepo.isBiometricLockEnabled(),
    settingsRepo.isOnboardingDone(),
  ).wait;

  unawaited(_cleanupOrphanedPhotos(db));

  runApp(
    ProviderScope(
      observers: const [AppProviderObserver()],
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        biometricLockStateProvider.overrideWith((ref) => biometricEnabled),
        initialBiometricEnabledProvider.overrideWithValue(biometricEnabled),
        initialOnboardingDoneProvider.overrideWithValue(onboardingDone),
      ],
      child: const ThreeLinesApp(),
    ),
  );
}

void logUncaughtZoneError(Object error, StackTrace stack) {
  developer.log(
    'Uncaught zone error',
    name: appLogName,
    error: error,
    stackTrace: stack,
  );
}

void _installErrorLogging() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'FlutterError',
      name: appLogName,
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    developer.log(
      'PlatformDispatcher error',
      name: appLogName,
      error: error,
      stackTrace: stack,
    );
    return true;
  };
}

void _registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    final nanum = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['NanumMyeongjo (나눔명조)'], nanum);
    final noto = await rootBundle.loadString('assets/fonts/NotoSans-OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Noto Sans'], noto);
  });
}

final class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      'Provider failed: ${context.provider.name ?? context.provider.runtimeType}',
      name: appLogName,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<void> _cleanupOrphanedPhotos(AppDatabase db) async {
  final entryRepo = EntryRepository(db);
  final validPaths = (await entryRepo.getAllPhotoPaths()).toSet();
  await PhotoService().cleanupOrphanedPhotos(validPaths);
}
