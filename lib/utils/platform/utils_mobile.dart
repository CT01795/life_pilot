import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:life_pilot/utils/utils_common_function.dart';

Future<bool> checkExactAlarmPermission() async {
  if (!kIsWeb && Platform.isAndroid) {
    const platform = MethodChannel('com.example.life_pilot/exact_alarm');
    try {
      final bool isGranted =
          await platform.invokeMethod('checkExactAlarmPermission');
      if (!isGranted) {
        try {
          await platform.invokeMethod('openExactAlarmSettings');
        } on PlatformException catch (e, stacktrace) {
          logger.e('Failed to open exact alarm settings:',
              error: e, stackTrace: stacktrace);
        }
      }
    } on PlatformException catch (e, stacktrace) {
      logger.e('Failed to open exact alarm settings:',
          error: e, stackTrace: stacktrace);
    }
  }
  return true;
}

Future<int?> getAndroidVersion() async {
  if (kIsWeb || !Platform.isAndroid) return null;

  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  return androidInfo.version.sdkInt; // 回傳Android SDK版本號 (int)
}