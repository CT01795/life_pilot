import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/main.dart';

BuildContext? get currentContext => navigatorKey.currentContext;
OverlayState? get currentOverlay => navigatorKey.currentState?.overlay;

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

extension ReminderOptionExtension on ReminderOption {
  Duration get duration {
    switch (this) {
      case ReminderOption.fifteenMin:
        return Duration(minutes: 15);
      case ReminderOption.thirtyMin:
        return Duration(minutes: 30);
      case ReminderOption.oneHour:
        return Duration(hours: 1);
      case ReminderOption.sameDay8am:
      case ReminderOption.dayBefore8am:
        return Duration.zero; // 這兩個用固定時間
      case ReminderOption.twoDays:
        return Duration(days: 2);
      case ReminderOption.oneWeek:
        return Duration(days: 7);
      case ReminderOption.twoWeeks:
        return Duration(days: 14);
      case ReminderOption.oneMonth:
        return Duration(days: 30);
    }
  }

  String toKey() {
    switch (this) {
      case ReminderOption.fifteenMin:
        return '15_min';
      case ReminderOption.thirtyMin:
        return '30_min';
      case ReminderOption.oneHour:
        return '1_hour';
      case ReminderOption.sameDay8am:
        return 'same_day_8am';
      case ReminderOption.dayBefore8am:
        return 'day_before_8am';
      case ReminderOption.twoDays:
        return '2_days';
      case ReminderOption.oneWeek:
        return '1_week';
      case ReminderOption.twoWeeks:
        return '2_weeks';
      case ReminderOption.oneMonth:
        return '1_month';
    }
  }

  static ReminderOption? fromKey(String key) {
    switch (key) {
      case '15_min':
        return ReminderOption.fifteenMin;
      case '30_min':
        return ReminderOption.thirtyMin;
      case '1_hour':
        return ReminderOption.oneHour;
      case 'same_day_8am':
        return ReminderOption.sameDay8am;
      case 'day_before_8am':
        return ReminderOption.dayBefore8am;
      case '2_days':
        return ReminderOption.twoDays;
      case '1_week':
        return ReminderOption.oneWeek;
      case '2_weeks':
        return ReminderOption.twoWeeks;
      case '1_month':
        return ReminderOption.oneMonth;
      default:
        return null;
    }
  }

  String getNotificationLabel(AppLocalizations loc) {
    switch (this) {
      case ReminderOption.fifteenMin:
        return loc.reminder_options_15_minutes_before;
      case ReminderOption.thirtyMin:
        return loc.reminder_options_30_minutes_before;
      case ReminderOption.oneHour:
        return loc.reminder_options_1_hour_before;
      case ReminderOption.sameDay8am:
        return loc.reminder_options_default_same_day_8am;
      case ReminderOption.dayBefore8am:
        return loc.reminder_options_default_day_before_8am;
      case ReminderOption.twoDays:
        return loc.reminder_options_2_days_before;
      case ReminderOption.oneWeek:
        return loc.reminder_options_1_week_before;
      case ReminderOption.twoWeeks:
        return loc.reminder_options_2_weeks_before;
      case ReminderOption.oneMonth:
        return loc.reminder_options_1_month_before;
    }
  }
}

class ReminderUtils {
  // 用 eventId + reminderOption 組合產生 notification ID
  static int generateNotificationId(String eventId, String option) =>
    eventId.hashCode ^ option.hashCode;

  // 將 option 字串轉為時間差
  static Duration getReminderDuration(ReminderOption option) {
    switch (option) {
      case ReminderOption.fifteenMin:
        return const Duration(minutes: 15);
      case ReminderOption.thirtyMin:
        return const Duration(minutes: 30);
      case ReminderOption.oneHour:
        return const Duration(hours: 1);
      case ReminderOption.twoDays:
        return const Duration(days: 2);
      case ReminderOption.oneWeek:
        return const Duration(days: 7);
      case ReminderOption.twoWeeks:
        return const Duration(days: 14);
      case ReminderOption.oneMonth:
        return const Duration(days: 30);
      default:
        return Duration.zero;
    }
  }

  //顯示用的提醒文字（可客製化）
  static String getReminderLabel(AppLocalizations loc, ReminderOption option) {
    switch (option) {
      case ReminderOption.fifteenMin:
        return loc.reminder_options_15_minutes_before;
      case ReminderOption.thirtyMin:
        return loc.reminder_options_30_minutes_before;
      case ReminderOption.oneHour:
        return loc.reminder_options_1_hour_before;
      case ReminderOption.sameDay8am:
        return loc.reminder_options_default_same_day_8am;
      case ReminderOption.dayBefore8am:
        return loc.reminder_options_default_day_before_8am;
      case ReminderOption.twoDays:
        return loc.reminder_options_2_days_before;
      case ReminderOption.oneWeek:
        return loc.reminder_options_1_week_before;
      case ReminderOption.twoWeeks:
        return loc.reminder_options_2_weeks_before;
      case ReminderOption.oneMonth:
        return loc.reminder_options_1_month_before;
    }
  }
}