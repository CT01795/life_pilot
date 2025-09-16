import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:logger/logger.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;

Future<String> setTimezoneFromDevice(
    {String fallbackTz = 'Asia/Taipei'}) async {
  try {
    // 初始化時區資料
    tz.initializeTimeZones();

    String tzName = 'Asia/Taipei';
    if (kIsWeb) {
      // ✅ Web: 使用 Dart 提供的 fallback
      tzName = DateTime.now().timeZoneName;

      // 簡單處理一些常見的時區名稱差異
      if (tzName == 'CST') {
        tzName = 'Asia/Taipei';
      } else if (tzName == 'EST') {
        tzName = 'America/New_York';
      } else if (tzName == 'JST') {
        tzName = 'Asia/Tokyo';
      } else {
        tzName = fallbackTz;
      }
      logger.e('🌐 Web 時區設定為 $tzName');
    } else {
      // ✅ Mobile 使用 flutter_timezone_plus
      tzName = (await FlutterTimezone.getLocalTimezone()).toString();
      logger.e('📱 裝置時區為 $tzName');
    }

    tz.setLocalLocation(tz.getLocation(tzName));
    return tzName;
  } catch (ex, stackTrace) {
    tz.setLocalLocation(tz.getLocation(fallbackTz));
    logger.e('⚠️ 取得設備時區錯誤，使用預設 $fallbackTz', error: ex, stackTrace: stackTrace);
    return fallbackTz;
  }
}

String getCalendarIdByTimezone(String tzName) {
  if (tzName.contains('Taipei') || tzName.contains('CST')) {
    return 'zh.taiwan%23holiday%40group.v.calendar.google.com';
  } else if (tzName.contains('New_York') || tzName.contains('EST')) {
    return 'en.usa%23holiday%40group.v.calendar.google.com';
  } else if (tzName.contains('Tokyo') || tzName.contains('JST')) {
    return 'ja.japanese%23holiday%40group.v.calendar.google.com';
  } else {
    return 'zh.taiwan%23holiday%40group.v.calendar.google.com'; // 預設
  }
}
