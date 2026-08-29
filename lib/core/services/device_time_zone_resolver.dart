import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

abstract interface class DeviceTimeZoneResolver {
  Future<String> getIdentifier();
}

final class FlutterDeviceTimeZoneResolver implements DeviceTimeZoneResolver {
  @override
  Future<String> getIdentifier() async {
    final info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  }
}

final deviceTimeZoneResolverProvider = Provider<DeviceTimeZoneResolver>((ref) {
  return FlutterDeviceTimeZoneResolver();
});
