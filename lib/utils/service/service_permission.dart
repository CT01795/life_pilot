import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/utils/logger.dart';

class ServicePermission {
  Future<bool> checkExactAlarmPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      const platform = MethodChannel('com.example.life_pilot/exact_alarm');
      try {
        final bool isGranted =
            await platform.invokeMethod('checkExactAlarmPermission');
        if (!isGranted) {
          await platform.invokeMethod('openExactAlarmSettings');
        }
        return isGranted;
      } on PlatformException catch (e, stacktrace) {
        logger.e('Failed to open exact alarm settings:',
            error: e, stackTrace: stacktrace);
        return false;
      }
    }
    return true; // Web 或非 Android 一律 true
  }

  Future<int?> getAndroidVersion() async {
    if (kIsWeb || !Platform.isAndroid) return null;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt; // 回傳Android SDK版本號 (int)
  }

  // ✅ 檢查與請求 iOS 通知權限
  Future<bool> checkIosNotificationPermission() async {
    if (!Platform.isIOS) return true;

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // 嘗試檢查目前通知權限狀態
    final bool? isGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    if (isGranted == null || !isGranted) {
      logger.w('iOS Notification permission denied');
      return false;
    }
    return true;
  }

  // ✅ 檢查與請求 iOS 背景刷新權限（Background App Refresh）
  Future<bool> checkIosBackgroundRefreshPermission() async {
    if (!Platform.isIOS) return true;

    const platform = MethodChannel('com.example.life_pilot/background_refresh');
    try {
      final bool isEnabled =
          await platform.invokeMethod('checkBackgroundRefresh');
      if (!isEnabled) {
        await platform.invokeMethod('openBackgroundRefreshSettings');
      }
      return isEnabled;
    } on PlatformException catch (e, stacktrace) {
      logger.e('Failed to check background refresh permission:',
          error: e, stackTrace: stacktrace);
      return false;
    }
  }
}
