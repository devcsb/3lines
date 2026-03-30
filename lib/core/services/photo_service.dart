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
      developer.log('Failed to delete photo', error: e, stackTrace: stack);
    }
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

      // Copy to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
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
      developer.log('Failed to pick photo', error: e, stackTrace: stack);
      return null;
    }
  }
}

final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService();
});
