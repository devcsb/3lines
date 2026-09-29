import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:three_lines/app/bootstrap.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';

void main() {
  late Directory temp;
  late Directory docs;
  late File source;
  late AppDatabase db;
  late EntryRepository repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('3lines_startup_photo_test_');
    docs = await Directory(p.join(temp.path, 'documents')).create();
    source = await File(
      p.join(temp.path, 'source.jpg'),
    ).writeAsString('complete image');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  PhotoService makeService({
    Future<void> Function(String sourcePath, String savedPath)? photoCopier,
  }) => PhotoService(
    documentsDirectoryProvider: () async => docs,
    picker: _Picker(XFile(source.path)),
    photoCopier: photoCopier,
  );

  test('helper 호출은 DB 조회 전에 동기적으로 보호를 시작한다', () async {
    final service = makeService();
    final release = Completer<List<String>>();
    var readStarted = false;
    final cleanup = cleanupStartupPhotos(service, () {
      readStarted = true;
      expect(service.beginStartupCleanupProtection, throwsStateError);
      return release.future;
    });
    expect(readStarted, isTrue);
    expect(service.beginStartupCleanupProtection, throwsStateError);
    release.complete([]);
    await cleanup;
    expect(service.beginStartupCleanupProtection, returnsNormally);
    service.endStartupCleanupProtection();
  });

  test('낡은 DB snapshot 뒤 완료된 picker 복사를 정리 종료까지 보존한다', () async {
    final service = makeService();
    final snapshotRead = Completer<void>();
    final releaseSnapshot = Completer<void>();
    final cleanup = cleanupStartupPhotos(service, () async {
      final snapshot = await repo.getAllPhotoPaths();
      snapshotRead.complete();
      await releaseSnapshot.future;
      return snapshot;
    });
    await snapshotRead.future;
    final saved = (await service.pickFromGallery())!;
    await repo.saveEntry(
      DailyEntry(
        date: '2026-09-30',
        emotion: 3,
        answer1: 'answer',
        photoPath: saved,
      ),
    );
    expect(await File(saved).readAsString(), 'complete image');
    releaseSnapshot.complete();
    await cleanup;
    expect((await repo.getEntryByDate('2026-09-30'))!.photoPath, saved);
    expect(await File(saved).exists(), isTrue);
    // 낡은 스냅샷을 다시 사용하면 보호 종료 후 정리가 가능하다.
    expect(await service.cleanupOrphanedPhotos({}), 1);
    expect(await File(saved).exists(), isFalse);
  });

  test('실제 복사가 진행 중인 부분 대상도 복사 전 예약으로 보존한다', () async {
    final partialWritten = Completer<String>();
    final resumeCopy = Completer<void>();
    final snapshotRead = Completer<void>();
    final releaseSnapshot = Completer<void>();
    final service = makeService(
      photoCopier: (sourcePath, savedPath) async {
        await File(savedPath).writeAsString('partial image');
        partialWritten.complete(savedPath);
        await resumeCopy.future;
        await File(sourcePath).copy(savedPath);
      },
    );
    final cleanup = cleanupStartupPhotos(service, () async {
      final snapshot = await repo.getAllPhotoPaths();
      snapshotRead.complete();
      await releaseSnapshot.future;
      return snapshot;
    });
    await snapshotRead.future;
    final pick = service.pickFromGallery();
    final saved = await partialWritten.future;
    expect(await File(saved).readAsString(), 'partial image');
    releaseSnapshot.complete();
    await cleanup;
    expect(await File(saved).exists(), isTrue);
    resumeCopy.complete();
    expect(await pick, saved);
    expect(await File(saved).readAsString(), 'complete image');
    expect(await service.cleanupOrphanedPhotos({}), 1);
  });

  test('DB 조회 실패는 기존 사진을 남기고 finally에서 복사 보호를 끝낸다', () async {
    final photos = await Directory(p.join(docs.path, 'photos')).create();
    final existing = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('existing');
    final service = makeService();
    final snapshotRead = Completer<void>();
    final failSnapshot = Completer<void>();
    final cleanup = cleanupStartupPhotos(service, () async {
      snapshotRead.complete();
      await failSnapshot.future;
      throw StateError('sensitive DB path');
    });
    await snapshotRead.future;
    final saved = (await service.pickFromGallery())!;
    failSnapshot.complete();
    await expectLater(cleanup, completes);
    expect(await existing.readAsString(), 'existing');
    expect(await File(saved).exists(), isTrue);
    expect(await service.cleanupOrphanedPhotos({}), 2);
    expect(service.beginStartupCleanupProtection, returnsNormally);
    service.endStartupCleanupProtection();
  });

  test('정리 예외도 전파하지 않고 finally에서 같은 서비스 보호를 끝낸다', () async {
    final service = _FailingCleanupPhotoService(
      docs,
      _Picker(XFile(source.path)),
    );
    await expectLater(cleanupStartupPhotos(service, () async => []), completes);
    expect(service.beginStartupCleanupProtection, returnsNormally);
    service.endStartupCleanupProtection();
  });
}

class _Picker extends ImagePicker {
  _Picker(this.file);
  final XFile file;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => file;
}

class _FailingCleanupPhotoService extends PhotoService {
  _FailingCleanupPhotoService(Directory docs, ImagePicker picker)
    : super(documentsDirectoryProvider: () async => docs, picker: picker);

  @override
  Future<int> cleanupOrphanedPhotos(Set<String> validPaths) async {
    throw const FileSystemException('sensitive cleanup path');
  }
}
