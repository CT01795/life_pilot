import 'package:life_pilot/l10n/app_localizations.dart';

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
    const durationMap = {
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

    return durationMap[this]!;
  }

  String toKey() {
    const reminderOptionMap = {
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

    return reminderOptionMap[this]!;
  }

  static ReminderOption? fromKey({required String key}) {
    const keyToOptionMap = {
      '15_min': ReminderOption.fifteenMin,
      '30_min': ReminderOption.thirtyMin,
      '1_hour': ReminderOption.oneHour,
      'same_day_8am': ReminderOption.sameDay8am,
      'day_before_8am': ReminderOption.dayBefore8am,
      '2_days': ReminderOption.twoDays,
      '1_week': ReminderOption.oneWeek,
      '2_weeks': ReminderOption.twoWeeks,
      '1_month': ReminderOption.oneMonth,
    };

    return keyToOptionMap[key];
  }

  String getNotificationLabel({required AppLocalizations loc}) {
    final map = {
      ReminderOption.fifteenMin: loc.reminder_options_15_minutes_before,
      ReminderOption.thirtyMin: loc.reminder_options_30_minutes_before,
      ReminderOption.oneHour: loc.reminder_options_1_hour_before,
      ReminderOption.sameDay8am: loc.reminder_options_default_same_day_8am,
      ReminderOption.dayBefore8am: loc.reminder_options_default_day_before_8am,
      ReminderOption.twoDays: loc.reminder_options_2_days_before,
      ReminderOption.oneWeek: loc.reminder_options_1_week_before,
      ReminderOption.twoWeeks: loc.reminder_options_2_weeks_before,
      ReminderOption.oneMonth: loc.reminder_options_1_month_before,
    };

    return map[this]!;
  }
}