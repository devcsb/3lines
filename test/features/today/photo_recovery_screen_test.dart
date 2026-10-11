import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:three_lines/core/constants/default_prompts.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/journal_draft.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/today/today_controller.dart';
import 'package:three_lines/features/today/today_screen.dart';

class _Clock extends AppClock {
  @override
  DateTime now() => DateTime(2026, 10, 11, 9);
}

class _Picker extends ImagePicker {
  XFile? file;
  Object? error;
  Completer<XFile?>? gate;
  final entered = Completer<void>();

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (!entered.isCompleted) entered.complete();
    if (gate != null) return gate!.future;
    if (error != null) throw error!;
    return file;
  }
}

class _ObservedPhotoService extends PhotoService {
  _ObservedPhotoService({
    required super.documentsDirectoryProvider,
    required super.picker,
    super.photoCopier,
  });
  final completed = <Completer<void>>[];
  String? lastPath;

  Future<PhotoPickResult> _observe(
    Future<PhotoPickResult> Function() pick,
  ) async {
    final done = Completer<void>();
    completed.add(done);
    try {
      final result = await pick();
      lastPath = result.path;
      return result;
    } finally {
      done.complete();
    }
  }

  @override
  Future<PhotoPickResult> pickFromGalleryResult() =>
      _observe(super.pickFromGalleryResult);
  @override
  Future<PhotoPickResult> pickFromCameraResult() =>
      _observe(super.pickFromCameraResult);
}

void main() {
  late Directory temp;
  late Directory photos;
  late File source;
  late AppDatabase db;
  late EntryRepository entries;
  late _Picker picker;
  late ProviderContainer container;
  late _ObservedPhotoService service;

  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('3lines_photo_recovery_');
    photos = await Directory(p.join(temp.path, 'photos')).create();
    source = await File(p.join(temp.path, 'source.png')).writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entries = EntryRepository(db, clock: _Clock());
    picker = _Picker();
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<void> show(WidgetTester tester, {bool copyFails = false}) async {
    service = _ObservedPhotoService(
      documentsDirectoryProvider: () async => temp,
      picker: picker,
      photoCopier: copyFails
          ? (sourcePath, targetPath) async =>
                throw const FileSystemException('copy denied')
          : null,
    );
    await tester.runAsync(() async {
      await entries.storeDraft(
        JournalDraft(
          date: '2026-10-11',
          revision: 1,
          emotion: 3,
          prompts: defaultPromptQuestions,
          answers: const ['사진 없이도 남길 글', '', ''],
        ),
        epoch: 0,
      );
      container = ProviderContainer(
        overrides: [
          appClockProvider.overrideWithValue(_Clock()),
          entryRepositoryProvider.overrideWithValue(entries),
          settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
          photoServiceProvider.overrideWithValue(service),
        ],
      );
      container.listen(todayControllerProvider, (_, _) {});
      await container.read(todayControllerProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TodayScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text(label));
      await service.completed.last.future.timeout(const Duration(seconds: 3));
      await entries.listDrafts();
    });
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  }

  testWidgets('사진 picker 취소는 오류 없이 돌아와 작성한 글을 유지한다', (tester) async {
    await show(tester);
    await pick(tester, '갤러리');
    expect(
      container.read(todayControllerProvider).value!.answer1,
      '사진 없이도 남길 글',
    );
    expect(container.read(todayControllerProvider).value!.photoPath, isNull);
    expect(find.textContaining('권한'), findsNothing);
    expect(find.text('다시 시도'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진 권한 거부는 글을 유지하고 권한 확인 안내와 실제 재시도를 제공한다', (tester) async {
    picker.error = PlatformException(code: 'camera_access_denied');
    await show(tester);
    await pick(tester, '카메라');
    expect(
      container.read(todayControllerProvider).value!.answer1,
      '사진 없이도 남길 글',
    );
    expect(find.textContaining('권한'), findsWidgets);
    expect(find.text('다시 시도'), findsOneWidget);
    picker.error = null; // 재시도에서 취소하면 안내도 조용히 끝난다.
    await tester.tap(find.text('다시 시도'));
    await tester.runAsync(() async {
      await service.completed.last.future.timeout(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsNothing);
    expect(
      container.read(todayControllerProvider).value!.answer1,
      '사진 없이도 남길 글',
    );
  });

  testWidgets('사진 복사 실패는 취소와 구분해 안내하고 텍스트를 유지한다', (tester) async {
    picker.file = XFile(source.path);
    await show(tester, copyFails: true);
    await pick(tester, '갤러리');
    expect(
      container.read(todayControllerProvider).value!.answer1,
      '사진 없이도 남길 글',
    );
    expect(container.read(todayControllerProvider).value!.photoPath, isNull);
    expect(find.textContaining('사진'), findsWidgets);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진 실패 뒤 예시 Undo 안내는 새 picker 취소가 닫지 않는다', (tester) async {
    picker.error = PlatformException(code: 'photo_access_denied');
    await show(tester);
    await pick(tester, '갤러리');
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.ensureVisible(find.text('맑은 날씨').first);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('맑은 날씨').first);
      await entries.listDrafts().timeout(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();
    final inserted = container.read(todayControllerProvider).value!.answer1;
    expect(find.text('되돌리기'), findsOneWidget);
    picker.error = null;
    await pick(tester, '갤러리');
    expect(find.text('되돌리기'), findsOneWidget);
    expect(container.read(todayControllerProvider).value!.answer1, inserted);
  });

  testWidgets('늦은 picker 결과는 다른 날짜의 글과 기존 사진을 덮지 않고 미사용 파일만 정리한다', (
    tester,
  ) async {
    await tester.runAsync(() async {
      picker.gate = Completer<XFile?>();
    });
    await show(tester);
    final retained = p.join(photos.path, 'photo_20.png');
    await tester.runAsync(() async {
      await source.copy(retained);
      await entries.storeDraft(
        JournalDraft(
          date: '2026-10-10',
          revision: 1,
          emotion: 4,
          prompts: defaultPromptQuestions,
          answers: const ['다른 날짜의 글', '', ''],
          photoPath: retained,
        ),
        epoch: 0,
      );
    });
    await tester.ensureVisible(find.text('갤러리'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('갤러리'));
      await picker.entered.future.timeout(const Duration(seconds: 3));
      await container
          .read(todayControllerProvider.notifier)
          .selectDate('2026-10-10');
      picker.gate!.complete(XFile(source.path));
      await service.completed.last.future.timeout(const Duration(seconds: 3));
      for (
        var turn = 0;
        turn < 30 && await File(service.lastPath!).exists();
        turn++
      ) {
        await entries.getAllPhotoPaths();
        if (turn == 29) fail('late picker file was not cleaned');
      }
    });
    await tester.pumpAndSettle();
    final current = container.read(todayControllerProvider).value!;
    expect(current.draftDate, '2026-10-10');
    expect(current.answer1, '다른 날짜의 글');
    expect(current.photoPath, retained);
    await tester.runAsync(() async {
      expect(await File(retained).exists(), isTrue);
      expect(await File(service.lastPath!).exists(), isFalse);
    });
    expect(tester.takeException(), isNull);
  });
}
