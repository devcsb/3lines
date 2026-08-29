import 'dart:async';

import 'package:three_lines/core/services/widget_sync_service.dart';

final class FakeWidgetSync implements WidgetSync {
  int syncCount = 0;

  @override
  Future<void> sync() async => syncCount++;

  @override
  Future<Uri?> initiallyLaunchedUri() async => null;

  @override
  StreamSubscription<Uri?>? listenWidgetClicks(void Function(Uri uri) onUri) =>
      null;
}
