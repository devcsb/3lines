import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/notification_platform.dart';

void main() {
  test('플랫폼 초기화 설정은 Darwin 권한을 암묵적으로 요청하지 않는다', () {
    final settings = notificationInitializationSettings();
    final ios = settings.iOS!;
    final macOS = settings.macOS!;

    expect(ios.requestAlertPermission, isFalse);
    expect(ios.requestBadgePermission, isFalse);
    expect(ios.requestSoundPermission, isFalse);
    expect(macOS.requestAlertPermission, isFalse);
    expect(macOS.requestBadgePermission, isFalse);
    expect(macOS.requestSoundPermission, isFalse);
  });
}
