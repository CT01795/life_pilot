import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;

class ServiceTimezone {
  final String fallbackTz;

  final Future<String> Function()? timezoneProvider;

  // 可注入 timezoneProvider，方便測試
  ServiceTimezone({this.fallbackTz = 'Asia/Taipei', this.timezoneProvider}) {
    // 初始化時區資料表
    tz.initializeTimeZones();
  }

  Future<String> setTimezoneFromDevice() async {
    try {
      String tzName = fallbackTz;

      if (timezoneProvider != null) {
        // 注入自訂 provider
        tzName = await timezoneProvider!();
      } else if (kIsWeb) {
        // Web 時區
        tzName = DateTime.now().timeZoneName;

        // 處理常見縮寫
        switch (tzName) {
          case 'CST':
            tzName = 'Asia/Taipei';
            break;
          case 'EST':
            tzName = 'America/New_York';
            break;
          case 'JST':
            tzName = 'Asia/Tokyo';
            break;
          case 'KST':
            tzName = 'Asia/Seoul';
            break;
          default:
            tzName = fallbackTz;
        }
        logger.d('Web 時區設定為 $tzName');
      } else {
        // Android / iOS
        tzName = await FlutterTimezone.getLocalTimezone();
        logger.d('裝置時區為 $tzName');
      }

      tz.setLocalLocation(tz.getLocation(tzName));
      return tzName;
    } catch (ex, stackTrace) {
      tz.setLocalLocation(tz.getLocation(fallbackTz));
      logger.e('取得設備時區錯誤，使用預設 $fallbackTz', error: ex, stackTrace: stackTrace);
      return fallbackTz;
    }
  }
}