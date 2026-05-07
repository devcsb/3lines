import 'dart:async';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
        appDatabaseProvider.overrideWithValue(db),
        biometricLockStateProvider.overrideWith((ref) => biometricEnabled),
      ],
      child: const ThreeLinesApp(),
    ),
  );
}

Future<void> _cleanupOrphanedPhotos(AppDatabase db) async {
  final entryRepo = EntryRepository(db);
  final validPaths = (await entryRepo.getAllPhotoPaths()).toSet();
  await PhotoService().cleanupOrphanedPhotos(validPaths);
}
