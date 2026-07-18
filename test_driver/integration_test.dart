import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// flutter drive 스크린샷 수신용 드라이버.
/// takeScreenshot(name) 이 보낸 bytes 를 `screenshots/e2e/` 폴더에 png 로 저장한다.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('screenshots/e2e/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
