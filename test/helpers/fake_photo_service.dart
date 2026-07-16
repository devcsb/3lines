import 'dart:async';

import 'package:three_lines/core/services/photo_service.dart';

/// PhotoService fake that records deleted paths and returns a configurable
/// pick result without touching the filesystem.
class FakePhotoService extends PhotoService {
  final List<String> deletedPaths = [];
  String? nextPickResult;
  Completer<void>? deleteStarted;
  Completer<void>? deleteGate;
  Object? deleteError;

  @override
  Future<String?> pickFromGallery() async => nextPickResult;

  @override
  Future<String?> pickFromCamera() async => nextPickResult;

  @override
  Future<void> deletePhoto(String path) async {
    deletedPaths.add(path);
    if (deleteStarted?.isCompleted == false) {
      deleteStarted!.complete();
    }
    await deleteGate?.future;
    if (deleteError != null) throw deleteError!;
  }
}
