import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';

// -------------------- PageType --------------------
extension PageTypeExtension on PageType {
  //Dart 的 enum 自 2.15 以後有內建 name 屬性，會直接返回 enum 變數名稱字串，因此不用寫明確的 switch：
  String get key => name; //ex PageType.personalEvent 會返回 'personalEvent'

  static final Map<String, PageType> _keyMap = {
    for (var e in PageType.values) e.key: e,
  };

  //fromKey 改寫成 Map 快取（優化搜尋效率）
  //目前 fromKey 會用 firstWhere 遍歷所有值，當 enum 值很多時效率會下降。可以用一個靜態 Map 快取字串到 enum 的對應關係：
  static PageType fromKey(String key) =>
      _keyMap[key] ?? PageType.recommendedEvent;

  String title({required AppLocalizations loc}) {
    final map = _titlesForLocale(loc);
    return map[this]!;
  }

  static Map<PageType, String> _titlesForLocale(AppLocalizations loc) => {
    PageType.personalEvent: loc.personalEvent,
    PageType.settings: loc.settings,
    PageType.recommendedEvent: loc.recommendedEvent,
    PageType.recommendedAttractions: loc.recommendedAttractions,
    PageType.memoryTrace: loc.memoryTrace,
    PageType.accountRecords: loc.accountRecords,
    PageType.pointsRecord: loc.pointsRecord,
    PageType.game: loc.game,
    PageType.ai: loc.ai,
    PageType.feedbackAdmin: loc.feedback,
    PageType.businessPlan: loc.businessPlan,
  };
}

// -------------------- Calendar --------------------
// 📘 RepeatRule 擴充：label、key、日期推算
extension CalendarRepeatRuleExtension on CalendarRepeatRule {
  // 取得對應的顯示文字
  String label(AppLocalizations loc) {
    switch (this) {
      case CalendarRepeatRule.once:
        return loc.repeatOptionsOnce;
      case CalendarRepeatRule.everyDay:
        return loc.repeatOptionsEveryDay;
      case CalendarRepeatRule.everyWeek:
        return loc.repeatOptionsEveryWeek;
      case CalendarRepeatRule.everyTwoWeeks:
        return loc.repeatOptionsEveryTwoWeeks;
      case CalendarRepeatRule.everyMonth:
        return loc.repeatOptionsEveryMonth;
      case CalendarRepeatRule.everyTwoMonths:
        return loc.repeatOptionsEveryTwoMonths;
      case CalendarRepeatRule.everyYear:
        return loc.repeatOptionsEveryYear;
    }
  }

  // 對應唯一 key（儲存或序列化使用）
  String get key => switch (this) {
    CalendarRepeatRule.once => 'once',
    CalendarRepeatRule.everyDay => 'every_day',
    CalendarRepeatRule.everyWeek => 'every_week',
    CalendarRepeatRule.everyTwoWeeks => 'every_two_weeks',
    CalendarRepeatRule.everyMonth => 'every_month',
    CalendarRepeatRule.everyTwoMonths => 'every_two_months',
    CalendarRepeatRule.everyYear => 'every_year',
  };

  // 從 key 還原 RepeatRule
  static CalendarRepeatRule fromKey(String? key) {
    if (key == null) return CalendarRepeatRule.once;
    return CalendarRepeatRule.values.firstWhere(
      (r) => r.key == key,
      orElse: () => CalendarRepeatRule.once,
    );
  }

  // 取得下一個日期（用於重複事件生成）
  DateTime getNextDate(DateTime date) => switch (this) {
    CalendarRepeatRule.once || CalendarRepeatRule.everyDay => date.add(const Duration(days: 1)),
    CalendarRepeatRule.everyWeek => date.add(const Duration(days: 7)),
    CalendarRepeatRule.everyTwoWeeks => date.add(const Duration(days: 14)),
    CalendarRepeatRule.everyMonth => DateTime(date.year, date.month + 1, date.day),
    CalendarRepeatRule.everyTwoMonths => DateTime(date.year, date.month + 2, date.day),
    CalendarRepeatRule.everyYear => DateTime(date.year + 1, date.month, date.day),
  };
}

extension CalendarReminderOptionLabel on CalendarReminderOption {
  String label(AppLocalizations loc) => switch (this) {
    CalendarReminderOption.fifteenMin => loc.reminderOptions15MinutesBefore,
    CalendarReminderOption.thirtyMin => loc.reminderOptions30MinutesBefore,
    CalendarReminderOption.oneHour => loc.reminderOptionsOneHourBefore,
    CalendarReminderOption.sameDay8am => loc.reminderOptionsDefaultSameDay8am,
    CalendarReminderOption.dayBefore8am => loc.reminderOptionsDefaultDayBefore8am,
    CalendarReminderOption.twoDays => loc.reminderOptionsTwoDaysBefore,
    CalendarReminderOption.oneWeek => loc.reminderOptionsOneWeekBefore,
    CalendarReminderOption.twoWeeks => loc.reminderOptionsTwoWeeksBefore,
    CalendarReminderOption.oneMonth => loc.reminderOptionsOneMonthBefore,
  };
}

// -------------------- DateTime Extensions --------------------
extension DateTimeExtension on DateTime {
  String toMonthKey() =>
      '$year-${month.toString().padLeft(2, CalendarMisc.zero)}';

  String formatDateString({bool passYear = false, bool formatShow = false}) {
    if (passYear) {
      return '${month.toString().padLeft(2, CalendarMisc.zero)}${formatShow ? '/' : '-'}${day.toString().padLeft(2, CalendarMisc.zero)}';
    }
    return '${year.toString()}${formatShow ? '/' : '-'}${month.toString().padLeft(2, CalendarMisc.zero)}${formatShow ? '/' : '-'}${day.toString().padLeft(2, CalendarMisc.zero)}';
  }
}

extension TimeOfDayExtension on TimeOfDay {
  String formatTimeString() {
    return '${hour.toString().padLeft(2, CalendarMisc.zero)}:${minute.toString().padLeft(2, CalendarMisc.zero)}';
  }
}

extension StringTimeOfDay on String {
  TimeOfDay? parseToTimeOfDay() {
    final parts = split(':');
    if (parts.length < 2 ||
        int.tryParse(parts[0]) == null ||
        int.tryParse(parts[1]) == null) {
      return null;
    }
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

