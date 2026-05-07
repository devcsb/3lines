import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoService {
  final ImagePicker _picker = ImagePicker();

  /// Pick a photo from the gallery. Returns the saved local path, or null.
  Future<String?> pickFromGallery() async {
    return _pickAndSave(ImageSource.gallery);
  }

  /// Pick a photo from the camera. Returns the saved local path, or null.
  Future<String?> pickFromCamera() async {
    return _pickAndSave(ImageSource.camera);
  }

  /// Delete a photo file at the given path.
  Future<void> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, stack) {
      developer.log('Failed to delete photo: $path',
          name: 'PhotoService', error: e, stackTrace: stack);
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
      if (!await dir.exists()) return 0;

      var removed = 0;
      await for (final entity in dir.list()) {
        if (entity is File && !validPaths.contains(entity.path)) {
          try {
            await entity.delete();
            removed++;
          } catch (e, stack) {
            developer.log('Failed to remove orphan: ${entity.path}',
                name: 'PhotoService', error: e, stackTrace: stack);
          }
        }
      }
      return removed;
    } catch (e, stack) {
      developer.log('Orphan cleanup failed',
          name: 'PhotoService', error: e, stackTrace: stack);
      return 0;
    }
  }

  Future<Directory> _photosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
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
    } catch (e, stack) {
      developer.log('Failed to pick photo',
          name: 'PhotoService', error: e, stackTrace: stack);
      return null;
    }
  }
}

final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService();
});
