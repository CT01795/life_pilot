// -------------------- Calendar --------------------
// 🏮 節日工具類（用於連假判定與 Calendar ID）
import 'dart:ui';

import 'package:life_pilot/app/config_app.dart';

class Holidays {
  // 📌 關鍵字：哪些節日要被合併成連假
  static const Set<String> mergeHolidayKeywords = {
    "春節",
    "兒童節",
    "清明節",
    "除夕",
    "New Year",
    "Children",
    "Tomb Sweeping",
    "New Year's Eve",
  };

  // ✅ 判斷是否屬於連假節日
  static bool shouldMergeHoliday(String summary) {
    return mergeHolidayKeywords.any((keyword) => summary.contains(keyword));
  }

  // ✅ 根據時區判定地區代碼
  static String getRegionFromTimezone(String tz) {
    tz = tz.toLowerCase();
    if (tz.contains('new_york') || tz.contains('est')) return 'usa';
    if (tz.contains('taipei') || tz.contains('cst')) return 'taiwan';
    if (tz.contains('tokyo') || tz.contains('jst')) return 'japanese';
    if (tz.contains('seoul') || tz.contains('kst')) return 'south_korea';
    return 'taiwan';
  }

  // ✅ 根據語言代碼判定地區（補強 fallback）
  static String getRegionFromLanguageCode(String code) {
    code = code.toLowerCase();
    if (code.startsWith(Locales.en)) return 'usa';
    if (code.startsWith(Locales.zh)) return 'taiwan';
    if (code.startsWith(Locales.ja)) return 'japanese';
    if (code.startsWith(Locales.ko)) return 'south_korea';
    return 'taiwan';
  }

  // ✅ 組合 Google Calendar ID
  static String getCalendarIdByLocale(String tzName, Locale locale) {
    final languageCode = locale.languageCode.toLowerCase();
    final countryCode = getRegionFromTimezone(tzName);
        //getRegionFromLanguageCode(languageCode);  //getRegionFromTimezone(tzName);
    return '$languageCode.$countryCode%23holiday%40group.v.calendar.google.com';
  }
}


