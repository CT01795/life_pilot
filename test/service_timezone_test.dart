import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/service/service_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_timezone');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    tz.setLocalLocation(tz.UTC);
  });

  test('uses the IANA identifier returned by timezone 5 native API', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => {'identifier': 'America/New_York'},
        );
    expect(await ServiceTimezone().setTimezoneFromDevice(), 'America/New_York');
    expect(tz.local.name, 'America/New_York');
    expect(
      tz.TZDateTime(tz.local, 2026, 1, 15).timeZoneOffset,
      const Duration(hours: -5),
    );
    expect(
      tz.TZDateTime(tz.local, 2026, 7, 15).timeZoneOffset,
      const Duration(hours: -4),
    );
  });

  test('retains compatibility with native string timezone results', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'Asia/Tokyo');
    expect(await ServiceTimezone().setTimezoneFromDevice(), 'Asia/Tokyo');
    expect(tz.local.name, 'Asia/Tokyo');
  });

  test('native lookup failure falls back to configured timezone', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'timezone_unavailable'),
        );
    expect(await ServiceTimezone().setTimezoneFromDevice(), 'Asia/Taipei');
    expect(tz.local.name, 'Asia/Taipei');
  });
}
