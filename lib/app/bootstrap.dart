import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart'
    show FlutterError, LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/services/notification_service.dart';
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

  final notificationService = NotificationService();
  await notificationService.initialize();

  final db = AppDatabase();
  final settingsRepo = SettingsRepository(db);
  final biometricEnabled = await settingsRepo.isBiometricLockEnabled();

  unawaited(_cleanupOrphanedPhotos(db));

  runApp(
    ProviderScope(
      observers: const [AppProviderObserver()],
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
        appDatabaseProvider.overrideWithValue(db),
        biometricLockStateProvider.overrideWith((ref) => biometricEnabled),
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
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['NanumMyeongjo (나눔명조)'], ofl);
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
