import 'package:three_lines/core/services/biometric_service.dart';

/// BiometricService fake that returns configurable results without invoking
/// the real device authentication APIs.
class FakeBiometricService extends BiometricService {
  bool available = true;
  bool authResult = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate() async => authResult;
}
