import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS release sandbox permits required app capabilities', () {
    final release = File(
      'macos/Runner/Release.entitlements',
    ).readAsStringSync();
    expect(release, contains('com.apple.security.network.client'));
    expect(release, contains('com.apple.security.device.audio-input'));
    expect(
      release,
      contains('com.apple.security.files.user-selected.read-write'),
    );
  });

  test('macOS declares privacy prompts and recovery deep link', () {
    final plist = File('macos/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSMicrophoneUsageDescription'));
    expect(plist, contains('NSSpeechRecognitionUsageDescription'));
    expect(plist, contains('NSPhotoLibraryUsageDescription'));
    expect(plist, contains('<string>lifepilot</string>'));
  });

  test('macOS uses production identity and hardened release runtime', () {
    final appInfo = File(
      'macos/Runner/Configs/AppInfo.xcconfig',
    ).readAsStringSync();
    final release = File(
      'macos/Runner/Configs/Release.xcconfig',
    ).readAsStringSync();
    expect(
      appInfo,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.minavi.life_pilot'),
    );
    expect(release, contains('ENABLE_HARDENED_RUNTIME = YES'));
  });
}
