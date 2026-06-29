import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/photo_service.dart';
import 'data/database/app_database.dart';
import 'data/repositories/entry_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/lock/lock_screen.dart';

const _logName = '3lines';

void main() {
  // 모든 에러 경로(위젯 트리 밖 비동기 포함)를 단일 zone 에서 포착한다.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 위젯 빌드/렌더 단계의 프레임워크 에러.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      developer.log('FlutterError',
          name: _logName, error: details.exception, stackTrace: details.stack);
    };
    // 엔진/플랫폼 콜백에서 올라오는 에러(위 onError 로 잡히지 않는 경로).
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      developer.log('PlatformDispatcher error',
          name: _logName, error: error, stackTrace: stack);
      return true;
    };

    await initializeDateFormatting('ko', null);

    final notificationService = NotificationService();
    await notificationService.initialize();

    // DB를 먼저 생성하고 생체인증 잠금 설정을 사전 로딩하여
    // 앱 시작 시 홈 화면이 순간 노출되는 문제를 방지한다.
    final db = AppDatabase();
    final settingsRepo = SettingsRepository(db);
    final biometricEnabled = await settingsRepo.isBiometricLockEnabled();

    // 이전 실행에서 중단된 사진 삭제(예: 프로세스 강제 종료)를 회수한다.
    // DB 의 photoPath 와 photos/ 폴더를 비교해 orphan 파일을 제거한다.
    unawaited(_cleanupOrphanedPhotos(db));

    runApp(
      ProviderScope(
        observers: [_AppProviderObserver()],
        overrides: [
          notificationServiceProvider.overrideWithValue(notificationService),
          appDatabaseProvider.overrideWithValue(db),
          biometricLockStateProvider.overrideWith((ref) => biometricEnabled),
        ],
        child: const ThreeLinesApp(),
      ),
    );
  }, (error, stack) {
    developer.log('Uncaught zone error',
        name: _logName, error: error, stackTrace: stack);
  });
}

/// provider 단위 실패를 중앙에서 로깅한다(예: 저장소/서비스 비동기 실패).
final class _AppProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      'Provider failed: ${context.provider.name ?? context.provider.runtimeType}',
      name: _logName,
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
