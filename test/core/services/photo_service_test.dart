import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:three_lines/core/services/photo_service.dart';

import '../../helpers/fake_photo_service.dart';

void main() {
  late Directory temp;
  late Directory docs;
  late Directory photos;
  late PhotoService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('3lines_photo_test_');
    docs = await Directory(p.join(temp.path, 'documents')).create();
    photos = await Directory(p.join(docs.path, 'photos')).create();
    service = PhotoService(documentsDirectoryProvider: () async => docs);
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('앱 문서 폴더 밖의 파일은 삭제하지 않는다', () async {
    final outside = await File(
      p.join(temp.path, 'outside.jpg'),
    ).writeAsString('outside');

    await service.deletePhoto(outside.path);

    expect(await outside.exists(), isTrue);
  });

  test('traversal, 상대 경로, 폴더와 비소유 파일은 삭제하지 않는다', () async {
    final owned = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('owned');
    final database = await File(
      p.join(photos.path, 'app.db'),
    ).writeAsString('database');
    final arbitrary = await File(
      p.join(photos.path, 'notes.txt'),
    ).writeAsString('notes');
    final nested = await Directory(p.join(photos.path, 'nested')).create();
    final nestedPhoto = await File(
      p.join(nested.path, 'photo_456.jpg'),
    ).writeAsString('nested');
    for (final path in [
      photos.path,
      docs.path,
      database.path,
      arbitrary.path,
      nested.path,
      nestedPhoto.path,
      'photo_123.jpg',
      '${photos.path}/../photos/photo_123.jpg',
    ]) {
      expect(await service.canonicalPhotoPath(path), isNull);
      await service.deletePhoto(path);
    }
    expect(await owned.exists(), isTrue);
    expect(await database.exists(), isTrue);
    expect(await arbitrary.exists(), isTrue);
    expect(await nestedPhoto.exists(), isTrue);
  });

  for (final extension in [
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif',
    'webp',
    'gif',
    'bmp',
    'avif',
    'JPG',
  ]) {
    test('소유 사진의 .$extension 확장자는 삭제할 수 있다', () async {
      final photo = await File(
        p.join(photos.path, 'photo_123.$extension'),
      ).writeAsString('owned');
      await service.deletePhoto(photo.path);
      expect(await photo.exists(), isFalse);
      await expectLater(service.deletePhoto(photo.path), completes);
    });
  }

  test('허용 목록 밖 확장자와 숫자가 아닌 basename은 정리해도 보존한다', () async {
    final unsupported = await File(
      p.join(photos.path, 'photo_123.tiff'),
    ).writeAsString('unsupported');
    final badNumber = await File(
      p.join(photos.path, 'photo_abc.jpg'),
    ).writeAsString('bad number');
    final badSuffix = await File(
      p.join(photos.path, 'photo_123.jpg.extra'),
    ).writeAsString('bad suffix');
    for (final file in [unsupported, badNumber, badSuffix]) {
      await service.deletePhoto(file.path);
    }
    expect(await service.cleanupOrphanedPhotos({}), 0);
    for (final file in [unsupported, badNumber, badSuffix]) {
      expect(await file.exists(), isTrue);
    }
  });

  test('최종 symlink와 디렉터리 symlink는 삭제와 정리에서 보존한다', () async {
    final outside = await File(
      p.join(temp.path, 'outside.jpg'),
    ).writeAsString('outside');
    final finalLink = await Link(
      p.join(photos.path, 'photo_456.jpg'),
    ).create(outside.path);
    final nested = await Directory(p.join(temp.path, 'nested')).create();
    final nestedPhoto = await File(
      p.join(nested.path, 'photo_789.jpg'),
    ).writeAsString('outside nested');
    final directoryLink = await Link(
      p.join(photos.path, 'nested'),
    ).create(nested.path);
    await service.deletePhoto(finalLink.path);
    await service.deletePhoto(p.join(directoryLink.path, 'photo_789.jpg'));
    expect(await service.cleanupOrphanedPhotos({}), 0);
    expect(await outside.exists(), isTrue);
    expect(await nestedPhoto.exists(), isTrue);
    expect(await finalLink.exists(), isTrue);
    expect(await directoryLink.exists(), isTrue);
  });

  test('photos root symlink는 외부 파일과 링크를 보존한다', () async {
    final outsidePhotos = await Directory(
      p.join(temp.path, 'outside_photos'),
    ).create();
    final outside = await File(
      p.join(outsidePhotos.path, 'photo_123.jpg'),
    ).writeAsString('outside');
    await photos.delete();
    final rootLink = await Link(photos.path).create(outsidePhotos.path);
    await service.deletePhoto(p.join(rootLink.path, 'photo_123.jpg'));
    expect(await service.cleanupOrphanedPhotos({}), 0);
    expect(await outside.exists(), isTrue);
    expect(await rootLink.exists(), isTrue);
  });

  test('Documents 별칭 참조는 같은 canonical 사진을 보호한다', () async {
    final photo = await File(
      p.join(photos.path, 'photo_123.JPG'),
    ).writeAsString('owned');
    final alias = await Link(p.join(temp.path, 'docs_alias')).create(docs.path);
    final aliasService = PhotoService(
      documentsDirectoryProvider: () async => Directory(alias.path),
    );
    final aliasPath = p.join(alias.path, 'photos', 'photo_123.JPG');
    final realPath = await photo.resolveSymbolicLinks();
    expect(await aliasService.canonicalPhotoPath(aliasPath), realPath);
    expect(await aliasService.referencesPhoto(photo.path, [aliasPath]), isTrue);
    expect(await aliasService.cleanupOrphanedPhotos({aliasPath}), 0);
    expect(await photo.exists(), isTrue);
    await aliasService.deletePhoto(aliasPath);
    expect(await photo.exists(), isFalse);
  });

  test('참조 하나라도 판정 불명이면 일치 참조 유무와 무관하게 보존한다', () async {
    final photo = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('owned');
    final unknown = p.join(temp.path, 'unknown');
    for (final references in [
      [unknown],
      [photo.path, unknown],
      [unknown, photo.path],
    ]) {
      expect(await service.referencesPhoto(photo.path, references), isNull);
      expect(await service.cleanupOrphanedPhotos(references.toSet()), 0);
      expect(await photo.exists(), isTrue);
    }
  });

  test('정리에서는 직접 자식 소유 파일만 삭제하고 보호 참조는 남긴다', () async {
    final protected = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('protected');
    final orphan = await File(
      p.join(photos.path, 'photo_456.PNG'),
    ).writeAsString('orphan');
    final database = await File(
      p.join(photos.path, 'app.db'),
    ).writeAsString('database');
    final nested = await Directory(p.join(photos.path, 'nested')).create();
    final nestedPhoto = await File(
      p.join(nested.path, 'photo_789.jpg'),
    ).writeAsString('nested');
    final photoDirectory = await Directory(
      p.join(photos.path, 'photo_999.jpg'),
    ).create();
    expect(await service.cleanupOrphanedPhotos({protected.path}), 1);
    expect(await protected.exists(), isTrue);
    expect(await orphan.exists(), isFalse);
    expect(await database.exists(), isTrue);
    expect(await nestedPhoto.exists(), isTrue);
    expect(await photoDirectory.exists(), isTrue);
    expect(await service.cleanupOrphanedPhotos({protected.path}), 0);
  });

  test('존재하지 않는 소유 경로도 참조를 비교하며 반복 삭제는 성공한다', () async {
    final absent = p.join(photos.path, 'photo_123.jpg');
    final realPhotos = await photos.resolveSymbolicLinks();
    expect(
      await service.canonicalPhotoPath(absent),
      p.join(realPhotos, 'photo_123.jpg'),
    );
    expect(await service.referencesPhoto(absent, [absent]), isTrue);
    expect(await service.referencesPhoto(absent, []), isFalse);
    await expectLater(service.deletePhoto(absent), completes);
  });

  test('Documents 조회 오류는 판정 불명이며 삭제와 정리는 보존한다', () async {
    final photo = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('owned');
    final failingService = PhotoService(
      documentsDirectoryProvider: () async {
        throw const FileSystemException('sensitive exception');
      },
    );
    expect(await failingService.canonicalPhotoPath(photo.path), isNull);
    expect(await failingService.referencesPhoto(photo.path, []), isNull);
    await expectLater(failingService.deletePhoto(photo.path), completes);
    expect(await failingService.cleanupOrphanedPhotos({}), 0);
    expect(await photo.exists(), isTrue);
  });

  test('최신 DB 참조가 사라진 뒤에만 사진을 삭제한다', () async {
    final photo = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('owned');
    var references = [photo.path];
    Future<List<String>> readReferences() async => references;
    await service.deleteUnreferencedPhoto(
      photo.path,
      readReferences: readReferences,
    );
    expect(await photo.exists(), isTrue);
    references = [];
    await service.deleteUnreferencedPhoto(
      photo.path,
      readReferences: readReferences,
    );
    expect(await photo.exists(), isFalse);
  });

  test('DB 조회 오류가 있으면 실제 사진을 보존하고 오류를 전파하지 않는다', () async {
    final photo = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('owned');
    await expectLater(
      service.deleteUnreferencedPhoto(
        photo.path,
        readReferences: () async =>
            throw StateError('sensitive database error'),
      ),
      completes,
    );
    expect(await photo.exists(), isTrue);
  });

  test('보존할 draft 별칭은 DB 참조가 없어도 실제 사진을 보호한다', () async {
    final photo = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('owned');
    final alias = await Link(p.join(temp.path, 'docs_alias')).create(docs.path);
    await service.deleteUnreferencedPhoto(
      photo.path,
      readReferences: () async => [],
      retainedPaths: [p.join(alias.path, 'photos', 'photo_123.jpg')],
    );
    expect(await photo.exists(), isTrue);
  });

  test('다른 DB 참조와 draft만 남았으면 미참조 사진을 삭제한다', () async {
    final photo = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('owned');
    final other = await File(
      p.join(photos.path, 'photo_456.jpg'),
    ).writeAsString('other');
    final draft = await File(
      p.join(photos.path, 'photo_789.jpg'),
    ).writeAsString('draft');
    await service.deleteUnreferencedPhoto(
      photo.path,
      readReferences: () async => [other.path],
      retainedPaths: [draft.path],
    );
    expect(await photo.exists(), isFalse);
    expect(await other.exists(), isTrue);
    expect(await draft.exists(), isTrue);
  });

  test('DB나 draft 참조가 불명이면 실제 사진을 보존한다', () async {
    final photo = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('owned');
    final unknown = p.join(temp.path, 'unknown');
    await service.deleteUnreferencedPhoto(
      photo.path,
      readReferences: () async => [unknown],
    );
    expect(await photo.exists(), isTrue);
    await service.deleteUnreferencedPhoto(
      photo.path,
      readReferences: () async => [],
      retainedPaths: [unknown],
    );
    expect(await photo.exists(), isTrue);
  });

  test('참조 순회 오류도 판정 불명으로 처리한다', () async {
    final photo = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('owned');
    expect(
      await service.referencesPhoto(photo.path, _throwingReferences()),
      isNull,
    );
    await expectLater(
      service.deleteUnreferencedPhoto(
        photo.path,
        readReferences: () async => [],
        retainedPaths: _throwingReferences(),
      ),
      completes,
    );
    expect(await photo.exists(), isTrue);
  });

  test('공통 삭제 helper는 삭제 오류를 전파하지 않고 실제 사진을 보존한다', () async {
    final photo = await File(
      p.join(photos.path, 'photo_123.jpg'),
    ).writeAsString('owned');
    final failingService = _FailingDeletionPhotoService(docs);
    await expectLater(
      failingService.deleteUnreferencedPhoto(
        photo.path,
        readReferences: () async => [],
      ),
      completes,
    );
    expect(await photo.exists(), isTrue);
  });

  test('fake에서도 공통 helper가 별칭과 불명 참조를 보호한다', () async {
    final fake = FakePhotoService();
    fake.canonicalAliases['/alias/new.jpg'] = '/photos/new.jpg';
    await fake.deleteUnreferencedPhoto(
      '/photos/new.jpg',
      readReferences: () async => ['/alias/new.jpg'],
    );
    expect(fake.deletedPaths, isEmpty);
    fake.referenceCheckFails = true;
    await fake.deleteUnreferencedPhoto(
      '/photos/new.jpg',
      readReferences: () async => [],
    );
    expect(fake.deletedPaths, isEmpty);
    fake.referenceCheckFails = false;
    await fake.deleteUnreferencedPhoto(
      '/photos/new.jpg',
      readReferences: () async => [],
    );
    expect(fake.deletedPaths, ['/photos/new.jpg']);
  });
}

Iterable<String> _throwingReferences() sync* {
  throw StateError('sensitive reference error');
}

class _FailingDeletionPhotoService extends PhotoService {
  _FailingDeletionPhotoService(Directory docs)
    : super(documentsDirectoryProvider: () async => docs);

  @override
  Future<void> deletePhoto(String path) async {
    throw const FileSystemException('sensitive deletion error');
  }
}
