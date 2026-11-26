import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/utils/service/platforms/notification_mobile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('macOS initializes native notification presentation defaults', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    MacOSFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await NotificationServiceMobile().initialize();

    final initialization = calls.singleWhere(
      (call) => call.method == 'initialize',
    );
    expect(initialization.arguments['defaultPresentAlert'], isTrue);
    expect(initialization.arguments['defaultPresentBadge'], isTrue);
    expect(initialization.arguments['defaultPresentSound'], isTrue);
  });
}
