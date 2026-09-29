import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoService {
  PhotoService({
    Future<Directory> Function()? documentsDirectoryProvider,
    ImagePicker? picker,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _picker = picker ?? ImagePicker();

  final Future<Directory> Function() _documentsDirectoryProvider;
  final ImagePicker _picker;

  static final _ownedPhotoName = RegExp(
    r'^photo_\d+\.(jpg|jpeg|png|heic|heif|webp|gif|bmp|avif)$',
    caseSensitive: false,
  );

  /// Pick a photo from the gallery. Returns the saved local path, or null.
  Future<String?> pickFromGallery() async {
    return _pickAndSave(ImageSource.gallery);
  }

  /// Pick a photo from the camera. Returns the saved local path, or null.
  Future<String?> pickFromCamera() async {
    return _pickAndSave(ImageSource.camera);
  }

  /// Resolves an owned direct child of the trusted photos directory.
  /// Unknown ownership or an unsafe path returns null, including symlinks.
  Future<String?> canonicalPhotoPath(String path) async {
    try {
      if (!p.isAbsolute(path) || p.split(path).contains('..')) return null;
      if (!_ownedPhotoName.hasMatch(p.basename(path))) return null;

      final docs = await _documentsDirectoryProvider();
      final realDocs = await docs.resolveSymbolicLinks();
      final trustedRoot = p.join(realDocs, 'photos');
      final originalRoot = p.join(docs.path, 'photos');
      if (await FileSystemEntity.type(originalRoot, followLinks: false) !=
          FileSystemEntityType.directory) {
        return null;
      }
      if (await FileSystemEntity.type(p.dirname(path), followLinks: false) !=
          FileSystemEntityType.directory) {
        return null;
      }

      final parent = await Directory(p.dirname(path)).resolveSymbolicLinks();
      if (!p.equals(parent, trustedRoot)) return null;
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.notFound) {
        return null;
      }

      final canonical = p.join(parent, p.basename(path));
      if (type == FileSystemEntityType.file &&
          !p.equals(await File(path).resolveSymbolicLinks(), canonical)) {
        return null;
      }
      return canonical;
    } catch (_) {
      return null;
    }
  }

  /// True protects a matching reference; null protects uncertain ownership.
  Future<bool?> referencesPhoto(
    String path,
    Iterable<String> references,
  ) async {
    try {
      final target = await canonicalPhotoPath(path);
      if (target == null) return null;
      var found = false;
      for (final reference in references) {
        final canonical = await canonicalPhotoPath(reference);
        if (canonical == null) return null;
        if (p.equals(target, canonical)) found = true;
      }
      return found;
    } catch (_) {
      return null;
    }
  }

  /// Reads current DB references and protects retained drafts before deletion.
  /// Callers remain responsible for committing DB changes first.
  Future<void> deleteUnreferencedPhoto(
    String path, {
    required Future<List<String>> Function() readReferences,
    Iterable<String> retainedPaths = const [],
  }) async {
    try {
      final references = await readReferences();
      final referenced = await referencesPhoto(path, [
        ...references,
        ...retainedPaths,
      ]);
      if (referenced == false) {
        await deletePhoto(path);
      } else if (referenced == null) {
        developer.log('Photo reference check failed', name: 'PhotoService');
      }
    } catch (_) {
      developer.log('Photo cleanup failed', name: 'PhotoService');
    }
  }

  /// Deletes only a validated owned photo, without following its final link.
  Future<void> deletePhoto(String path) async {
    final canonical = await canonicalPhotoPath(path);
    if (canonical == null) return;
    try {
      if (await FileSystemEntity.type(canonical, followLinks: false) ==
          FileSystemEntityType.file) {
        await File(canonical).delete();
      }
    } catch (_) {
      developer.log('Photo deletion failed', name: 'PhotoService');
    }
  }

  /// Removes any photo files in the photos directory that are not referenced
  /// by [validPaths]. Returns the number of removed files.
  ///
  /// Safe to call on app start to recover from incomplete deletions
  /// (e.g. process killed between DB delete and file delete).
  Future<int> cleanupOrphanedPhotos(Set<String> validPaths) async {
    if (kIsWeb) return 0;
    try {
      final dir = await _photosDir();
      if (await FileSystemEntity.type(dir.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        return 0;
      }

      final protected = <String>{};
      for (final path in validPaths) {
        final canonical = await canonicalPhotoPath(path);
        if (canonical == null) return 0;
        protected.add(canonical);
      }

      var removed = 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final canonical = await canonicalPhotoPath(entity.path);
        if (canonical == null || protected.contains(canonical)) continue;
        await deletePhoto(canonical);
        if (await FileSystemEntity.type(canonical, followLinks: false) ==
            FileSystemEntityType.notFound) {
          removed++;
        }
      }
      return removed;
    } catch (_) {
      developer.log('Orphan cleanup failed', name: 'PhotoService');
      return 0;
    }
  }

  Future<Directory> _photosDir() async {
    final appDir = await _documentsDirectoryProvider();
    return Directory(p.join(appDir.path, 'photos'));
  }

  Future<String?> _pickAndSave(ImageSource source) async {
    if (kIsWeb) return null;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return null;

      final photosDir = await _photosDir();
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final ext = p.extension(picked.path).isNotEmpty
          ? p.extension(picked.path)
          : '.jpg';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'photo_$timestamp$ext';
      final savedPath = p.join(photosDir.path, fileName);

      await File(picked.path).copy(savedPath);
      return savedPath;
    } catch (_) {
      developer.log('Failed to pick photo', name: 'PhotoService');
      return null;
    }
  }
}

final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService();
});
