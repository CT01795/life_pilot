import 'dart:ui';

import 'package:life_pilot/config/config_app.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

// 🔁 重複規則（事件重複頻率）
enum RepeatRule {
  once,
  everyDay,
  everyWeek,
  everyTwoWeeks,
  everyMonth,
  everyTwoMonths,
  everyYear,
}

// 📘 RepeatRule 擴充：label、key、日期推算
extension RepeatRuleExtension on RepeatRule {
  // 取得對應的顯示文字
  String label(AppLocalizations loc) {
    switch (this) {
      case RepeatRule.once:
        return loc.repeatOptionsOnce;
      case RepeatRule.everyDay:
        return loc.repeatOptionsEveryDay;
      case RepeatRule.everyWeek:
        return loc.repeatOptionsEveryWeek;
      case RepeatRule.everyTwoWeeks:
        return loc.repeatOptionsEveryTwoWeeks;
      case RepeatRule.everyMonth:
        return loc.repeatOptionsEveryMonth;
      case RepeatRule.everyTwoMonths:
        return loc.repeatOptionsEveryTwoMonths;
      case RepeatRule.everyYear:
        return loc.repeatOptionsEveryYear;
    }
  }

  // 對應唯一 key（儲存或序列化使用）
  String get key => switch (this) {
    RepeatRule.once => 'once',
    RepeatRule.everyDay => 'every_day',
    RepeatRule.everyWeek => 'every_week',
    RepeatRule.everyTwoWeeks => 'every_two_weeks',
    RepeatRule.everyMonth => 'every_month',
    RepeatRule.everyTwoMonths => 'every_two_months',
    RepeatRule.everyYear => 'every_year',
  };

  // 從 key 還原 RepeatRule
  static RepeatRule fromKey(String? key) {
    if (key == null) return RepeatRule.once;
    return RepeatRule.values.firstWhere(
      (r) => r.key == key,
      orElse: () => RepeatRule.once,
    );
  }

  // 取得下一個日期（用於重複事件生成）
  DateTime getNextDate(DateTime date) => switch (this) {
    RepeatRule.once || RepeatRule.everyDay => date.add(const Duration(days: 1)),
    RepeatRule.everyWeek => date.add(const Duration(days: 7)),
    RepeatRule.everyTwoWeeks => date.add(const Duration(days: 14)),
    RepeatRule.everyMonth => DateTime(date.year, date.month + 1, date.day),
    RepeatRule.everyTwoMonths => DateTime(date.year, date.month + 2, date.day),
    RepeatRule.everyYear => DateTime(date.year + 1, date.month, date.day),
  };
}

// 🏮 節日工具類（用於連假判定與 Calendar ID）
class HolidayUtils {
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

// ⏰ 提醒時間類型
enum ReminderOption {
  fifteenMin,
  thirtyMin,
  oneHour,
  sameDay8am,
  dayBefore8am,
  twoDays,
  oneWeek,
  twoWeeks,
  oneMonth;
}

// 📘 ReminderOption 對應 label
extension ReminderOptionLabel on ReminderOption {
  String label(AppLocalizations loc) => switch (this) {
    ReminderOption.fifteenMin => loc.reminderOptions15MinutesBefore,
    ReminderOption.thirtyMin => loc.reminderOptions30MinutesBefore,
    ReminderOption.oneHour => loc.reminderOptionsOneHourBefore,
    ReminderOption.sameDay8am => loc.reminderOptionsDefaultSameDay8am,
    ReminderOption.dayBefore8am => loc.reminderOptionsDefaultDayBefore8am,
    ReminderOption.twoDays => loc.reminderOptionsTwoDaysBefore,
    ReminderOption.oneWeek => loc.reminderOptionsOneWeekBefore,
    ReminderOption.twoWeeks => loc.reminderOptionsTwoWeeksBefore,
    ReminderOption.oneMonth => loc.reminderOptionsOneMonthBefore,
  };
}

// 📦 ReminderOption 映射工具（key ↔ duration）
class ReminderMapper {
  static const Map<ReminderOption, String> _keyMap = {
    ReminderOption.fifteenMin: '15_min',
    ReminderOption.thirtyMin: '30_min',
    ReminderOption.oneHour: '1_hour',
    ReminderOption.sameDay8am: 'same_day_8am',
    ReminderOption.dayBefore8am: 'day_before_8am',
    ReminderOption.twoDays: '2_days',
    ReminderOption.oneWeek: '1_week',
    ReminderOption.twoWeeks: '2_weeks',
    ReminderOption.oneMonth: '1_month',
  };

  static const Map<ReminderOption, Duration> _durationMap = {
    ReminderOption.fifteenMin: Duration(minutes: 15),
    ReminderOption.thirtyMin: Duration(minutes: 30),
    ReminderOption.oneHour: Duration(hours: 1),
    ReminderOption.sameDay8am: Duration.zero,
    ReminderOption.dayBefore8am: Duration.zero,
    ReminderOption.twoDays: Duration(days: 2),
    ReminderOption.oneWeek: Duration(days: 7),
    ReminderOption.twoWeeks: Duration(days: 14),
    ReminderOption.oneMonth: Duration(days: 30),
  };

  // 取得對應 key
  static String toKey({required ReminderOption reminderOption}) =>
      _keyMap[reminderOption]!;

  // 根據 key 還原
  static ReminderOption fromKey({required String key}) => _keyMap.entries
      .firstWhere((e) => e.value == key,
          orElse: () => const MapEntry(ReminderOption.fifteenMin, '15_min'))
      .key;

  // 取得對應 Duration
  static Duration getDuration({required ReminderOption reminderOption}) =>
      _durationMap[reminderOption]!;
}

/*🚀 優化成果總覽
可讀性	多層 switch、重複字串	統一封裝 + switch 表達式簡潔
效能	多次字串比對（contains / split）	預先 lowercase、Map 查找 O(1)
維護性	多處重複 key 定義	集中定義於 enum extension
錯誤處理	無 fallback	firstWhere(orElse) 提供安全回傳
結構	分散職責	完整分層：RepeatRule / Holiday / Reminder*/